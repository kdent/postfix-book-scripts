#!/usr/bin/perl -w
#
# inforeply.pl - Automatic email reply.
#
# All messages are logged to your mail log. Check the
# log after executing the script to see the results.
#
# Set $UID to the uid of the process that runs the script.
# Check the entry in master.cf that calls this script. Use
# the uid of the account you assign to the user= attribute.
# If you want to test the script from the command line,
# set $UID to your own uid.
#
# Set $ENV_FROM to the envelope FROM address you want on
# outgoing replies. By default it's blank, which will
# use the NULL sender address <>. You can set it to an
# address to receive bounces, but make sure you don't set
# it to the same address that invokes the program, or
# you'll create a mail loop.
#
# Point $INFOFILE to a text file that contains the text of
# the outgoing reply. Include any headers you want in the
# message such as Subject: and From:. The To: header is
# set automatically based on the $ENV_FROM address. Make
# sure you have an empty line between your headers and the
# body of the message.
#
# If necessary, change the path to sendmail in $MAILBIN.
#
# @MAILOPTS contains options to sendmail. Make changes if
# necessary. The default options should work in most
# situations.
#
# The calls to syslog require that your Perl installation
# converted the necessary header files. See h2ph in your
# Perl distribution.
#

require 5.004;  # for setlogsock in Sys::Syslog module

use strict;
use Sys::Syslog qw(:DEFAULT setlogsock);

#
# Config options. Set these according to your needs.
#
my $UID = 500;
my $ENV_FROM = "";
my $INFOFILE = "/home/autoresp/inforeply.txt";
my $MAILBIN = "/usr/sbin/sendmail";
my @MAILOPTS = ("-oi", "-tr", "$ENV_FROM");
my $SELF = "inforeply.pl";
#
# end of config options

my $EX_TEMPFAIL = 75;
my $EX_UNAVAILABLE = 69;
my $EX_OK = 0;
my $sender;
my $euid = $>;

$SIG{PIPE} = \&PipeHandler;
$ENV{PATH} = "/bin:/usr/bin:/sbin:/usr/sbin";

setlogsock('unix');
openlog($SELF, 'ndelay,pid', 'user');

#
# Check our environment.
#
if ( $euid != $UID ) {
	syslog('mail|err',"error: invalid uid: $> (expecting: $UID)");
	exit($EX_TEMPFAIL);
}
if ( @ARGV != 1 ) {
	syslog('mail|err',"error: invalid invocation (expecting 1 argument)");
	exit($EX_TEMPFAIL);
} else {
	$sender = $ARGV[0];
	if ( $sender =~ /([\w\-.%]+\@[\w.-]+)/ ) {   # scrub address
		$sender = $1;
	} else {
		syslog('mail|err',"error: Illegal sender address");
		exit($EX_UNAVAILABLE);
	}
}
if (! -x $MAILBIN ) {
	syslog('mail|err', "error: $MAILBIN not found or not executable");
	exit($EX_TEMPFAIL);
}
if (! -f $INFOFILE ) {
	syslog('mail|err', "error: $INFOFILE not found");
	exit($EX_TEMPFAIL);
}

#
# Check sender exceptions.
#
if ($sender eq ""
    || $sender =~ /^owner-|-(request|owner)\@|^(mailer-daemon|postmaster)\@/i) {
    exit($EX_OK);
}

#
# Check message contents for Precedence header.
#
while ( <STDIN> ) {
	last if (/^$/);
	exit($EX_OK) if (/^precedence:\s+(bulk|list|junk)/i);
}

#
# Open info file.
#
if (! open(INFO, "<$INFOFILE") ) {
	syslog('mail|err',"error: can't open $INFOFILE: %m");
	exit($EX_TEMPFAIL);
}

#
# Open pipe to mailer.
#
my $pid = open(MAIL, "|-") || exec("$MAILBIN", @MAILOPTS);

#
# Send reply.
#
print MAIL "To: $sender\n";
print MAIL while (<INFO>);

if (! close(MAIL) ) {
	syslog('mail|err',"error: failure invoking $MAILBIN: %m");
	exit($EX_UNAVAILABLE);
}

close(INFO);
syslog('mail|info',"sent reply to $sender");
exit($EX_OK);


sub PipeHandler {
	syslog('mail|err',"error: broken pipe to mailer");
}

