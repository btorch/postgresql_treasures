#!/bin/sh
#
# Ping PostgreSQL Database

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

psql -U $PG_USER -c "SELECT 1" -A -t | wc -l
