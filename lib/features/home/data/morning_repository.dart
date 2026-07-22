import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../habits/domain/habit.dart';
import '../domain/morning_snapshot.dart';

abstract interface class MorningRepository {
  Future<MorningSnapshot> load(DateTime date);

  Future<HabitCompletionResult> setHabitCompletion({
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
    await _client.rpc('ensure_user_profile');
    final results = await Future.wait<dynamic>([
      _client
          .from('profiles')
          .select(
            'display_name, onboarding_goals, discipline_level, total_xp, '
            'current_streak, longest_streak, notifications_enabled, created_at',
          )
          .eq('id', userId)
          .single(),
      _client.rpc('get_today_habits'),
    ]);

    final profile = results[0] as Map<String, dynamic>;
    final habitRows = (results[1] as List).cast<Map<String, dynamic>>();
    final createdAt = DateTime.parse(profile['created_at'] as String).toLocal();
    final effective = habitRows.isEmpty
        ? date
        : DateTime.parse(habitRows.first['local_date'] as String);
    final today = DateTime(effective.year, effective.month, effective.day);
    final started = DateTime(createdAt.year, createdAt.month, createdAt.day);

    return MorningSnapshot(
      displayName: _firstName(profile['display_name'] as String?),
      identityLabel: _identityLabel(profile),
      dayNumber: today.difference(started).inDays.clamp(0, 100000) + 1,
      totalXp: (profile['total_xp'] as num).toInt(),
      currentStreak: (profile['current_streak'] as num).toInt(),
      longestStreak: (profile['longest_streak'] as num).toInt(),
      habits: [for (final row in habitRows) Habit.fromJson(row)],
      forDate: today,
      notificationsEnabled: profile['notifications_enabled'] == true,
    );
  }

  @override
  Future<HabitCompletionResult> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  }) async {
    try {
      final response = await _client.rpc(
        'set_habit_completion_v2',
        params: {
          'p_habit_id': habitId,
          'p_is_complete': isComplete,
          'p_source': 'home',
        },
      );
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.length != 1) {
        throw const PostgrestException(
          message: 'The completion RPC returned an unexpected result.',
          code: 'FORGE_RPC_CONTRACT',
        );
      }
      final result = HabitCompletionResult.fromJson(rows.single);
      if (kDebugMode) {
        debugPrint(
          '[habits] completion RPC confirmed '
          'habit=$habitId complete=$isComplete changed=${result.changed} '
          'date=${result.completionDate.toIso8601String()} '
          'totalXp=${result.totalXp}',
        );
      }
      return result;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[habits] completion RPC failed '
          'habit=$habitId complete=$isComplete: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  static String _firstName(String? displayName) {
    final trimmed = displayName?.trim() ?? '';
    if (trimmed.isEmpty) return 'Builder';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  static String _identityLabel(Map<String, dynamic> profile) {
    final goals =
        (profile['onboarding_goals'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    const labels = {
      'disciplined': 'more disciplined',
      'healthier': 'healthier',
      'productive': 'more productive',
      'student': 'a stronger student',
      'betterSleep': 'well-rested',
      'reduceScreenTime': 'more intentional',
    };
    final selected = goals
        .map((goal) => labels[goal])
        .whereType<String>()
        .take(2)
        .toList();
    if (selected.isEmpty) return 'someone who keeps promises';
    if (selected.length == 1) return selected.first;
    return '${selected.first} and ${selected.last}';
  }
}

class EmptyMorningRepository implements MorningRepository {
  const EmptyMorningRepository();

  @override
  Future<MorningSnapshot> load(DateTime date) async => MorningSnapshot(
    displayName: 'Builder',
    identityLabel: 'someone who keeps promises',
    dayNumber: 1,
    totalXp: 0,
    currentStreak: 0,
    longestStreak: 0,
    habits: const [],
    forDate: DateTime(date.year, date.month, date.day),
    notificationsEnabled: false,
  );

  @override
  Future<HabitCompletionResult> setHabitCompletion({
    required String habitId,
    required DateTime date,
    required bool isComplete,
  }) async => HabitCompletionResult(
    completionDate: DateTime(date.year, date.month, date.day),
    changed: true,
    totalXp: 0,
  );
}
