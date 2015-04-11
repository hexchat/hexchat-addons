# Author:		xnite <xnite@AfraidIRC.net>
# Author Home:	http://xnite.me
# Description:	Adds commands and functions especially useful for IRCops. Tested on Charybdis, I cannot guarantee that all of the commands will work for all IRCd's.
# Feedback:		Please send feedback to me at xnite@AfraidIRC.net & prepend the email subject line with [OperBuddy].
#
# LICENSE
# This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

package IRC::XChat::OperBuddy;
use strict;
our $version=1.0;
Xchat::register( "OperBuddy", $version, "Provides useful functions for IRCops", "");
Xchat::hook_print('Open Dialog', "whois_on_query");
Xchat::hook_server('382', 'server_rehash');
Xchat::hook_server('WALLOPS', 'show_wallops');
Xchat::hook_command('operbuddy', 'operbuddy_commands');
Xchat::hook_command('setawaymsg', 'operbuddy_set_away_message');
Xchat::hook_command('useautoaway', 'operbuddy_set_use_away_message');
Xchat::hook_server('NOTICE', 'operbuddy_snotice');
Xchat::hook_server('216', 'stats_g');
Xchat::hook_server('709', 'operbuddy_global_invite_process');
Xchat::hook_command('ginvite', 'operbuddy_global_invite_command');
Xchat::hook_command('reroute', 'operbuddy_reroute');
Xchat::hook_command('closechan', 'operbuddy_closechan');

Xchat::print("\002[OperBuddy]\002 Loaded OperBuddy v".$version." by xnite <xnite\@AfraidIRC.net>.");
if(!defined(Xchat::plugin_pref_get('OperBuddy_away_message'))) {
	Xchat::print("\002[OperBuddy]\002 No away message set, you can set one with '/operbuddy set away_message', or leave it default.");
	Xchat::plugin_pref_set('OperBuddy_away_message', '[AutoReply]: I am currently away, please be patient until I return. If you need help please join #help');
}
if(!defined(Xchat::plugin_pref_get('OperBuddy_use_away_message'))) {
	Xchat::print("\002[OperBuddy]\002 Activating use_away_message, you can change this setting with '/operbuddy set use_away_message'");
	Xchat::plugin_pref_set('OperBuddy_use_away_message', 1);
}
if(!defined(Xchat::plugin_pref_get('OperBuddy_away_message'))) {
	Xchat::print("\002[OperBuddy]\002 Activating whois_on_query, you can change this setting with '/operbuddy set whois_on_query'");
	Xchat::plugin_pref_set('OperBuddy_away_message', '[AutoReply]: I am currently away, please be patient until I return. If you need help please join #help');
}

sub operbuddy_reroute {
	if(defined($_[0][2])) {
		Xchat::print("\002[OperBuddy]\002 Re-Routing server ".$_[0][1]." to ".$_[0][2]."\n");
		Xchat::command("SQUIT ".$_[0][1]." rerouting to ".$_[0][2]);
		sleep(1);
		Xchat::command("CONNECT ".$_[0][1]." 0 ".$_[0][2]);
		Xchat::print("\002[OperBuddy]\002 Re-Routed server ".$_[0][1]." to ".$_[0][2]."\n");
	} else {
		Xchat::print("\002[OperBuddy]\002 Please provide the names of the servers you would like rerouted.\n");
	}
}

sub operbuddy_closechan {
	if(defined($_[0][2])) {
		Xchat::print("\002[OperBuddy]\002 Redirecting closed channel, ".$_[0][1].", to ".$_[0][2]."\n");
		Xchat::command("MODE ".$_[0][1]." +fpis ".$_[0][2]);
		if(defined($_[0][3])) {
			Xchat::command("PRIVMSG OperServ :CLEARCHAN KICK ".$_[0][1]." ".$_[1][3]);
		} else {
			Xchat::command("PRIVMSG OperServ :CLEARCHAN KICK ".$_[0][1]." This channel is being closed. Please join ".$_[0][2]." instead.");
		}
		Xchat::print("\002[OperBuddy]\002 Re-Routed server ".$_[0][1]." to ".$_[0][2]."\n");
	} else {
		Xchat::print("\002[OperBuddy]\002 Usage: /closechan <channel> <redirect-channel> \[Reason\]\n");
	}
}

