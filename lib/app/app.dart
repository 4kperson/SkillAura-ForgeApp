import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_env.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/data/morning_repository.dart';
import '../features/onboarding/data/notification_permission_service.dart';
import '../features/onboarding/data/onboarding_repository.dart';
import '../features/onboarding/domain/onboarding_profile.dart';
import '../features/onboarding/presentation/onboarding_gate_controller.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class ForgeApp extends StatefulWidget {
  const ForgeApp({
    super.key,
    this.sessionController,
    this.onboardingRepository,
    this.onboardingGateController,
    this.morningRepository,
    this.initialLocation = '/splash',
  });

  final SessionController? sessionController;
  final OnboardingRepository? onboardingRepository;
  final OnboardingGateController? onboardingGateController;
  final MorningRepository? morningRepository;
  final String initialLocation;

  @override
  State<ForgeApp> createState() => _ForgeAppState();
}

class _ForgeAppState extends State<ForgeApp> {
  late final SessionController _session;
  late final bool _ownsSession;
  late final OnboardingRepository _onboardingRepository;
  late final OnboardingGateController _onboardingGate;
  late final MorningRepository _morningRepository;
  late final bool _ownsOnboardingGate;
  late final Listenable _routerRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.sessionController == null;
    _session =
        widget.sessionController ??
        SessionController(
          AppEnv.hasSupabaseConfig
              ? SupabaseSessionSource(Supabase.instance.client)
              : const UnauthenticatedSessionSource(),
        );
    _onboardingRepository =
        widget.onboardingRepository ??
        (AppEnv.hasSupabaseConfig
            ? SupabaseOnboardingRepository(Supabase.instance.client)
            : _CompletedOnboardingRepository());
    _ownsOnboardingGate = widget.onboardingGateController == null;
    _onboardingGate =
        widget.onboardingGateController ??
        OnboardingGateController(_onboardingRepository);
    _morningRepository =
        widget.morningRepository ??
        (AppEnv.hasSupabaseConfig
            ? SupabaseMorningRepository(Supabase.instance.client)
            : const EmptyMorningRepository());
    _routerRefresh = Listenable.merge([_session, _onboardingGate]);
    _session.addListener(_synchronizeOnboardingGate);
    _synchronizeOnboardingGate();
    _router = GoRouter(
      initialLocation: widget.initialLocation,
      refreshListenable: _routerRefresh,
      redirect: (context, state) {
        final location = state.matchedLocation;
        if (!_session.isReady) return location == '/splash' ? null : '/splash';
        if (!_session.isAuthenticated) {
          return location == '/auth' ? null : '/auth';
        }
        if (_onboardingGate.isLoading) {
          return location == '/splash' ? null : '/splash';
        }
        if (_onboardingGate.hasFailed) {
          return location == '/splash' ? null : '/splash';
        }
        if (!_onboardingGate.isCompleted) {
          return location == '/onboarding' ? null : '/onboarding';
        }
        return switch (location) {
          '/auth' || '/splash' || '/onboarding' => '/home',
          _ => null,
        };
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (_, _) => AnimatedBuilder(
            animation: _routerRefresh,
            builder: (_, _) => _SplashScreen(
              profileLoadFailed:
                  _session.isAuthenticated && _onboardingGate.hasFailed,
              onRetry: _onboardingGate.resolve,
            ),
          ),
        ),
        GoRoute(
          path: '/auth',
          builder: (_, _) =>
              AuthScreen(initialMessage: _session.callbackErrorMessage),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => OnboardingScreen(
            repository: _onboardingRepository,
            notificationPermissionRequester:
                const DeviceNotificationPermissionService().request,
            onCompleted: () {
              _onboardingGate.markCompleted();
              _router.go('/home');
            },
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => HomeScreen(
            repository: _morningRepository,
            onSignOut: _session.signOut,
          ),
        ),
      ],
    );
  }

  void _synchronizeOnboardingGate() {
    if (_session.isAuthenticated) {
      _onboardingGate.resolve();
    } else if (_session.isReady) {
      _onboardingGate.reset();
    }
  }

  @override
  void dispose() {
    _session.removeListener(_synchronizeOnboardingGate);
    _router.dispose();
    if (_ownsOnboardingGate) _onboardingGate.dispose();
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Forge',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    routerConfig: _router,
  );
}

class _CompletedOnboardingRepository implements OnboardingRepository {
  @override
  Future<OnboardingProfile> load() async =>
      const OnboardingProfile(isCompleted: true);

  @override
  Future<void> save(OnboardingProfile profile) async {}

  @override
  Future<void> complete(OnboardingProfile profile) async {}
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({this.profileLoadFailed = false, this.onRetry});

  final bool profileLoadFailed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: profileLoadFailed
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 34),
                  const SizedBox(height: 18),
                  const Text(
                    'Your journey is safe.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Forge could not load your profile. We will never restart your onboarding because of a connection problem.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          : const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
    ),
  );
}
