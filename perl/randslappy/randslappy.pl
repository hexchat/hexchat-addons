# Name:        randslappy.pl
# Version:     0.7
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2011-07-19
# Description: Random !slap script, uses configuration to define different triggers
#              (!slap, !stab, !eat, etc.) for different channels

# Version History
# 0.1  2008-06-26 Initial Version
# 0.2  2008-07-27 More Efficient loading, allow for more prefixes, %o may be used multiple
#			times with multiple random lines, allow macros to be in objects file, option
#			for shorter commands, more variance to flood protection
# 0.3  2008-11-09 Fixed objects not having the macros replaced
# 0.4  2009-03-04 fix problem with = in a slappy command, add -throttle option for /slappy
#			Reloadable configuration, EAT_XCHAT instead of EAT_ALL, flexible +/-channel
# 0.5  2009-03-06 Well that was a stupid mistake when I put in that variable...
# 0.6  2009-09-30 Make /slappy the last slappy event to show up on /sl<tab>
#			Fix wrong error message
# 0.7  2011-07-19 Allow randomness in command line: %r{choice one}{choice two}
#				After the %r, group options by surrounding them with {}s. To have a } as
#				part of a choice, use \} instead
#				Example: %r{choice one}{choice two}{choice\}three}
#			Fix case where only prefix is typed in channel

use warnings;
use strict;
use Xchat qw( :all );

my $NAME    = 'Rand Slappy';
my $VERSION = '0.7';

register($NAME, $VERSION, 'Configurable random slap script which handles multiple triggers');
prnt("Loading $NAME $VERSION");

# hook before the conf is loaded, for tab order
hook_command('slappyreload', \&reload_conf, { help_text => "slappyreload, reload the $NAME configuration file" });

my @floodtrack = ();
my %alreadynoticed;

my @hookedcommands = ();

my $PREFIX = '!';

my $config = {};
load_conf();

foreach my $event ('Channel Message', 'Channel Msg Hilight', 'Your Message') {
	hook_print($event, \&check_message);
}

sub check_message {
	# Start out with a few escape cases
	return EAT_NONE unless ( $_[0][1] =~ /^\Q$PREFIX\E./ ); #only continue if starts with $PREFIX
	return EAT_NONE unless ( get_info('server') ); # returns undef if not connected, error correction

	my ($trigger, $target) = ($_[0][1] =~ m/^\Q$PREFIX\E(\w+)(?:\s+(.*))?/);

	my $channel = lc ( get_info('channel') . '/' . get_info('network') );

	my $cando = 0;

	$trigger = lc $trigger;

	# Loop through %conf to determine if command is valid for this particular channel
	if ($config->{triggers}{$trigger} && $config->{triggers}{$trigger}{command}) {
		foreach (@{ $config->{triggers}{$trigger}{positive} }) {
			if ( $channel =~ m!$_! ) { $cando = 1; last; }
		}
		if ($cando) {
			foreach (@{ $config->{triggers}{$trigger}{negative} }) {
				if ( $channel =~ m!$_! ) { $cando = 0; last; }
			}
		}
	}
	return EAT_NONE unless $cando;

	# This section is flood protection, but only to be run if $PERMINUTE is not 0
	if ($config->{perunit}) {
		my $pos = my $count = 0;
		while ($pos < scalar(@floodtrack)) {
			my ($f_chan, $f_time) = split(/ /,$floodtrack[$pos]);
			if ($f_time < time() - $config->{timeunit}) {
				splice(@floodtrack, $pos, 1);
			}
			else {
				$count++ if $f_chan eq $channel;
				$pos++;
			}
		}
		if ($count >= $config->{perunit}) {
			my $who_triggered = strip_code($_[0][0]);

			# Only notice the user 1 time per limit reached
			unless ( exists $alreadynoticed{$channel} && $alreadynoticed{$channel} =~ / $who_triggered / ) {
				if ( exists $alreadynoticed{$channel} ) {
					$alreadynoticed{$channel} .= " $who_triggered ";
				}
				else {
					$alreadynoticed{$channel} = " $who_triggered ";
				}

				my $error_notice;
				if ($config->{timeunit} == 60) {
					$error_notice = "Sorry, the random trigger has already been used $config->{perunit} times this minute";
				}
				elsif ($config->{timeunit} % 60 == 0) {
					$error_notice = 'Sorry, the random trigger has already been used ' . $config->{perunit} .
							' timers in the last ' . ($config->{timeunit} / 60) . ' minutes';
				}
				else {
					$error_notice = "Sorry, the random trigger has already been used $config->{perunit} times in the last $config->{timeunit} seconds";
				}
				command("raw NOTICE $who_triggered :$error_notice");
				
			}

			return EAT_NONE;
		}
		else {
			push @floodtrack, $channel.' '.time();
			delete $alreadynoticed{$channel} if ( exists $alreadynoticed{$channel} ); # reset individual notice list
		}
	} #Flood protection over

	$target = strip_code($_[0][0]) if (!$target);
	$target =~ s/\s+$//; #Trim end, original regex trimmed begining

	# Ok, Pick the command randomly
	my $command = @{ $config->{triggers}{$trigger}{command} }[rand(@{ $config->{triggers}{$trigger}{command} })];

	delaycommand(macro_replace($command, strip_code($_[0][0]), $target));

	return EAT_NONE;
}