sub operbuddy_global_invite_command {
	if(defined($_[0][1])) {
		Xchat::plugin_pref_set('OperBuddy_global_invite', 1);
		Xchat::plugin_pref_set('OperBuddy_global_invite_channel', $_[0][1]);
		Xchat::command("QUOTE MASKTRACE !*!*@*");
		Xchat::print("\002[OperBuddy]\002 Sending out Global Invites, this may take a while.");
	} else {
		Xchat::print("\002[OperBuddy]\002 Please specify a channel.");
	}
	Xchat::EAT_ALL;
}
sub operbuddy_global_invite_process {
	if(Xchat::plugin_pref_get('OperBuddy_global_invite') == 1) {
		Xchat::command("INVITE ".$_[0][5]." ".Xchat::plugin_pref_get('OperBuddy_global_invite_channel'));
		Xchat::EAT_ALL;
	}
}

sub whois_on_query {
	if(Xchat::get_info('channel') !~ /OpBud:/i) {
		if(Xchat::plugin_pref_get('OperBuddy_whois_on_query') == 1) {
			Xchat::command("QUERY ".Xchat::get_info('channel'));
			Xchat::command("WHOIS ".Xchat::get_info('channel'));
			if(Xchat::plugin_pref_get('OperBuddy_use_away_message') == 1) {
				if(defined(Xchat::get_info('away'))) {
					Xchat::command("TIMER .5 MSG ".Xchat::get_info('channel')." ".Xchat::plugin_pref_get('OperBuddy_away_message'));
				}
			}
		}
	}
	return Xchat::EAT_ALL;
}
sub server_rehash {
	my $server	= substr $_[0][0], 1;
	my $message	= $_[0][3];
	Xchat::print("\002[OperBuddy]\002 ".$server.":\t\t".$message."\n");
	return Xchat::EAT_ALL;
}

sub show_wallops {
	my $who		= substr $_[0][0], 1;
	my $message	= substr $_[1][2], 1;
	my $nick	= Xchat::get_info('nick');
	Xchat::command("RECV :OpBud:WALLOPS!null\@null PRIVMSG ".$nick." :".$message);
	return Xchat::EAT_ALL;
}

sub operbuddy_commands {
	my $command = $_[0][1];
	if(!defined($command)) {
		Xchat::print("\002-- OperBuddy Help --\002\n");
		Xchat::print("\002enabled\002\t\t\tView which features of OperBuddy you have enabled.\n");
		Xchat::print("\002set\002\t\t\t\tChange OperBuddy settings (see README for more info).\n");
		Xchat::print("\002--end of help--\002\n");
	} elsif(defined($command)) {
		if($command eq 'set') {
			my $key		= $_[0][2];
			my $value	= $_[1][3];
			if($key eq 'away_message'
				|| $key eq 'use_away_message'
				|| $key eq 'whois_on_query'
				|| $key eq 'global_invite'
				|| $key eq 'show_full_server_name'
				|| $key eq 'netsplit_audio_file'
			) {
				if($key eq 'use_away_message'
					|| $key eq 'whois_on_query'
					|| $key eq 'global_invite'
					|| $key eq 'show_full_server_name'
				) {
					if($value != 0 && $value != 1) {
						Xchat::print("\002[OperBuddy]\002 Value must be a 1 or 0!");
					} else {
						if(Xchat::plugin_pref_set('OperBuddy_'.$key, $value) == 1) {
							Xchat::print("\002[OperBuddy]\002 Set ".$key." to ".$value);
						} else {
							Xchat::print("\002[OperBuddy]\002 Could not apply settings. Please email xnite\@AfraidIRC.net if you continue having this issue.");
						}
					}
				} else {
					if(Xchat::plugin_pref_set('OperBuddy_'.$key, $value) == 1) {
						Xchat::print("\002[OperBuddy]\002 Set ".$key." to ".$value);
					} else {
						Xchat::print("\002[OperBuddy]\002 Could not apply settings. Please email xnite\@AfraidIRC.net if you continue having this issue.");
					}
				}
			} else {
				Xchat::print("\002[OperBuddy]\002 Setting, '".$key."', does not exist.");
			}
		}
		if($command eq 'settings') {
			if(Xchat::plugin_pref_get('OperBuddy_whois_on_query') == 1) { Xchat::print("\002[OperBuddy]\002 Whois on Query: Enabled\n"); } else { Xchat::print("\002[OperBuddy]\002 Whois_on_Query: Disabled\n"); }
			if(Xchat::plugin_pref_get('OperBuddy_use_away_message') == 1) {
				Xchat::print("\002[OperBuddy]\002 Away Reply: Enabled\n");
				Xchat::print("\002[OperBuddy]\002 Your Reply: \"".Xchat::plugin_pref_get('OperBuddy_away_message')."\"");
			} else { Xchat::print("\002[OperBuddy]\002 Away Reply: Disabled"); }
		}
	} else {
		Xchat::print("\002[OperBuddy]\002 Unknown Error!");
	}
	Xchat::EAT_ALL;
}

