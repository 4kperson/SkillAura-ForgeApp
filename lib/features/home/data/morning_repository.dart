import 'package:supabase_flutter/supabase_flutter.dart';

import '../../habits/domain/habit.dart';
import '../domain/morning_snapshot.dart';

abstract interface class MorningRepository {
  Future<MorningSnapshot> load(DateTime date);

  Future<void> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  });
}

class SupabaseMorningRepository implements MorningRepository {
  SupabaseMorningRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('A signed-in user is required.');
    }
    return userId;
  }

  @override
  Future<MorningSnapshot> load(DateTime date) async {
    final userId = _userId;
    final dateKey = _dateKey(date);
    final results = await Future.wait<dynamic>([
      _client
          .from('profiles')
          .select(
            'display_name, total_xp, current_streak, longest_streak, created_at',
          )
          .eq('id', userId)
          .single(),
      _client
          .from('habits')
          .select('id, title, xp_reward, created_at')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at'),
      _client
          .from('habit_completions')
          .select('habit_id')
          .eq('user_id', userId)
          .eq('completed_on', dateKey),
    ]);

    final profile = results[0] as Map<String, dynamic>;
    final habitRows = (results[1] as List).cast<Map<String, dynamic>>();
    final completedIds = (results[2] as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['habit_id'] as String)
        .toSet();
    final createdAt = DateTime.parse(profile['created_at'] as String).toLocal();
    final today = DateTime(date.year, date.month, date.day);
    final started = DateTime(createdAt.year, createdAt.month, createdAt.day);

    return MorningSnapshot(
      displayName: _firstName(profile['display_name'] as String?),
      dayNumber: today.difference(started).inDays.clamp(0, 100000) + 1,
      totalXp: (profile['total_xp'] as num).toInt(),
      currentStreak: (profile['current_streak'] as num).toInt(),
      longestStreak: (profile['longest_streak'] as num).toInt(),
      habits: [
        for (final row in habitRows)
          Habit.fromJson(row, isComplete: completedIds.contains(row['id'])),
      ],
      forDate: today,
    );
  }

  @override
  Future<void> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  }) async {
    await _client.rpc(
      'set_habit_completion',
      params: {
        'p_habit_id': habitId,
        'p_completed_on': _dateKey(date),
        'p_is_complete': isComplete,
      },
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _firstName(String? displayName) {
    final trimmed = displayName?.trim() ?? '';
    if (trimmed.isEmpty) return 'Builder';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}
