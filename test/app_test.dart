import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/app/app.dart';
import 'package:forge_app/features/auth/presentation/session_controller.dart';
import 'package:forge_app/features/onboarding/data/onboarding_repository.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
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

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily commitments'), findsOneWidget);
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
      ProviderScope(
        child: ForgeApp(
          sessionController: controller,
          initialLocation: '/auth',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily commitments'), findsOneWidget);
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

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
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
      ProviderScope(
        child: ForgeApp(
          sessionController: controller,
          initialLocation: '/home',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
    expect(find.text('Daily commitments'), findsNothing);
  });

  testWidgets('sign out returns the user to authentication', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
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
      ProviderScope(
        child: ForgeApp(
          sessionController: controller,
          onboardingRepository: onboarding,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('This plan was built\naround you.'), findsOneWidget);
    expect(find.text('Daily commitments'), findsNothing);
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
      ProviderScope(
        child: ForgeApp(
          sessionController: controller,
          onboardingRepository: onboarding,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily commitments'), findsOneWidget);
    expect(find.text('You already took\nthe hardest step.'), findsNothing);
  });

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
      ProviderScope(
        child: ForgeApp(
          sessionController: controller,
          onboardingRepository: onboarding,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Daily commitments'), findsNothing);

    profile.complete(const OnboardingProfile());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('You already took\nthe hardest step.'), findsOneWidget);
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

  Future<void> dispose() => _changes.close();
}

class _FakeOnboardingRepository implements OnboardingRepository {
  _FakeOnboardingRepository(this.value, {this.loadCallback});

  OnboardingProfile value;
  final Future<OnboardingProfile> Function()? loadCallback;

  @override
  Future<OnboardingProfile> load() async =>
      loadCallback?.call() ?? Future.value(value);

  @override
  Future<void> save(OnboardingProfile profile) async => value = profile;
}
