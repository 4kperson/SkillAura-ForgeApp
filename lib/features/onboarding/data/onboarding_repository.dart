import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/onboarding_profile.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingProfile> load();
  Future<void> save(OnboardingProfile profile);
}

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'onboarding_goal, discipline_level, wake_time, sleep_time, '
      'onboarding_step, notifications_enabled, onboarding_completed';

  String get _userId {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const AuthException('A signed-in user is required.');
    }
    return userId;
  }

  @override
  Future<OnboardingProfile> load() async {
    final response = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', _userId)
        .maybeSingle();
    return response == null
        ? const OnboardingProfile()
        : OnboardingProfile.fromJson(response);
  }

  @override
  Future<void> save(OnboardingProfile profile) async {
    await _client.from('profiles').update(profile.toJson()).eq('id', _userId);
  }
}
