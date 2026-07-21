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
