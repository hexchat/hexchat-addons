# Name:        urltitlesay-005.pl
# Version:     005
# Author:      LifeIsPain
# Date:        2010-06-19
# Description: Parse through incoming lines for URLs, saying the titles of
#		the url when available. Keep a list of channels to reply in, as
#		well as URLs and Titles not to say

# Script will require using Perl 5.10 or updated "threads" and
# "threads::shared" modulesrather than Perl 5.8

# Change Log
# 001 2010-02-20 - Initial Release
# 002 2010-02-20 - better context handling in thread, title patern ignore
# 003 2010-02-25 - add 's to nick in default format, does not cause other
#			scripts to error
# 004 2010-03-12 - add default pattern ignore, set UA
# 005 2010-06-19 - should exit the thread explicitly, add actions, and
#			possible self calls (with configuration)

# available macros for message_format
#	{t} - The url title
#	{d} - The domain of the url
#	{u} - The full url (will have http:// prefixed if a normal www.)
#	{c} - The channel
#	{w} - Who said the url
#	{n} - The counter string (counter_format) when more than one url is said
#	{i} - Which URL in the message this applies to
#	{I} - How many URLs were in the message

use strict;
use warnings;
use Xchat qw(:all);
require LWP;
require YAML;
use File::Spec;
use threads;
use threads::shared;

register('Url Title Say', '005', 'Parse URLs from channel messages and say the tile');

my %human_readable = (
	channels_deny => 'channel deny list',
	channels_permit => 'channel permit list',
	nicks_deny => 'nick deny list',
	nicks_permit => 'nick permit list',
	patterns_ignore => 'pattern ignore list',
	titles_ignore => 'title pattern ignore list',
);
my %multi_line_lists = (
	titles_ignore => 1,
);

my @result_commands = ();
share(@result_commands);
my $active = 0;
share($active);

my $hooks = [];

hook_print($_, \&look_for_url) foreach ('Channel Message', 'Channel Msg Hilight', 'Channel Action', 'Channel Action Hilight');
hook_command('uts_loadconf', \&load_conf, { help_text => 'uts_loadconf, reload the configuration from disk' });
hook_command('uts_listmanage', \&manage_lists, { help_text => 'uts_listmanage <list name> (add|delete|list) [<string>]'});
hook_command('uts_set', \&manage_strings, { help_text => 'uts_set (message_format|counter_format|user_agent|self_call) [<string>]'});

my $CONF = {};
my $conf_file = File::Spec->catfile(get_info('xchatdir'), 'urltitlesay.conf');
load_conf();

# This will be called every line, most of which won't have URLs
sub look_for_url {
	# if there is an http or www in the line, goto the sub which is larger
	if ($_[0][1] =~ m/http|www/i) {
		goto &check_url;
	}
	return EAT_NONE;
}

sub check_url {
	# only need to continue on if we are in a valid channel
	my $channel = lc get_info('channel');
	my $nick = lc strip_code($_[0][0]);
	my $allowed = 1;
	my $replycontext = get_context();

	# If channels_permit is specified, only go on if it is a permited channel
	if (scalar %{$CONF->{channels_permit}}) {
		$allowed = 0 unless exists $CONF->{channels_permit}{$channel};
	}
	# otherwise, assume valid, unless in channel
	else {
		$allowed = 0 if exists $CONF->{channels_deny}{$channel};
	}

	if ($allowed) {
		# now that this is done, check individual nicks
		if (scalar %{$CONF->{nicks_permit}}) {
			$allowed = 0 unless exists $CONF->{nicks_permit}{$nick};
		}
		# otherwise, assume valid, unless in channel
		else {
			$allowed = 0 if exists $CONF->{nicks_deny}{$nick};
		}

		# more nested ifs (due to not wanting to multi point exit)
		if ($allowed) {
			# increment for that if check later
			$active++;
			threads->create(\&thread_command, get_context(), strip_code($_[0][0]), $_[0][1], get_info('channel'));

			# only really need to start up a thread if $active was 0, so now 1
			if ($active == 1) {
				hook_timer( 100,
					sub {
						while (scalar @result_commands) {
							# $result_commands[] = [ $context, $command ]
							my $command = pop @result_commands;
							# make sure it isn't a killthread
							if ($command->[1] eq 'killthread') {
								$command->[2]->join();
							}
							else {
								set_context($command->[0]);
								command($command->[1]);
							}
						}
						# if $active == 0, done for now
						if ($active == 0) {
							return REMOVE;
						}
						else {
							return KEEP;
						}
					}
				); 
			}
		}
	}
	return EAT_NONE;
}

