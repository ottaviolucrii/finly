-- 23: spotting recurring items. suggest_recurring() looks at the person's own
-- history (no AI) for entries that come back every month: the same
-- description, about the same amount, in at least 3 of the last 6 months, not
-- already covered by a recurring item of the workspace. Runs as the person
-- (RLS applies). Run once in the Supabase SQL editor, after 22.

create or replace function public.suggest_recurring(p_workspace uuid)
returns table (
  description  text,
  type         public.transaction_type,
  amount_cents bigint,
  account_id   uuid,
  category_id  uuid,
  day_of_month integer,
  months_seen  integer,
  last_seen    date
)
  language sql stable security invoker set search_path = public as $$
  with recent as (
    select lower(btrim(t.description)) as key,
           t.description, t.type, t.amount_cents, t.account_id, t.category_id,
           (t.occurred_at at time zone 'America/Sao_Paulo')::date as day,
           date_trunc('month', t.occurred_at at time zone 'America/Sao_Paulo')::date as month
    from transactions t
    where t.workspace_id = p_workspace
      and t.type in ('income', 'expense')
      and t.status in ('posted', 'pending')
      and t.deleted_at is null
      and t.transfer_id is null
      and char_length(btrim(t.description)) >= 3
      and t.occurred_at > now() - interval '190 days'
  ),
  grouped as (
    select r.key,
           r.type,
           -- the most common amount, within 15% of each other, is "the" amount
           (array_agg(r.description order by r.day desc))[1]            as description,
           percentile_disc(0.5) within group (order by r.amount_cents)   as amount_cents,
           min(r.amount_cents)                                           as min_amount,
           max(r.amount_cents)                                           as max_amount,
           (array_agg(r.account_id order by r.day desc))[1]              as account_id,
           (array_agg(r.category_id order by r.day desc) filter (where r.category_id is not null))[1] as category_id,
           percentile_disc(0.5) within group (order by extract(day from r.day))::integer as day_of_month,
           count(distinct r.month)::integer                              as months_seen,
           max(r.day)                                                    as last_seen
    from recent r
    group by r.key, r.type
  )
  select g.description, g.type, g.amount_cents::bigint, g.account_id, g.category_id,
         g.day_of_month, g.months_seen, g.last_seen
  from grouped g
  where g.months_seen >= 3
    and g.max_amount <= g.min_amount * 1.15
    -- seen recently: a subscription cancelled months ago is not a suggestion
    and g.last_seen > current_date - 50
    -- not already a recurring item of the workspace
    and not exists (
      select 1 from recurring_transactions rt
      where rt.workspace_id = p_workspace
        and rt.is_active
        and lower(btrim(rt.description)) = g.key
    )
  order by g.months_seen desc, g.amount_cents desc
  limit 8;
$$;

grant execute on function public.suggest_recurring(uuid) to authenticated;
