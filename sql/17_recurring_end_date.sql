-- =====================================================================
-- Finly | 17_recurring_end_date.sql
-- A recurring item can have its end date moved later, or taken off, and the
-- occurrences that the end date had removed are made again. Run after 00..16.
--
-- Before: an end date only marked the pending occurrences after it as deleted
-- and the generator kept counting them as made, so they never came back (and
-- they sat in the trash). Now:
--   * the pending occurrences after the end date are removed for good (nothing
--     of the person's is lost: they were never confirmed, and the audit log
--     keeps a line for each);
--   * the generator is moved back to the first occurrence after the end date,
--     so when the end date moves later or goes away, those occurrences are made
--     again, on the spot and by the daily job;
--   * an occurrence the person confirmed, or deleted, is not touched and is not
--     made twice (the unique index on recurring_id + scheduled_for keeps it).
-- =====================================================================

create or replace function public.update_recurring(
  p_recurring_id uuid,
  p_description text,
  p_amount_cents bigint,
  p_category_id uuid,
  p_end_date date
)
returns void
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
declare
  r public.recurring_transactions;
  v_today date := private.local_date(now());
  v_first_after int;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;

  select * into r from public.recurring_transactions where id = p_recurring_id;
  if not found or not public.is_workspace_member(r.workspace_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_category_id is not null and not exists (
    select 1 from public.categories c
    where c.id = p_category_id and c.workspace_id = r.workspace_id and c.kind::text = r.type::text
  ) then
    raise exception 'category kind does not match transaction type' using errcode = '23514';
  end if;

  -- The table's CHECK constraints validate the values (amount, description,
  -- end date). The schedule (frequency, interval, start date) never changes.
  update public.recurring_transactions
     set description = btrim(p_description),
         amount_cents = p_amount_cents,
         category_id = p_category_id,
         end_date = p_end_date
   where id = p_recurring_id;

  -- Occurrences still pending, from today on, follow the new values. What was
  -- already confirmed, or is overdue, keeps what it had.
  update public.transactions t
     set description = btrim(p_description),
         amount_cents = p_amount_cents,
         category_id = p_category_id
   where t.recurring_id = p_recurring_id
     and t.status = 'pending'
     and t.deleted_at is null
     and private.local_date(t.occurred_at) >= v_today
     and not exists (select 1 from public.credit_card_invoices i where i.id = t.invoice_id and i.status = 'paid');

  if p_end_date is not null then
    -- Pending occurrences after the new end date are removed for good.
    delete from public.transactions t
     where t.recurring_id = p_recurring_id
       and t.status = 'pending'
       and t.deleted_at is null
       and t.scheduled_for > p_end_date
       and not exists (select 1 from public.credit_card_invoices i where i.id = t.invoice_id and i.status = 'paid');

    -- The next occurrence to make is the first one after the end date. Only the
    -- occurrences already made matter, so the count stops there.
    v_first_after := 0;
    while v_first_after < r.generated_count
      and private.recurrence_date(r.start_date, r.frequency, r.interval_count, v_first_after) <= p_end_date
    loop
      v_first_after := v_first_after + 1;
    end loop;

    update public.recurring_transactions
       set generated_count = least(generated_count, v_first_after)
     where id = p_recurring_id;
  end if;

  -- Make the occurrences that are missing now (an end date that moved later or
  -- was taken off), as the daily job would.
  select * into r from public.recurring_transactions where id = p_recurring_id;
  if r.is_active then
    perform private.generate_recurring_for(r, v_today + 35);
  end if;
end $function$;
