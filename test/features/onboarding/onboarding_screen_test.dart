import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/core/theme/app_theme.dart';
import 'package:forge_app/features/onboarding/data/notification_permission_service.dart';
import 'package:forge_app/features/onboarding/data/onboarding_repository.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:forge_app/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  Widget subject(
    OnboardingRepository repository, {
    ValueChanged<OnboardingProfile>? onCompleted,
  }) => MaterialApp(
    theme: AppTheme.dark,
    home: OnboardingScreen(
      repository: repository,
      onCompleted: onCompleted,
      notificationPermissionService: _FakeNotificationService(
        permission: NotificationPreference.granted,
      ),
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
          notificationPermissionService: _FakeNotificationService(
            permission: NotificationPreference.granted,
            onRequest: () => requested = true,
          ),
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
    expect(
      repository.value.notificationPreference,
      NotificationPreference.granted,
    );
    expect(find.text('Your first promise\nis waiting.'), findsOneWidget);
  });

  testWidgets('denied notifications are acknowledged before continuing', (
    tester,
  ) async {
    var completed = false;
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(currentStep: 5),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(
          repository: repository,
          notificationPermissionService: _FakeNotificationService(
            permission: NotificationPreference.denied,
          ),
          onCompleted: (_) => completed = true,
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
    expect(find.text('REMINDERS ARE OFF'), findsOneWidget);
    expect(
      find.text('Notifications are\ncurrently turned off.'),
      findsOneWidget,
    );
    expect(find.text('Enable reminders'), findsOneWidget);
    expect(find.text('Continue without reminders'), findsOneWidget);
    expect(find.textContaining('inside the app instead'), findsNothing);

    await tester.tap(find.text('Continue without reminders'));
    await tester.pumpAndSettle();

    expect(repository.value.isCompleted, isTrue);
    expect(completed, isTrue);
  });

  testWidgets('denied choice stays calm when cleanup cannot run', (
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
          notificationPermissionService: _FakeNotificationService(
            permission: NotificationPreference.denied,
            syncResult: const NotificationSyncResult(
              permissionState: NotificationPreference.denied,
              initializationSucceeded: false,
              schedulingState: ReminderSchedulingState.notRequested,
              cancellationState: ReminderCancellationState.failed,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep me on track'));
    await tester.pumpAndSettle();

    expect(find.text('REMINDERS ARE OFF'), findsOneWidget);
    expect(find.textContaining('could not be prepared'), findsNothing);
    expect(find.textContaining('could not be cleared'), findsNothing);
  });

  testWidgets('granted choice offers retry when scheduling fails', (
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
          notificationPermissionService: _FakeNotificationService(
            permission: NotificationPreference.granted,
            syncResult: const NotificationSyncResult(
              permissionState: NotificationPreference.granted,
              initializationSucceeded: true,
              schedulingState: ReminderSchedulingState.failed,
              cancellationState: ReminderCancellationState.nothingToCancel,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep me on track'));
    await tester.pumpAndSettle();

    expect(find.text('Support when\nintention gets busy.'), findsOneWidget);
    expect(find.textContaining('could not be prepared'), findsOneWidget);
  });

  testWidgets('Not now uses the same disabled screen without requesting', (
    tester,
  ) async {
    var requested = false;
    var completed = false;
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(currentStep: 5),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(
          repository: repository,
          notificationPermissionService: _FakeNotificationService(
            permission: NotificationPreference.denied,
            onRequest: () => requested = true,
            syncResult: const NotificationSyncResult(
              permissionState: NotificationPreference.skipped,
              initializationSucceeded: false,
              schedulingState: ReminderSchedulingState.notRequested,
              cancellationState: ReminderCancellationState.failed,
            ),
          ),
          onCompleted: (_) => completed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(
      repository.value.notificationPreference,
      NotificationPreference.skipped,
    );
    expect(requested, isFalse);
    expect(repository.value.currentStep, 5);
    expect(find.text('REMINDERS ARE OFF'), findsOneWidget);
    expect(
      find.text('Notifications are\ncurrently turned off.'),
      findsOneWidget,
    );
    expect(find.text('Enable reminders'), findsOneWidget);
    expect(find.textContaining('could not be cleared'), findsNothing);

    await tester.tap(find.text('Continue without reminders'));
    await tester.pumpAndSettle();

    expect(repository.value.isCompleted, isTrue);
    expect(completed, isTrue);
  });

  testWidgets('unified reminder-off screen is safe on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(
          repository: _MemoryOnboardingRepository(
            const OnboardingProfile(
              currentStep: 5,
              notificationPreference: NotificationPreference.skipped,
            ),
          ),
          notificationPermissionService: _FakeNotificationService(
            permission: NotificationPreference.denied,
          ),
          onCompleted: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Notifications are\ncurrently turned off.'),
      findsOneWidget,
    );
    expect(find.text('Enable reminders'), findsOneWidget);
    expect(find.text('Continue without reminders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Enable reminders recovers a skipped choice', (tester) async {
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(
        currentStep: 5,
        notificationPreference: NotificationPreference.skipped,
      ),
    );
    final notifications = _FakeNotificationService(
      permission: NotificationPreference.granted,
      recoveryResult: const NotificationRecoveryResult(
        state: NotificationRecoveryState.granted,
        preference: NotificationPreference.granted,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(
          repository: repository,
          notificationPermissionService: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable reminders'));
    await tester.pumpAndSettle();

    expect(notifications.recoveryCalls, 1);
    expect(
      repository.value.notificationPreference,
      NotificationPreference.granted,
    );
    expect(repository.value.currentStep, 6);
    expect(find.text('Your first promise\nis waiting.'), findsOneWidget);
  });

  testWidgets('returning from settings restores reminders and continues', (
    tester,
  ) async {
    final repository = _MemoryOnboardingRepository(
      const OnboardingProfile(
        currentStep: 5,
        notificationPreference: NotificationPreference.denied,
      ),
    );
    final notifications = _FakeNotificationService(
      permission: NotificationPreference.denied,
      permissionOnResume: NotificationPreference.granted,
      recoveryResult: const NotificationRecoveryResult(
        state: NotificationRecoveryState.settingsOpened,
        preference: NotificationPreference.denied,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnboardingScreen(
          repository: repository,
          notificationPermissionService: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enable reminders'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      repository.value.notificationPreference,
      NotificationPreference.granted,
    );
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
      subject(repository, onCompleted: (_) => completed = true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Start Day One'));
    await tester.pump();

    expect(repository.value.isCompleted, isTrue);
    expect(completed, isTrue);
  });
}

class _FakeNotificationService implements NotificationPermissionService {
  _FakeNotificationService({
    required this.permission,
    this.onRequest,
    this.syncResult,
    this.recoveryResult,
    this.permissionOnResume,
  });

  final NotificationPreference permission;
  final VoidCallback? onRequest;
  final NotificationSyncResult? syncResult;
  final NotificationRecoveryResult? recoveryResult;
  final NotificationPreference? permissionOnResume;
  final List<OnboardingProfile> synchronizedProfiles = [];
  var recoveryCalls = 0;

  @override
  Future<NotificationPreference> requestPermission() async {
    onRequest?.call();
    return permission;
  }

  @override
  Future<NotificationRecoveryResult> helpEnable(
    NotificationPreference currentPreference,
  ) async {
    recoveryCalls++;
    return recoveryResult ??
        NotificationRecoveryResult(
          state: NotificationRecoveryState.denied,
          preference: currentPreference,
        );
  }

  @override
  Future<NotificationPreference?> currentPermission() async =>
      permissionOnResume ?? permission;

  @override
  Future<NotificationSyncResult> synchronize(OnboardingProfile profile) async {
    synchronizedProfiles.add(profile);
    return syncResult ??
        NotificationSyncResult(
          permissionState: profile.notificationPreference,
          initializationSucceeded: true,
          schedulingState:
              profile.notificationPreference == NotificationPreference.granted
              ? ReminderSchedulingState.scheduled
              : ReminderSchedulingState.notRequested,
          cancellationState: ReminderCancellationState.nothingToCancel,
        );
  }
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
