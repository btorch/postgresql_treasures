#!/bin/sh
#
# Number of commits
# 

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`
TABLE_NAME=$1

psql -U $PG_USER -d $CLUSTER_DB -c "SELECT pg_stat_get_dead_tuples((SELECT oid from pg_class where relname = '$TABLE_NAME')::oid)" -A -t

