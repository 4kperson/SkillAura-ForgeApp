-- Add multi-goal onboarding persistence without changing legacy profile data.
alter table public.profiles
  add column if not exists onboarding_goals text[] not null default '{}'::text[];

-- Verification: expected column, type, nullability, and default.
select
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name = 'onboarding_goals';
