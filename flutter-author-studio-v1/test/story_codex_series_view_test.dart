/// Widget-level behaviour of cross-book scope in the Codex workspace.
///
/// The service tests prove a shared record is readable from a second book.
/// These prove the author can see which side of the line an entry is on, can
/// move it, and is stopped from rewriting canon another book owns.
library;

import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:author_studio_v1/story_codex_workspace.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

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
      );

  testWidgets('a standalone book is not shown a scope it does not have',
      (tester) async {
    final codex = codexFor('book-1');
    await codex.ensureFoundation();
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

    expect(find.byKey(const Key('codex-scope-filter-series')), findsNothing,
        reason: 'progressive complexity: no series, no scope control');
    expect(find.byKey(const Key('codex-series-button')), findsOneWidget,
        reason: 'starting a series must still be reachable');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a book in a series gets the scope facet and a scope chip',
      (tester) async {
    final codex = codexFor('book-1');
    await codex.ensureFoundation();
    await codex.series.createSeries(title: 'The Endovier Cycle');
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

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
    await codex.ensureFoundation();
    await codex.series.createSeries(title: 'Endovier');
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

    await tester.tap(find.byKey(const Key('codex-entry-tile-watch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('codex-entry-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('codex-share-with-series')));
    await tester.pumpAndSettle();

    // The confirmation is deliberate: sharing changes what other books see.
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    final entry = await codex.getCodexEntry('watch');
    expect(entry?.isShared, isTrue);
    expect(find.byKey(const Key('codex-shared-marker-watch')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canon another book owns is marked and cannot be saved over',
      (tester) async {
    final one = codexFor('book-1');
    await one.ensureFoundation();
    final series = await one.series.createSeries(title: 'Endovier');
    await seedEntry(one, 'noxmere', 'House Noxmere');
    await one.promoteToSeries('noxmere');

    final two = codexFor('book-2');
    await two.ensureFoundation();
    await two.series.enrol(series.id);

    await pump(tester, 'book-2');

    // Book two sees the shared entry at all — this is the whole feature.
    expect(find.byKey(const Key('codex-entry-tile-noxmere')), findsOneWidget);
    expect(find.byKey(const Key('codex-shared-marker-noxmere')), findsOneWidget);

    await tester.tap(find.byKey(const Key('codex-entry-tile-noxmere')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('codex-foreign-canon-banner')), findsOneWidget);

    // The pane offers no way to move a record it does not own.
    await tester.tap(find.byKey(const Key('codex-entry-actions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('codex-return-to-book')), findsNothing);
    expect(find.byKey(const Key('codex-share-with-series')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('starting a series from the header enrols the book',
      (tester) async {
    final codex = codexFor('book-1');
    await codex.ensureFoundation();
    await seedEntry(codex, 'watch', 'The Harbour Watch');
    await pump(tester, 'book-1');

    await tester.tap(find.byKey(const Key('codex-series-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('codex-series-start')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('codex-series-name-field')),
      'The Endovier Cycle',
    );
    await tester.tap(find.byKey(const Key('codex-series-confirm')));
    await tester.pumpAndSettle();

    final chain = await codex.scopeChain();
    expect(chain.isStandalone, isFalse);
    final series = await codex.series.currentSeries();
    expect(series?.title, 'The Endovier Cycle');
    expect(tester.takeException(), isNull);
  });
}
