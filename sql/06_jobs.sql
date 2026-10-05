-- =====================================================================
-- Finly | 06_jobs.sql   (Supabase only; enable the pg_cron extension first)
-- Times are UTC. 06:00 UTC = 03:00 America/Sao_Paulo.
-- =====================================================================

-- create extension if not exists pg_cron;

-- select cron.schedule('finly-generate-recurring', '0 6 * * *', $$select private.generate_all_recurring()$$);
-- select cron.schedule('finly-close-invoices',     '5 6 * * *', $$select private.close_due_invoices()$$);
-- select cron.schedule('finly-purge-trash',        '10 6 * * *', $$select private.purge_deleted(30)$$);
