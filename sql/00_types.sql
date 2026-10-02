-- =====================================================================
-- Finly | 00_types.sql
-- Enumerated types. Run first. Idempotent only on a clean database.
-- =====================================================================

create type public.workspace_type       as enum ('personal', 'business');
create type public.tax_id_type          as enum ('cpf', 'cnpj');
create type public.account_type         as enum ('checking', 'savings', 'investment', 'credit_card');
create type public.transaction_type     as enum ('income', 'expense', 'transfer_in', 'transfer_out');
create type public.transaction_status   as enum ('pending', 'posted', 'failed');
create type public.category_kind        as enum ('income', 'expense');
create type public.invoice_status       as enum ('open', 'closed', 'paid');
create type public.recurrence_frequency as enum ('daily', 'weekly', 'monthly', 'yearly');
create type public.transfer_kind        as enum ('internal', 'owner_withdrawal', 'owner_contribution');
create type public.audit_action         as enum ('INSERT', 'UPDATE', 'DELETE');
create type public.switch_protection    as enum ('confirm', 'biometric', 'password');
create type public.theme_mode           as enum ('system', 'light', 'dark');
