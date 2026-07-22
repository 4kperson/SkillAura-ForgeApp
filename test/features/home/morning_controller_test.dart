import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/habits/domain/habit.dart';
import 'package:forge_app/features/home/data/morning_repository.dart';
import 'package:forge_app/features/home/domain/morning_snapshot.dart';
import 'package:forge_app/features/home/presentation/morning_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('loads the current morning snapshot', () async {
    final repository = _MemoryMorningRepository(_snapshot());
    final controller = MorningController(
      repository,
      now: () => DateTime(2026, 7, 21, 8),
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.status, MorningStatus.ready);
    expect(controller.snapshot?.displayName, 'Brian');
  });

  test('completes a habit and awards XP after persistence succeeds', () async {
    final repository = _MemoryMorningRepository(_snapshot());
    final controller = MorningController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.toggleHabit('focus');

    expect(controller.snapshot?.habits.first.isComplete, isTrue);
    expect(controller.snapshot?.totalXp, 240);
    expect(repository.lastHabitId, 'focus');
    expect(repository.lastCompletion, isTrue);
  });

  test(
    'keeps a promise incomplete while server confirmation is pending',
    () async {
      final repository = _MemoryMorningRepository(
        _snapshot(),
        saveDelay: const Duration(milliseconds: 20),
      );
      final controller = MorningController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      final completion = controller.toggleHabit('focus');

      expect(controller.isUpdating('focus'), isTrue);
      expect(controller.snapshot?.habits.first.isComplete, isFalse);
      expect(controller.snapshot?.totalXp, 200);

      await completion;

      expect(controller.isUpdating('focus'), isFalse);
      expect(controller.snapshot?.habits.first.isComplete, isTrue);
      expect(controller.snapshot?.totalXp, 240);
    },
  );

  test('rolls back an optimistic completion when persistence fails', () async {
    final repository = _MemoryMorningRepository(_snapshot(), shouldFail: true);
    final controller = MorningController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.toggleHabit('focus');

    expect(controller.snapshot?.habits.first.isComplete, isFalse);
    expect(controller.snapshot?.totalXp, 200);
    expect(controller.errorMessage, isNotNull);
  });

  for (final failure in <String, Object>{
    'inactive-day attempt': const PostgrestException(
      message: 'Habit is not active today',
      code: '22023',
    ),
    'RPC/schema mismatch': const PostgrestException(
      message: 'Could not find the function',
      code: 'PGRST202',
    ),
    'RLS rejection': const PostgrestException(
      message: 'permission denied',
      code: '42501',
    ),
  }.entries) {
    test('${failure.key} never changes completion or XP', () async {
      final repository = _MemoryMorningRepository(
        _snapshot(),
        failure: failure.value,
      );
      final controller = MorningController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      expect(await controller.toggleHabit('focus'), isFalse);

      expect(controller.snapshot?.habits.first.isComplete, isFalse);
      expect(controller.snapshot?.totalXp, 200);
      expect(controller.errorMessage, contains('not saved'));
    });
  }

  test(
    'ignores duplicate completion taps while the first save is active',
    () async {
      final repository = _MemoryMorningRepository(
        _snapshot(),
        saveDelay: const Duration(milliseconds: 20),
      );
      final controller = MorningController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      final first = controller.toggleHabit('focus');
      final duplicate = controller.toggleHabit('focus');
      await Future.wait([first, duplicate]);

      expect(repository.completionCalls, 1);
      expect(controller.snapshot?.totalXp, 240);
    },
  );

  test(
    'undo reverses the confirmed completion and its XP exactly once',
    () async {
      final repository = _MemoryMorningRepository(_snapshot());
      final controller = MorningController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      expect(await controller.toggleHabit('focus'), isTrue);
      expect(controller.snapshot?.totalXp, 240);
      expect(await controller.undoHabit('focus'), isTrue);

      expect(controller.snapshot?.habits.first.isComplete, isFalse);
      expect(controller.snapshot?.totalXp, 200);
      expect(repository.completionCalls, 2);
      expect(await controller.undoHabit('focus'), isFalse);
      expect(repository.completionCalls, 2);
    },
  );

  test('server duplicate completion does not award XP again', () async {
    final repository = _MemoryMorningRepository(
      _snapshot(),
      forceUnchanged: true,
    );
    final controller = MorningController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(await controller.toggleHabit('focus'), isFalse);
    expect(controller.snapshot?.totalXp, 200);
    expect(repository.completionCalls, 1);
  });
}

MorningSnapshot _snapshot() => MorningSnapshot(
  displayName: 'Brian',
  identityLabel: 'more disciplined',
  dayNumber: 12,
  totalXp: 200,
  currentStreak: 6,
  longestStreak: 9,
  habits: const [Habit(id: 'focus', title: 'Deep work', xp: 40)],
  forDate: DateTime(2026, 7, 21),
);

class _MemoryMorningRepository implements MorningRepository {
  _MemoryMorningRepository(
    this.value, {
    this.shouldFail = false,
    this.saveDelay,
    this.failure,
    this.forceUnchanged = false,
  });

  MorningSnapshot value;
  final bool shouldFail;
  final Duration? saveDelay;
  final Object? failure;
  final bool forceUnchanged;
  String? lastHabitId;
  bool? lastCompletion;
  int completionCalls = 0;

  @override
  Future<MorningSnapshot> load(DateTime date) async => value;

  @override
  Future<HabitCompletionResult> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  }) async {
    completionCalls++;
    if (saveDelay case final delay?) await Future<void>.delayed(delay);
    if (failure case final error?) throw error;
    if (shouldFail) throw Exception('offline');
    if (forceUnchanged) {
      return HabitCompletionResult(
        completionDate: value.forDate,
        changed: false,
        totalXp: value.totalXp,
      );
    }
    lastHabitId = habitId;
    lastCompletion = isComplete;
    final index = value.habits.indexWhere((habit) => habit.id == habitId);
    final habit = value.habits[index];
    final habits = [...value.habits]
      ..[index] = habit.copyWith(isComplete: isComplete);
    value = value.copyWith(
      habits: habits,
      totalXp: value.totalXp + (isComplete ? habit.xp : -habit.xp),
    );
    return HabitCompletionResult(
      completionDate: value.forDate,
      changed: true,
      totalXp: value.totalXp,
    );
  }
}
