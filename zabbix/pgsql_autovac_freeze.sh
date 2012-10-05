#!/bin/sh
#
# Checks how close each database is to the Postgres autovacuum_freeze_max_age setting.
# This action will only work for databases version 8.2 or higher. The --warning and
# --critical options should be expressed as percentages. The 'age' of the transactions
# in each database is compared to the autovacuum_freeze_max_age setting (200 million by
# default) to generate a rounded percentage. The default values are 90% for the warning
# and 95% for the critical. Databases can be filtered by use of the --include and --exclude
# options. See the BASIC FILTERING section for more details.
#
# autovacuum_freeze_max_age (integer)
#
#    Specifies the maximum age (in transactions) that a table's pg_class.relfrozenxid field can
# attain before a VACUUM operation is forced to prevent transaction ID wraparound within the table.
# Note that the system will launch autovacuum processes to prevent wraparound even when
# autovacuum is otherwise disabled. The default is 200 million transactions. This
# parameter can only be set at server start, but the setting can be reduced
# for individual tables by changing storage parameters. For more information see Section 23.1.4. 
#
# Output: %

MYDIR=`dirname $0`
. $MYDIR/../etc/pgsql.conf

#PG_USER="postgres"
#PG_PASS=""
#PG_DB=""

EXCLUDE="--exclude="~template,postgres""

if [[ "x$PG_PASS" == "x" ]]; then
	PASS=""
else
	PASS="--dbpass=$PG_PASS"
fi

$MYDIR/check_postgres.pl -u $PG_USER $PASS --action=autovac_freeze --output=mrtg $EXCLUDE  | head -n 1
