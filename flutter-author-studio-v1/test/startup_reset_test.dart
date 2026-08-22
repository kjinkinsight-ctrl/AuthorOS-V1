import 'package:author_studio_v1/author_profile_store.dart';
import 'package:author_studio_v1/login_select_user_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Clearing local data is one tap from the sign-in screen, and on a public web
/// deployment that screen is reachable by anyone who opens the URL. The action
/// erases every profile and project in the browser with no undo, so it has to
/// ask first.
void main() {
  AuthorProfile profile() => const AuthorProfile(
        id: 'ari',
        displayName: 'Ari Rowan',
        penName: '',
        email: 'ari@example.com',
        genres: '',
        goals: '',
        region: '',
      );

  Future<void> pumpLogin(
    WidgetTester tester, {
    required Future<void> Function() onReset,
  }) async {
    // The startup panel is a tall column; the default 800x600 test window cuts
    // off its footer, where this control lives.
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: LoginSelectUserPage(
        profiles: [profile()],
        onContinue: (_) {},
        onAddNewUser: () {},
        onReset: onReset,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapReset(WidgetTester tester) async {
    final reset = find.byKey(const Key('startup-reset'));
    await tester.ensureVisible(reset);
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
  }

  testWidgets('the reset control is named for an author, not a developer',
      (tester) async {
    await pumpLogin(tester, onReset: () async {});

    expect(find.text('Start over on this device'), findsOneWidget);
    expect(find.text('Reset app state'), findsNothing);
  });

  testWidgets('erasing local data asks before it happens', (tester) async {
    var reset = 0;
    await pumpLogin(tester, onReset: () async => reset++);

    await tapReset(tester);

    expect(find.byKey(const Key('startup-reset-confirm')), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(reset, 0, reason: 'nothing may be erased before confirmation');
  });

  testWidgets('declining the confirmation keeps the author\'s work',
      (tester) async {
    var reset = 0;
    await pumpLogin(tester, onReset: () async => reset++);

    await tapReset(tester);
    await tester.tap(find.text('Keep my work'));
    await tester.pumpAndSettle();

    expect(reset, 0);
    expect(find.byKey(const Key('startup-reset-confirm')), findsNothing);
  });

  testWidgets('confirming erases local data', (tester) async {
    var reset = 0;
    await pumpLogin(tester, onReset: () async => reset++);

    await tapReset(tester);
    await tester.tap(find.byKey(const Key('startup-reset-confirm-action')));
    await tester.pumpAndSettle();

    expect(reset, 1);
  });
}
