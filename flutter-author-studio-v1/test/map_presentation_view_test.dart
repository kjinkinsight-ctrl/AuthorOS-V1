import 'dart:typed_data';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/manuscript_export.dart' show ExportFileSaver;
import 'package:author_studio_v1/map_presentation_service.dart';
import 'package:author_studio_v1/map_service.dart';
import 'package:author_studio_v1/map_studio_view.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Map Studio Phase 6 — presentation and export, driven through the Studio.
const projectId = 'project-map';
final timestamp = DateTime.utc(2026, 8, 22, 9);

const testProject = StarterProject(
  id: projectId,
  title: 'A Crown of Ash',
  genre: 'Fantasy',
  projectType: 'Novel',
  wordGoal: 90000,
  acts: ['Act I'],
  chapters: [StarterChapter(title: 'Chapter 1', prompt: 'Begin')],
  characterSheets: [StarterCharacterSheet(name: 'Mara', role: 'Protagonist')],
  beatChecklist: ['Opening Image'],
  firstSceneTitle: 'The First Bell',
);

/// Keeps whatever an export hands it, so a test can look at the bytes.
class _MemorySaver extends ExportFileSaver {
  String? name;
  String? mimeType;
  Uint8List? bytes;

  @override
  Future<String?> saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
    required List<String> extensions,
    String typeLabel = 'File',
  }) async {
    name = suggestedName;
    this.mimeType = mimeType;
    this.bytes = bytes;
    return '/exports/$suggestedName';
  }
}

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late MapService maps;
  late ConnectionEngine connections;
  late MapPresentationService presentations;
  late _MemorySaver saver;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    maps = MapService(projectId: projectId, repository: repository);
    connections = ConnectionEngine(scopeId: projectId, repository: repository);
    presentations = MapPresentationService(
      projectId: projectId,
      repository: repository,
    );
    saver = _MemorySaver();
  });

  tearDown(() => database.close());

  ResolvedTheme resolvedTheme() {
    final engine = ThemeEngine.standard(store: MemoryThemeSettingsStore());
    return engine.resolveSelection(
      selection: const ThemeSelection(
        themeId: 'light',
        mode: AuthorOsThemeMode.light,
      ),
      hostBrightness: ThemeBrightness.light,
    );
  }

  Future<void> pumpStudio(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = resolvedTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: AuthorOsTheme.toThemeData(theme),
        home: StudioThemeScope(
          theme: theme,
          studio: StudioId.shell,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MapStudioView(
                project: testProject,
                service: maps,
                presentations: presentations,
                fileSaver: saver,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seedMap() => maps.createMap(
        const MapDraft(id: 'map-kingdom', title: 'Kingdom Map'),
        timestamp: timestamp,
      );

  Future<MapLocationView> seedPlace(String id, String name, double x) =>
      maps.createLocation(
        MapLocationDraft(
          id: id,
          mapId: 'map-kingdom',
          name: name,
          locationType: 'City',
          position: MapPosition(x, 300),
        ),
        timestamp: timestamp,
      );

  Future<void> seedManuscript() => repository.putManuscriptNodes([
        ManuscriptNodeReference(
          id: 'chapter-one',
          projectId: projectId,
          nodeType: 'chapter',
          title: 'The Bell',
          createdAt: timestamp,
          updatedAt: timestamp,
          extensionData: const {'order': 1},
        ),
        ManuscriptNodeReference(
          id: 'chapter-nine',
          projectId: projectId,
          nodeType: 'chapter',
          title: 'The Siege',
          createdAt: timestamp,
          updatedAt: timestamp,
          extensionData: const {'order': 9},
        ),
      ]);

  Future<void> press(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('the presentation panel', () {
    testWidgets('offers every theme and decoration', (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      expect(find.byKey(const Key('map-presentation-panel')), findsOneWidget);
      for (final theme in MapPresentationTheme.values) {
        expect(find.byKey(Key('map-theme-${theme.name}')), findsOneWidget);
      }
      for (final decoration in MapDecoration.values) {
        expect(
          find.byKey(Key('map-decoration-${decoration.name}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('choosing a theme changes what the export contains',
        (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      Future<String> exportSvg() async {
        await press(tester, 'map-export-button');
        await press(tester, 'map-export-format-svg');
        await press(tester, 'map-export-run');
        await press(tester, 'map-export-close');
        return String.fromCharCodes(saver.bytes!);
      }

      await press(tester, 'map-theme-classicFantasy');
      final fantasy = await exportSvg();

      await press(tester, 'map-theme-minimal');
      final minimal = await exportSvg();

      expect(fantasy, contains('Kingdom Map'));
      expect(minimal, contains('Kingdom Map'));
      expect(minimal.length, lessThan(fantasy.length),
          reason: 'a minimal map is line and label only — no frame, no '
              'compass, no legend');
    });
  });

  group('presentation mode', () {
    testWidgets('shows the map alone, and comes back', (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      await press(tester, 'map-present-button');
      expect(
        find.byKey(const Key('map-presentation-surface')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('map-editor-toolbar')), findsNothing,
          reason: 'presentation mode is the finished map, not the editor');

      await press(tester, 'map-presentation-close');
      expect(find.byKey(const Key('map-editor-toolbar')), findsOneWidget);
    });

    testWidgets('the map carries a description for a reader who cannot see it',
        (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await seedPlace('city-vey', 'Vey', 600);
      await pumpStudio(tester);

      await press(tester, 'map-present-button');
      final semantics = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.byKey(const Key('map-presentation-surface')),
              matching: find.byType(Semantics),
            )
            .first,
      );

      expect(semantics.properties.label, contains('Kingdom Map'));
      expect(semantics.properties.label, contains('2 places'));
    });
  });

  group('export', () {
    testWidgets('writes a PNG through the saver', (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      await press(tester, 'map-export-button');
      expect(find.byKey(const Key('map-export-dialog')), findsOneWidget);
      await press(tester, 'map-export-format-png');
      // Rasterising goes through the engine, which needs real async: inside the
      // test's fake clock `Picture.toImage` never completes. How long the
      // engine takes is the machine's business, so wait for the saver to be
      // called rather than for a fixed delay — a fixed delay is a race that a
      // cold CI runner loses.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('map-export-run')));
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (saver.name == null && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();

      expect(saver.name, 'kingdom-map.png');
      expect(saver.mimeType, 'image/png');
      expect(saver.bytes, isNotNull);
      expect(saver.bytes!.sublist(1, 4), [0x50, 0x4E, 0x47]);
      expect(find.byKey(const Key('map-export-saved')), findsOneWidget);
    });

    testWidgets('writes an SVG, and says where it went', (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      await press(tester, 'map-export-button');
      await press(tester, 'map-export-format-svg');
      await press(tester, 'map-export-run');

      expect(saver.name, 'kingdom-map.svg');
      expect(String.fromCharCodes(saver.bytes!), contains('<svg'));
      expect(find.textContaining('/exports/kingdom-map.svg'), findsOneWidget);
    });

    testWidgets('reports what the canonical model could not supply',
        (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      await press(tester, 'map-export-button');

      expect(find.byKey(const Key('map-export-gap-Series title')),
          findsOneWidget);
      expect(find.textContaining('no Studio creates'), findsOneWidget);
    });
  });

  group('reader maps', () {
    testWidgets('a spoiler level appears once the manuscript has chapters',
        (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await seedManuscript();
      await pumpStudio(tester);

      expect(find.textContaining('Through The Bell'), findsOneWidget);
      expect(find.textContaining('Through The Siege'), findsOneWidget);
    });

    testWidgets('an unrevealed place never reaches the exported bytes',
        (tester) async {
      await seedMap();
      await seedManuscript();
      await seedPlace('city-aurel', 'Aurel', 200);
      await seedPlace('city-secret', 'The Hidden City', 600);
      await connections.connect(
        sourceId: 'city-aurel',
        targetId: 'chapter-one',
        typeId: 'revealedIn',
        timestamp: timestamp,
      );
      await pumpStudio(tester);

      await tester.tap(
        find.byKey(Key('map-spoiler-${'Through The Bell'.hashCode}')),
      );
      await tester.pumpAndSettle();

      await press(tester, 'map-export-button');
      await press(tester, 'map-export-format-svg');
      await press(tester, 'map-export-run');

      final svg = String.fromCharCodes(saver.bytes!);
      expect(svg, contains('Aurel'));
      expect(svg, isNot(contains('The Hidden City')),
          reason: 'a reader map cannot leak what it was never given');
    });

    testWidgets('the author view still shows everything', (tester) async {
      await seedMap();
      await seedManuscript();
      await seedPlace('city-secret', 'The Hidden City', 600);
      await pumpStudio(tester);

      await press(tester, 'map-export-button');
      await press(tester, 'map-export-format-svg');
      await press(tester, 'map-export-run');

      expect(String.fromCharCodes(saver.bytes!), contains('The Hidden City'));
    });
  });

  group('Phase 6 writes nothing and regresses nothing', () {
    testWidgets('presenting and exporting leave the database untouched',
        (tester) async {
      await seedMap();
      await seedManuscript();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      final before = (await repository.snapshot()).toJson();

      await press(tester, 'map-theme-historical');
      await press(tester, 'map-decoration-compass');
      await press(tester, 'map-present-button');
      await press(tester, 'map-presentation-close');
      await press(tester, 'map-export-button');
      await press(tester, 'map-export-format-pdf');
      await press(tester, 'map-export-run');
      await press(tester, 'map-export-close');

      expect((await repository.snapshot()).toJson(), before,
          reason: 'presentation and export are projections, never writes');
    });

    testWidgets('the Phase 1–5 Studio still works underneath', (tester) async {
      await seedMap();
      await seedPlace('city-aurel', 'Aurel', 200);
      await pumpStudio(tester);

      await press(tester, 'map-location-city-aurel');
      expect(find.byKey(const Key('map-detail')), findsOneWidget);

      await press(tester, 'map-tool-terrain');
      expect(find.byKey(const Key('map-terrain-tools')), findsOneWidget);

      expect(find.byKey(const Key('map-overlay-panel')), findsOneWidget);
      expect(find.byKey(const Key('map-world-panel')), findsOneWidget);
    });
  });
}
