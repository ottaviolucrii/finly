-- =====================================================================
-- Finly | 08_credit_card.sql
-- Creates a credit card in ONE operation: the card account and its settings
-- (limit, closing day, due day). Two separate inserts from the app could
-- leave a card account without settings if the second one failed.
-- Run after 00..07. Safe to re-run.
-- =====================================================================

create or replace function public.create_credit_card(
  p_workspace_id uuid,
  p_name         text,
  p_currency     text,
  p_limit_cents  bigint,
  p_closing_day  integer,
  p_due_day      integer)
returns uuid
language plpgsql security definer set search_path = public, private as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if not public.is_workspace_member(p_workspace_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;

  -- A card starts with no debt: opening balance 0.
  insert into public.accounts (workspace_id, name, type, currency, opening_balance_cents)
  values (p_workspace_id, btrim(p_name), 'credit_card', p_currency, 0)
  returning id into v_id;

  insert into public.credit_card_details (account_id, limit_cents, closing_day, due_day)
  values (v_id, p_limit_cents, p_closing_day, p_due_day);

  return v_id;
end $$;

revoke all on function public.create_credit_card(uuid, text, text, bigint, integer, integer) from public, anon;
grant execute on function public.create_credit_card(uuid, text, text, bigint, integer, integer) to authenticated;