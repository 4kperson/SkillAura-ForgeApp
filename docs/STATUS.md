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
