enum OnboardingGoal {
  disciplined,
  healthier,
  productive,
  student,
  betterSleep,
  reduceScreenTime,
}

enum DisciplineLevel { starting, improving, consistent }

enum StarterHabitKind { discipline, health, focus, study, sleep, screenTime }

class StarterHabit {
  const StarterHabit({
    required this.title,
    required this.cue,
    required this.xp,
    required this.effortMinutes,
    required this.kind,
  });

  final String title;
  final String cue;
  final int xp;
  final int effortMinutes;
  final StarterHabitKind kind;
}

class OnboardingProfile {
  const OnboardingProfile({
    this.goals = const [],
    this.disciplineLevel,
    this.wakeTimeMinutes = 7 * 60,
    this.sleepTimeMinutes = 23 * 60,
    this.currentStep = 0,
    this.notificationsEnabled,
    this.isCompleted = false,
  });

  final List<OnboardingGoal> goals;
  final DisciplineLevel? disciplineLevel;
  final int wakeTimeMinutes;
  final int sleepTimeMinutes;
  final int currentStep;
  final bool? notificationsEnabled;
  final bool isCompleted;

  static const totalSteps = 7;
  static const maxGoals = 3;

  OnboardingGoal? get primaryGoal => goals.isEmpty ? null : goals.first;

  List<StarterHabit> get recommendedHabits {
    final level = disciplineLevel ?? DisciplineLevel.starting;
    final selected = goals.isEmpty ? const [OnboardingGoal.disciplined] : goals;
    final habits = <StarterHabit>[];

    for (final goal in selected) {
      _addUnique(habits, _habitFor(goal, level));
      if (habits.length == 3) return habits;
    }

    for (final fallback in const [
      OnboardingGoal.disciplined,
      OnboardingGoal.productive,
      OnboardingGoal.betterSleep,
      OnboardingGoal.healthier,
    ]) {
      _addUnique(habits, _habitFor(fallback, level));
      if (habits.length == 3) break;
    }
    return habits;
  }

  int get startingXpTarget =>
      recommendedHabits.fold(0, (sum, habit) => sum + habit.xp);

  String get personalizationSummary {
    final level = switch (disciplineLevel ?? DisciplineLevel.starting) {
      DisciplineLevel.starting => 'Beginner',
      DisciplineLevel.improving => 'Intermediate',
      DisciplineLevel.consistent => 'Advanced',
    };
    final goalCount = goals.length == 1
        ? '1 priority'
        : '${goals.length} priorities';
    return '$goalCount · $level · ${_formatTime(wakeTimeMinutes)}–${_formatTime(sleepTimeMinutes)}';
  }

