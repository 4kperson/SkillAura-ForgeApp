import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';

void main() {
  test('round-trips persisted onboarding answers', () {
    final profile = OnboardingProfile.fromJson({
      'onboarding_goal': 'entrepreneur',
      'discipline_level': 'improving',
      'wake_time': '06:30:00',
      'sleep_time': '22:45:00',
      'onboarding_step': 4,
      'notifications_enabled': true,
      'onboarding_completed': false,
    });

    expect(profile.goal, OnboardingGoal.entrepreneur);
    expect(profile.disciplineLevel, DisciplineLevel.improving);
    expect(profile.wakeTimeMinutes, 390);
    expect(profile.sleepTimeMinutes, 1365);
    expect(profile.currentStep, 4);
    expect(profile.notificationsEnabled, isTrue);
    expect(profile.toJson()['wake_time'], '06:30:00');
  });

  test('creates goal-aware starting habits', () {
    const profile = OnboardingProfile(goal: OnboardingGoal.student);

    expect(profile.recommendedHabits, [
      'Plan the day',
      'Focused study',
      'Read 20 minutes',
    ]);
  });

  test('uses safe defaults for a new or partially persisted profile', () {
    final profile = OnboardingProfile.fromJson(const {});

    expect(profile.currentStep, 0);
    expect(profile.wakeTimeMinutes, 420);
    expect(profile.sleepTimeMinutes, 1380);
    expect(profile.isCompleted, isFalse);
  });
}
