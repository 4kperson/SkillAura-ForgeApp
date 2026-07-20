import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/core/config/app_env.dart';

void main() {
  const expectSupabaseConfig = bool.fromEnvironment('EXPECT_SUPABASE_CONFIG');

  test('recognizes Supabase Dart defines when supplied', () {
    if (!expectSupabaseConfig) return;

    expect(AppEnv.supabaseUrl, startsWith('https://'));
    expect(AppEnv.supabaseAnonKey, isNotEmpty);
    expect(AppEnv.hasSupabaseConfig, isTrue);
  });
}
