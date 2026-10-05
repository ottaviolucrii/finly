-- =====================================================================
-- Finly | 03_logic.sql
-- Triggers, derived-balance views and RPC functions.
-- Trigger functions and internals live in schema "private" (not exposed
-- by the Supabase API). Public RPCs are SECURITY DEFINER and always check
-- auth.uid() ownership themselves.
-- =====================================================================

-- ---------- access helpers (used by RLS) --------------------------------

-- Today: workspace owner. Shared workspaces later = add a membership check here only.
create or replace function public.is_workspace_member(p_workspace_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
begin
  return exists (
    select 1 from public.workspaces w
    where w.id = p_workspace_id and w.owner_id = (select auth.uid()));
end $$;

create or replace function public.owns_account(p_account_id uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
begin
  return exists (
    select 1 from public.accounts a
    join public.workspaces w on w.id = a.workspace_id
    where a.id = p_account_id and w.owner_id = (select auth.uid()));
end $$;

-- ---------- updated_at ----------------------------------------------------

create trigger trg_profiles_updated     before update on public.profiles               for each row execute function private.set_updated_at();
create trigger trg_settings_updated     before update on public.user_settings          for each row execute function private.set_updated_at();
create trigger trg_workspaces_updated   before update on public.workspaces             for each row execute function private.set_updated_at();
create trigger trg_accounts_updated     before update on public.accounts               for each row execute function private.set_updated_at();
create trigger trg_cc_details_updated   before update on public.credit_card_details    for each row execute function private.set_updated_at();
create trigger trg_invoices_updated     before update on public.credit_card_invoices   for each row execute function private.set_updated_at();
create trigger trg_categories_updated   before update on public.categories             for each row execute function private.set_updated_at();
create trigger trg_budgets_updated      before update on public.budgets                for each row execute function private.set_updated_at();
create trigger trg_recurring_updated    before update on public.recurring_transactions for each row execute function private.set_updated_at();
create trigger trg_transactions_updated before update on public.transactions           for each row execute function private.set_updated_at();
create trigger trg_push_tokens_updated  before update on public.push_tokens            for each row execute function private.set_updated_at();

-- ---------- new auth user -> profile + settings --------------------------

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(nullif(btrim(new.raw_user_meta_data ->> 'full_name'), ''), 'Usuario'));
  insert into public.user_settings (user_id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------- workspace guards ----------------------------------------------

create or replace function private.workspaces_before_write()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.tax_id := private.normalize_tax_id(new.tax_id);
  elsif new.type <> old.type or new.tax_id_type <> old.tax_id_type
     or new.tax_id <> old.tax_id or new.owner_id <> old.owner_id then
    raise exception 'workspace type, tax id and owner are immutable' using errcode = '23514';
  end if;
  return new;
end $$;

create trigger trg_workspaces_guard
  before insert or update on public.workspaces
  for each row execute function private.workspaces_before_write();

-- ---------- credit card invoice engine ------------------------------------

-- Which invoice (reference month) a purchase date belongs to.
create or replace function private.invoice_ref_month(p_closing_day int, p_date date)
returns date language plpgsql immutable as $$
declare v_close date;
begin
  v_close := private.clamp_day(extract(year from p_date)::int, extract(month from p_date)::int, p_closing_day);
  if p_date <= v_close then
    return private.month_start(p_date);
  end if;
  return private.add_months(private.month_start(p_date), 1);
end $$;

-- Gets or creates the invoice of a card for a reference month.
create or replace function private.ensure_invoice(p_account_id uuid, p_ref date)
returns uuid language plpgsql security definer set search_path = public, private as $$
declare
  cc public.credit_card_details%rowtype;
  v_close date; v_prev date; v_due date; v_next date; v_id uuid;
  y int := extract(year from p_ref)::int;
  m int := extract(month from p_ref)::int;
begin
  select * into cc from public.credit_card_details where account_id = p_account_id;
  if not found then
    raise exception 'account % is not a credit card', p_account_id using errcode = '23514';
  end if;

  v_close := private.clamp_day(y, m, cc.closing_day);
  v_prev  := private.add_months(p_ref, -1);
  v_prev  := private.clamp_day(extract(year from v_prev)::int, extract(month from v_prev)::int, cc.closing_day);

  if cc.due_day > cc.closing_day then
    v_due := private.clamp_day(y, m, cc.due_day);
  else
    v_next := private.add_months(p_ref, 1);
    v_due  := private.clamp_day(extract(year from v_next)::int, extract(month from v_next)::int, cc.due_day);
  end if;

  insert into public.credit_card_invoices (account_id, reference_month, period_start, period_end, due_date, status)
  values (p_account_id, p_ref, v_prev + 1, v_close, v_due,
          case when private.local_date(now()) > v_close then 'closed' else 'open' end::public.invoice_status)
  on conflict (account_id, reference_month) do nothing;

  select id into v_id from public.credit_card_invoices
  where account_id = p_account_id and reference_month = p_ref;
  return v_id;
end $$;

-- ---------- transaction guard (validation + automatic invoice) -----------

create or replace function private.tx_before_write()
returns trigger language plpgsql security definer set search_path = public, private as $$
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
    if new.type <> old.type or new.account_id <> old.account_id or new.workspace_id <> old.workspace_id
       or new.currency <> old.currency or new.transfer_id is distinct from old.transfer_id then
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
end $$;

create trigger trg_transactions_guard
  before insert or update on public.transactions
  for each row execute function private.tx_before_write();

-- ---------- audit log (append-only) ----------------------------------------

create or replace function private.audit_row()
returns trigger language plpgsql security definer set search_path = public, private as $$
declare
  v_row jsonb; v_id uuid; v_ws uuid; v_owner uuid;
begin
  if coalesce(current_setting('finly.purge', true), '') = 'on' then return null; end if;

  v_row := to_jsonb(case when tg_op = 'DELETE' then old else new end);
  v_id  := (v_row ->> 'id')::uuid;
  v_ws  := case when tg_table_name = 'workspaces' then v_id else (v_row ->> 'workspace_id')::uuid end;

  select owner_id into v_owner from public.workspaces where id = v_ws;
  v_owner := coalesce(v_owner, (select auth.uid()));
  if v_owner is null then return null; end if;

  insert into public.audit_logs (owner_id, workspace_id, table_name, record_id, action, old_data, new_data, changed_by)
  values (v_owner, v_ws, tg_table_name, v_id, tg_op::public.audit_action,
          case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end,
          (select auth.uid()));
  return null;
end $$;

create or replace function private.audit_guard()
returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('finly.purge', true), '') <> 'on' then
    raise exception 'audit_logs is append-only' using errcode = '42501';
  end if;
  return coalesce(old, new);
end $$;

create trigger trg_audit_workspaces   after insert or update or delete on public.workspaces             for each row execute function private.audit_row();
create trigger trg_audit_accounts     after insert or update or delete on public.accounts               for each row execute function private.audit_row();
create trigger trg_audit_transactions after insert or update or delete on public.transactions           for each row execute function private.audit_row();
create trigger trg_audit_categories   after insert or update or delete on public.categories             for each row execute function private.audit_row();
create trigger trg_audit_budgets      after insert or update or delete on public.budgets                for each row execute function private.audit_row();
create trigger trg_audit_recurring    after insert or update or delete on public.recurring_transactions for each row execute function private.audit_row();

create trigger trg_audit_logs_guard
  before update or delete on public.audit_logs
  for each row execute function private.audit_guard();

-- ---------- derived balances (views respect RLS) ----------------------------

create or replace view public.account_balances with (security_invoker = true) as
select
  a.id           as account_id,
  a.workspace_id,
  a.type,
  a.currency,
  a.opening_balance_cents,
  (a.opening_balance_cents + coalesce(sum(
      case when t.status = 'posted'
           then case when t.type in ('income', 'transfer_in') then t.amount_cents else -t.amount_cents end
      end), 0))::bigint as posted_balance_cents,
  (a.opening_balance_cents + coalesce(sum(
      case when t.status in ('posted', 'pending')
           then case when t.type in ('income', 'transfer_in') then t.amount_cents else -t.amount_cents end
      end), 0))::bigint as projected_balance_cents
from public.accounts a
left join public.transactions t
  on t.account_id = a.id and t.deleted_at is null and t.status <> 'failed'
group by a.id;

create or replace view public.invoice_totals with (security_invoker = true) as
select
  i.id as invoice_id,
  i.account_id,
  coalesce(sum(case when t.type = 'expense' then t.amount_cents else -t.amount_cents end), 0)::bigint as total_cents
from public.credit_card_invoices i
left join public.transactions t
  on t.invoice_id = i.id and t.deleted_at is null and t.status <> 'failed'
group by i.id;

create or replace view public.monthly_category_spend with (security_invoker = true) as
select
  t.workspace_id,
  t.category_id,
  t.currency,
  date_trunc('month', t.occurred_at at time zone 'America/Sao_Paulo')::date as month,
  sum(t.amount_cents)::bigint as spent_cents
from public.transactions t
where t.type = 'expense' and t.deleted_at is null and t.status <> 'failed'
group by t.workspace_id, t.category_id, t.currency, 4;

-- ---------- default categories -----------------------------------------------

create or replace function private.seed_default_categories(p_workspace_id uuid, p_type public.workspace_type)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_type = 'personal' then
    insert into public.categories (workspace_id, name, kind, icon, color, is_default) values
      (p_workspace_id, 'Alimentação',        'expense', 'restaurant',   '#F29D38', true),
      (p_workspace_id, 'Moradia',            'expense', 'home',         '#1A2E44', true),
      (p_workspace_id, 'Transporte',         'expense', 'directions_car','#1060E3', true),
      (p_workspace_id, 'Saúde',              'expense', 'favorite',     '#D64545', true),
      (p_workspace_id, 'Educação',           'expense', 'school',       '#6B5BD2', true),
      (p_workspace_id, 'Lazer',              'expense', 'celebration',  '#2E9E6B', true),
      (p_workspace_id, 'Compras',            'expense', 'shopping_bag', '#C2569B', true),
      (p_workspace_id, 'Contas e serviços',  'expense', 'receipt_long', '#5B6470', true),
      (p_workspace_id, 'Assinaturas',        'expense', 'subscriptions','#3A8FB7', true),
      (p_workspace_id, 'Outros',             'expense', 'category',     '#A8A8A8', true),
      (p_workspace_id, 'Salário',            'income',  'payments',     '#1060E3', true),
      (p_workspace_id, 'Rendimentos',        'income',  'trending_up',  '#2E9E6B', true),
      (p_workspace_id, 'Outros',             'income',  'category',     '#A8A8A8', true);
  else
    insert into public.categories (workspace_id, name, kind, icon, color, is_default) values
      (p_workspace_id, 'Fornecedores',        'expense', 'local_shipping','#F29D38', true),
      (p_workspace_id, 'Folha de pagamento',  'expense', 'groups',        '#1A2E44', true),
      (p_workspace_id, 'Impostos',            'expense', 'account_balance','#D64545', true),
      (p_workspace_id, 'Aluguel',             'expense', 'apartment',     '#6B5BD2', true),
      (p_workspace_id, 'Marketing',           'expense', 'campaign',      '#C2569B', true),
      (p_workspace_id, 'Software e serviços', 'expense', 'cloud',         '#3A8FB7', true),
      (p_workspace_id, 'Transporte',          'expense', 'directions_car','#1060E3', true),
      (p_workspace_id, 'Outros',              'expense', 'category',      '#A8A8A8', true),
      (p_workspace_id, 'Vendas',              'income',  'sell',          '#1060E3', true),
      (p_workspace_id, 'Serviços prestados',  'income',  'handyman',      '#2E9E6B', true),
      (p_workspace_id, 'Rendimentos',         'income',  'trending_up',   '#3A8FB7', true),
      (p_workspace_id, 'Outros',              'income',  'category',      '#A8A8A8', true);
    update public.categories set is_tax = true
    where workspace_id = p_workspace_id and kind = 'expense' and name = 'Impostos';
  end if;
end $$;

-- =====================================================================
-- Public RPC functions (called by the Flutter app)
-- =====================================================================

-- Creates the first/second workspace, seeds categories and activates it.
create or replace function public.create_workspace(p_name text, p_type public.workspace_type, p_tax_id text)
returns public.workspaces language plpgsql security definer set search_path = public, private as $$
declare
  v_uid uuid := auth.uid();
  v_tax text := private.normalize_tax_id(p_tax_id);
  v_tt  public.tax_id_type := case p_type when 'personal' then 'cpf' else 'cnpj' end;
  v_ws  public.workspaces;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if (v_tt = 'cpf' and not public.is_valid_cpf(v_tax)) or (v_tt = 'cnpj' and not public.is_valid_cnpj(v_tax)) then
    raise exception 'invalid_tax_id' using errcode = '22023';
  end if;
  if exists (select 1 from public.workspaces where owner_id = v_uid and type = p_type) then
    raise exception 'workspace_type_already_exists' using errcode = '23505';
  end if;

  insert into public.workspaces (owner_id, name, type, tax_id_type, tax_id)
  values (v_uid, btrim(p_name), p_type, v_tt, v_tax)
  returning * into v_ws;

  perform private.seed_default_categories(v_ws.id, p_type);
  update public.profiles set active_workspace_id = v_ws.id
  where id = v_uid and active_workspace_id is null;
  return v_ws;
end $$;

-- Changes the active workspace (re-authentication is enforced by the app, see SRS FR-W04).
create or replace function public.switch_workspace(p_workspace_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not public.is_workspace_member(p_workspace_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.profiles set active_workspace_id = p_workspace_id where id = auth.uid();
end $$;

-- Two-leg transfer (internal or between the user's own workspaces).
create or replace function public.create_transfer(
  p_from_account uuid, p_to_account uuid, p_amount_cents bigint, p_description text,
  p_occurred_at timestamptz default now(),
  p_kind public.transfer_kind default 'internal',
  p_to_amount_cents bigint default null,
  p_status public.transaction_status default 'posted')
returns uuid language plpgsql security definer set search_path = public, private as $$
declare
  v_uid uuid := auth.uid();
  a_from public.accounts; a_to public.accounts;
  w_from public.workspaces; w_to public.workspaces;
  v_tid uuid; v_to_amount bigint;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if p_amount_cents is null or p_amount_cents <= 0 then raise exception 'amount must be positive'; end if;
  if p_from_account = p_to_account then raise exception 'source and destination must differ'; end if;

  select * into a_from from public.accounts where id = p_from_account;
  select * into a_to   from public.accounts where id = p_to_account;
  if a_from.id is null or a_to.id is null then raise exception 'account not found'; end if;
  select * into w_from from public.workspaces where id = a_from.workspace_id;
  select * into w_to   from public.workspaces where id = a_to.workspace_id;
  if w_from.owner_id <> v_uid or w_to.owner_id <> v_uid then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_kind = 'internal' and a_from.workspace_id <> a_to.workspace_id then
    raise exception 'internal transfers must stay inside one workspace';
  elsif p_kind = 'owner_withdrawal' and not (w_from.type = 'business' and w_to.type = 'personal') then
    raise exception 'owner withdrawal goes from business to personal';
  elsif p_kind = 'owner_contribution' and not (w_from.type = 'personal' and w_to.type = 'business') then
    raise exception 'owner contribution goes from personal to business';
  end if;

  v_to_amount := coalesce(p_to_amount_cents, p_amount_cents);
  if a_from.currency <> a_to.currency and p_to_amount_cents is null then
    raise exception 'destination amount is required for cross-currency transfers';
  end if;
  if a_from.currency = a_to.currency and v_to_amount <> p_amount_cents then
    raise exception 'amounts must match for same-currency transfers';
  end if;

  insert into public.transfers (owner_id, kind) values (v_uid, p_kind) returning id into v_tid;

  insert into public.transactions
    (workspace_id, account_id, currency, type, status, amount_cents, description, occurred_at, transfer_id)
  values
    (a_from.workspace_id, a_from.id, a_from.currency, 'transfer_out', p_status, p_amount_cents, p_description, p_occurred_at, v_tid),
    (a_to.workspace_id,   a_to.id,   a_to.currency,   'transfer_in',  p_status, v_to_amount,    p_description, p_occurred_at, v_tid);

  return v_tid;
end $$;

-- Soft-deletes both legs; reopens an invoice if this transfer had paid it.
create or replace function public.delete_transfer(p_transfer_id uuid)
returns void language plpgsql security definer set search_path = public, private as $$
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.transfers where id = p_transfer_id and owner_id = auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  perform set_config('finly.rpc', 'on', true);
  update public.transactions set deleted_at = now()
  where transfer_id = p_transfer_id and deleted_at is null;

  update public.credit_card_invoices
  set status = case when private.local_date(now()) > period_end then 'closed' else 'open' end::public.invoice_status,
      paid_at = null, paid_by_transfer_id = null
  where paid_by_transfer_id = p_transfer_id;
  perform set_config('finly.rpc', 'off', true);
end $$;

-- Installment purchase on a credit card: N rows spread over consecutive invoices.
-- The first installment absorbs the rounding remainder; later ones start as 'pending'.
create or replace function public.create_installments(
  p_account_id uuid, p_category_id uuid, p_total_cents bigint, p_installments int,
  p_description text, p_purchase_at timestamptz default now())
returns uuid language plpgsql security definer set search_path = public, private as $$
declare
  v_acc public.accounts; v_cc public.credit_card_details;
  v_group uuid := gen_random_uuid();
  v_base bigint; v_rest bigint; v_ref0 date; i int; v_amount bigint;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if p_installments < 2 or p_installments > 48 then raise exception 'installments must be between 2 and 48'; end if;
  if p_total_cents < p_installments then raise exception 'total too small for this many installments'; end if;

  select * into v_acc from public.accounts where id = p_account_id;
  if v_acc.id is null or not public.is_workspace_member(v_acc.workspace_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into v_cc from public.credit_card_details where account_id = p_account_id;
  if v_cc.account_id is null then raise exception 'account is not a credit card'; end if;

  v_base := p_total_cents / p_installments;
  v_rest := p_total_cents - v_base * p_installments;
  v_ref0 := private.invoice_ref_month(v_cc.closing_day, private.local_date(p_purchase_at));

  for i in 1..p_installments loop
    v_amount := v_base + case when i = 1 then v_rest else 0 end;
    insert into public.transactions
      (workspace_id, account_id, currency, category_id, invoice_id, type, status, amount_cents,
       description, occurred_at, installment_group_id, installment_number, installment_total)
    values
      (v_acc.workspace_id, v_acc.id, v_acc.currency, p_category_id,
       private.ensure_invoice(p_account_id, private.add_months(v_ref0, i - 1)),
       'expense', case when i = 1 then 'posted' else 'pending' end::public.transaction_status,
       v_amount, p_description || ' (' || i || '/' || p_installments || ')',
       p_purchase_at + make_interval(months => i - 1), v_group, i, p_installments);
  end loop;
  return v_group;
end $$;

-- Pays the full invoice total from another account (a transfer) and marks it paid.
create or replace function public.pay_invoice(
  p_invoice_id uuid, p_from_account_id uuid, p_paid_at timestamptz default now())
returns uuid language plpgsql security definer set search_path = public, private as $$
declare
  v_inv public.credit_card_invoices; v_total bigint; v_tid uuid;
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
  if v_total <= 0 then raise exception 'nothing to pay on this invoice'; end if;

  v_tid := public.create_transfer(p_from_account_id, v_inv.account_id, v_total,
             'Pagamento fatura ' || to_char(v_inv.reference_month, 'MM/YYYY'), p_paid_at);

  update public.credit_card_invoices
  set status = 'paid', paid_at = now(), paid_by_transfer_id = v_tid
  where id = v_inv.id;
  return v_tid;
end $$;

-- ---------- recurring transactions -----------------------------------------

create or replace function private.generate_recurring_for(t public.recurring_transactions, p_until date)
returns integer language plpgsql security definer set search_path = public, private as $$
declare n int := t.generated_count; d date; created int := 0; v_created_on date := private.local_date(t.created_at);
begin
  loop
    d := private.recurrence_date(t.start_date, t.frequency, t.interval_count, n);
    exit when d > p_until or (t.end_date is not null and d > t.end_date);
    if d >= v_created_on then
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

-- Called by the app on launch: only the caller's templates.
create or replace function public.generate_my_recurring(p_until date default null)
returns integer language plpgsql security definer set search_path = public, private as $$
declare r public.recurring_transactions; total int := 0;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  for r in select * from public.recurring_transactions
           where is_active and public.is_workspace_member(workspace_id)
  loop
    total := total + private.generate_recurring_for(r, coalesce(p_until, private.local_date(now()) + 35));
  end loop;
  return total;
end $$;

-- Called by the daily job (see 06_jobs.sql): every active template.
create or replace function private.generate_all_recurring(p_until date default null)
returns integer language plpgsql security definer set search_path = public, private as $$
declare r public.recurring_transactions; total int := 0;
begin
  for r in select * from public.recurring_transactions where is_active loop
    total := total + private.generate_recurring_for(r, coalesce(p_until, private.local_date(now()) + 35));
  end loop;
  return total;
end $$;

-- ---------- maintenance jobs ------------------------------------------------

create or replace function private.close_due_invoices()
returns integer language plpgsql security definer set search_path = public, private as $$
declare n int;
begin
  update public.credit_card_invoices set status = 'closed'
  where status = 'open' and period_end < private.local_date(now());
  get diagnostics n = row_count;
  return n;
end $$;

-- Hard-deletes transactions soft-deleted more than p_days ago (trash retention).
create or replace function private.purge_deleted(p_days int default 30)
returns integer language plpgsql security definer set search_path = public, private as $$
declare n int;
begin
  delete from public.transactions where deleted_at < now() - make_interval(days => p_days);
  get diagnostics n = row_count;
  delete from public.transfers t
  where not exists (select 1 from public.transactions x where x.transfer_id = t.id);
  return n;
end $$;

-- ---------- account deletion (LGPD erasure) -----------------------------------

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public, private as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  perform set_config('finly.purge', 'on', true);
  delete from public.audit_logs where owner_id = v_uid;
  delete from auth.users where id = v_uid;   -- cascades to every user-owned row
end $$;
