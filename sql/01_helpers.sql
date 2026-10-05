-- =====================================================================
-- Finly | 01_helpers.sql
-- Private schema + pure helper functions (no table access).
-- =====================================================================

create schema if not exists private;
revoke all on schema private from public;

-- ---------- tax id helpers -------------------------------------------

-- Keeps only letters/digits and upper-cases them (CPF/CNPJ masks removed).
create or replace function private.normalize_tax_id(p_value text)
returns text language sql immutable as $$
  select upper(regexp_replace(coalesce(p_value, ''), '[^0-9A-Za-z]', '', 'g'))
$$;

-- CPF: 11 digits, two mod-11 check digits, rejects repeated digits.
create or replace function public.is_valid_cpf(p_cpf text)
returns boolean language plpgsql immutable as $$
declare
  s int; r int; i int;
begin
  if p_cpf is null or p_cpf !~ '^[0-9]{11}$' then return false; end if;
  if p_cpf ~ '^(.)\1{10}$' then return false; end if;

  s := 0;
  for i in 1..9 loop s := s + substr(p_cpf, i, 1)::int * (11 - i); end loop;
  r := (s * 10) % 11; if r = 10 then r := 0; end if;
  if r <> substr(p_cpf, 10, 1)::int then return false; end if;

  s := 0;
  for i in 1..10 loop s := s + substr(p_cpf, i, 1)::int * (12 - i); end loop;
  r := (s * 10) % 11; if r = 10 then r := 0; end if;
  return r = substr(p_cpf, 11, 1)::int;
end $$;

-- CNPJ (numeric and alphanumeric, Receita Federal IN RFB 2.229/2024):
-- 12 chars [0-9A-Z] + 2 numeric check digits; value of a char = ASCII - 48.
create or replace function public.is_valid_cnpj(p_cnpj text)
returns boolean language plpgsql immutable as $$
declare
  w1 int[] := array[5,4,3,2,9,8,7,6,5,4,3,2];
  w2 int[] := array[6,5,4,3,2,9,8,7,6,5,4,3,2];
  v  int[] := '{}';
  s int; r int; i int; dv1 int; dv2 int;
begin
  if p_cnpj is null or p_cnpj !~ '^[0-9A-Z]{12}[0-9]{2}$' then return false; end if;
  if p_cnpj ~ '^(.)\1{13}$' then return false; end if;

  for i in 1..14 loop v[i] := ascii(substr(p_cnpj, i, 1)) - 48; end loop;

  s := 0;
  for i in 1..12 loop s := s + v[i] * w1[i]; end loop;
  r := s % 11; dv1 := case when r < 2 then 0 else 11 - r end;
  if dv1 <> v[13] then return false; end if;

  s := 0;
  for i in 1..13 loop s := s + v[i] * w2[i]; end loop;
  r := s % 11; dv2 := case when r < 2 then 0 else 11 - r end;
  return dv2 = v[14];
end $$;

-- ---------- date helpers ---------------------------------------------

create or replace function private.local_date(p_ts timestamptz)
returns date language sql stable as $$
  select (p_ts at time zone 'America/Sao_Paulo')::date
$$;

create or replace function private.month_start(p_date date)
returns date language sql immutable as $$
  select make_date(extract(year from p_date)::int, extract(month from p_date)::int, 1)
$$;

-- Adds months; Postgres clamps to month end (Jan 31 + 1 month = Feb 28/29).
create or replace function private.add_months(p_date date, p_months int)
returns date language sql immutable as $$
  select (p_date + make_interval(months => p_months))::date
$$;

-- Day-of-month clamped to the last day of that month.
create or replace function private.clamp_day(p_year int, p_month int, p_day int)
returns date language sql immutable as $$
  select make_date(
    p_year, p_month,
    least(p_day, extract(day from (make_date(p_year, p_month, 1) + interval '1 month - 1 day'))::int)
  )
$$;

-- n-th occurrence of a recurrence (index based => no month-end drift).
create or replace function private.recurrence_date(
  p_start date, p_freq public.recurrence_frequency, p_interval int, p_n int)
returns date language sql immutable as $$
  select case p_freq
    when 'daily'   then p_start + (p_n * p_interval)
    when 'weekly'  then p_start + (p_n * p_interval * 7)
    when 'monthly' then private.add_months(p_start, p_n * p_interval)
    when 'yearly'  then private.add_months(p_start, 12 * p_n * p_interval)
  end
$$;

-- ---------- generic triggers -----------------------------------------

create or replace function private.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;
