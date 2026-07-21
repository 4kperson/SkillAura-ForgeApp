import 'package:flutter/foundation.dart';

import '../data/morning_repository.dart';
import '../domain/morning_snapshot.dart';

enum MorningStatus { loading, ready, failed }

class MorningController extends ChangeNotifier {
  MorningController(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MorningRepository _repository;
  final DateTime Function() _now;
  final Set<String> _updatingHabitIds = {};

  MorningStatus _status = MorningStatus.loading;
  MorningSnapshot? _snapshot;
  String? _errorMessage;

  MorningStatus get status => _status;
  MorningSnapshot? get snapshot => _snapshot;
  String? get errorMessage => _errorMessage;
  bool isUpdating(String habitId) => _updatingHabitIds.contains(habitId);

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

  Future<void> toggleHabit(String habitId) async {
    final current = _snapshot;
    if (current == null || _updatingHabitIds.contains(habitId)) return;
    final index = current.habits.indexWhere((habit) => habit.id == habitId);
    if (index < 0) return;

    final habit = current.habits[index];
    final nextCompletion = !habit.isComplete;
    final optimisticHabits = [...current.habits]
      ..[index] = habit.copyWith(isComplete: nextCompletion);
    final xpDelta = nextCompletion ? habit.xp : -habit.xp;

    _updatingHabitIds.add(habitId);
    _snapshot = current.copyWith(
      habits: optimisticHabits,
      totalXp: (current.totalXp + xpDelta).clamp(0, 1 << 31),
    );
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.setHabitCompletion(
        habitId: habitId,
        date: current.forDate,
        isComplete: nextCompletion,
      );
    } catch (_) {
      _snapshot = current;
      _errorMessage = 'That promise was not saved. Tap again to retry.';
      _updatingHabitIds.remove(habitId);
      notifyListeners();
      return;
    }

    try {
      _snapshot = await _repository.load(current.forDate);
    } catch (_) {
      _errorMessage =
          'Your promise is saved. Live streak details will refresh shortly.';
    } finally {
      _updatingHabitIds.remove(habitId);
      notifyListeners();
    }
  }
}
