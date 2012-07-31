use strict;
use warnings;
use Xchat qw(:all);

register('Names Join', '001', 'Print the names replies when joining a channel');

hook_print('You Join', \&start_looking);

my $watching = {};
my $hook_names;
my $hook_complete;

# when joining, the server automatically sends a /names, look for it
sub start_looking {
	$watching->{get_info 'id'}{$_[0][1]} = get_context();
	# startup both hooks if complete isn't there
	unless ($hook_complete) {
		$hook_names = hook_server('353', \&cb_hook_names);
		$hook_complete = hook_server('366', \&cb_hook_complete);
	}
	return EAT_NONE;
}

# don't want double emits after the fact, only emit on the initial one that XChat hides
sub cb_hook_names {
	# only need to print out this event if looking and it matches (deal with context)
	if (defined $watching->{get_info 'id'}{$_[0][4]}) {
		set_context($watching->{get_info 'id'}{$_[0][4]});
		emit_print('Users On Channel', $_[0][4], substr $_[1][5], 1);
	}
	return EAT_NONE;
}

sub cb_hook_complete {
	my $id = get_info 'id';
	# progressively look for and delete down the line
	if (defined $watching->{$id}{$_[0][3]}) {
		delete $watching->{$id}{$_[0][3]};
		unless (keys %{$watching->{$id}}) {
			delete $watching->{$id};
			# if there are no more keys, then we can unhook
			unless (keys %$watching) {
				unhook($hook_names);
				unhook($hook_complete);
				undef $hook_names;
				undef $hook_complete;
			}
		}
	}
	return EAT_NONE;
}


__END__

Name:        namesjoin.pl
Version:     001
Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
Date:        2010-04-18
Description: XChat hides the inital names on join, this prints them


<< JOIN #dontmindme
>> :nickname!~user@host.whatever.net JOIN :#dontmindme
<< MODE #dontmindme
>> :irc.ircnetwork.net MODE #dontmindme +nt
>> :irc.ircnetwork.net 353 nickname = #dontmindme :@nickname
>> :irc.ircnetwork.net 366 nickname #dontmindme :End of /NAMES list.
>> :irc.ircnetwork.net 324 nickname #dontmindme +nt 
>> :irc.ircnetwork.net 329 nickname #dontmindme 1271607931
