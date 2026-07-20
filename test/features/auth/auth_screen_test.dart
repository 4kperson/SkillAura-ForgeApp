import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/auth/presentation/auth_screen.dart';

void main() {
  Widget buildSubject() => const MaterialApp(home: AuthScreen());

  testWidgets('renders without overflow on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
    expect(find.text('Continue to Forge'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches clearly between sign in and account creation', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Your next level\nstarts here.'), findsOneWidget);
    expect(find.text('Begin your journey'), findsOneWidget);
  });

  testWidgets('shows actionable validation without calling authentication', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.ensureVisible(find.text('Continue to Forge'));
    await tester.tap(find.text('Continue to Forge'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });
}
