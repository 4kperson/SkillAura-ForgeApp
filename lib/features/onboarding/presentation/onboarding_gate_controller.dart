import 'package:flutter/foundation.dart';

import '../data/onboarding_repository.dart';
import '../domain/onboarding_profile.dart';

enum OnboardingGateStatus { idle, loading, required, completed, failed }

class OnboardingGateController extends ChangeNotifier {
  OnboardingGateController(this._repository);

  final OnboardingRepository _repository;
  OnboardingGateStatus _status = OnboardingGateStatus.idle;
  OnboardingProfile? _profile;
  int _resolutionVersion = 0;

  OnboardingGateStatus get status => _status;
  OnboardingProfile? get profile => _profile;
  bool get isLoading =>
      _status == OnboardingGateStatus.idle ||
      _status == OnboardingGateStatus.loading;
  bool get isCompleted => _status == OnboardingGateStatus.completed;
  bool get hasFailed => _status == OnboardingGateStatus.failed;

  Future<void> resolve() async {
    if (_status != OnboardingGateStatus.idle &&
        _status != OnboardingGateStatus.failed) {
      return;
    }
    final version = ++_resolutionVersion;
    _status = OnboardingGateStatus.loading;
    notifyListeners();
    try {
      final profile = await _repository.load();
      if (version != _resolutionVersion) return;
      _profile = profile;
      _status = profile.isCompleted
          ? OnboardingGateStatus.completed
          : OnboardingGateStatus.required;
    } catch (_) {
      if (version != _resolutionVersion) return;
      _status = OnboardingGateStatus.failed;
    }
    notifyListeners();
  }

  void markCompleted([OnboardingProfile? profile]) {
    _profile = profile ?? _profile;
    if (_status == OnboardingGateStatus.completed && profile == null) return;
    _status = OnboardingGateStatus.completed;
    notifyListeners();
  }

  void updateProfile(OnboardingProfile profile) {
    _profile = profile;
    _status = profile.isCompleted
        ? OnboardingGateStatus.completed
        : OnboardingGateStatus.required;
    notifyListeners();
  }

  void reset() {
    _resolutionVersion++;
    _profile = null;
    if (_status == OnboardingGateStatus.idle) return;
    _status = OnboardingGateStatus.idle;
    notifyListeners();
  }
}
