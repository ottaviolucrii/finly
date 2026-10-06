-- =====================================================================
-- Finly | 13_schedule_purge.sql
-- The trash keeps deleted transactions for 30 days; this job removes them
-- for good after that (and the transfers left with no legs).
-- 03:25 UTC is 00:25 in Sao Paulo. Scheduling a job with an existing name
-- updates it, so running this again never duplicates it.
-- Supabase only (needs pg_cron): run_db_tests.py does not apply this file,
-- but it does test private.purge_deleted(). Run after 00..12.
-- =====================================================================

select cron.schedule(
  'finly-purge-deleted',
  '25 3 * * *',
  $job$select private.purge_deleted()$job$
);