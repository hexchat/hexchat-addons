This plugin will allow you to automatically Oper on ratbox (and ratbox derived) IRCds using the ratbox-respond protocal with your RSA private key.
Simply configure the location of your private key file for the matching public key in your operator {} block on your IRCd.

You will need to install the following perl modules:
Crypt::OpenSSL::RSA
Digest::SHA1
MIME::Base64