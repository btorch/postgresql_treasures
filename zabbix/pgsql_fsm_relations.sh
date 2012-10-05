#!/bin/sh
#
# Checks how close a cluster is to the Postgres max_fsm_relations setting. This action will only work for databases of 8.2 or higher, and it requires the contrib module pg_freespacemap be installed.
#
# Output: %

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

#PG_USER="postgres"
#PG_PASS=""
#PG_DB=""

if [[ "x$PG_PASS" == "x" ]]; then
	PASS=""
else
	PASS="--dbpass=$PG_PASS"
fi

$MYDIR/check_postgres.pl -u $PG_USER $PASS --action=fsm_relations --output=mrtg | head -n 1
