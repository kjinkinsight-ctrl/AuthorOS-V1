import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/entity_suggestions.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entity recognition over manuscript prose — suggest-only, always.
///
/// The rule the whole feature turns on: AuthorOS never silently rewrites canon.
/// A scan reads and returns; only an explicit author action writes.
void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late ManuscriptService manuscripts;
  late EntitySuggestionService suggestions;
  late SeriesService series;
  final timestamp = DateTime.utc(2026, 8, 21);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    manuscripts = ManuscriptService(
      projectId: 'project-a',
      repository: repository,
      store: ManuscriptStore(repository: repository),
    );
    suggestions = EntitySuggestionService(
      projectId: 'project-a',
      repository: repository,
    );
    series = SeriesService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> character(
    String id,
    String name, {
    List<String> aliases = const [],
  }) =>
      records.createRecord(
        AuthorRecord(
          id: id,
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          title: name,
          templateId: 'character',
          fields: {
            'name': name,
            'identity.fullName': name,
            if (aliases.isNotEmpty) 'aliases': aliases,
          },
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  Future<(ManuscriptProjectSummary, String)> sceneSaying(String prose) async {
    var manuscript = await manuscripts.load(
      manuscriptTitle: 'Endovier',
      defaultChapters: const [
        ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
      ],
    );
    final sceneId = manuscript.chapters.first.scenes.first.id;
    manuscript = await manuscripts.writeSceneBody(manuscript, sceneId, prose);
    return (manuscript, sceneId);
  }

  group('recognition states', () {
    test('an unlinked known name is Suggested', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');

      final found = await suggestions.forScene(manuscript, sceneId);
      expect(found, hasLength(1));
      expect(found.single.state, EntityRecognitionState.suggested);
      expect(found.single.entityId, 'kali');
      expect(found.single.matchedName, 'Kali Vale');
      expect(found.single.actions, contains(EntitySuggestionAction.link));
    });

    test('an already-connected name is Confirmed', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      await suggestions.connections.connect(
        sourceId: 'kali',
        targetId: sceneId,
        typeId: 'appearsIn',
      );

      final found = await suggestions.forScene(manuscript, sceneId);
      expect(found.single.state, EntityRecognitionState.confirmed);
      expect(found.single.actions, [EntitySuggestionAction.review]);
    });

    test('a name meaning two entities is Unconfirmed, not guessed at',
        () async {
      await character('kali', 'Kali Vale', aliases: const ['Widow']);
      await character('lucia', 'Lucia Vane', aliases: const ['Widow']);
      final (manuscript, sceneId) =
          await sceneSaying('The Widow crossed the harbour.');

      final found = await suggestions.forScene(manuscript, sceneId);
      final widow =
          found.firstWhere((each) => each.matchedName.toLowerCase() == 'widow');
      expect(widow.state, EntityRecognitionState.unconfirmed);
      expect(widow.entityId, isNull);
      expect(widow.candidateIds, containsAll(<String>{'kali', 'lucia'}));
      expect(widow.isAmbiguous, isTrue);
    });

    test('an alias match is flagged as one', () async {
      await character('kali', 'Kali Vale', aliases: const ['Red Widow']);
      final (manuscript, sceneId) =
          await sceneSaying('The Red Widow crossed the harbour.');

      final found = await suggestions.forScene(manuscript, sceneId);
      expect(found.single.isAlias, isTrue);
      expect(found.single.entityId, 'kali');
      expect(found.single.entityTitle, 'Kali Vale');
    });

    test('a suggestion carries the sentence it was found in', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) = await sceneSaying(
        'The harbour was quiet. Kali Vale entered the room. Nobody spoke.',
      );

      final found = await suggestions.forScene(manuscript, sceneId);
      expect(found.single.snippet, contains('Kali Vale entered the room'));
    });

    test('prose naming nobody produces nothing', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) = await sceneSaying('The harbour was quiet.');
      expect(await suggestions.forScene(manuscript, sceneId), isEmpty);
    });
  });

  group('a scan never writes', () {
    test('scanning creates no record and no link', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      final before = await repository.snapshot();

      await suggestions.forScene(manuscript, sceneId);

      final after = await repository.snapshot();
      expect(after.records.length, before.records.length);
      expect(after.links.length, before.links.length);
    });
  });

  group('actions', () {
    test('Link connects the entity and stamps its provenance', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      final suggestion =
          (await suggestions.forScene(manuscript, sceneId)).single;

      final link = await suggestions.link(suggestion);

      expect(link.sourceId, 'kali');
      expect(link.targetId, sceneId);
      expect(link.typeId, 'appearsIn');
      expect(link.extensionData['derivedFrom'], 'entityRecognition');
      expect(link.extensionData['matchedName'], 'Kali Vale');

      // ...and it now reads as Confirmed.
      final after = await suggestions.forScene(manuscript, sceneId);
      expect(after.single.state, EntityRecognitionState.confirmed);
    });

    test('Link refuses an ambiguous name until the author picks', () async {
      await character('kali', 'Kali Vale', aliases: const ['Widow']);
      await character('lucia', 'Lucia Vane', aliases: const ['Widow']);
      final (manuscript, sceneId) = await sceneSaying('The Widow crossed.');
      final widow = (await suggestions.forScene(manuscript, sceneId))
          .firstWhere((each) => each.isAmbiguous);

      expect(() => suggestions.link(widow), throwsStateError);

      // ...but the author can name the one they meant.
      final link = await suggestions.link(widow, entityId: 'lucia');
      expect(link.sourceId, 'lucia');
    });

    test('Create Alias teaches the name and is versioned like any edit',
        () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale met the Red Widow.');
      final suggestion =
          (await suggestions.forScene(manuscript, sceneId)).single;

      final updated = await suggestions.addAlias('kali', 'Red Widow');
      expect(updated.fields['aliases'], ['Red Widow']);

      final versions =
          await records.history.getVersionHistory(recordId: 'kali');
      expect(versions.length, greaterThan(1),
          reason: 'an alias edit is history, not a silent field write');

      // The alias is recognised from now on.
      final rescanned = await suggestions.forScene(manuscript, sceneId);
      expect(
        rescanned.map((each) => each.matchedName.toLowerCase()),
        contains('red widow'),
      );
      expect(suggestion.actions, contains(EntitySuggestionAction.ignore));
    });

    test('adding an alias twice does not duplicate it', () async {
      await character('kali', 'Kali Vale', aliases: const ['Red Widow']);
      final updated = await suggestions.addAlias('kali', 'red widow');
      expect(updated.fields['aliases'], ['Red Widow']);
    });

    test('an empty alias is refused', () async {
      await character('kali', 'Kali Vale');
      expect(() => suggestions.addAlias('kali', '  '), throwsArgumentError);
    });
  });

  group('dismissal', () {
    test('an ignored suggestion does not come back on a rescan', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      final suggestion =
          (await suggestions.forScene(manuscript, sceneId)).single;

      await suggestions.ignore(suggestion);

      expect(await suggestions.forScene(manuscript, sceneId), isEmpty);
    });

    test('a dismissal survives a fresh service and a reopened database',
        () async {
      await database.close();
      final directory = await Directory.systemTemp.createTemp('suggestions-');
      final file = File('${directory.path}${Platform.pathSeparator}s.sqlite');

      final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
      final firstRepository = DriftConnectedDomainRepository(firstDatabase);
      final firstManuscripts = ManuscriptService(
        projectId: 'durable',
        repository: firstRepository,
        store: ManuscriptStore(repository: firstRepository),
      );
      final firstSuggestions = EntitySuggestionService(
        projectId: 'durable',
        repository: firstRepository,
      );
      await RecordService(projectId: 'durable', repository: firstRepository)
          .createRecord(
        AuthorRecord(
          id: 'kali',
          typeId: 'character',
          scopeType: RecordScopeType.project,
          scopeId: 'durable',
          projectId: 'durable',
          title: 'Kali Vale',
          templateId: 'character',
          fields: const {'name': 'Kali Vale', 'identity.fullName': 'Kali Vale'},
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
      var manuscript = await firstManuscripts.load(
        manuscriptTitle: 'Endovier',
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
        ],
      );
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript = await firstManuscripts.writeSceneBody(
        manuscript,
        sceneId,
        'Kali Vale entered the room.',
      );
      final suggestion =
          (await firstSuggestions.forScene(manuscript, sceneId)).single;
      await firstSuggestions.ignore(suggestion);
      await firstDatabase.close();

      final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopenedRepository =
          DriftConnectedDomainRepository(reopenedDatabase);
      final reopened = EntitySuggestionService(
        projectId: 'durable',
        repository: reopenedRepository,
      );
      final reopenedManuscripts = ManuscriptService(
        projectId: 'durable',
        repository: reopenedRepository,
        store: ManuscriptStore(repository: reopenedRepository),
      );
      final reloaded =
          await reopenedManuscripts.load(manuscriptTitle: 'Endovier');

      expect(await reopened.dismissedKeys(), contains(suggestion.key));
      expect(await reopened.forScene(reloaded, sceneId), isEmpty);
    });

    test('a dismissal never hides something the author connected', () async {
      // Ignoring silences an open question, not an established fact.
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      final suggestion =
          (await suggestions.forScene(manuscript, sceneId)).single;
      await suggestions.ignore(suggestion);

      await suggestions.link(suggestion, entityId: 'kali');

      final after = await suggestions.forScene(manuscript, sceneId);
      expect(after.single.state, EntityRecognitionState.confirmed);
    });

    test('a dismissal can be undone', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      final suggestion =
          (await suggestions.forScene(manuscript, sceneId)).single;

      await suggestions.ignore(suggestion);
      await suggestions.restore(suggestion);

      expect(await suggestions.forScene(manuscript, sceneId), hasLength(1));
    });

    test('dismissals write no version history', () async {
      // Housekeeping, not authorship. A click should not put a snapshot in the
      // author's history.
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      final suggestion =
          (await suggestions.forScene(manuscript, sceneId)).single;

      await suggestions.ignore(suggestion);

      final versions = await records.history.getVersionHistory(
        recordId: suggestions.dismissalRecordId,
      );
      expect(versions, isEmpty);
    });

    test('dismissals travel in the archive', () async {
      await character('kali', 'Kali Vale');
      final (manuscript, sceneId) =
          await sceneSaying('Kali Vale entered the room.');
      await suggestions
          .ignore((await suggestions.forScene(manuscript, sceneId)).single);

      const archive = AuthorOsArchiveService();
      final restored = archive.importSnapshot(
        archive.exportSnapshot(
          await repository.snapshot(),
          archiveId: 'archive-1',
          rootId: 'project-a',
          applicationVersion: '2.0.0',
          platform: 'linux',
          createdAt: timestamp,
        ),
      );

      final stored = restored.records
          .firstWhere((each) => each.id == suggestions.dismissalRecordId);
      expect(stored.fields['dismissedKeys'], isNotEmpty);
    });
  });

  group('book awareness', () {
    test('a Book 2 entity is not suggested against a Book 1 scene', () async {
      final one = await series.createBook(title: 'Book One');
      await series.createBook(title: 'Book Two');
      final two = (await series.books()).last;
      await character('cameo', 'Harbour Boy');
      await series.restrictToBook('cameo', two.id);

      var manuscript = await manuscripts.load(
        manuscriptTitle: 'Endovier',
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
        ],
      );
      final chapterId = manuscript.chapters.first.id;
      final sceneId = manuscript.chapters.first.scenes.first.id;
      manuscript =
          await manuscripts.assignChapterToBook(manuscript, chapterId, one.id);
      manuscript = await manuscripts.writeSceneBody(
        manuscript,
        sceneId,
        'The Harbour Boy waved from the dock.',
      );

      expect(await suggestions.forScene(manuscript, sceneId), isEmpty);

      // ...and it is suggested inside its own book.
      manuscript =
          await manuscripts.assignChapterToBook(manuscript, chapterId, two.id);
      final inTwo = await suggestions.forScene(manuscript, sceneId);
      expect(inTwo.single.entityId, 'cameo');
    });
  });
}
