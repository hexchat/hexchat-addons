#!perl
package AutoNick;
use strict;
use warnings;

use HexChat qw,:all,;

# Change this to a true value to see some debug output.
use constant DEBUGGING => 0;

# If you log on, and there's another "you", we send him a message which he
# *ought to* automatically respond to.  If he doesn't after CTCP_TIMEOUT
# milliseconds, we give him the boot, or at least ask NickServ to do so for us.
use constant CTCP_TIMEOUT => 2_000;

# After asking NickServ to log your other self off, 
# we wait NICK_TIMEOUT milliseconds until doing /NICK
use constant NICK_TIMEOUT =>  2_000;

# It's still alpha, but now debugging can be toggled and the timeouts are
# no longer hardcoded literals.
register( "Automatic NICK", '0.2',
	"Acquire preferred nick as soon as possible" );

sub _net_preferred {
	my $netname = get_info("network") or return;
	my ($netinfo) = grep $_->{network} eq $netname, get_list "networks"
		or return;
	@{$netinfo}{sort grep /^irc_nick/, keys %$netinfo};
}

sub _global_preferred {
	map get_prefs("irc_nick$_"), 1..3;
}

sub _preferred {
	my %seen;
	grep defined && length && !$seen{$_}++, _net_preferred, _global_preferred;
}

sub _nick_ix {
	my ($nick, $nicks) = @_;
	for my $ix (0 .. $#$nicks) {
		next if nickcmp $nick, $nicks->[$ix];
		return $ix || "0e0";
	}
	return ();
}

# In theory, we should only hook this if we don't have
# our favorite nick on all servers we're connected to.

# In practice, it's not worth the complication that'd be
# involved in detecting that, and detecting new network
# connections (or reconnections), and re-enabling the hook.

# I suppose if we were on a channel where folks were nick-ing
# and quitting constantly, the cpu-usage might make it worthwhile,
# but none of the channels *I* chat on are like that.

sub _someone_left {
	my ($words, $words_eol, $cb_extra) = @_;
	my ($he) = @$words;
	$he =~ s/^://;
	$he =~ s/!.*// or $he =~ s/\@.*//;
	my @nicks = _preferred or return EAT_NONE;
	my $he_ix = _nick_ix( $he, \@nicks ) or return EAT_NONE;
	my $me_ix = _nick_ix( get_info("nick"), \@nicks ) || @nicks;
	&print("In _someone_left callback: [@$words]\n") if DEBUGGING;
	command "NICK $he" if $me_ix > $he_ix;
	EAT_NONE;
}

hook_server $_, \&_someone_left for "NICK", "Change Nick", "Quit";

use constant MOTD_DONE_MASK => ( 1 << 3 );

