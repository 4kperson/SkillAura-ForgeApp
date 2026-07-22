import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/habits/data/habit_repository.dart';
import 'package:forge_app/features/habits/domain/habit.dart';
import 'package:forge_app/features/habits/presentation/habit_engine_controller.dart';
import 'package:forge_app/features/home/data/morning_repository.dart';
import 'package:forge_app/features/home/domain/morning_snapshot.dart';
import 'package:forge_app/features/home/presentation/morning_controller.dart';

void main() {
  test('create and edit reload confirmed server state', () async {
    final repository = _MemoryHabitRepository();
    final controller = HabitEngineController(repository);
    await controller.initialize();

    expect(await controller.create(_draft('Read ten pages')), isTrue);
    final created = controller.library!.active.single;
    expect(created.title, 'Read ten pages');

    final changed = HabitDraft(
      title: 'Read twenty pages',
      category: HabitCategory.learning,
      symbol: HabitSymbol.book,
      reminderMinutes: 20 * 60,
      activeWeekdays: const {1, 2, 3, 4, 5},
      timeZone: 'UTC',
    );
    expect(await controller.update(created.id, changed), isTrue);
    expect(controller.library!.active.single.title, 'Read twenty pages');
    expect(controller.library!.active.single.reminderMinutes, 20 * 60);
    expect(controller.library!.active.single.activeWeekdays, {1, 2, 3, 4, 5});
  });

  test(
    'pause, resume, archive, restore, and delete keep sections correct',
    () async {
      final repository = _MemoryHabitRepository()
        ..seed(_habit('habit-1', 'Move'));
      final controller = HabitEngineController(repository);
      await controller.initialize();

      expect(await controller.setPaused('habit-1', paused: true), isTrue);
      expect(controller.library!.paused, hasLength(1));
      expect(await controller.setPaused('habit-1', paused: false), isTrue);
      expect(controller.library!.active, hasLength(1));

      expect(await controller.setArchived('habit-1', archived: true), isTrue);
      expect(controller.library!.archived, hasLength(1));
      expect(await controller.setArchived('habit-1', archived: false), isTrue);
      expect(controller.library!.active, hasLength(1));

      expect(await controller.delete('habit-1'), isTrue);
      expect(controller.library!.habits, isEmpty);
    },
  );

  test('reorder is immediate, persists, and reloads server order', () async {
    final repository = _MemoryHabitRepository()
      ..seed(_habit('one', 'One', sortPosition: 0))
      ..seed(_habit('two', 'Two', sortPosition: 1))
      ..seed(_habit('three', 'Three', sortPosition: 2));
    final controller = HabitEngineController(repository);
    await controller.initialize();

    final result = await controller.reorderActive(0, 2);

    expect(result, isTrue);
    expect(repository.lastOrder, ['two', 'three', 'one']);
    expect(controller.library!.active.map((habit) => habit.id), [
      'two',
      'three',
      'one',
    ]);
  });

  test('reorders last to first and a middle item deterministically', () async {
    final repository = _MemoryHabitRepository()
      ..seed(_habit('one', 'One', sortPosition: 0))
      ..seed(_habit('two', 'Two', sortPosition: 1))
      ..seed(_habit('three', 'Three', sortPosition: 2))
      ..seed(_habit('four', 'Four', sortPosition: 3));
    final controller = HabitEngineController(repository);
    await controller.initialize();

    expect(await controller.reorderActive(3, 0), isTrue);
    expect(repository.lastOrder, ['four', 'one', 'two', 'three']);

    expect(await controller.reorderActive(1, 3), isTrue);
    expect(repository.lastOrder, ['four', 'two', 'three', 'one']);
  });

  test('reorder persists after a fresh controller reload', () async {
    final repository = _MemoryHabitRepository()
      ..seed(_habit('one', 'One', sortPosition: 0))
      ..seed(_habit('two', 'Two', sortPosition: 1))
      ..seed(_habit('three', 'Three', sortPosition: 2));
    final firstController = HabitEngineController(repository);
    await firstController.initialize();
    expect(await firstController.reorderActive(2, 0), isTrue);

    final restoredController = HabitEngineController(repository);
    await restoredController.initialize();

    expect(restoredController.library!.active.map((habit) => habit.id), [
      'three',
      'one',
      'two',
    ]);
  });

  test('Home and Habit Manager load the same manual order', () async {
    final repository = _MemoryHabitRepository()
      ..seed(_habit('one', 'One', sortPosition: 0))
      ..seed(_habit('two', 'Two', sortPosition: 1))
      ..seed(_habit('three', 'Three', sortPosition: 2));
    final manager = HabitEngineController(repository);
    await manager.initialize();
    expect(await manager.reorderActive(0, 2), isTrue);

    final home = MorningController(_HabitBackedMorningRepository(repository));
    addTearDown(home.dispose);
    await home.initialize();

    expect(home.snapshot!.habits.map((habit) => habit.id), [
      'two',
      'three',
      'one',
    ]);
    expect(
      home.snapshot!.habits.map((habit) => habit.id),
      manager.library!.active.map((habit) => habit.id),
    );
  });

  test('pause, resume, archive, and restore preserve manual order', () async {
    final repository = _MemoryHabitRepository()
      ..seed(_habit('one', 'One', sortPosition: 0))
      ..seed(_habit('two', 'Two', sortPosition: 1))
      ..seed(_habit('three', 'Three', sortPosition: 2));
    final controller = HabitEngineController(repository);
    await controller.initialize();

    expect(await controller.setPaused('two', paused: true), isTrue);
    expect(await controller.reorderActive(1, 0), isTrue);
    expect(repository.lastOrder, ['three', 'one', 'two']);
    expect(await controller.setPaused('two', paused: false), isTrue);
    expect(controller.library!.active.map((habit) => habit.id), [
      'three',
      'one',
      'two',
    ]);

    expect(await controller.setArchived('one', archived: true), isTrue);
    expect(await controller.reorderActive(1, 0), isTrue);
    expect(repository.lastOrder, ['two', 'three', 'one']);
    expect(await controller.setArchived('one', archived: false), isTrue);
    expect(controller.library!.active.map((habit) => habit.id), [
      'two',
      'three',
      'one',
    ]);
  });

  test('reorder repairs duplicate positions into a sequential order', () async {
    final repository = _MemoryHabitRepository()
      ..seed(_habit('one', 'One', sortPosition: 0))
      ..seed(_habit('two', 'Two', sortPosition: 0))
      ..seed(_habit('three', 'Three', sortPosition: 5));
    final controller = HabitEngineController(repository);
    await controller.initialize();

    expect(await controller.reorderActive(2, 0), isTrue);

    expect(controller.library!.habits.map((habit) => habit.sortPosition), [
      0,
      1,
      2,
    ]);
    expect(repository.lastOrder, ['three', 'one', 'two']);
  });

  test(
    'failed save keeps confirmed server habit and gives recoverable copy',
    () async {
      final repository = _MemoryHabitRepository()
        ..seed(_habit('habit-1', 'Original'))
        ..failMutations = true;
      final controller = HabitEngineController(repository);
      await controller.initialize();

      final saved = await controller.update('habit-1', _draft('Unsaved edit'));

      expect(saved, isFalse);
      expect(controller.library!.habits.single.title, 'Original');
      expect(controller.errorMessage, contains('not saved'));
    },
  );

  test('failed reorder rolls back the optimistic order', () async {
    final repository = _MemoryHabitRepository()
      ..seed(_habit('one', 'One', sortPosition: 0))
      ..seed(_habit('two', 'Two', sortPosition: 1));
    final controller = HabitEngineController(repository);
    await controller.initialize();
    repository.failMutations = true;

    final saved = await controller.reorderActive(0, 1);

    expect(saved, isFalse);
    expect(controller.library!.active.map((habit) => habit.id), ['one', 'two']);
    expect(controller.errorMessage, contains('previous order'));
  });

  test('loading and failure states are explicit', () async {
    final repository = _MemoryHabitRepository()..failLoads = true;
    final controller = HabitEngineController(repository);

    await controller.initialize();

    expect(controller.status, HabitEngineStatus.failed);
    expect(controller.errorMessage, contains('could not be loaded'));
  });
}

