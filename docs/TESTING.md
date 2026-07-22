# Testing strategy

## Every pull request
- Formatting check
- Static analysis
- Unit tests
- Widget tests

## Before beta
- Authentication integration tests
- Database/RLS tests
- Subscription sandbox tests on iOS and Android
- Accessibility checks
- Offline/slow-network behavior
- Crash recovery and analytics event validation

## Release gates
No release with critical crashes, broken purchases, data loss, authentication lockout, or failing CI.

## Persistence regression gate

The application test suite must cover this complete route lifecycle:

1. Authenticated new account enters onboarding.
2. Every onboarding decision is persisted and Day One completes.
3. The user signs out.
4. The same account signs in again.
5. The router waits for the server profile and opens Home without rendering
   onboarding.

Profile-load failures must remain on the recoverable splash state. They must
never be converted into an onboarding-required state.

Sprint 3 stabilization additionally verifies authenticated cold start, app
restart, Home after onboarding and reauthentication, granted/denied permission
mapping, personalized reminder times, the disabled-reminder Home state, the
zero-mission recovery state, and duplicate completion taps. The server RPC's
unique completion key remains the final protection against duplicate XP awards.

Notification lifecycle tests cover granted scheduling success and rollback on
failure; denied and skipped cleanup with zero or existing reminders; cleanup
requested before initialization; calm denied/skipped UI behavior after a native
cleanup failure; and restoration of the persisted notification preference. The
final UX gate also covers Allow, Deny, Not now, native prompt versus settings
selection, the actionable Home reminder card, and automatic restoration after
returning from system settings.

Sprint 3 final acceptance coverage verifies the exact signup and resend redirect,
cold-start and already-running confirmation callbacks, session creation and
routing, malformed callbacks, expired and consumed links, PKCE mismatch recovery,
and the resend action. Morning tests verify that incomplete promises have no
checkmark, loading blocks duplicate input, XP is not awarded before server
success, and the confirmed check appears only after persistence succeeds.

Sprint 4 database tests assert that the migration is additive, owner-only RLS
has no permissive `true` policy, completion mutation is server-owned, the
habit/date key prevents duplicate completion and XP, and active-day evaluation
uses the habit timezone on the server.

Habit domain and controller tests cover full-row parsing, active and missed
weekdays, paused/archived eligibility, reminder serialization, validation,
recorded-XP history, create, edit, pause/resume, archive/restore, delete,
reorder persistence, reorder rollback, failed save recovery, and load failure.
