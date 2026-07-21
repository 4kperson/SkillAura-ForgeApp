-- Repair profile creation, persist onboarding as real habits, and keep daily
-- progression server-owned. This migration is additive and idempotent.

create extension if not exists pgcrypto;

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  xp_reward integer not null default 10 check (xp_reward between 0 and 500),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.habit_completions (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  completed_on date not null,
  created_at timestamptz not null default now()
);

alter table public.profiles
  add column if not exists onboarding_goal text,
  add column if not exists onboarding_goals text[] not null default '{}'::text[],
  add column if not exists discipline_level text,
  add column if not exists wake_time time not null default '07:00:00',
  add column if not exists sleep_time time not null default '23:00:00',
  add column if not exists onboarding_step integer not null default 0,
  add column if not exists notifications_enabled boolean,
  add column if not exists onboarding_completed boolean not null default false,
  add column if not exists onboarding_updated_at timestamptz;

alter table public.profiles
  add column if not exists notification_permission_state text not null default 'undecided';

alter table public.habits
  add column if not exists source text not null default 'user',
  add column if not exists source_key text,
  add column if not exists scheduled_time time,
  add column if not exists effort_minutes integer;

update public.profiles
set onboarding_goals = case onboarding_goal
  when 'entrepreneur' then array['productive']::text[]
  when 'betterHabits' then array['disciplined']::text[]
  else array[onboarding_goal]::text[]
end
where cardinality(onboarding_goals) = 0
  and onboarding_goal is not null;

update public.profiles
set notification_permission_state = case
  when notifications_enabled then 'granted'
  else 'denied'
end
where notification_permission_state = 'undecided'
  and notifications_enabled is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_notification_permission_state_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_notification_permission_state_check check (
        notification_permission_state in ('undecided', 'granted', 'denied', 'skipped')
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'habits_source_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits
      add constraint habits_source_check check (source in ('user', 'onboarding'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'habits_effort_minutes_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits
      add constraint habits_effort_minutes_check check (
        effort_minutes is null or effort_minutes between 1 and 1440
      );
  end if;
end;
$$;

create unique index if not exists habits_onboarding_source_key_unique
  on public.habits (user_id, source_key)
  where source = 'onboarding' and source_key is not null;

create unique index if not exists habit_completions_habit_date_unique
  on public.habit_completions (habit_id, completed_on);

alter table public.profiles enable row level security;
alter table public.habits enable row level security;
alter table public.habit_completions enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles_select_own'
  ) then
    create policy profiles_select_own on public.profiles
      for select using (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles_update_own'
  ) then
    create policy profiles_update_own on public.profiles
      for update using (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'habits'
      and policyname = 'habits_manage_own'
  ) then
    create policy habits_manage_own on public.habits
      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'habit_completions'
      and policyname = 'completions_manage_own'
  ) then
    create policy completions_manage_own on public.habit_completions
      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
end;
$$;

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.habits to authenticated;
grant select, insert, update, delete on public.habit_completions to authenticated;

create or replace function public.ensure_user_profile()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  insert into public.profiles (id)
  values (v_user_id)
  on conflict (id) do nothing;
end;
$$;

revoke all on function public.ensure_user_profile() from public;
grant execute on function public.ensure_user_profile() to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_trigger
    where tgname = 'on_auth_user_created'
      and tgrelid = 'auth.users'::regclass
      and not tgisinternal
  ) then
    create trigger on_auth_user_created
      after insert on auth.users
      for each row execute procedure public.handle_new_user();
  end if;
end;
$$;

