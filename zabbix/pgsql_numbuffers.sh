#!/bin/sh
#
# Total number of buffers in buffercache
# Requies pg_buffercache contrib

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

psql -U $PG_USER -c "SELECT count(*) FROM pg_buffercache;" -A -t
