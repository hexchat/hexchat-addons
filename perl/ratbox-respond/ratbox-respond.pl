## Author:	xnite <xnite@afraidirc.net>
## Note for Windows Users:	You may want to use strawberry perl so that you can install the required perl modules easier.
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
package IRC::XChat::ratboxRespond;
use Crypt::OpenSSL::RSA;
use MIME::Base64;
use Digest::SHA1  qw(sha1 sha1_hex sha1_base64);
Xchat::register( "ratbox-respond", "0.1", "ratbox-respond", "");
Xchat::hook_server('740', 'ratbox_respond');
Xchat::hook_server('741', 'ratbox_respond_complete_auth');
Xchat::print("ratbox-respond for HexChat by xnite Loaded");

# CONFIGURATION #
our $private_key_path	= '/home/you/.config/hexchat/certs/client.key'; #this file should contain ONLY the private key.
# END OF CONFIGURATION - DO NOT EDIT BEYOND THIS POINT!

sub ratbox_respond {
	my $string = substr $_[0][3], 1;
	our $challenge = $challenge.$string;
	return Xchat::EAT_ALL;
}
sub ratbox_respond_complete_auth {
	Xchat::print("RATBOX-RESPOND: Received challenge from server.\nRATBOX-RESPOND: Challenge Key is: \"".$challenge."\"");
	local $/;
	Xchat::print("Opening private key file\n");
	open(FILE, $private_key_path) or Xchat::print("The private key located at \"".$private_key_path."\" could not be opened. Please check that the file exists");  
	$rsa_private_key = <FILE>; 
	close (FILE);  

	$rsa = Crypt::OpenSSL::RSA->new_private_key($rsa_private_key);
	my $plaintext = $rsa->decrypt(decode_base64($challenge));
	my $reply = sha1($plaintext);
	our $reply = encode_base64($reply);
	Xchat::command("QUOTE CHALLENGE +".$reply."\n");
	return Xchat::EAT_ALL;
}