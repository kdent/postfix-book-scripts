#!/usr/bin/perl
#
# Send contents of the real inforeply.pl to a browser.
# This is to workaround the fact that I cannot configure
# the web server to provide *.pl files as files rather
# than treating them as cgi scripts.
#

use strict;

my $FILE = "/home2/seaglas1/public_html/postfix/inforeply.txt";

print "Content-type: text/plain\r\n\r\n";

if (! open(FH, $FILE) ) {
	print "Sorry, I am unable to deliver the script.\n";
	print $!;
	exit;
}

while (<FH>) {
	chomp;
	print;
	print "\n";
}

