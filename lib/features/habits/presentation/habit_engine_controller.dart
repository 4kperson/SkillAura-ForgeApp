import 'package:flutter/foundation.dart';

import '../data/habit_repository.dart';
import '../domain/habit.dart';

enum HabitEngineStatus { loading, ready, failed }

class HabitEngineController extends ChangeNotifier {
  HabitEngineController(this._repository);

  final HabitRepository _repository;
  final Set<String> _busyHabitIds = {};

  HabitEngineStatus _status = HabitEngineStatus.loading;
  HabitLibrary? _library;
  String? _errorMessage;
  bool _creating = false;
  bool _reordering = false;

  HabitEngineStatus get status => _status;
  HabitLibrary? get library => _library;
  String? get errorMessage => _errorMessage;
  bool get isCreating => _creating;
  bool get isReordering => _reordering;
  bool isBusy(String habitId) => _busyHabitIds.contains(habitId);

  Future<void> initialize() async {
    if (_library == null) _status = HabitEngineStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _library = await _repository.load();
      _status = HabitEngineStatus.ready;
    } catch (_) {
      _status = HabitEngineStatus.failed;
      _errorMessage =
          'Your habits could not be loaded. Check your connection and try again.';
    }
    notifyListeners();
  }

  Future<bool> create(HabitDraft draft) async {
    if (_creating) return false;
    final validation = draft.validationMessage;
    if (validation != null) {
      _errorMessage = validation;
      notifyListeners();
      return false;
    }
    _creating = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.create(draft);
      await _reloadAfterMutation();
      return true;
    } catch (_) {
      _errorMessage =
          'That habit was not saved. Your edits are still here—please try again.';
      return false;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  Future<bool> update(String habitId, HabitDraft draft) =>
      _mutate(habitId, () => _repository.update(habitId, draft));

  Future<bool> setPaused(String habitId, {required bool paused}) => _mutate(
    habitId,
    () => _repository.setPaused(habitId, paused: paused),
    failureMessage: paused
        ? 'This habit could not be paused. Nothing changed.'
        : 'This habit could not be resumed. Please try again.',
  );

  Future<bool> setArchived(String habitId, {required bool archived}) => _mutate(
    habitId,
    () => _repository.setArchived(habitId, archived: archived),
    failureMessage: archived
        ? 'This habit could not be archived. Nothing changed.'
        : 'This habit could not be restored. Please try again.',
  );

  Future<bool> delete(String habitId) async {
    if (_busyHabitIds.contains(habitId)) return false;
    _busyHabitIds.add(habitId);
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.delete(habitId);
      await _reloadAfterMutation();
      return true;
    } catch (_) {
      _errorMessage =
          'This habit could not be deleted. Your history is still safe.';
      return false;
    } finally {
      _busyHabitIds.remove(habitId);
      notifyListeners();
    }
  }

  Future<bool> reorderActive(int oldIndex, int newIndex) async {
    final current = _library;
    if (current == null || _reordering) return false;
    final active = [...current.active];
    if (oldIndex < 0 || oldIndex >= active.length) return false;
    final insertion = newIndex;
    if (insertion < 0 || insertion > active.length) return false;
    final moved = active.removeAt(oldIndex);
    active.insert(insertion, moved);

    final positions = {
      for (var index = 0; index < active.length; index++)
        active[index].id: index,
    };
    final optimistic = [
      for (final habit in current.habits)
        positions.containsKey(habit.id)
            ? habit.copyWith(position: positions[habit.id])
            : habit,
    ]..sort(_compareHabits);
    _library = HabitLibrary(habits: optimistic, timeZone: current.timeZone);
    _reordering = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.reorder(active.map((habit) => habit.id).toList());
      await _reloadAfterMutation();
      return true;
    } catch (_) {
      _library = current;
      _errorMessage =
          'Your new order was not saved. The previous order is back.';
      return false;
    } finally {
      _reordering = false;
      notifyListeners();
    }
  }

  Future<List<HabitCompletion>> loadHistory(String habitId) =>
      _repository.loadHistory(habitId);

  void clearMessage() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _mutate(
    String habitId,
    Future<Habit> Function() mutation, {
    String failureMessage =
        'That change was not saved. Your previous habit is still active.',
  }) async {
    if (_busyHabitIds.contains(habitId)) return false;
    _busyHabitIds.add(habitId);
    _errorMessage = null;
    notifyListeners();
    try {
      await mutation();
      await _reloadAfterMutation();
      return true;
    } catch (_) {
      _errorMessage = failureMessage;
      return false;
    } finally {
      _busyHabitIds.remove(habitId);
      notifyListeners();
    }
  }

  Future<void> _reloadAfterMutation() async {
    _library = await _repository.load();
    _status = HabitEngineStatus.ready;
  }

  static int _compareHabits(Habit a, Habit b) {
    final position = a.position.compareTo(b.position);
    if (position != 0) return position;
    return a.title.compareTo(b.title);
  }
}
