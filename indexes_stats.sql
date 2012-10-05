SELECT a.relname, a.indexrelname, a.idx_scan, a.idx_tup_read, a.idx_tup_fetch, b.idx_blks_read, b.idx_blks_hit 
from pg_stat_user_indexes a join pg_statio_user_indexes b using(indexrelname) order by b.idx_blks_hit desc;
