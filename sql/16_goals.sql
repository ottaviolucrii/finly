-- =====================================================================
-- Finly | 16_goals.sql
-- Savings goals ("metas"). Run after 00..15.
--
-- A goal follows one account (a bank account, savings or investment, never a
-- credit card): its progress is the posted balance of that account, so there is
-- no second number to keep in step and nothing is counted twice. The account
-- must be of the same workspace and currency (a composite foreign key, like
-- transactions), and a name can be used once among the goals that are not
-- archived. Same security as the other tables: Row Level Security by workspace
-- membership, the audit trigger and the updated_at trigger.
-- =====================================================================

create table public.goals (
  id            uuid primary key default gen_random_uuid(),
  workspace_id  uuid not null references public.workspaces (id) on delete cascade,
  account_id    uuid not null,
  currency      text not null,
  name          text not null,
  target_cents  bigint not null,
  target_date   date,
  archived_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint goals_name_check     check (char_length(btrim(name)) between 1 and 80),
  constraint goals_target_check   check (target_cents > 0),
  constraint goals_currency_check check (currency ~ '^[A-Z]{3}$'),
  constraint goals_account_fkey   foreign key (account_id, workspace_id, currency)
    references public.accounts (id, workspace_id, currency) on delete cascade
);

create unique index goals_workspace_name_uidx
  on public.goals (workspace_id, lower(name)) where archived_at is null;
create index goals_workspace_idx on public.goals (workspace_id, created_at);

-- A credit card balance is debt, not savings; the workspace and the currency of
-- a goal never change; the name is trimmed.
create or replace function private.goals_guard()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'private'
as $function$
declare
  v_type public.account_type;
begin
  select type into v_type from public.accounts where id = new.account_id;
  if v_type = 'credit_card' then
    raise exception 'a goal cannot follow a credit card' using errcode = '23514';
  end if;

  if tg_op = 'UPDATE' and (new.workspace_id <> old.workspace_id or new.currency <> old.currency) then
    raise exception 'workspace and currency of a goal are immutable' using errcode = '23514';
  end if;

  new.name := btrim(new.name);
  return new;
end $function$;

create trigger trg_goals_guard
  before insert or update on public.goals
  for each row execute function private.goals_guard();
create trigger trg_goals_updated
  before update on public.goals
  for each row execute function private.set_updated_at();
create trigger trg_audit_goals
  after insert or update or delete on public.goals
  for each row execute function private.audit_row();

alter table public.goals enable row level security;

create policy goals_all on public.goals
  for all
  using (public.is_workspace_member(workspace_id))
  with check (public.is_workspace_member(workspace_id));

revoke all on public.goals from public, anon;
grant select, insert, update, delete on public.goals to authenticated;