# (get_context(), $strippednick, $fullline, get_info('channel'));
sub thread_command {
	# regex found and slighlty modified from:
	# http://daringfireball.net/2009/11/liberal_regex_for_matching_urls
	my @urls = $_[2] =~ m{\b((?:https?://?|www\.)[^\s()<>]+(?:\([\w\d]+\)|(?:[^[:punct:]\s]|/)))}gi;

	my $replaces = {
		'c' => $_[3],
		'w' => $_[1], # who gave url
		'n' => '', # the counter if used
		'I' => scalar @urls,
	};

	for (my $i = 0; $i < @urls; $i++) {
		# prefix url with http:// if it starts with www
		$urls[$i] = 'http://'.$urls[$i] if ($urls[$i] =~ /^www/i);
		next if (grep ($urls[$i] =~ /$_/i, @{$CONF->{patterns_ignore}}));
		my $ua = ($CONF->{user_agent} ? LWP::UserAgent->new(agent => $CONF->{user_agent}) : LWP::UserAgent->new());
		my $result = $ua->request(HTTP::Request->new(GET => $urls[$i]));
		if ($result->is_success && $result->title && $result->title !~ /^\s*$/) {
			# first, make sure it isn't one of those forbidden titles
			my $title = $result->title;
			next if (grep ($title =~ /$_/i, @{$CONF->{titles_ignore}}));
			# keep track of domain for macro
			$urls[$i] =~ m{^https?://(?:www\.)?([^/]+)};
			$replaces->{d} = $1;
			$replaces->{u} = $urls[$i];

			# set title macro
			$replaces->{t} = $title;

			# 0 to 1 base conversion
			$replaces->{i} = $i+1;
			if (@urls != 1) {
				my $counter = $CONF->{counter_format};
				$counter =~ s/{(\w)}/replace_macro($1, $replaces)/eg;
				$replaces->{n} = $counter;
			}
			my $reply = $CONF->{message_format};
			$reply =~ s/{(\w)}/replace_macro($1, $replaces)/eg;

			my $result = [];
			share($result);
			$result->[0] = $_[0];
			$result->[1] = 'say '.$reply;

			push(@result_commands, $result);
		}
	}

	push(@result_commands, shared_clone([$_[0], 'killthread', threads->self()]));

	# all done with this one, decrement
	$active--;
}

# for use in the modification of message_format, string inside of {}s passed
# as well as a hash reference containing replacement values
sub replace_macro {
	return (defined $_[1]->{$_[0]} ? $_[1]->{$_[0]} : "{$_[0]}");
}

# append a list to a reference, either of a hash, or a list
sub append_list {
	my $ref = shift;
	if (ref ($ref) eq 'HASH') {
		$ref->{$_} = undef foreach(@_);
	}
	elsif (ref ($ref) eq 'ARRAY') {
		my %seen = ();
		@seen{@$ref} = (1) x @$ref;
		foreach (@_) { push (@$ref, $_) unless ($seen{$_}++); }
	}
}

# remove items from a reference, either of a hash, or a list
sub remove_from_list {
	my $ref = shift;
	if (ref ($ref) eq 'HASH') {
		delete $ref->{$_} foreach(@_);
	}
	elsif (ref ($ref) eq 'ARRAY') {
		my %provided = ();
		@provided{@_} = (1) x @_;
		my $i = 0;
		while ($i < @$ref) {
			splice (@$ref, --$i, 1) if ($provided{$ref->[$i++]});
		}
	}
}

# return space delimited, either keys or items
sub list_to_string {
	my $string = '';
	my $ref = shift;
	if (ref ($ref) eq 'HASH') {
		$string = join (' ', sort keys %$ref);
	}
	elsif (ref ($ref) eq 'ARRAY') {
		$string = join (' ', @$ref);
	}
	return $string;
}

# return an array ref of 1 per line strings, with prefix
sub list_to_multiline {
	my $listref = [];
	my $ref = shift;
	if (ref ($ref) eq 'HASH') {
		push(@$listref, ' - '.$_."\n") foreach (sort keys %$ref);
	}
	elsif (ref ($ref) eq 'ARRAY') {
		push(@$listref, ' - '.$_."\n") foreach (@$ref);
	}
	return $listref;
}

# uts_listmanage <list_variable> (add|delete|list) [<string>]
sub manage_lists {
	my $error = 0;
	my @args = map ($_ = lc($_), @{$_[0]});
	my $command = shift @args;
	my ($what, $method, $string);

	if (@args) {
		$what = shift @args;
		$method = shift @args if @args;
		unless (defined $human_readable{$what}) {
			prnt('Unknown list, valid lists: '.join (', ', sort keys %human_readable));
			prnt('Usage: '.$command.' <list_name> (add|delete|list) [<string>]');
		}
		elsif (!$method) {
			prnt('Must specify a method, valid methods: add, delete, list');
			prnt('Usage: '.$command.' '.$what.' (add|delete|list) [<string>]');
		}
		elsif ($method eq 'add') {
			append_list($CONF->{$what}, @args);
			save_conf() if @args;
		}
		elsif ($method =~ m/^del/) {
			remove_from_list($CONF->{$what}, @args);
			save_conf() if @args;
		}
		elsif ($method eq 'list') {
			if (defined $multi_line_lists{$what}) {
				prnt ('URL Title Say '.$human_readable{$what}.':');
				prnt ( list_to_multiline($CONF->{$what}) );
			}
			else {
				prnt ('URL Title Say '.$human_readable{$what}.': '.list_to_string($CONF->{$what}));
			}
		}
		else {
			prnt('Unknown method, valid methods: add, delete, list');
			prnt('Usage: '.$command.' '.$what.' (add|delete|list) [<string>]');
		}
	}
	else {
		prnt('Usage: '.$command.' <list_name> (add|delete|list) [<string>]');
	}

	return EAT_XCHAT;
}

#uts_set (message_format|counter_format) [<string>]
sub manage_strings {
	my $var = lc $_[0][1] if (defined $_[0][1]);
	if (!defined $_[0][1] || ($var ne 'message_format' && $var ne 'counter_format' && $var ne 'user_agent' && $var ne 'self_call')) {
		prnt('Unknown variable, valid usage: '.$_[0][0].' (message_format|counter_format|user_agent|self_call) [<string>]');
	}
	elsif (!defined $_[1][2]) {
		# print current value
		prnt("$var: $CONF->{$var}");
	}
	else {
		$CONF->{$var} = $_[1][2];
		if ($var eq 'self_call') {
			$CONF->{$var} = ($CONF->{$var} =~ /^[tTyY1-9]/ ? 1 : 0);
			update_self_hook();
		}
		prnt("$var: $CONF->{$var}");
		save_conf();
	}
	return EAT_XCHAT;
}

sub load_conf {
	if (-r $conf_file) {
		$CONF = YAML::LoadFile($conf_file);
	}

	my %defaults = (
		channels_permit => {},
		channels_deny => {},
		nicks_permit => {},
		nicks_deny => {},
		patterns_ignore => ['\.(jpe?g|png|gif|exe|dll|py|pl)$'],
		titles_ignore => [],
		message_format => '{w}\'s Website Title{n}: {t}',
		counter_format => '[{i}]',
		user_agent => '',
		self_call => 0,
	);

	# make sure the defaults are good
	foreach (keys %defaults) {
		$CONF->{$_} = $defaults{$_} unless defined $CONF->{$_};
	}

	update_self_hook();
}

sub update_self_hook {
	# clear any existing self hooks
	foreach (@{$hooks}) {
		unhook $_;
	}
	$hooks = [];
	if ($CONF->{self_call}) {
		foreach ('Your Message', 'Your Action') {
			push (@{$hooks}, hook_print($_, \&look_for_url));
		}
	}
}

sub save_conf {
	if (!-e $conf_file || -w $conf_file) {
		YAML::DumpFile($conf_file, $CONF);
	}
}
