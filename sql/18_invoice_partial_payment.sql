-- =====================================================================
-- Finly | 18_invoice_partial_payment.sql
-- Pay a credit card invoice in parts. Run after 00..17.
--
-- Before: pay_invoice paid the whole invoice at once. Now it takes an optional
-- amount: up to what is still owed. Each payment is a transfer to the card, as
-- before (so balances and reports stay right), and is linked to the invoice in
-- invoice_payments. The invoice becomes "paid" only when nothing is owed.
--
--   * What was paid is not a stored number: it is the card side of the linked
--     transfers that are still alive, so deleting a payment lowers it again.
--   * What is owed = the invoice total minus what was paid (never below zero).
--     Purchases that join an open invoice after a payment raise it again.
--   * Deleting any payment of a paid invoice reopens the invoice.
--   * An unpaid remainder stays on the same invoice (no interest, no carry-over).
-- =====================================================================

create table public.invoice_payments (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references public.credit_card_invoices (id) on delete cascade,
  transfer_id uuid not null references public.transfers (id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint invoice_payments_transfer_uidx unique (transfer_id)
);

create index invoice_payments_invoice_idx on public.invoice_payments (invoice_id);

-- Read-only for clients, like transfers: the rows are written by pay_invoice().
alter table public.invoice_payments enable row level security;

create policy invoice_payments_select on public.invoice_payments
  for select
  using (public.owns_account(
    (select i.account_id from public.credit_card_invoices i where i.id = invoice_id)));

revoke all on public.invoice_payments from public, anon;
grant select on public.invoice_payments to authenticated;

-- The invoices that were already paid in full by one transfer.
insert into public.invoice_payments (invoice_id, transfer_id)
select i.id, i.paid_by_transfer_id
from public.credit_card_invoices i
where i.paid_by_transfer_id is not null
on conflict do nothing;

-- Total, paid and still owed, per invoice (derived, never stored).
create or replace view public.invoice_balances with (security_invoker = true) as
select
  i.id as invoice_id,
  i.account_id,
  coalesce(tt.total_cents, 0)::bigint as total_cents,
  coalesce(pp.paid_cents, 0)::bigint as paid_cents,
  greatest(coalesce(tt.total_cents, 0) - coalesce(pp.paid_cents, 0), 0)::bigint as remaining_cents
from public.credit_card_invoices i
left join public.invoice_totals tt on tt.invoice_id = i.id
left join (
  select ip.invoice_id, sum(t.amount_cents) as paid_cents
  from public.invoice_payments ip
  join public.transactions t
    on t.transfer_id = ip.transfer_id
   and t.type = 'transfer_in'
   and t.deleted_at is null
   and t.status <> 'failed'
  group by ip.invoice_id
) pp on pp.invoice_id = i.id;

revoke all on public.invoice_balances from public, anon;
grant select on public.invoice_balances to authenticated;

-- The old function had three arguments; this one has four (the last is optional).
-- The old one has to go, or a call with three would match both.
drop function if exists public.pay_invoice(uuid, uuid, timestamptz);

create or replace function public.pay_invoice(
  p_invoice_id uuid,
  p_from_account_id uuid,
  p_paid_at timestamptz default now(),
  p_amount_cents bigint default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
declare
  v_inv public.credit_card_invoices;
  v_total bigint;
  v_paid bigint;
  v_remaining bigint;
  v_amount bigint;
  v_tid uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;

  select * into v_inv from public.credit_card_invoices where id = p_invoice_id for update;
  if v_inv.id is null or not public.owns_account(v_inv.account_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_inv.status = 'paid' then raise exception 'invoice already paid'; end if;

  select coalesce(sum(case when t.type = 'expense' then t.amount_cents else -t.amount_cents end), 0)
    into v_total
  from public.transactions t
  where t.invoice_id = v_inv.id and t.deleted_at is null and t.status <> 'failed';

  select coalesce(sum(t.amount_cents), 0)
    into v_paid
  from public.invoice_payments ip
  join public.transactions t
    on t.transfer_id = ip.transfer_id
   and t.type = 'transfer_in'
   and t.deleted_at is null
   and t.status <> 'failed'
  where ip.invoice_id = v_inv.id;

  v_remaining := v_total - v_paid;
  if v_remaining <= 0 then raise exception 'nothing to pay on this invoice'; end if;

  v_amount := coalesce(p_amount_cents, v_remaining);
  if v_amount <= 0 then
    raise exception 'payment amount must be positive' using errcode = '23514';
  end if;
  if v_amount > v_remaining then
    raise exception 'payment amount is above what is owed' using errcode = '23514';
  end if;

  v_tid := public.create_transfer(
    p_from_account_id, v_inv.account_id, v_amount,
    'Pagamento fatura ' || to_char(v_inv.reference_month, 'MM/YYYY')
      || case when v_amount < v_remaining then ' (parcial)' else '' end,
    p_paid_at);

  insert into public.invoice_payments (invoice_id, transfer_id) values (v_inv.id, v_tid);

  if v_amount = v_remaining then
    update public.credit_card_invoices
    set status = 'paid', paid_at = now(), paid_by_transfer_id = v_tid
    where id = v_inv.id;
  end if;

  return v_tid;
end $function$;

revoke all on function public.pay_invoice(uuid, uuid, timestamptz, bigint) from public, anon;
grant execute on function public.pay_invoice(uuid, uuid, timestamptz, bigint) to authenticated;

-- Deleting a transfer reopens a paid invoice when the transfer was one of its
-- payments (the last one, or an earlier part: the invoice is not settled any more).
create or replace function public.delete_transfer(p_transfer_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.transfers where id = p_transfer_id and owner_id = auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  perform set_config('finly.rpc', 'on', true);
  update public.transactions set deleted_at = now()
  where transfer_id = p_transfer_id and deleted_at is null;

  update public.credit_card_invoices i
  set status = case when private.local_date(now()) > i.period_end then 'closed' else 'open' end::public.invoice_status,
      paid_at = null, paid_by_transfer_id = null
  where i.status = 'paid'
    and (i.paid_by_transfer_id = p_transfer_id
         or exists (select 1 from public.invoice_payments ip
                    where ip.invoice_id = i.id and ip.transfer_id = p_transfer_id));
  perform set_config('finly.rpc', 'off', true);
end $function$;

revoke all on function public.delete_transfer(uuid) from public, anon;
grant execute on function public.delete_transfer(uuid) to authenticated;
