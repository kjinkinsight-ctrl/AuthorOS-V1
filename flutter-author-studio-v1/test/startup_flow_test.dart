import 'dart:convert';

import 'package:author_studio_v1/author_profile_store.dart';
import 'package:author_studio_v1/create_profile_page.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/login_select_user_page.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/startup_backdrop.dart';
import 'package:author_studio_v1/welcome_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A roster entry, encoded the way [AuthorProfileStore] persists it.
String encodeRoster(List<Map<String, Object?>> profiles) =>
    jsonEncode(profiles);

Map<String, Object?> profileJson({
  required String id,
  required String displayName,
  String penName = '',
  String email = '',
  String? lastActiveAt,
}) => {
  'id': id,
  'displayName': displayName,
  'penName': penName,
  'email': email,
  'genres': '',
  'goals': '',
  'region': '',
  'avatarPath': '',
  'lastActiveAt': lastActiveAt,
};

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

  Future<void> pumpApp(WidgetTester tester, {bool showWelcome = true}) async {
    // A desktop-sized window: the startup panel is a tall column and the
    // default 800x600 test view leaves its lower controls off-screen.
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AuthorStudioApp(
        manuscriptStore: manuscriptStore,
        showWelcome: showWelcome,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('cold start', () {
    testWidgets('resolves to Login / Select User, not the opening page', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await pumpApp(tester);

      expect(find.byType(LoginSelectUserPage), findsOneWidget);
      // First run, so the greeting welcomes rather than welcomes back.
      expect(find.text('Welcome to'), findsOneWidget);
      expect(find.byType(WelcomePage), findsNothing);
    });

    testWidgets('offers an empty roster rather than jumping to creation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await pumpApp(tester);

      expect(find.byType(CreateProfilePage), findsNothing);
      expect(find.byKey(const Key('startup-add-user')), findsOneWidget);
    });
  });

  group('profile selection', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        AuthorProfileStore.profilesKey: encodeRoster([
          profileJson(
            id: 'a',
            displayName: 'Alexandra',
            penName: 'Lead Author',
            email: 'alexandra@example.com',
            lastActiveAt: '2026-08-20T09:00:00.000',
          ),
          profileJson(
            id: 'b',
            displayName: 'Michael',
            penName: 'Worldbuilder',
            email: 'michael@example.com',
            lastActiveAt: '2026-08-18T09:00:00.000',
          ),
        ]),
      });
    });

    testWidgets('greets a returning author and offers Add New User',
        (tester) async {
      await pumpApp(tester);

      expect(find.text('Welcome Back to'), findsOneWidget);
      expect(find.text('Select a User'), findsOneWidget);
      expect(find.text('Add New User'), findsOneWidget);
    });

    testWidgets('lists every local profile', (tester) async {
      await pumpApp(tester);

      expect(find.text('Alexandra'), findsOneWidget);
      expect(find.text('Michael'), findsOneWidget);
      expect(find.byKey(const Key('startup-profile-a')), findsOneWidget);
      expect(find.byKey(const Key('startup-profile-b')), findsOneWidget);
    });

    testWidgets('a different profile can be selected', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('startup-profile-b')));
      await tester.pumpAndSettle();

      final card = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const Key('startup-profile-b')),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(card.properties.selected, isTrue);
    });

    testWidgets('Continue transitions to the opening page', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('startup-continue')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginSelectUserPage), findsNothing);
      expect(find.byType(WelcomePage), findsOneWidget);
    });
  });

  OutlinedButton continueButton(WidgetTester tester) =>
      tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const Key('startup-continue')),
          matching: find.byType(OutlinedButton),
        ),
      );

  testWidgets('Continue is disabled when no profile is selected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);

    expect(continueButton(tester).onPressed, isNull);
  });

  testWidgets('Continue becomes available once a profile is selected', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AuthorProfileStore.profilesKey: encodeRoster([
        profileJson(id: 'a', displayName: 'Alexandra'),
      ]),
    });
    await pumpApp(tester);

    expect(continueButton(tester).onPressed, isNotNull);
  });

  group('profile creation', () {
    testWidgets('Add New User opens Create Your Profile', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('startup-add-user')));
      await tester.pumpAndSettle();

      expect(find.byType(CreateProfilePage), findsOneWidget);
      expect(find.text('Create Your Profile'), findsOneWidget);
      expect(find.text('Start Your Adventure'), findsOneWidget);
    });

    testWidgets('required fields are validated before the adventure starts', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('startup-add-user')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start-your-adventure')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a display name.'), findsOneWidget);
      expect(find.text('Enter an email address.'), findsOneWidget);
      expect(find.byType(CreateProfilePage), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        'Sophie',
      );
      await tester.enterText(
        find.byKey(const Key('profile-email-field')),
        'not-an-email',
      );
      await tester.tap(find.byKey(const Key('start-your-adventure')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(find.byType(CreateProfilePage), findsOneWidget);
    });

    testWidgets('a created profile persists and opens the opening page', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('startup-add-user')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        'Sophie',
      );
      await tester.enterText(
        find.byKey(const Key('profile-pen-name-field')),
        'Character Creator',
      );
      await tester.enterText(
        find.byKey(const Key('profile-email-field')),
        'sophie@example.com',
      );
      await tester.tap(find.byKey(const Key('start-your-adventure')));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomePage), findsOneWidget);

      // Persisted through the existing SharedPreferences architecture, with
      // the active-profile mirrors the rest of the app already reads.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('author_studio.profile.name'), 'Sophie');
      expect(
        prefs.getString('author_studio.profile.email'),
        'sophie@example.com',
      );

      final roster = await const AuthorProfileStore().loadProfiles();
      expect(roster, hasLength(1));
      expect(roster.single.displayName, 'Sophie');
      expect(roster.single.penName, 'Character Creator');
    });

    testWidgets('Back returns to login without creating anything', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester);

      await tester.tap(find.byKey(const Key('startup-add-user')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-profile-back')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginSelectUserPage), findsOneWidget);
      expect(await const AuthorProfileStore().loadProfiles(), isEmpty);
    });
  });

  group('remote sign-in entry points', () {
    for (final entry in const {
      'startup-email-auth': 'Continue with Email',
      'startup-password-auth': 'Use Password',
    }.entries) {
      testWidgets('${entry.value} opens without inventing a session', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await pumpApp(tester);

        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('startup-auth-notice')), findsOneWidget);
        expect(find.byType(LoginSelectUserPage), findsOneWidget);
        expect(find.byType(WelcomePage), findsNothing);
      });
    }
  });

  group('theme and accessibility', () {
    testWidgets('startup reuses the engine palette without a second ThemeData', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpApp(tester);

      // Exactly one MaterialApp, so no startup-local ThemeData was introduced.
      expect(find.byType(MaterialApp), findsOneWidget);

      final palette = StartupPalette.engineDark;
      expect(palette.gold, const Color(0xFFD4AF37));
      expect(palette.background, const Color(0xFF080808));
    });

    testWidgets('major startup controls carry semantic labels', (tester) async {
      SharedPreferences.setMockInitialValues({
        AuthorProfileStore.profilesKey: encodeRoster([
          profileJson(id: 'a', displayName: 'Alexandra'),
        ]),
      });
      final handle = tester.ensureSemantics();
      await pumpApp(tester);

      expect(find.bySemanticsLabel('Continue'), findsOneWidget);
      expect(find.bySemanticsLabel('Add New User'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Alexandra, last active')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('startup controls are reachable by keyboard', (tester) async {
      SharedPreferences.setMockInitialValues({
        AuthorProfileStore.profilesKey: encodeRoster([
          profileJson(id: 'a', displayName: 'Alexandra'),
        ]),
      });
      await pumpApp(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(
        FocusManager.instance.primaryFocus!.context,
        isNotNull,
        reason: 'Tab should move focus onto a startup control.',
      );
    });
  });

  testWidgets('the existing opening page is still reachable after sign-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AuthorProfileStore.profilesKey: encodeRoster([
        profileJson(id: 'a', displayName: 'Alexandra'),
      ]),
    });
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('startup-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomePage), findsOneWidget);
  });

  group('AuthorProfileStore', () {
    test('adopts a pre-roster install from the legacy profile keys', () async {
      SharedPreferences.setMockInitialValues({
        'author_studio.profile.name': 'Old Name',
        'author_studio.profile.email': 'old@example.com',
      });

      final roster = await const AuthorProfileStore().loadProfiles();

      expect(roster, hasLength(1));
      expect(roster.single.displayName, 'Old Name');
      expect(roster.single.email, 'old@example.com');
    });

    test('orders the roster by most recently active', () async {
      SharedPreferences.setMockInitialValues({
        AuthorProfileStore.profilesKey: encodeRoster([
          profileJson(
            id: 'older',
            displayName: 'Older',
            lastActiveAt: '2026-08-01T09:00:00.000',
          ),
          profileJson(
            id: 'newer',
            displayName: 'Newer',
            lastActiveAt: '2026-08-19T09:00:00.000',
          ),
        ]),
      });

      final roster = await const AuthorProfileStore().loadProfiles();

      expect(roster.map((profile) => profile.id), ['newer', 'older']);
    });

    test('formats the last-active line', () {
      final now = DateTime(2026, 8, 21);
      expect(formatLastActive(DateTime(2026, 8, 21), now: now), 'Today');
      expect(formatLastActive(DateTime(2026, 8, 20), now: now), 'Yesterday');
      expect(formatLastActive(DateTime(2026, 8, 18), now: now), '3 days ago');
      expect(formatLastActive(null, now: now), 'Not opened yet');
    });
  });
}
