-- 20: Amora answers questions about the person's money ("quanto gastei com
-- Uber esse ano?"). The AI never reads the history: it can only ask for the
-- totals below, run as the person (RLS applies), and only those totals go
-- back to it. It needs its own consent (ask_enabled), apart from the quick add.
-- Run once in the Supabase SQL editor.

alter table public.ai_settings
  add column if not exists ask_enabled      boolean not null default false,
  add column if not exists ask_consented_at timestamptz;

-- One use of today's quota (shared with the quick add), when questions are on.
create or replace function public.ai_take_ask_quota() returns text
  language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_day  date := (now() at time zone 'America/Sao_Paulo')::date;
  v_uses integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not exists (select 1 from ai_settings where user_id = v_uid and ask_enabled) then
    return 'disabled';
  end if;
  insert into ai_usage (user_id, day, uses) values (v_uid, v_day, 1)
  on conflict (user_id, day) do update
    set uses = ai_usage.uses + 1
    where ai_usage.uses < ai_daily_limit()
  returning uses into v_uses;
  return case when v_uses is null then 'limit' else 'ok' end;
end $$;

revoke all on function public.ai_take_ask_quota() from public;
grant execute on function public.ai_take_ask_quota() to authenticated;

-- Spending per category in a period (confirmed and pending; never failed or
-- deleted). Card purchases are pending until the invoice is paid: they count.
create or replace function public.ai_spending_by_category(p_workspace uuid, p_from date, p_to date)
returns table (category text, currency text, total_cents bigint, transactions integer)
  language plpgsql stable security invoker set search_path = public as $$
begin
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 1100 then
    raise exception 'invalid_period' using errcode = '22023';  -- dates in order, at most 3 years
  end if;
  return query
    select coalesce(c.name, 'Sem categoria'), t.currency, sum(t.amount_cents)::bigint, count(*)::integer
    from transactions t
    left join categories c on c.id = t.category_id
    where t.workspace_id = p_workspace
      and t.type = 'expense'
      and t.status in ('posted', 'pending')
      and t.deleted_at is null
      and (t.occurred_at at time zone 'America/Sao_Paulo')::date between p_from and p_to
    group by 1, 2
    order by 3 desc
    limit 30;
end $$;

-- Spending whose description has a word ("uber", "ifood"), in a period.
create or replace function public.ai_spending_matching(p_workspace uuid, p_from date, p_to date, p_text text)
returns table (currency text, total_cents bigint, transactions integer)
  language plpgsql stable security invoker set search_path = public as $$
declare
  v_text text := btrim(coalesce(p_text, ''));
begin
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 1100 then
    raise exception 'invalid_period' using errcode = '22023';  -- dates in order, at most 3 years
  end if;
  if char_length(v_text) < 2 or char_length(v_text) > 60 then
    raise exception 'invalid_text' using errcode = '22023';
  end if;
  -- the word is searched as written: % and _ have no special meaning
  v_text := replace(replace(replace(v_text, '\', '\\'), '%', '\%'), '_', '\_');
  return query
    select t.currency, sum(t.amount_cents)::bigint, count(*)::integer
    from transactions t
    where t.workspace_id = p_workspace
      and t.type = 'expense'
      and t.status in ('posted', 'pending')
      and t.deleted_at is null
      and (t.occurred_at at time zone 'America/Sao_Paulo')::date between p_from and p_to
      and t.description ilike '%' || v_text || '%'
    group by t.currency;
end $$;

-- Money in and out in a period, per currency (transfers between accounts do
-- not count: they are neither).
create or replace function public.ai_income_expense(p_workspace uuid, p_from date, p_to date)
returns table (currency text, income_cents bigint, expense_cents bigint)
  language plpgsql stable security invoker set search_path = public as $$
begin
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 1100 then
    raise exception 'invalid_period' using errcode = '22023';  -- dates in order, at most 3 years
  end if;
  return query
    select t.currency,
           coalesce(sum(t.amount_cents) filter (where t.type = 'income'), 0)::bigint,
           coalesce(sum(t.amount_cents) filter (where t.type = 'expense'), 0)::bigint
    from transactions t
    where t.workspace_id = p_workspace
      and t.type in ('income', 'expense')
      and t.status in ('posted', 'pending')
      and t.deleted_at is null
      and (t.occurred_at at time zone 'America/Sao_Paulo')::date between p_from and p_to
    group by t.currency;
end $$;

-- The balance of each active account today, and what is expected.
create or replace function public.ai_account_balances(p_workspace uuid)
returns table (account text, account_type text, currency text, balance_cents bigint, expected_cents bigint)
  language sql stable security invoker set search_path = public as $$
  select a.name, a.type::text, a.currency, b.posted_balance_cents::bigint, b.projected_balance_cents::bigint
  from accounts a
  join account_balances b on b.account_id = a.id
  where a.workspace_id = p_workspace
    and a.archived_at is null
  order by a.name;
$$;

grant execute on function public.ai_spending_by_category(uuid, date, date) to authenticated;
grant execute on function public.ai_spending_matching(uuid, date, date, text) to authenticated;
grant execute on function public.ai_income_expense(uuid, date, date) to authenticated;
grant execute on function public.ai_account_balances(uuid) to authenticated;