BEGIN {
	my %hooks;
	my $notice_hook;
	
	# Only pay attention to notices sent by
	# persons that we sent ctcp pings to.
	sub _notice_hook {
		my ($words, $words_eol, $cb_extra) = @_;
		my ($nick) = $words->[0] =~ m/^:([^!]+)!/ or return EAT_NONE;
		my $id = get_info "id";
		my $nick2timeout = $hooks{$id} or return EAT_NONE;
		my @want = keys %$nick2timeout;
		my $ix = _nick_ix $nick, \@want or return EAT_NONE;
		my $timeout = delete $nick2timeout->{$want[$ix]} or return EAT_NONE; 
		
		# No matter what kind of message we got from $nick,
		# it means they're not disconnected.  We don't need
		# to parse the ctcp ping response.  Just throw away
		# the timeout, and perhaps the notice hook.
		&print("Got a NOTICE from $nick; won't ghost him.") if DEBUGGING;
		
		unhook $timeout;
		delete $hooks{$id} unless %$nick2timeout;
		if( not keys %hooks ) {
			unhook $notice_hook;
			undef $notice_hook;
		}
		EAT_NONE;
	}
	
	sub _timeout_hook {
		my ($want_and_id) = @_;
		my ($want, $id) = @$want_and_id;
		my $nick2timeout = $hooks{$id} or return REMOVE;
		defined delete $nick2timeout->{$want} or return REMOVE;
		
		delete $hooks{$id} unless %$nick2timeout;
		if( not keys %hooks ) {
			unhook $notice_hook;
			undef $notice_hook;
		}
		
		unless( $id eq get_info("id") ) {
			# uh-oh, the the context we were created in no
			# longer exists AND the 'randomly selected' context
			# isn't the right network.
			my @c = grep $_->{id} eq $id, get_list("channels")
				or return REMOVE;
			my ($c) = sort { $a->{type} <=> $b->{type} } @c;
			set_context $c;
		}
		
		# if we've got multiple preferred nicks, and we switched
		# to our favorite nick during the timeout, we're done.
		my @nicks = _preferred;
		if( my $me_ix = _nick_ix( get_info("nick"), \@nicks ) ) {
			return REMOVE if 0 == $me_ix;
			my $he_ix = _nick_ix( $want, \@nicks ) or die;
			return REMOVE if $me_ix <= $he_ix;
		}
		
		unless( context_info->{flags} & MOTD_DONE_MASK ) {
			# We must have disconnected while waiting for the timeout.
			# Annoying.
			return REMOVE;
		}

		&print("The timeout has expired.  Time to ghost $want") if DEBUGGING;
		my $pass = get_info "nickserv";
		defined($pass) ? ($pass = " $pass") : ($pass = "");
		if( DEBUGGING ) {
			command "MSG NICKSERV GHOST $want$pass";
		} else {
			command "QUOTE PRIVMSG NICKSERV :GHOST $want$pass";
		}
		hook_timer NICK_TIMEOUT, sub { command "NICK ".pop; REMOVE }, $want;
		REMOVE;
	}

	my %motd_pending;
	my @motd_hooks;
	
	sub _motd_done_hook {
		my $id = get_info("id");
		defined(my $want = delete $motd_pending{$id}) or return EAT_NONE;
		&print("The motd for id $id is done") if DEBUGGING;
		unless( %motd_pending ) {
			unhook $_ for splice @motd_hooks;
		}
		_consider_ghosting( $_, 1 ) for keys %$want;
		EAT_NONE;
	}
	
	sub _consider_ghosting {
		my ($want, $force) = @_;
		my $id = get_info("id");
		return if $hooks{$id}{$want};
		&print("In _consider_ghosting(@_)\n") if DEBUGGING;
		MOTD_DONE: {
			last if $force;
			last if context_info()->{flags} & MOTD_DONE_MASK;
			&print("The motd is not done!  Waiting for it to finish...") if DEBUGGING;
			undef $motd_pending{$id}{$want};
			unless( @motd_hooks ) {
				push @motd_hooks, hook_server $_, \&_motd_done_hook
					for 422, 376;
			}
			return;
		}
		$notice_hook = hook_server "NOTICE", \&_notice_hook unless $notice_hook;
		$hooks{$id}{$want} = hook_timer CTCP_TIMEOUT, \&_timeout_hook, [ $want, $id ];
		&print("About to ctcp ping $want\n") if DEBUGGING;
		command "PING $want";
	}
}

sub _nickchange_failed {
	my ($words, $words_eol, $nick_ix) = @_;
	&print("In _nickchange_failed callback: [@$words]\n") if DEBUGGING;
	my $want = $words->[$nick_ix];
	my @nicks = _preferred or return EAT_NONE;
	my $want_ix = _nick_ix( $want, \@nicks ) or return EAT_NONE;
	return EAT_NONE if $want_ix == $#nicks;
	_consider_ghosting( $nicks[$_] ) for 0 .. $want_ix;
	return EAT_NONE;
}


hook_server 433, \&_nickchange_failed, {data => 3};
hook_server 'Nick Clash', \&_nickchange_failed, {data => 0};

{
	my $original = get_context;
	my %seen;
	for my $s_info ( sort { $a->{type} <=> $b->{type} } get_list "channels" ) {
		next if $seen{$s_info->{id}}++;
		set_context $s_info->{context};
		#next unless context_info->{flags} & MOTD_DONE_MASK;
		&print( "In get_list loop, network is $s_info->{network}\n") if DEBUGGING;
		&print( "The network type is $s_info->{type}, id is $s_info->{id}\n") if DEBUGGING;
		my @nicks = _preferred or next;
		my $me_ix = _nick_ix( get_info("nick"), \@nicks ) || @nicks;
		&print( "Prefered nicks: [@nicks]\n" ) if DEBUGGING;
		&print( "\$me_ix: $me_ix\n" ) if DEBUGGING;
		_consider_ghosting($nicks[$_]) for 0 .. $me_ix - 1;
	}
	set_context $original;
}

&print('Perl plugin '.__PACKAGE__.' loaded.');
1;
__END__
