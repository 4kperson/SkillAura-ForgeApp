import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/app/app.dart';

void main() {
  testWidgets('onboarding opens and navigates to home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ForgeApp()));

    expect(find.textContaining('Become the person'), findsOneWidget);

    await tester.tap(find.text('Start building discipline'));
    await tester.pumpAndSettle();

    expect(find.text('Daily commitments'), findsOneWidget);
  });
}
