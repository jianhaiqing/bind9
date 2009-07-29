#!/bin/sh
#
# Copyright (C) 2004, 2007  Internet Systems Consortium, Inc. ("ISC")
# Copyright (C) 2000, 2001  Internet Software Consortium.
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
# REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
# INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
# LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
# OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SOFTWARE.

# $Id: tests.sh,v 1.26 2009/07/29 17:52:00 each Exp $

SYSTEMTESTTOP=..
. $SYSTEMTESTTOP/conf.sh

status=0

echo "I:fetching first copy of zone before update"
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd example.nil.\
	@10.53.0.1 axfr -p 5300 > dig.out.ns1 || status=1

echo "I:fetching second copy of zone before update"
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd example.nil.\
	@10.53.0.2 axfr -p 5300 > dig.out.ns2 || status=1

echo "I:comparing pre-update copies to known good data"
$PERL ../digcomp.pl knowngood.ns1.before dig.out.ns1 || status=1
$PERL ../digcomp.pl knowngood.ns1.before dig.out.ns2 || status=1

echo "I:updating zone"
# nsupdate will print a ">" prompt to stdout as it gets each input line.
$NSUPDATE -k ns1/ddns.key <<END > /dev/null || status=1
server 10.53.0.1 5300
update add updated.example.nil. 600 A 10.10.10.1
update add updated.example.nil. 600 TXT Foo
update delete t.example.nil.

END
echo "I:sleeping 15 seconds for server to incorporate changes"
sleep 15

echo "I:fetching first copy of zone after update"
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd example.nil.\
	@10.53.0.1 axfr -p 5300 > dig.out.ns1 || status=1

echo "I:fetching second copy of zone after update"
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd example.nil.\
	@10.53.0.2 axfr -p 5300 > dig.out.ns2 || status=1

echo "I:comparing post-update copies to known good data"
$PERL ../digcomp.pl knowngood.ns1.after dig.out.ns1 || status=1
$PERL ../digcomp.pl knowngood.ns1.after dig.out.ns2 || status=1

echo "I:testing local update policy"
pre=`$DIG +short new.other.nil. @10.53.0.1 a -p 5300` || status=1
[ -z "$pre" ] || status=1

echo "I:updating zone"
# nsupdate will print a ">" prompt to stdout as it gets each input line.
$NSUPDATE -l -p 5300 -k ns1/session.key > /dev/null <<END || status=1
zone other.nil.
update add new.other.nil. 600 IN A 10.10.10.1
send
END

echo "I:sleeping 5 seconds for server to incorporate changes"
sleep 5

echo "I:checking result of update"
post=`$DIG +short new.other.nil. @10.53.0.1 a -p 5300` || status=1
[ "$post" = "10.10.10.1" ] || status=1

echo "I:comparing post-update copy to known good data"
$PERL ../digcomp.pl knowngood.ns1.after dig.out.ns1 || status=1

if $PERL -e 'use Net::DNS;' 2>/dev/null
then
    echo "I:running update.pl test"
    $PERL update_test.pl -s 10.53.0.1 -p 5300 update.nil. || status=1
else
    echo "I:The second part of this test requires the Net::DNS library." >&2
fi

echo "I:fetching first copy of test zone"
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd example.nil.\
	@10.53.0.1 axfr -p 5300 > dig.out.ns1 || status=1

echo "I:fetching second copy of test zone"
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd example.nil.\
	@10.53.0.2 axfr -p 5300 > dig.out.ns2 || status=1

echo "I:comparing zones"
$PERL ../digcomp.pl dig.out.ns1 dig.out.ns2 || status=1

echo "I:SIGKILL and restart server ns1"
cd ns1
kill -KILL `cat named.pid`
rm named.pid
cd ..
sleep 10
if 
	$PERL $SYSTEMTESTTOP/start.pl --noclean . ns1
then
	echo "I:restarted server ns1"	
else
	echo "I:could not restart server ns1"
	exit 1
fi
sleep 10

echo "I:fetching ns1 after hard restart"
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd example.nil.\
	@10.53.0.1 axfr -p 5300 > dig.out.ns1.after || status=1

echo "I:comparing zones"
$PERL ../digcomp.pl dig.out.ns1 dig.out.ns1.after || status=1

echo "I:begin RT #482 regression test"

echo "I:update master"
$NSUPDATE -k ns1/ddns.key <<END > /dev/null || status=1
server 10.53.0.1 5300
update add updated2.example.nil. 600 A 10.10.10.2
update add updated2.example.nil. 600 TXT Bar
update delete c.example.nil.
send
END

sleep 5

echo "I:SIGHUP slave"
kill -HUP `cat ns2/named.pid`

sleep 5

echo "I:update master again"
$NSUPDATE -k ns1/ddns.key <<END > /dev/null || status=1
server 10.53.0.1 5300
update add updated3.example.nil. 600 A 10.10.10.3
update add updated3.example.nil. 600 TXT Zap
update delete d.example.nil.
send
END

sleep 5

echo "I:SIGHUP slave again"
kill -HUP `cat ns2/named.pid`

sleep 5

if grep "out of sync" ns2/named.run
then
	status=1
fi

echo "I:end RT #482 regression test"

echo "I:testing that rndc stop updates the master file"
$NSUPDATE -k ns1/ddns.key <<END > /dev/null || status=1
server 10.53.0.1 5300
update add updated4.example.nil. 600 A 10.10.10.3
send
END
$PERL $SYSTEMTESTTOP/stop.pl --use-rndc . ns1
# Removing the journal file and restarting the server means
# that the data served by the new server process are exactly
# those dumped to the master file by "rndc stop".
rm -f ns1/*jnl
$PERL $SYSTEMTESTTOP/start.pl --noclean . ns1
$DIG +tcp +noadd +nosea +nostat +noquest +nocomm +nocmd updated4.example.nil.\
	@10.53.0.1 a -p 5300 > dig.out.ns1 || status=1
$PERL ../digcomp.pl knowngood.ns1.afterstop dig.out.ns1 || status=1

echo "I:exit status: $status"
exit $status
