import 'dart:io';

import 'package:author_studio_v1/core/starter_project.dart';
import 'package:author_studio_v1/core/writing_series.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/project_roster_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

StarterProject _project(String id, {String? title, int wordGoal = 80000}) =>
    StarterProject(
      id: id,
      title: title ?? id,
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: wordGoal,
      acts: const [],
      chapters: const [],
      characterSheets: const [],
      beatChecklist: const [],
      firstSceneTitle: 'Opening Scene',
    );

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ManuscriptStore manuscriptStore;
  late ProjectRosterStore roster;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    manuscriptStore = ManuscriptStore(repository: repository);
    roster = ProjectRosterStore(repository: repository);
  });

  tearDown(() => database.close());

  /// Pumps the shell straight into the Projects Studio.
  Future<StarterProject?> pumpProjects(
    WidgetTester tester, {
    required StarterProject active,
  }) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    StarterProject? switched;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthorStudioShell(
          project: active,
          manuscriptStore: manuscriptStore,
          rosterStore: roster,
          themeId: 'light',
          accentId: 'default',
          onThemeChanged: (_, __) {},
          initialSection: StudioSection.projects,
          onProjectChanged: (project) => switched = project,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return switched;
  }

  group('the roster is real', () {
    testWidgets('projects render from storage, not from fixtures',
        (tester) async {
      await roster.save(_project('book-1', title: 'Throne of Ash'));
      await roster.save(_project('book-2', title: 'Crown of Salt'));

      await pumpProjects(tester, active: _project('book-1'));

      expect(find.byKey(const Key('projects-studio')), findsOneWidget);
      expect(find.text('Throne of Ash'), findsOneWidget);
      expect(find.text('Crown of Salt'), findsOneWidget);
      // The mock's fixtures are gone for good.
      expect(find.text('Ash and Lanterns'), findsNothing);
      expect(find.text('City of Quiet Bridges'), findsNothing);
    });

    testWidgets('the open project is marked as open', (tester) async {
      await roster.save(_project('book-1', title: 'Throne of Ash'));
      await roster.save(_project('book-2', title: 'Crown of Salt'));

      await pumpProjects(tester, active: _project('book-1'));

      expect(
        find.byKey(const Key('projects-active-badge-book-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('projects-active-badge-book-2')),
        findsNothing,
      );
    });

    testWidgets('an author with nothing stored is told the roster is empty',
        (tester) async {
      await pumpProjects(tester, active: _project('nothing-saved'));

      expect(find.byKey(const Key('projects-empty')), findsOneWidget);
    });

    testWidgets('a pre-roster install shows its one project', (tester) async {
      // What an author upgrading from the single-project build actually has:
      // one project under the legacy key and no roster rows at all. It must
      // appear here rather than the screen claiming they have no books.
      SharedPreferences.setMockInitialValues({
        'author_studio.starter_project':
            '{"id":"legacy-1","title":"Hidden Draft","genre":"Fantasy",'
            '"projectType":"Novel","wordGoal":80000,"acts":[],"chapters":[],'
            '"characterSheets":[],"beatChecklist":[],'
            '"firstSceneTitle":"Opening Scene"}',
        'author_studio.onboarding_complete': true,
      });

      await pumpProjects(tester, active: _project('legacy-1'));

      expect(find.byKey(const Key('projects-empty')), findsNothing);
      expect(find.text('Hidden Draft'), findsOneWidget);
      expect(
        (await roster.load()).single.projectId,
        'legacy-1',
        reason: 'The pre-roster project is adopted, keeping its id so its '
            'manuscript still resolves.',
      );
    });

    testWidgets('word counts come from stored manuscripts only',
        (tester) async {
      await roster.save(_project('book-1', title: 'Throne of Ash'));
      final preferences = await SharedPreferences.getInstance();
      final keysBefore = preferences.getKeys().toSet();

      await pumpProjects(tester, active: _project('book-1'));

      expect(
        find.byKey(const Key('projects-words-book-1')),
        findsOneWidget,
      );
      expect(
        preferences.getKeys().toSet(),
        keysBefore,
        reason: 'Listing projects must not seed a manuscript for any of them.',
      );
    });
  });

  group('creating projects', () {
    testWidgets('a new project persists to the roster', (tester) async {
      await roster.save(_project('book-1'));

      await pumpProjects(tester, active: _project('book-1'));
      await tester.tap(find.byKey(const Key('projects-new')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('projects-new-dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('projects-new-title-field')),
        'Court of Embers',
      );
      await tester.enterText(
        find.byKey(const Key('projects-new-goal-field')),
        '95000',
      );
      await tester.tap(find.byKey(const Key('projects-new-save')));
      await tester.pumpAndSettle();

      final stored = await roster.load();
      expect(stored, hasLength(2));
      final created =
          stored.firstWhere((entry) => entry.title == 'Court of Embers');
      expect(created.targetWords, 95000);
      expect(find.text('Court of Embers'), findsOneWidget);
    });

    testWidgets('a project without a title is refused', (tester) async {
      await roster.save(_project('book-1'));

      await pumpProjects(tester, active: _project('book-1'));
      await tester.tap(find.byKey(const Key('projects-new')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('projects-new-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('projects-new-dialog')), findsOneWidget);
      expect(find.text('Give the project a title.'), findsOneWidget);
      expect(await roster.load(), hasLength(1));
    });
  });

  group('series', () {
    testWidgets('a series can be created and shows its books in order',
        (tester) async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier Chronicles',
          defaultTargetWords: 90000,
        ),
      );
      await roster.save(_project('book-1', title: 'Throne of Ash'));
      await roster.save(_project('book-2', title: 'Crown of Salt'));
      await roster.addBookToSeries(
          projectId: 'book-1', seriesId: 'series-1');
      await roster.addBookToSeries(
          projectId: 'book-2', seriesId: 'series-1');

      await pumpProjects(tester, active: _project('book-1'));

      expect(find.byKey(const Key('projects-series-series-1')), findsOneWidget);
      expect(find.text('Endovier Chronicles'), findsOneWidget);
      expect(find.text('BOOK 1'), findsOneWidget);
      expect(find.text('BOOK 2'), findsOneWidget);
    });

    testWidgets('creating a series persists it', (tester) async {
      await roster.save(_project('book-1'));

      await pumpProjects(tester, active: _project('book-1'));
      await tester.tap(find.byKey(const Key('projects-series-new')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('projects-series-name-field')),
        'Endovier Chronicles',
      );
      await tester.tap(find.byKey(const Key('projects-series-save')));
      await tester.pumpAndSettle();

      final stored = await roster.allSeries();
      expect(stored, hasLength(1));
      expect(stored.single.name, 'Endovier Chronicles');
    });

    testWidgets('reordering a series persists the new order', (tester) async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier Chronicles',
          defaultTargetWords: 0,
        ),
      );
      for (final id in ['book-1', 'book-2']) {
        await roster.save(_project(id, title: id));
        await roster.addBookToSeries(projectId: id, seriesId: 'series-1');
      }

      await pumpProjects(tester, active: _project('book-1'));
      await tester.tap(
        find.byKey(const Key('projects-series-move-down-book-1')),
      );
      await tester.pumpAndSettle();

      expect(
        (await roster.books('series-1')).map((book) => book.projectId),
        ['book-2', 'book-1'],
      );
    });

    testWidgets('a book can be taken out of its series', (tester) async {
      await roster.saveSeries(
        const WritingSeries(
          id: 'series-1',
          name: 'Endovier Chronicles',
          defaultTargetWords: 0,
        ),
      );
      await roster.save(_project('book-1', title: 'Throne of Ash'));
      await roster.addBookToSeries(
          projectId: 'book-1', seriesId: 'series-1');

      await pumpProjects(tester, active: _project('book-1'));
      await tester.tap(find.byKey(const Key('projects-unassign-book-1')));
      await tester.pumpAndSettle();

      final entry = await repository.projectRosterEntry('book-1');
      expect(entry!.isBook, isFalse);
      expect(entry.title, 'Throne of Ash',
          reason: 'Leaving a series must not touch the project itself.');
    });
  });

  group('switching the open project', () {
    testWidgets('opening another project reports it to the shell',
        (tester) async {
      await roster.save(_project('book-1', title: 'Throne of Ash'));
      await roster.save(_project('book-2', title: 'Crown of Salt'));

      StarterProject? switched;
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthorStudioShell(
            project: _project('book-1'),
            manuscriptStore: manuscriptStore,
            rosterStore: roster,
            themeId: 'light',
            accentId: 'default',
            onThemeChanged: (_, __) {},
            initialSection: StudioSection.projects,
            onProjectChanged: (project) => switched = project,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('projects-open-book-2')));
      await tester.pumpAndSettle();

      expect(switched, isNotNull);
      expect(switched!.id, 'book-2');
      expect(switched!.title, 'Crown of Salt');
    });

    testWidgets('the open project cannot be re-opened', (tester) async {
      await roster.save(_project('book-1'));

      await pumpProjects(tester, active: _project('book-1'));

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('projects-open-book-1')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('architecture', () {
    test('the Projects Studio mock is gone', () {
      final source = File('lib/main.dart').readAsStringSync();

      expect(source, isNot(contains('class _ProjectRecord')));
      expect(source, isNot(contains('Ash and Lanterns')));
      expect(source, isNot(contains('City of Quiet Bridges')));
      expect(source, contains('ProjectRosterStore'));
    });

    test('the Projects Studio lists projects without seeding manuscripts', () {
      final source = File('lib/main.dart').readAsStringSync();
      final view = source.substring(
        source.indexOf('class _ProjectsStudioView'),
        source.indexOf('class _NoteRecord'),
      );

      expect(view, contains('peekStudio('));
      expect(
        view,
        isNot(contains('loadStudio(')),
        reason: 'Listing projects must not create a manuscript for each one.',
      );
    });
  });
}
