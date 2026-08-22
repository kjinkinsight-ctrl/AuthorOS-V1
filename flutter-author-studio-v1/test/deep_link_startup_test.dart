import 'dart:convert';

import 'package:author_studio_v1/author_profile_store.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/login_select_user_page.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/welcome_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What has to be true for a bookmark to be worth having.
///
/// Opening `/plot` cannot skip signing in — the profile gate is the whole
/// security model on a shared machine — but everything after that has to
/// honour the address. The failure this guards against is subtle and total: a
/// deep link that survives the URL bar but quietly lands the author on the
/// default section, which looks like it works until you check where you are.
void main() {
  late AuthorOsDatabase database;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    debugDisableAuroraAnimation = true;
    database = AuthorOsDatabase(NativeDatabase.memory());
    manuscriptStore = ManuscriptStore(
      repository: DriftConnectedDomainRepository(database),
    );
  });

  tearDown(() {
    database.close();
    debugDisableAuroraAnimation = false;
  });

  /// A device that already holds a profile and a project, so the only thing
  /// between the author and the workspace is choosing who they are.
  void seedReturningAuthor() {
    SharedPreferences.setMockInitialValues({
      AuthorProfileStore.profilesKey: jsonEncode([
        {
          'id': 'ari',
          'displayName': 'Ari Rowan',
          'penName': '',
          'email': 'ari@example.com',
          'genres': '',
          'goals': '',
          'region': '',
          'avatarPath': '',
          'lastActiveAt': '2026-08-20T10:00:00.000Z',
        },
      ]),
      'author_studio.starter_project': jsonEncode(
        NovelStarterKit.create(
          title: 'Signal Fire',
          genre: 'Fantasy',
          projectType: 'Novel',
          wordGoal: 90000,
        ).toJson(),
      ),
    });
  }

  Future<void> pumpAppAt(WidgetTester tester, String location) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = location;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AuthorStudioApp(manuscriptStore: manuscriptStore),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a deep link still has to pass the profile gate', (tester) async {
    seedReturningAuthor();
    await pumpAppAt(tester, '/statistics');

    // Naming a section in the URL is not a way past signing in.
    expect(find.byType(LoginSelectUserPage), findsOneWidget);
    expect(find.byType(AuthorStudioShell), findsNothing);
  });

  testWidgets('signing in from a deep link lands on the section, not the launcher',
      (tester) async {
    seedReturningAuthor();
    await pumpAppAt(tester, '/statistics');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // No welcome page in between: the author already said where they were
    // going, and asking again is what makes a bookmark not worth keeping.
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(AuthorStudioShell), findsOneWidget);
    expect(currentSection(tester), 'Statistics');
  });

  testWidgets('without a deep link the launcher still greets the author',
      (tester) async {
    seedReturningAuthor();
    await pumpAppAt(tester, '/');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testWidgets('an unknown path opens AuthorOS at the gate', (tester) async {
    seedReturningAuthor();
    await pumpAppAt(tester, '/nonsense');

    expect(find.byType(LoginSelectUserPage), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Nothing was invented from the bad path, so the normal landing applies.
    expect(find.byType(WelcomePage), findsOneWidget);
  });
}

/// The section the shell is showing, read from the sidebar's selected tile.
String currentSection(WidgetTester tester) {
  final selected = tester
      .widgetList<Material>(find.descendant(
        of: find.byType(AuthorStudioShell),
        matching: find.byType(Material),
      ))
      .where((material) =>
          material.color != null &&
          material.color != Colors.transparent &&
          material.borderRadius == BorderRadius.circular(14));

  expect(selected, hasLength(1), reason: 'expected exactly one selected tile');

  final tile = find.descendant(
    of: find.byWidget(selected.single),
    matching: find.byType(Text),
  );
  return tester.widgetList<Text>(tile).first.data ?? '';
}
