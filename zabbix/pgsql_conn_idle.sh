#!/bin/sh
#
# Total number of IDLE connections
# 

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

psql -U $PG_USER -c "SELECT COUNT(*) FROM pg_stat_activity WHERE current_query = '<IDLE>';" -A -t
