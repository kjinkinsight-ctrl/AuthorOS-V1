/// The suggestions inbox in the Codex workspace.
///
/// The service tests prove the recommendations are correct. These prove the
/// author can see them, act on one, and refuse one — and that nothing is
/// written until they do.
library;

import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:author_studio_v1/story_codex_workspace.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late StoryCodexService codex;
  final timestamp = DateTime.utc(2026, 8, 22);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    codex = StoryCodexService(projectId: 'book-1', repository: repository);
  });

  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: StoryCodexWorkspace(
            projectId: 'book-1',
            repository: repository,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// An entry whose prose names another entry, with no connection recording it.
  Future<void> seedUnlinkedMention() async {
    await codex.createCodexEntry(
      const CodexEntryDraft(
        id: 'noxmere',
        title: 'House Noxmere',
        templateId: 'faction',
        categoryId: 'factions',
      ),
      timestamp: timestamp,
    );
    await codex.createCodexEntry(
      const CodexEntryDraft(
        id: 'harbour',
        title: 'Noxmere Harbour',
        templateId: 'location',
        categoryId: 'locations',
        content: 'The harbour is held by House Noxmere.',
      ),
      timestamp: timestamp,
    );
  }

  testWidgets('opening the Codex does not sweep', (tester) async {
    await seedUnlinkedMention();
    await pump(tester);

    expect(find.byKey(const Key('codex-suggestions-button')), findsOneWidget);
    expect(find.byKey(const Key('codex-suggestion-inbox')), findsNothing,
        reason: 'a project-wide scan must not be the cost of opening a Studio');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the inbox lists what the sweep found', (tester) async {
    await seedUnlinkedMention();
    await pump(tester);

    await tester.tap(find.byKey(const Key('codex-suggestions-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('codex-suggestion-inbox')), findsOneWidget);
    expect(find.textContaining('Unlinked mention'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a clean project says so rather than showing an empty list',
      (tester) async {
    await codex.ensureFoundation(timestamp: timestamp);
    await pump(tester);

    await tester.tap(find.byKey(const Key('codex-suggestions-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('codex-suggestions-clean-state')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepting a link suggestion creates the link', (tester) async {
    await seedUnlinkedMention();
    await pump(tester);

    await tester.tap(find.byKey(const Key('codex-suggestions-button')));
    await tester.pumpAndSettle();

    final accept = find.byWidgetPredicate(
      (widget) =>
          widget is FilledButton &&
          widget.key.toString().contains('codex-suggestion-accept-'),
    );
    expect(accept, findsWidgets);
    expect(await repository.linksByScope('book-1'), isEmpty,
        reason: 'nothing may be written before the author accepts');

    await tester.ensureVisible(accept.first);
    await tester.pumpAndSettle();
    await tester.tap(accept.first);
    await tester.pumpAndSettle();

    // The confirmation is deliberate: accepting writes a real link.
    expect(find.byKey(const Key('codex-confirm-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('codex-confirm-button')));
    await tester.pumpAndSettle();

    expect(await repository.linksByScope('book-1'), isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissing a suggestion hides it and offers it back',
      (tester) async {
    await seedUnlinkedMention();
    await pump(tester);

    await tester.tap(find.byKey(const Key('codex-suggestions-button')));
    await tester.pumpAndSettle();

    final dismiss = find.byWidgetPredicate(
      (widget) =>
          widget is TextButton &&
          widget.key.toString().contains('codex-suggestion-dismiss-'),
    );
    final before = dismiss.evaluate().length;
    expect(before, greaterThan(0));

    await tester.ensureVisible(dismiss.first);
    await tester.pumpAndSettle();
    await tester.tap(dismiss.first);
    await tester.pumpAndSettle();

    expect(dismiss.evaluate().length, before - 1);
    expect(find.byKey(const Key('codex-restore-dismissed')), findsOneWidget,
        reason: 'a dismissed recommendation must be recoverable');

    await tester.tap(find.byKey(const Key('codex-restore-dismissed')));
    await tester.pumpAndSettle();

    expect(dismiss.evaluate().length, before);
    expect(tester.takeException(), isNull);
  });
}
