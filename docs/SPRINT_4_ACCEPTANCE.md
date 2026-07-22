# Sprint 4 User Acceptance Checklist

## Preparation

- Rerun `202607220001_habit_engine.sql` in the Supabase SQL Editor.
- Apply `202607220003_habit_engine_sort_position_repair.sql` next.
- Apply `202607220002_habit_engine_compatibility.sql` last.
- Apply `202607220004_habit_engine_stabilization.sql` after that. For a project
  that already ran `001 -> 003 -> 002`, apply only `004` now.
- Confirm the verification results show RLS enabled and the expected owner-only
  policies and functions.
- Install a fresh debug build and sign in to an account that completed
  onboarding.

## Starter plan ownership

- Open **Manage** from Today's Mission.
- Confirm all onboarding promises appear with a subtle `STARTER` badge.
- Edit one starter promise, close Habit Management, and confirm Home updates.
- Restart and sign in again; confirm the edit remains unchanged.

## Create and edit

- Create an everyday habit without a reminder.
- Create a weekday-only habit with a reminder.
- Edit its title, category, symbol, weekdays, and reminder time.
- Confirm validation appears for an empty title or zero selected days.
- Disable connectivity during Save; confirm the draft stays in the sheet and a
  calm retry message appears.

## Lifecycle and ordering

- Drag active habits into a new order and confirm Home uses that order.
- Leave Habit Management, restart Forge, and confirm the exact same order.
- Pause a habit and confirm it leaves Home but appears under **Paused**.
- Resume it and confirm it returns on an active weekday.
- Archive a habit and confirm it appears under **Archive** with history intact.
- Restore it and confirm it returns to the active plan.
- Begin permanent deletion, verify the history/XP warning, cancel once, then
  confirm deletion intentionally.

## Completion trust

- Complete a Today's Mission habit once and confirm XP changes once.
- Tap rapidly while saving and confirm only one completion is recorded.
- Use **Undo** and confirm the mission and exact previous XP return.
- Repeat completion and Undo attempts and confirm neither XP operation happens
  twice.
- Open habit history and confirm date, confirmation time, and awarded XP.
- Disable connectivity and attempt completion; confirm Home remains incomplete
  and offers a recoverable message.

## Scheduling and boundaries

- Confirm a non-active weekday habit does not appear in Today's Mission.
- Change a reminder time, close Habit Management, and inspect the device's
  pending notification behavior.
- Pause or archive the habit and confirm its reminder no longer fires.
- Test once across local midnight and, when possible, a daylight-saving change
  or device/profile timezone change.

## Accessibility and layout

- Repeat create, edit, menu, delete, completion, and Undo with a screen reader.
- Verify controls have clear labels and comfortable touch targets.
- Test a 360 × 640 device and increased system text size for clipping or
  unreachable actions.
