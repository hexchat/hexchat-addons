#
# No modifications to the code are necessary to use it.
#
use strict;
use warnings;
use POSIX 'strftime';
use Xchat qw(:all);

my $NAME    = 'textualdynambot';
my $VERSION = '009.01';
my $PREFIX  = "\02TDB\02\t";
register($NAME, $VERSION, 'The reaction script.');

use constant CONF_FILE    => 'textualdynambot.conf'; # filename looked for in 'xchatdir'
use constant MACRO_CHAR   => '%'; # for conf macros
use constant MACRO_META   => '\\\\%'; # for conf macros that are given quotemeta
use constant SEPARATOR    => qr{\s*:\s*}; # for conf properties
use constant LIST_SEP     => qr{\s*,\s*}; # for conf values
use constant NO_MODE      => 'none'; # mode string for no-mode user
use constant REGEX_FLAG   => '/'; # something that can't start a user mask
use constant NETWORK_SEP  => ':'; # network:#channel in +-in/where
use constant MASK_MESSAGE => 1;
use constant MASK_ACTION  => 2;
use constant MASK_HILIGHT => 4;
use constant MASK_NORMAL  => 8;

my $patterns; # script-wide config entries stored here
my %COMMANDS = (
	'TEXTUALDYNAMBOT' => [ \&cmd_tdb, 'Usage: TEXTUALDYNAMBOT [off], reloads '.CONF_FILE.', or disables replies' ],
	'TDB'             => [ \&cmd_tdb, 'Usage: TDB [off]'.         ', reloads '.CONF_FILE.', or disables replies' ],
	'TDBECHO' => [ \&user_test,
		" <nick!user\@addr> '<mode>' <ispriv> <isaction> <ishilight> <network or server> <message text>\n".
		"	   quotes on mode are required (eg '\@', '+', '')\n".
		"	   ispriv, isaction, and ishilight should be 1 or 0\n".
		"	   TDBTEST runs the commands, TDBECHO prints the commands instead\n" ],
);
$COMMANDS{'TDBTEST'} = [ \&user_test, 'Usage: TDBTEST'.$COMMANDS{'TDBECHO'}->[1] ];
$COMMANDS{'TDBECHO'}->[1] = 'Usage: TDBECHO'.$COMMANDS{'TDBECHO'}->[1];
hook_command( $_, $COMMANDS{$_}->[0], { help_text=>$COMMANDS{$_}->[1] } ) for( keys %COMMANDS );
prnt( "\02$NAME v$VERSION\02 by LifeIsPain, based on thermodynambot by b0at (use /".(join(', /',keys %COMMANDS)).")" ); # announce

my @privmsg_hooks = (); # for hooking/unhooking events
my $who_rate_hook;
hookage(1); # do config and hook events for the first time

my $waiting_on = {}; # need for doing less whos

