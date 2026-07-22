import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('signup uses the exact mobile confirmation redirect', () async {
    final transport = _FakeAuthTransport();
    final repository = AuthRepository.withTransport(transport);

    await repository.signUp(email: 'builder@example.com', password: 'password');

    expect(transport.lastRedirect, 'com.skillaura.forge://login-callback/');
  });

  test('resend preserves the exact mobile confirmation redirect', () async {
    final transport = _FakeAuthTransport();
    final repository = AuthRepository.withTransport(transport);

    await repository.resendConfirmation(email: 'builder@example.com');

    expect(transport.resendEmail, 'builder@example.com');
    expect(transport.lastRedirect, 'com.skillaura.forge://login-callback/');
  });
}

class _FakeAuthTransport implements AuthTransport {
  String? lastRedirect;
  String? resendEmail;

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async => AuthResponse();

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String emailRedirectTo,
  }) async {
    lastRedirect = emailRedirectTo;
    return AuthResponse();
  }

  @override
  Future<void> resendSignupConfirmation({
    required String email,
    required String emailRedirectTo,
  }) async {
    resendEmail = email;
    lastRedirect = emailRedirectTo;
  }
}
