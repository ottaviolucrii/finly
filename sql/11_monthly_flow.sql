-- =====================================================================
-- Finly | 11_monthly_flow.sql
-- Income and expenses that already happened (posted), per workspace,
-- currency and month (Sao Paulo time). Used by the dashboard bar chart.
-- Transfers and failed or deleted entries do not count.
-- security_invoker: Row Level Security of transactions applies.
-- Run after 00..10.
-- =====================================================================

create or replace view public.monthly_flow
with (security_invoker = true) as
select
  t.workspace_id,
  t.currency,
  date_trunc('month', t.occurred_at at time zone 'America/Sao_Paulo')::date as month,
  coalesce(sum(t.amount_cents) filter (where t.type = 'income'), 0)::bigint  as income_cents,
  coalesce(sum(t.amount_cents) filter (where t.type = 'expense'), 0)::bigint as expense_cents
from public.transactions t
where t.type in ('income', 'expense')
  and t.status = 'posted'
  and t.deleted_at is null
group by t.workspace_id, t.currency,
         date_trunc('month', t.occurred_at at time zone 'America/Sao_Paulo')::date;

revoke all on public.monthly_flow from public, anon, authenticated;
grant select on public.monthly_flow to authenticated;