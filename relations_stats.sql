SELECT a.relname,a.idx_tup_fetch,a.seq_tup_read, b.heap_blks_read, b.heap_blks_hit
from pg_stat_user_tables a  join pg_statio_user_tables b using(relname);
