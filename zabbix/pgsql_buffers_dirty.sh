#!/bin/sh
#
# Total number of used buffers
# Requies pg_buffercache contrib

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

psql -U $PG_USER -c "SELECT COUNT(*) FROM pg_buffercache WHERE isdirty='t';" -A -t
