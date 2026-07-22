import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/email_confirmation_callback.dart';
import '../data/email_confirmation_link_source.dart';

enum SessionStatus { loading, authenticated, unauthenticated }

abstract interface class SessionSource {
  Future<bool> restoreSignedInState();
  Stream<bool> get signedInChanges;
  Stream<Object> get authErrors;
  Future<void> signOut();
}

class UnauthenticatedSessionSource implements SessionSource {
  const UnauthenticatedSessionSource();

  @override
  Future<bool> restoreSignedInState() async => false;

  @override
  Stream<bool> get signedInChanges => const Stream<bool>.empty();
  @override
  Stream<Object> get authErrors => const Stream<Object>.empty();

  @override
  Future<void> signOut() async {}
}

class SupabaseSessionSource implements SessionSource {
  SupabaseSessionSource(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> restoreSignedInState() async =>
      _client.auth.currentSession != null;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);
  @override
  Stream<Object> get authErrors => _client.auth.onAuthStateChange.transform(
    StreamTransformer<AuthState, Object>.fromHandlers(
      handleData: (_, _) {},
      handleError: (error, stackTrace, sink) => sink.add(error),
    ),
  );

  @override
  Future<void> signOut() => _client.auth.signOut();
}

class SessionController extends ChangeNotifier {
  SessionController(
    this._source, {
    EmailConfirmationLinkSource? confirmationLinks,
    this.confirmationTimeout = const Duration(seconds: 15),
  }) : _confirmationLinks = confirmationLinks {
    _subscription = _source.signedInChanges.listen(_setSignedIn);
    _errorSubscription = _source.authErrors.listen(_setCallbackError);
    if (confirmationLinks != null) {
      _confirmationLinkSubscription = confirmationLinks.links.listen(
        _handleConfirmationLink,
        onError: _setConfirmationLinkError,
      );
    }
    unawaited(_restore());
  }

  final SessionSource _source;
  final EmailConfirmationLinkSource? _confirmationLinks;
  final Duration confirmationTimeout;
  late final StreamSubscription<bool> _subscription;
  late final StreamSubscription<Object> _errorSubscription;
  StreamSubscription<Uri>? _confirmationLinkSubscription;
  Timer? _confirmationTimer;
  final Set<String> _handledConfirmationLinks = {};
  SessionStatus _status = SessionStatus.loading;
  var _confirmationPending = false;

  SessionStatus get status => _status;
  bool get isReady => _status != SessionStatus.loading;
  bool get isAuthenticated => _status == SessionStatus.authenticated;
  String? get callbackErrorMessage => _callbackErrorMessage;
  bool get canResendConfirmation =>
      _callbackStatus != null &&
      EmailConfirmationCallback.canResend(_callbackStatus!);
  String? _callbackErrorMessage;
  EmailConfirmationCallbackStatus? _callbackStatus;

  Future<void> _restore() async {
    try {
      final initialLink = await _confirmationLinks?.initialLink();
      if (initialLink != null) _handleConfirmationLink(initialLink);
    } catch (error) {
      _setConfirmationLinkError(error);
    }
    final signedIn = await _source.restoreSignedInState();
    if (signedIn || !isAuthenticated) _setSignedIn(signedIn);
  }

  void _setSignedIn(bool signedIn) {
    if (!signedIn && _confirmationPending) return;
    if (signedIn) {
      _confirmationPending = false;
      _confirmationTimer?.cancel();
      _confirmationTimer = null;
      _callbackErrorMessage = null;
      _callbackStatus = null;
    }
    final next = signedIn
        ? SessionStatus.authenticated
        : SessionStatus.unauthenticated;
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  Future<void> signOut() async {
    _confirmationPending = false;
    _confirmationTimer?.cancel();
    await _source.signOut();
    _setSignedIn(false);
  }

  void _setCallbackError(Object error) {
    final status = EmailConfirmationCallback.classifyError(error);
    _showCallbackFailure(status);
  }

  void _handleConfirmationLink(Uri uri) {
    if (!EmailConfirmationCallback.usesForgeScheme(uri) ||
        !_handledConfirmationLinks.add(uri.toString())) {
      return;
    }
    if (!EmailConfirmationCallback.matchesForgeCallback(uri)) {
      _showCallbackFailure(EmailConfirmationCallbackStatus.invalid);
      return;
    }

    final status = EmailConfirmationCallback.classify(uri);
    if (status != EmailConfirmationCallbackStatus.valid) {
      _showCallbackFailure(status);
      return;
    }

    _confirmationPending = true;
    _callbackErrorMessage = null;
    _callbackStatus = null;
    if (isAuthenticated) {
      _confirmationPending = false;
      notifyListeners();
      return;
    }
    _status = SessionStatus.loading;
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer(
      confirmationTimeout,
      () => _showCallbackFailure(EmailConfirmationCallbackStatus.pkceMismatch),
    );
    notifyListeners();
  }

  void _setConfirmationLinkError(Object error) {
    _showCallbackFailure(EmailConfirmationCallback.classifyError(error));
  }

  void _showCallbackFailure(EmailConfirmationCallbackStatus status) {
    _confirmationPending = false;
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    _callbackStatus = status;
    _callbackErrorMessage = EmailConfirmationCallback.messageFor(status);
    if (!isAuthenticated) _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    _subscription.cancel();
    _errorSubscription.cancel();
    _confirmationLinkSubscription?.cancel();
    super.dispose();
  }
}