sub slappy_command {
	unless ( $_[0][1] ) {
		my $message = "TYPE of slap not provided, ussage: \cB/slappy <type> [-throttle] [<target>]\cB where type: " . valid_types();
		emit_print('Generic Message', "*$NAME*", $message);
		return EAT_XCHAT;
	}
	shift @{$_[0]};
	my $trigger = lc shift(@{$_[0]});

	unless ($config->{triggers}{$trigger} && $config->{triggers}{$trigger}{command}) {
		# TODO: add check for command here
		my $message2 = "Type \cB$trigger\cB is not valid. Valid types: " . valid_types();
		emit_print('Generic Message', "*$NAME*", $message2);
		return EAT_XCHAT;
	}

	# Check to see if -throttle is used for calling limit function
	my $throttle = ("-throttle" eq lc $_[0][0] ? 1 : 0);
	shift @{$_[0]} if $throttle;

	# Fill in some throttle stuff now
	if ($throttle && $config->{perunit}) {
		my $channel = lc ( get_info('channel') . '/' . get_info('network') );
		my $pos = my $count = 0;
		while ($pos < scalar(@floodtrack)) {
			my ($f_chan, $f_time) = split(/ /,$floodtrack[$pos]);
			if ($f_time < time() - $config->{timeunit}) {
				splice(@floodtrack, $pos, 1);
			}
			else {
				$count++ if $f_chan eq $channel;
				$pos++;
			}
		}
		if ($count >= $config->{perunit}) {
			return EAT_XCHAT;
		}
		else {
			push @floodtrack, $channel.' '.time();
			delete $alreadynoticed{$channel} if ( exists $alreadynoticed{$channel} ); # reset individual notice list
		}
	} # throttle check over

	my $target = (scalar $_[0] ? join(' ',@{$_[0]}) : get_info('nick'));
	$target =~ s/\s+$//; #Trim end, I don't see how begining would need

	# strip the trarget and get rid of many non printable characters
	$target = strip_code($target);
	$target =~ s/[\x01-\x1F]//g;

	# Ok, Pick the command randomly
	my $command = @{ $config->{triggers}{$trigger}{command} }[rand(@{ $config->{triggers}{$trigger}{command} })];

	delaycommand(macro_replace($command, get_info('nick'), $target));

	return EAT_XCHAT;
}

# called when creating an alias
sub slappy_short {
	command('slappy ' . $_[2] . ($_[1][1] ? ' '.$_[1][1] : ''));
	return EAT_XCHAT;
}

# Function used in help messages to show valid types of slaps for /slappy
sub valid_types {
	my @validkeys = ();

	foreach my $key (keys %{ $config->{triggers} }) {
		push(@validkeys, $key) if ( $config->{triggers}{$key}{command} );
	}

	return join(', ', @validkeys);
}

