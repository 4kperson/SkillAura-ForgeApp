-- Sprint 4: expand onboarding promises into Forge's complete habit engine.
-- This migration is additive, idempotent, and preserves every existing row.

create extension if not exists pgcrypto;

alter table public.habits
  add column if not exists category text,
  add column if not exists symbol text,
  add column if not exists active_weekdays smallint[],
  add column if not exists timezone text,
  add column if not exists position integer,
  add column if not exists paused boolean not null default false,
  add column if not exists archived boolean not null default false,
  add column if not exists updated_at timestamptz;

-- Reminder time is nullable by design. Backfill it only when the column is first
-- introduced so rerunning this migration never restores a reminder a user removed.
do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'habits'
      and column_name = 'reminder_time'
  ) then
    alter table public.habits add column reminder_time time;
    update public.habits set reminder_time = scheduled_time;
  end if;
end;
$$;

update public.habits
set category = case source_key
  when 'discipline' then 'discipline'
  when 'health' then 'health'
  when 'focus' then 'focus'
  when 'study' then 'learning'
  when 'sleep' then 'sleep'
  when 'screenTime' then 'digital'
  else 'personal'
end
where category is null;

update public.habits
set symbol = case source_key
  when 'discipline' then 'shield'
  when 'health' then 'heart'
  when 'focus' then 'target'
  when 'study' then 'book'
  when 'sleep' then 'moon'
  when 'screenTime' then 'phone'
  else 'spark'
end
where symbol is null;

update public.habits
set active_weekdays = array[1, 2, 3, 4, 5, 6, 7]::smallint[]
where active_weekdays is null;

update public.habits h
set timezone = coalesce(nullif(p.timezone, ''), 'America/New_York')
from public.profiles p
where h.user_id = p.id
  and h.timezone is null;

update public.habits
set timezone = 'America/New_York'
where timezone is null;

with ranked as (
  select
    id,
    row_number() over (partition by user_id order by created_at, id) - 1 as new_position
  from public.habits
  where position is null
)
update public.habits h
set position = ranked.new_position
from ranked
where h.id = ranked.id;

update public.habits
set archived = true
where is_active = false
  and archived = false;

update public.habits
set updated_at = coalesce(updated_at, created_at, now())
where updated_at is null;

alter table public.habits
  alter column category set default 'personal',
  alter column category set not null,
  alter column symbol set default 'spark',
  alter column symbol set not null,
  alter column active_weekdays set default array[1, 2, 3, 4, 5, 6, 7]::smallint[],
  alter column active_weekdays set not null,
  alter column timezone set default 'America/New_York',
  alter column timezone set not null,
  alter column position set default 0,
  alter column position set not null,
  alter column updated_at set default now(),
  alter column updated_at set not null;

alter table public.habit_completions
  add column if not exists completion_date date,
  add column if not exists completed_at timestamptz,
  add column if not exists xp_awarded integer,
  add column if not exists source text;

update public.habit_completions
set completion_date = completed_on
where completion_date is null;

update public.habit_completions
set completed_at = coalesce(completed_at, created_at, now())
where completed_at is null;

update public.habit_completions c
set xp_awarded = greatest(0, h.xp_reward)
from public.habits h
where c.habit_id = h.id
  and c.xp_awarded is null;

update public.habit_completions
set xp_awarded = 0
where xp_awarded is null;

update public.habit_completions
set source = 'legacy'
where source is null;

alter table public.habit_completions
  alter column completion_date set not null,
  alter column completed_at set default now(),
  alter column completed_at set not null,
  alter column xp_awarded set default 0,
  alter column xp_awarded set not null,
  alter column source set default 'manual',
  alter column source set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'habits_category_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits add constraint habits_category_check check (
      category in (
        'discipline', 'health', 'focus', 'learning', 'sleep',
        'digital', 'wellbeing', 'personal'
      )
    );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'habits_symbol_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits add constraint habits_symbol_check check (
      char_length(symbol) between 1 and 32
    );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'habits_active_weekdays_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits add constraint habits_active_weekdays_check check (
      cardinality(active_weekdays) between 1 and 7
      and active_weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
    );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'habits_timezone_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits add constraint habits_timezone_check check (
      char_length(timezone) between 1 and 64
    );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'habits_position_check'
      and conrelid = 'public.habits'::regclass
  ) then
    alter table public.habits add constraint habits_position_check check (
      position >= 0
    );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'habit_completions_xp_awarded_check'
      and conrelid = 'public.habit_completions'::regclass
  ) then
    alter table public.habit_completions
      add constraint habit_completions_xp_awarded_check check (
        xp_awarded between 0 and 500
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'habit_completions_source_check'
      and conrelid = 'public.habit_completions'::regclass
  ) then
    alter table public.habit_completions
      add constraint habit_completions_source_check check (
        source in ('home', 'habit_manager', 'manual', 'legacy')
      );
  end if;
end;
$$;

create unique index if not exists habit_completions_habit_completion_date_unique
  on public.habit_completions (habit_id, completion_date);

create index if not exists habits_user_status_position_idx
  on public.habits (user_id, archived, paused, position);

create index if not exists habit_completions_user_date_idx
  on public.habit_completions (user_id, completion_date desc);

alter table public.habits enable row level security;
alter table public.habit_completions enable row level security;

-- The existing owner policies are retained. These guards repair installations
-- where one of the earlier migrations was not applied.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'habits'
      and policyname = 'habits_manage_own'
  ) then
    create policy habits_manage_own on public.habits
      for all using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'habit_completions'
      and policyname = 'completions_manage_own'
  ) then
    create policy completions_manage_own on public.habit_completions
      for all using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end;
$$;

