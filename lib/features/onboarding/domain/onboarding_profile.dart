enum OnboardingGoal {
  disciplined,
  healthier,
  productive,
  student,
  entrepreneur,
  betterHabits,
}

enum DisciplineLevel { starting, improving, consistent }

class OnboardingProfile {
  const OnboardingProfile({
    this.goal,
    this.disciplineLevel,
    this.wakeTimeMinutes = 7 * 60,
    this.sleepTimeMinutes = 23 * 60,
    this.currentStep = 0,
    this.notificationsEnabled,
    this.isCompleted = false,
  });

  final OnboardingGoal? goal;
  final DisciplineLevel? disciplineLevel;
  final int wakeTimeMinutes;
  final int sleepTimeMinutes;
  final int currentStep;
  final bool? notificationsEnabled;
  final bool isCompleted;

  static const totalSteps = 7;

  List<String> get recommendedHabits => switch (goal) {
    OnboardingGoal.healthier => const [
      'Morning movement',
      'Drink water',
      'Evening reset',
    ],
    OnboardingGoal.student => const [
      'Plan the day',
      'Focused study',
      'Read 20 minutes',
    ],
    OnboardingGoal.entrepreneur => const [
      'Morning priorities',
      'Deep work',
      'Daily review',
    ],
    OnboardingGoal.betterHabits => const [
      'Morning routine',
      'One focused hour',
      'Evening reflection',
    ],
    OnboardingGoal.disciplined ||
    OnboardingGoal.productive ||
    null => const ['Morning routine', 'Deep work', 'Read 20 minutes'],
  };

  OnboardingProfile copyWith({
    OnboardingGoal? goal,
    DisciplineLevel? disciplineLevel,
    int? wakeTimeMinutes,
    int? sleepTimeMinutes,
    int? currentStep,
    bool? notificationsEnabled,
    bool clearNotificationPreference = false,
    bool? isCompleted,
  }) => OnboardingProfile(
    goal: goal ?? this.goal,
    disciplineLevel: disciplineLevel ?? this.disciplineLevel,
    wakeTimeMinutes: wakeTimeMinutes ?? this.wakeTimeMinutes,
    sleepTimeMinutes: sleepTimeMinutes ?? this.sleepTimeMinutes,
    currentStep: currentStep ?? this.currentStep,
    notificationsEnabled: clearNotificationPreference
        ? null
        : notificationsEnabled ?? this.notificationsEnabled,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  factory OnboardingProfile.fromJson(Map<String, dynamic> json) {
    return OnboardingProfile(
      goal: _goalFromValue(json['onboarding_goal'] as String?),
      disciplineLevel: _levelFromValue(json['discipline_level'] as String?),
      wakeTimeMinutes: _timeToMinutes(json['wake_time'] as String?) ?? 7 * 60,
      sleepTimeMinutes:
          _timeToMinutes(json['sleep_time'] as String?) ?? 23 * 60,
      currentStep: (json['onboarding_step'] as num?)?.toInt() ?? 0,
      notificationsEnabled: json['notifications_enabled'] as bool?,
      isCompleted: json['onboarding_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'onboarding_goal': goal?.name,
    'discipline_level': disciplineLevel?.name,
    'wake_time': _minutesToTime(wakeTimeMinutes),
    'sleep_time': _minutesToTime(sleepTimeMinutes),
    'onboarding_step': currentStep.clamp(0, totalSteps - 1),
    'notifications_enabled': notificationsEnabled,
    'onboarding_completed': isCompleted,
    'onboarding_updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  static OnboardingGoal? _goalFromValue(String? value) {
    for (final goal in OnboardingGoal.values) {
      if (goal.name == value) return goal;
    }
    return null;
  }

  static DisciplineLevel? _levelFromValue(String? value) {
    for (final level in DisciplineLevel.values) {
      if (level.name == value) return level;
    }
    return null;
  }

  static int? _timeToMinutes(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  static String _minutesToTime(int minutes) {
    final normalized = minutes.clamp(0, 1439);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }
}
