# Architecture

## Principles
- Feature-first folders to keep product areas independent.
- Riverpod for testable state and dependency injection.
- GoRouter for explicit navigation.
- Supabase behind repositories, never called directly from UI widgets.
- RevenueCat is the subscription entitlement source of truth.
- Firebase Crashlytics handles production crash reporting.

## Layers
1. Presentation: screens, widgets, controllers.
2. Domain: entities and business rules.
3. Data: repositories, Supabase data sources, local cache.

## Branch policy
- `main`: production-ready only.
- `develop`: integration branch.
- `feature/<issue>-<name>`: one scoped feature.
- `fix/<issue>-<name>`: defect fixes.
- Changes enter through pull requests and must pass CI.
