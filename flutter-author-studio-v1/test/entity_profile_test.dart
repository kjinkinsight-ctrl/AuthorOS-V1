import 'package:author_studio_v1/core/canon_facts.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/entity_profile_service.dart';
import 'package:author_studio_v1/manuscript_service.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/series_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One entity, its whole series on one page.
void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;
  late SeriesService series;
  late ManuscriptService manuscripts;
  late EntityProfileService profiles;
  final timestamp = DateTime.utc(2026, 8, 21);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
    series = SeriesService(projectId: 'project-a', repository: repository);
    manuscripts = ManuscriptService(
      projectId: 'project-a',
      repository: repository,
      store: ManuscriptStore(repository: repository),
    );
    profiles = EntityProfileService(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  Future<AuthorRecord> record(
    String id,
    String title, {
    String typeId = 'character',
    Map<String, Object?> fields = const {},
  }) =>
      records.createRecord(
        AuthorRecord(
          id: id,
          typeId: typeId,
          scopeType: RecordScopeType.project,
          scopeId: 'project-a',
          projectId: 'project-a',
          canonStatus: CanonStatus.canon,
          title: title,
          templateId: typeId,
          fields: {
            'name': title,
            if (typeId == 'character') 'identity.fullName': title,
            ...fields,
          },
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );

  group('usage across books', () {
    test('usage is grouped Books to Chapters to Scenes', () async {
      final one = await series.createBook(title: 'Book One', order: 0);
      final two = await series.createBook(title: 'Book Two', order: 1);
      await record('kali', 'Kali Vale');

      var manuscript = await manuscripts.load(
        manuscriptTitle: 'Endovier',
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
          ManuscriptChapterSeed(title: 'Chapter 02', scenes: ['Scene 02']),
        ],
      );
      manuscript = await manuscripts.assignChapterToBook(
        manuscript,
        manuscript.chapters[0].id,
        one.id,
      );
      manuscript = await manuscripts.assignChapterToBook(
        manuscript,
        manuscript.chapters[1].id,
        two.id,
      );
      for (final chapter in manuscript.chapters) {
        await series.connections.connect(
          sourceId: 'kali',
          targetId: chapter.scenes.first.id,
          typeId: 'appearsIn',
        );
      }
      await series.recordBookAppearance('kali', one.id, role: 'protagonist');

      final usage = await profiles.usageFor('kali');

      expect(usage!.books.map((book) => book.bookTitle),
          ['Book One', 'Book Two']);
      expect(usage.books.first.chapters.single.chapterTitle, 'Chapter 01');
      expect(usage.books.first.chapters.single.scenes, hasLength(1));
      expect(usage.books.first.appearance!.metadata['role'], 'protagonist');
      expect(usage.bookCount, 2);
      expect(usage.sceneCount, 2);
    });

    test('a project with no books reports its chapters as unfiled', () async {
      await record('kali', 'Kali Vale');
      final manuscript = await manuscripts.load(
        manuscriptTitle: 'Endovier',
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
        ],
      );
      await series.connections.connect(
        sourceId: 'kali',
        targetId: manuscript.chapters.first.scenes.first.id,
        typeId: 'appearsIn',
      );

      final usage = await profiles.usageFor('kali');
      expect(usage!.books, isEmpty);
      expect(usage.unfiledChapters.single.chapterTitle, 'Chapter 01');
      expect(usage.sceneCount, 1);
    });

    test('plot, timeline and research usage are bucketed by kind', () async {
      await record('kali', 'Kali Vale');
      await record('thread', 'Red Widow Arc', typeId: 'plot-thread');
      await record('event', 'Battle of Endovier', typeId: 'timeline-event');
      await record('notes', 'Fae Biology', typeId: 'research-entry');

      await series.connections
          .connect(sourceId: 'kali', targetId: 'thread', typeId: 'pursues');
      await series.connections
          .connect(sourceId: 'event', targetId: 'kali', typeId: 'involves');
      await series.connections
          .connect(sourceId: 'notes', targetId: 'kali', typeId: 'documents');

      final usage = await profiles.usageFor('kali');
      final kinds = usage!.nonEmptyGroups.map((group) => group.kind).toSet();
      expect(
        kinds,
        containsAll(<ReferenceKind>{
          ReferenceKind.plot,
          ReferenceKind.timeline,
          ReferenceKind.codex,
        }),
      );
    });

    test('a book the entity never appears in is left out', () async {
      await series.createBook(title: 'Book One');
      await series.createBook(title: 'Book Two');
      await record('kali', 'Kali Vale');

      final usage = await profiles.usageFor('kali');
      expect(usage!.books, isEmpty);
      expect(usage.isEmpty, isTrue);
    });

    test('a book the entity only differs in still shows', () async {
      final two = await series.createBook(title: 'Book Two');
      await record('kali', 'Kali Vale', fields: const {'identity.age': 27});
      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      final usage = await profiles.usageFor('kali');
      expect(usage!.books.single.bookTitle, 'Book Two');
      expect(usage.books.single.stateRecordId, isNotNull);
    });

    test('derived usage is kept apart from recorded usage', () async {
      // A name the prose mentions but nothing links is a suggestion, not a
      // fact, and merging the two would blur what the author has decided.
      await record('kali', 'Kali Vale');
      var manuscript = await manuscripts.load(
        manuscriptTitle: 'Endovier',
        defaultChapters: const [
          ManuscriptChapterSeed(title: 'Chapter 01', scenes: ['Scene 01']),
        ],
      );
      manuscript = await manuscripts.renameScene(
        manuscript,
        manuscript.chapters.first.scenes.first.id,
        'Kali Vale at the harbour',
      );

      final usage = await profiles.usageFor('kali');
      expect(usage!.derived, hasLength(1));
      expect(usage.derived.single.matchedName, 'Kali Vale');
      expect(usage.books, isEmpty, reason: 'nothing is linked yet');
      expect(usage.unfiledChapters, isEmpty);
    });

    test('a usage read never seeds a manuscript', () async {
      // ManuscriptStore.loadStudio invents a starter manuscript on a project
      // nobody has opened. A report must not be able to create a chapter just
      // by looking at one.
      await record('kali', 'Kali Vale');

      await profiles.usageFor('kali');

      expect(await repository.manuscriptNodesByProject('project-a'), isEmpty);
    });
  });

  group('the profile', () {
    test('assembles every section from the services that own them', () async {
      final one = await series.ensureSeries(title: 'Endovier Chronicles');
      final book = await series.createBook(title: 'Book One');
      await record('kali', 'Kali Vale', fields: const {
        'aliases': ['Red Widow'],
        'notes': 'Carries the whole arc.',
      });
      await record('vincenzo', 'Vincenzo');
      await record('endovier', 'Endovier', typeId: 'city');
      await record('event', 'Battle of Endovier', typeId: 'timeline-event');
      await record('notes', 'Fae Biology', typeId: 'research-entry');

      await series.connections.connect(
        sourceId: 'kali',
        targetId: 'vincenzo',
        typeId: 'rivalOf',
        direction: RecordLinkDirection.undirected,
      );
      await series.connections
          .connect(sourceId: 'kali', targetId: 'endovier', typeId: 'livesIn');
      await series.connections
          .connect(sourceId: 'event', targetId: 'kali', typeId: 'involves');
      await series.connections
          .connect(sourceId: 'notes', targetId: 'kali', typeId: 'documents');
      await series.recordBookAppearance('kali', book.id);

      final profile = await profiles.profileFor('kali');

      expect(profile!.title, 'Kali Vale');
      expect(profile.typeName, 'Character');
      expect(profile.aliases, ['Red Widow']);
      expect(profile.seriesTitle, one.title);
      expect(profile.bookTitles, ['Book One']);

      final byId = {
        for (final section in profile.sections) section.id: section,
      };
      expect(byId['relationships']!.entries.single.detail, 'Vincenzo');
      expect(byId['locations']!.entries.single.detail, 'Endovier');
      expect(byId['timeline']!.entries.single.detail, 'Battle of Endovier');
      expect(byId['appearances']!.entries.single.label, 'Book One');
      expect(byId['research']!.entries.single.detail, 'Fae Biology');
      expect(byId['notes']!.entries.single.label, 'Carries the whole arc.');
    });

    test('the same shape renders for a location and for plain lore', () async {
      // A universal profile has to work for everything, not just characters.
      await record('endovier', 'Endovier', typeId: 'city');
      await record('magic', 'Blood Magic', typeId: 'general-lore');

      for (final id in const ['endovier', 'magic']) {
        final profile = await profiles.profileFor(id);
        expect(profile, isNotNull, reason: id);
        expect(
          profile!.sections.map((section) => section.id),
          [
            'relationships',
            'locations',
            'timeline',
            'appearances',
            'research',
            'notes',
          ],
        );
      }
    });

    test('canon reads as contradicted while something disagrees', () async {
      final two = await series.createBook(title: 'Book Two');
      await record('kali', 'Kali Vale', fields: const {'identity.age': 27});

      var profile = await profiles.profileFor('kali');
      expect(profile!.canonStatus, CanonFactStatus.canon);
      expect(profile.conflictCount, 0);
      expect(profile.confidence, 0.8);

      await series.setEntityState(
        'kali',
        two.id,
        overrides: const {'identity.age': 29},
      );

      profile = await profiles.profileFor('kali');
      expect(profile!.canonStatus, CanonFactStatus.contradicted);
      expect(profile.conflictCount, 1);
      expect(profile.confidence, 0.25);
    });

    test('a missing record has no profile', () async {
      expect(await profiles.profileFor('nobody'), isNull);
      expect(await profiles.usageFor('nobody'), isNull);
    });

    test('building a profile writes nothing', () async {
      final book = await series.createBook(title: 'Book One');
      await record('kali', 'Kali Vale');
      await series.recordBookAppearance('kali', book.id);
      final before = await repository.snapshot();

      await profiles.profileFor('kali');

      final after = await repository.snapshot();
      expect(after.records.length, before.records.length);
      expect(after.links.length, before.links.length);
      expect(
        after.records.map((each) => each.revision).toList(),
        before.records.map((each) => each.revision).toList(),
      );
    });
  });
}