grant select, insert, update on public.habits to authenticated;
revoke delete on public.habits from authenticated;
grant select on public.habit_completions to authenticated;
revoke insert, update, delete on public.habit_completions from authenticated;

create or replace function public.touch_habit_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_trigger
    where tgname = 'habits_touch_updated_at'
      and tgrelid = 'public.habits'::regclass
      and not tgisinternal
  ) then
    create trigger habits_touch_updated_at
      before update on public.habits
      for each row execute procedure public.touch_habit_updated_at();
  end if;
end;
$$;

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
  position integer,
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
    h.position,
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
  order by h.position, h.created_at, h.id;
end;
$$;

revoke all on function public.get_today_habits() from public;
grant execute on function public.get_today_habits() to authenticated;

create or replace function public.set_habit_completion_v2(
  p_habit_id uuid,
  p_is_complete boolean,
  p_source text default 'home'
)
returns table (
  completion_date date,
  changed boolean,
  total_xp integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_xp_reward integer;
  v_timezone text;
  v_active_weekdays smallint[];
  v_paused boolean;
  v_archived boolean;
  v_is_active boolean;
  v_completion_date date;
  v_changed boolean := false;
  v_awarded integer := 0;
  v_source text;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select
    h.xp_reward,
    h.timezone,
    h.active_weekdays,
    h.paused,
    h.archived,
    h.is_active
  into
    v_xp_reward,
    v_timezone,
    v_active_weekdays,
    v_paused,
    v_archived,
    v_is_active
  from public.habits h
  where h.id = p_habit_id
    and h.user_id = v_user_id;

  if not found then
    raise exception 'Habit not found';
  end if;

  v_completion_date := (now() at time zone v_timezone)::date;
  v_source := case
    when p_source in ('home', 'habit_manager', 'manual') then p_source
    else 'manual'
  end;

  if p_is_complete then
    if not v_is_active or v_paused or v_archived then
      raise exception 'Habit is not currently active';
    end if;
    if extract(isodow from (now() at time zone v_timezone))::smallint
       <> all(v_active_weekdays) then
      raise exception 'Habit is not active today';
    end if;

    insert into public.habit_completions (
      habit_id,
      user_id,
      completed_on,
      completion_date,
      completed_at,
      xp_awarded,
      source,
      created_at
    ) values (
      p_habit_id,
      v_user_id,
      v_completion_date,
      v_completion_date,
      now(),
      v_xp_reward,
      v_source,
      now()
    )
    on conflict (habit_id, completion_date) do nothing
    returning true into v_changed;

    if coalesce(v_changed, false) then
      update public.profiles
      set total_xp = total_xp + v_xp_reward,
          updated_at = now()
      where id = v_user_id;
    end if;
  else
    delete from public.habit_completions c
    where c.habit_id = p_habit_id
      and c.user_id = v_user_id
      and c.completion_date = v_completion_date
    returning c.xp_awarded into v_awarded;

    v_changed := found;
    if v_changed then
      update public.profiles
      set total_xp = greatest(0, total_xp - v_awarded),
          updated_at = now()
      where id = v_user_id;
    end if;
  end if;

  perform public.refresh_user_streak(v_user_id);

  return query
  select
    v_completion_date,
    coalesce(v_changed, false),
    p.total_xp
  from public.profiles p
  where p.id = v_user_id;
end;
$$;

revoke all on function public.set_habit_completion_v2(uuid, boolean, text)
from public;
grant execute on function public.set_habit_completion_v2(uuid, boolean, text)
to authenticated;

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
  set position = requested.ordinality - 1,
      updated_at = now()
  from unnest(p_habit_ids) with ordinality as requested(value, ordinality)
  where h.id = requested.value
    and h.user_id = v_user_id;
end;
$$;

revoke all on function public.reorder_habits(uuid[]) from public;
grant execute on function public.reorder_habits(uuid[]) to authenticated;

create or replace function public.delete_habit(p_habit_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_xp_to_reverse integer := 0;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1 from public.habits
    where id = p_habit_id and user_id = v_user_id
  ) then
    raise exception 'Habit not found';
  end if;

  select coalesce(sum(xp_awarded), 0)::integer
  into v_xp_to_reverse
  from public.habit_completions
  where habit_id = p_habit_id
    and user_id = v_user_id;

  delete from public.habits
  where id = p_habit_id
    and user_id = v_user_id;

  update public.profiles
  set total_xp = greatest(0, total_xp - v_xp_to_reverse),
      updated_at = now()
  where id = v_user_id;

  perform public.refresh_user_streak(v_user_id);
end;
$$;

revoke all on function public.delete_habit(uuid) from public;
grant execute on function public.delete_habit(uuid) to authenticated;

-- Verification: expected columns, unique completion protection, RLS, policies,
-- grants, triggers, and ownership-checked functions.
select table_name, column_name, data_type, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('habits', 'habit_completions')
  and column_name in (
    'id', 'user_id', 'title', 'category', 'symbol', 'reminder_time',
    'active_weekdays', 'timezone', 'position', 'paused', 'archived',
    'created_at', 'updated_at', 'habit_id', 'completion_date',
    'completed_at', 'xp_awarded', 'source'
  )
order by table_name, ordinal_position;

select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('habits', 'habit_completions');

select tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('habits', 'habit_completions')
order by tablename, policyname;

select indexname, indexdef
from pg_indexes
where schemaname = 'public'
  and indexname in (
    'habit_completions_habit_completion_date_unique',
    'habits_user_status_position_idx',
    'habit_completions_user_date_idx'
  )
order by indexname;

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'get_today_habits', 'set_habit_completion_v2',
    'reorder_habits', 'delete_habit'
  )
order by routine_name;
