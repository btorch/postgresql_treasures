#!/bin/sh

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`
RELATION=$1

psql -U $PG_USER -d $CLUSTER_DB -c "SELECT round(extract(epoch from now()) - extract(epoch from last_autovacuum))  from pg_stat_user_tables where relname = '$RELATION'; " -A -t
