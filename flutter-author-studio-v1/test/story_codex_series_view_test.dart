/// Cross-book scope in the Codex workspace, under the locked identity model.
///
/// The Projects Studio owns series identity (Q-S1), so the Codex has no control
/// that creates, renames or joins one. What it must still do is show which
/// series this book is in, mark shared canon, let an author share and return an
/// entry, and refuse to rewrite canon another book owns.
library;

import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:author_studio_v1/story_codex_workspace.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/series_fixture.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  final timestamp = DateTime.utc(2026, 8, 22);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  StoryCodexService codexFor(String projectId) =>
      StoryCodexService(projectId: projectId, repository: repository);

  Future<void> pump(WidgetTester tester, String projectId) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StoryCodexWorkspace(
            projectId: projectId,
            repository: repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> seedEntry(StoryCodexService codex, String id, String title) =>
      codex.createCodexEntry(
        CodexEntryDraft(
          id: id,
          title: title,
          templateId: 'faction',
          categoryId: 'factions',
        ),
        timestamp: timestamp,
      );

  testWidgets('the Codex offers no way to create a series', (tester) async {
    final codex = codexFor('book-1');
    await codex.ensureFoundation(timestamp: timestamp);
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

    for (final gone in const [
      'codex-series-button',
      'codex-series-start',
      'codex-series-name-field',
      'codex-series-menu',
    ]) {
      expect(find.byKey(Key(gone)), findsNothing,
          reason: 'series identity is the Projects Studio\'s ($gone)');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a standalone book is not shown a scope it does not have',
      (tester) async {
    final codex = codexFor('book-1');
    await codex.ensureFoundation(timestamp: timestamp);
    await enrolStandalone(repository, 'book-1');
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

    expect(find.byKey(const Key('codex-scope-filter-series')), findsNothing);
    expect(find.byKey(const Key('codex-series-chip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a book in a series names it, and gains the scope facet',
      (tester) async {
    final codex = codexFor('book-1');
    await codex.ensureFoundation(timestamp: timestamp);
    await enrolInSeries(repository,
        seriesId: 'series_1724_0',
        projectIds: ['book-1'],
        name: 'The Endovier Cycle');
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

    expect(find.byKey(const Key('codex-series-chip')), findsOneWidget);
    expect(find.text('The Endovier Cycle'), findsWidgets,
        reason: 'the name comes from the roster, not from a second record');
    expect(find.byKey(const Key('codex-scope-filter-series')), findsOneWidget);
    expect(find.byKey(const Key('codex-scope-filter-book')), findsOneWidget);

    await tester.tap(find.byKey(const Key('codex-entry-tile-watch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('codex-scope-chip')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an entry can be shared with the series from its own pane',
      (tester) async {
    final codex = codexFor('book-1');
    await codex.ensureFoundation(timestamp: timestamp);
    await enrolInSeries(repository,
        seriesId: 'series_1724_0', projectIds: ['book-1']);
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

    await tester.tap(find.byKey(const Key('codex-entry-tile-watch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('codex-entry-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('codex-share-with-series')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final entry = await codex.getCodexEntry('watch');
    expect(entry?.isShared, isTrue);
    expect(entry?.seriesId, 'series_1724_0',
        reason: 'shared canon hangs on the roster\'s id');
    expect(find.byKey(const Key('codex-shared-marker-watch')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canon another book owns is marked and cannot be saved over',
      (tester) async {
    final one = codexFor('book-1');
    await one.ensureFoundation(timestamp: timestamp);
    await enrolInSeries(repository,
        seriesId: 'series_1724_0', projectIds: ['book-1', 'book-2']);
    await seedEntry(one, 'noxmere', 'House Noxmere');
    await one.promoteToSeries('noxmere');

    final two = codexFor('book-2');
    await two.ensureFoundation(timestamp: timestamp);
    await pump(tester, 'book-2');

    expect(find.byKey(const Key('codex-entry-tile-noxmere')), findsOneWidget,
        reason: 'book two reads the series canon book one shared');
    expect(find.byKey(const Key('codex-shared-marker-noxmere')), findsOneWidget);

    await tester.tap(find.byKey(const Key('codex-entry-tile-noxmere')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('codex-foreign-canon-banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('codex-entry-actions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('codex-return-to-book')), findsNothing);
    expect(find.byKey(const Key('codex-share-with-series')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