create or replace function public.complete_onboarding(
  p_goals text[],
  p_level text,
  p_wake_time time,
  p_sleep_time time,
  p_notification_state text,
  p_plan jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_goals text[] := coalesce(p_goals, array['disciplined']::text[]);
  v_habit jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if cardinality(v_goals) = 0 or cardinality(v_goals) > 3 then
    raise exception 'Choose between one and three goals';
  end if;
  if not v_goals <@ array[
    'disciplined', 'healthier', 'productive', 'student',
    'betterSleep', 'reduceScreenTime'
  ]::text[] then
    raise exception 'Invalid onboarding goal';
  end if;
  if p_level not in ('starting', 'improving', 'consistent') then
    raise exception 'Invalid discipline level';
  end if;
  if p_notification_state not in ('undecided', 'granted', 'denied', 'skipped') then
    raise exception 'Invalid notification state';
  end if;
  if jsonb_typeof(coalesce(p_plan, '[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_plan, '[]'::jsonb)) <> 3 then
    raise exception 'A three-habit starter plan is required';
  end if;

  insert into public.profiles (
    id,
    onboarding_goals,
    discipline_level,
    wake_time,
    sleep_time,
    onboarding_step,
    notifications_enabled,
    notification_permission_state,
    onboarding_completed,
    onboarding_updated_at,
    updated_at
  ) values (
    v_user_id,
    v_goals,
    p_level,
    p_wake_time,
    p_sleep_time,
    6,
    p_notification_state = 'granted',
    p_notification_state,
    true,
    now(),
    now()
  )
  on conflict (id) do update set
    onboarding_goals = excluded.onboarding_goals,
    discipline_level = excluded.discipline_level,
    wake_time = excluded.wake_time,
    sleep_time = excluded.sleep_time,
    onboarding_step = excluded.onboarding_step,
    notifications_enabled = excluded.notifications_enabled,
    notification_permission_state = excluded.notification_permission_state,
    onboarding_completed = true,
    onboarding_updated_at = excluded.onboarding_updated_at,
    updated_at = excluded.updated_at;

  update public.habits
  set is_active = false
  where user_id = v_user_id
    and source = 'onboarding';

  for v_habit in
    select value from jsonb_array_elements(p_plan)
  loop
    if coalesce(v_habit ->> 'source_key', '') = ''
       or coalesce(v_habit ->> 'title', '') = '' then
      raise exception 'Invalid starter habit';
    end if;

    insert into public.habits (
      user_id,
      title,
      xp_reward,
      is_active,
      source,
      source_key,
      scheduled_time,
      effort_minutes
    ) values (
      v_user_id,
      left(v_habit ->> 'title', 80),
      greatest(0, least(500, (v_habit ->> 'xp_reward')::integer)),
      true,
      'onboarding',
      v_habit ->> 'source_key',
      nullif(v_habit ->> 'scheduled_time', '')::time,
      (v_habit ->> 'effort_minutes')::integer
    )
    on conflict (user_id, source_key)
      where source = 'onboarding' and source_key is not null
    do update set
      title = excluded.title,
      xp_reward = excluded.xp_reward,
      is_active = true,
      scheduled_time = excluded.scheduled_time,
      effort_minutes = excluded.effort_minutes;
  end loop;
end;
$$;

revoke all on function public.complete_onboarding(text[], text, time, time, text, jsonb)
from public;
grant execute on function public.complete_onboarding(text[], text, time, time, text, jsonb)
to authenticated;

create or replace function public.refresh_user_streak(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cursor date := current_date;
  v_streak integer := 0;
begin
  if not exists (
    select 1 from public.habit_completions
    where user_id = p_user_id and completed_on = v_cursor
  ) then
    v_cursor := v_cursor - 1;
  end if;

  while exists (
    select 1 from public.habit_completions
    where user_id = p_user_id and completed_on = v_cursor
  ) loop
    v_streak := v_streak + 1;
    v_cursor := v_cursor - 1;
  end loop;

  update public.profiles
  set current_streak = v_streak,
      longest_streak = greatest(longest_streak, v_streak),
      updated_at = now()
  where id = p_user_id;
end;
$$;

revoke all on function public.refresh_user_streak(uuid) from public;

create or replace function public.set_habit_completion(
  p_habit_id uuid,
  p_completed_on date,
  p_is_complete boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_xp_reward integer;
  v_changed boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select h.xp_reward
  into v_xp_reward
  from public.habits h
  where h.id = p_habit_id
    and h.user_id = v_user_id
    and h.is_active = true;

  if v_xp_reward is null then
    raise exception 'Habit not found';
  end if;

  if p_is_complete then
    insert into public.habit_completions (habit_id, user_id, completed_on)
    values (p_habit_id, v_user_id, p_completed_on)
    on conflict (habit_id, completed_on) do nothing
    returning true into v_changed;

    if coalesce(v_changed, false) then
      update public.profiles
      set total_xp = total_xp + v_xp_reward,
          updated_at = now()
      where id = v_user_id;
    end if;
  else
    delete from public.habit_completions
    where habit_id = p_habit_id
      and user_id = v_user_id
      and completed_on = p_completed_on
    returning true into v_changed;

    if coalesce(v_changed, false) then
      update public.profiles
      set total_xp = greatest(0, total_xp - v_xp_reward),
          updated_at = now()
      where id = v_user_id;
    end if;
  end if;

  perform public.refresh_user_streak(v_user_id);
end;
$$;

revoke all on function public.set_habit_completion(uuid, date, boolean)
from public;
grant execute on function public.set_habit_completion(uuid, date, boolean)
to authenticated;

-- Verification: required columns, RLS, policies, trigger, and RPCs.
select column_name, data_type, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('profiles', 'habits')
  and column_name in (
    'onboarding_completed', 'onboarding_goals', 'discipline_level',
    'wake_time', 'sleep_time', 'notifications_enabled',
    'notification_permission_state', 'source', 'source_key',
    'scheduled_time', 'effort_minutes'
  )
order by table_name, column_name;

select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('profiles', 'habits');

select policyname, tablename, cmd
from pg_policies
where schemaname = 'public' and tablename in ('profiles', 'habits')
order by tablename, policyname;

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'ensure_user_profile', 'complete_onboarding',
    'refresh_user_streak', 'set_habit_completion'
  )
order by routine_name;
