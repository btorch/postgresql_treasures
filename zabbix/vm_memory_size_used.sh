#!/bin/sh
#
# Actualy used (by apps) memory = Total - Free - Buffers - Cached

#MemTotal:      2028216 kB
#MemFree:         25440 kB
#Buffers:        209052 kB
#Cached:        1222696 kB

MEMINFO=`head -n 4 /proc/meminfo`
TOTAL=`echo $MEMINFO | cut -d " " -f 2`
FREE=`echo $MEMINFO | cut -d " " -f 5`
BUFFERS=`echo $MEMINFO | cut -d " " -f 8`
CACHED=`echo $MEMINFO | cut -d " " -f 11`

#echo $TOTAL

let USED=$(( 1024 * ($TOTAL-$FREE-$BUFFERS-$CACHED) ))
echo $USED
