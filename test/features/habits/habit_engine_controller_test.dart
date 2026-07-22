import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/habits/data/habit_repository.dart';
import 'package:forge_app/features/habits/domain/habit.dart';
import 'package:forge_app/features/habits/presentation/habit_engine_controller.dart';

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
      ..seed(_habit('one', 'One', position: 0))
      ..seed(_habit('two', 'Two', position: 1))
      ..seed(_habit('three', 'Three', position: 2));
    final controller = HabitEngineController(repository);
    await controller.initialize();

    final result = await controller.reorderActive(0, 3);

    expect(result, isTrue);
    expect(repository.lastOrder, ['two', 'three', 'one']);
    expect(controller.library!.active.map((habit) => habit.id), [
      'two',
      'three',
      'one',
    ]);
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
      ..seed(_habit('one', 'One', position: 0))
      ..seed(_habit('two', 'Two', position: 1));
    final controller = HabitEngineController(repository);
    await controller.initialize();
    repository.failMutations = true;

    final saved = await controller.reorderActive(0, 2);

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

Habit _habit(String id, String title, {int position = 0}) => Habit(
  id: id,
  userId: 'user-1',
  title: title,
  xp: 10,
  position: position,
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
      ..sort((a, b) => a.position.compareTo(b.position));
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
      position: _habits.length,
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
      _habits[habitIndex] = _habits[habitIndex].copyWith(position: index);
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
