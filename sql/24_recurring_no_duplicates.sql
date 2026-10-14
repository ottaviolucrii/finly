-- 24: a recurring item no longer doubles what is already entered.
-- Until now, creating a recurring item generated a pending transaction for
-- every occurrence in the coming days, even when the person already had that
-- one (entered by hand, or an upcoming one), so it appeared twice. Now an
-- occurrence is skipped when the same account already has a matching entry
-- that did not come from a recurring item:
--   - the same type and the same description (ignoring capitals and extra spaces);
--   - about the same amount (within 15%, since subscriptions change price);
--   - in the same period: the same calendar month for monthly and yearly
--     items, within 3 days for weekly ones, the same day for daily ones.
-- Deleted and failed entries do not count. An occurrence that is skipped is
-- not tried again later. Run once in the Supabase SQL editor, after 23.

create or replace function private.generate_recurring_for(t public.recurring_transactions, p_until date)
returns integer language plpgsql security definer set search_path = public, private as $$
declare n int := t.generated_count; d date; created int := 0; v_created_on date := private.local_date(t.created_at);
begin
  loop
    d := private.recurrence_date(t.start_date, t.frequency, t.interval_count, n);
    exit when d > p_until or (t.end_date is not null and d > t.end_date);
    if d >= v_created_on
       and not exists (
         select 1
         from public.transactions x
         where x.workspace_id = t.workspace_id
           and x.account_id = t.account_id
           and x.type = t.type
           and x.recurring_id is null
           and x.deleted_at is null
           and x.status <> 'failed'
           and regexp_replace(lower(btrim(x.description)), '\s+', ' ', 'g') = regexp_replace(lower(btrim(t.description)), '\s+', ' ', 'g')
           and x.amount_cents between t.amount_cents * 0.85 and t.amount_cents * 1.15
           and case t.frequency
                 when 'daily'  then private.local_date(x.occurred_at) = d
                 when 'weekly' then abs(private.local_date(x.occurred_at) - d) <= 3
                 else date_trunc('month', private.local_date(x.occurred_at)::timestamp) = date_trunc('month', d::timestamp)
               end
       )
    then
      insert into public.transactions
        (workspace_id, account_id, currency, category_id, recurring_id, scheduled_for,
         type, status, amount_cents, description, occurred_at)
      values
        (t.workspace_id, t.account_id, t.currency, t.category_id, t.id, d,
         t.type, 'pending', t.amount_cents, t.description,
         (d + time '12:00') at time zone 'America/Sao_Paulo')
      on conflict (recurring_id, scheduled_for) where recurring_id is not null do nothing;
      if found then created := created + 1; end if;
    end if;
    n := n + 1;
  end loop;
  update public.recurring_transactions set generated_count = n where id = t.id and generated_count <> n;
  return created;
end $$;
