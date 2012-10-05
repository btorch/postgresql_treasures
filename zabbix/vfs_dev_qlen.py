#!/usr/bin/env python
#
# average disk queue length
# Depends on sysstat
# This script is part of GreenMice Zabbix template collection and distributed under GPLv3
#
# Copyright (c) 2009 Murano Sofware [http://muranosoft.com/]
# Copyright (c) 2009 Vladimir Rusinov <vladimir@greenmice.info> [http://greenmice.info/]
########################################################################################

# iostat example output:
#
# # iostat sda -x
# Device:         rrqm/s   wrqm/s     r/s     w/s   rsec/s   wsec/s avgrq-sz avgqu-sz   await  svctm  %util
# sda               0.16    23.66    0.57    0.36    13.55    96.27   118.66     0.05   51.33   3.96   0.37
#
# where
# * rrqm/s : The number of read requests merged per second that were queued to the hard disk
# * wrqm/s : The number of write requests merged per second that were queued to the hard disk
# * r/s : The number of read requests per second
# * w/s : The number of write requests per second
# * rsec/s : The number of sectors read from the hard disk per second
# * wsec/s : The number of sectors written to the hard disk per second
# * avgrq-sz : The average size (in sectors) of the requests that were issued to the device.
# * avgqu-sz : The average queue length of the requests that were issued to the device
# * await : The average time (in milliseconds) for I/O requests issued to the device to be served. This includes the time spent by the requests in queue and the time spent servicing them.
# * svctm : The average service time (in milliseconds) for I/O requests that were issued to the device
# * %util : Percentage of CPU time during which I/O requests were issued to the device (bandwidth utilization for the device). Device saturation occurs when this value is close to 100%.

import os
import sys

s = os.popen("LC_ALL=POSIX iostat %s -x" % (sys.argv[1])).readlines()[-2].strip()

(rrqm, wrqm, r, w, rsec, wsec, avgrqsz, avgqusz, await, svctm, util) = [float(x) for x in s.split()[1:] if x]
print avgqusz
