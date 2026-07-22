-- Repair Sprint 4 databases where migration 001 stopped at get_today_habits.
-- This migration is additive and idempotent. It never deletes habit data,
-- completion data, or XP, and it never overwrites an existing sort_position.

alter table public.habits
  add column if not exists sort_position integer;

-- Compatibility for the partially applied migration only. PostgreSQL requires
-- quoting the legacy keyword-shaped column, so dynamic SQL keeps that old name
-- out of the permanent schema and RPC contract.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'habits'
      and column_name = 'position'
  ) then
    execute format(
      'update public.habits set sort_position = coalesce(sort_position, %I) where sort_position is null',
      'position'
    );
  end if;
end;
$$;

with ranked as (
  select
    id,
    row_number() over (partition by user_id order by created_at, id) - 1 as new_position
  from public.habits
  where sort_position is null
)
update public.habits h
set sort_position = ranked.new_position
from ranked
where h.id = ranked.id
  and h.sort_position is null;

alter table public.habits
  alter column sort_position set default 0,
  alter column sort_position set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'habits_sort_position_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits
      add constraint habits_sort_position_check check (sort_position >= 0);
  end if;
end;
$$;

create index if not exists habits_user_status_sort_position_idx
  on public.habits (user_id, archived, paused, sort_position);

create or replace function public.get_today_habits()
returns table (
  id uuid,
  user_id uuid,
  title text,
  category text,
  symbol text,
  reminder_time time,
  active_weekdays smallint[],
  timezone text,
  sort_position integer,
  paused boolean,
  archived boolean,
  created_at timestamptz,
  updated_at timestamptz,
  xp_reward integer,
  source text,
  source_key text,
  effort_minutes integer,
  local_date date,
  is_completed boolean
)
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

  return query
  select
    h.id,
    h.user_id,
    h.title,
    h.category,
    h.symbol,
    h.reminder_time,
    h.active_weekdays,
    h.timezone,
    h.sort_position,
    h.paused,
    h.archived,
    h.created_at,
    h.updated_at,
    h.xp_reward,
    h.source,
    h.source_key,
    h.effort_minutes,
    (now() at time zone h.timezone)::date as local_date,
    exists (
      select 1
      from public.habit_completions c
      where c.habit_id = h.id
        and c.user_id = v_user_id
        and c.completion_date = (now() at time zone h.timezone)::date
    ) as is_completed
  from public.habits h
  where h.user_id = v_user_id
    and h.is_active = true
    and h.paused = false
    and h.archived = false
    and extract(isodow from (now() at time zone h.timezone))::smallint = any(h.active_weekdays)
  order by h.sort_position, h.created_at, h.id;
end;
$$;

revoke all on function public.get_today_habits() from public;
grant execute on function public.get_today_habits() to authenticated;

create or replace function public.reorder_habits(p_habit_ids uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_requested integer := coalesce(cardinality(p_habit_ids), 0);
  v_distinct integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if v_requested = 0 then
    return;
  end if;

  select count(distinct value)::integer
  into v_distinct
  from unnest(p_habit_ids) as requested(value);

  if v_distinct <> v_requested then
    raise exception 'Habit order contains duplicates';
  end if;

  if exists (
    select 1
    from unnest(p_habit_ids) as requested(value)
    left join public.habits h on h.id = requested.value
    where h.id is null
      or h.user_id <> v_user_id
      or h.archived = true
  ) then
    raise exception 'Habit order contains an unavailable habit';
  end if;

  update public.habits h
  set sort_position = requested.ordinality - 1,
      updated_at = now()
  from unnest(p_habit_ids) with ordinality as requested(value, ordinality)
  where h.id = requested.value
    and h.user_id = v_user_id;
end;
$$;

revoke all on function public.reorder_habits(uuid[]) from public;
grant execute on function public.reorder_habits(uuid[]) to authenticated;

-- Verification: one live order column, its constraint/index, and repaired RPCs.
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'habits'
  and column_name = 'sort_position';

select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.habits'::regclass
  and conname = 'habits_sort_position_check';

select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and indexname = 'habits_user_status_sort_position_idx';

select routine_name, routine_type, security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in ('get_today_habits', 'reorder_habits')
order by routine_name;
