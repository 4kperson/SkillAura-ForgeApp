import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/auth/data/email_confirmation_callback.dart';

void main() {
  test('accepts only the registered Forge callback target', () {
    expect(
      EmailConfirmationCallback.matchesForgeCallback(
        Uri.parse('com.skillaura.forge://login-callback/?code=valid'),
      ),
      isTrue,
    );
    expect(
      EmailConfirmationCallback.matchesForgeCallback(
        Uri.parse('com.skillaura.forge://different-host/?code=valid'),
      ),
      isFalse,
    );
  });

  test('classifies a valid PKCE confirmation callback', () {
    final uri = Uri.parse(
      'com.skillaura.forge://login-callback/?code=confirmation-code',
    );
    expect(
      EmailConfirmationCallback.classify(uri),
      EmailConfirmationCallbackStatus.valid,
    );
  });

  test('classifies invalid callbacks', () {
    final uri = Uri.parse(
      'com.skillaura.forge://login-callback/?error=access_denied',
    );
    expect(
      EmailConfirmationCallback.classify(uri),
      EmailConfirmationCallbackStatus.invalid,
    );
  });

  test('classifies expired callbacks', () {
    final uri = Uri.parse(
      'com.skillaura.forge://login-callback/?error_code=otp_expired',
    );
    expect(
      EmailConfirmationCallback.classify(uri),
      EmailConfirmationCallbackStatus.expired,
    );
  });

  test('classifies already-used callbacks', () {
    final uri = Uri.parse(
      'com.skillaura.forge://login-callback/?error_description=link+already+used',
    );
    expect(
      EmailConfirmationCallback.classify(uri),
      EmailConfirmationCallbackStatus.alreadyUsed,
    );
  });

  test('classifies callbacks with missing parameters', () {
    final uri = Uri.parse('com.skillaura.forge://login-callback/');
    expect(
      EmailConfirmationCallback.classify(uri),
      EmailConfirmationCallbackStatus.missingParameters,
    );
  });

  test('classifies a mismatched PKCE callback as recoverable', () {
    final uri = Uri.parse(
      'com.skillaura.forge://login-callback/?error_description=PKCE+code+verifier+not+found',
    );
    final status = EmailConfirmationCallback.classify(uri);

    expect(status, EmailConfirmationCallbackStatus.pkceMismatch);
    expect(EmailConfirmationCallback.canResend(status), isTrue);
    expect(EmailConfirmationCallback.messageFor(status), contains('new link'));
  });
}
