SELECT *, now() - query_start AS duration from pg_stat_activity where current_query not like '%IDLE%' order by duration desc;
