-- =====================================================================
-- Finly | 02_tables.sql
-- Tables, constraints and indexes. Balances are NEVER stored: they are
-- derived by views from opening_balance_cents + transactions (see 03).
-- =====================================================================

-- ---------- identity ---------------------------------------------------

create table public.profiles (
  id                  uuid primary key references auth.users (id) on delete cascade,
  full_name           text not null check (char_length(btrim(full_name)) between 2 and 120),
  active_workspace_id uuid,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
comment on table public.profiles is 'One row per auth user. E-mail and password live in auth.users only.';

create table public.user_settings (
  user_id               uuid primary key references public.profiles (id) on delete cascade,
  theme                 public.theme_mode not null default 'system',
  locale                text not null default 'pt-BR' check (locale in ('pt-BR', 'en')),
  lock_timeout_seconds  integer not null default 120 check (lock_timeout_seconds between 0 and 900),
  biometric_enabled     boolean not null default false,
  switch_protection     public.switch_protection not null default 'confirm',
  notification_prefs    jsonb not null default
    '{"card_due":true,"low_balance":true,"bill_reminder":true,"budget_alert":true,"pending_digest":true}',
  low_balance_cents     bigint not null default 0 check (low_balance_cents >= 0),
  accepted_terms_version text,
  accepted_terms_at     timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create table public.workspaces (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references public.profiles (id) on delete cascade,
  name            text not null check (char_length(btrim(name)) between 1 and 80),
  type            public.workspace_type not null,
  tax_id_type     public.tax_id_type not null,
  tax_id          text not null,
  base_currency   text not null default 'BRL' check (base_currency ~ '^[A-Z]{3}$'),
  tax_reserve_bps integer not null default 0 check (tax_reserve_bps between 0 and 10000),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint workspaces_one_per_type unique (owner_id, type),
  constraint workspaces_type_matches_tax_id check (
    (type = 'personal' and tax_id_type = 'cpf') or (type = 'business' and tax_id_type = 'cnpj')),
  constraint workspaces_tax_id_valid check (
    (tax_id_type = 'cpf'  and public.is_valid_cpf(tax_id)) or
    (tax_id_type = 'cnpj' and public.is_valid_cnpj(tax_id))),
  constraint workspaces_tax_reserve_business_only check (type = 'business' or tax_reserve_bps = 0)
);
comment on column public.workspaces.tax_reserve_bps is 'Tax reserve rate in basis points (1% = 100). Integer on purpose: no floats.';

alter table public.profiles
  add constraint profiles_active_workspace_fk
  foreign key (active_workspace_id) references public.workspaces (id) on delete set null;

-- ---------- accounts & credit cards -----------------------------------

create table public.accounts (
  id                    uuid primary key default gen_random_uuid(),
  workspace_id          uuid not null references public.workspaces (id) on delete cascade,
  name                  text not null check (char_length(btrim(name)) between 1 and 80),
  type                  public.account_type not null,
  currency              text not null default 'BRL' check (currency ~ '^[A-Z]{3}$'),
  opening_balance_cents bigint not null default 0,
  archived_at           timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint accounts_id_workspace_currency_key unique (id, workspace_id, currency),
  constraint accounts_id_workspace_key          unique (id, workspace_id),
  constraint accounts_id_type_key               unique (id, type)
);
create unique index accounts_workspace_name_uidx
  on public.accounts (workspace_id, lower(name)) where archived_at is null;

create table public.credit_card_details (
  account_id   uuid primary key,
  account_type public.account_type not null default 'credit_card' check (account_type = 'credit_card'),
  limit_cents  bigint not null check (limit_cents >= 0),
  closing_day  smallint not null check (closing_day between 1 and 31),
  due_day      smallint not null check (due_day between 1 and 31),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  foreign key (account_id, account_type) references public.accounts (id, type) on delete cascade
);

create table public.transfers (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references public.profiles (id) on delete cascade,
  kind       public.transfer_kind not null default 'internal',
  created_at timestamptz not null default now()
);

create table public.credit_card_invoices (
  id                  uuid primary key default gen_random_uuid(),
  account_id          uuid not null references public.credit_card_details (account_id) on delete cascade,
  reference_month     date not null check (extract(day from reference_month) = 1),
  period_start        date not null,
  period_end          date not null,
  due_date            date not null,
  status              public.invoice_status not null default 'open',
  paid_at             timestamptz,
  paid_by_transfer_id uuid references public.transfers (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint invoices_one_per_month unique (account_id, reference_month),
  constraint invoices_period_valid check (period_end >= period_start and due_date >= period_end),
  constraint invoices_paid_shape   check ((status = 'paid') = (paid_at is not null))
);

-- ---------- categories, budgets, recurring ----------------------------

create table public.categories (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  name         text not null check (char_length(btrim(name)) between 1 and 60),
  kind         public.category_kind not null,
  icon         text not null default 'category',
  color        text not null default '#A8A8A8' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  is_default   boolean not null default false,
  is_tax       boolean not null default false check (not is_tax or kind = 'expense'),
  archived_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint categories_id_workspace_key      unique (id, workspace_id),
  constraint categories_id_workspace_kind_key unique (id, workspace_id, kind)
);
create unique index categories_workspace_kind_name_uidx
  on public.categories (workspace_id, kind, lower(name));

create table public.budgets (
  id            uuid primary key default gen_random_uuid(),
  workspace_id  uuid not null references public.workspaces (id) on delete cascade,
  category_id   uuid not null,
  category_kind public.category_kind not null default 'expense' check (category_kind = 'expense'),
  effective_from date not null check (extract(day from effective_from) = 1),
  limit_cents   bigint not null check (limit_cents > 0),
  currency      text not null default 'BRL' check (currency ~ '^[A-Z]{3}$'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  foreign key (category_id, workspace_id, category_kind)
    references public.categories (id, workspace_id, kind),
  constraint budgets_version_key unique (workspace_id, category_id, effective_from)
);
comment on table public.budgets is 'Monthly limit per expense category. The limit for month M is the row with the greatest effective_from <= M.';

create table public.recurring_transactions (
  id              uuid primary key default gen_random_uuid(),
  workspace_id    uuid not null references public.workspaces (id) on delete cascade,
  account_id      uuid not null,
  currency        text not null,
  category_id     uuid,
  type            public.transaction_type not null check (type in ('income', 'expense')),
  amount_cents    bigint not null check (amount_cents > 0),
  description     text not null check (char_length(btrim(description)) between 1 and 200),
  frequency       public.recurrence_frequency not null,
  interval_count  smallint not null default 1 check (interval_count between 1 and 52),
  start_date      date not null,
  end_date        date,
  lead_days       smallint not null default 3 check (lead_days between 0 and 30),
  generated_count integer not null default 0 check (generated_count >= 0),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check (end_date is null or end_date >= start_date),
  foreign key (account_id, workspace_id, currency) references public.accounts (id, workspace_id, currency),
  foreign key (category_id, workspace_id)          references public.categories (id, workspace_id)
);

-- ---------- transactions ----------------------------------------------

create table public.transactions (
  id                 uuid primary key default gen_random_uuid(),
  workspace_id       uuid not null references public.workspaces (id) on delete cascade,
  account_id         uuid not null,
  currency           text not null,
  category_id        uuid,
  invoice_id         uuid references public.credit_card_invoices (id),
  recurring_id       uuid references public.recurring_transactions (id),
  scheduled_for      date,
  transfer_id        uuid references public.transfers (id) on delete cascade,
  installment_group_id uuid,
  installment_number smallint,
  installment_total  smallint,
  type               public.transaction_type not null,
  status             public.transaction_status not null,
  amount_cents       bigint not null check (amount_cents > 0),
  description        text not null check (char_length(btrim(description)) between 1 and 200),
  notes              text check (char_length(notes) <= 2000),
  occurred_at        timestamptz not null,
  receipt_path       text,
  deleted_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  -- account must live in the same workspace and share the currency
  constraint tx_account_fk  foreign key (account_id, workspace_id, currency)
    references public.accounts (id, workspace_id, currency),
  constraint tx_category_fk foreign key (category_id, workspace_id)
    references public.categories (id, workspace_id),
  constraint tx_transfer_shape check ((type in ('transfer_in', 'transfer_out')) = (transfer_id is not null)),
  constraint tx_transfer_no_category check (transfer_id is null or category_id is null),
  constraint tx_recurring_shape check ((recurring_id is null) = (scheduled_for is null)),
  constraint tx_installment_shape check (
    (installment_group_id is null and installment_number is null and installment_total is null) or
    (installment_group_id is not null and installment_total between 2 and 48
       and installment_number between 1 and installment_total))
);

create index tx_workspace_date_idx on public.transactions (workspace_id, occurred_at desc) where deleted_at is null;
create index tx_account_date_idx   on public.transactions (account_id, occurred_at desc);
create index tx_invoice_idx        on public.transactions (invoice_id) where invoice_id is not null;
create index tx_category_idx       on public.transactions (category_id) where category_id is not null;
create index tx_transfer_idx       on public.transactions (transfer_id) where transfer_id is not null;
create unique index tx_recurring_occurrence_uidx
  on public.transactions (recurring_id, scheduled_for) where recurring_id is not null;

-- ---------- audit & devices -------------------------------------------

create table public.audit_logs (
  id           bigint generated always as identity primary key,
  owner_id     uuid not null,           -- no FK on purpose: removed only by delete_my_account()
  workspace_id uuid,
  table_name   text not null,
  record_id    uuid not null,
  action       public.audit_action not null,
  old_data     jsonb,
  new_data     jsonb,
  changed_by   uuid,
  occurred_at  timestamptz not null default now()
);
create index audit_owner_idx  on public.audit_logs (owner_id, occurred_at desc);
create index audit_ws_idx     on public.audit_logs (workspace_id, occurred_at desc);
create index audit_record_idx on public.audit_logs (table_name, record_id);

create table public.push_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  token      text not null unique,
  platform   text not null check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now()
);

-- ---------- remote app configuration (force-update check) ---------------

create table public.app_config (
  key   text primary key,
  value jsonb not null
);
insert into public.app_config (key, value)
values ('min_app_version', '{"android":"1.0.0","ios":"1.0.0"}');
