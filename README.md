# Forge — SkillAura Apps

Production-oriented starter for a discipline and habit-building mobile app targeting iOS and Android.

## Included
- Flutter feature-first architecture
- Riverpod state management
- GoRouter navigation
- Dark violet design system
- Runnable onboarding and daily commitments prototype
- Supabase schema with row-level security
- Firebase Crashlytics bootstrap hook
- RevenueCat dependency placeholder
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

## Mobile email confirmation

Supabase Flutter listens for the confirmation callback and exchanges its code or
tokens for a persisted session. The native projects register this callback URI:

`com.skillaura.forge://login-callback/`

In the Supabase dashboard, open **Authentication → URL Configuration → Redirect
URLs** and add the exact URI above. Without this allow-list entry, confirmation
links cannot return to the installed app.
