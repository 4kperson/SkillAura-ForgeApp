import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/auth/data/email_confirmation_link_source.dart';
import 'package:forge_app/features/auth/presentation/session_controller.dart';

void main() {
  test(
    'cold-start confirmation waits for and restores the new session',
    () async {
      final source = _FakeSessionSource();
      final links = _FakeConfirmationLinks(
        initial: Uri.parse(
          'com.skillaura.forge://login-callback/?code=confirmation-code',
        ),
      );
      final controller = SessionController(source, confirmationLinks: links);
      addTearDown(() async {
        controller.dispose();
        await source.dispose();
        await links.dispose();
      });

      await _flushEvents();
      expect(controller.status, SessionStatus.loading);

      source.setSignedIn(true);
      await _flushEvents();

      expect(controller.status, SessionStatus.authenticated);
      expect(controller.callbackErrorMessage, isNull);
    },
  );

  test(
    'confirmation received while open creates an authenticated session',
    () async {
      final source = _FakeSessionSource();
      final links = _FakeConfirmationLinks();
      final controller = SessionController(source, confirmationLinks: links);
      addTearDown(() async {
        controller.dispose();
        await source.dispose();
        await links.dispose();
      });

      await _flushEvents();
      expect(controller.status, SessionStatus.unauthenticated);

      links.add(
        Uri.parse(
          'com.skillaura.forge://login-callback/?code=confirmation-code',
        ),
      );
      await _flushEvents();
      expect(controller.status, SessionStatus.loading);

      source.setSignedIn(true);
      await _flushEvents();
      expect(controller.status, SessionStatus.authenticated);
    },
  );

  test('expired and consumed callbacks expose resend recovery', () async {
    for (final callback in [
      'com.skillaura.forge://login-callback/?error_code=otp_expired',
      'com.skillaura.forge://login-callback/?error_description=link+already+consumed',
    ]) {
      final source = _FakeSessionSource();
      final links = _FakeConfirmationLinks(initial: Uri.parse(callback));
      final controller = SessionController(source, confirmationLinks: links);

      await _flushEvents();
      expect(controller.status, SessionStatus.unauthenticated);
      expect(controller.callbackErrorMessage, isNotEmpty);
      expect(controller.canResendConfirmation, isTrue);

      controller.dispose();
      await source.dispose();
      await links.dispose();
    }
  });

  test('malformed callback shows a useful nonblank message', () async {
    final source = _FakeSessionSource();
    final links = _FakeConfirmationLinks(
      initial: Uri.parse('com.skillaura.forge://login-callback/'),
    );
    final controller = SessionController(source, confirmationLinks: links);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
      await links.dispose();
    });

    await _flushEvents();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.callbackErrorMessage, contains('incomplete'));
    expect(controller.canResendConfirmation, isFalse);
  });

  test('mismatched callback host is rejected with a useful message', () async {
    final source = _FakeSessionSource();
    final links = _FakeConfirmationLinks(
      initial: Uri.parse(
        'com.skillaura.forge://wrong-host/?code=confirmation-code',
      ),
    );
    final controller = SessionController(source, confirmationLinks: links);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
      await links.dispose();
    });

    await _flushEvents();

    expect(controller.status, SessionStatus.unauthenticated);
    expect(controller.callbackErrorMessage, contains('could not verify'));
  });

  test(
    'PKCE exchange failure becomes a recoverable confirmation message',
    () async {
      final source = _FakeSessionSource();
      final controller = SessionController(source);
      addTearDown(() async {
        controller.dispose();
        await source.dispose();
      });

      await _flushEvents();
      source.addError(StateError('PKCE code verifier not found'));
      await _flushEvents();

      expect(controller.callbackErrorMessage, contains('new link'));
      expect(controller.canResendConfirmation, isTrue);
    },
  );
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _FakeSessionSource implements SessionSource {
  final _changes = StreamController<bool>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  var signedIn = false;

  @override
  Stream<Object> get authErrors => _errors.stream;

  @override
  Future<bool> restoreSignedInState() async => signedIn;

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  void setSignedIn(bool value) {
    signedIn = value;
    _changes.add(value);
  }

  void addError(Object error) => _errors.add(error);

  @override
  Future<void> signOut() async => setSignedIn(false);

  Future<void> dispose() async {
    await _changes.close();
    await _errors.close();
  }
}

class _FakeConfirmationLinks implements EmailConfirmationLinkSource {
  _FakeConfirmationLinks({this.initial});

  final Uri? initial;
  final _links = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> initialLink() async => initial;

  @override
  Stream<Uri> get links => _links.stream;

  void add(Uri uri) => _links.add(uri);

  Future<void> dispose() => _links.close();
}
