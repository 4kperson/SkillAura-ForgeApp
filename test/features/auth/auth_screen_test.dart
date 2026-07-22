import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/features/auth/data/auth_repository.dart';
import 'package:forge_app/features/auth/presentation/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  testWidgets('expired confirmation offers a working resend action', (
    tester,
  ) async {
    final auth = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          initialMessage:
              'This confirmation link has expired. Please request a new one.',
          canResendConfirmation: true,
          authService: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resend confirmation'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'builder@example.com',
    );
    await tester.ensureVisible(find.text('Resend confirmation'));
    await tester.tap(find.text('Resend confirmation'));
    await tester.pumpAndSettle();

    expect(auth.resentEmail, 'builder@example.com');
    expect(find.textContaining('new confirmation email'), findsOneWidget);
    expect(find.text('Resend confirmation'), findsNothing);
  });
}

class _FakeAuthService implements AuthService {
  String? resentEmail;

  @override
  Future<void> resendConfirmation({required String email}) async {
    resentEmail = email;
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async => AuthResponse();

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async => AuthResponse();
}
