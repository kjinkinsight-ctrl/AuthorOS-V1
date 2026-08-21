import 'package:author_studio_v1/liquid_aurora_background.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/map_studio_view.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late ManuscriptStore manuscriptStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  StarterProject project() => NovelStarterKit.create(
        title: 'Northstar',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 90000,
      );

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
    final theme = engine.resolveSelection(
      selection: const ThemeSelection(
        themeId: 'light',
        mode: AuthorOsThemeMode.light,
      ),
      hostBrightness: ThemeBrightness.light,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AuthorOsTheme.toThemeData(theme),
        home: StudioThemeScope(
          theme: theme,
          studio: StudioId.shell,
          child: AuthorStudioShell(
            project: project(),
            manuscriptStore: manuscriptStore,
            themeId: 'light',
            accentId: 'default',
            onThemeChanged: (_, __) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('the shell registers Map as a section', () {
    expect(StudioSection.values, contains(StudioSection.map));
  });

  test('Map sits with the story sections, directly after World', () {
    expect(
      StudioSection.values.indexOf(StudioSection.map),
      StudioSection.values.indexOf(StudioSection.world) + 1,
    );
  });

  test('Map carries its own label and navigation icon', () {
    expect(StudioSection.map.label, 'Map');
    expect(StudioSection.map.icon, Icons.map_outlined);
    // It must not wear World Studio's globe.
    expect(StudioSection.map.icon, isNot(StudioSection.world.icon));
  });

  test('the Theme Engine knows Map Studio', () {
    expect(StudioId.map.value, 'map');
    expect(StudioId.map, isNot(StudioId.world));
    expect(StudioId.map, const StudioId('map'));
  });

  testWidgets('the navigation rail offers Map and opens Map Studio',
      (tester) async {
    await pumpShell(tester);

    expect(find.text('Map'), findsOneWidget);
    expect(find.byType(MapStudioView), findsNothing);

    await tester.tap(find.text('Map'));
    // The shell-mounted Studio binds to the application database, so it stays
    // on its loading frame here; the point of this test is that the section
    // resolves to Map Studio at all. Loading, empty and authored states are
    // covered against a fixture database in `map_studio_view_test.dart`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MapStudioView), findsOneWidget);
    expect(find.byKey(const Key('map-studio-title')), findsOneWidget);
    expect(find.text('MAP STUDIO'), findsOneWidget);
  });
}
