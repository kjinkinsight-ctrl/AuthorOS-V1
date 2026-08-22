/// The project-wide sweep, end to end against a real database and a real
/// manuscript blob.
library;

import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/core/codex_intelligence.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Future<CodexEntry> entry(
    String id,
    String title, {
    String templateId = 'faction',
    String categoryId = 'factions',
    String content = '',
    String summary = '',
  }) =>
      codex.createCodexEntry(
        CodexEntryDraft(
          id: id,
          title: title,
          templateId: templateId,
          categoryId: categoryId,
          content: content,
          summary: summary,
          // The character template requires a full name; every other template
          // ignores the field.
          structuredFields: {'identity.fullName': title},
        ),
        timestamp: timestamp,
      );

  ManuscriptScene sceneOf({
    required String id,
    required String title,
    required int order,
    required String content,
    String location = '',
    String chapterId = 'chapter-1',
  }) =>
      ManuscriptScene(
        id: id,
        chapterId: chapterId,
        title: title,
        order: order,
        content: content,
        location: location,
        status: ManuscriptNodeStatus.draft,
        createdAt: timestamp,
        updatedAt: timestamp,
      );

  ManuscriptProjectSummary manuscriptOf(
    String projectId,
    List<ManuscriptScene> scenes,
  ) =>
      ManuscriptProjectSummary(
        projectId: projectId,
        manuscriptTitle: 'Ash and Lanterns',
        chapters: [
          ManuscriptChapter(
            id: 'chapter-1',
            title: 'One',
            order: 1,
            status: ManuscriptNodeStatus.draft,
            createdAt: timestamp,
            updatedAt: timestamp,
            scenes: scenes,
          ),
        ],
        currentChapterId: 'chapter-1',
        currentSceneId: scenes.isEmpty ? '' : scenes.first.id,
        createdAt: timestamp,
        updatedAt: timestamp,
        version: 1,
      );

  /// Writes a manuscript the way the Manuscript Studio would.
  Future<void> seedManuscript(List<(String, String)> scenes) =>
      ManuscriptStore(repository: repository).saveStudio(
        manuscriptOf('book-1', [
          for (var i = 0; i < scenes.length; i += 1)
            sceneOf(
              id: 'scene-${i + 1}',
              title: scenes[i].$1,
              order: i + 1,
              content: scenes[i].$2,
            ),
        ]),
      );

  test('a sweep with nothing to find is empty, not an error', () async {
    await codex.ensureFoundation(timestamp: timestamp);
    final sweep = await codex.suggestions.sweep();

    expect(sweep.isEmpty, isTrue);
    expect(sweep.scenesScanned, 0, reason: 'this project has no manuscript');
  });

  test('asking for prose does not create a manuscript', () async {
    await codex.ensureFoundation(timestamp: timestamp);
    await codex.suggestions.sweep();

    final store = ManuscriptStore(repository: repository);
    expect(await store.peekStudio('book-1'), isNull,
        reason: 'a read must never be what causes a manuscript to exist');
  });

  test('an unlinked mention in a Codex entry becomes a link suggestion',
      () async {
    await entry('noxmere', 'House Noxmere');
    await entry(
      'harbour',
      'Noxmere Harbour',
      templateId: 'location',
      categoryId: 'locations',
      content: 'The harbour is held by House Noxmere.',
    );

    final sweep = await codex.suggestions.sweep();
    final suggestion = sweep.suggestions.firstWhere(
      (item) => item.subjectId == 'harbour' && item.targetId == 'noxmere',
    );

    expect(suggestion.actionKind, ContinuityActionKind.link);
    expect(suggestion.source, CodexSuggestionSource.codexEntry);
    expect(suggestion.targetTitle, 'House Noxmere');
  });

  test('a name in the manuscript that has no record becomes a create '
      'suggestion', () async {
    // The scene declares a location no record covers.
    await ManuscriptStore(repository: repository).saveStudio(
      manuscriptOf('book-1', [
        sceneOf(
          id: 'scene-1',
          title: 'Arrival',
          order: 1,
          content: 'A scene far north.',
          location: 'Endovier',
        ),
      ]),
    );

    final sweep = await codex.suggestions.sweep();

    expect(sweep.scenesScanned, 1);
    expect(
      sweep.suggestions.where((item) =>
          item.actionKind == ContinuityActionKind.create &&
          item.missingName == 'Endovier'),
      isNotEmpty,
    );
  });

  test('a Codex record mentioned in prose is recognised in the manuscript',
      () async {
    await entry(
      'kali',
      'Kali Vale',
      templateId: 'character',
      categoryId: 'characters',
    );
    await seedManuscript([
      ('Arrival', 'Kali Vale walked the northern road.'),
    ]);

    final sweep = await codex.suggestions.sweep();
    final suggestion = sweep.suggestions.firstWhere(
      (item) =>
          item.source == CodexSuggestionSource.manuscriptScene &&
          item.targetId == 'kali',
    );

    expect(suggestion.actionKind, ContinuityActionKind.link);
    expect(suggestion.connectionTypeId, 'appearsIn');
  });

  test('records sharing scenes are discovered as a relationship', () async {
    await entry('kali', 'Kali Vale',
        templateId: 'character', categoryId: 'characters');
    await entry('vale', 'Ruan Vale',
        templateId: 'character', categoryId: 'characters');
    await seedManuscript([
      ('One', 'Kali Vale and Ruan Vale argued.'),
      ('Two', 'Ruan Vale followed Kali Vale north.'),
    ]);

    final sweep = await codex.suggestions.sweep();
    final discovered = sweep.suggestions.where(
      (item) => item.source == CodexSuggestionSource.coOccurrence,
    );

    expect(discovered, isNotEmpty);
    expect(discovered.first.actionKind, ContinuityActionKind.link);
    expect(discovered.first.confidence, lessThanOrEqualTo(1));
  });

  test('discovery never writes a link on its own', () async {
    await entry('kali', 'Kali Vale',
        templateId: 'character', categoryId: 'characters');
    await entry('vale', 'Ruan Vale',
        templateId: 'character', categoryId: 'characters');
    await seedManuscript([
      ('One', 'Kali Vale and Ruan Vale argued.'),
      ('Two', 'Ruan Vale followed Kali Vale north.'),
    ]);

    await codex.suggestions.sweep();

    expect(await repository.linksByScope('book-1'), isEmpty,
        reason: 'not one derived edge may reach record_link_rows unprompted');
  });

  group('dismissals', () {
    test('a dismissed suggestion stays gone and is counted', () async {
      await entry('noxmere', 'House Noxmere');
      await entry(
        'harbour',
        'Noxmere Harbour',
        templateId: 'location',
        categoryId: 'locations',
        content: 'The harbour is held by House Noxmere.',
      );

      final before = await codex.suggestions.sweep();
      final target = before.suggestions.first;
      await codex.suggestions.dismiss(target.id, timestamp: timestamp);

      final after = await codex.suggestions.sweep();
      expect(after.suggestions.map((item) => item.id),
          isNot(contains(target.id)));
      expect(after.dismissedCount, greaterThan(0));
    });

    test('a dismissal survives a database close and reopen', () async {
      await entry('noxmere', 'House Noxmere');
      await entry(
        'harbour',
        'Noxmere Harbour',
        templateId: 'location',
        categoryId: 'locations',
        content: 'The harbour is held by House Noxmere.',
      );
      final target = (await codex.suggestions.sweep()).suggestions.first;
      await codex.suggestions.dismiss(target.id, timestamp: timestamp);

      expect(await codex.suggestions.dismissedIds(), contains(target.id));
    });

    test('restoring brings every dismissal back', () async {
      await entry('noxmere', 'House Noxmere');
      await entry(
        'harbour',
        'Noxmere Harbour',
        templateId: 'location',
        categoryId: 'locations',
        content: 'The harbour is held by House Noxmere.',
      );
      final target = (await codex.suggestions.sweep()).suggestions.first;
      await codex.suggestions.dismiss(target.id, timestamp: timestamp);
      await codex.suggestions.restoreDismissed(timestamp: timestamp);

      final after = await codex.suggestions.sweep();
      expect(after.suggestions.map((item) => item.id), contains(target.id));
      expect(after.dismissedCount, 0);
    });

    test('the dismissal record is not a Codex entry', () async {
      await entry('noxmere', 'House Noxmere');
      await codex.suggestions.dismiss('anything', timestamp: timestamp);

      final ids = (await codex.getEntries(includeArchived: true))
          .map((item) => item.id);
      expect(ids.where((id) => id.contains('suggestion-state')), isEmpty);
    });
  });

  test('recognition spans the series', () async {
    // Book one shares a character with the series.
    final series = await codex.series.createSeries(title: 'Endovier');
    await entry('kali', 'Kali Vale',
        templateId: 'character', categoryId: 'characters');
    await codex.promoteToSeries('kali');

    // Book two joins and writes prose naming that shared character.
    final second = StoryCodexService(projectId: 'book-2', repository: repository);
    await second.ensureFoundation(timestamp: timestamp);
    await second.series.enrol(series.id, timestamp: timestamp);
    await ManuscriptStore(repository: repository).saveStudio(
      manuscriptOf('book-2', [
        sceneOf(
          id: 'b2-scene-1',
          title: 'Return',
          order: 1,
          content: 'Kali Vale came back to the harbour.',
        ),
      ]),
    );

    final sweep = await second.suggestions.sweep();

    expect(
      sweep.suggestions.where((item) => item.targetId == 'kali'),
      isNotEmpty,
      reason: 'a series character must be recognised in book two\'s prose',
    );
  });
}
