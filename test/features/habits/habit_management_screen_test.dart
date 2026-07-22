import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/core/theme/app_theme.dart';
import 'package:forge_app/features/habits/data/habit_repository.dart';
import 'package:forge_app/features/habits/domain/habit.dart';
import 'package:forge_app/features/habits/presentation/habit_management_screen.dart';

void main() {
  testWidgets('empty state creates a habit without leaving the screen', (
    tester,
  ) async {
    final repository = _ScreenHabitRepository();
    await _pump(tester, repository);

    expect(find.text('Your plan is ready for a first move.'), findsOneWidget);
    await tester.tap(find.text('Create a habit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('habit-title-field')),
      'Read for 20 minutes',
    );
    await tester.fling(find.byType(ListView).last, const Offset(0, -900), 1500);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-habit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Read for 20 minutes'), findsOneWidget);
    expect(repository.habits, hasLength(1));
  });

  testWidgets('editing changes title, active weekdays, and reminder time', (
    tester,
  ) async {
    final repository = _ScreenHabitRepository()
      ..habits.add(_habit('habit-1', 'Old title'));
    await _pump(tester, repository);

    await tester.tap(find.text('Old title'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('habit-title-field')),
      'Evening reading',
    );
    await tester.fling(find.byType(ListView).last, const Offset(0, -620), 1200);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weekday-1')));
    await tester.fling(find.byType(ListView).last, const Offset(0, -360), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('No reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView).last, const Offset(0, -500), 1000);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-habit-button')));
    await tester.pumpAndSettle();

    expect(repository.lastDraft?.title, 'Evening reading');
    expect(repository.lastDraft?.activeWeekdays, isNot(contains(1)));
    expect(repository.lastDraft?.reminderMinutes, 8 * 60);
    expect(find.text('Evening reading'), findsOneWidget);
  });

  testWidgets('pause, resume, archive, restore, and delete are clear', (
    tester,
  ) async {
    final repository = _ScreenHabitRepository()
      ..habits.add(_habit('habit-1', 'Move outside'));
    await _pump(tester, repository);

    await _chooseAction(tester, 'Pause');
    await tester.tap(find.text('Paused  1'));
    await tester.pumpAndSettle();
    expect(find.text('Move outside'), findsOneWidget);

    await _chooseAction(tester, 'Resume');
    await tester.tap(find.text('Active  1'));
    await tester.pumpAndSettle();
    await _chooseAction(tester, 'Archive');
    await tester.tap(find.text('Archive  1'));
    await tester.pumpAndSettle();
    expect(find.text('Move outside'), findsOneWidget);

    await _chooseAction(tester, 'Restore');
    await tester.tap(find.text('Active  1'));
    await tester.pumpAndSettle();
    await _chooseAction(tester, 'Delete permanently');
    await tester.pumpAndSettle();
    expect(find.text('Delete this habit?'), findsOneWidget);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(repository.habits, isEmpty);
    expect(find.text('Your plan is ready for a first move.'), findsOneWidget);
  });

  testWidgets('history presents confirmed server records', (tester) async {
    final repository = _ScreenHabitRepository()
      ..habits.add(_habit('habit-1', 'Deep work'))
      ..history.add(
        HabitCompletion(
          habitId: 'habit-1',
          userId: 'user-1',
          completionDate: DateTime(2026, 7, 22),
          completedAt: DateTime(2026, 7, 22, 9, 30),
          xpAwarded: 20,
          source: 'home',
          createdAt: DateTime(2026, 7, 22, 9, 30),
        ),
      );
    await _pump(tester, repository);

    await _chooseAction(tester, 'View history');
    await tester.pumpAndSettle();

    expect(find.text('COMPLETION HISTORY'), findsOneWidget);
    expect(find.text('Jul 22, 2026'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
  });

  testWidgets('onboarding starter promise is editable in the same engine', (
    tester,
  ) async {
    final repository = _ScreenHabitRepository()
      ..habits.add(
        _habit('starter-1', 'Starter promise', source: 'onboarding'),
      );
    await _pump(tester, repository);

    expect(find.text('STARTER'), findsOneWidget);
    await tester.tap(find.text('Starter promise'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('habit-title-field')),
      'My own promise',
    );
    await tester.fling(find.byType(ListView).last, const Offset(0, -900), 1500);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-habit-button')));
    await tester.pumpAndSettle();

    expect(repository.habits.single.title, 'My own promise');
    expect(repository.habits.single.source, 'onboarding');
    expect(find.text('My own promise'), findsOneWidget);
  });

  testWidgets('loading, load error, and retry are intentional', (tester) async {
    final load = Completer<HabitLibrary>();
    final repository = _ScreenHabitRepository(loadCompleter: load);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HabitManagementScreen(repository: repository),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    load.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan could not be reached.'), findsOneWidget);

    repository.loadCompleter = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan is ready for a first move.'), findsOneWidget);
  });

  testWidgets('management and editor are safe on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ScreenHabitRepository()
      ..habits.add(_habit('habit-1', 'Protect one focused block'));
    await _pump(tester, repository);

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Create a promise'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _ScreenHabitRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: HabitManagementScreen(repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseAction(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Habit actions').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Habit _habit(String id, String title, {String source = 'user'}) => Habit(
  id: id,
  userId: 'user-1',
  title: title,
  category: HabitCategory.health,
  symbol: HabitSymbol.heart,
  activeWeekdays: const {1, 2, 3, 4, 5, 6, 7},
  timeZone: 'UTC',
  xp: 20,
  source: source,
);

class _ScreenHabitRepository implements HabitRepository {
  _ScreenHabitRepository({this.loadCompleter});

  final List<Habit> habits = [];
  final List<HabitCompletion> history = [];
  Completer<HabitLibrary>? loadCompleter;
  HabitDraft? lastDraft;
  var _counter = 0;

  @override
  Future<HabitLibrary> load() async {
    if (loadCompleter case final completer?) return completer.future;
    return HabitLibrary(habits: [...habits], timeZone: 'UTC');
  }

  @override
  Future<Habit> create(HabitDraft draft) async {
    lastDraft = draft;
    final habit = Habit(
      id: 'created-${_counter++}',
      userId: 'user-1',
      title: draft.title,
      category: draft.category,
      symbol: draft.symbol,
      reminderMinutes: draft.reminderMinutes,
      activeWeekdays: draft.activeWeekdays,
      timeZone: draft.timeZone,
      position: habits.length,
      xp: 10,
    );
    habits.add(habit);
    return habit;
  }

  @override
  Future<Habit> update(String habitId, HabitDraft draft) async {
    lastDraft = draft;
    final index = _index(habitId);
    final changed = habits[index].copyWith(
      title: draft.title,
      category: draft.category,
      symbol: draft.symbol,
      reminderMinutes: draft.reminderMinutes,
      clearReminder: draft.reminderMinutes == null,
      activeWeekdays: draft.activeWeekdays,
      timeZone: draft.timeZone,
    );
    habits[index] = changed;
    return changed;
  }

  @override
  Future<Habit> setPaused(String habitId, {required bool paused}) async {
    final index = _index(habitId);
    return habits[index] = habits[index].copyWith(isPaused: paused);
  }

  @override
  Future<Habit> setArchived(String habitId, {required bool archived}) async {
    final index = _index(habitId);
    return habits[index] = habits[index].copyWith(
      isArchived: archived,
      isPaused: false,
    );
  }

  @override
  Future<void> delete(String habitId) async => habits.removeAt(_index(habitId));

  @override
  Future<void> reorder(List<String> habitIds) async {
    for (var position = 0; position < habitIds.length; position++) {
      final index = _index(habitIds[position]);
      habits[index] = habits[index].copyWith(position: position);
    }
    habits.sort((a, b) => a.position.compareTo(b.position));
  }

  @override
  Future<List<HabitCompletion>> loadHistory(
    String habitId, {
    int limit = 60,
  }) async => history;

  @override
  Future<HabitCompletionResult> setCompletion({
    required String habitId,
    required bool isComplete,
    required String source,
  }) => throw UnimplementedError();

  int _index(String habitId) =>
      habits.indexWhere((habit) => habit.id == habitId);
}
