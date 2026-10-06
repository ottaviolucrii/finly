-- =====================================================================
-- Finly | 14_restore_transfer.sql
-- Brings a deleted transfer back, both legs together (the trash screen uses it).
-- SECURITY DEFINER like delete_transfer: the guard on transfer legs only lets
-- the functions through.
-- A transfer that touches a credit card (an invoice payment) is refused: its
-- link to the invoice was cleared when it was deleted, so restoring only the
-- money would lower the card debt while the invoice stays open. The invoice
-- has to be paid again.
-- Run after 00..13.
-- =====================================================================

create or replace function public.restore_transfer(p_transfer_id uuid)
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
  if not exists (select 1 from public.transactions where transfer_id = p_transfer_id and deleted_at is not null) then
    raise exception 'transfer is not deleted' using errcode = '23514';
  end if;
  if exists (
    select 1 from public.transactions t join public.accounts a on a.id = t.account_id
    where t.transfer_id = p_transfer_id and a.type = 'credit_card'
  ) then
    raise exception 'a card payment cannot be restored: pay the invoice again' using errcode = '23514';
  end if;

  perform set_config('finly.rpc', 'on', true);
  update public.transactions set deleted_at = null
  where transfer_id = p_transfer_id and deleted_at is not null;
  perform set_config('finly.rpc', 'off', true);
end $function$;

revoke all on function public.restore_transfer(uuid) from public, anon;
grant execute on function public.restore_transfer(uuid) to authenticated;