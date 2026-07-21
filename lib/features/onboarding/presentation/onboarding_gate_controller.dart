import 'package:flutter/foundation.dart';

import '../data/onboarding_repository.dart';

enum OnboardingGateStatus { idle, loading, required, completed, failed }

class OnboardingGateController extends ChangeNotifier {
  OnboardingGateController(this._repository);

  final OnboardingRepository _repository;
  OnboardingGateStatus _status = OnboardingGateStatus.idle;

  OnboardingGateStatus get status => _status;
  bool get isLoading =>
      _status == OnboardingGateStatus.idle ||
      _status == OnboardingGateStatus.loading;
  bool get isCompleted => _status == OnboardingGateStatus.completed;

  Future<void> resolve() async {
    if (_status != OnboardingGateStatus.idle &&
        _status != OnboardingGateStatus.failed) {
      return;
    }
    _status = OnboardingGateStatus.loading;
    notifyListeners();
    try {
      final profile = await _repository.load();
      _status = profile.isCompleted
          ? OnboardingGateStatus.completed
          : OnboardingGateStatus.required;
    } catch (_) {
      _status = OnboardingGateStatus.failed;
    }
    notifyListeners();
  }

  void markCompleted() {
    if (_status == OnboardingGateStatus.completed) return;
    _status = OnboardingGateStatus.completed;
    notifyListeners();
  }

  void reset() {
    if (_status == OnboardingGateStatus.idle) return;
    _status = OnboardingGateStatus.idle;
    notifyListeners();
  }
}
