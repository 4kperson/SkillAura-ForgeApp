-- Atomically record or remove a habit completion and keep total XP aligned.
-- The function validates that the habit belongs to the authenticated user.

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
    insert into public.habit_completions (
      habit_id,
      user_id,
      completed_on
    )
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
end;
$$;

revoke all on function public.set_habit_completion(uuid, date, boolean)
from public;

grant execute on function public.set_habit_completion(uuid, date, boolean)
to authenticated;
