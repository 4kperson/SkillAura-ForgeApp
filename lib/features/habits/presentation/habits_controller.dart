import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/habit.dart';

final NotifierProvider<HabitsController, List<Habit>> habitsProvider =
    NotifierProvider<HabitsController, List<Habit>>(HabitsController.new);

class HabitsController extends Notifier<List<Habit>> {
  @override
  List<Habit> build() => const <Habit>[
        Habit(id: 'move', title: 'Move your body', xp: 20),
        Habit(id: 'focus', title: '60 minutes of deep work', xp: 40),
        Habit(id: 'read', title: 'Read for 20 minutes', xp: 20),
        Habit(id: 'reflect', title: 'Evening reflection', xp: 15),
      ];

  void toggle(String id) {
    state = <Habit>[
      for (final Habit habit in state)
        if (habit.id == id)
          habit.copyWith(isComplete: !habit.isComplete)
        else
          habit,
    ];
  }
}
