import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class AuthErrorMapper {
  static const String missingConfigurationMessage =
      'Authentication is not configured yet. Please try again shortly.';

  static String messageFor(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return 'Check your connection and try again.';
    }

    if (error is AuthRetryableFetchException) {
      return 'We could not reach the server. Check your connection and try again.';
    }

    if ((error is StateError || error is AssertionError) &&
        error.toString().toLowerCase().contains('supabase')) {
      return missingConfigurationMessage;
    }

    if (error is AuthException) {
      final code = error.code?.toLowerCase() ?? '';
      final message = error.message.toLowerCase();
      final statusCode = error.statusCode;

      if (statusCode == '429' ||
          code.contains('rate') ||
          message.contains('too many requests')) {
        return 'Too many attempts. Please wait a moment and try again.';
      }
      if (code.contains('email_address_invalid') ||
          code.contains('invalid_email') ||
          message.contains('invalid email')) {
        return 'Enter a valid email address.';
      }
      if (code.contains('weak_password') || message.contains('weak password')) {
        return 'Choose a stronger password with at least 8 characters.';
      }
      if (code.contains('user_already_exists') ||
          code.contains('email_exists') ||
          message.contains('already registered') ||
          message.contains('already exists')) {
        return 'An account with this email already exists. Sign in instead.';
      }
      if (code.contains('email_not_confirmed') ||
          message.contains('email not confirmed')) {
        return 'Confirm your email before signing in.';
      }
    }

    return 'We could not complete authentication. Please try again.';
  }

  static void logSafely(Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;

    final details = error is AuthException
        ? 'type=${error.runtimeType}, status=${error.statusCode}, code=${error.code}'
        : 'type=${error.runtimeType}';
    debugPrint('Authentication failure [$details]');
    debugPrintStack(stackTrace: stackTrace, label: 'Authentication failure');
  }
}
