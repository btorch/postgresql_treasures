#!/bin/sh
#
# Number of rollbacks
# 

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`

psql -U $PG_USER -c "SELECT SUM(xact_rollback) FROM pg_stat_database WHERE datname LIKE  '$CLUSTER_DB%' ;" -A -t
