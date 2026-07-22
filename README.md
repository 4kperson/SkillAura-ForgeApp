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

## Daily reminders

Forge requests notification access only after its onboarding explanation. A
granted choice schedules the three personalized starter commitments at their
configured local times. Denied and skipped choices cancel Forge reminders and
remain persisted in Supabase, so cold starts and future scheduling respect the
user's decision. Android uses inexact daily alarms to avoid requesting exact
alarm access.

Notification startup is ordered: initialize time zones, initialize the native
plugin with `@drawable/ic_stat_forge`, create the `daily_promises` channel, and
then cancel or schedule Forge-owned IDs `4100` through `4102`. Cancelling when
no reminders exist is a successful no-op. Cleanup failures are logged in debug
builds but never block a denied or skipped onboarding choice.

## Mobile email confirmation

Supabase Flutter listens for the confirmation callback and exchanges its code or
tokens for a persisted session. The native projects register this callback URI:

`com.skillaura.forge://login-callback/`

In the Supabase dashboard, open **Authentication → URL Configuration → Redirect
URLs** and add the exact URI above. Without this allow-list entry, confirmation
links cannot return to the installed app.
