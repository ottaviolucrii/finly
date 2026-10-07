-- =====================================================================
-- Finly | 15_move_transaction.sql
-- Moves an income or an expense to another account of the same workspace
-- and currency. Run after 00..14.
--
-- 1. The guard on transactions refused every change of account. Only the
--    definer functions (which switch finly.rpc on, like delete_transfer) may
--    change it now, and move_transaction is the only one that does. A client
--    cannot set finly.rpc: the API exposes no way to run set_config.
-- 2. move_transaction moves a transaction to another account of its workspace
--    and currency. An expense of a bank account can also go to a credit card: it
--    becomes a purchase on the invoice of its date (refused when that invoice is
--    already paid, and an income never goes to a card). A card purchase can come
--    back to a bank account while its invoice is not paid. It refuses: a deleted
--    transaction, a transfer leg, an installment, the same account, an account
--    of another workspace, an archived one, another currency, a card purchase
--    sent to another card, and anyone who is not a member of the workspace.
-- =====================================================================

create or replace function private.tx_before_write()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
declare
  v_acc_type public.account_type;
  v_closing  int;
  v_cat_kind public.category_kind;
  v_inv      public.credit_card_invoices%rowtype;
  v_rpc      boolean := coalesce(current_setting('finly.rpc', true), '') = 'on';
begin
  select type into v_acc_type from public.accounts where id = new.account_id;

  if new.category_id is not null then
    select kind into v_cat_kind from public.categories where id = new.category_id;
    if (new.type = 'income' and v_cat_kind <> 'income') or (new.type = 'expense' and v_cat_kind <> 'expense') then
      raise exception 'category kind does not match transaction type' using errcode = '23514';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if new.type <> old.type or new.workspace_id <> old.workspace_id
       or new.currency <> old.currency or new.transfer_id is distinct from old.transfer_id
       or (new.account_id <> old.account_id and not v_rpc) then
      raise exception 'type, account, workspace, currency and transfer are immutable' using errcode = '23514';
    end if;
    if (old.status::text, new.status::text) in (('posted', 'failed'), ('failed', 'posted')) then
      raise exception 'invalid status change: go through pending first' using errcode = '23514';
    end if;
    if old.transfer_id is not null and not v_rpc
       and (new.amount_cents <> old.amount_cents or new.status <> old.status
            or new.occurred_at <> old.occurred_at or new.deleted_at is distinct from old.deleted_at) then
      raise exception 'transfer legs are managed through create_transfer/delete_transfer' using errcode = '23514';
    end if;
    if old.invoice_id is not null
       and (new.amount_cents <> old.amount_cents or new.status <> old.status
            or new.occurred_at <> old.occurred_at or new.deleted_at is distinct from old.deleted_at)
       and exists (select 1 from public.credit_card_invoices i where i.id = old.invoice_id and i.status = 'paid') then
      raise exception 'invoice already paid: its transactions are locked' using errcode = '23514';
    end if;
  end if;

  if v_acc_type = 'credit_card' and new.type in ('income', 'expense') then
    if new.invoice_id is null
       or (tg_op = 'UPDATE' and new.occurred_at <> old.occurred_at and new.installment_group_id is null) then
      select closing_day into v_closing from public.credit_card_details where account_id = new.account_id;
      new.invoice_id := private.ensure_invoice(
        new.account_id, private.invoice_ref_month(v_closing, private.local_date(new.occurred_at)));
    end if;
    select * into v_inv from public.credit_card_invoices where id = new.invoice_id;
    if v_inv.account_id <> new.account_id then
      raise exception 'invoice belongs to another account' using errcode = '23514';
    end if;
    if tg_op = 'INSERT' and v_inv.status = 'paid' then
      raise exception 'invoice already paid' using errcode = '23514';
    end if;
  elsif new.invoice_id is not null then
    raise exception 'invoice only applies to credit card income/expense' using errcode = '23514';
  end if;

  return new;
end $function$;

create or replace function public.move_transaction(p_transaction_id uuid, p_account_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
declare
  v_tx      public.transactions%rowtype;
  v_from    public.accounts%rowtype;
  v_to      public.accounts%rowtype;
  v_closing int;
  v_invoice uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;

  select * into v_tx from public.transactions where id = p_transaction_id for update;
  if not found or not public.is_workspace_member(v_tx.workspace_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_tx.deleted_at is not null then
    raise exception 'transaction is deleted' using errcode = '23514';
  end if;
  if v_tx.transfer_id is not null or v_tx.type not in ('income', 'expense') then
    raise exception 'transfer legs cannot be moved' using errcode = '23514';
  end if;

  select * into v_from from public.accounts where id = v_tx.account_id;

  select * into v_to from public.accounts where id = p_account_id;
  if not found or not public.is_workspace_member(v_to.workspace_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_to.workspace_id <> v_tx.workspace_id then
    raise exception 'the account belongs to another workspace' using errcode = '23514';
  end if;
  if v_to.id = v_tx.account_id then
    raise exception 'transaction is already in this account' using errcode = '23514';
  end if;
  if v_to.archived_at is not null then
    raise exception 'the account is archived' using errcode = '23514';
  end if;
  if v_to.currency <> v_tx.currency then
    raise exception 'the account has another currency' using errcode = '23514';
  end if;

  if v_from.type = 'credit_card' or v_tx.invoice_id is not null then
    -- a card purchase can only go back to a bank account, while its invoice is open
    if v_tx.installment_group_id is not null then
      raise exception 'an installment cannot be moved' using errcode = '23514';
    end if;
    if v_to.type = 'credit_card' then
      raise exception 'a card purchase can only go to a bank account' using errcode = '23514';
    end if;
    if exists (select 1 from public.credit_card_invoices i where i.id = v_tx.invoice_id and i.status = 'paid') then
      raise exception 'the invoice is already paid' using errcode = '23514';
    end if;
  elsif v_to.type = 'credit_card' then
    -- an expense of a bank account becomes a purchase on the invoice of its date
    if v_tx.type <> 'expense' then
      raise exception 'only an expense can be moved to a card' using errcode = '23514';
    end if;
    select closing_day into v_closing from public.credit_card_details where account_id = v_to.id;
    if v_closing is null then
      raise exception 'the card has no details' using errcode = '23514';
    end if;
    v_invoice := private.ensure_invoice(
      v_to.id, private.invoice_ref_month(v_closing, private.local_date(v_tx.occurred_at)));
    if exists (select 1 from public.credit_card_invoices i where i.id = v_invoice and i.status = 'paid') then
      raise exception 'the invoice of that date is already paid' using errcode = '23514';
    end if;
  end if;

  -- invoice_id is cleared: the guard gives a card purchase the invoice of its
  -- date, and a purchase that goes back to a bank account has none.
  perform set_config('finly.rpc', 'on', true);
  update public.transactions set account_id = p_account_id, invoice_id = null where id = p_transaction_id;
  perform set_config('finly.rpc', 'off', true);
end $function$;

revoke all on function public.move_transaction(uuid, uuid) from public, anon;
grant execute on function public.move_transaction(uuid, uuid) to authenticated;