sub operbuddy_snotice {
	my $me			= $_[0][2];
	our $server;
	if(Xchat::plugin_pref_get('OperBuddy_show_full_server_name') == 1) {
		our $server			= substr $_[0][0], 1;
	} else {
		my @server_array	= split(/\./, substr $_[0][0], 1);
		our $server			= $server_array[0];
	}
	my $message		= $_[1][3];
	my $nick		= Xchat::get_info('nick');
	if($me eq '*') {
		if($message =~ /\*\*\* Notice \-\- Netsplit/i) {
			Xchat::command("RECV :OpBud:Links!null\@null PRIVMSG ".$nick." :".$_[1][6]);
			if(defined(Xchat::plugin_pref_get('OperBuddy_netsplit_audio_file'))) {
				Xchat::command('SPLAY '.Xchat::plugin_pref_get('OperBuddy_netsplit_audio_file'));
			}
			Xchat::EAT_ALL;
		} elsif($message =~ /split from/i) {
			Xchat::command("RECV :OpBud:Links!null\@null PRIVMSG ".$nick." :\00304".$_[1][6]."\003");
			Xchat::command("GUI SHOW");
			Xchat::command("GUI FOCUS");
			#sleep(1);
			#This has been getting rather annoying.
			#Xchat::command("GUI MSGBOX \"".$_[1][6]."\"");
			Xchat::EAT_ALL;
		} elsif($message =~ /being introduced by/i) {
			Xchat::command("RECV :OpBud:Links!null\@null PRIVMSG ".$nick." :".$_[1][6]);
			Xchat::EAT_ALL;
		} elsif($message =~ /Netjoin/i) {
			Xchat::command("RECV :OpBud:Links!null\@null PRIVMSG ".$nick." :".$_[1][6]);
			Xchat::EAT_ALL;
		} elsif($message =~ /\*\*\* Notice \-\- Client exiting/i) {
			Xchat::command("RECV :OpBud:Clients!null\@null PRIVMSG ".$nick." :\00304".$_[1][8]."\003");
			Xchat::EAT_ALL;
		} elsif($message =~ /\*\*\* Notice \-\- Client connecting/i) {
			Xchat::command("RECV :OpBud:Clients!null\@null PRIVMSG ".$nick." :\00303".$_[1][8]."\003");
			Xchat::EAT_ALL;
		} elsif($message =~ /Listed on DNSBL/i) {
			Xchat::command("RECV :OpBud:Clients!null\@null PRIVMSG ".$nick." :".$_[1][6]);
			Xchat::EAT_ALL;
		} else {
			Xchat::command("RECV :OpBud:SNotice!null\@null PRIVMSG ".$nick." :<".$server."> ".$_[1][6]);
			Xchat::EAT_ALL;
		}
	}
}

sub stats_g {
	my $nick		= Xchat::get_info('nick');
	my $ip			= $_[0][4];
	my $username	= $_[0][6];
	my @string		= split(/\|/, substr $_[1][7], 1);
	my $reason		= $string[0];
	my $setter		= $string[1];
	Xchat::command("RECV :OpBud:Bans!null\@null PRIVMSG ".$nick." :\002Global K:Line for ".$username."\@".$ip."\002");
	Xchat::command("RECV :OpBud:Bans!null\@null PRIVMSG ".$nick." :\t\t\t\t\002Reason:\002\t".$reason);
	Xchat::command("RECV :OpBud:Bans!null\@null PRIVMSG ".$nick." :\t\t\t\t\002Set By:\002\t".$setter);
	Xchat::EAT_ALL;
}


sub stats_k {
	my $nick		= Xchat::get_info('nick');
	my $ip			= $_[0][4];
	my $username	= $_[0][6];
	my @string		= split(/\|/, substr $_[1][7], 1);
	my $reason		= $string[0];
	my $setter		= $string[1];	
	Xchat::command("RECV :OpBud:Bans!null\@null PRIVMSG ".$nick." :\002Global K:Line for ".$username."\@".$ip."\002");
	Xchat::command("RECV :OpBud:Bans!null\@null PRIVMSG ".$nick." :\t\t\t\t\002Reason:\002\t".$reason);
	Xchat::command("RECV :OpBud:Bans!null\@null PRIVMSG ".$nick." :\t\t\t\t\002Set By:\002\t".$setter);
	Xchat::EAT_ALL;
}