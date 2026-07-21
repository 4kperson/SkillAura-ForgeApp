enum EmailConfirmationCallbackStatus {
  valid,
  invalid,
  expired,
  alreadyUsed,
  missingParameters,
}

/// Classifies callback links before they are presented to the user.
abstract final class EmailConfirmationCallback {
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

  static String messageFor(EmailConfirmationCallbackStatus status) =>
      switch (status) {
        EmailConfirmationCallbackStatus.expired =>
          'This confirmation link has expired. Please request a new one.',
        EmailConfirmationCallbackStatus.alreadyUsed =>
          'This confirmation link was already used. Try signing in instead.',
        EmailConfirmationCallbackStatus.invalid =>
          'This confirmation link is invalid. Please request a new one.',
        EmailConfirmationCallbackStatus.missingParameters =>
          'This confirmation link is incomplete. Please request a new one.',
        EmailConfirmationCallbackStatus.valid => '',
      };
}
