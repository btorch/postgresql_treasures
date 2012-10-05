#!/bin/sh
#
# Total number of connections in waiting state
# 

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

psql -U $PG_USER -c "SELECT COUNT(*) FROM pg_stat_activity WHERE waiting<>'f';" -A -t
