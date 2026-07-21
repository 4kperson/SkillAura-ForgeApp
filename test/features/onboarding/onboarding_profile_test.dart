import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';

void main() {
  test('round-trips every selected onboarding goal', () {
    final profile = OnboardingProfile.fromJson({
      'onboarding_goals': ['healthier', 'productive', 'betterSleep'],
      'discipline_level': 'improving',
      'wake_time': '06:30:00',
      'sleep_time': '22:45:00',
      'onboarding_step': 4,
      'notifications_enabled': true,
      'onboarding_completed': false,
    });

    expect(profile.goals, const [
      OnboardingGoal.healthier,
      OnboardingGoal.productive,
      OnboardingGoal.betterSleep,
    ]);
    expect(profile.disciplineLevel, DisciplineLevel.improving);
    expect(profile.wakeTimeMinutes, 390);
    expect(profile.sleepTimeMinutes, 1365);
    expect(profile.currentStep, 4);
    expect(profile.notificationsEnabled, isTrue);
    expect(profile.notificationPreference, NotificationPreference.granted);
    expect(profile.toJson()['onboarding_goals'], [
      'healthier',
      'productive',
      'betterSleep',
    ]);
    expect(profile.toJson()['wake_time'], '06:30:00');
  });

  test('persists distinct denied and skipped notification states', () {
    const denied = OnboardingProfile(
      notificationPreference: NotificationPreference.denied,
    );
    const skipped = OnboardingProfile(
      notificationPreference: NotificationPreference.skipped,
    );

    expect(denied.toJson()['notification_permission_state'], 'denied');
    expect(denied.toJson()['notifications_enabled'], isFalse);
    expect(skipped.toJson()['notification_permission_state'], 'skipped');
    expect(skipped.toJson()['notifications_enabled'], isFalse);
  });

  test('keeps legacy single-goal profiles compatible', () {
    final entrepreneur = OnboardingProfile.fromJson({
      'onboarding_goal': 'entrepreneur',
    });
    final habits = OnboardingProfile.fromJson({
      'onboarding_goal': 'betterHabits',
    });

    expect(entrepreneur.goals, [OnboardingGoal.productive]);
    expect(habits.goals, [OnboardingGoal.disciplined]);
  });

  test('creates a goal, level, and routine-aware starting plan', () {
    const profile = OnboardingProfile(
      goals: [OnboardingGoal.productive, OnboardingGoal.betterSleep],
      disciplineLevel: DisciplineLevel.consistent,
      wakeTimeMinutes: 390,
      sleepTimeMinutes: 1350,
    );

    expect(profile.recommendedHabits.first.title, '60 minutes of focused work');
    expect(profile.recommendedHabits.first.cue, contains('8:00 AM'));
    expect(profile.recommendedHabits[1].title, 'Begin a 50-minute wind-down');
    expect(profile.recommendedHabits[1].cue, contains('9:40 PM'));
    expect(profile.startingXpTarget, greaterThan(100));
  });

  test('difficulty increases effort and XP expectations', () {
    const beginner = OnboardingProfile(
      goals: [OnboardingGoal.student],
      disciplineLevel: DisciplineLevel.starting,
    );
    const advanced = OnboardingProfile(
      goals: [OnboardingGoal.student],
      disciplineLevel: DisciplineLevel.consistent,
    );

    expect(
      advanced.recommendedHabits.first.effortMinutes,
      greaterThan(beginner.recommendedHabits.first.effortMinutes),
    );
    expect(advanced.startingXpTarget, greaterThan(beginner.startingXpTarget));
  });

  test('starter plan serializes as three server-ready habits', () {
    const profile = OnboardingProfile(
      goals: [OnboardingGoal.productive, OnboardingGoal.betterSleep],
      disciplineLevel: DisciplineLevel.improving,
      wakeTimeMinutes: 420,
      sleepTimeMinutes: 1380,
    );

    final plan = profile.recommendedHabits
        .map((habit) => habit.toJson())
        .toList();
    expect(plan, hasLength(3));
    expect(plan.first['source_key'], 'focus');
    expect(plan.first['scheduled_time'], '08:30:00');
    expect(plan.first['xp_reward'], greaterThan(0));
    expect(plan.first['effort_minutes'], greaterThan(0));
  });

  test('uses safe defaults for a new or partially persisted profile', () {
    final profile = OnboardingProfile.fromJson(const {});

    expect(profile.goals, isEmpty);
    expect(profile.currentStep, 0);
    expect(profile.wakeTimeMinutes, 420);
    expect(profile.sleepTimeMinutes, 1380);
    expect(profile.isCompleted, isFalse);
    expect(profile.recommendedHabits, hasLength(3));
  });
}
