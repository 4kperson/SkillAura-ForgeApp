import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_error_mapper.dart';

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
      handleError: (error, stackTrace, sink) => sink.add(error),
    ),
  );

  @override
  Future<void> signOut() => _client.auth.signOut();
}

class SessionController extends ChangeNotifier {
  SessionController(this._source) {
    _subscription = _source.signedInChanges.listen(_setSignedIn);
    _errorSubscription = _source.authErrors.listen(_setCallbackError);
    unawaited(_restore());
  }

  final SessionSource _source;
  late final StreamSubscription<bool> _subscription;
  late final StreamSubscription<Object> _errorSubscription;
  SessionStatus _status = SessionStatus.loading;

  SessionStatus get status => _status;
  bool get isReady => _status != SessionStatus.loading;
  bool get isAuthenticated => _status == SessionStatus.authenticated;
  String? get callbackErrorMessage => _callbackErrorMessage;
  String? _callbackErrorMessage;

  Future<void> _restore() async {
    final signedIn = await _source.restoreSignedInState();
    _setSignedIn(signedIn);
  }

  void _setSignedIn(bool signedIn) {
    final next = signedIn
        ? SessionStatus.authenticated
        : SessionStatus.unauthenticated;
    if (_status == next) return;
    _status = next;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _source.signOut();
    _setSignedIn(false);
  }

  void _setCallbackError(Object error) {
    _callbackErrorMessage = AuthErrorMapper.messageFor(error);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _errorSubscription.cancel();
    super.dispose();
  }
}
