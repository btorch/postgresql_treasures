#!/bin/sh

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

RELATION=$1
CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`

psql -d $CLUSTER_DB -U $PG_USER -c "SELECT pg_relation_size('$RELATION') ;" -A -t
