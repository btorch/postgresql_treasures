#!/bin/bash

TMP_FILE="/tmp/pg_vacuum_stats"
EMAIL="b@g.com"

touch  $TMP_FILE 

echo " "  >> $TMP_FILE 
echo "---- `date` ----- " >> $TMP_FILE 

psql -U postgres  -d nast -c "SELECT oid, cast(reltuples AS bigint) from pg_class where  relname in ('baskets','egg_instance','entities')"  >> $TMP_FILE

psql -x -U postgres -d nast -c "SELECT * from pg_stat_user_tables where relname in ('baskets','egg_instance','entities')"  >> $TMP_FILE

echo " " >> $TMP_FILE

cat $TMP_FILE | mail -s "PG Vacuum Stats - PR1 DB2-1"  $EMAIL

rm  $TMP_FILE

