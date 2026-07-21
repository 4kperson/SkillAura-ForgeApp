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

  testWidgets('requires and persists an identity choice', (tester) async {
    final repository = _MemoryOnboardingRepository();
    await tester.pumpWidget(subject(repository));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.ensureVisible(find.text('Make the commitment'));
    await tester.tap(find.text('Make the commitment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'This is who I am becoming'),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(find.text('More disciplined'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.text('This is who I am becoming'));
    await tester.tap(find.text('This is who I am becoming'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(repository.value.goal, OnboardingGoal.disciplined);
    expect(repository.value.currentStep, 2);
    expect(find.text('Where are you\nright now?'), findsOneWidget);
  });

  testWidgets('resumes directly at the persisted plan step', (tester) async {
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(
        goal: OnboardingGoal.student,
        disciplineLevel: DisciplineLevel.improving,
        currentStep: 4,
      ),
    );

    await tester.pumpWidget(subject(repository));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.text('Small enough to start.\nStrong enough to matter.'),
      findsOneWidget,
    );
    expect(find.text('Focused study'), findsOneWidget);
  });
}

class _MemoryOnboardingRepository implements OnboardingRepository {
  _MemoryOnboardingRepository([this.value = const OnboardingProfile()]);

  OnboardingProfile value;

  @override
  Future<OnboardingProfile> load() async => value;

  @override
  Future<void> save(OnboardingProfile profile) async => value = profile;
}
