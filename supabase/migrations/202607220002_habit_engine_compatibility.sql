-- Keep future onboarding-generated promises on the Sprint 4 habit contract and
-- repair an ambiguous completion-column reference for already-migrated projects.
-- This migration replaces functions only; it does not remove or rewrite data.

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
  v_source_key text;
  v_category text;
  v_symbol text;
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
  set is_active = false,
      archived = true,
      updated_at = now()
  where user_id = v_user_id
    and source = 'onboarding';

  for v_habit in
    select value from jsonb_array_elements(p_plan)
  loop
    v_source_key := coalesce(v_habit ->> 'source_key', '');
    if v_source_key = '' or coalesce(v_habit ->> 'title', '') = '' then
      raise exception 'Invalid starter habit';
    end if;

    v_category := case v_source_key
      when 'discipline' then 'discipline'
      when 'health' then 'health'
      when 'focus' then 'focus'
      when 'study' then 'learning'
      when 'sleep' then 'sleep'
      when 'screenTime' then 'digital'
      else 'personal'
    end;
    v_symbol := case v_source_key
      when 'discipline' then 'shield'
      when 'health' then 'heart'
      when 'focus' then 'target'
      when 'study' then 'book'
      when 'sleep' then 'moon'
      when 'screenTime' then 'phone'
      else 'spark'
    end;

    insert into public.habits (
      user_id,
      title,
      category,
      symbol,
      xp_reward,
      is_active,
      source,
      source_key,
      scheduled_time,
      reminder_time,
      effort_minutes,
      active_weekdays,
      timezone,
      position,
      paused,
      archived
    ) values (
      v_user_id,
      left(v_habit ->> 'title', 80),
      v_category,
      v_symbol,
      greatest(0, least(500, (v_habit ->> 'xp_reward')::integer)),
      true,
      'onboarding',
      v_source_key,
      nullif(v_habit ->> 'scheduled_time', '')::time,
      coalesce(
        nullif(v_habit ->> 'reminder_time', ''),
        nullif(v_habit ->> 'scheduled_time', '')
      )::time,
      (v_habit ->> 'effort_minutes')::integer,
      array[1, 2, 3, 4, 5, 6, 7]::smallint[],
      coalesce(nullif(v_habit ->> 'timezone', ''), 'America/New_York'),
      greatest(0, coalesce((v_habit ->> 'position')::integer, 0)),
      false,
      false
    )
    on conflict (user_id, source_key)
      where source = 'onboarding' and source_key is not null
    do update set
      title = excluded.title,
      category = excluded.category,
      symbol = excluded.symbol,
      xp_reward = excluded.xp_reward,
      is_active = true,
      scheduled_time = excluded.scheduled_time,
      reminder_time = excluded.reminder_time,
      effort_minutes = excluded.effort_minutes,
      active_weekdays = excluded.active_weekdays,
      timezone = excluded.timezone,
      position = excluded.position,
      paused = false,
      archived = false,
      updated_at = now();
  end loop;
end;
$$;

revoke all on function public.complete_onboarding(text[], text, time, time, text, jsonb)
from public;
grant execute on function public.complete_onboarding(text[], text, time, time, text, jsonb)
to authenticated;

create or replace function public.ensure_onboarding_habits(p_plan jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_habit jsonb;
  v_source_key text;
  v_category text;
  v_symbol text;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = v_user_id and onboarding_completed = true
  ) then
    raise exception 'Onboarding is not complete';
  end if;
  if jsonb_typeof(coalesce(p_plan, '[]'::jsonb)) <> 'array' then
    raise exception 'Invalid starter plan';
  end if;

  for v_habit in
    select value from jsonb_array_elements(p_plan)
  loop
    v_source_key := coalesce(v_habit ->> 'source_key', '');
    if v_source_key = '' or coalesce(v_habit ->> 'title', '') = '' then
      raise exception 'Invalid starter habit';
    end if;
    v_category := case v_source_key
      when 'discipline' then 'discipline'
      when 'health' then 'health'
      when 'focus' then 'focus'
      when 'study' then 'learning'
      when 'sleep' then 'sleep'
      when 'screenTime' then 'digital'
      else 'personal'
    end;
    v_symbol := case v_source_key
      when 'discipline' then 'shield'
      when 'health' then 'heart'
      when 'focus' then 'target'
      when 'study' then 'book'
      when 'sleep' then 'moon'
      when 'screenTime' then 'phone'
      else 'spark'
    end;

    insert into public.habits (
      user_id,
      title,
      category,
      symbol,
      xp_reward,
      is_active,
      source,
      source_key,
      scheduled_time,
      reminder_time,
      effort_minutes,
      active_weekdays,
      timezone,
      position,
      paused,
      archived
    ) values (
      v_user_id,
      left(v_habit ->> 'title', 80),
      v_category,
      v_symbol,
      greatest(0, least(500, (v_habit ->> 'xp_reward')::integer)),
      true,
      'onboarding',
      v_source_key,
      nullif(v_habit ->> 'scheduled_time', '')::time,
      coalesce(
        nullif(v_habit ->> 'reminder_time', ''),
        nullif(v_habit ->> 'scheduled_time', '')
      )::time,
      (v_habit ->> 'effort_minutes')::integer,
      array[1, 2, 3, 4, 5, 6, 7]::smallint[],
      coalesce(nullif(v_habit ->> 'timezone', ''), 'America/New_York'),
      greatest(0, coalesce((v_habit ->> 'position')::integer, 0)),
      false,
      false
    )
    on conflict (user_id, source_key)
      where source = 'onboarding' and source_key is not null
    do nothing;
  end loop;
end;
$$;

revoke all on function public.ensure_onboarding_habits(jsonb) from public;
grant execute on function public.ensure_onboarding_habits(jsonb) to authenticated;

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

select routine_name, security_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'complete_onboarding', 'ensure_onboarding_habits',
    'set_habit_completion_v2'
  )
order by routine_name;
