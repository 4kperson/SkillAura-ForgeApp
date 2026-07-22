# Sprint 1 Status

## Milestone: starter import

Status: complete locally on 2026-07-20.

- Extracted the supplied `forge_app_starter.zip` without modifying starter source files.
- Initialized a local Git repository on the `main` branch.
- Connected the official GitHub remote and pushed the foundation commit:
  [`7b3392f`](https://github.com/4kperson/SkillAura-ForgeApp/commit/7b3392f).
- Confirmed the starter includes source, tests, Supabase migration, CI workflow, and project documentation.

## Milestone: verified Flutter foundation

Status: complete locally on 2026-07-20.

- Generated the Android and iOS Flutter host projects.
- Set the Android namespace/application ID and iOS bundle ID to
  `com.skillaura.forge`.
- Replaced the deprecated Supabase initialization argument with
  `publishableKey`.
- Removed Flutter's generated sample test and retained the project-specific
  widget and controller tests.
- Ran `dart format --output=none --set-exit-if-changed lib test` successfully.
- Ran `flutter analyze` successfully with no issues.
- Ran `flutter test` successfully: 2 tests passed.
- Built `build/app/outputs/flutter-apk/app-debug.apk` successfully.

The local repository has a configured author identity and its `origin` remote
tracks `https://github.com/4kperson/SkillAura-ForgeApp.git`.

## Next milestone

Implement email authentication against Supabase, including loading, validation,
error, and signed-in states, with focused unit and widget tests.

## Supabase

The app is prepared to receive `SUPABASE_URL` and `SUPABASE_ANON_KEY` through
Dart defines. Local Supabase values are stored in the ignored `.env` file; no
secrets have been added to the repository.

# Sprint 2 Status

## Milestone: onboarding persistence foundation

Status: complete locally on 2026-07-21.

- Added a typed onboarding profile covering goal, discipline level, routine,
  resume step, notification preference, and completion.
- Added a repository boundary with a Supabase implementation.
- Added a database migration with constrained onboarding profile columns.
- Added domain serialization, defaults, and plan-recommendation tests.

## Milestone: premium onboarding experience

Status: complete locally on 2026-07-21.

- Replaced the placeholder with a seven-step emotional commitment journey.
- Added goal and discipline personalization, native routine pickers, a tailored
  starting plan, notification pre-permission education, and Day One completion.
- Added restrained motion, semantic selection states, responsive layouts, and
  compact-device overflow coverage.
- Added controller tests for resume, progressive persistence, and completion.

## Milestone: onboarding routing and native permission integration

Status: complete locally on 2026-07-21.

- Added a startup onboarding gate that resolves after authentication without
  route flicker.
- Incomplete users resume onboarding; completed users bypass it permanently.
- Added Android notification permission configuration and requests permission
  only after the benefit explanation.
- Added integration coverage for loading, resume, permanent bypass,
  notification consent, completion persistence, and Home handoff.

## Milestone: personalized onboarding polish

Status: complete locally on 2026-07-21.

- Expanded onboarding to persist up to three selected priorities.
- Made Beginner, Intermediate, and Advanced paths change habit effort, mission
  size, and XP expectations.
- Generated three starter habits from selected goals, difficulty, wake time,
  and sleep time instead of serving a universal plan.
- Reworked decision copy to explain why each answer matters and reframed the
  final screen as the beginning of Day One.
- Preserved legacy single-goal profile compatibility and added an additive
  `text[]` database migration.

## Database repair

The existing `public.profiles` table is preserved. Run
`202607210002_repair_onboarding_profile.sql` in Supabase when applying the
onboarding schema. It contains no drop, rename, recreate, truncate, or data
deletion statements and can safely be rerun.

# Sprint 3 Status

## Milestone: morning data foundation

Status: complete locally on 2026-07-21.

- Added a production-shaped morning aggregate for profile, day identity,
  habits, completion, streak, XP, and level progress.
- Added a Supabase repository that reads the existing profile, habits, and
  completion tables.
- Added optimistic completion with rollback and an atomic, ownership-checked
  database function for completion and XP changes.
- Added focused domain and controller tests.

## Product stabilization: persistence and premium Home foundation

Status: complete locally on 2026-07-21.

- Repaired missing profile rows before onboarding reads and writes.
- Made onboarding completion an atomic Supabase transaction that persists all
  answers and creates the three personalized habits.
- Prevented profile-load failures from routing users back into onboarding.
- Added distinct granted, denied, skipped, and undecided notification states,
  including a respectful denied-permission experience.
- Replaced placeholder tasks and the local demo controller with real Supabase
  habits, atomic XP completion, server-refreshed streaks, and disappearing
  completed missions.
- Rebuilt Home around identity, next action, XP, levels, streaks, milestones,
  and the next achievement without a percentage dashboard.
- Added the full onboarding → sign-out → same-account sign-in regression test.

## Sprint 3 stabilization

Status: complete locally on 2026-07-22.

- Replaced boolean-only notification handling with explicit native permission
  mapping and persisted granted, denied, and skipped states.
- Added local daily scheduling for the personalized starter plan, cancellation
  for non-granted states, reboot restoration on Android, and cold-start sync.
- Exposed reminder state through the existing Morning profile query and added a
  quiet Home acknowledgement when reminders are disabled.
- Polished Morning loading and mission transitions and separated a missing plan
  from a genuinely completed day.
- Removed unused Riverpod, RevenueCat, and starter utility dependencies.
- Added routing, restart, reminder-plan, denied-state, empty-state, and duplicate
  XP-tap regression coverage.
- Repaired Android notification initialization with a dedicated drawable status
  icon, explicit channel creation, and ordered one-time initialization.
- Made cancellation idempotent for fresh installs and separated cleanup results
  from consent so denied and skipped users never receive a false error banner.
- Added operation-level debug exceptions and stack traces, partial-schedule
  rollback, and regression coverage for successful and failed native outcomes.

## Final notification UX polish

Status: complete locally on 2026-07-22.

- Unified denied permission and **Not now** behind one respectful reminder-off
  screen with clear enable and continue actions.
- Added platform-aware recovery through the native prompt or system app settings.
- Made returning from settings restore permission, scheduling, and the persisted
  profile before advancing or refreshing Home.
- Turned the quiet Home reminder state into a premium, accessible action card.
- Added service and widget coverage for Allow, Deny, Not now, Home recovery, and
  app-resume restoration.

## Sprint 3 final acceptance fixes

Status: complete locally on 2026-07-22.

- Replaced the misleading incomplete-promise checkmark with distinct outline,
  loading, and server-confirmed completion states.
- Delayed XP and visual completion until the completion RPC succeeds while
  preserving duplicate-tap protection and disappearing completed missions.
- Made Supabase PKCE and automatic URI detection explicit at application startup.
- Connected cold-start and foreground callback observation to session routing.
- Added useful callback messages and resend recovery for expired, consumed, and
  mismatched-PKCE confirmation links.
- Documented the production Site URL and both required mobile redirect entries.

# Sprint 4 Status

## Milestone: secure habit-engine schema

Status: complete locally on 2026-07-22.

- Expanded every existing onboarding habit in place with category, symbol,
  reminder, active weekdays, timezone, order, paused, archived, and update
  metadata.
- Expanded completion history with its effective local date, completion time,
  awarded XP, and source while preserving legacy fields and rows.
- Added unique duplicate-completion protection and server-owned completion,
  undo, reorder, and permanent-delete operations.
- Kept owner-only RLS enabled, repaired missing policies idempotently, and
  revoked unsafe direct completion and habit-delete mutations.
- Added server-side local-day eligibility using each habit's IANA timezone.

## Milestone: typed Flutter habit engine

Status: complete locally on 2026-07-22.

- Added complete typed habit, draft, completion, completion-result, and library
  domain models with legacy onboarding compatibility.
- Added Supabase create, edit, pause, resume, archive, restore, delete, reorder,
  complete, undo, and history repository operations.
- Added a controller that prevents concurrent duplicate mutations, reloads
  confirmed Supabase state after saves, and rolls back failed reorders.
- Added validation and calm offline/save/load recovery messages that preserve
  unsaved form input and confirmed server data.

## Milestone: premium Habit Management and Home integration

Status: complete locally on 2026-07-22.

- Added a protected, premium Habit Management screen with active, paused, and
  archived sections, drag ordering, intentional empty/loading/error states, and
  compact-device support.
- Added keyboard-safe create/edit sheets with category, symbol, active weekday,
  native reminder-time, validation, retry, and explicit saved feedback.
- Added pause/resume, archive/restore, history, and a permanent-delete warning
  that explains completion-history and XP consequences.
- Made Home refresh immediately after management, filter today's server-active
  plan, and offer server-backed completion Undo.
- Added weekly timezone-aware native reminders regenerated from the confirmed
  active plan after edits and on cold start.
- Prevented startup repair from overwriting onboarding promises that users have
  customized in the Habit Engine.

## Milestone: partial-migration recovery

Status: complete locally on 2026-07-22.

- Replaced the unsafe SQL order identifier with `sort_position` across the
  database, RPC, Flutter model, repository, onboarding payload, and tests.
- Made migration 001 recover a legacy partially applied `position` column
  without dropping it or overwriting an existing `sort_position`.
- Added an additive repair migration that can be rerun without changing XP,
  completions, user-edited habits, policies, constraints, indexes, or triggers.
- Documented the required SQL Editor recovery order before compatibility
  migration 002 is applied.
