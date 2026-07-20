import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_env.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class ForgeApp extends StatefulWidget {
  const ForgeApp({
    super.key,
    this.sessionController,
    this.initialLocation = '/splash',
  });

  final SessionController? sessionController;
  final String initialLocation;

  @override
  State<ForgeApp> createState() => _ForgeAppState();
}

class _ForgeAppState extends State<ForgeApp> {
  late final SessionController _session;
  late final bool _ownsSession;
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
    _router = GoRouter(
      initialLocation: widget.initialLocation,
      refreshListenable: _session,
      redirect: (context, state) {
        final location = state.matchedLocation;
        if (!_session.isReady) return location == '/splash' ? null : '/splash';
        if (!_session.isAuthenticated) {
          return location == '/auth' ? null : '/auth';
        }
        return switch (location) {
          '/auth' || '/splash' || '/onboarding' => '/home',
          _ => null,
        };
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => HomeScreen(onSignOut: _session.signOut),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
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

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}
