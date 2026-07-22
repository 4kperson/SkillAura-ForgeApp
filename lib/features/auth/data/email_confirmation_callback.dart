enum EmailConfirmationCallbackStatus {
  valid,
  invalid,
  expired,
  alreadyUsed,
  pkceMismatch,
  missingParameters,
}

/// Classifies callback links before they are presented to the user.
abstract final class EmailConfirmationCallback {
  static const scheme = 'com.skillaura.forge';
  static const host = 'login-callback';

  static bool usesForgeScheme(Uri uri) => uri.scheme.toLowerCase() == scheme;

  static bool matchesForgeCallback(Uri uri) =>
      usesForgeScheme(uri) && uri.host.toLowerCase() == host;

  static EmailConfirmationCallbackStatus classify(Uri uri) {
    final values = <String, String>{
      ...uri.queryParameters,
      ..._fragmentParameters(uri),
    };
    final error =
        '${values['error'] ?? ''} ${values['error_code'] ?? ''} '
                '${values['error_description'] ?? ''}'
            .toLowerCase();

    if (error.trim().isNotEmpty) {
      if (_containsAny(error, ['expired', 'otp_expired', 'invalid_token'])) {
        return EmailConfirmationCallbackStatus.expired;
      }
      if (_containsAny(error, ['already', 'used', 'consumed'])) {
        return EmailConfirmationCallbackStatus.alreadyUsed;
      }
      if (_containsAny(error, [
        'pkce',
        'code verifier',
        'code_verifier',
        'code challenge',
      ])) {
        return EmailConfirmationCallbackStatus.pkceMismatch;
      }
      return EmailConfirmationCallbackStatus.invalid;
    }

    if (values['code']?.isNotEmpty == true ||
        (values['access_token']?.isNotEmpty == true &&
            values['refresh_token']?.isNotEmpty == true)) {
      return EmailConfirmationCallbackStatus.valid;
    }
    return EmailConfirmationCallbackStatus.missingParameters;
  }

  static Map<String, String> _fragmentParameters(Uri uri) {
    if (uri.fragment.isEmpty) return const {};
    try {
      return Uri.splitQueryString(uri.fragment);
    } on FormatException {
      return const {};
    }
  }

  static bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);

  static EmailConfirmationCallbackStatus classifyError(Object error) {
    final normalized = error.toString().toLowerCase();
    if (_containsAny(normalized, ['expired', 'otp_expired', 'invalid_token'])) {
      return EmailConfirmationCallbackStatus.expired;
    }
    if (_containsAny(normalized, ['already', 'used', 'consumed'])) {
      return EmailConfirmationCallbackStatus.alreadyUsed;
    }
    if (_containsAny(normalized, [
      'pkce',
      'code verifier',
      'code_verifier',
      'code challenge',
    ])) {
      return EmailConfirmationCallbackStatus.pkceMismatch;
    }
    return EmailConfirmationCallbackStatus.invalid;
  }

  static bool canResend(EmailConfirmationCallbackStatus status) =>
      status == EmailConfirmationCallbackStatus.expired ||
      status == EmailConfirmationCallbackStatus.alreadyUsed ||
      status == EmailConfirmationCallbackStatus.pkceMismatch;

  static String messageFor(
    EmailConfirmationCallbackStatus status,
  ) => switch (status) {
    EmailConfirmationCallbackStatus.expired =>
      'This confirmation link has expired. Please request a new one.',
    EmailConfirmationCallbackStatus.alreadyUsed =>
      'This confirmation link was already used. Try signing in, or request a new link below.',
    EmailConfirmationCallbackStatus.pkceMismatch =>
      'Forge could not match this link to the request on this device. Request a new link, then open the newest email here.',
    EmailConfirmationCallbackStatus.invalid =>
      'Forge could not verify this confirmation link. Open the newest confirmation email and try again.',
    EmailConfirmationCallbackStatus.missingParameters =>
      'This confirmation link is incomplete. Return to the newest confirmation email and try again.',
    EmailConfirmationCallbackStatus.valid => '',
  };
}
