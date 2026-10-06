-- =====================================================================
-- Finly | 10_schedule_jobs.sql
-- Daily jobs (pg_cron), in UTC: 03:05 UTC is 00:05 in Sao Paulo.
--   finly-close-invoices      closes the invoices whose cycle has ended
--   finly-generate-recurring  creates the pending occurrences of every
--                             active recurring item, 35 days ahead
-- Scheduling a job with an existing name updates it, so running this again
-- never duplicates anything. Run after 00..09.
-- =====================================================================

create extension if not exists pg_cron;

select cron.schedule(
  'finly-close-invoices',
  '5 3 * * *',
  $job$select private.close_due_invoices()$job$
);

select cron.schedule(
  'finly-generate-recurring',
  '15 3 * * *',
  $job$select private.generate_all_recurring()$job$
);