-- =====================================================================
-- Finly | 99_reset_dev.sql
-- DEV ONLY. Drops every table, view, function and enum type in schema
-- "public" plus schema "private", so 00..06 can be re-applied from zero.
-- It does NOT touch auth.users (your test accounts stay).
-- NEVER run this on a database with real data.
-- =====================================================================
do $$
declare r record;
begin
  drop trigger if exists on_auth_user_created on auth.users;

  for r in select viewname from pg_views where schemaname = 'public' loop
    execute format('drop view if exists public.%I cascade', r.viewname);
  end loop;

  for r in select tablename from pg_tables where schemaname = 'public' loop
    execute format('drop table if exists public.%I cascade', r.tablename);
  end loop;

  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind in ('f', 'p')
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('drop function if exists %s cascade', r.sig);
  end loop;

  for r in
    select t.typname from pg_type t join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public' and t.typtype = 'e'
  loop
    execute format('drop type if exists public.%I cascade', r.typname);
  end loop;
end $$;

drop schema if exists private cascade;
