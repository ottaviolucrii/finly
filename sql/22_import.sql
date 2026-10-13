-- 22: importing a bank statement (OFX or CSV) into an account.
-- Each imported line may carry the bank's own id (external_id, the FITID of
-- an OFX), so importing the same file twice never doubles anything. Without
-- it (most CSVs), a line is a duplicate when the account already has one on
-- the same day, with the same amount, type and description.
-- import_transactions() checks (p_dry_run) or saves all the lines at once:
-- a real error saves nothing. Lines that would fall in an invoice already
-- paid are skipped and counted, not an error.
-- Run once in the Supabase SQL editor, after 21.

alter table public.transactions
  add column if not exists external_id text check (char_length(external_id) between 1 and 120);

create unique index if not exists transactions_account_external_key
  on public.transactions (account_id, external_id) where external_id is not null;

-- The lines, as the app sends them: [{ "external_id": "...", "date":
-- "YYYY-MM-DD", "amount_cents": -1290, "description": "...", "category_id":
-- "..." }, ...]. A negative amount is money going out (an expense), a
-- positive one money coming in (an income; on a card, a credit).
-- Returns, per line, 'new', 'duplicate' or 'paid_invoice', and the totals.
create or replace function public.import_transactions(p_account uuid, p_rows jsonb, p_dry_run boolean default true)
returns jsonb
  language plpgsql security invoker set search_path = public as $$
declare
  v_account  accounts%rowtype;
  v_row      jsonb;
  v_index    integer := 0;
  v_date     date;
  v_amount   bigint;
  v_type     transaction_type;
  v_desc     text;
  v_ext      text;
  v_cat      uuid;
  v_status   text;
  v_statuses jsonb := '[]'::jsonb;
  v_new      integer := 0;
  v_dup      integer := 0;
  v_paid     integer := 0;
begin
  select * into v_account from accounts where id = p_account and archived_at is null;
  if not found then
    raise exception 'account_not_found' using errcode = 'P0002';
  end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 or jsonb_array_length(p_rows) > 1000 then
    raise exception 'invalid_rows' using errcode = '22023';
  end if;

  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_index := v_index + 1;
    begin
      v_date := (v_row ->> 'date')::date;
      v_amount := (v_row ->> 'amount_cents')::bigint;
    exception when others then
      raise exception 'invalid_row %', v_index using errcode = '22023';
    end;
    v_desc := left(btrim(coalesce(v_row ->> 'description', '')), 200);
    v_ext := nullif(left(btrim(coalesce(v_row ->> 'external_id', '')), 120), '');
    if v_date is null or v_amount is null or v_amount = 0 or v_desc = ''
       or v_date > current_date + 400 or v_date < current_date - 3700 then
      raise exception 'invalid_row %', v_index using errcode = '22023';
    end if;
    v_type := case when v_amount < 0 then 'expense' else 'income' end;

    -- the category only when it exists in the workspace and fits the type
    v_cat := null;
    if v_row ->> 'category_id' is not null then
      select c.id into v_cat from categories c
      where c.id = (v_row ->> 'category_id')::uuid
        and c.workspace_id = v_account.workspace_id
        and c.archived_at is null
        and c.kind::text = v_type::text;
    end if;

    if (v_ext is not null and exists (
          select 1 from transactions t where t.account_id = p_account and t.external_id = v_ext))
       or exists (
          select 1 from transactions t
          where t.account_id = p_account
            and t.deleted_at is null
            and t.type = v_type
            and t.amount_cents = abs(v_amount)
            and (t.occurred_at at time zone 'America/Sao_Paulo')::date = v_date
            and lower(btrim(t.description)) = lower(v_desc)) then
      v_status := 'duplicate';
      v_dup := v_dup + 1;
    elsif p_dry_run then
      v_status := 'new';
      v_new := v_new + 1;
    else
      begin
        insert into transactions (workspace_id, account_id, category_id, type, status, amount_cents,
                                  currency, description, occurred_at, external_id)
        values (v_account.workspace_id, p_account, v_cat, v_type, 'posted', abs(v_amount),
                v_account.currency, v_desc, (v_date + time '12:00') at time zone 'America/Sao_Paulo', v_ext);
        v_status := 'new';
        v_new := v_new + 1;
      exception when others then
        if sqlerrm like '%invoice already paid%' then
          v_status := 'paid_invoice';
          v_paid := v_paid + 1;
        else
          raise;
        end if;
      end;
    end if;
    v_statuses := v_statuses || to_jsonb(v_status);
  end loop;

  return jsonb_build_object('rows', v_statuses, 'new', v_new, 'duplicates', v_dup, 'paid_invoice', v_paid);
end $$;

grant execute on function public.import_transactions(uuid, jsonb, boolean) to authenticated;

-- The usual category for many descriptions at once (the preview of an import).
create or replace function public.suggest_categories(p_workspace uuid, p_descriptions text[], p_type public.transaction_type)
returns table (description text, category_id uuid)
  language sql stable security invoker set search_path = public as $$
  select d, public.suggest_category(p_workspace, d, p_type)
  from unnest(p_descriptions[1:300]) as d;
$$;

grant execute on function public.suggest_categories(uuid, text[], public.transaction_type) to authenticated;
