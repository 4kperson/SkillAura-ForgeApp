import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/onboarding/data/notification_permission_service.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('maps every accepted native status to granted', () {
    expect(
      notificationPreferenceFor(PermissionStatus.granted),
      NotificationPreference.granted,
    );
    expect(
      notificationPreferenceFor(PermissionStatus.provisional),
      NotificationPreference.granted,
    );
  });

  test('maps native refusal states to denied', () {
    for (final status in [
      PermissionStatus.denied,
      PermissionStatus.permanentlyDenied,
      PermissionStatus.restricted,
    ]) {
      expect(notificationPreferenceFor(status), NotificationPreference.denied);
    }
  });

  test('builds one daily reminder for each personalized starter habit', () {
    const profile = OnboardingProfile(
      goals: [
        OnboardingGoal.disciplined,
        OnboardingGoal.productive,
        OnboardingGoal.betterSleep,
      ],
      disciplineLevel: DisciplineLevel.improving,
      wakeTimeMinutes: 6 * 60 + 30,
      sleepTimeMinutes: 22 * 60 + 30,
      notificationPreference: NotificationPreference.granted,
    );

    final reminders = buildDailyReminders(profile);

    expect(reminders, hasLength(3));
    expect(reminders.map((reminder) => reminder.title), [
      'Plan your three priorities',
      '35 minutes of focused work',
      'Begin a 35-minute wind-down',
    ]);
    expect(reminders.map((reminder) => (reminder.hour, reminder.minute)), [
      (7, 0),
      (8, 0),
      (21, 55),
    ]);
  });
}
