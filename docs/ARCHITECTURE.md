# Architecture

## Principles
- Feature-first folders to keep product areas independent.
- ChangeNotifier controllers behind testable repository and service interfaces.
- GoRouter for explicit navigation.
- Supabase behind repositories, never called directly from UI widgets.
- Firebase Crashlytics handles production crash reporting.

## Layers
1. Presentation: screens, widgets, controllers.
2. Domain: entities and business rules.
3. Data: repositories, Supabase data sources, local cache.

## Onboarding persistence

`OnboardingProfile` is the single domain model for selected goals, difficulty,
routine, resume position, notification preference, and completion. Its plan
engine turns those inputs into three routine-aware starter habits with explicit
effort and XP expectations. Presentation code talks only to the
`OnboardingRepository` interface. The Supabase implementation stores every goal
in `profiles.onboarding_goals`; it still reads the legacy single-goal column so
existing profiles migrate without data loss. The row remains protected by the
existing owner-only row-level security policy.

`OnboardingGateController` resolves only after authentication. Routing remains
on the splash screen until both session and onboarding status are known, which
prevents Auth, Onboarding, or Home from flashing during startup. Completion
updates Supabase before the gate permits Home. Profile-load failures remain on
a recoverable splash state and are never interpreted as incomplete onboarding.

`SupabaseOnboardingRepository` calls the idempotent `ensure_user_profile` RPC
before reads and partial writes. Final completion uses `complete_onboarding` so
the complete profile and its three personalized starter habits are committed in
one server transaction. Supabase remains the only persistence source of truth.

## Morning experience

`MorningSnapshot` is the presentation-ready aggregate for the first Home view.
`SupabaseMorningRepository` builds it from the authenticated user's profile,
active habits, and today's completion rows. `MorningController` owns loading,
optimistic one-tap completion, rollback, and retry messaging. Completion writes
go through an ownership-checked database function so the completion row and XP
remain atomic and idempotent.

Home renders only `MorningRepository` data. Completing a mission optimistically
updates the experience, persists through `set_habit_completion`, then reloads
the server snapshot so XP and streak state remain authoritative. Completed
missions remain in the domain snapshot for progress calculations but disappear
from the action list.

## Notification boundary

`NotificationPermissionService` owns native permission interpretation and
local reminder scheduling. Onboarding first persists the exact granted,
denied, or skipped state to Supabase, then synchronizes device reminders. The
application also synchronizes the persisted profile once after an authenticated
cold start. Non-granted states always cancel Forge-owned reminder identifiers.

The service reports permission, scheduling, and cancellation independently.
Initialization is shared and awaited exactly once per service instance in this
order: time-zone database and local zone, platform plugin, Android channel.
Scheduling uses unique IDs `4100`-`4102` with inexact allow-while-idle delivery;
it does not require exact-alarm access. Cancellation first inspects pending
requests and treats an empty result as success. Every native operation logs its
exception and complete stack trace in debug builds without including secrets.

The Morning snapshot reads `notifications_enabled` from the same profile query
that supplies XP and streak data. This keeps Supabase authoritative without an
extra Home request and lets the interface acknowledge when reminders are quiet.

Permission recovery is also owned by `NotificationPermissionService`. It uses
the native request when the operating system can still present one and opens
platform app settings after a permanent Android denial or an iOS denial. Both
onboarding and Home observe app resume, re-check native permission, schedule
reminders, and only then persist `granted`. `OnboardingGateController` receives
that saved profile immediately, avoiding a duplicate profile query or reminder
sync during the same transition.

XP is modeled as cumulative progression through `LevelProgress`, including the
current level floor, next level target, and remaining XP. UI percentages are a
derived presentation detail rather than the source of truth.

## Email confirmation boundary

`Supabase.initialize` explicitly enables PKCE and SDK URI-session detection.
`AppLinksEmailConfirmationLinkSource` observes both the cold-start URI and links
received while Forge is already running. `SessionController` holds the splash
while a valid callback is exchanging, then routes from the resulting Supabase
auth event. It classifies error callbacks independently so malformed, expired,
consumed, and mismatched-verifier links reach the existing Auth screen with a
recoverable message. Supabase remains responsible for code exchange and session
persistence; Forge never attempts a second exchange.

The callback target is validated as scheme `com.skillaura.forge` and host
`login-callback`. Android registers both values in its browsable intent filter;
iOS registers the custom scheme and Forge validates the host in Dart.

## Mission completion state

An incomplete mission remains unchanged while its server completion is pending.
The controller locks duplicate taps and the card shows a loading control. XP and
the completed state appear only after the completion RPC succeeds. A short
confirmed check state then transitions to the existing disappearing-card and
day-complete behavior.

## Branch policy
- `main`: production-ready only.
- `develop`: integration branch.
- `feature/<issue>-<name>`: one scoped feature.
- `fix/<issue>-<name>`: defect fixes.
- Changes enter through pull requests and must pass CI.
