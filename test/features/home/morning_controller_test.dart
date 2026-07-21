import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/habits/domain/habit.dart';
import 'package:forge_app/features/home/data/morning_repository.dart';
import 'package:forge_app/features/home/domain/morning_snapshot.dart';
import 'package:forge_app/features/home/presentation/morning_controller.dart';

void main() {
  test('loads the current morning snapshot', () async {
    final repository = _MemoryMorningRepository(_snapshot());
    final controller = MorningController(
      repository,
      now: () => DateTime(2026, 7, 21, 8),
    );

    await controller.initialize();

    expect(controller.status, MorningStatus.ready);
    expect(controller.snapshot?.displayName, 'Brian');
  });

  test('optimistically completes a habit and persists it', () async {
    final repository = _MemoryMorningRepository(_snapshot());
    final controller = MorningController(repository);
    await controller.initialize();

    await controller.toggleHabit('focus');

    expect(controller.snapshot?.habits.first.isComplete, isTrue);
    expect(controller.snapshot?.totalXp, 240);
    expect(repository.lastHabitId, 'focus');
    expect(repository.lastCompletion, isTrue);
  });

  test('rolls back an optimistic completion when persistence fails', () async {
    final repository = _MemoryMorningRepository(_snapshot(), shouldFail: true);
    final controller = MorningController(repository);
    await controller.initialize();

    await controller.toggleHabit('focus');

    expect(controller.snapshot?.habits.first.isComplete, isFalse);
    expect(controller.snapshot?.totalXp, 200);
    expect(controller.errorMessage, isNotNull);
  });
}

MorningSnapshot _snapshot() => MorningSnapshot(
  displayName: 'Brian',
  dayNumber: 12,
  totalXp: 200,
  currentStreak: 6,
  longestStreak: 9,
  habits: const [Habit(id: 'focus', title: 'Deep work', xp: 40)],
  forDate: DateTime(2026, 7, 21),
);

class _MemoryMorningRepository implements MorningRepository {
  _MemoryMorningRepository(this.value, {this.shouldFail = false});

  final MorningSnapshot value;
  final bool shouldFail;
  String? lastHabitId;
  bool? lastCompletion;

  @override
  Future<MorningSnapshot> load(DateTime date) async => value;

  @override
  Future<void> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  }) async {
    if (shouldFail) throw Exception('offline');
    lastHabitId = habitId;
    lastCompletion = isComplete;
  }
}
