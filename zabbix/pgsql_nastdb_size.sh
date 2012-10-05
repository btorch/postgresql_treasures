#!/bin/sh
#

# Checks database size
#

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

#PG_USER="postgres"

CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`

psql -U $PG_USER -t -c "select pg_database_size('$CLUSTER_DB');" -A -t
