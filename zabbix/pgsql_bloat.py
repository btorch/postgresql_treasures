#!/usr/bin/env python
"""
pgsql.bloat.max

Checks the maximum amount of bloat in all tables and indexes in all databases. (Bloat is generally the amount of dead unused space taken up in a table or index. This space is usually reclaimed by use of the VACUUM command.) This action requires that stats collection be enabled on the target databases, and requires that ANALYZE is run frequently.

Append any agrument and I will display top 20 bloatest relations
"""

import sys
import os
import os.path

import psycopg2 as pg

# reading configs
mydir = os.path.dirname(sys.argv[0])
confdir = os.path.join(mydir, '../etc/')
conf = os.path.join(confdir, 'pgsql.conf')
exec(open(conf).read())

report = (len(sys.argv) > 1)

# getting list of databases
dbh = pg.connect(database='postgres', host='localhost', user=PG_USER, password=PG_PASS)
dbc = dbh.cursor()

dbc.execute("SELECT datname FROM pg_database")
dbs = [x[0] for x in dbc.fetchall() if x[0] <> 'template0']
dbc.close()
dbh.close()

pages = 0
otta = 0
bloatest = [ (0, 'none') ]

for db in dbs:
	try:
		dbh = pg.connect(database=db, host='localhost', user=PG_USER, password=PG_PASS)
		dbc = dbh.cursor()

		# kind of brainfuck
		q = """
SELECT
  schemaname,
  tablename,
  iname,
  reltuples::bigint,
  relpages::bigint,
  otta,
  ROUND(CASE WHEN otta=0 THEN 0.0 ELSE sml.relpages/otta::numeric END,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta END AS wastedpages,
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::bigint END AS wastedbytes,
  CASE WHEN relpages < otta THEN '0 bytes'::text ELSE (bs*(relpages-otta))::bigint || ' bytes' END AS wastedsize,
  ituples::bigint, ipages::bigint, iotta
FROM (
  SELECT
    schemaname, tablename, cc.reltuples, cc.relpages, bs,
    CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS otta,
    COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta -- very rough approximation, assumes all cols
  FROM (
    SELECT
      ma,bs,schemaname,tablename,
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM (
      SELECT
        schemaname, tablename, hdr, ma, bs,
        SUM((1-null_frac)*avg_width) AS datawidth,
        MAX(null_frac) AS maxfracsum,
        hdr+(
          SELECT 1+count(*)/8
          FROM pg_stats s2
          WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
        ) AS nullhdr
      FROM pg_stats s, (
        SELECT
          (SELECT current_setting('block_size')::numeric) AS bs,
          CASE WHEN substring(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr,
          CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
        FROM (SELECT version() AS v) AS foo
      ) AS constants
      GROUP BY 1,2,3,4,5
    ) AS foo
  ) AS rs
  JOIN pg_class cc ON cc.relname = rs.tablename
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema' AND nn.nspname <> 'pg_catalog'
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
) AS sml
	"""
		dbc.execute(q)
		for r in dbc.fetchall():
			pages += r[4]
			otta += r[5]
			if report and r[4] > 1000:
				bloat = 100*(r[4]-r[5]) / r[4]
				if bloat > bloatest[-1][0]:
					bloatest.append( (bloat, "%s: %s.%s->%s (%i, shouldbe %i): %.2fX " % (db, r[0], r[1], r[2], r[4], r[5], r[4]/r[5] ) ))
					bloatest.sort(reverse=True)
					bloatest = bloatest[:20]

		dbc.close()
		dbh.close()
	except:
		raise
		pass

if pages < 5000: # cluster < then 40 Mb is no serious
	print 0
else:
	print 100*(pages - otta) / pages
if report:
	print "Bloatest tables:"
	for b in bloatest:
		print b
