import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/core/theme/app_theme.dart';
import 'package:forge_app/features/habits/domain/habit.dart';
import 'package:forge_app/features/home/data/morning_repository.dart';
import 'package:forge_app/features/home/domain/morning_snapshot.dart';
import 'package:forge_app/features/home/presentation/home_screen.dart';
import 'package:forge_app/features/onboarding/data/notification_permission_service.dart';
import 'package:forge_app/features/onboarding/domain/onboarding_profile.dart';

void main() {
  testWidgets(
    'answers identity, next action, and progression without a percent',
    (tester) async {
      final repository = _InteractiveMorningRepository(_snapshot());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: HomeScreen(repository: repository, onSignOut: () async {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('more disciplined'), findsOneWidget);
      expect(find.text('Deep work'), findsOneWidget);
      expect(find.text('LEVEL'), findsOneWidget);
      expect(find.textContaining('XP until Level'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    },
  );

  testWidgets('promise control reflects incomplete, loading, then confirmed', (
    tester,
  ) async {
    final repository = _InteractiveMorningRepository(
      _snapshot(),
      saveDelay: const Duration(milliseconds: 40),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(repository: repository, onSignOut: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('promise-incomplete')), findsOneWidget);
    expect(find.byKey(const ValueKey('promise-completed')), findsNothing);

    await tester.tap(find.text('Deep work'));
    await tester.pump();

    expect(find.byKey(const ValueKey('promise-loading')), findsOneWidget);
    expect(repository.value.totalXp, 200);

    await tester.pump(const Duration(milliseconds: 45));
    await tester.pump();

    expect(find.byKey(const ValueKey('promise-completed')), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(repository.value.totalXp, 240);
    expect(repository.value.completedCount, 1);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Deep work'), findsNothing);
    expect(find.text('Every promise kept.'), findsOneWidget);
    expect(find.text('240 TOTAL XP'), findsOneWidget);
  });

  testWidgets('premium morning layout is overflow-safe on a compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          repository: _InteractiveMorningRepository(_snapshot()),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make today count.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled reminder card is clearly actionable', (tester) async {
    final snapshot = _snapshot().copyWith(notificationsEnabled: false);
    final repository = _InteractiveMorningRepository(snapshot);
    var enableCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          repository: repository,
          onSignOut: () async {},
          onEnableReminders: () async {
            enableCalls++;
            repository.value = repository.value.copyWith(
              notificationsEnabled: true,
            );
            return const NotificationRecoveryResult(
              state: NotificationRecoveryState.granted,
              preference: NotificationPreference.granted,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reminders are off'), findsOneWidget);
    expect(find.text('Tap to enable your daily cues'), findsOneWidget);

    await tester.tap(find.text('Reminders are off'));
    await tester.pumpAndSettle();

    expect(enableCalls, 1);
    expect(find.text('Reminders are off'), findsNothing);
  });

  testWidgets('returning from settings refreshes the reminder card', (
    tester,
  ) async {
    final repository = _InteractiveMorningRepository(
      _snapshot().copyWith(notificationsEnabled: false),
    );
    var refreshCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          repository: repository,
          onSignOut: () async {},
          onEnableReminders: () async => const NotificationRecoveryResult(
            state: NotificationRecoveryState.settingsOpened,
            preference: NotificationPreference.denied,
          ),
          onRefreshReminderPermission: () async {
            refreshCalls++;
            repository.value = repository.value.copyWith(
              notificationsEnabled: true,
            );
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders are off'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(refreshCalls, 1);
    expect(find.text('Reminders are off'), findsNothing);
  });

  testWidgets('an empty plan is not presented as a completed day', (
    tester,
  ) async {
    final snapshot = _snapshot().copyWith(habits: const []);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          repository: _InteractiveMorningRepository(snapshot),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your plan is catching up.'), findsOneWidget);
    expect(find.text('Every promise kept.'), findsNothing);
  });

  testWidgets('successful completion offers a server-backed undo', (
    tester,
  ) async {
    final repository = _InteractiveMorningRepository(_snapshot());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(repository: repository, onSignOut: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deep work'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Deep work completed. +40 XP'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();

    expect(repository.value.totalXp, 200);
    expect(repository.value.habits.single.isComplete, isFalse);
    expect(find.text('Deep work'), findsOneWidget);
  });

  testWidgets('returning from habit management refreshes Home immediately', (
    tester,
  ) async {
    final repository = _InteractiveMorningRepository(_snapshot());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: HomeScreen(
          repository: repository,
          onSignOut: () async {},
          onManageHabits: () async {
            final changed = repository.value.habits.single.copyWith(
              title: 'Updated focus block',
            );
            repository.value = repository.value.copyWith(habits: [changed]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    expect(find.text('Updated focus block'), findsOneWidget);
    expect(find.text('Deep work'), findsNothing);
  });
}

MorningSnapshot _snapshot() => MorningSnapshot(
  displayName: 'Brian',
  identityLabel: 'more disciplined',
  dayNumber: 12,
  totalXp: 200,
  currentStreak: 6,
  longestStreak: 9,
  habits: const [
    Habit(
      id: 'focus',
      title: 'Deep work',
      xp: 40,
      kind: 'focus',
      effortMinutes: 35,
      scheduledTime: '08:00:00',
    ),
  ],
  forDate: DateTime(2026, 7, 21),
  notificationsEnabled: true,
);

class _InteractiveMorningRepository implements MorningRepository {
  _InteractiveMorningRepository(this.value, {this.saveDelay});

  MorningSnapshot value;
  final Duration? saveDelay;

  @override
  Future<MorningSnapshot> load(DateTime date) async => value;

  @override
  Future<void> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  }) async {
    if (saveDelay case final delay?) await Future<void>.delayed(delay);
    final index = value.habits.indexWhere((habit) => habit.id == habitId);
    final habit = value.habits[index];
    final habits = [...value.habits]
      ..[index] = habit.copyWith(isComplete: isComplete);
    value = value.copyWith(
      habits: habits,
      totalXp: value.totalXp + (isComplete ? habit.xp : -habit.xp),
      currentStreak: isComplete ? 7 : 6,
      longestStreak: isComplete ? 9 : 9,
    );
  }
}
