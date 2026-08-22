import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:author_studio_v1/research_studio_view.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget coverage for the capabilities layered onto Research Studio: the
/// dashboard band, the unresolved shelf, structured sources, connections, and
/// saved views — plus the shell round trip back out of the Studio.
const projectId = 'project-research-ext-view';
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
    String citation = '',
    List<String> tags = const [],
    int minute = 0,
  }) =>
      research.createResearch(
        ResearchDraft(
          id: id,
          title: title,
          kind: kind,
          category: category,
          status: status,
          citation: citation,
          tags: tags,
        ),
        timestamp: timestamp.add(Duration(minutes: minute)),
      );

  Future<void> pumpStudio(
    WidgetTester tester, {
    Size size = const Size(1440, 1200),
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
            service: research,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('Dashboard band', () {
    testWidgets('an empty library still renders the dashboard',
        (tester) async {
      await pumpStudio(tester);

      expect(find.byKey(const Key('research-dashboard')), findsOneWidget);
      expect(find.byKey(const Key('research-metric-items')), findsOneWidget);
    });

    testWidgets('metrics reflect the stored records', (tester) async {
      await seed('r1', 'Roman roads', kind: 'Source', category: 'History');
      await seed('r2', 'Field notes', kind: 'Note', category: 'History');
      await seed('r3', 'Style guide', kind: 'Reference');

      await pumpStudio(tester);

      final items = tester.widget<Container>(
        find.byKey(const Key('research-metric-items')),
      );
      expect(items, isNotNull);
      // The band renders the count text next to its label.
      expect(
        find.descendant(
          of: find.byKey(const Key('research-metric-items')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('research-metric-sources')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the unresolved metric filters the library when tapped',
        (tester) async {
      await seed('r1', 'Needs work', status: 'New');
      await seed('r2', 'Finished', status: 'Verified');

      await pumpStudio(tester);
      expect(find.text('Finished'), findsWidgets);

      await tester.tap(find.byKey(const Key('research-metric-unresolved')));
      await tester.pumpAndSettle();

      expect(find.text('Needs work'), findsWidgets);
      expect(find.text('Finished'), findsNothing);
    });

    testWidgets('the dashboard updates after an entry is archived',
        (tester) async {
      await seed('r1', 'Roman roads');
      await pumpStudio(tester);

      await tester.tap(find.text('Roman roads').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('research-detail-archive')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('research-metric-archived')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Unresolved shelf', () {
    testWidgets('the rail offers an Unresolved shelf that narrows the list',
        (tester) async {
      await seed('r1', 'Needs work', status: 'New');
      await seed('r2', 'Finished', status: 'Verified');

      await pumpStudio(tester);

      await tester.tap(find.text('Unresolved').first);
      await tester.pumpAndSettle();

      expect(find.text('Needs work'), findsWidgets);
      expect(find.text('Finished'), findsNothing);
    });
  });

  group('Structured sources', () {
    testWidgets('an entry with no sources says so', (tester) async {
      await seed('r1', 'Roman roads', kind: 'Source');
      await pumpStudio(tester);

      await tester.tap(find.text('Roman roads').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('research-detail-no-sources')),
        findsOneWidget,
      );
    });

    testWidgets('a source is added through the detail pane and persists',
        (tester) async {
      await seed('r1', 'Roman roads', kind: 'Source');
      await pumpStudio(tester);

      await tester.tap(find.text('Roman roads').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('research-add-source')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('research-source-label')),
        'Gibbon',
      );
      await tester.enterText(
        find.byKey(const Key('research-source-location')),
        'ch. 4',
      );
      await tester.tap(find.byKey(const Key('research-source-confirm')));
      await tester.pumpAndSettle();

      // Visible in the pane...
      expect(find.textContaining('Gibbon'), findsWidgets);
      // ...and written to the canonical record.
      final stored = await research.getResearch('r1');
      expect(ResearchService.sourcesOf(stored!).single.label, 'Gibbon');
    });

    testWidgets('a source is removed again', (tester) async {
      await seed('r1', 'Roman roads', kind: 'Source');
      await research.addSource(
        'r1',
        const CodexSourceReference(
          recordId: '',
          kind: 'external',
          label: 'Gibbon',
        ),
      );
      await pumpStudio(tester);

      await tester.tap(find.text('Roman roads').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove source').first);
      await tester.pumpAndSettle();

      final stored = await research.getResearch('r1');
      expect(ResearchService.sourcesOf(stored!), isEmpty);
    });
  });

  group('Connections', () {
    testWidgets('a connection is created through the detail pane',
        (tester) async {
      await seed('r1', 'Roman roads');
      await seed('r2', 'Ship designs');
      await pumpStudio(tester);

      await tester.tap(find.text('Roman roads').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('research-add-connection')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('research-connect-confirm')));
      await tester.pumpAndSettle();

      final connections = await research.connectedRecords('r1');
      expect(connections.map((view) => view.record.id), ['r2']);
    });

    testWidgets('connecting is refused when nothing else exists',
        (tester) async {
      await seed('r1', 'Roman roads');
      await pumpStudio(tester);

      await tester.tap(find.text('Roman roads').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('research-add-connection')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nothing else in this project'),
        findsOneWidget,
      );
    });

    testWidgets('a connection is removed from the pane', (tester) async {
      await seed('r1', 'Roman roads');
      await seed('r2', 'Ship designs');
      await research.connect(
        sourceId: 'r1',
        targetId: 'r2',
        typeId: 'documents',
      );
      await pumpStudio(tester);

      await tester.tap(find.text('Roman roads').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove connection').first);
      await tester.pumpAndSettle();

      expect(await research.connectedRecords('r1'), isEmpty);
    });
  });

  group('Saved views', () {
    testWidgets('the bar reports when nothing is saved', (tester) async {
      await pumpStudio(tester);

      expect(find.byKey(const Key('research-saved-views')), findsOneWidget);
      expect(find.text('None yet'), findsOneWidget);
    });

    testWidgets('the current filter is saved and restored', (tester) async {
      await seed('r1', 'Needs work', status: 'New');
      await seed('r2', 'Finished', status: 'Verified');
      await pumpStudio(tester);

      // Narrow to unresolved, then save that as a view.
      await tester.tap(find.text('Unresolved').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('research-save-view')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('research-save-view-name')),
        'Open questions',
      );
      await tester.tap(find.byKey(const Key('research-save-view-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Open questions'), findsWidgets);

      // Widen back to everything, then re-apply the saved view.
      await tester.tap(find.text('All research').first);
      await tester.pumpAndSettle();
      expect(find.text('Finished'), findsWidgets);

      await tester.tap(find.text('Open questions').first);
      await tester.pumpAndSettle();

      expect(find.text('Needs work'), findsWidgets);
      expect(find.text('Finished'), findsNothing);
    });

    testWidgets('a saved view is deleted from the bar', (tester) async {
      await research.saveView(
        id: 'research-view-open',
        name: 'Open questions',
        filter: const ResearchViewFilter(shelf: ResearchShelf.unresolved),
      );
      await pumpStudio(tester);

      expect(find.text('Open questions'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(await research.savedViews(), isEmpty);
    });
  });

  group('Shell navigation', () {
    testWidgets('Dashboard -> Research -> Dashboard returns to the dashboard',
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

      // Into Research.
      final researchTile = find.widgetWithText(InkWell, 'Research');
      await tester.ensureVisible(researchTile.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(researchTile.first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.byType(ResearchStudioView), findsOneWidget);

      // ...and back out again. Returning is the half a one-way test misses.
      final dashboardTile = find.widgetWithText(InkWell, 'Dashboard');
      await tester.ensureVisible(dashboardTile.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(dashboardTile.first);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(ResearchStudioView), findsNothing);
    });

    testWidgets('Settings stays reachable beside the Research entry',
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

      expect(find.text('Research'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
    });
  });
}
