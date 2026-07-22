import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_env.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/session_controller.dart';
import '../features/auth/data/email_confirmation_link_source.dart';
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
    this.notificationPermissionService,
    this.initialLocation = '/splash',
  });

  final SessionController? sessionController;
  final OnboardingRepository? onboardingRepository;
  final OnboardingGateController? onboardingGateController;
  final MorningRepository? morningRepository;
  final NotificationPermissionService? notificationPermissionService;
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
  late final NotificationPermissionService _notificationPermissionService;
  late final bool _ownsOnboardingGate;
  late final Listenable _routerRefresh;
  late final GoRouter _router;
  String? _notificationSyncFingerprint;

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
          confirmationLinks: AppEnv.hasSupabaseConfig
              ? AppLinksEmailConfirmationLinkSource()
              : null,
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
    _notificationPermissionService =
        widget.notificationPermissionService ??
        (AppEnv.hasSupabaseConfig
            ? DeviceNotificationPermissionService()
            : const DisabledNotificationPermissionService());
    _routerRefresh = Listenable.merge([_session, _onboardingGate]);
    _session.addListener(_synchronizeOnboardingGate);
    _onboardingGate.addListener(_synchronizeNotifications);
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
          builder: (_, _) => AuthScreen(
            initialMessage: _session.callbackErrorMessage,
            canResendConfirmation: _session.canResendConfirmation,
          ),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => OnboardingScreen(
            repository: _onboardingRepository,
            notificationPermissionService: _notificationPermissionService,
            onCompleted: (profile) {
              _onboardingGate.markCompleted(profile);
              _router.go('/home');
            },
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => HomeScreen(
            repository: _morningRepository,
            onSignOut: _session.signOut,
            onEnableReminders: _enableHomeReminders,
            onRefreshReminderPermission: _refreshHomeReminderPermission,
          ),
        ),
      ],
    );
  }

  void _synchronizeOnboardingGate() {
    if (_session.isAuthenticated) {
      _onboardingGate.resolve();
    } else if (_session.isReady) {
      _notificationSyncFingerprint = null;
      _onboardingGate.reset();
    }
  }

  void _synchronizeNotifications() {
    final profile = _onboardingGate.profile;
    if (!_session.isAuthenticated ||
        !_onboardingGate.isCompleted ||
        profile == null ||
        !profile.isCompleted) {
      return;
    }
    final fingerprint = _notificationFingerprint(profile);
    if (_notificationSyncFingerprint == fingerprint) return;
    _notificationSyncFingerprint = fingerprint;
    unawaited(_synchronizePersistedNotifications(profile, fingerprint));
  }

  String _notificationFingerprint(OnboardingProfile profile) => [
    profile.notificationPreference.name,
    profile.timeZone,
    profile.wakeTimeMinutes,
    profile.sleepTimeMinutes,
    profile.disciplineLevel?.name,
    ...profile.goals.map((goal) => goal.name),
  ].join(':');

  Future<NotificationRecoveryResult> _enableHomeReminders() async {
    final profile = _onboardingGate.profile;
    if (profile == null) {
      return const NotificationRecoveryResult(
        state: NotificationRecoveryState.failed,
        preference: NotificationPreference.denied,
      );
    }
    final recovery = await _notificationPermissionService.helpEnable(
      profile.notificationPreference,
    );
    if (recovery.isGranted) return _activateHomeReminders(profile);
    if (recovery.state == NotificationRecoveryState.denied &&
        recovery.preference != profile.notificationPreference) {
      await _persistNotificationPreference(profile, recovery.preference);
    }
    return recovery;
  }

  Future<bool> _refreshHomeReminderPermission() async {
    final profile = _onboardingGate.profile;
    if (profile == null) return false;
    final permission = await _notificationPermissionService.currentPermission();
    if (permission != NotificationPreference.granted) return false;
    final result = await _activateHomeReminders(profile);
    return result.isGranted;
  }

  Future<NotificationRecoveryResult> _activateHomeReminders(
    OnboardingProfile profile,
  ) async {
    final updated = profile.copyWith(
      notificationPreference: NotificationPreference.granted,
    );
    try {
      final synchronized = await _notificationPermissionService.synchronize(
        updated,
      );
      if (!synchronized.remindersReady) {
        return NotificationRecoveryResult(
          state: NotificationRecoveryState.failed,
          preference: profile.notificationPreference,
        );
      }
      await _onboardingRepository.save(updated);
      _notificationSyncFingerprint = _notificationFingerprint(updated);
      _onboardingGate.updateProfile(updated);
      return const NotificationRecoveryResult(
        state: NotificationRecoveryState.granted,
        preference: NotificationPreference.granted,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[notifications] Home recovery failed: $error');
        debugPrintStack(
          label: '[notifications] Home recovery stack trace',
          stackTrace: stackTrace,
        );
      }
      return NotificationRecoveryResult(
        state: NotificationRecoveryState.failed,
        preference: profile.notificationPreference,
      );
    }
  }

  Future<void> _persistNotificationPreference(
    OnboardingProfile profile,
    NotificationPreference preference,
  ) async {
    final updated = profile.copyWith(notificationPreference: preference);
    try {
      await _onboardingRepository.save(updated);
      _notificationSyncFingerprint = _notificationFingerprint(updated);
      _onboardingGate.updateProfile(updated);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[notifications] permission state save failed: $error');
        debugPrintStack(
          label: '[notifications] permission state save stack trace',
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _synchronizePersistedNotifications(
    OnboardingProfile profile,
    String fingerprint,
  ) async {
    try {
      final result = await _notificationPermissionService.synchronize(profile);
      final grantedButUnavailable =
          profile.notificationPreference == NotificationPreference.granted &&
          !result.remindersReady;
      if (grantedButUnavailable &&
          _notificationSyncFingerprint == fingerprint) {
        _notificationSyncFingerprint = null;
      }
    } catch (error, stackTrace) {
      if (_notificationSyncFingerprint == fingerprint) {
        _notificationSyncFingerprint = null;
      }
      if (kDebugMode) {
        debugPrint('[notifications] persisted synchronization failed: $error');
        debugPrintStack(
          label: '[notifications] persisted synchronization stack trace',
          stackTrace: stackTrace,
        );
      }
    }
  }

  @override
  void dispose() {
    _session.removeListener(_synchronizeOnboardingGate);
    _onboardingGate.removeListener(_synchronizeNotifications);
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
