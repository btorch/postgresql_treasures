-- Enable all autovacuum settings in the pg_autovacuum table

BEGIN;
	UPDATE pg_autovacuum
		SET enabled = 't';
COMMIT;