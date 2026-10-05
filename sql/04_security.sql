-- =====================================================================
-- Finly | 04_security.sql
-- Row Level Security + explicit grants. Every policy chains back to
-- workspaces.owner_id = auth.uid() through is_workspace_member().
-- NEVER use "auth.role() = 'authenticated'" as a policy on its own.
-- =====================================================================

alter table public.profiles                enable row level security;
alter table public.user_settings           enable row level security;
alter table public.workspaces              enable row level security;
alter table public.accounts                enable row level security;
alter table public.credit_card_details     enable row level security;
alter table public.credit_card_invoices    enable row level security;
alter table public.transfers               enable row level security;
alter table public.categories              enable row level security;
alter table public.budgets                 enable row level security;
alter table public.recurring_transactions  enable row level security;
alter table public.transactions            enable row level security;
alter table public.audit_logs              enable row level security;
alter table public.push_tokens             enable row level security;
alter table public.app_config              enable row level security;

-- profiles / settings
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid())
              and (active_workspace_id is null or public.is_workspace_member(active_workspace_id)));

create policy settings_select on public.user_settings for select to authenticated
  using (user_id = (select auth.uid()));
create policy settings_update on public.user_settings for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- workspaces (INSERT only through create_workspace())
create policy workspaces_select on public.workspaces for select to authenticated
  using (owner_id = (select auth.uid()));
create policy workspaces_update on public.workspaces for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy workspaces_delete on public.workspaces for delete to authenticated
  using (owner_id = (select auth.uid()));

-- workspace-scoped tables
create policy accounts_all on public.accounts for all to authenticated
  using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy categories_all on public.categories for all to authenticated
  using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy budgets_all on public.budgets for all to authenticated
  using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));
create policy recurring_all on public.recurring_transactions for all to authenticated
  using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));

-- account-scoped tables
create policy cc_details_all on public.credit_card_details for all to authenticated
  using (public.owns_account(account_id)) with check (public.owns_account(account_id));
create policy invoices_select on public.credit_card_invoices for select to authenticated
  using (public.owns_account(account_id));

-- transfers: read-only for clients; legs are written by create_transfer()
create policy transfers_select on public.transfers for select to authenticated
  using (owner_id = (select auth.uid()));

-- transactions: clients may only create income/expense directly
create policy tx_select on public.transactions for select to authenticated
  using (public.is_workspace_member(workspace_id));
create policy tx_insert on public.transactions for insert to authenticated
  with check (public.is_workspace_member(workspace_id)
              and type in ('income', 'expense') and transfer_id is null);
create policy tx_update on public.transactions for update to authenticated
  using (public.is_workspace_member(workspace_id)) with check (public.is_workspace_member(workspace_id));

-- audit: owner can read, nobody can write from the API
create policy audit_select on public.audit_logs for select to authenticated
  using (owner_id = (select auth.uid()));

create policy push_tokens_all on public.push_tokens for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- public, read-only configuration (needed before login for the force-update check)
create policy app_config_read on public.app_config for select to anon, authenticated using (true);

-- ---------- grants (explicit, minimal) ----------------------------------------

revoke all on all tables    in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon;

grant usage on schema public to anon, authenticated;
grant select on public.app_config to anon, authenticated;

grant select on public.profiles to authenticated;
grant update (full_name, active_workspace_id) on public.profiles to authenticated;

grant select on public.user_settings to authenticated;
grant update (theme, locale, lock_timeout_seconds, biometric_enabled, switch_protection,
              notification_prefs, low_balance_cents, accepted_terms_version, accepted_terms_at)
  on public.user_settings to authenticated;

grant select, delete on public.workspaces to authenticated;
grant update (name, tax_reserve_bps) on public.workspaces to authenticated;

grant select, insert, update, delete on public.accounts, public.credit_card_details,
  public.categories, public.budgets, public.recurring_transactions, public.push_tokens to authenticated;

grant select on public.credit_card_invoices, public.transfers, public.audit_logs to authenticated;
grant select, insert, update on public.transactions to authenticated;

grant select on public.account_balances, public.invoice_totals, public.monthly_category_spend to authenticated;

-- RPCs and helpers callable by logged-in users only
grant execute on all functions in schema public to authenticated;
