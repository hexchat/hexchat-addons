# Name:        tempconv.pl
# Version:     001
# Author:      LifeIsPain < idontlikespam (at) orvp [dot] net >
# Date:        2010-02-16
# Description: Convert temperatures locally between Celsius, Fahrenheit, Kelvin, and  Rankine

# Version History
# 001  2010-02-16 Initial Version

use strict;
use warnings;
use Xchat qw(:all);

register('Temp Convert', '001', 'Convert standard temperatures between eachother');
hook_command('tempconv', \&parse_convert, { help_text => 'tempconv <From Temp>[CKFR] [CKFR]' });

my $table = {
	'C' => {
		'C' => sub { return $_[0]; },
		'K' => sub { return ( $_[0] + 273.15 ); },
		'F' => sub { return ( $_[0] * 1.8 + 32 ); },
		'R' => sub { return ( $_[0] * 1.8 + 491.67 ); }
	},
	'K' => {
		'C' => sub { return ( $_[0] - 273.15 ); },
		'K' => sub { return $_[0]; },
		'F' => sub { return ( $_[0] * 1.8 + 459.67 ); },
		'R' => sub { return ( $_[0] * 1.8 ); }
	},
	'F' => {
		'C' => sub { return ( ($_[0] - 32) * 5/9 ); },
		'K' => sub { return ( ($_[0] + 459.67) * 5/9 ); },
		'F' => sub { return $_[0]; },
		'R' => sub { return ( $_[0] + 459.67 ); }
	},
	'R' => {
		'C' => sub { return ( ($_[0] - 491.67) * 5/9 ); },
		'K' => sub { return ( $_[0] * 5/9 ); },
		'F' => sub { return ( $_[0] - 459.67 ); },
		'R' => sub { return $_[0]; }
	}
};

sub parse_convert {
	my $string = uc $_[1][1];
	my ($temp, $from, $to) = $string =~ m/^(-?\d*(?:\.\d+)?)\s*([CKFR])(?:\W*(?:TO|IN)?\W*)([CKFR])/;
	unless (defined $temp) {
		prnt ("Proper syntax: <From Temp>[CKFR] [CKFR]");
	}
	elsif (defined $table->{$from}{$to}) {
		prntf ("%.4g%s = %.4g%s", $temp, $from, $table->{$from}{$to}($temp), $to);
	}
	return EAT_XCHAT;
};