# handle differences in events, then pass to respond, then to do_commands to execute
# stripping color codes from the nick is key
sub hdl_chan             {
	my ($nick, $text, $mode) = @{$_[0]};
	if( my $cmds = respond({nick=>strip_codes($nick), msg=>$text, mode=>$mode, private=>0, mask=>$_[1]}) )
	{ do_commands( $cmds, get_context() ) }
	return EAT_NONE;
}
sub hdl_priv             {
	my ($nick, $text) = @{$_[0]};
	if( my $cmds = respond({nick=>strip_codes($nick), msg=>$text, mode=>'',    private=>1, mask=>$_[1]}) )
	{ do_commands( $cmds, get_context() ) }
	return EAT_NONE;
}
sub user_test            { # handle user command triggering for testing
	my ($word, $eol) = @_;
	if( $$word[7] and $$word[2]=~/^(['"])(.*)\1$/ ) {
		my ($nick,$host) = split '!', $$word[1];
		my $cmds = respond( 
		{
			msg=>$$eol[7], 
			#mode=>$2, 
			private=>$$word[3], 
			action=>$$word[4], 
			hilight=>$$word[5],
			network=>$$word[6],
			mask=>($$word[4] ? MASK_ACTION : MASK_MESSAGE) | ($$word[5] ? MASK_HILIGHT : 0),
		}, 
		{
			nick=>$nick, 
			host=>$host, 
			prefix=>$2
		});
		if( uc $$word[0] eq 'TDBECHO' ) { prnt($PREFIX.$_) foreach( @$cmds ) }
		else { do_commands($_, get_context()) foreach( @$cmds )	}
	}
	else { prnt( $COMMANDS{TDBTEST}->[1] ) }
	return EAT_ALL; # don't pass to server
}

sub respond              {
	my ($event, $user) = @_; # hash refs

	# get some context info (needed for user_info_* below)
	unless (defined $$event{where}) { # why do this if we already have it?
		$$event{where}     = get_info('channel'); # get tab name
		$$event{server}    = get_info('server')  || 'offline';
		$$event{network} ||= get_info('network') || $$event{server};
		$$event{match}     = ($$event{private} ?
			[ $$event{network}, $$event{mask} ] :
			[ $$event{network}, $$event{where}, $$event{mask} ]
		);
	}

	# if for whatever reason, $_[0][0] or $_[0][1] aren't defined, why do anything?
	return unless (defined $$event{msg} && defined $$event{nick});

	# never should have this infi loop again, but better safe than sorry
	$$event{attempt} = (defined $$event{attempt} ? $$event{attempt} + 1 : 0);
	return if ($$event{attempt} > 3); # silently eating if it makes it back here too much

	# if we don't already have user info...
	$user = user_info( $$event{nick} )      if not ($user and $$user{host});   # check the current tab
	$user = user_info_tabs( $event, $user ) if not ($user and $$user{host});   # next, check other tabs

	# may have no user information if a PM or a out of channel message
	if( not defined $user ) {                                                   # next, do a /who <nick>
		user_info_who($event);
		return; # will pick up after who results
	}
	if( not defined $$user{host} ) {
		# if there is a user, but no host, check to see if a who
		# is waiting to be done
		if (get_prefs('irc_who_join') && not defined $$event{nowhojoin}) {
			channel_who_wait($event);
			return;
		}
		else {
			user_info_who($event);
			return; # will return from who catch
		}
	}

	@$user{qw(user addr)} = split '@', $$user{host};
	$$user{who}           = ($$user{nick}||'') . '!' . ($$user{host}||''); # PARENTHESES CRUCIALLY CRITICAL
	my @commands; # store commands to run later

	# check patterns against event data
	# 006: define PATTERN block for next in action/private check
	PATTERN: for my $rule (@$patterns) {

		next if not my @match = $$event{msg} =~ /$$rule{pattern}/;              # required text

		# people
		next if     match($$user{who}, $$rule{from}[0]);                        # excluded people
		next unless match($$user{who}, $$rule{from}[1]);                        # required people

		# private events
		if( $$event{private} )
		{
			# network + mask
			next if match_nm($$event{match}, $$rule{private}[0]);
			next unless match_nm($$event{match}, $$rule{private}[1]);
		}
		# public events
		else
		{ 
			# channels + network + mask
			next if match_ncm($$event{match}, $$rule{where}[0]);
			next unless match_ncm($$event{match}, $$rule{where}[1]);

			# modes
			if( not $$user{prefix} and not $$rule{nomode}[1] ) {          # if user modeless + modeless not explicitly allowed
				next if $$rule{nomode}[0];                                 # ... next if modeless explicitly disallowed
				next if not $$rule{nomode}[1] and not $$rule{nomode}[1]    # ... next if modeless not explicitly mentioned
					and scalar @{$$rule{mode}[1]}                           # ... + and other modes are required

			} elsif( $$user{prefix} ) {                                   # elsif user has a mode
				next if not @{$$rule{mode}[1]} 	                          # ... next if no modes are required
					and $$rule{nomode}[1];                                  # ... + except for modeless
				next if scalar @{$$rule{mode}[1]}                          # ... next if any modes are required
					and not match_eq($$user{prefix}, $$rule{mode}[1]);      # ... + and user doesn't match one
				next if scalar @{$$rule{mode}[0]}                          # ... next if any modes are excluded
					and match_eq($$user{prefix}, $$rule{mode}[0]);          # ... + and user matches one
			}
		}

		# check if the cap has been reached
		if ($$rule{capnum}) {
			my $timesused = 0;
			# trim the old ones
			while (defined $$rule{captrack}[0] && $$rule{captrack}[0][0] < time - $$rule{captime}) {
				pop @{$$rule{captrack}};
			}
			if ($$rule{capshared}) {
				$timesused = scalar @{$$rule{captrack}};
			}
			else {
				my $context = get_context();
				foreach (@{$$rule{captrack}}) {
					$timesused++ if $$_[1] == $context;
				}
			}
			# don't respond this time, but some other rule may be used
			next PATTERN if $timesused >= $$rule{capnum};
		}

		# the event matched
		push @commands, expand_macros( $$rule{commands}, \@match, $event, $user);
		# keep track of throttling in some cases
		if ($$rule{capnum}) {
			push @{$$rule{captrack}}, [scalar time, get_context()];
		}
	}
	return \@commands;
}
sub load_conf        ($) { # read in conf, return valid data; print on error, stop on fatal error
	my ($filename, $count, $fh, $new_conf) = (shift, 0,);
	return unless( $filename and -e $filename 
		and open $fh, '<:encoding(UTF-8)', $filename );

	my @p; # store pattern entries here
	while( my $l = <$fh> ) {
		++$count; # line count

		next if $l=~/^#/;
		$l =~ s/^\s+//; # trim after checking for comments, '#' must be first char
		$l =~ s/\s+$//;
		next if $l=~/^$/;
		last if $l=~/^__END__$/;

		if( my ($method, $pattern)     = $l =~ /^\[(text|regex|line)(??{SEPARATOR})(.+?)\]$/i ) {
			# new entry
			push @p, { #   => [ neg (0),  pos (1) ],
					# 006: DEFAULT to blank, but later on, default to +in: * if not specified
					from     => [ [],       []  ], 
					where    => [ [],       []  ],

					mode     => [ [],       []      ], # status
					# special values, bool
					nomode   => [ undef,    undef   ], # there's probably a better way, but it's fine for now
					#			networks allowed, networks disallowed
					private  => [ [],       []      ],
					commands => [],							# just a list
					# Using throttles will require a number and a time frame
					captime   => 60, # default to 1 minute
					capnum    => 0,
					capshared => 0,
					captrack  => [], 
				};

			if( lc $method eq 'text' ) {   
				$p[$#p]{pattern} = '(?i)'.wildcard($pattern); # '(?i)' makes it case insensitive
			}
			elsif( lc $method eq 'line' )  {
				$p[$#p]{pattern} = '(?i)^'.wildcard($pattern).'$'; # new to 005
			}
			elsif( lc $method eq 'regex' ) {
				$p[$#p]{pattern} = $pattern;
			}
		}
		elsif ( $l =~ /^\[.*\]$/i ) { # bad form in an entry, don't risk overlapping entries' data
			prnt($PREFIX."Parse error: '$_' is not of the form '[method:REGULAR EXPRESSION]',");
			prnt($PREFIX."\cBParse halted.\cB");
			last;
		}

		elsif ( my ($plusminus, $option, $value) = $l =~ /^(\+|-)?(\S+?)(??{SEPARATOR})(.+)$/ ) {
			$option = lc $option;
			$plusminus = (defined $plusminus && $plusminus eq '+') ? 1 : 0;

			if ( $option eq 'in' || $option eq 'where' )   {
				PLACE: for my $place ( split LIST_SEP, $value ) {
					# Network:#channel:channel/private/hilight/all:message/action
					# hilight is implied in channel
					# check for all type so combinations with a split
					my @parts = split (NETWORK_SEP, $place);
					my $index = scalar @parts - 1;
					my %options = (
						network => undef,
						channel => undef,
						private => 0,
						mask    => (MASK_NORMAL | MASK_HILIGHT),
					);
					# only 5 needed, but allow for hilight and channel both (althouh implied)
					if ($index > 5) {
						prnt($PREFIX.'Too many options in location on line '.$count.': '.$place);
					}
					else {
						# go from back to front until word does not match an option
						while($index >= 0) {
							$_ = $parts[$index];
							if (/^(?:message|msg)$/i) {
								$options{mask} |= MASK_MESSAGE;
							}
							elsif (/^action$/i) {
								$options{mask} |= MASK_ACTION;
							} 
							elsif (/^hi(?:gh)?light$/i) {
								$options{mask} &= ~MASK_NORMAL;
								$options{mask} |= MASK_HILIGHT;
							}
							elsif (/^(?:normal|no.*light)$/i) {
								$options{mask} &= ~MASK_HILIGHT;
								$options{mask} |= MASK_NORMAL;
							}
							elsif (/^(?:private|pm)$/i) {
								$options{private} = 1;
							}
							elsif (/^chan(?:nel)?$/i) {
								# just incase someone puts it in!
								$options{channel} = '.+';
							}
							else {
								# at this point, there should only be two items left
								if ($index > 1) {
									prnt($PREFIX.'Too many options left over, not all can be valid. Line '.$count.': '.join(NETWORK_SEP, @parts[0..$index]));
									next PLACE;
								}
								elsif ($index == 0) {
									if ($options{private} || /^\w/) {
										$options{network} = regex_or_wild($_);
									}
									else {
										$options{channel} = regex_or_wild($_);
									}
								}
								else {
									$options{network} = regex_or_wild($parts[0]);
									$options{channel} = regex_or_wild($parts[1]);
									$index = 0;
								}
									
							}
							$index--;
						}
						# fill in the missing bits
						# set to show on messages if not specified on action
						if ( !($options{mask} & MASK_ACTION) ){
							# if it was already set, don't care, do again!
							$options{mask} |= MASK_MESSAGE;
						}
						# set the default channel as all if none provided and not private
						if (!defined $options{channel} && !$options{private}) {
							$options{channel} = '.+';
						}
						# set network to all if not provided
						if (!defined $options{network}) {
							$options{network} = '.+';
						}

						# push the new setting to the appropriate area(s)
						if ($options{private}) {
							push @{ $p[$#p]{private}[$plusminus] }, [$options{network}, $options{mask}];
						}
						if (defined $options{channel}) {
							push @{ $p[$#p]{where}[$plusminus] }, [$options{network}, $options{channel}, $options{mask}];
						}
					}
				} # // for $place loop
			}
			elsif ( $option eq 'from' )                    {
				for ( split LIST_SEP, $value ) {
					if( /^(??{REGEX_FLAG})([^!]+![^@]+@.+)$/ ) { # full mask - regex
						push @{ $p[$#p]{from}[$plusminus] }, $1;
					}
					elsif( /^[^!]+![^@]+@.+$/ )                { # full mask - wildcard
						push @{ $p[$#p]{from}[$plusminus] }, wildcard($_);
					}
					elsif( /^[^!]+!$/ )                        { # lonesome nick ('bob!')
						push @{ $p[$#p]{from}[$plusminus] }, wildcard($_).".*?@.*?";
					}				
					elsif( /^\@.+$/ )                          { # lonesome address ('@foo.com')
						push @{ $p[$#p]{from}[$plusminus] }, ".*?!.*?".wildcard($_);
					}
					else { # unknown - assume wildcard on full mask (eg '*')
						push @{ $p[$#p]{from}[$plusminus] }, wildcard($_);
					}
				}
			}
			elsif ( $option eq 'mode' )                     {
				my %modelist = map {$_=>1} split LIST_SEP, $value;
				# extract NO_MODE keyword
				if( $modelist{+NO_MODE} ) { # NO_MODE is a constant
					$p[$#p]{nomode}[$plusminus] = 1; # eg -mode: none -> nomode[-==0]=1 -> no moders are disallowed
					delete $modelist{+NO_MODE};
				}
				push @{ $p[$#p]{mode}[$plusminus] }, keys %modelist; # regular modes
			}
			elsif ( $option eq 'command' )                 {
				push @{ $p[$#p]{commands} }, $value;
			}
			elsif ( $option eq 'captime' )                 {
				$p[$#p]{captime} = abs int $value;
			}
			elsif ( $option eq 'capnum' )                  {
				$p[$#p]{capnum} = abs int $value;
			}
			elsif ( $option eq 'capshared' )               {
				# no set for 0, no, off, false
				# yes set for 1, yes, on, true
				$p[$#p]{capshared} = ($value =~ m/^(?:y|on|t)/i || int $value > 0) ? 1 : 0;
			}
			else { # unknown option
				prnt($PREFIX."Unknown option on line $count");
			}
		}
		else { # parse error notice
			prnt($PREFIX."Parse error on line $count: unknown data.");
		}
	} # <$fh>
	close $fh;

	# 006: rather than in 005.02 how defaulted to +in: * and +from: *, this caused too many matches, when others were specified
	#   in 006, after all lines are parsed, go through each hash and add the defaults if none are present otherwise
	foreach (@p) {
		# For from people, check to see that -1 is the last added item in array ref, if so, add one of default
		if ($#{$_->{from}[1]} == -1) {
			$_->{from}[1] = ['.+'];
		}
		# Same as above, but make sure for both where and private, cause private shouldn't be public
		if ($#{$_->{where}[1]} == -1 && $#{$_->{private}[1]} == -1) {
			$_->{where}[1] = [ ['.+', '.+', (MASK_MESSAGE | MASK_HILIGHT | MASK_NORMAL)] ];
		}
	}

	return \@p;
}

# helpers

sub do_commands     ($$) {
	my ($cmds, $context) = @_;
	hook_timer(0, # immediately after this event
	sub {
		#my $original_context = get_context(); # uncomment for polite context switching
		set_context( $context );
		command( $cmds );
		#set_context($original_context); # uncomment for polite context switching
		return REMOVE; # do this timer only once
	} );
}
sub user_info_tabs   ($) {
	my ($event, $user) = @_;
	my $original_context = get_context();
	CHANNEL: for my $tab ( get_list('channels') ) {

		# find channel on same server as event
		next unless $$tab{type} == 2; # channel
		next unless((
			$$event{network} and $$tab{network} and
				$$tab{network} eq $$event{network}
		) or (
			$$event{server}  and $$tab{server}  and
				$$tab{server}  eq $$event{server}
		));

		# channel on same server: go there
		set_context( $$tab{context} );

		# find user with same nick
		for my $u ( get_list('users') ) {
			next unless nickcmp( $$u{nick}, $$event{nick} )==0;
			# found the guy
			# doesn't do any good unless host defined
			next CHANNEL unless (defined $$u{host});
			set_context( $original_context ); # be polite
			# return a shallow copy with previous prefix
			# (if in another channel, prefix doesn't apply)
			return {%$u, prefix=>$$event{mode}};
			# doing $u={%$u}; then setting prefix and returning $u
			#	resulted in some strange "attempt to free unreferenced
			#	scalar" errors, this method works without resorting
			#	to Storable's dclone()
		}
	}
	set_context( $original_context ); # be polite
	return $user; # if there isn't something found, pass what came in
}
sub channel_who_wait ($) {
	my ($event) = @_;
	my ($sid, $who_hook) = (get_info('id'), );

	$$event{context}   = get_context();

	# only need to look for 352, as 315 will already be eaten
	if (not scalar keys %{$waiting_on}) {
		$who_hook = hook_server('352', sub {
			my $hook_sid = get_info('id');
			if ( defined $$waiting_on{$hook_sid}{$_[0][7]} ) {
				foreach (@{$waiting_on->{$hook_sid}{$_[0][7]}{events}}) {
					do_commands( respond($_, { # fill in user data...
						away => ($_[0][8]=~/G/?1:0),
						nick => $_[0][7], # actual, case-correct nick
						host => $_[0][4].'@'.$_[0][5],
						prefix => $_->{mode}||'', # doesn't apply if they're not in the channel
					}), $_->{context} ); # do commands in required context
				}
				delete $waiting_on->{$hook_sid}{$_[0][7]};
				# if this was the last one, delete away
				delete $waiting_on->{$hook_sid} unless scalar keys %{$waiting_on->{$hook_sid}};
				unhook($who_hook) unless scalar keys %{$waiting_on};
			}
			return EAT_NONE; # the who is already eaten based on irc_who_join
		});
		prnt("$who_hook is undefined?");
	}

	# are we already waiting on this nick?
	if ( defined $$waiting_on{$sid} && defined $$waiting_on{$sid}{$$event{nick}} ) {
		push (@{$waiting_on->{$sid}{$$event{nick}}{events}}, $event);
	}
	else {
		$$waiting_on{$sid}{$$event{nick}}{events} = [$event];
	}

}
sub user_info_who    ($) {
	my ($event) = @_; # user may be undef though, but it may have prefix!
	my ($sid, $who, $who_end) = (get_info('id'), );
	$$event{context} = get_context() unless $$event{context};

	# even though much of this is similar to channel_who_wait, keeping separate
	# and at a higher priority so as to eat a 315 if necessary
	if ( defined $$waiting_on{$sid} && defined $$waiting_on{$sid}{$$event{nick}} ) {
		push (@{$waiting_on->{$sid}{$$event{nick}}{events}}, $event);
	}
	else {
		$$waiting_on{$sid}{$$event{nick}}{events} = [$event];

		$who = hook_server('352', sub {
			my ($w, $e) = @_;
			return EAT_NONE if nickcmp($$w[7],$$event{nick})!=0;

			my $hook_sid = get_info('id');
			if ( defined $$waiting_on{$hook_sid}{$$w[7]} ) {
				foreach (@{$waiting_on->{$hook_sid}{$$w[7]}{events}}) {
					do_commands( respond($_, { # fill in user data...
						away => ($$w[8]=~/G/?1:0),
						nick => $$w[7], # actual, case-correct nick
						host => $$w[4].'@'.$$w[5],
						prefix => $_->{mode}||'', # doesn't apply if they're not in the channel
					}), $_->{context} ); # do commands in required context
				}
				delete $$waiting_on{$hook_sid}{$$w[7]};
				# if this was the last one, delete away
				delete $$waiting_on{$hook_sid} unless scalar keys %{$waiting_on->{$hook_sid}};
			}
			unhook($who); undef($who); # remove this hook
			return EAT_XCHAT; # hide our /who from user
		}, { priority => PRI_HIGH } );

		# hide "End of /who output" line from user, too
		$who_end = hook_server('315', sub {
			return EAT_NONE if $who; # still waiting on our who output
			unhook($who_end); return EAT_XCHAT;
		} );
		# keep these in the record incase they need to be unhooked
		$$waiting_on{$sid}{$$event{nick}}{whohook} = $who;
		$$waiting_on{$sid}{$$event{nick}}{whoend} = $who_end;

		# now send the command and wait for server response
		command("who $$event{nick}");
	}
}
# if we get a 263, there may be events still in holding, need to re-run them all
sub who_rate_limited     {
	return EAT_NONE unless ($_[0][3] eq 'WHO');
	my $sid = get_info('id');
	if ( defined $$waiting_on{$sid} ) {
		# must wait 500ms after receiving due to rate limiting (since this was
		# already limited), then make sure the send buffer is clear first
		hook_timer(500, sub {
			my $ci = context_info();
			if ($$ci{queue}) {
				return KEEP;
			}
			else {
				foreach my $usergroup (keys %{$waiting_on->{$sid}}) {
					# try again individually
					foreach (@$usergroup) {
						$$_{nowhojoin} = 1;
						do_commands(respond($_), $$_{context});
					}
					unhook ($$usergroup{whohook}) if (defined $$usergroup{whohook});
					unhook ($$usergroup{whoend})  if (defined $$usergroup{whoend});
				}
				delete $$waiting_on{$sid};
				return REMOVE;
			}
		});
		return EAT_XCHAT;
	}
	else {
		return EAT_NONE;
	}
}

sub match           ($$) { # find first /^match$/ in list, return pattern matched for success or undef
	my ($value, $list) = @_;
	for ( @$list ) { return $_ if $value =~ /^$_$/ }
	return;
}
sub match_eq        ($$) { # the '+' for voice mode screws with regex
	my ($value, $list) = @_;
	my %search = map {$_=>1} @$list;
	return exists $search{$value};
}
sub match_ncm       ($$) {
	my ($values, $list) = @_;
	for my $sublist (@$list) {
		return $sublist if (($$values[2] & $$sublist[2]) == $$values[2] &&
			$$values[0] =~ /^$$sublist[0]$/ &&
			$$values[1] =~ /^$$sublist[1]$/);
	}
	return;
}
sub match_nm        ($$) {
	my ($values, $list) = @_;
	for my $sublist (@$list) {
		return $sublist if (($$values[1] & $$sublist[1]) == $$values[1] &&
			$$values[0] =~ /^$$sublist[0]$/);
	}
	return;
}
sub wc_escapes     ($$$) {
	my ($slashes, $normal, $replacement) = @_;
	if ((length $slashes) % 2 == 1) {
		return "$slashes$normal";
	}
	else {
		return "$slashes$replacement";
	}
}
sub wildcard         ($) {
	# quote meta characters coming in
	my $w = "\Q$_[0]\E"; # makes <*> -> <\*>

	# need to find and replace quotmeta'd '\\'.'\*' now, not just '\*'
	# for each case, send to the unescape which picks which to use based
	# on the number of \s preceeding
	$w =~ s!(\\*)\1\\\?     !wc_escapes($1,'?',"\E(.)\Q")!gex;   # one character
	$w =~ s!(\\*)\1\\\*(?=.)!wc_escapes($1,'*',"\E(.*?)\Q")!gex; # non-greedy begining
	$w =~ s!(\\*)\1\\\*    $!wc_escapes($1,'*',"\E(.*)\Q")!gex;  # greedy end

	return $w;
}
sub regex_or_wild    ($) {
	my $p = shift;
	if ($p eq '*') {
		return '.+';
	}
	elsif ($p =~ /^(??{REGEX_FLAG})(.+)$/ ) {
		return $1;
	}
	else {
		return '(?i)'.wildcard($p);
	}
}
sub strip_codes      ($) { # strip color codes for print events which laden nicks with them
	my $s = shift;
	$s=~s/\cB//g;
	$s=~s/\cC\d{0,2}(?:,\d{0,2})?//g;
	$s=~s/\cG//g;
	$s=~s/\cO//g;
	$s=~s/\cV//g;
	$s=~s/\c_//g;
	return $s;
}
sub expand_macros ($$$$) {
	# m includes matches and '$' for last match
	my ($cmds, $match, $event, $user) = @_;
	my $split = '('.MACRO_CHAR.'.|'.MACRO_META.'.)';
	my $bit   = '^'.MACRO_CHAR.'(.)';
	my $meta  = '^'.MACRO_META.'(.)';
	return map { join '', map {
		if(/$bit/) { # is a macro
			# match against only non-macro char,
			# don't allow later matches to clobber actual value
			$_ = $1;
			if($_ eq MACRO_CHAR) { +MACRO_CHAR }
			# user data
			elsif(/n/) {$$user{nick}     }
			elsif(/u/) {$$user{user}     }
			elsif(/a/) {$$user{addr}     }
			elsif(/o/) {$$user{prefix}   }
			# event data
			elsif(/s/) {$$event{msg}     }
			elsif(/w/) {$$event{network} }
			elsif(/c/) {$$event{where}   }

			# captures: zero-indexed, macros start at %1, so sub. 1
			elsif(/\d/) {exists $$match[$_-1]     ? $$match[$_-1]     : ''}
			elsif(/\$/) {exists $$match[$#$match] ? $$match[$#$match] : ''}
			# color codes
			elsif(/B/) {"\cB"} # %B == \cB
			elsif(/C/) {"\cC"} # %C == \cC
			elsif(/O/) {"\cO"} # %O == \cO
			elsif(/R/) {"\cV"} # %R == \cV
			elsif(/U/) {"\c_"} # %U == \c_
			# own nick
			elsif(/m/) {get_info('nick')}
			# time/date
			elsif(/d/) {strftime('%Y/%m/%d', localtime)} # local date
			elsif(/y/) {strftime('%Y/%m/%d', gmtime   )} # zulu date
			elsif(/t/) {strftime('%H:%M:%S', localtime)} # local time
			elsif(/z/) {strftime('%H:%M:%S', gmtime   )} # zulu time
			else {''}
		}
		elsif(/$meta/) { # is a macro
			# match against only non-macro char,
			# don't allow later matches to clobber actual value
			$_ = $1;
			if($_ eq MACRO_META) { +MACRO_META }
			# user data
			elsif(/n/) {quotemeta $$user{nick}     }
			elsif(/u/) {quotemeta $$user{user}     }
			elsif(/a/) {quotemeta $$user{addr}     }
			elsif(/o/) {quotemeta $$user{prefix}   }
			# event data
			elsif(/s/) {quotemeta $$event{msg}     }
			elsif(/w/) {quotemeta $$event{network} }
			elsif(/c/) {quotemeta $$event{where}   }

			# captures: zero-indexed, macros start at %1, so sub. 1
			elsif(/\d/) {exists $$match[$_-1]     ? quotemeta $$match[$_-1]     : ''}
			elsif(/\$/) {exists $$match[$#$match] ? quotemeta $$match[$#$match] : ''}
			# color codes
			elsif(/B/) {"\\\cB"} # %B == \cB
			elsif(/C/) {"\\\cC"} # %C == \cC
			elsif(/O/) {"\\\cO"} # %O == \cO
			elsif(/R/) {"\\\cV"} # %R == \cV
			elsif(/U/) {"\\\c_"} # %U == \c_
			# own nick
			elsif(/m/) {quotemeta get_info('nick')}
			# time/date
			elsif(/d/) {quotemeta strftime('%Y/%m/%d', localtime)} # local date
			elsif(/y/) {quotemeta strftime('%Y/%m/%d', gmtime   )} # zulu date
			elsif(/t/) {quotemeta strftime('%H:%M:%S', localtime)} # local time
			elsif(/z/) {quotemeta strftime('%H:%M:%S', gmtime   )} # zulu time
			else {''}
		} else {$_} # is not a macro
	} split /$split/ } @$cmds;
}
sub cmd_tdb              { # for /tdb, pass it on with params
	my $unload = 0;
	my $quiet = 0;
	my $i = 1;
	while (defined $_[0][$i]) {
		my $param = lc $_[0][1];
		$unload = 1 if ($param eq 'off' || $param eq 'unload');
		$quiet = 1 if ($param eq 'quiet');
		$i++;
	}
	hookage($quiet, $unload);
	return EAT_ALL;
}
sub hookage              { # get full conf path, attempt to load it, hook or unhook event
	my ($quiet, $unload) = @_;
	my $conffile = get_info('xchatdir');
	$conffile =~ s!\\+!/!g; # de-windows-ize it if necessary
	$conffile =~ s!/$!!; # remove ending slash to prevent doubling up, just in case
	$conffile .= '/'.CONF_FILE;

	if( !$unload && ($patterns = load_conf($conffile)) )
	{
		if( not @privmsg_hooks )
		{
			push @privmsg_hooks, hook_print('Channel Message',           \&hdl_chan, { data => (MASK_MESSAGE | MASK_NORMAL ) });
			push @privmsg_hooks, hook_print('Channel Msg Hilight',       \&hdl_chan, { data => (MASK_MESSAGE | MASK_HILIGHT) });
			push @privmsg_hooks, hook_print('Channel Action',            \&hdl_chan, { data => (MASK_ACTION  | MASK_NORMAL ) });
			push @privmsg_hooks, hook_print('Channel Action Hilight',    \&hdl_chan, { data => (MASK_ACTION  | MASK_HILIGHT) });
			push @privmsg_hooks, hook_print('Private Message',           \&hdl_priv, { data => MASK_MESSAGE });
			push @privmsg_hooks, hook_print('Private Message to Dialog', \&hdl_priv, { data => MASK_MESSAGE });
			push @privmsg_hooks, hook_print('Private Action',            \&hdl_priv, { data => MASK_ACTION  });
			push @privmsg_hooks, hook_print('Private Action to Dialog',  \&hdl_priv, { data => MASK_ACTION  });
		}
		if( not defined $who_rate_hook )
		{
			$who_rate_hook = hook_server('263', \&who_rate_limited);
		}
		prnt($PREFIX.'Config loaded, events hooked.') if not $quiet;
	}
	else
	{
		if( @privmsg_hooks )
		{
			unhook($_) for @privmsg_hooks; # unhook all
			@privmsg_hooks = (); # set it to empty
			unhook($who_rate_hook); # stop watching for 263
			undef($who_rate_hook); # and undef
		}
		if ($unload) {
			prnt($PREFIX.'Config unloaded, hooks removed');
		}
		else {
			prnt($PREFIX."\02Error\02: Config unable to load. Events not hooked.");
		}
	}
}

__END__
