import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late StoryCodexService service;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    service =
        StoryCodexService(projectId: 'project-codex', repository: repository);
  });

  tearDown(() => database.close());

  testWidgets(
      'dashboard creates a template-backed universal record and reloads',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpCodex(tester, repository);

    expect(find.text('Story Codex'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Recent Entries'), findsOneWidget);
    expect(find.text('Collections'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-codex-entry-button')));
    await tester.pumpAndSettle();
    final templateField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('codex-template-field')),
    );
    templateField.onChanged?.call('location');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('codex-title-field')),
      'Noxmere Harbor',
    );
    await tester.enterText(
      find.byKey(const Key('codex-summary-field')),
      'A cold harbor beneath the northern cliffs.',
    );
    await tester.enterText(
      find.byKey(const Key('codex-content-field')),
      'The Widow Network maintains hidden routes here.',
    );
    await tester.enterText(
      find.byKey(const Key('codex-tags-field')),
      'Book One, Important',
    );
    await tester.tap(find.byKey(const Key('save-codex-entry-button')));
    await tester.pumpAndSettle();

    expect(find.text('Noxmere Harbor'), findsWidgets);
    final stored = await service.getEntries();
    expect(stored, hasLength(1));
    expect(stored.single.recordType, 'location');
    expect(stored.single.categoryId, 'locations');
    expect(stored.single.tagIds, containsAll(['book-one', 'important']));

    await _pumpCodex(tester, repository);
    expect(find.text('Noxmere Harbor'), findsWidgets);
    expect((await service.getEntries()).single.summary,
        'A cold harbor beneath the northern cliffs.');
  });

  testWidgets(
      'entry view edits, searches, archives, and restores canonical data',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final entry = await service.createCodexEntry(const CodexEntryDraft(
      id: 'blood-binding',
      title: 'Blood Binding',
      templateId: 'magic-rule',
      categoryId: 'magic',
      summary: 'A costly binding rule.',
    ));
    await _pumpCodex(tester, repository);

    await tester.tap(find.byKey(Key('codex-entry-${entry.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('codex-entry-view')), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('codex-summary-field')),
      'A binding rule with an irreversible cost.',
    );
    await tester.tap(find.byKey(const Key('save-codex-entry-button')));
    await tester.pumpAndSettle();
    expect(
        find.text('A binding rule with an irreversible cost.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('story-codex-search-field')),
      'irreversible',
    );
    await tester.pumpAndSettle();
    expect(find.text('Blood Binding'), findsWidgets);

    await tester.tap(find.byTooltip('Entry actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect((await service.getCodexEntry(entry.id))?.isArchived, isTrue);

    await tester.tap(find.byTooltip('Entry actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect((await service.getCodexEntry(entry.id))?.isArchived, isFalse);
  });
}

Future<void> _pumpCodex(
  WidgetTester tester,
  DriftConnectedDomainRepository repository,
) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StoryCodexView(
          projectId: 'project-codex',
          repository: repository,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
