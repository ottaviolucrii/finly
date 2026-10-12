-- 21: Amora understands more, and the app suggests categories.
-- More totals the AI can ask for (run as the person, RLS applies, only the
-- totals go to the AI): where the money goes, budgets of a month, invoices to
-- pay, goals. And suggest_category(): the category the person usually picks
-- for a description, from their own history (no AI).
-- Run once in the Supabase SQL editor, after 20.

-- Where the money goes: the descriptions with the most spending in a period.
create or replace function public.ai_top_spending(p_workspace uuid, p_from date, p_to date)
returns table (description text, total_cents bigint, transactions integer, currency text)
  language plpgsql stable security invoker set search_path = public as $$
begin
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 1100 then
    raise exception 'invalid_period' using errcode = '22023';
  end if;
  return query
    select min(btrim(t.description)), sum(t.amount_cents)::bigint, count(*)::integer, t.currency
    from transactions t
    where t.workspace_id = p_workspace
      and t.type = 'expense'
      and t.status in ('posted', 'pending')
      and t.deleted_at is null
      and (t.occurred_at at time zone 'America/Sao_Paulo')::date between p_from and p_to
    group by lower(btrim(t.description)), t.currency
    order by 2 desc
    limit 8;
end $$;

-- The budgets of a month: the limit in force (the latest version up to that
-- month; 0 means stopped), what was spent and what is left.
create or replace function public.ai_budget_status(p_workspace uuid, p_month date)
returns table (category text, currency text, limit_cents bigint, spent_cents bigint, left_cents bigint)
  language sql stable security invoker set search_path = public as $$
  with month as (select date_trunc('month', p_month)::date as first_day),
  versions as (
    select distinct on (b.category_id) b.category_id, b.limit_cents, b.currency
    from budgets b, month m
    where b.workspace_id = p_workspace and b.effective_from <= m.first_day
    order by b.category_id, b.effective_from desc
  )
  select c.name, v.currency, v.limit_cents::bigint,
         coalesce(s.spent, 0)::bigint,
         (v.limit_cents - coalesce(s.spent, 0))::bigint
  from versions v
  join categories c on c.id = v.category_id
  cross join month m
  left join lateral (
    select sum(t.amount_cents) as spent
    from transactions t
    where t.workspace_id = p_workspace
      and t.category_id = v.category_id
      and t.type = 'expense'
      and t.status in ('posted', 'pending')
      and t.deleted_at is null
      and date_trunc('month', t.occurred_at at time zone 'America/Sao_Paulo')::date = m.first_day
  ) s on true
  where v.limit_cents > 0
  order by (coalesce(s.spent, 0)::numeric / v.limit_cents) desc;
$$;

-- The invoices still to pay, the one due first first.
create or replace function public.ai_invoices_to_pay(p_workspace uuid)
returns table (card text, reference_month date, due_date date, left_cents bigint, currency text)
  language sql stable security invoker set search_path = public as $$
  select a.name, i.reference_month, i.due_date, ib.remaining_cents::bigint, a.currency
  from credit_card_invoices i
  join accounts a on a.id = i.account_id
  join invoice_balances ib on ib.invoice_id = i.id
  where a.workspace_id = p_workspace
    and a.archived_at is null
    and ib.remaining_cents > 0
  order by i.due_date
  limit 8;
$$;

-- The goals: the target, what is saved (the balance of their account) and the date.
create or replace function public.ai_goals(p_workspace uuid)
returns table (goal text, target_cents bigint, saved_cents bigint, target_date date, currency text)
  language sql stable security invoker set search_path = public as $$
  select g.name, g.target_cents::bigint, greatest(coalesce(b.posted_balance_cents, 0), 0)::bigint, g.target_date, g.currency
  from goals g
  left join account_balances b on b.account_id = g.account_id
  where g.workspace_id = p_workspace and g.archived_at is null
  order by g.name;
$$;

-- The category the person usually picks for this description (the same
-- words first, then the same first word), from the last year. Null when the
-- history has no answer. No AI: just their own choices.
create or replace function public.suggest_category(p_workspace uuid, p_description text, p_type public.transaction_type)
returns uuid
  language sql stable security invoker set search_path = public as $$
  with typed as (select lower(btrim(coalesce(p_description, ''))) as text),
  candidates as (
    select t.category_id,
           case when lower(btrim(t.description)) = typed.text then 2 else 1 end as weight
    from transactions t, typed
    where t.workspace_id = p_workspace
      and t.type = p_type
      and t.category_id is not null
      and t.deleted_at is null
      and t.occurred_at > now() - interval '365 days'
      and char_length(typed.text) >= 3
      and (lower(btrim(t.description)) = typed.text
           or split_part(lower(btrim(t.description)), ' ', 1) = split_part(typed.text, ' ', 1))
  )
  select c.category_id
  from candidates c
  join categories k on k.id = c.category_id and k.archived_at is null
  group by c.category_id
  order by sum(c.weight) desc, count(*) desc
  limit 1;
$$;

grant execute on function public.ai_top_spending(uuid, date, date) to authenticated;
grant execute on function public.ai_budget_status(uuid, date) to authenticated;
grant execute on function public.ai_invoices_to_pay(uuid) to authenticated;
grant execute on function public.ai_goals(uuid) to authenticated;
grant execute on function public.suggest_category(uuid, text, public.transaction_type) to authenticated;
