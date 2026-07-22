import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/app/app.dart';
import 'package:forge_app/features/auth/presentation/session_controller.dart';
import 'package:forge_app/features/onboarding/data/notification_permission_service.dart';
import 'package:forge_app/features/onboarding/data/onboarding_repository.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';

void main() {
  testWidgets('unauthenticated launch resolves to authentication', (
    tester,
  ) async {
    final source = _FakeSessionSource();
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(ForgeApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
  });

  testWidgets('authenticated launch resolves directly to home', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(ForgeApp(sessionController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Make today count.'), findsOneWidget);
  });

  testWidgets('authenticated confirmation callback resolves to home', (
    tester,
  ) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ForgeApp(sessionController: controller, initialLocation: '/auth'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make today count.'), findsOneWidget);
  });

  testWidgets('shows a splash while the stored session is resolving', (
    tester,
  ) async {
    final restore = Completer<bool>();
    final source = _FakeSessionSource(restore: () => restore.future);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(ForgeApp(sessionController: controller));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    restore.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
  });

  testWidgets('protected home route redirects signed-out users', (
    tester,
  ) async {
    final source = _FakeSessionSource();
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ForgeApp(sessionController: controller, initialLocation: '/home'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
    expect(find.text('Make today count.'), findsNothing);
  });

  testWidgets('sign out returns the user to authentication', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(ForgeApp(sessionController: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
  });

  testWidgets('authenticated incomplete users resume onboarding', (
    tester,
  ) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    final onboarding = _FakeOnboardingRepository(
      const OnboardingProfile(
        goals: [OnboardingGoal.student],
        disciplineLevel: DisciplineLevel.improving,
        currentStep: 4,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ForgeApp(sessionController: controller, onboardingRepository: onboarding),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('This plan was built\naround you.'), findsOneWidget);
    expect(find.text('Make today count.'), findsNothing);
  });

  testWidgets('completed users never see onboarding again', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    final onboarding = _FakeOnboardingRepository(
      const OnboardingProfile(isCompleted: true),
    );
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ForgeApp(sessionController: controller, onboardingRepository: onboarding),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make today count.'), findsOneWidget);
    expect(find.text('You already took\nthe hardest step.'), findsNothing);
  });

  testWidgets('cold start restores Home and synchronizes persisted reminders', (
    tester,
  ) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    final notifications = _FakeNotificationPermissionService();
    final onboarding = _FakeOnboardingRepository(
      const OnboardingProfile(
        isCompleted: true,
        notificationPreference: NotificationPreference.denied,
      ),
    );
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ForgeApp(
        sessionController: controller,
        onboardingRepository: onboarding,
        notificationPermissionService: notifications,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make today count.'), findsOneWidget);
    expect(notifications.synchronizedProfiles, hasLength(1));
    expect(
      notifications.synchronizedProfiles.single.notificationPreference,
      NotificationPreference.denied,
    );
  });

  testWidgets('app restart restores an authenticated user directly to Home', (
    tester,
  ) async {
    final source = _FakeSessionSource(signedIn: true);
    final onboarding = _FakeOnboardingRepository(
      const OnboardingProfile(isCompleted: true),
    );
    final firstController = SessionController(source);

    await tester.pumpWidget(
      ForgeApp(
        sessionController: firstController,
        onboardingRepository: onboarding,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Make today count.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    firstController.dispose();

    final restoredController = SessionController(source);
    addTearDown(() async {
      restoredController.dispose();
      await source.dispose();
    });
    await tester.pumpWidget(
      ForgeApp(
        sessionController: restoredController,
        onboardingRepository: onboarding,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make today count.'), findsOneWidget);
    expect(find.text('Return to the\nwork that matters.'), findsNothing);
  });

  testWidgets(
    'complete onboarding then logout and login restores Home permanently',
    (tester) async {
      final source = _FakeSessionSource(signedIn: true);
      final controller = SessionController(source);
      final onboarding = _FakeOnboardingRepository(const OnboardingProfile());
      addTearDown(() async {
        controller.dispose();
        await source.dispose();
      });

      await tester.pumpWidget(
        ForgeApp(
          sessionController: controller,
          onboardingRepository: onboarding,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));

      Future<void> advance(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await advance('Make the commitment');
      await advance('Build discipline');
      await advance('Shape my path');
      await advance('Beginner');
      await advance('Set my starting standard');
      await advance('Build around my rhythm');
      await advance('Commit to this Day One');
      await advance('Not now');
      await advance('Start Day One');

      expect(onboarding.value.isCompleted, isTrue);
      expect(onboarding.completeCalls, 1);
      expect(onboarding.value.goals, [OnboardingGoal.disciplined]);
      expect(onboarding.value.disciplineLevel, DisciplineLevel.starting);
      expect(onboarding.value.recommendedHabits, hasLength(3));
      expect(find.text('Make today count.'), findsOneWidget);

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Return to the\nwork that matters.'), findsOneWidget);

      source.signIn();
      await tester.pumpAndSettle();

      expect(find.text('Make today count.'), findsOneWidget);
      expect(find.text('You already took\nthe hardest step.'), findsNothing);
    },
  );

  testWidgets('holds splash until onboarding status resolves', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    final profile = Completer<OnboardingProfile>();
    final onboarding = _FakeOnboardingRepository(
      const OnboardingProfile(),
      loadCallback: () => profile.future,
    );
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ForgeApp(sessionController: controller, onboardingRepository: onboarding),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Make today count.'), findsNothing);

    profile.complete(const OnboardingProfile());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('You already took\nthe hardest step.'), findsOneWidget);
  });

  testWidgets('profile load failure never restarts onboarding', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    final onboarding = _FakeOnboardingRepository(
      const OnboardingProfile(),
      loadCallback: () async => throw Exception('offline'),
    );
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ForgeApp(sessionController: controller, onboardingRepository: onboarding),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Your journey is safe.'), findsOneWidget);
    expect(find.text('You already took\nthe hardest step.'), findsNothing);
    expect(find.text('Make today count.'), findsNothing);
  });
}

class _FakeSessionSource implements SessionSource {
  _FakeSessionSource({this.signedIn = false, this.restore});

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool signedIn;
  final Future<bool> Function()? restore;

  @override
  Future<bool> restoreSignedInState() =>
      restore?.call() ?? Future.value(signedIn);

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  @override
  Stream<Object> get authErrors => const Stream<Object>.empty();

  @override
  Future<void> signOut() async {
    signedIn = false;
    _changes.add(false);
  }

  void signIn() {
    signedIn = true;
    _changes.add(true);
  }

  Future<void> dispose() => _changes.close();
}

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository(this.value, {this.loadCallback});

  OnboardingProfile value;
  final Future<OnboardingProfile> Function()? loadCallback;
  int completeCalls = 0;

  @override
  Future<OnboardingProfile> load() async =>
      loadCallback?.call() ?? Future.value(value);

  @override
  Future<void> save(OnboardingProfile profile) async => value = profile;

  @override
  Future<void> complete(OnboardingProfile profile) async {
    completeCalls++;
    value = profile;
  }
}

class _FakeNotificationPermissionService
    implements NotificationPermissionService {
  final List<OnboardingProfile> synchronizedProfiles = [];

  @override
  Future<NotificationPreference> requestPermission() async =>
      NotificationPreference.denied;

  @override
  Future<void> synchronize(OnboardingProfile profile) async {
    synchronizedProfiles.add(profile);
  }
}
