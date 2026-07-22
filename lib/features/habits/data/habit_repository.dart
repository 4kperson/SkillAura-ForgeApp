import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/habit.dart';

class HabitLibrary {
  const HabitLibrary({required this.habits, required this.timeZone});

  final List<Habit> habits;
  final String timeZone;

  List<Habit> get active => habits
      .where((habit) => !habit.isPaused && !habit.isArchived)
      .toList(growable: false);
  List<Habit> get paused => habits
      .where((habit) => habit.isPaused && !habit.isArchived)
      .toList(growable: false);
  List<Habit> get archived =>
      habits.where((habit) => habit.isArchived).toList(growable: false);
}

abstract interface class HabitRepository {
  Future<HabitLibrary> load();
  Future<Habit> create(HabitDraft draft);
  Future<Habit> update(String habitId, HabitDraft draft);
  Future<Habit> setPaused(String habitId, {required bool paused});
  Future<Habit> setArchived(String habitId, {required bool archived});
  Future<void> delete(String habitId);
  Future<void> reorder(List<String> habitIds);
  Future<HabitCompletionResult> setCompletion({
    required String habitId,
    required bool isComplete,
    required String source,
  });
  Future<List<HabitCompletion>> loadHistory(String habitId, {int limit = 60});
}

class SupabaseHabitRepository implements HabitRepository {
  SupabaseHabitRepository(this._client);

  final SupabaseClient _client;

  static const _habitColumns =
      'id, user_id, title, category, symbol, reminder_time, scheduled_time, '
      'active_weekdays, timezone, sort_position, paused, archived, xp_reward, '
      'is_active, source, source_key, effort_minutes, created_at, updated_at';

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('A signed-in user is required.');
    }
    return userId;
  }

  @override
  Future<HabitLibrary> load() async {
    final userId = _userId;
    final responses = await Future.wait<dynamic>([
      _client
          .from('habits')
          .select(_habitColumns)
          .eq('user_id', userId)
          .order('sort_position'),
      _client.from('profiles').select('timezone').eq('id', userId).single(),
    ]);
    final rows = (responses[0] as List).cast<Map<String, dynamic>>();
    final profile = responses[1] as Map<String, dynamic>;
    return HabitLibrary(
      habits: rows.map(Habit.fromJson).toList(growable: false),
      timeZone: profile['timezone'] as String? ?? 'America/New_York',
    );
  }

  @override
  Future<Habit> create(HabitDraft draft) async {
    _validate(draft);
    final userId = _userId;
    final orderRows = await _client
        .from('habits')
        .select('sort_position')
        .eq('user_id', userId)
        .order('sort_position', ascending: false)
        .limit(1);
    final nextPosition = orderRows.isEmpty
        ? 0
        : ((orderRows.first['sort_position'] as num?)?.toInt() ?? 0) + 1;
    final row = await _client
        .from('habits')
        .insert({
          ...draft.toJson(),
          'user_id': userId,
          'sort_position': nextPosition,
          'paused': false,
          'archived': false,
          'is_active': true,
          'source': 'user',
        })
        .select(_habitColumns)
        .single();
    return Habit.fromJson(row);
  }

  @override
  Future<Habit> update(String habitId, HabitDraft draft) async {
    _validate(draft);
    final row = await _client
        .from('habits')
        .update(draft.toJson())
        .eq('id', habitId)
        .eq('user_id', _userId)
        .select(_habitColumns)
        .maybeSingle();
    return _savedHabit(row);
  }

  @override
  Future<Habit> setPaused(String habitId, {required bool paused}) =>
      _updateState(habitId, {'paused': paused});

  @override
  Future<Habit> setArchived(String habitId, {required bool archived}) =>
      _updateState(habitId, {
        'archived': archived,
        'is_active': !archived,
        if (archived) 'paused': false,
      });

  Future<Habit> _updateState(
    String habitId,
    Map<String, dynamic> values,
  ) async {
    final row = await _client
        .from('habits')
        .update(values)
        .eq('id', habitId)
        .eq('user_id', _userId)
        .select(_habitColumns)
        .maybeSingle();
    return _savedHabit(row);
  }

  @override
  Future<void> delete(String habitId) =>
      _client.rpc('delete_habit', params: {'p_habit_id': habitId});

  @override
  Future<void> reorder(List<String> habitIds) async {
    try {
      await _client.rpc('reorder_habits', params: {'p_habit_ids': habitIds});
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[habits] reorder RPC failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  @override
  Future<HabitCompletionResult> setCompletion({
    required String habitId,
    required bool isComplete,
    required String source,
  }) async {
    final response = await _client.rpc(
      'set_habit_completion_v2',
      params: {
        'p_habit_id': habitId,
        'p_is_complete': isComplete,
        'p_source': source,
      },
    );
    final rows = (response as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) {
      throw const PostgrestException(message: 'Completion was not confirmed.');
    }
    return HabitCompletionResult.fromJson(rows.single);
  }

  @override
  Future<List<HabitCompletion>> loadHistory(
    String habitId, {
    int limit = 60,
  }) async {
    final rows = await _client
        .from('habit_completions')
        .select(
          'id, habit_id, user_id, completion_date, completed_at, '
          'xp_awarded, source, created_at',
        )
        .eq('habit_id', habitId)
        .eq('user_id', _userId)
        .order('completion_date', ascending: false)
        .limit(limit.clamp(1, 365));
    return rows
        .map((row) => HabitCompletion.fromJson(row))
        .toList(growable: false);
  }

  static Habit _savedHabit(Map<String, dynamic>? row) {
    if (row == null) {
      throw const PostgrestException(message: 'Habit was not saved.');
    }
    return Habit.fromJson(row);
  }

  static void _validate(HabitDraft draft) {
    final message = draft.validationMessage;
    if (message != null) throw HabitValidationException(message);
  }
}

class HabitValidationException implements Exception {
  const HabitValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmptyHabitRepository implements HabitRepository {
  const EmptyHabitRepository();

  @override
  Future<HabitLibrary> load() async =>
      const HabitLibrary(habits: [], timeZone: 'America/New_York');

  @override
  Future<Habit> create(HabitDraft draft) => _unavailable();

  @override
  Future<Habit> update(String habitId, HabitDraft draft) => _unavailable();

  @override
  Future<Habit> setPaused(String habitId, {required bool paused}) =>
      _unavailable();

  @override
  Future<Habit> setArchived(String habitId, {required bool archived}) =>
      _unavailable();

  @override
  Future<void> delete(String habitId) => _unavailable();

  @override
  Future<void> reorder(List<String> habitIds) => _unavailable();

  @override
  Future<HabitCompletionResult> setCompletion({
    required String habitId,
    required bool isComplete,
    required String source,
  }) => _unavailable();

  @override
  Future<List<HabitCompletion>> loadHistory(
    String habitId, {
    int limit = 60,
  }) async => const [];

  static Future<T> _unavailable<T>() async =>
      throw StateError('Habit persistence is not configured.');
}
