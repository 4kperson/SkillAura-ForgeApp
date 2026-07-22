-- Sprint 4 stabilization after the live 001 -> 003 -> 002 recovery path.
-- Additive and repeatable: preserves habits, completion history, and XP.

-- Repair legacy duplicate/gapped positions without changing the user's existing
-- relative order. This is idempotent once every user's positions are 0..n.
with ranked as (
  select
    h.id,
    row_number() over (
      partition by h.user_id
      order by h.sort_position, h.created_at, h.id
    )::integer - 1 as repaired_position
  from public.habits h
)
update public.habits h
set sort_position = ranked.repaired_position,
    updated_at = now()
from ranked
where h.id = ranked.id
  and h.sort_position is distinct from ranked.repaired_position;

-- Convert the existing unique completion-date index into a named constraint so
-- ON CONFLICT never collides with the PL/pgSQL completion_date output variable.
do $$
declare
  v_existing_constraint text;
  v_existing_index regclass;
begin
  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.habit_completions'::regclass
      and c.conname = 'habit_completions_habit_completion_date_unique'
  ) then
    select c.conname
    into v_existing_constraint
    from pg_constraint c
    where c.conrelid = 'public.habit_completions'::regclass
      and c.contype = 'u'
      and pg_get_constraintdef(c.oid) = 'UNIQUE (habit_id, completion_date)'
    limit 1;

    if v_existing_constraint is not null then
      execute format(
        'alter table public.habit_completions rename constraint %I to habit_completions_habit_completion_date_unique',
        v_existing_constraint
      );
    else
      v_existing_index := to_regclass(
        'public.habit_completions_habit_completion_date_unique'
      );
      if v_existing_index is not null and not exists (
        select 1 from pg_constraint c where c.conindid = v_existing_index
      ) then
        alter table public.habit_completions
          add constraint habit_completions_habit_completion_date_unique
          unique using index habit_completions_habit_completion_date_unique;
      else
        alter table public.habit_completions
          add constraint habit_completions_habit_completion_date_unique
          unique (habit_id, completion_date);
      end if;
    end if;
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
    raise exception 'Authentication required' using errcode = '42501';
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
    and extract(isodow from (now() at time zone h.timezone))::smallint
        = any(h.active_weekdays)
  order by h.sort_position;
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
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  perform public.ensure_user_profile();

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
    and h.user_id = v_user_id
  for update;

  if not found then
    raise exception 'Habit not found or not owned by the current user'
      using errcode = '42501';
  end if;

  v_completion_date := (now() at time zone v_timezone)::date;
  v_source := case
    when p_source in ('home', 'habit_manager', 'manual') then p_source
    else 'manual'
  end;

  if p_is_complete then
    if not v_is_active or v_paused or v_archived then
      raise exception 'Habit is not currently active' using errcode = '22023';
    end if;
    if extract(isodow from (now() at time zone v_timezone))::smallint
       <> all(v_active_weekdays) then
      raise exception 'Habit is not active today' using errcode = '22023';
    end if;

    insert into public.habit_completions as saved_completion (
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
    on conflict on constraint habit_completions_habit_completion_date_unique
      do nothing
    returning saved_completion.xp_awarded into v_awarded;

    v_changed := found;
    if v_changed then
      update public.profiles p
      set total_xp = p.total_xp + v_awarded,
          updated_at = now()
      where p.id = v_user_id;
    end if;
  else
    delete from public.habit_completions c
    where c.habit_id = p_habit_id
      and c.user_id = v_user_id
      and c.completion_date = v_completion_date
    returning c.xp_awarded into v_awarded;

    v_changed := found;
    if v_changed then
      update public.profiles p
      set total_xp = greatest(0, p.total_xp - v_awarded),
          updated_at = now()
      where p.id = v_user_id;
    end if;
  end if;

  if v_changed then
    perform public.refresh_user_streak(v_user_id);
  end if;

  return query
  select
    v_completion_date,
    v_changed,
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
  v_owned integer;
  v_updated integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  perform 1
  from public.habits h
  where h.user_id = v_user_id
  order by h.id
  for update;

  select count(*)::integer
  into v_owned
  from public.habits h
  where h.user_id = v_user_id;

  if v_owned = 0 and v_requested = 0 then
    return;
  end if;
  if v_requested <> v_owned then
    raise exception 'Habit order must contain every owned habit exactly once'
      using errcode = '22023';
  end if;

  select count(distinct requested.value)::integer
  into v_distinct
  from unnest(p_habit_ids) as requested(value);

  if v_distinct <> v_requested then
    raise exception 'Habit order contains duplicates' using errcode = '22023';
  end if;

  if exists (
    select 1
    from unnest(p_habit_ids) as requested(value)
    left join public.habits h
      on h.id = requested.value
      and h.user_id = v_user_id
    where h.id is null
  ) then
    raise exception 'Habit order contains a habit not owned by the current user'
      using errcode = '42501';
  end if;

  update public.habits h
  set sort_position = requested.ordinality::integer - 1,
      updated_at = now()
  from unnest(p_habit_ids) with ordinality as requested(value, ordinality)
  where h.id = requested.value
    and h.user_id = v_user_id;

  get diagnostics v_updated = row_count;
  if v_updated <> v_owned then
    raise exception 'Habit order was not fully persisted' using errcode = '40001';
  end if;
end;
$$;

revoke all on function public.reorder_habits(uuid[]) from public;
grant execute on function public.reorder_habits(uuid[]) to authenticated;

-- Verification: exact RPC signatures, canonical uniqueness, RLS, and policies.
select
  p.proname,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_today_habits', 'set_habit_completion_v2', 'reorder_habits'
  )
order by p.proname;

select c.conname, pg_get_constraintdef(c.oid) as definition
from pg_constraint c
where c.conrelid = 'public.habit_completions'::regclass
  and c.conname = 'habit_completions_habit_completion_date_unique';

select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('habits', 'habit_completions')
order by c.relname;

select tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('habits', 'habit_completions')
order by tablename, policyname;
