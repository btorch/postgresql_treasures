#!/bin/sh

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`
RELATION=$1

psql -U $PG_USER -d $CLUSTER_DB -c "SELECT n_tup_hot_upd FROM pg_stat_user_tables WHERE relname = '$RELATION' ;" -A -t
