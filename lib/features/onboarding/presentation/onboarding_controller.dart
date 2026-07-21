import 'package:flutter/foundation.dart';

import '../data/onboarding_repository.dart';
import '../domain/onboarding_profile.dart';

enum OnboardingStatus { loading, ready, saving, failed, completed }

class OnboardingController extends ChangeNotifier {
  OnboardingController(this._repository);

  final OnboardingRepository _repository;

  OnboardingStatus _status = OnboardingStatus.loading;
  OnboardingProfile _profile = const OnboardingProfile();
  String? _errorMessage;

  OnboardingStatus get status => _status;
  OnboardingProfile get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _status == OnboardingStatus.saving;

  Future<void> initialize() async {
    _status = OnboardingStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _profile = await _repository.load();
      _status = _profile.isCompleted
          ? OnboardingStatus.completed
          : OnboardingStatus.ready;
    } catch (_) {
      _status = OnboardingStatus.failed;
      _errorMessage =
          'We could not restore your progress. Check your connection and try again.';
    }
    notifyListeners();
  }

  void toggleGoal(OnboardingGoal goal) {
    final goals = [..._profile.goals];
    if (goals.contains(goal)) {
      goals.remove(goal);
    } else if (goals.length < OnboardingProfile.maxGoals) {
      goals.add(goal);
    }
    _update(_profile.copyWith(goals: goals));
  }

  void selectDisciplineLevel(DisciplineLevel level) =>
      _update(_profile.copyWith(disciplineLevel: level));

  void setRoutine({required int wakeMinutes, required int sleepMinutes}) =>
      _update(
        _profile.copyWith(
          wakeTimeMinutes: wakeMinutes,
          sleepTimeMinutes: sleepMinutes,
        ),
      );

  Future<bool> moveTo(int step) async {
    if (step < 0 || step >= OnboardingProfile.totalSteps || isBusy) {
      return false;
    }
    return _persist(_profile.copyWith(currentStep: step));
  }

  Future<bool> setNotificationPreference(bool enabled) =>
      _persist(_profile.copyWith(notificationsEnabled: enabled));

  Future<bool> complete() async {
    final saved = await _persist(
      _profile.copyWith(
        currentStep: OnboardingProfile.totalSteps - 1,
        isCompleted: true,
      ),
    );
    if (saved) {
      _status = OnboardingStatus.completed;
      notifyListeners();
    }
    return saved;
  }

  void _update(OnboardingProfile profile) {
    _profile = profile;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _persist(OnboardingProfile next) async {
    _status = OnboardingStatus.saving;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.save(next);
      _profile = next;
      _status = OnboardingStatus.ready;
      notifyListeners();
      return true;
    } catch (_) {
      _status = OnboardingStatus.failed;
      _errorMessage =
          'Your progress was not saved. Check your connection and try again.';
      notifyListeners();
      return false;
    }
  }
}
