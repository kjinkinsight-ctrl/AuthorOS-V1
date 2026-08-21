import 'dart:io';

import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:author_studio_v1/research_studio_view.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/resolved_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_registry.dart';
import 'package:author_studio_v1/theme/theme_resolver.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const projectId = 'project-research-ui';
final timestamp = DateTime.utc(2026, 5, 4, 9);

/// The light theme, optionally carrying Research Studio overrides.
ResolvedTheme resolvedTheme({
  Map<ThemeColorRef, ThemeColor> researchOverrides = const {},
  ThemeBrightness brightness = ThemeBrightness.light,
  AuthorOsThemeMode mode = AuthorOsThemeMode.light,
  ThemeAccessibility accessibility = ThemeAccessibility.none,
  String themeId = 'light',
}) {
  final base = ThemeRegistry.standard().byId(themeId);
  final definition = ThemeDefinition(
    id: base.id,
    name: base.name,
    description: base.description,
    palettes: base.palettes,
    typography: base.typography,
    metrics: base.metrics,
    studioOverrides: {
      ...base.studioOverrides,
      if (researchOverrides.isNotEmpty) StudioId.research: researchOverrides,
    },
  );
  return const ThemeResolver().resolve(
    definition: definition,
    mode: mode,
    hostBrightness: brightness,
    accessibility: accessibility,
  );
}

StarterProject project() => const StarterProject(
      id: projectId,
      title: 'Northstar',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 80000,
      acts: [],
      chapters: [],
      characterSheets: [],
      beatChecklist: [],
      firstSceneTitle: 'Opening',
    );

