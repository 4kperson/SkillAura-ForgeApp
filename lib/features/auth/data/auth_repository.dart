import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  static const emailConfirmationRedirectUri =
      'com.skillaura.forge://login-callback/';

  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailConfirmationRedirectUri,
    );
  }
}
