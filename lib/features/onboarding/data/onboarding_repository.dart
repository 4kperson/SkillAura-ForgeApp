import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/onboarding_profile.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingProfile> load();
  Future<void> save(OnboardingProfile profile);
  Future<void> complete(OnboardingProfile profile);
}

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'onboarding_goal, onboarding_goals, discipline_level, wake_time, sleep_time, '
      'onboarding_step, notifications_enabled, notification_permission_state, '
      'onboarding_completed, timezone';

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('A signed-in user is required.');
    }
    return userId;
  }

  @override
  Future<OnboardingProfile> load() async {
    await _ensureProfile();
    final response = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', _userId)
        .maybeSingle();
    final profile = response == null
        ? const OnboardingProfile()
        : OnboardingProfile.fromJson(response);
    if (profile.isCompleted) await _persistCompletion(profile);
    return profile;
  }

  @override
  Future<void> save(OnboardingProfile profile) async {
    await _ensureProfile();
    final updated = await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', _userId)
        .select('id');
    if (updated.isEmpty) {
      throw const PostgrestException(message: 'Profile update was not saved.');
    }
  }

  @override
  Future<void> complete(OnboardingProfile profile) =>
      _persistCompletion(profile);

  Future<void> _ensureProfile() => _client.rpc('ensure_user_profile');

  Future<void> _persistCompletion(OnboardingProfile profile) async {
    final goals = profile.goals.isEmpty
        ? const [OnboardingGoal.disciplined]
        : profile.goals;
    await _client.rpc(
      'complete_onboarding',
      params: {
        'p_goals': goals.map((goal) => goal.name).toList(),
        'p_level': (profile.disciplineLevel ?? DisciplineLevel.starting).name,
        'p_wake_time': _minutesToTime(profile.wakeTimeMinutes),
        'p_sleep_time': _minutesToTime(profile.sleepTimeMinutes),
        'p_notification_state': profile.notificationPreference.name,
        'p_plan': [
          for (final habit in profile.recommendedHabits) habit.toJson(),
        ],
      },
    );
  }

  static String _minutesToTime(int minutes) {
    final normalized = minutes.clamp(0, 1439);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }
}
