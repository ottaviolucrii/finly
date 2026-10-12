-- 19: AI quick add ("escreva como você falaria").
-- The person turns the AI on in the app (ai_settings). Each use goes through
-- ai_take_quota(), which counts uses per day and refuses past the limit, so a
-- bug or abuse can never run up the bill. Only the Edge Function calls it.
-- Run once in the Supabase SQL editor.

create table if not exists public.ai_settings (
  user_id      uuid primary key references public.profiles (id) on delete cascade,
  enabled      boolean not null default false,
  consented_at timestamptz,
  updated_at   timestamptz not null default now()
);

alter table public.ai_settings enable row level security;

drop policy if exists ai_settings_select_own on public.ai_settings;
create policy ai_settings_select_own on public.ai_settings
  for select to authenticated using (user_id = auth.uid());

drop policy if exists ai_settings_insert_own on public.ai_settings;
create policy ai_settings_insert_own on public.ai_settings
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists ai_settings_update_own on public.ai_settings;
create policy ai_settings_update_own on public.ai_settings
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update on public.ai_settings to authenticated;

-- Uses per person per day (Brazil time). Readable by its owner; changed only
-- by ai_take_quota().
create table if not exists public.ai_usage (
  user_id uuid    not null references public.profiles (id) on delete cascade,
  day     date    not null,
  uses    integer not null default 0 check (uses >= 0),
  primary key (user_id, day)
);

alter table public.ai_usage enable row level security;

drop policy if exists ai_usage_select_own on public.ai_usage;
create policy ai_usage_select_own on public.ai_usage
  for select to authenticated using (user_id = auth.uid());

grant select on public.ai_usage to authenticated;

-- The daily limit lives here, on the server: the app cannot change it.
create or replace function public.ai_daily_limit() returns integer
  language sql immutable as $$ select 60 $$;

-- Takes one use of today's quota. Returns:
--   'ok'       the use was counted
--   'disabled' the person has not turned the AI on
--   'limit'    today's limit was reached (nothing counted)
create or replace function public.ai_take_quota() returns text
  language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_day  date := (now() at time zone 'America/Sao_Paulo')::date;
  v_uses integer;
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  if not exists (select 1 from ai_settings where user_id = v_uid and enabled) then
    return 'disabled';
  end if;

  insert into ai_usage (user_id, day, uses) values (v_uid, v_day, 1)
  on conflict (user_id, day) do update
    set uses = ai_usage.uses + 1
    where ai_usage.uses < ai_daily_limit()
  returning uses into v_uses;

  return case when v_uses is null then 'limit' else 'ok' end;
end $$;

revoke all on function public.ai_take_quota() from public;
grant execute on function public.ai_take_quota() to authenticated;