HabitDraft _draft(String title) => HabitDraft(
  title: title,
  category: HabitCategory.learning,
  symbol: HabitSymbol.book,
  reminderMinutes: 19 * 60,
  activeWeekdays: const {1, 2, 3, 4, 5, 6, 7},
  timeZone: 'UTC',
);

Habit _habit(String id, String title, {int sortPosition = 0}) => Habit(
  id: id,
  userId: 'user-1',
  title: title,
  xp: 10,
  sortPosition: sortPosition,
  timeZone: 'UTC',
);

class _MemoryHabitRepository implements HabitRepository {
  final List<Habit> _habits = [];
  var _counter = 0;
  bool failLoads = false;
  bool failMutations = false;
  List<String>? lastOrder;

  void seed(Habit habit) => _habits.add(habit);

  @override
  Future<HabitLibrary> load() async {
    if (failLoads) throw StateError('offline');
    final sorted = [..._habits]
      ..sort((a, b) => a.sortPosition.compareTo(b.sortPosition));
    return HabitLibrary(habits: sorted, timeZone: 'UTC');
  }

  @override
  Future<Habit> create(HabitDraft draft) async {
    _failIfNeeded();
    final habit = Habit(
      id: 'created-${_counter++}',
      userId: 'user-1',
      title: draft.title.trim(),
      category: draft.category,
      symbol: draft.symbol,
      reminderMinutes: draft.reminderMinutes,
      activeWeekdays: draft.activeWeekdays,
      timeZone: draft.timeZone,
      sortPosition: _habits.length,
      xp: 10,
    );
    _habits.add(habit);
    return habit;
  }

