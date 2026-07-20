import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/progress_ring.dart';
import '../../habits/domain/habit.dart';
import '../../habits/presentation/habits_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Habit> habits = ref.watch(habitsProvider);
    final int completed = habits.where((Habit h) => h.isComplete).length;
    final double progress = completed / habits.length;
    final int earnedXp = habits
        .where((Habit h) => h.isComplete)
        .fold<int>(0, (int total, Habit h) => total + h.xp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: <Widget>[
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: <Widget>[
                  ProgressRing(progress: progress, label: 'Daily score'),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('DAY 1'),
                        const SizedBox(height: 8),
                        Text(
                          '$earnedXp XP earned',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$completed of ${habits.length} commitments complete',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Daily commitments',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final Habit habit in habits) ...<Widget>[
            Card(
              child: CheckboxListTile(
                value: habit.isComplete,
                onChanged: (_) =>
                    ref.read(habitsProvider.notifier).toggle(habit.id),
                title: Text(habit.title),
                subtitle: Text('+${habit.xp} XP'),
                secondary: Icon(
                  habit.isComplete
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
