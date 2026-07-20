import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge_app/app/app.dart';
import 'package:forge_app/features/auth/presentation/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('unauthenticated launch resolves to authentication', (
    tester,
  ) async {
    final source = _FakeSessionSource();
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
  });

  testWidgets('authenticated launch resolves directly to home', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily commitments'), findsOneWidget);
  });

  testWidgets('shows a splash while the stored session is resolving', (
    tester,
  ) async {
    final restore = Completer<bool>();
    final source = _FakeSessionSource(restore: () => restore.future);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    restore.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
  });

  testWidgets('protected home route redirects signed-out users', (
    tester,
  ) async {
    final source = _FakeSessionSource();
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: ForgeApp(
          sessionController: controller,
          initialLocation: '/home',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
    expect(find.text('Daily commitments'), findsNothing);
  });

  testWidgets('sign out returns the user to authentication', (tester) async {
    final source = _FakeSessionSource(signedIn: true);
    final controller = SessionController(source);
    addTearDown(() async {
      controller.dispose();
      await source.dispose();
    });

    await tester.pumpWidget(
      ProviderScope(child: ForgeApp(sessionController: controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Return to the\nwork that matters.'), findsOneWidget);
  });
}

class _FakeSessionSource implements SessionSource {
  _FakeSessionSource({this.signedIn = false, this.restore});

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool signedIn;
  final Future<bool> Function()? restore;

  @override
  Future<bool> restoreSignedInState() =>
      restore?.call() ?? Future.value(signedIn);

  @override
  Stream<bool> get signedInChanges => _changes.stream;

  @override
  Future<void> signOut() async {
    signedIn = false;
    _changes.add(false);
  }

  Future<void> dispose() => _changes.close();
}