sub load_conf {
	$config->{dir} = get_info('xchatdir');
	$config->{perunit} = 0;
	$config->{timeunit} = 60;
	$config->{objects} = "$config->{dir}/randobjects.txt";

	my $trigger;
	my $message;
	my @makeshort;

	open (DATA, '<', $config->{dir}.'/randslappy.conf') or do {
		unless (-e $config->{dir}.'/randslappy.conf') {
			$message = 'Configuration file does not exist. Please create randslappy.conf in the configuration directory.';
		}
		elsif ( !(-r $config->{dir}.'/randslappy.conf') ) {
			$message = "Unable to read \002$config->{dir}/randslappy.conf\002. Please make sure you have proper permission for this file.";
		}
		else {
			$message = "Unknown problem encountered reading \002$config->{dir}/randslappy.conf\002.";
		}

		emit_print('Generic Message', "*$NAME*", $message);
		return;
	};

	while (<DATA>) {
		s/\s*$//;
		s/^\s*//;
		last if (/^__END__$/);
		next if (/^$/);

		my ($cmd, @line);
		($cmd, $_) = split(/=\s*/,$_,2);
		@line = split(/\s+/) if $_;

		$cmd = lc $cmd;

		if ($cmd eq 'prefix' && $line[0]) {
			$PREFIX = $line[0];
		}
		elsif ($cmd eq 'trigger' && $line[0]) {
			$trigger = $line[0];
		}
		elsif ($cmd eq 'perminute' || $cmd eq 'pertimeunit') {
			if ( $line[0] && int($line[0]) ) {
				$config->{perunit} = int($line[0]);
			}
		}
		elsif ($cmd eq 'timeunit') {
			if ( $line[0] && int($line[0]) ) {
				$config->{timeunit} = int($line[0]);
			}
		}
		elsif ($trigger) {
			if ($cmd eq '+channel') {
				for (split(/,\s*/,$_)) {
					push ( @{ $config->{triggers}{$trigger}{positive} }, format_channel($_) );
				}
			}
			elsif ($cmd eq '-channel') {
				for (split(/,\s*/,$_)) {
					push ( @{ $config->{triggers}{$trigger}{negative} }, format_channel($_) );
				}
			}
			elsif ($cmd eq 'command') {
				push ( @{ $config->{triggers}{$trigger}{command} }, (trim($_)) );
			}
			elsif ($cmd eq 'makesimple') {
				if ($line[0] =~ /^(?:y|o|t|1)/i) {
					push (@makeshort, $trigger);
				}
			}
		}
	}
	close DATA;

	# hook slappy and place in the hooked commands, here so the list gets updated
	push (@hookedcommands, hook_command('slappy', \&slappy_command, { help_text => 'SLAPPY <type> [<target>], Perform Slappy Type on target, where TYPE is one of: ' . valid_types() } ));

	# add the short slappys after the main one for tab order of /sl<tab>
	foreach $trigger (@makeshort) {
		push (@hookedcommands, hook_command('s'.$trigger, \&slappy_short, {
			data => $trigger,
			help_text => 'S'.uc($trigger).' [-throttle] [<target>], Perform Slappy '.$trigger.' on target'
		} ));
	}

	return;
}

sub reload_conf {
	# Unhook any short commands
	foreach (@hookedcommands) {
		unhook($_);
	}
	# wipe what we just unhooked
	@hookedcommands = ();

	# wipe the config so it can be....
	$config = {};
	# reloaded
	load_conf();
	prnt("Re-loaded $NAME $VERSION configuration");

	return EAT_XCHAT;
}

sub format_channel {
	$_[0] = lc $_[0];
	$_[0] =~ s/\*/[^ ]*/;
	my ($channel, $network) = split(/\//, trim($_[0]), 2);
	$network = '[^ ]+' unless ($network);

	return ("$channel/$network");
}

sub get_random; # needed because of compile time issue
sub get_random {
	my $line;

	open (RAND, "<$config->{objects}") or (emit_print('Generic Message', "*$NAME*", "Cannot open file: $config->{objects}"));
	rand($.) < 1 && ($line = $_) while <RAND>; # Gets the Random Line
	close(RAND);
	$line = trim($line);

	# replace any %o in the line with another random object
	$line =~ s/\%o/get_random/eg;

	return $line;
}

# delay the command til after event
sub delaycommand {
	my $context = get_context();
	my $command = $_[0];
	hook_timer( 0,
		sub {
			set_context($context);
			command($command);
			return REMOVE;
		}
	); 
	return EAT_NONE;
}

# trim opening and closing whitespace
sub trim {
	my $line = $_[0];
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	return $line;
}

# Replace certain macros in the string with values, and return the compiled string
# Usage: $command = macro_replace($command, $whocalled, $target);
sub macro_replace {
	my ($cmd, $from, $target) = @_;

	#my $chan = get_info('channel');

	$cmd =~ s/\%o/get_random/eg;
	$cmd =~ s/\%t/$target/g;
	$cmd =~ s/\%n/$from/g;
	# I think it would be more efficent this way than declaring earlier as normally isn't used
	$cmd =~ s/\%c/get_info('channel')/eg;
	$cmd =~ s/\%r((?:\{.*?(?<!\\)\})+)/choose_item($1)/eg;

	return $cmd;
}

# Grab one item from the %r set
sub choose_item {
	$_ = $_[0];
	# line comes in with the {}s around full item
	s/^\{//;
	s/\}$//;
	# allow for \} to be an escaped }
	my @options = split(/(?<!\\)\}\{/, $_);
	$_ = $options[rand @options];
	s/\\\}/}/g;
	return $_;
}
