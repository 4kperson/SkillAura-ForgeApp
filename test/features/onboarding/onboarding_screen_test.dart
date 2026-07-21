import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/core/theme/app_theme.dart';
import 'package:forge_app/features/onboarding/data/onboarding_repository.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:forge_app/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  Widget subject(
    OnboardingRepository repository, {
    VoidCallback? onCompleted,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: OnboardingScreen(
      repository: repository,
      onCompleted: onCompleted,
      notificationPermissionRequester: () async => true,
    ),
  );

  testWidgets('welcome is premium and overflow-safe on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(subject(_MemoryOnboardingRepository()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('You already took\nthe hardest step.'), findsOneWidget);
    expect(find.text('Make the commitment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires and persists multiple priority choices', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository();
    await tester.pumpWidget(subject(repository));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.ensureVisible(find.text('Make the commitment'));
    await tester.tap(find.text('Make the commitment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Shape my path'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text('Build discipline'));
    await tester.tap(find.text('Improve health'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('2 of 3 selected'), findsOneWidget);
    await tester.ensureVisible(find.text('Shape my path'));
    await tester.tap(find.text('Shape my path'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.value.goals, [
      OnboardingGoal.disciplined,
      OnboardingGoal.healthier,
    ]);
    expect(repository.value.currentStep, 2);
    expect(find.text('What challenge will\nyou respect?'), findsOneWidget);
  });

  testWidgets('resumes directly at the persisted plan step', (tester) async {
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(
        goals: [OnboardingGoal.student],
        disciplineLevel: DisciplineLevel.improving,
        currentStep: 4,
      ),
    );

    await tester.pumpWidget(subject(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('This plan was built\naround you.'), findsOneWidget);
    expect(find.text('Study one topic for 35 minutes'), findsOneWidget);
  });

  testWidgets('requests notification permission only after explanation', (
    tester,
  ) async {
    var requested = false;
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(currentStep: 5),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(
          repository: repository,
          notificationPermissionRequester: () async {
            requested = true;
            return true;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(requested, isFalse);
    expect(find.text('Support when\nintention gets busy.'), findsOneWidget);

    await tester.tap(find.text('Keep me on track'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(requested, isTrue);
    expect(repository.value.notificationsEnabled, isTrue);
    expect(find.text('Your first promise\nis waiting.'), findsOneWidget);
  });

  testWidgets('denied notifications are acknowledged before continuing', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(currentStep: 5),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(
          repository: repository,
          notificationPermissionRequester: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep me on track'));
    await tester.pumpAndSettle();

    expect(
      repository.value.notificationPreference,
      NotificationPreference.denied,
    );
    expect(repository.value.currentStep, 5);
    expect(find.text('CHOICE RESPECTED'), findsOneWidget);
    expect(find.text('Continue without reminders'), findsOneWidget);
    expect(find.textContaining('inside the app instead'), findsNothing);

    await tester.tap(find.text('Continue without reminders'));
    await tester.pumpAndSettle();

    expect(repository.value.currentStep, 6);
    expect(find.text('Your first promise\nis waiting.'), findsOneWidget);
  });

  testWidgets('Start Day One persists completion before handoff', (
    tester,
  ) async {
    var completed = false;
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(currentStep: 6),
    );
    await tester.pumpWidget(
      subject(repository, onCompleted: () => completed = true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Start Day One'));
    await tester.pump();

    expect(repository.value.isCompleted, isTrue);
    expect(completed, isTrue);
  });
}

class _MemoryOnboardingRepository implements OnboardingRepository {
  _MemoryOnboardingRepository([this.value = const OnboardingProfile()]);

  OnboardingProfile value;

  @override
  Future<OnboardingProfile> load() async => value;

  @override
  Future<void> save(OnboardingProfile profile) async => value = profile;

  @override
  Future<void> complete(OnboardingProfile profile) async => value = profile;
}
