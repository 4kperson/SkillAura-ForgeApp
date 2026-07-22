# Forge — SkillAura Apps

Production-oriented starter for a discipline and habit-building mobile app targeting iOS and Android.

## Included
- Flutter feature-first architecture
- Testable ChangeNotifier presentation controllers
- GoRouter navigation
- Dark violet design system
- Persistent personalized onboarding and real daily commitments
- Supabase schema with row-level security
- Firebase Crashlytics bootstrap hook
- Permission-aware local daily reminders
- Unit/widget tests
- GitHub Actions CI
- Architecture, decisions, and testing documentation

## Local setup
1. Install the latest Flutter stable SDK.
2. Run `flutter create . --platforms=android,ios` inside this folder to generate native platform projects.
3. Run `flutter pub get`.
4. Configure Supabase and pass environment values using `--dart-define`.
5. Configure Firebase with FlutterFire CLI.
6. Run `flutter test`, then `flutter run`.

Example:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

Never commit production secrets. Supabase's publishable/anon key is designed for clients, while database protection must be enforced through RLS.

### Apply database migrations

Apply the SQL files in `supabase/migrations` to the connected Supabase project
in filename order. Sprint 2 requires
`202607210002_repair_onboarding_profile.sql`; it adds the profile fields used to
save answers, resume progress, notification preference, and permanent
completion without recreating the existing `profiles` table. The migration
also includes verification queries for columns, RLS, and owner policies.

Sprint 3 also requires `202607210003_morning_completion_rpc.sql`, which adds
the authenticated completion function used to keep habit completion and XP
changes atomic.

The personalized onboarding polish requires
`202607210004_personalized_onboarding.sql`. It adds the non-destructive
`onboarding_goals text[]` column used to persist every selected priority. The
legacy single-goal column and all existing profile rows remain unchanged.

The product-stability release requires
`202607210005_product_stability.sql`. Run it after the earlier migrations. It:

- repairs missing profile creation for existing and future authenticated users;
- persists notification permission state;
- stores the personalized onboarding plan as real habits;
- keeps completion, XP, and streak changes server-owned;
- restores missing habit tables, policies, trigger, and RPCs idempotently for
  projects whose earliest schema migration only partially completed.

Sprint 4 requires `202607220001_habit_engine.sql`. Run it after the product
stability migration. It preserves the onboarding-generated habits and adds the
editable category, symbol, reminder, weekday, timezone, order, paused,
archived, and update fields. It also records completion dates, completion
timestamps, awarded XP, and source while retaining the legacy compatibility
columns. Completion, undo, reorder, and permanent deletion use authenticated
server functions so XP and history remain atomic. The migration is additive,
idempotent, and contains verification queries for columns, RLS, policies,
indexes, and functions.

Then run `202607220002_habit_engine_compatibility.sql`. It upgrades future
onboarding plans to the same editable habit contract, preserves starter habits
the user already customized, and repairs completion undo for projects that
already applied the first Sprint 4 migration. Both migrations are required,
additive, idempotent, and contain no table drops or truncation.

## Daily reminders

Forge requests notification access only after its onboarding explanation. A
granted choice schedules the confirmed active habit plan at its configured
weekdays, times, and IANA timezones. Denied and skipped choices cancel Forge
reminders and remain persisted in Supabase, so cold starts and future scheduling
respect the user's decision. Android uses inexact alarms to avoid requesting
exact alarm access.

Notification startup is ordered: initialize time zones, initialize the native
plugin with `@drawable/ic_stat_forge`, create the `daily_promises` channel, and
then cancel or schedule Forge-owned IDs. Onboarding uses `4100` through `4102`;
the Habit Engine uses deterministic IDs in a separate reserved range. Cancelling
when no reminders exist is a successful no-op. Cleanup failures are logged in
debug builds but never block a denied or skipped onboarding choice.

Denied permission and **Not now** share one respectful recovery experience.
Users can continue directly to Home or ask Forge to enable reminders. Forge
uses the native prompt while it is still available and opens the app's system
settings when the platform requires it. Home keeps a subtle, tappable reminder
card visible until access is granted; returning from settings is detected and
the persisted profile and local schedule are refreshed automatically.

## Mobile email confirmation

Supabase Flutter is initialized with PKCE and automatic callback detection. It
exchanges the callback code for a persisted session, while Forge separately
classifies callback failures so expired, consumed, malformed, and mismatched
PKCE links never leave the user on a blank or generic error state. The native
projects register this callback URI:

`com.skillaura.forge://login-callback/`

In the Supabase dashboard, open **Authentication → URL Configuration** and set:

```text
Site URL:
https://skillaura.io

Allowed Redirect URLs:
com.skillaura.forge://login-callback/
com.skillaura.forge://**
```

The exact URL is used by signup and resend. The wildcard supports callback
parameters and future auth callback paths under the same private scheme. If the
redirect is not allow-listed, Supabase falls back to the Site URL instead of
returning to Forge. Keep the signup email template on Supabase's generated
`{{ .ConfirmationURL }}` so verification remains on the secure hosted endpoint
before redirecting into the app.

Expired, consumed, and mismatched-PKCE callbacks offer **Resend confirmation**.
Users enter their account email and Forge sends a new signup confirmation using
the same mobile redirect. Only the newest link should be opened on the device
that requested it.
