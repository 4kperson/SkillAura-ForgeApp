import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/auth/data/auth_error_mapper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthErrorMapper', () {
    test('maps the uninitialized Supabase client failure', () {
      expect(() => Supabase.instance.client, throwsA(isA<AssertionError>()));
      expect(
        AuthErrorMapper.messageFor(
          AssertionError('Supabase has not been initialized'),
        ),
        AuthErrorMapper.missingConfigurationMessage,
      );
    });

    test('maps missing Supabase initialization', () {
      expect(
        AuthErrorMapper.messageFor(
          AssertionError('Supabase has not been initialized'),
        ),
        AuthErrorMapper.missingConfigurationMessage,
      );
    });

    test('maps invalid email and weak password errors', () {
      expect(
        AuthErrorMapper.messageFor(
          const AuthException('invalid', code: 'email_address_invalid'),
        ),
        'Enter a valid email address.',
      );
      expect(
        AuthErrorMapper.messageFor(
          const AuthException('weak', code: 'weak_password'),
        ),
        'Choose a stronger password with at least 8 characters.',
      );
    });

    test('maps existing account and confirmation errors', () {
      expect(
        AuthErrorMapper.messageFor(
          const AuthException('exists', code: 'user_already_exists'),
        ),
        'An account with this email already exists. Sign in instead.',
      );
      expect(
        AuthErrorMapper.messageFor(
          const AuthException('confirm', code: 'email_not_confirmed'),
        ),
        'Confirm your email before signing in.',
      );
    });

    test('maps network and rate limit failures', () {
      expect(
        AuthErrorMapper.messageFor(const SocketException('offline')),
        'Check your connection and try again.',
      );
      expect(
        AuthErrorMapper.messageFor(TimeoutException('timed out')),
        'Check your connection and try again.',
      );
      expect(
        AuthErrorMapper.messageFor(
          const AuthException('slow down', statusCode: '429'),
        ),
        'Too many attempts. Please wait a moment and try again.',
      );
    });

    test('maps unknown Supabase failures to a safe message', () {
      expect(
        AuthErrorMapper.messageFor(const AuthException('server issue')),
        'We could not complete authentication. Please try again.',
      );
    });
  });
}