Future<void> pumpStudio(
  WidgetTester tester, {
  required ResearchService service,
  ResolvedTheme? theme,
  List<ResearchNavigationRequest>? navigations,
  Size surfaceSize = const Size(1400, 1800),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final resolved = theme ?? resolvedTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: AuthorOsTheme.toThemeData(resolved),
      home: Scaffold(
        body: StudioThemeScope(
          theme: resolved,
          studio: StudioId.shell,
          child: SingleChildScrollView(
            child: ResearchStudioView(
              project: project(),
              service: service,
              onNavigate: navigations?.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ResearchService service;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    service = ResearchService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<CodexEntry> seedTide() => service.createResearch(
        const ResearchDraft(
          id: 'research-tide',
          title: 'Tidal lock records',
          summary: 'Harbour tide tables for the siege chapters.',
          details: 'Two tides a day, four hours out of phase.',
          notes: 'Cross-check the winter schedule.',
          tagIds: ['harbour'],
        ),
        timestamp: timestamp,
      );

  Future<CodexEntry> seedCharts() => service.createResearch(
        const ResearchDraft(
          id: 'research-charts',
          title: 'Depth sounding notes',
          typeId: 'reference',
          categoryId: 'reference',
          summary: 'Soundings around the northern cliffs.',
          tagIds: ['charts'],
          canonStatus: CodexCanonStatus.canon,
          knowledgeStatus: CodexKnowledgeStatus.confirmed,
          sources: [
            CodexSourceReference(
              id: 'source-chart',
              recordId: '',
              kind: 'external',
              label: 'Admiralty Chart 118',
              location: 'https://example.invalid/chart-118',
            ),
          ],
        ),
        timestamp: timestamp,
      );

  Future<void> seedLocation() async {
    final codex =
        StoryCodexService(projectId: projectId, repository: repository);
    await codex.createCodexEntry(
      const CodexEntryDraft(
        id: 'loc-cliffs',
        title: 'Northern cliffs',
        templateId: 'location',
        categoryId: 'locations',
      ),
      timestamp: timestamp,
    );
  }

  // -------------------------------------------------------------------------
  // Rendering
  // -------------------------------------------------------------------------

  group('rendering', () {
    testWidgets('renders the dashboard and an empty library', (tester) async {
      await pumpStudio(tester, service: service);

      expect(find.byKey(const ValueKey('research-studio')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-dashboard')), findsOneWidget);
      expect(find.text('Research Studio'), findsOneWidget);

      expect(find.byKey(const ValueKey('research-empty-state')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-detail-empty-state')),
          findsOneWidget);

      for (final key in const [
        'research-metric-items',
        'research-metric-sources',
        'research-metric-categories',
        'research-metric-tags',
        'research-metric-unresolved',
        'research-metric-connected',
        'research-metric-archived',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(find.byKey(const ValueKey('research-recent-panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-unresolved-panel')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-sources-panel')), findsOneWidget);
    });

    testWidgets('renders a populated library and dashboard counts',
        (tester) async {
      await seedTide();
      await seedCharts();
      await pumpStudio(tester, service: service);

      expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-item-tile-research-charts')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-empty-state')), findsNothing);

      expect(metricValue(tester, 'research-metric-items'), '2');
      expect(metricValue(tester, 'research-metric-sources'), '1');
      expect(metricValue(tester, 'research-metric-categories'), '2');
      expect(metricValue(tester, 'research-metric-tags'), '2');
      // Only the chart entry is verified and sourced.
      expect(metricValue(tester, 'research-metric-unresolved'), '1');

      expect(find.byKey(const ValueKey('research-recent-research-tide')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-unresolved-research-tide')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-source-source-chart')),
          findsOneWidget);
    });

    testWidgets('shows every stored field of the selected research item',
        (tester) async {
      await seedTide();
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));

      expect(find.byKey(const ValueKey('research-detail-pane')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('research-detail-title')))
            .data,
        'Tidal lock records',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('research-detail-summary')))
            .data,
        'Harbour tide tables for the siege chapters.',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('research-detail-details')))
            .data,
        'Two tides a day, four hours out of phase.',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('research-detail-notes')))
            .data,
        'Cross-check the winter schedule.',
      );
      expect(find.byKey(const ValueKey('research-detail-type')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('research-detail-category')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-detail-canon')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-detail-knowledge')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-detail-lifecycle')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('research-detail-project')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-detail-tag-harbour')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('research-sources-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-connections-empty')),
          findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Create and edit
  // -------------------------------------------------------------------------

  group('create and edit', () {
    testWidgets('creates research through the service', (tester) async {
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-new-button'));
      expect(
          find.byKey(const ValueKey('research-editor-dialog')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('research-editor-title')),
        'Lighthouse rotation',
      );
      await tester.enterText(
        find.byKey(const ValueKey('research-editor-summary')),
        'Four-hour watches, two keepers.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('research-editor-notes')),
        'Confirm the winter schedule.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('research-editor-tags')),
        'harbour, lights',
      );
      await tapKey(tester, const ValueKey('research-editor-save'));

      final stored = await service.listResearch();
      expect(stored, hasLength(1));
      expect(stored.single.title, 'Lighthouse rotation');
      expect(stored.single.summary, 'Four-hour watches, two keepers.');
      expect(
          stored.single.structuredFields['notes'], 'Confirm the winter schedule.');
      expect(stored.single.tagIds, containsAll(['harbour', 'lights']));
      expect(stored.single.record.typeId, ResearchRecordTypes.entryTypeId);

      expect(
        find.byKey(ValueKey('research-item-tile-${stored.single.id}')),
        findsOneWidget,
      );
      expect(metricValue(tester, 'research-metric-items'), '1');
    });

    testWidgets('a blank title is refused with an explanation', (tester) async {
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-new-button'));
      await tapKey(tester, const ValueKey('research-editor-save'));

      expect(find.byKey(const ValueKey('research-editor-error')), findsOneWidget);
      expect(await service.listResearch(), isEmpty);
    });

    testWidgets('edits an existing item and saves it back', (tester) async {
      await seedTide();
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));
      await tapKey(tester, const ValueKey('research-edit-button'));

      await tester.enterText(
        find.byKey(const ValueKey('research-editor-title')),
        'Tide tables, revised',
      );
      await tester.enterText(
        find.byKey(const ValueKey('research-editor-summary')),
        'Revised summary.',
      );
      await tapKey(tester, const ValueKey('research-editor-save'));

      final stored = await service.getResearch('research-tide');
      expect(stored!.title, 'Tide tables, revised');
      expect(stored.summary, 'Revised summary.');
      expect(find.text('Tide tables, revised'), findsWidgets);
    });
  });

  // -------------------------------------------------------------------------
  // Search and filter
  // -------------------------------------------------------------------------

  group('search and filter', () {
    testWidgets('search narrows the library to stored matches',
        (tester) async {
      await seedTide();
      await seedCharts();
      await pumpStudio(tester, service: service);

      await tester.enterText(
        find.byKey(const ValueKey('research-search-field')),
        'Soundings',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('research-item-tile-research-charts')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
          findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('research-search-field')),
        'nothing-matches-this',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('research-empty-state')), findsOneWidget);
    });

    testWidgets('the unresolved filter keeps only open questions',
        (tester) async {
      await seedTide();
      await seedCharts();
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-unresolved-toggle'));

      expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-item-tile-research-charts')),
          findsNothing);
    });

    testWidgets('a tag facet survives its last item being archived',
        (tester) async {
      await seedTide();
      await seedCharts();
      await pumpStudio(tester, service: service);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('research-tag-filter')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('harbour').last);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-item-tile-research-charts')),
          findsNothing);

      // Archiving the only item carrying the tag removes it from the facet
      // list; the still-selected value must not break the dropdown.
      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));
      await tapKey(tester, const ValueKey('research-archive-button'));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('research-studio')), findsOneWidget);
      expect(find.byKey(const ValueKey('research-empty-state')), findsOneWidget);
    });

    testWidgets('the connected filter keeps research linked to the project',
        (tester) async {
      await seedTide();
      await seedCharts();
      await seedLocation();
      await service.connectResearch(
        researchId: 'research-charts',
        targetId: 'loc-cliffs',
        typeId: 'documents',
        timestamp: timestamp,
      );
      await pumpStudio(tester, service: service);

      expect(metricValue(tester, 'research-metric-connected'), '1');

      await tapKey(tester, const ValueKey('research-connected-toggle'));

      expect(find.byKey(const ValueKey('research-item-tile-research-charts')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
          findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  group('lifecycle', () {
    testWidgets('archives and restores an item from the detail pane',
        (tester) async {
      await seedTide();
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));
      await tapKey(tester, const ValueKey('research-archive-button'));

      expect((await service.getResearch('research-tide'))!.isArchived, isTrue);
      expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
          findsNothing);
      expect(metricValue(tester, 'research-metric-archived'), '1');

      await tapKey(tester, const ValueKey('research-archived-toggle'));
      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));
      await tapKey(tester, const ValueKey('research-restore-button'));

      expect((await service.getResearch('research-tide'))!.isArchived, isFalse);
      expect(metricValue(tester, 'research-metric-archived'), '0');
    });

    testWidgets('deleting asks first and then removes it from the library',
        (tester) async {
      await seedTide();
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));
      await tapKey(tester, const ValueKey('research-delete-button'));

      expect(
          find.byKey(const ValueKey('research-delete-confirm')), findsOneWidget);
      await tapKey(tester, const ValueKey('research-delete-confirm-button'));

      expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
          findsNothing);
      expect(
        (await service.listResearch(includeArchived: true)),
        isEmpty,
      );
      // The record itself is retained by the shared architecture.
      expect(await repository.recordById('research-tide'), isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // Sources and connections
  // -------------------------------------------------------------------------

  group('sources and connections', () {
    testWidgets('adds and removes a source on the selected item',
        (tester) async {
      await seedTide();
      await pumpStudio(tester, service: service);

      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));
      await tapKey(tester, const ValueKey('research-add-source-button'));

      expect(
          find.byKey(const ValueKey('research-source-dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('research-source-label')),
        'Harbourmaster ledger',
      );
      await tester.enterText(
        find.byKey(const ValueKey('research-source-location')),
        'https://example.invalid/ledger',
      );
      await tapKey(tester, const ValueKey('research-source-save'));

      final stored = await service.getResearch('research-tide');
      expect(stored!.sources, hasLength(1));
      final sourceId = stored.sources.single.stableId;
      expect(find.byKey(ValueKey('research-source-row-$sourceId')),
          findsOneWidget);
      expect(metricValue(tester, 'research-metric-sources'), '1');

      await tapKey(tester, ValueKey('research-remove-source-$sourceId'));
      expect((await service.getResearch('research-tide'))!.sources, isEmpty);
    });

    testWidgets('connects research to another record and opens it',
        (tester) async {
      await seedTide();
      await seedLocation();
      final navigations = <ResearchNavigationRequest>[];
      await pumpStudio(tester, service: service, navigations: navigations);

      await tapKey(tester, const ValueKey('research-item-tile-research-tide'));
      await tapKey(tester, const ValueKey('research-connect-button'));

      expect(find.byKey(const ValueKey('research-connection-dialog')),
          findsOneWidget);
      await tapKey(tester, const ValueKey('research-connection-save'));

      final connections = await service.connectionsFor('research-tide');
      expect(connections, hasLength(1));
      final linkId = connections.single.linkId;
      expect(
          find.byKey(ValueKey('research-connection-$linkId')), findsOneWidget);

      await tapKey(tester, ValueKey('research-connection-$linkId'));
      expect(navigations, hasLength(1));
      expect(navigations.single.recordId, 'loc-cliffs');
      expect(navigations.single.recordType, 'location');

      await tapKey(tester, ValueKey('research-disconnect-$linkId'));
      expect(await service.connectionsFor('research-tide'), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Theme
  // -------------------------------------------------------------------------

  group('theme integration', () {
    testWidgets('paints from the resolved palette', (tester) async {
      final theme = resolvedTheme();
      await pumpStudio(tester, service: service, theme: theme);

      final root = tester.widget<Container>(
        find.byKey(const ValueKey('research-studio')),
      );
      expect(
        root.color,
        AuthorOsTheme.color(theme.colorFor(StudioId.research,
            ThemeColorRef.surface)),
      );

      final metric = tester.widget<Container>(
        find.byKey(const ValueKey('research-metric-items')),
      );
      expect(
        (metric.decoration! as BoxDecoration).color,
        AuthorOsTheme.color(
          theme.colorFor(StudioId.research, ThemeColorRef.surfaceContainer),
        ),
      );
    });

    testWidgets('honours the StudioId.research override', (tester) async {
      const overridden = ThemeColor(0xFF2E7D32);
      final theme = resolvedTheme(
        researchOverrides: const {ThemeColorRef.surfaceContainer: overridden},
      );
      await pumpStudio(tester, service: service, theme: theme);

      final metric = tester.widget<Container>(
        find.byKey(const ValueKey('research-metric-items')),
      );
      expect(
        (metric.decoration! as BoxDecoration).color,
        const Color(0xFF2E7D32),
      );
      // The shell palette is untouched by the Studio override.
      expect(
        AuthorOsTheme.color(theme.color(ThemeColorRef.surfaceContainer)),
        isNot(const Color(0xFF2E7D32)),
      );
    });

    testWidgets('renders in light, dark, and system-resolved dark',
        (tester) async {
      await seedTide();

      for (final theme in [
        resolvedTheme(),
        resolvedTheme(
          themeId: 'dark',
          mode: AuthorOsThemeMode.dark,
          brightness: ThemeBrightness.dark,
        ),
        resolvedTheme(
          themeId: 'dark',
          mode: AuthorOsThemeMode.system,
          brightness: ThemeBrightness.dark,
        ),
      ]) {
        await pumpStudio(tester, service: service, theme: theme);
        final root = tester.widget<Container>(
          find.byKey(const ValueKey('research-studio')),
        );
        expect(
          root.color,
          AuthorOsTheme.color(
            theme.colorFor(StudioId.research, ThemeColorRef.surface),
          ),
        );
        expect(find.byKey(const ValueKey('research-item-tile-research-tide')),
            findsOneWidget);
      }
    });

    testWidgets('inherits the engine\'s accessibility transformation',
        (tester) async {
      final plain = resolvedTheme();
      final contrast = resolvedTheme(
        accessibility: const ThemeAccessibility(highContrast: true),
      );
      expect(
        contrast.color(ThemeColorRef.onSurface).value,
        isNot(plain.color(ThemeColorRef.onSurface).value),
      );

      await pumpStudio(tester, service: service, theme: contrast);

      final metric = tester.widget<Container>(
        find.byKey(const ValueKey('research-metric-items')),
      );
      expect(
        (metric.decoration! as BoxDecoration).color,
        AuthorOsTheme.color(
          contrast.colorFor(StudioId.research, ThemeColorRef.surfaceContainer),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Source hygiene
  // -------------------------------------------------------------------------

  group('source hygiene', () {
    final source = File('lib/research_studio_view.dart').readAsStringSync();

    test('reads the Theme Engine instead of owning a theme', () {
      expect(source, contains('StudioThemeScope'));
      expect(source, contains('StudioId.research'));
      expect(source, isNot(contains('ThemeData')));
      expect(source, isNot(contains('Colors.')));
      expect(source, isNot(contains('Color(0x')));
      expect(source, isNot(contains('Theme.of(')));
    });

    test('owns no persistence', () {
      expect(source, contains('ResearchService'));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('AuthorOsDatabase')));
      expect(source, isNot(contains('jsonEncode')));
    });

    test('the domain layer stays free of Flutter', () {
      final domain = File('lib/core/research_domain.dart').readAsStringSync();
      expect(domain, isNot(contains('package:flutter')));
      expect(domain, isNot(contains('Color(')));
    });
  });
}

/// The value rendered inside a dashboard metric tile.
String metricValue(WidgetTester tester, String key) {
  final texts = tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .toList();
  return texts.last.data ?? '';
}
