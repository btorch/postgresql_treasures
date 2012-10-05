#!/bin/sh

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

#PG_USER="postgres"
#PG_PASS=""
#PG_DB=""

EXCLUDE="--exclude="~template,postgres""

if [[ "x$PG_PASS" == "x" ]]; then
	PASS=""
else
	PASS="--dbpass=$PG_PASS"
fi

$MYDIR/check_postgres.pl -u $PG_USER $PASS --output=simple --action=txn_time $EXCLUDE
