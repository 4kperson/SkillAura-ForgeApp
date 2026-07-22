import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/habits/domain/habit.dart';

void main() {
  test('parses the full habit engine model and server completion state', () {
    final habit = Habit.fromJson({
      'id': 'habit-1',
      'user_id': 'user-1',
      'title': 'Protect one focus block',
      'category': 'focus',
      'symbol': 'target',
      'reminder_time': '09:30:00',
      'active_weekdays': [1, 3, 5],
      'timezone': 'Europe/London',
      'sort_position': 2,
      'paused': false,
      'archived': false,
      'xp_reward': 20,
      'source': 'onboarding',
      'source_key': 'focus',
      'effort_minutes': 45,
      'local_date': '2026-07-22',
      'is_completed': true,
      'created_at': '2026-07-20T12:00:00Z',
      'updated_at': '2026-07-22T12:00:00Z',
    });

    expect(habit.category, HabitCategory.focus);
    expect(habit.symbol, HabitSymbol.target);
    expect(habit.reminderMinutes, 9 * 60 + 30);
    expect(habit.activeWeekdays, {1, 3, 5});
    expect(habit.timeZone, 'Europe/London');
    expect(habit.sortPosition, 2);
    expect(habit.isComplete, isTrue);
    expect(habit.source, 'onboarding');
  });

  test('active weekdays distinguish scheduled and missed days', () {
    const habit = Habit(
      id: 'habit-1',
      title: 'Read',
      xp: 10,
      activeWeekdays: {1, 3, 5},
    );

    expect(habit.isActiveOn(DateTime(2026, 7, 20)), isTrue); // Monday
    expect(habit.isActiveOn(DateTime(2026, 7, 21)), isFalse); // Tuesday
    expect(habit.isActiveOn(DateTime(2026, 7, 22)), isTrue); // Wednesday
  });

  test('paused and archived habits cannot be completed', () {
    const paused = Habit(id: 'paused', title: 'Paused', xp: 10, isPaused: true);
    const archived = Habit(
      id: 'archived',
      title: 'Archived',
      xp: 10,
      isArchived: true,
    );

    expect(paused.isActiveOn(DateTime(2026, 7, 22)), isFalse);
    expect(archived.isActiveOn(DateTime(2026, 7, 22)), isFalse);
  });

  test('draft serializes reminder, weekdays, and category exactly', () {
    const draft = HabitDraft(
      title: '  Evening reset  ',
      category: HabitCategory.wellbeing,
      symbol: HabitSymbol.leaf,
      reminderMinutes: 21 * 60 + 5,
      activeWeekdays: {7, 2, 4},
      timeZone: 'America/New_York',
    );

    expect(draft.toJson(), {
      'title': 'Evening reset',
      'category': 'wellbeing',
      'symbol': 'leaf',
      'reminder_time': '21:05:00',
      'scheduled_time': '21:05:00',
      'active_weekdays': [2, 4, 7],
      'timezone': 'America/New_York',
    });
  });

  test('draft protects title and active-day requirements', () {
    const noTitle = HabitDraft(
      title: ' ',
      category: HabitCategory.personal,
      symbol: HabitSymbol.spark,
      activeWeekdays: {1},
      timeZone: 'UTC',
    );
    const noDays = HabitDraft(
      title: 'Read',
      category: HabitCategory.learning,
      symbol: HabitSymbol.book,
      activeWeekdays: {},
      timeZone: 'UTC',
    );

    expect(noTitle.validationMessage, isNotNull);
    expect(noDays.validationMessage, isNotNull);
  });

  test('completion history keeps the awarded XP used by undo', () {
    final completion = HabitCompletion.fromJson({
      'id': 'completion-1',
      'habit_id': 'habit-1',
      'user_id': 'user-1',
      'completion_date': '2026-07-22',
      'completed_at': '2026-07-22T13:10:00Z',
      'xp_awarded': 25,
      'source': 'home',
      'created_at': '2026-07-22T13:10:00Z',
    });

    expect(completion.completionDate, DateTime(2026, 7, 22));
    expect(completion.xpAwarded, 25);
    expect(completion.source, 'home');
  });
}
