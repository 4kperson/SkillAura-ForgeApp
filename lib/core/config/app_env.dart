abstract final class AppEnv {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String revenueCatAppleKey =
      String.fromEnvironment('REVENUECAT_APPLE_KEY');
  static const String revenueCatGoogleKey =
      String.fromEnvironment('REVENUECAT_GOOGLE_KEY');

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
