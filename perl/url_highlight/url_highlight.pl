use strict;
use warnings;
use Xchat qw(:all);

### TODO ###
# Deal with colors in front of the URL
############

### Configuration #######
# Set to 1 to also highlight your own messages
my $HIGHLIGHT_SELF = 0;

# This setting controls how much the script attempts to conform to what the
# RFCs define as a valid domain and therefore what is a valid URL.
# When set to:
# 0) Anything with using a-zA-Z0-9- separated by a dot followed by a TLD will be
#    accepted as a valid domain.
# 1) Each part of the domain must start and end with only a letter or number,
#    it may contain from 1 to 63 of a-zA-Z0-9-, there can be no more than 127
#    parts.
my $STRICT = 0;

# The default list of TLDs is taken from http://www.iana.org/domains/root/db/
# If you only care about certain TLDs then you can specify it here. This will
# replace the default list.
# Example: my @TLDs = qw(com net org info);
my @TLDs = qw();

# These can be changed to highlight URLs differently.
# The defaults will highlight the URLs by reversing the background
# and foreground
my $HIGHLIGHT_START = "\037";
my $HIGHLIGHT_END = "\037";

### End Configuration ###

register(
	"URL Highlight",
	"1.0301",
	"Make URLs stand out from the rest of the text",
);

my @events = (
	"Channel Message",
	"Channel Msg Hilight",
	"Channel Action",
	"Channel Action Hilight",
);
if( $HIGHLIGHT_SELF ) {
	push @events, "Your Message", "Your Action";
}

for my $event ( @events ) {
	hook_print( $event, \&highlight_url, { data => $event } );
}

my @tlds = @TLDs ? @TLDs : qw(
	ac ad ae aero af ag ai al am an ao aq ar arpa as asia at au au aw ax az
	ba bb bd be bf bg bh bi biz bj bl bm bn bo bq br bs bt bv bw by bz
	ca cat cc cd cf cg ch ci ck cl cm cn co com coop cr cu cv cw cx cy cz
	de dj dk dm do dz
	ec edu ee eg eh er es et eu
	fi fj fk fm fo fr
	ga gb gd ge gf gg gh gi gl gm gn gov gp gq gr gs gt gu gw gy
	hk hm hn hr ht hu
	id ie il im in info int io iq ir is it
	je jm jo jobs jp
	ke kg kh ki km kn kp kr kw ky kz
	la lb lc li lk lr ls lt lu lv ly
	ma mc md me mf mg mh mil mk ml mm mn mo mobi mp mq mr ms mt mu museum mv mw
	mx my mz
	na name nc ne net nf ng ni nl no np nr nu nz
	om org
	pa pe pf pg ph pk pl pm pn pr pro ps pt pw py
	qa
	re ro rs ru rw
	sa sb sc sd se sg sh si sj sk sl sm sn so sr st su sv sx sy sz
	tc td tel tf tg th tj tk tl tm tn to tp tr travel tt tv tw tz
	ua ug uk um us uy uz
	va vc ve vg vi vn vu
	wf ws
);

@tlds = sort { length( $b ) <=> length( $a ) } @tlds;
my $tld_re = join '|', map { quotemeta } @tlds;
$tld_re = qr/$tld_re/i;

my $label_re = $STRICT ?
	qr/
		(?:
			(?<![a-z0-9])
			[a-z0-9]
			(?>[a-z0-9-]{0,61})
			[a-z0-9]?
			[.]
		){1,127}
	/xi
	: qr/
		(?:
			[a-z0-9-]+
			[.]
		)+
	/xi;

my $domain_re = qr/ $label_re	$tld_re /x;

# safe characters, including the reserved ones
my $safe = join "", map chr, 0x20 .. 0x7e; # US-ASCII RFC1738
$safe =~ tr/ <>"'{}|\\^[]`//d; # remove unsafe RFC1738
my $safe_re = qr/[$safe]*/;

(my $safe_after_tld_re = $safe) =~ tr/a-zA-Z//d;
$safe_after_tld_re = qr/[$safe_after_tld_re]/;

# loose definition of an IP
my $ip_re = qr/ (?:\d{1,3}[.]){3} \d{1,3} /x;

