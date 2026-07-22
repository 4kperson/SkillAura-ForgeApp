import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/onboarding/data/notification_permission_service.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const expectedNativePermission = String.fromEnvironment(
    'NOTIFICATION_PERMISSION_EXPECTATION',
  );
  if (expectedNativePermission.isNotEmpty) {
    testWidgets('reads the configured native permission state', (tester) async {
      final service = DeviceNotificationPermissionService();

      final preference = await service.requestPermission();

      expect(preference.name, expectedNativePermission);
    });
  }

  testWidgets('real device supports allow, deny, and skipped reminder flows', (
    tester,
  ) async {
    final platform = FlutterLocalNotificationPlatform();
    final service = DeviceNotificationPermissionService(platform: platform);

    final granted = await service.synchronize(
      _profile(NotificationPreference.granted),
    );
    expect(granted.initializationSucceeded, isTrue);
    expect(granted.schedulingState, ReminderSchedulingState.scheduled);
    expect(
      await platform.pendingNotificationIds(),
      containsAll(DeviceNotificationPermissionService.reminderIds),
    );

    final denied = await service.synchronize(
      _profile(NotificationPreference.denied),
    );
    expect(denied.initializationSucceeded, isTrue);
    expect(denied.cancellationState, ReminderCancellationState.cancelled);
    final pendingAfterDenial = await platform.pendingNotificationIds();
    expect(
      pendingAfterDenial.intersection(
        DeviceNotificationPermissionService.reminderIds.toSet(),
      ),
      isEmpty,
    );

    final skipped = await service.synchronize(
      _profile(NotificationPreference.skipped),
    );
    expect(skipped.initializationSucceeded, isTrue);
    expect(
      skipped.cancellationState,
      ReminderCancellationState.nothingToCancel,
    );
    expect(await platform.pendingNotificationIds(), isEmpty);
  });
}

OnboardingProfile _profile(NotificationPreference preference) =>
    OnboardingProfile(
      goals: const [
        OnboardingGoal.disciplined,
        OnboardingGoal.productive,
        OnboardingGoal.betterSleep,
      ],
      disciplineLevel: DisciplineLevel.improving,
      notificationPreference: preference,
    );
