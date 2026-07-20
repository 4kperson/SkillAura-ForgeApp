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
