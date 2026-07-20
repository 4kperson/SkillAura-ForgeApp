import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/habits/presentation/habits_controller.dart';

void main() {
  test('toggling a habit updates completion state', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(habitsProvider).first.isComplete, isFalse);

    container.read(habitsProvider.notifier).toggle('move');

    expect(container.read(habitsProvider).first.isComplete, isTrue);
  });
}
