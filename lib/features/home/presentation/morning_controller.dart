import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/morning_repository.dart';
import '../domain/morning_snapshot.dart';

enum MorningStatus { loading, ready, failed }

class MorningController extends ChangeNotifier {
  MorningController(
    this._repository, {
    DateTime Function()? now,
    this.confirmedStateDuration = const Duration(milliseconds: 650),
  }) : _now = now ?? DateTime.now;

  final MorningRepository _repository;
  final DateTime Function() _now;
  final Duration confirmedStateDuration;
  final Set<String> _updatingHabitIds = {};
  final Set<String> _recentlyCompletedHabitIds = {};
  final Map<String, Timer> _confirmedStateTimers = {};

  MorningStatus _status = MorningStatus.loading;
  MorningSnapshot? _snapshot;
  String? _errorMessage;

  MorningStatus get status => _status;
  MorningSnapshot? get snapshot => _snapshot;
  String? get errorMessage => _errorMessage;
  bool isUpdating(String habitId) => _updatingHabitIds.contains(habitId);
  bool isRecentlyCompleted(String habitId) =>
      _recentlyCompletedHabitIds.contains(habitId);

  Future<void> initialize() async {
    _status = MorningStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _snapshot = await _repository.load(_now());
      _status = MorningStatus.ready;
    } catch (_) {
      _status = MorningStatus.failed;
      _errorMessage =
          'Your morning could not be loaded. Check your connection and try again.';
    }
    notifyListeners();
  }

  Future<bool> toggleHabit(String habitId) async {
    final current = _snapshot;
    if (current == null || _updatingHabitIds.contains(habitId)) return false;
    final index = current.habits.indexWhere((habit) => habit.id == habitId);
    if (index < 0) return false;

    final habit = current.habits[index];
    if (habit.isComplete) return false;

    _updatingHabitIds.add(habitId);
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.setHabitCompletion(
        habitId: habitId,
        date: current.forDate,
        isComplete: true,
      );
      if (!result.changed) {
        _snapshot = await _repository.load(result.completionDate);
        _updatingHabitIds.remove(habitId);
        notifyListeners();
        return false;
      }

      final confirmedHabits = [...current.habits]
        ..[index] = habit.copyWith(isComplete: true);
      _snapshot = current.copyWith(
        habits: confirmedHabits,
        totalXp: result.totalXp,
        forDate: result.completionDate,
      );
    } catch (error, stackTrace) {
      _logFailure('habit completion', error, stackTrace);
      _errorMessage = 'That promise was not saved. Tap again to retry.';
      _updatingHabitIds.remove(habitId);
      notifyListeners();
      return false;
    }

    _updatingHabitIds.remove(habitId);
    _recentlyCompletedHabitIds.add(habitId);
    _scheduleConfirmedStateDismissal(habitId);
    notifyListeners();

    try {
      _snapshot = await _repository.load(current.forDate);
    } catch (error, stackTrace) {
      _logFailure('morning refresh after completion', error, stackTrace);
      _errorMessage =
          'Your promise is saved. Live streak details will refresh shortly.';
    }
    notifyListeners();
    return true;
  }

  Future<bool> undoHabit(String habitId) async {
    final current = _snapshot;
    if (current == null || _updatingHabitIds.contains(habitId)) return false;
    final index = current.habits.indexWhere((habit) => habit.id == habitId);
    if (index < 0 || !current.habits[index].isComplete) return false;
    final habit = current.habits[index];

    _updatingHabitIds.add(habitId);
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _repository.setHabitCompletion(
        habitId: habitId,
        date: current.forDate,
        isComplete: false,
      );
      if (!result.changed) {
        _snapshot = await _repository.load(result.completionDate);
        _updatingHabitIds.remove(habitId);
        notifyListeners();
        return false;
      }

      _confirmedStateTimers.remove(habitId)?.cancel();
      _recentlyCompletedHabitIds.remove(habitId);
      final restored = [...current.habits]
        ..[index] = habit.copyWith(isComplete: false);
      _snapshot = current.copyWith(
        habits: restored,
        totalXp: result.totalXp,
        forDate: result.completionDate,
      );
    } catch (error, stackTrace) {
      _logFailure('habit completion undo', error, stackTrace);
      _errorMessage =
          'That completion could not be undone. Your saved progress is unchanged.';
      _updatingHabitIds.remove(habitId);
      notifyListeners();
      return false;
    }

    _updatingHabitIds.remove(habitId);
    notifyListeners();

    try {
      _snapshot = await _repository.load(current.forDate);
    } catch (error, stackTrace) {
      _logFailure('morning refresh after completion undo', error, stackTrace);
      _errorMessage =
          'The completion was undone. Live streak details will refresh shortly.';
    }
    notifyListeners();
    return true;
  }

  void _scheduleConfirmedStateDismissal(String habitId) {
    _confirmedStateTimers.remove(habitId)?.cancel();
    _confirmedStateTimers[habitId] = Timer(confirmedStateDuration, () {
      _confirmedStateTimers.remove(habitId);
      if (_recentlyCompletedHabitIds.remove(habitId)) notifyListeners();
    });
  }

  static void _logFailure(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;
    debugPrint('[habits] $operation failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  @override
  void dispose() {
    for (final timer in _confirmedStateTimers.values) {
      timer.cancel();
    }
    _confirmedStateTimers.clear();
    super.dispose();
  }
}
