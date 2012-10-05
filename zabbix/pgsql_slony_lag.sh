#!/bin/sh

MYDIR=`dirname $0`
. $MYDIR/../etc/slony.conf

psql -U $PG_USER $DB -c "SELECT cast(extract(epoch from st_lag_time) as int8) FROM \"_$CLUSTERNAME\".sl_status;" -A -t
