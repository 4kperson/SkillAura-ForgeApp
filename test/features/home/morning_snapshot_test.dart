import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/habits/domain/habit.dart';
import 'package:forge_app/features/home/domain/morning_snapshot.dart';

void main() {
  test('turns raw progress into emotionally meaningful metrics', () {
    final snapshot = MorningSnapshot(
      displayName: 'Brian',
      dayNumber: 12,
      totalXp: 620,
      currentStreak: 8,
      longestStreak: 11,
      habits: const [
        Habit(id: 'move', title: 'Morning movement', xp: 20, isComplete: true),
        Habit(id: 'focus', title: 'Deep work', xp: 40),
        Habit(id: 'read', title: 'Read 20 minutes', xp: 20),
      ],
      forDate: DateTime(2026, 7, 21),
    );

    expect(snapshot.completedCount, 1);
    expect(snapshot.completion, closeTo(1 / 3, .001));
    expect(snapshot.todayXp, 20);
    expect(snapshot.levelProgress.level, 3);
    expect(snapshot.levelProgress.xpRemaining, 130);
    expect(snapshot.dayIdentity, 'Consistency is your superpower.');
  });

  test('celebrates keeping every promise', () {
    final snapshot = MorningSnapshot(
      displayName: 'Brian',
      dayNumber: 3,
      totalXp: 100,
      currentStreak: 2,
      longestStreak: 2,
      habits: const [
        Habit(id: 'focus', title: 'Deep work', xp: 40, isComplete: true),
      ],
      forDate: DateTime(2026, 7, 21),
    );

    expect(snapshot.dayIdentity, 'You kept every promise today.');
  });
}
