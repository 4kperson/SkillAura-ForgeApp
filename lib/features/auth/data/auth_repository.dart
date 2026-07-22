import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthService {
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  });

  Future<void> resendConfirmation({required String email});
}

abstract interface class AuthTransport {
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String emailRedirectTo,
  });

  Future<void> resendSignupConfirmation({
    required String email,
    required String emailRedirectTo,
  });
}

class AuthRepository implements AuthService {
  static const emailConfirmationRedirectUri =
      'com.skillaura.forge://login-callback/';

  AuthRepository(SupabaseClient client)
    : _transport = SupabaseAuthTransport(client);

  AuthRepository.withTransport(this._transport);

  final AuthTransport _transport;

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _transport.signInWithPassword(email: email, password: password);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _transport.signUp(
      email: email,
      password: password,
      emailRedirectTo: emailConfirmationRedirectUri,
    );
  }

  @override
  Future<void> resendConfirmation({required String email}) =>
      _transport.resendSignupConfirmation(
        email: email,
        emailRedirectTo: emailConfirmationRedirectUri,
      );
}

class SupabaseAuthTransport implements AuthTransport {
  SupabaseAuthTransport(this._client);

  final SupabaseClient _client;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) => _client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String emailRedirectTo,
  }) => _client.auth.signUp(
    email: email,
    password: password,
    emailRedirectTo: emailRedirectTo,
  );

  @override
  Future<void> resendSignupConfirmation({
    required String email,
    required String emailRedirectTo,
  }) async {
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: emailRedirectTo,
    );
  }
}
