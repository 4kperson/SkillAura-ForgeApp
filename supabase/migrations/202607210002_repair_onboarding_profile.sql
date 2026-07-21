-- Safe repair for an existing public.profiles table.
-- This migration is additive and may be run more than once.

alter table public.profiles
  add column if not exists onboarding_goal text,
  add column if not exists discipline_level text,
  add column if not exists wake_time time not null default '07:00:00',
  add column if not exists sleep_time time not null default '23:00:00',
  add column if not exists onboarding_step integer not null default 0,
  add column if not exists notifications_enabled boolean,
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists onboarding_updated_at timestamptz;

-- Preserve owner-only access. ENABLE is idempotent and does not change rows.
alter table public.profiles enable row level security;

-- Do not duplicate the policies from the initial schema if they already exist.
do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_select_own'
  ) then
    create policy "profiles_select_own" on public.profiles
      for select using (auth.uid() = id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_update_own'
  ) then
    create policy "profiles_update_own" on public.profiles
      for update using (auth.uid() = id);
  end if;
end;
$$;

-- Verification 1: every field used by the onboarding repository is present,
-- with the PostgreSQL type and nullability expected by the model.
select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name in (
    'onboarding_goal',
    'discipline_level',
    'wake_time',
    'sleep_time',
    'onboarding_step',
    'notifications_enabled',
    'onboarding_completed',
    'onboarding_updated_at'
  )
order by column_name;

-- Verification 2: RLS remains enabled and the relevant owner policies exist.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname = 'profiles';

select
  schemaname,
  tablename,
  policyname,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'profiles'
  and policyname in ('profiles_select_own', 'profiles_update_own')
order by policyname;
