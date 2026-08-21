import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:author_studio_v1/research_studio_view.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const projectId = 'project-research-view';
const otherProjectId = 'project-research-other';
final timestamp = DateTime.utc(2026, 8, 21, 9);

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

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ResearchService research;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    research = ResearchService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> seed(
    String id,
    String title, {
    String kind = 'Note',
    String category = 'Other',
    String status = 'New',
    bool important = false,
    String summary = '',
    String notes = '',
    List<String> tags = const [],
    ResearchService? service,
    int minute = 0,
  }) =>
      (service ?? research).createResearch(
        ResearchDraft(
          id: id,
          title: title,
          kind: kind,
          category: category,
          status: status,
          important: important,
          summary: summary,
          notes: notes,
          tags: tags,
        ),
        timestamp: timestamp.add(Duration(minutes: minute)),
      );

  Future<void> pumpStudio(
    WidgetTester tester, {
    DriftConnectedDomainRepository? repositoryOverride,
    String scopedProjectId = projectId,
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ResearchStudioView(
            project: testProject,
            service: ResearchService(
              projectId: scopedProjectId,
              repository: repositoryOverride ?? repository,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Research Studio widget', () {
    testWidgets('an empty library explains itself and creates a first entry',
        (tester) async {
      await pumpStudio(tester);

      expect(find.byKey(const Key('research-studio')), findsOneWidget);
      expect(find.byKey(const Key('research-empty-state')), findsOneWidget);
      expect(find.text('Your research library is empty.'), findsOneWidget);
      expect(
        find.text(
          'Create your first research entry to start building your '
          'knowledge base.',
        ),
        findsOneWidget,
      );

      await tapKey(tester, const Key('research-empty-create-button'));
      await tester.enterText(
        find.byKey(const Key('research-editor-title')),
        'Siege engines',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('research-editor-save'));

      expect(find.byKey(const Key('research-empty-state')), findsNothing);
      expect(find.byKey(const Key('research-entry-research-1')), findsOneWidget);

      // It landed in the canonical repository, not in Studio state.
      final stored = await repository.recordById('research-1');
      expect(stored, isNotNull);
      expect(stored!.title, 'Siege engines');
      expect(stored.projectId, projectId);
    });

    testWidgets('research records render with their canonical fields',
        (tester) async {
      await seed(
        'r-1',
        'Medieval siege warfare',
        kind: 'Source',
        category: 'History',
        status: 'Reviewed',
        summary: 'How walls fell.',
        tags: const ['siege'],
      );
      await pumpStudio(tester);

      expect(find.byKey(const Key('research-entry-r-1')), findsOneWidget);
      expect(find.text('Medieval siege warfare'), findsOneWidget);
      expect(find.text('Source'), findsWidgets);
      expect(find.text('History'), findsWidgets);
      expect(find.text('Reviewed'), findsWidgets);
      expect(find.text('#siege'), findsOneWidget);
      expect(find.text('How walls fell.'), findsOneWidget);
    });

    testWidgets('the library rail lists shelves and live categories',
        (tester) async {
      await seed('r-1', 'Siege engines', kind: 'Source', category: 'History');
      await seed('r-2', 'Harvest rites', kind: 'Note', category: 'Culture');
      await pumpStudio(tester);

      expect(find.byKey(const Key('research-library-rail')), findsOneWidget);
      for (final shelf in ResearchShelf.values) {
        expect(
          find.byKey(Key('research-shelf-${shelf.name}')),
          findsOneWidget,
          reason: 'shelf ${shelf.name} is missing',
        );
      }
      expect(find.byKey(const Key('research-category-History')), findsOneWidget);
      expect(find.byKey(const Key('research-category-Culture')), findsOneWidget);
      // Categories with no entries stay out of the rail.
      expect(find.byKey(const Key('research-category-Politics')), findsNothing);
    });

    testWidgets('search filters the library and is case-insensitive',
        (tester) async {
      await seed('r-hit', 'Medieval siege warfare', minute: 1);
      await seed('r-miss', 'Harvest festivals', minute: 2);
      await pumpStudio(tester);

      await tester.enterText(
        find.byKey(const Key('research-search-field')),
        'SIEGE',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('research-entry-r-hit')), findsOneWidget);
      expect(find.byKey(const Key('research-entry-r-miss')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('research-search-field')),
        'nothing whatsoever',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('research-empty-state')), findsOneWidget);
      expect(find.text('No research matches your search.'), findsOneWidget);
    });

    testWidgets('shelf and category filters narrow the list', (tester) async {
      await seed(
        'r-source',
        'Siege engines',
        kind: 'Source',
        category: 'History',
        minute: 1,
      );
      await seed(
        'r-note',
        'Harvest rites',
        kind: 'Note',
        category: 'Culture',
        minute: 2,
      );
      await pumpStudio(tester);

      await tapKey(tester, const Key('research-shelf-sources'));
      expect(find.byKey(const Key('research-entry-r-source')), findsOneWidget);
      expect(find.byKey(const Key('research-entry-r-note')), findsNothing);

      await tapKey(tester, const Key('research-shelf-all'));
      await tapKey(tester, const Key('research-category-Culture'));
      expect(find.byKey(const Key('research-entry-r-note')), findsOneWidget);
      expect(find.byKey(const Key('research-entry-r-source')), findsNothing);

      // A category with no entries on the current shelf explains itself.
      await tapKey(tester, const Key('research-shelf-sources'));
      expect(find.byKey(const Key('research-empty-state')), findsOneWidget);
      expect(
        find.text('No research in this category yet.'),
        findsOneWidget,
      );
    });

    testWidgets('the tag filter narrows the list and yields when its tag goes',
        (tester) async {
      await seed('r-tagged', 'Siege engines', tags: const ['war'], minute: 1);
      await seed('r-plain', 'Harvest rites', minute: 2);
      await pumpStudio(tester);

      await tester.tap(find.byKey(const Key('research-tag-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('war').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('research-entry-r-tagged')), findsOneWidget);
      expect(find.byKey(const Key('research-entry-r-plain')), findsNothing);

      // Editing the tag off the last record carrying it must not leave the
      // list filtered by a tag the dropdown no longer shows.
      await tapKey(tester, const Key('research-entry-r-tagged'));
      await tapKey(tester, const Key('research-detail-edit'));
      await tester.enterText(
        find.byKey(const Key('research-editor-tags')),
        '',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('research-editor-save'));

      expect(find.byKey(const Key('research-entry-r-tagged')), findsOneWidget);
      expect(find.byKey(const Key('research-entry-r-plain')), findsOneWidget);
    });

    testWidgets('the Important shelf follows the canonical field',
        (tester) async {
      await seed('r-plain', 'Rope making', minute: 1);
      await pumpStudio(tester);

      await tapKey(tester, const Key('research-shelf-important'));
      expect(find.byKey(const Key('research-empty-state')), findsOneWidget);

      await tapKey(tester, const Key('research-shelf-all'));
      await tapKey(tester, const Key('research-important-r-plain'));
      await tapKey(tester, const Key('research-shelf-important'));
      expect(find.byKey(const Key('research-entry-r-plain')), findsOneWidget);

      final stored = await repository.recordById('r-plain');
      expect(stored!.fields['researchImportant'], isTrue);
    });

    testWidgets('sorting reorders the visible list', (tester) async {
      await seed('r-alpha', 'Alchemy primers', minute: 1);
      await seed('r-zephyr', 'Zephyr charts', minute: 5);
      await pumpStudio(tester);

      // Recently updated puts the newest first.
      expect(
        tester
            .getTopLeft(find.byKey(const Key('research-entry-r-zephyr')))
            .dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('research-entry-r-alpha'))).dy,
        ),
      );

      await tester.tap(find.byKey(const Key('research-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alphabetical').last);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('research-entry-r-alpha'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const Key('research-entry-r-zephyr')))
              .dy,
        ),
      );
    });

    testWidgets('the detail view opens and shows the record', (tester) async {
      await seed(
        'r-detail',
        'Medieval siege warfare',
        kind: 'Source',
        category: 'History',
        summary: 'How walls fell.',
        notes: 'Trebuchets outranged mangonels.',
        tags: const ['siege'],
      );
      await pumpStudio(tester);

      expect(find.byKey(const Key('research-detail-pane')), findsNothing);
      await tapKey(tester, const Key('research-entry-r-detail'));

      expect(find.byKey(const Key('research-detail-pane')), findsOneWidget);
      expect(find.text('How walls fell.'), findsWidgets);
      expect(find.text('Trebuchets outranged mangonels.'), findsOneWidget);
      expect(
        find.byKey(const Key('research-detail-no-connections')),
        findsOneWidget,
      );

      await tapKey(tester, const Key('research-detail-close'));
      expect(find.byKey(const Key('research-detail-pane')), findsNothing);
    });

    testWidgets('editing from the detail view preserves untouched fields',
        (tester) async {
      await seed(
        'r-edit',
        'Star charts',
        category: 'Science',
        summary: 'Navigation.',
        tags: const ['stars'],
      );
      // A field this Studio does not edit, written by another surface.
      final existing = (await research.getResearch('r-edit'))!;
      await research.records.updateRecord(
        existing.copyWith(
          fields: {...existing.fields, 'knowledgeStatus': 'Confirmed'},
          updatedAt: timestamp.add(const Duration(minutes: 1)),
        ),
      );

      await pumpStudio(tester);
      await tapKey(tester, const Key('research-entry-r-edit'));
      await tapKey(tester, const Key('research-detail-edit'));

      await tester.enterText(
        find.byKey(const Key('research-editor-title')),
        'Star charts of the north',
      );
      await tester.pumpAndSettle();
      await tapKey(tester, const Key('research-editor-save'));

      expect(find.text('Star charts of the north'), findsWidgets);
      final stored = await repository.recordById('r-edit');
      expect(stored!.title, 'Star charts of the north');
      expect(stored.fields['summary'], 'Navigation.');
      expect(stored.fields['researchCategory'], 'Science');
      expect(stored.fields['knowledgeStatus'], 'Confirmed');
      expect(stored.tags, ['stars']);
    });

    testWidgets('the detail view lists connections made by the shared engine',
        (tester) async {
      await seed('r-connected', 'Siege engines');
      await research.records.createRecord(
        AuthorRecord(
          id: 'character-mara',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: projectId,
          projectId: projectId,
          title: 'Mara',
          fields: const {'name': 'Mara', 'identity.fullName': 'Mara'},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      await research.connect(
        sourceId: 'r-connected',
        targetId: 'character-mara',
        typeId: 'documents',
        timestamp: timestamp,
      );

      await pumpStudio(tester);
      await tapKey(tester, const Key('research-entry-r-connected'));

      expect(
        find.byKey(const Key('research-detail-no-connections')),
        findsNothing,
      );
      expect(find.textContaining('documents → Mara'), findsOneWidget);
    });

    testWidgets('archiving is the record lifecycle, not a research field',
        (tester) async {
      await seed('r-archive', 'Guild ledgers');
      await pumpStudio(tester);
      await tapKey(tester, const Key('research-entry-r-archive'));
      await tapKey(tester, const Key('research-detail-archive'));

      final stored = await repository.recordById('r-archive');
      expect(stored!.status, AuthorRecordStatus.archived);
      expect(stored.fields['researchStatus'], 'New');
      expect(find.text('Archived'), findsWidgets);
    });

    testWidgets('deleting removes the entry from the library', (tester) async {
      await seed('r-delete', 'Rope making');
      await pumpStudio(tester);
      await tapKey(tester, const Key('research-entry-r-delete'));
      await tapKey(tester, const Key('research-detail-delete'));
      await tapKey(tester, const Key('research-delete-confirm'));

      expect(find.byKey(const Key('research-entry-r-delete')), findsNothing);
      expect(find.byKey(const Key('research-empty-state')), findsOneWidget);
    });

    testWidgets('a failing repository surfaces the error state and retry',
        (tester) async {
      final failing = _FailingRepository(database);
      await pumpStudio(tester, repositoryOverride: failing);

      expect(find.byKey(const Key('research-error-state')), findsOneWidget);
      failing.failing = false;
      await tapKey(tester, const Key('research-retry-button'));
      expect(find.byKey(const Key('research-error-state')), findsNothing);
      expect(find.byKey(const Key('research-empty-state')), findsOneWidget);
    });

    testWidgets('the studio stays usable at the supported desktop sizes',
        (tester) async {
      await seed('r-one', 'Siege engines', minute: 1);
      await seed('r-two', 'Harvest rites', minute: 2);
      for (final size in const [
        Size(1280, 720),
        Size(1440, 900),
        Size(1920, 1080),
      ]) {
        await pumpStudio(tester, size: size);
        await tapKey(tester, const Key('research-entry-r-one'));
        expect(find.byKey(const Key('research-detail-pane')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Project isolation in the Studio', () {
    testWidgets('opening a project shows only that project\'s research',
        (tester) async {
      final other = ResearchService(
        projectId: otherProjectId,
        repository: repository,
      );
      await seed('research-a', 'Research A', minute: 1);
      await seed('research-b', 'Research B', service: other, minute: 1);

      await pumpStudio(tester);
      expect(find.byKey(const Key('research-entry-research-a')),
          findsOneWidget);
      expect(find.byKey(const Key('research-entry-research-b')), findsNothing);
      expect(find.text('Research B'), findsNothing);

      await pumpStudio(tester, scopedProjectId: otherProjectId);
      expect(find.byKey(const Key('research-entry-research-b')),
          findsOneWidget);
      expect(find.byKey(const Key('research-entry-research-a')), findsNothing);
      expect(find.text('Research A'), findsNothing);
    });
  });

  group('Theme Engine', () {
    testWidgets('the studio applies its own Studio theme scope',
        (tester) async {
      await seed('r-theme', 'A Lit Beacon');
      final resolved = ThemeEngine.standard(store: MemoryThemeSettingsStore())
          .resolveSelection(
        selection: const ThemeSelection(
          themeId: 'light',
          mode: AuthorOsThemeMode.light,
          accessibility: ThemeAccessibility.none,
        ),
        hostBrightness: ThemeBrightness.light,
      );
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: AuthorOsTheme.toThemeData(resolved),
        home: StudioThemeScope(
          theme: resolved,
          studio: StudioId.shell,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ResearchStudioView(
                project: testProject,
                service: ResearchService(
                  projectId: projectId,
                  repository: repository,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // The Studio nests a research-scoped theme scope inside the shell's.
      final scopes = tester
          .widgetList<StudioThemeScope>(find.byType(StudioThemeScope))
          .toList();
      expect(
        scopes.map((scope) => scope.studio),
        containsAll(<StudioId?>[StudioId.shell, StudioId.research]),
      );

      // Its surfaces come from the engine's research palette.
      final rail = tester.widget<Container>(
        find.byKey(const Key('research-library-rail')),
      );
      final decoration = rail.decoration! as BoxDecoration;
      expect(
        decoration.color,
        AuthorOsTheme.color(
          resolved.colorFor(StudioId.research, ThemeColorRef.surfaceContainer),
        ),
      );
    });
  });

  group('Sidebar navigation', () {
    testWidgets('the Research chip opens the real Research Studio',
        (tester) async {
      final project = NovelStarterKit.create(
        title: 'Northstar',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 90000,
      );
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: AuthorStudioShell(
          project: project,
          themeId: 'paper',
          accentId: 'default',
          onThemeChanged: (_, __) {},
          initialSection: StudioSection.dashboard,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      final tile = find.widgetWithText(InkWell, 'Research');
      await tester.ensureVisible(tile.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(tile.first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(ResearchStudioView), findsOneWidget);
      expect(find.text('Research Studio'), findsWidgets);
    });
  });
}

/// Fails every read until [failing] is cleared, so the Studio's error and
/// retry paths run against the real service stack.
class _FailingRepository extends DriftConnectedDomainRepository {
  _FailingRepository(super.database);

  bool failing = true;

  @override
  Future<List<RecordTypeDefinition>> recordTypeDefinitionsByScope({
    required RecordScopeType scopeType,
    required String scopeId,
  }) {
    if (failing) throw StateError('storage offline');
    return super.recordTypeDefinitionsByScope(
      scopeType: scopeType,
      scopeId: scopeId,
    );
  }
}
