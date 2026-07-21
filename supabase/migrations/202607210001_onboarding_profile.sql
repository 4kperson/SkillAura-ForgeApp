alter table public.profiles
  add column if not exists onboarding_goal text,
  add column if not exists discipline_level text,
  add column if not exists wake_time time not null default '07:00:00',
  add column if not exists sleep_time time not null default '23:00:00',
  add column if not exists onboarding_step integer not null default 0,
  add column if not exists notifications_enabled boolean,
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists onboarding_updated_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_onboarding_goal_check,
  add constraint profiles_onboarding_goal_check check (
    onboarding_goal is null or onboarding_goal in (
      'disciplined', 'healthier', 'productive', 'student',
      'entrepreneur', 'betterHabits'
    )
  ),
  drop constraint if exists profiles_discipline_level_check,
  add constraint profiles_discipline_level_check check (
    discipline_level is null or discipline_level in (
      'starting', 'improving', 'consistent'
    )
  ),
  drop constraint if exists profiles_onboarding_step_check,
  add constraint profiles_onboarding_step_check check (
    onboarding_step between 0 and 6
  );
