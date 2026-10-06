-- =====================================================================
-- Finly | 12_recurring_edit_delete.sql
-- Edit and delete a recurring bill together with what it generated.
-- SECURITY DEFINER with an explicit membership check, like the other RPCs.
-- The schedule (frequency, interval, start date) is not editable: the
-- generator numbers the occurrences from it.
-- transactions.tx_recurring_shape requires recurring_id and scheduled_for to
-- be set or cleared together, and transactions.recurring_id has no ON DELETE
-- action, so a bill with history is detached before it is deleted.
-- Run after 00..11.
-- =====================================================================

create or replace function public.update_recurring(
  p_recurring_id uuid,
  p_description  text,
  p_amount_cents bigint,
  p_category_id  uuid,
  p_end_date     date
) returns void
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
declare
  r public.recurring_transactions;
  v_today date := private.local_date(now());
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
  -- end date). The schedule never changes.
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

  -- Pending occurrences after a new end date are removed.
  if p_end_date is not null then
    update public.transactions t
       set deleted_at = now()
     where t.recurring_id = p_recurring_id
       and t.status = 'pending'
       and t.deleted_at is null
       and t.scheduled_for > p_end_date
       and not exists (select 1 from public.credit_card_invoices i where i.id = t.invoice_id and i.status = 'paid');
  end if;
end $function$;

create or replace function public.delete_recurring(p_recurring_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
declare
  r public.recurring_transactions;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;

  select * into r from public.recurring_transactions where id = p_recurring_id;
  if not found or not public.is_workspace_member(r.workspace_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- Pending occurrences that were never confirmed go away.
  update public.transactions t
     set deleted_at = now()
   where t.recurring_id = p_recurring_id
     and t.status = 'pending'
     and t.deleted_at is null
     and not exists (select 1 from public.credit_card_invoices i where i.id = t.invoice_id and i.status = 'paid');

  -- What already happened stays in the history, no longer tied to the bill.
  update public.transactions
     set recurring_id = null,
         scheduled_for = null
   where recurring_id = p_recurring_id;

  delete from public.recurring_transactions where id = p_recurring_id;
end $function$;

revoke all on function public.update_recurring(uuid, text, bigint, uuid, date) from public, anon;
revoke all on function public.delete_recurring(uuid) from public, anon;
grant execute on function public.update_recurring(uuid, text, bigint, uuid, date) to authenticated;
grant execute on function public.delete_recurring(uuid) to authenticated;