  OnboardingProfile copyWith({
    List<OnboardingGoal>? goals,
    DisciplineLevel? disciplineLevel,
    int? wakeTimeMinutes,
    int? sleepTimeMinutes,
    int? currentStep,
    bool? notificationsEnabled,
    bool clearNotificationPreference = false,
    bool? isCompleted,
  }) => OnboardingProfile(
    goals: goals ?? this.goals,
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
    final persistedGoals =
        (json['onboarding_goals'] as List?)
            ?.whereType<String>()
            .map(_goalFromValue)
            .whereType<OnboardingGoal>()
            .toList() ??
        const <OnboardingGoal>[];
    final legacyGoal = _goalFromValue(json['onboarding_goal'] as String?);

    return OnboardingProfile(
      goals: persistedGoals.isNotEmpty ? persistedGoals : [?legacyGoal],
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
    'onboarding_goals': goals.map((goal) => goal.name).toList(),
    'discipline_level': disciplineLevel?.name,
    'wake_time': _minutesToTime(wakeTimeMinutes),
    'sleep_time': _minutesToTime(sleepTimeMinutes),
    'onboarding_step': currentStep.clamp(0, totalSteps - 1),
    'notifications_enabled': notificationsEnabled,
    'onboarding_completed': isCompleted,
    'onboarding_updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  StarterHabit _habitFor(OnboardingGoal goal, DisciplineLevel level) {
    final scale = _DifficultyScale.forLevel(level);
    return switch (goal) {
      OnboardingGoal.disciplined => StarterHabit(
        title: switch (level) {
          DisciplineLevel.starting => 'Make one promise before 9 AM',
          DisciplineLevel.improving => 'Plan your three priorities',
          DisciplineLevel.consistent => 'Finish your hardest task first',
        },
        cue: '${_formatTime(wakeTimeMinutes + 30)} · Win the opening hour',
        xp: scale.baseXp,
        effortMinutes: scale.shortMinutes,
        kind: StarterHabitKind.discipline,
      ),
      OnboardingGoal.healthier => StarterHabit(
        title: 'Move for ${scale.mediumMinutes} minutes',
        cue: '${_formatTime(wakeTimeMinutes + 45)} · Energy before urgency',
        xp: scale.mediumXp,
        effortMinutes: scale.mediumMinutes,
        kind: StarterHabitKind.health,
      ),
      OnboardingGoal.productive => StarterHabit(
        title: '${scale.focusMinutes} minutes of focused work',
        cue: '${_formatTime(wakeTimeMinutes + 90)} · One protected block',
        xp: scale.focusXp,
        effortMinutes: scale.focusMinutes,
        kind: StarterHabitKind.focus,
      ),
      OnboardingGoal.student => StarterHabit(
        title: 'Study one topic for ${scale.focusMinutes} minutes',
        cue: '${_formatTime(wakeTimeMinutes + 120)} · Recall before review',
        xp: scale.focusXp,
        effortMinutes: scale.focusMinutes,
        kind: StarterHabitKind.study,
      ),
      OnboardingGoal.betterSleep => StarterHabit(
        title: 'Begin a ${scale.windDownMinutes}-minute wind-down',
        cue:
            '${_formatTime(sleepTimeMinutes - scale.windDownMinutes)} · Protect tomorrow tonight',
        xp: scale.mediumXp,
        effortMinutes: scale.windDownMinutes,
        kind: StarterHabitKind.sleep,
      ),
      OnboardingGoal.reduceScreenTime => StarterHabit(
        title: 'Keep the first ${scale.screenFreeMinutes} minutes phone-free',
        cue: '${_formatTime(wakeTimeMinutes)} · Start with your own attention',
        xp: scale.baseXp,
        effortMinutes: scale.screenFreeMinutes,
        kind: StarterHabitKind.screenTime,
      ),
    };
  }

  static void _addUnique(List<StarterHabit> habits, StarterHabit candidate) {
    if (habits.any((habit) => habit.kind == candidate.kind)) return;
    habits.add(candidate);
  }

  static OnboardingGoal? _goalFromValue(String? value) {
    if (value == 'entrepreneur') return OnboardingGoal.productive;
    if (value == 'betterHabits') return OnboardingGoal.disciplined;
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

  static String _formatTime(int minutes) {
    final normalized = minutes % 1440;
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour < 12 ? 'AM' : 'PM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}

class _DifficultyScale {
  const _DifficultyScale({
    required this.shortMinutes,
    required this.mediumMinutes,
    required this.focusMinutes,
    required this.windDownMinutes,
    required this.screenFreeMinutes,
    required this.baseXp,
    required this.mediumXp,
    required this.focusXp,
  });

  final int shortMinutes;
  final int mediumMinutes;
  final int focusMinutes;
  final int windDownMinutes;
  final int screenFreeMinutes;
  final int baseXp;
  final int mediumXp;
  final int focusXp;

  factory _DifficultyScale.forLevel(DisciplineLevel level) => switch (level) {
    DisciplineLevel.starting => const _DifficultyScale(
      shortMinutes: 5,
      mediumMinutes: 10,
      focusMinutes: 15,
      windDownMinutes: 20,
      screenFreeMinutes: 10,
      baseXp: 10,
      mediumXp: 15,
      focusXp: 20,
    ),
    DisciplineLevel.improving => const _DifficultyScale(
      shortMinutes: 10,
      mediumMinutes: 20,
      focusMinutes: 35,
      windDownMinutes: 35,
      screenFreeMinutes: 25,
      baseXp: 20,
      mediumXp: 25,
      focusXp: 35,
    ),
    DisciplineLevel.consistent => const _DifficultyScale(
      shortMinutes: 15,
      mediumMinutes: 35,
      focusMinutes: 60,
      windDownMinutes: 50,
      screenFreeMinutes: 45,
      baseXp: 30,
      mediumXp: 40,
      focusXp: 55,
    ),
  };
}
