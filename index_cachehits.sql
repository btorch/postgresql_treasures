SELECT indexrelname AS index, (idx_blks_read + idx_blks_hit) AS heap_hits, ROUND(((idx_blks_hit)::NUMERIC / (idx_blks_read + idx_blks_hit) * 100),2) AS ratio FROM pg_statio_user_indexes WHERE (idx_blks_read + idx_blks_hit) > 0 order by ratio desc;
