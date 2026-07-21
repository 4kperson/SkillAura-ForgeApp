import '../../habits/domain/habit.dart';

class MorningSnapshot {
  const MorningSnapshot({
    required this.displayName,
    required this.dayNumber,
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.habits,
    required this.forDate,
  });

  final String displayName;
  final int dayNumber;
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final List<Habit> habits;
  final DateTime forDate;

  int get completedCount => habits.where((habit) => habit.isComplete).length;
  int get totalCount => habits.length;
  double get completion => totalCount == 0 ? 0 : completedCount / totalCount;
  int get todayXp => habits
      .where((habit) => habit.isComplete)
      .fold(0, (total, habit) => total + habit.xp);

  LevelProgress get levelProgress => LevelProgress.fromTotalXp(totalXp);

  String get dayIdentity {
    if (completedCount == totalCount && totalCount > 0) {
      return 'You kept every promise today.';
    }
    if (currentStreak >= 7) return 'Consistency is your superpower.';
    if (currentStreak >= 3) return 'Momentum looks good on you.';
    if (dayNumber == 1) return 'Today is where momentum begins.';
    return 'One focused day changes the next.';
  }

  MorningSnapshot copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    List<Habit>? habits,
  }) => MorningSnapshot(
    displayName: displayName,
    dayNumber: dayNumber,
    totalXp: totalXp ?? this.totalXp,
    currentStreak: currentStreak ?? this.currentStreak,
    longestStreak: longestStreak ?? this.longestStreak,
    habits: habits ?? this.habits,
    forDate: forDate,
  );
}

class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
  });

  final int level;
  final int xpIntoLevel;
  final int xpForNextLevel;

  int get xpRemaining => xpForNextLevel - xpIntoLevel;
  double get fraction => xpIntoLevel / xpForNextLevel;

  static LevelProgress fromTotalXp(int totalXp) {
    final safeXp = totalXp < 0 ? 0 : totalXp;
    const xpPerLevel = 250;
    return LevelProgress(
      level: safeXp ~/ xpPerLevel + 1,
      xpIntoLevel: safeXp % xpPerLevel,
      xpForNextLevel: xpPerLevel,
    );
  }
}
