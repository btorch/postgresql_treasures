#!/bin/sh

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`

psql -d $CLUSTER_DB -U $PG_USER -c "SELECT count(*) from accounts ;" -A -t
