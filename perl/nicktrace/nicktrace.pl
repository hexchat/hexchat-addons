# Name: DMS-Nick-Trace
# Version: 1.6.3
# Original Source: http://www.electronic-culture.de/projects_xchat/nicktrace.html 
# Description: Logs user's hostmasks when they join a channel, adding them to a database, 
#    which allows for quick referencing if they happen to change their nick a lot.
#    Outputs by one of three methods: Join message (mentions alternative nicks after
#    the current), notice, or server notice. See line 34 for these and other 
#    user-customizable options.
# NOTE: If using *nix, please visit line 43 and change "\\hostmasks.db" to "/hostmasks.db".
#    This is an unfortunate issue with the way this script was originally created.
# Commands: /NickTrace NICK - Checks the database for the nick specified (must be in the channel).
#    /NickTrace_add NICK IDENT HOST/IP - Adds the specified nick to the database.

# Original changelog can be viewed at http://www.electronic-culture.de/projects_xchat/files/nicktrace.changelog.txt

# Changelog:
# 1.6.3: Use HexChat API; further cleanup
# 1.6.2: Handle ZNC playback with the buffextras module sanely
# 1.6.1: Clean up code, add description, add Xchat import

use warnings;

my $sname="DMS-Nick-Trace";
my $version="1.6.3";

HexChat::register($sname, $version, "Tracks nick changes.");

HexChat::print "\n\n\00312.::  $sname ::.\003\n";
HexChat::print "\00312:::  Version $version  :::\003\n";
HexChat::print "\00312:::    © DMS '05, '15    :::\003\n\n";

my $hostmasks=HexChat::get_info("configdir");

# BEGIN USER-CONFIGURABLE OPTIONS

my $outputType=1; #0=Join Message, 1=Notice, 2=Server Notice
# $autoAdd: set this value to 0 if you don't want to add nicks to db on join
my $autoAdd=1; 
# $minMEE: how many percent at the end of the hostmask must match to be handled as same hostmask 
# (0 = don't check, 100 = must be equal)
my $minMEE=50; 

$hostmasks="$hostmasks\\hostmasks.db"; #change \\ to / for *nix

# END USER-CONFIGURABLE OPTIONS

HexChat::hook_print('Join', 'joinHandler',{help_text => 'handles nickchanges'});
HexChat::hook_server('NICK','nickHandler',{help_text => 'handles joins'});
HexChat::hook_command('NickTrace','nicktraceHandler',{help_text => 'Check for aliases for given nick'});
HexChat::hook_command('NickTrace_add','nicktraceAddHandler',{help_text => 'Usage: /NickTrace_add NICK IDENT HOST/IP'});

sub readFile{
	$path=shift(@_);
	if (!open(DB, "<","$path")){
		HexChat::print("File not found: $path");return "";
	}
	@stats=stat(DB);
	my $data;
	read (DB,$data,$stats[7]);
	close (DB);
	return $data;
}

sub nicktraceHandler{
	$nick=$_[0][1];
	if (!$nick){
		HexChat::print("You have to give nick as argument");
		return HexChat::EAT_ALL;
	}
	my $data=HexChat::user_info("$nick");
	if (!$data){
		HexChat::print("Invalid user");
		return HexChat::EAT_ALL;
	}
	$host=$data->{"host"};
	@parts=split("@",$host);
	$akas=checkAlias($nick,$parts[0],$parts[1]);
	HexChat::printf("$nick$akas");
	return HexChat::EAT_ALL;
}


sub checkAlias{
	$nick=shift(@_);
	$ident=shift(@_);
	$hostmask=shift(@_);
	$aliases="";
	foreach $line (split "\n", readFile($hostmasks)){
		my($n, $i, $h)=(split "=", $line);
		if (($i eq $ident)||($h eq $hostmask)){
			if ($n ne $nick){
				if (($i eq $ident)&&(mee($h, $hostmask)>=$minMEE)){
					$aliases="$aliases aka. $n" if (index($aliases,"aka. $n")==-1);
				}
			}
		}
	}
	return $aliases;
}

sub addAlias{
	$nick=shift(@_);
	$ident=shift(@_);
	$hostmask=shift(@_);
	$db=readFile($hostmasks);
	open(DB, ">$hostmasks");
	foreach $line(split "\n", $db){
		my($n,$i, $h)=(split "=", $line);
		print DB "$n=$i=$h\n" if (($n ne $nick)||($i ne $ident)||($h ne $hostmask));
	}
	print DB "$nick=$ident=$hostmask\n";
	close(DB);
}

sub nicktraceAddHandler{
	addAlias($_[0][1],$_[0][2],$_[0][3]);
	HexChat::print("Added to hostmask.db");
	return HexChat::EAT_ALL;
}

sub joinHandler{
	$mask=$_[0][2];
	$nick=$_[0][0];
	$chan=$_[0][1];
	if (index($nick,"\002\002")==0){
		return HexChat::EAT_NONE;
	}
	@parts2=split("@",$mask);
	$ident=$parts2[0];
	$hostmask=$parts2[1];
	if (!$hostmask) { 
		return HexChat::EAT_NONE; 
	}
	$alias=checkAlias($nick,$ident,$hostmask);
	&addAlias($nick,$ident,$hostmask)if ($autoAdd==1);
	if ($outputType==0){ #join message
		my @ret=();
		push(@ret,"\002\002$nick$alias");
		push(@ret,$chan);
		push(@ret,"$mask");
		$rVal=HexChat::emit_print('Join',@ret);
		if ($rVal!=1){ #emit_print fails (why ever)
			HexChat::print("emit_print failed (returned $rVal)");
			HexChat::print("\002$nick$alias\002 ($mask) has joined $chan");
		}
		return HexChat::EAT_ALL;
	}
	if ($outputType==1){ #notice
		my @ret=();
		push(@ret,"nickTrace");
		push(@ret,"\002\002$nick$alias");
		HexChat::set_context("(notices)");
		$rVal=HexChat::emit_print('Notice',@ret);
		if ($rVal!=1){ #emit_print fails (why ever)
			HexChat::print("emit_print failed (returned $rVal)");
		}
	}
	if ($outputType==2){ #server notice
		my @ret=();
		push(@ret,"\002\002$nick$alias");
		push(@ret,"nickTrace");
		HexChat::set_context("(snotices)");
		$rVal=HexChat::emit_print('Server Notice',@ret);
		if ($rVal!=1){ #emit_print fails (why ever)
			HexChat::print("emit_print failed (returned $rVal)");
		}
	}
	
	return HexChat::EAT_NONE;
}

sub nickHandler{
	$mask=$_[0][0];
	$nick=substr($_[0][2],1);
	@parts1=split("!",$mask);
	@parts2=split("@",$parts1[1]);
	$ident=$parts2[0];
	$hostmask=$parts2[1];
	if (!$hostmask) { 
		return HexChat::EAT_NONE; 
	}
	addAlias($nick,$ident,$hostmask);
	return HexChat::EAT_NONE;
}

sub mee{
    my $mask1=uc(shift(@_));
	my $mask2=uc(shift(@_));
	my $maxLen; 
	my $minLen;
    if (length($mask1)>length($mask2)){
		$maxLen=length($mask1);
		$minLen=length($mask2);
	}
    else {
		$maxLen=length($mask2);
		$minLen=length($mask1);
	}
    for ($i=1;$i<=$minLen;$i++){
		return int(($i-1)*100/$maxLen) if (substr($mask1,length($mask1)-$i) ne substr($mask2,length($mask2)-$i));
	}
    return 100;
}