  @override
  Future<Habit> update(String habitId, HabitDraft draft) async {
    _failIfNeeded();
    final index = _index(habitId);
    final changed = _habits[index].copyWith(
      title: draft.title.trim(),
      category: draft.category,
      symbol: draft.symbol,
      reminderMinutes: draft.reminderMinutes,
      clearReminder: draft.reminderMinutes == null,
      activeWeekdays: draft.activeWeekdays,
      timeZone: draft.timeZone,
    );
    _habits[index] = changed;
    return changed;
  }

  @override
  Future<Habit> setPaused(String habitId, {required bool paused}) async {
    _failIfNeeded();
    final index = _index(habitId);
    return _habits[index] = _habits[index].copyWith(isPaused: paused);
  }

  @override
  Future<Habit> setArchived(String habitId, {required bool archived}) async {
    _failIfNeeded();
    final index = _index(habitId);
    return _habits[index] = _habits[index].copyWith(
      isArchived: archived,
      isPaused: archived ? false : _habits[index].isPaused,
    );
  }

  @override
  Future<void> delete(String habitId) async {
    _failIfNeeded();
    _habits.removeAt(_index(habitId));
  }

  @override
  Future<void> reorder(List<String> habitIds) async {
    _failIfNeeded();
    lastOrder = [...habitIds];
    for (var index = 0; index < habitIds.length; index++) {
      final habitIndex = _index(habitIds[index]);
      _habits[habitIndex] = _habits[habitIndex].copyWith(sortPosition: index);
    }
  }

  @override
  Future<HabitCompletionResult> setCompletion({
    required String habitId,
    required bool isComplete,
    required String source,
  }) => throw UnimplementedError();

  @override
  Future<List<HabitCompletion>> loadHistory(
    String habitId, {
    int limit = 60,
  }) async => const [];

  int _index(String habitId) =>
      _habits.indexWhere((habit) => habit.id == habitId);

  void _failIfNeeded() {
    if (failMutations) throw StateError('offline');
  }
}

class _HabitBackedMorningRepository implements MorningRepository {
  _HabitBackedMorningRepository(this.repository);

  final _MemoryHabitRepository repository;

  @override
  Future<MorningSnapshot> load(DateTime date) async {
    final library = await repository.load();
    return MorningSnapshot(
      displayName: 'Builder',
      identityLabel: 'more disciplined',
      dayNumber: 1,
      totalXp: 0,
      currentStreak: 0,
      longestStreak: 0,
      habits: library.active,
      forDate: DateTime(date.year, date.month, date.day),
    );
  }

  @override
  Future<HabitCompletionResult> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  }) => throw UnimplementedError();
}