# combine the parts
my $url_pattern = qr{
	(?:[a-z]+://)? # scheme
	(?: [^:\@\/ ]+ : [^:\@\/ ]* \@ )? # user:pass@
	(?:$domain_re|localhost|$ip_re)
	  (?:
	     $safe_after_tld_re $safe_re # non alpha after the tld followed by safe characters
		  | \b
	  )
}x;

my $search_re = qr{
	(?: # matches start at space delimited words
		(?<=\b)|(?<=\s)
	)
	( \(? $url_pattern )
}x;

sub wrap_emit(&) {
	my $block = shift;
	my $strip_color = get_prefs "text_stripcolor_msg";

	if( $strip_color ) {
		command( "SET -quiet text_stripcolor_msg OFF" );
		$block->();
		command( "SET -quiet text_stripcolor_msg ON" );
	} else {
		$block->();
	}
}

sub highlight_url {
	my ($nick, $text, $mode, $id_text) = @{$_[0]};
	my $args = @{$_[0]} - 1;
	my $event = $_[1];

	strip_code( $text ) if get_prefs "text_stripcolor_msg";
	if( $text =~ s[$search_re][format_highlight( $1 )]eg ) {
		# only emit as many args as we were passed to deal with older versions
		# where action events and message events received different number of
		# arguments
		wrap_emit {
			emit_print(	$event, ($nick, $text, $mode, $id_text)[0 .. $args]);
		};

		return EAT_ALL;
	}

	return EAT_NONE;
}

sub format_highlight {
	my $matched = shift;

	if( $matched =~ /^\(/ and $matched =~ /\)$/ ) {
		$matched = substr( $matched, 1, -1 );
		return format_url( $matched );
	}elsif( $matched =~ /^\(/ ) {
		# remove the leading ( since we will add it back later
		substr( $matched, 0, 1, "" );

		my $right_paren_index = rindex( $matched, ")" );
		my $remainder = "";

		if( $right_paren_index > 0 ) {
			$remainder = substr( $matched, $right_paren_index );
			$matched = substr( $matched, 0, $right_paren_index - 1 );
		} else {
			$matched = substr( $matched, 0 );
		}

		return '(' . format_url( $matched ) . $remainder;
	} elsif( $matched =~ /\)$/ ) {
		my $left_parens = $matched =~ tr/(/(/;
		my $right_parens = $matched =~ tr/)/)/;

		if( $right_parens > $left_parens ) {
			chop $matched;
			return format_url( $matched ) . ')';
		}
	}
	
	return format_url( $matched );

}

sub format_url {
	my $url = shift;
	
	my $start = $HIGHLIGHT_START || "\cV";
	my $end = $HIGHLIGHT_END || "\cV";

	return $start . $url . $end;
}

hook_command( "TEST_URLS", sub {
	if( $_[1][1] ) {
		display_test( $_[1][1] );
		return EAT_XCHAT;
	}
	
display_test( '-----------------------------------------------------------------' );
display_test( '01) http://en.wikipedia.org/wiki/DNS_label#Domain_name_syntax XXX' );
display_test( '02) http://en.wikipedia.org/wiki/Dog_%28zodiac%29 XXXXXXXXXXXXXXX' );
display_test( '03) http://en.wikipedia.org/wiki/Dog_(zodiac) XXXXXXXXXXXXXXXXXXX' );
display_test( '04) en.wikipedia.org/wiki/Dog_%28zodiac%29 XXXXXXXXXXXXXXXXXXXXXX' );
display_test( '05) en.wikipedia.org/wiki/Dog_(zodiac) XXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '06) foo.www.wikipedia.org XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '07) www.wikipedia.org XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '08) wiki-pedia.org XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '09) -invalidpedia.org XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '10) something.random XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '11) www.more.random XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '12) 0zero.example XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '13) #($&(@#http://example.com XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '14) (#*%example.com XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' );
display_test( '15) foo bar http://www.example.com) foo bar www.example.com)' );
display_test( '16) foo (http://www.example.com) bar (example.com) foo' );
display_test( '17) http://example.com/)foo example.com/)foo' );
display_test( '18) (http://example.com/)foo (example.com)foo' );
display_test( '19) http://example.com/()foo example.com/()foo' );
display_test( '20) invalid character in domain http://foo_bar.com/' );
display_test( '21) square [http://example.com] [http://example.com/foo] [example.com] [example.com/foo ] bar' );
display_test( '22) curly {http://example.com} {http://example.com/foo} {example.com} {example.com/foo} bar' );
display_test( '23) angle <http://example.com/foo> <example.com/foo>' );
display_test( '24) quoted "http://example.com"; \'example.com\' bar' );
display_test( '25) user and pass http://user:pass@example.com bar' );
display_test( '26) user and empty pass http://user:@example.com foo' );
display_test( '27) should not be valid http://:pass@example.com foo' );
display_test( '28) http://example.com/~user/' );
display_test( '29) http://search.cpan.org/~rcaputo/POE-1.299/lib/POE/Kernel.pm#delay_set_EVENT_NAME,_DURATION_SECONDS_[,_PARAMETER_LIST]' );
display_test( '-----------------------------------------------------------------' );
	
	return EAT_XCHAT;
});

sub display_test {
	my $text = shift;
	my $nick = get_info "nick";

	emit_print( "Channel Message", $nick, $text, "", "" );
}
