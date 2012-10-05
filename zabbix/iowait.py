#!/usr/bin/env python
#
# Iowait metric script for zabbix
# Written by Vladimir Rusinov
# http://greenmice.info/
# License: GPLv3
#
# Calculates iowait


import os

s = os.popen("LC_ALL=POSIX iostat").readlines()[3].strip()

(user, nice, system, iowait, steal, idle) = [float(x) for x in s.split() if x]
print iowait
