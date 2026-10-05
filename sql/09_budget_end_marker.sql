-- =====================================================================
-- Finly | 09_budget_end_marker.sql
-- A budget version with limit 0 means "no budget from this month on".
-- It lets the app stop a budget WITHOUT deleting the versions that earlier
-- months rely on (SRS BR-15: past months never change).
-- Run after 00..08. Safe to re-run.
-- =====================================================================

alter table public.budgets drop constraint if exists budgets_limit_cents_check;
alter table public.budgets add constraint budgets_limit_cents_check check (limit_cents >= 0);

comment on column public.budgets.limit_cents is
  'Monthly limit in cents. 0 is an end marker: no budget from effective_from on.';