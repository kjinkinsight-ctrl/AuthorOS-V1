// Verification harness: renders each startup state and writes a PNG so the
// actual pixels can be inspected.
//
// This is a tool, not a regression test. The filename deliberately lacks the
// `_test` suffix so `flutter test` skips it, and the PNGs it writes are not
// committed. Regenerate them on demand with:
//
//   flutter test test/startup_screens_capture.dart --update-goldens
//
// then look at test/startup_screens/.
import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/author_profile_store.dart';
import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/startup_backdrop.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Real text needs real fonts: `flutter test` does not load the pubspec fonts.
Future<void> loadAppFonts() async {
  const families = {
    'Merriweather': [
      'assets/fonts/Merriweather-400.ttf',
      'assets/fonts/Merriweather-700.ttf',
    ],
    'Inter': ['assets/fonts/Inter-400.ttf', 'assets/fonts/Inter-700.ttf'],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }

  // Icons are shipped with the Flutter SDK, not the app, so the test bundle
  // has no glyphs for them and every icon captures as an empty box.
  final iconFont = File(
    '${_flutterRoot()}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  if (iconFont.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        iconFont.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    await loader.load();
  }
}

String _flutterRoot() {
  // dart:io reports the SDK path via the running Dart executable.
  final executable = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final marker = executable.indexOf('/bin/cache/dart-sdk/');
  return marker == -1
      ? Platform.environment['FLUTTER_ROOT'] ?? ''
      : executable.substring(0, marker);
}

void main() {
  late AuthorOsDatabase database;
  late ManuscriptStore manuscriptStore;

  setUpAll(() async {
    await loadAppFonts();
  });

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

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    bool showWelcome = true,
  }) async {
    tester.view.physicalSize = size;
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

    // Decode the doorway artwork for real so the capture is not a blank frame.
    await tester.runAsync(() async {
      await precacheImage(
        startupDoorway,
        tester.element(find.byType(Stack).first),
      );
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('startup_screens/$name.png'),
    );
  }

  testWidgets('A login with zero profiles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await capture(tester, 'a_login_zero_profiles');
  });

  testWidgets('B login with one profile', (tester) async {
    SharedPreferences.setMockInitialValues({
      AuthorProfileStore.profilesKey: jsonEncode([
        profileJson(
          id: 'a',
          displayName: 'Alexandra',
          penName: 'Lead Author',
          email: 'alexandra@example.com',
          lastActiveAt: '2026-08-21T09:00:00.000',
        ),
      ]),
    });
    await pumpApp(tester);
    await capture(tester, 'b_login_one_profile');
  });

  testWidgets('C login with multiple profiles', (tester) async {
    SharedPreferences.setMockInitialValues({
      AuthorProfileStore.profilesKey: jsonEncode([
        profileJson(
          id: 'a',
          displayName: 'Alexandra',
          penName: 'Lead Author',
          email: 'alexandra@example.com',
          lastActiveAt: '2026-08-21T09:00:00.000',
        ),
        profileJson(
          id: 'b',
          displayName: 'Michael',
          penName: 'Worldbuilder',
          email: 'michael@example.com',
          lastActiveAt: '2026-08-20T09:00:00.000',
        ),
        profileJson(
          id: 'c',
          displayName: 'Sophie',
          penName: 'Character Creator',
          email: 'sophie@example.com',
          lastActiveAt: '2026-08-18T09:00:00.000',
        ),
      ]),
    });
    await pumpApp(tester);
    await capture(tester, 'c_login_multiple_profiles');

    // Selecting the third profile must not leave the first selected.
    await tester.tap(find.byKey(const Key('startup-profile-c')));
    await tester.pumpAndSettle();
    await capture(tester, 'c2_login_third_selected');
  });

  testWidgets('D create profile', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('startup-add-user')));
    await tester.pumpAndSettle();
    await capture(tester, 'd_create_profile');
  });

  testWidgets('E create profile with validation errors', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('startup-add-user')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('start-your-adventure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-your-adventure')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    await capture(tester, 'e_create_profile_errors');
  });

  testWidgets('F create profile with valid information', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('startup-add-user')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Sophie Marchetti',
    );
    await tester.enterText(
      find.byKey(const Key('profile-pen-name-field')),
      'S. M. Rowan',
    );
    await tester.enterText(
      find.byKey(const Key('profile-email-field')),
      'sophie@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('profile-genres-field')),
      'Fantasy, Mystery',
    );
    await tester.enterText(
      find.byKey(const Key('profile-goals-field')),
      'Finish my first trilogy',
    );
    await tester.enterText(
      find.byKey(const Key('profile-region-field')),
      'Australia',
    );
    await tester.pumpAndSettle();
    await capture(tester, 'f_create_profile_valid');
  });

  testWidgets('G opening page after profile creation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('startup-add-user')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-name-field')),
      'Sophie Marchetti',
    );
    await tester.enterText(
      find.byKey(const Key('profile-email-field')),
      'sophie@example.com',
    );
    await tester.ensureVisible(find.byKey(const Key('start-your-adventure')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-your-adventure')));
    await tester.pumpAndSettle();
    await capture(tester, 'g_opening_page');
  });

  testWidgets('H workspace after continuing from the opening page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AuthorProfileStore.profilesKey: jsonEncode([
        profileJson(id: 'a', displayName: 'Alexandra', email: 'a@example.com'),
      ]),
      'author_studio.starter_project': '{"title":"Northstar"}',
      'author_studio.onboarding_complete': true,
    });
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('startup-continue')));
    await tester.pumpAndSettle();
    await capture(tester, 'h1_opening_page_returning');

    await tester.tap(find.text('Open Project').first);
    await tester.pumpAndSettle();
    await capture(tester, 'h2_workspace');
  });

  group('responsive', () {
    for (final entry in const {
      'r1_desktop_1440x900': Size(1440, 900),
      'r2_smaller_1100x720': Size(1100, 720),
      'r3_narrow_620x780': Size(620, 780),
    }.entries) {
      testWidgets('login at ${entry.key}', (tester) async {
        SharedPreferences.setMockInitialValues({
          AuthorProfileStore.profilesKey: jsonEncode([
            profileJson(
              id: 'a',
              displayName: 'Alexandra',
              penName: 'Lead Author',
              email: 'alexandra@example.com',
              lastActiveAt: '2026-08-21T09:00:00.000',
            ),
          ]),
        });
        await pumpApp(tester, size: entry.value);
        await capture(tester, entry.key);
      });

      testWidgets('create profile at ${entry.key}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        await pumpApp(tester, size: entry.value);
        await tester.tap(find.byKey(const Key('startup-add-user')));
        await tester.pumpAndSettle();
        await capture(tester, '${entry.key}_create');
      });
    }
  });
}
