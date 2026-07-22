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
