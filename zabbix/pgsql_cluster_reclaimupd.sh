#!/bin/sh

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

CLUSTER_DB=`psql -U postgres -l -A -t |grep nast | cut -d "|" -f 1`
RELATION=$1

psql -U $PG_USER -d $CLUSTER_DB -c "SELECT ROUND(a.objects / b.n_live_tup, 2)* 100 as reclaimpct FROM  (SELECT SUM(egg_count) as objects from baskets) a, (SELECT n_live_tup from pg_stat_user_tables where relname = 'egg_instance') b; " -A -t
 
