#!/usr/bin/perl
# Distributed under the terms of the GNU General Public License, v2 or later
# $Header: ~/.config/hexchat/addons/query-blocker.pl, v2.0 2022/03/30 22:12:00 $
# Blocks all msgs by default allowing only nicks from user controled whitelist

# $deny_msg is the msg sent to users not on your whitelist that msg you
$deny_msg = "User does not accept private queries. Write to him on public channel.";

HexChat::print "Query Blocker (/qbhelp for help)\n";
HexChat::register("Query Blocker","2.0","Blocking queries with whitelist","");
HexChat::hook_command("qb", "qb_cb");
HexChat::hook_command("qbadd", "adduser_cb");
HexChat::hook_command("qbdel", "deluser_cb");
HexChat::hook_command("qblist", "qblist_cb");
HexChat::hook_command("qbhelp", "qbhelp_cb");
HexChat::hook_server("PRIVMSG", "privmsg_cntl_handler");

$homedir = $ENV{'HOME'};



sub qb_cb {
my $state = $_[0][1];

if (uc $state eq 'ON' ){
    system("touch $homedir/.config/hexchat/.blocked");
    HexChat::print("Query Blocker \cBactivated\cB");
    return 1;
    } else {
    if (uc $state eq 'OFF'){
    system("rm -f $homedir/.config/hexchat/.blocked");
    HexChat::print("Query Blocker \cBdeactivated\cB");
    return 1;
    }
}
HexChat::print("Usage: /qb <ON/OFF>");
HexChat::print("Turns the Query Blocker On/Off");
if (-e "$homedir/.config/hexchat/.blocked") {
    $qb_status="Currently \cBblocking\cB private messages";
    } else {
    $qb_status="Currently \cBnot blocking\cB private messages";
    }
HexChat::print("$qb_status");
return 1;
}



sub adduser_cb {
if (!$_[0][1]) {
      HexChat::print("No username given to add!");
      return 1;
      }
$clean=$_[0][1];
chomp($clean); $clean=~ s/ //;
#  system("touch ~/.config/hexchat/.whitelist"); # Ensure .whitelist exists
open(WHITELIST, ">>$homedir/.config/hexchat/.whitelist") || die "Cannot open whitelist\n";
print WHITELIST $clean,"\n";
close WHITELIST;
HexChat::print("\cB$clean\cB added to whitelist\n");
check_whitelist();
return 1;
}



sub deluser_cb {
if (!$_[0][1]) {
    HexChat::print("No username given to delete!");
    return 1;
    }
$remove = $_[0][1];
chomp($remove);
open(WHITELIST, "<$homedir/.config/hexchat/.whitelist") || die "Cannot open whitelist\n";
@whitelist="";
while ( defined ($Ruser = <WHITELIST>)) {
     chomp($Ruser);
     if (lc($Ruser) eq lc($remove)){
        HexChat::print("\cB$Ruser\cB removed from whitelist\n");
        }
     else {
        push(@whitelist,$Ruser);
        }
    }
close WHITELIST;
open(WHITELIST, ">$homedir/.config/hexchat/.whitelist") || die "Cannot open whitelist\n";
foreach $QUser (@whitelist) {
    if($QUser eq "" || $QUser eq "\0" || $QUser eq "\n") { ;; }
    else {
    print WHITELIST $QUser, "\n";
    }
}
close WHITELIST;
check_whitelist();
return 1;
}



sub qblist_cb {
open(DATA, "$homedir/.config/hexchat/.whitelist") || die "can't open whitelist\n";
my @Whitelist;
while ( defined ($Ruser = <DATA>)) {
    chomp($Ruser);
    push(@Whitelist,$Ruser);
    }
close DATA;
HexChat::print("\cC24,18 \cB   Allowed Users    ");
foreach $Wuser (@Whitelist) {
    HexChat::print(" $Wuser");
    }
return 1;
}



sub qbhelp_cb {
HexChat::print("[Query-blocker 2.0 Help]\n");
HexChat::print("  \cB/qb <ON/OFF>\cB turns blocking on/off\n");
HexChat::print("  \cB/qblist\cB displays allowed users\n");
HexChat::print("  \cB/qbadd <nick>\cB adds <nick> to whitelist (allows msgs)\n");
HexChat::print("  \cB/qbdel <nick>\cB removes <nick> from whitelist (denys msgs)\n");
HexChat::print("[Current Options]");
if(-e "$homedir/.config/hexchat/.blocked") {
    HexChat::print("  \cBBlocking\cB all privmsgs unless in whitelist (/qblist)");
    }
else {
    HexChat::print("  \cBAllowing\cB privmsgs (/qb ON to enable)");
    }
return 1;
}



sub privmsg_cntl_handler {
#$Allow = 0;
$R0 = $_[0][0];
$R2 = $_[0][2];
$Umessage = $_[1][3];
$MyName = (HexChat::get_info(nick));
if ($R2 eq $MyName) {
    my ($sadvotackom) = (split /!/, $R0)[0];
    $QUser = substr $sadvotackom, 1;
    if (-e "$homedir/.config/hexchat/.blocked") { $Allow = 0; } else { $Allow = 1; }
    check_whitelist();
# allow msgs to yourself
    if ($QUser eq $MyName) { $Allow = 1; }
    if ($Allow eq 0) { block_privmsg(); }
    }
}



sub check_whitelist {
open(DATA, "$homedir/.config/hexchat/.whitelist") || die "can't open whitelist\n";
@Whitelist="";
while ( defined ($Ruser = <DATA>)) {
    chomp($Ruser);
    push(@Whitelist,$Ruser);
    }       
    close DATA;
    foreach $Wuser (@Whitelist) {
        if (lc($QUser) eq lc($Wuser)) {
            $Allow = 1;
            return;
        }
    }
}



sub block_privmsg {
$chk = `cat ~/.config/hexchat/.qbl`;
chomp($chk);
# prevent an "auto respond war" if other user has a script that
# auto replies to messages as well.  Still prints the msg, but doesn't
# auto respond with the $deny_msg to $QUser
system("echo $QUser $Umessage >> $homedir/.config/hexchat/qb.log");
if ($chk eq $QUser) {
    return 1;
    }
HexChat::command("msg $QUser $deny_msg");
system("echo $QUser > ~/.config/hexchat/.qbl");
return 1;
}
