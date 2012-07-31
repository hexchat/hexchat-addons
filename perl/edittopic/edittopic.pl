use strict;
use warnings;
#!/usr/bin/perl
#
# Name:		edittopic.pl
# Version:	1.3
# Author:	LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:		2006-04-01
# Description:	Change the input field to the current topic, including color codes

# Changelog:
# - 1.3 2008-03-31 - Replace Raw useage with Quote
# - 1.2 2006-05-29 - Had to work around change made somewhere in CVS that was giving an error
# - 1.1 2006-04-01 - Just made a bit more strict and minor bug edit
# - 1.0 2005-12-15 - Nothing Changed, just bumped version because I hate to leave it
# - 0.1 2005-10-27 - Initial code written for someone on #xchat

Xchat::register("Edit Topic", "1.3", "Allows simple topic changes that preserve color codes");
Xchat::print "Loading Edit Topic 1.3";

Xchat::hook_command("edittopic", \&edit_topic, {
	help_text => 'Usage: edittopic, Changes inputbox to channel topic with color codes'
	});

for my $event ('Topic', 'Topic Change', 'Topic Creation') {
	Xchat::hook_print($event, \&catch_topic, { data => $event });
}

my $channel = '';
my $topic = '';
my $context = 0;
my $time = '';

sub edit_topic {
	if ($topic ne '' && $context == Xchat::get_context()) {
		my $commandchar = Xchat::get_prefs('input_command_char');
		Xchat::command("settext $commandchar" . "topic $topic");
		$context = 0;
		$channel = $topic = '';
	}
	else {
		$channel = Xchat::get_info('channel');
		$context = Xchat::get_context();
		$time = time();

		Xchat::command("quote TOPIC $channel");
	}
	return Xchat::EAT_ALL;
}

sub catch_topic {
	if (($_[0][0] eq $channel || ($_[1] eq "Topic Change" && $_[0][2] eq $channel))
		&& Xchat::get_context() == $context) {
		if ($_[1] ne 'Topic Creation') {
			if (Xchat::get_info('inputbox') eq '') {
				my $commandchar = Xchat::get_prefs('input_command_char');
				Xchat::command("settext $commandchar" . "topic $_[0][1]");
			}
			else {
				Xchat::emit_print('Generic Message', '*Info*', 'Your topic is waiting to be changed, please type ' . Xchat::get_prefs('input_command_char') . 'edittopic again');
				$topic = $_[0][1];
			}
		}
		elsif ($topic eq '') {
			$channel = '';
			$context = 0;
		}
		if (time() - $time < 20 && $_[1] ne 'Topic Change') { return Xchat::EAT_ALL; }
	}
}