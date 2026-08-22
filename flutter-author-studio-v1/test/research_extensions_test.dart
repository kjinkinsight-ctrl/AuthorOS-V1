import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:author_studio_v1/story_codex_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the capabilities layered onto Research Studio after the canonical
/// implementation landed: the derived dashboard, structured sources, saved
/// views, and the connection surface.
///
/// Each one reuses something the codebase already owns, so the tests assert
/// the reuse as much as the behaviour.
const projectId = 'project-research-ext';
final timestamp = DateTime.utc(2026, 8, 21, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ResearchService research;

  setUp(() {
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
    String sourceUrl = '',
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
          important: important,
          sourceUrl: sourceUrl,
          citation: citation,
          tags: tags,
        ),
        timestamp: timestamp.add(Duration(minutes: minute)),
      );

  group('Dashboard read-model', () {
    test('an empty project reports an empty dashboard', () async {
      final dashboard = await research.dashboard();

      expect(dashboard.isEmpty, isTrue);
      expect(dashboard.total, 0);
      expect(dashboard.recent, isEmpty);
      expect(dashboard.unresolved, isEmpty);
      expect(dashboard.categories, isEmpty);
    });

    test('counts are derived from the records, by kind and category',
        () async {
      await seed('r1', 'Roman roads',
          kind: 'Source', category: 'History', sourceUrl: 'https://example.org');
      await seed('r2', 'Field notes', kind: 'Note', category: 'History');
      await seed('r3', 'Style guide', kind: 'Reference', category: 'Culture');
      await seed('r4', 'Starred', kind: 'Note', important: true);

      final dashboard = await research.dashboard();

      expect(dashboard.total, 4);
      expect(dashboard.sources, 1);
      expect(dashboard.notes, 2);
      expect(dashboard.references, 1);
      expect(dashboard.important, 1);
      expect(dashboard.categories, containsAll(<String>['History', 'Culture']));
    });

    test('tags are collected across the library, de-duplicated and sorted',
        () async {
      await seed('r1', 'One', tags: const ['rome', 'maps']);
      await seed('r2', 'Two', tags: const ['Maps', 'ships']);

      final dashboard = await research.dashboard();

      // Distinct spellings are preserved; ordering is case-insensitive.
      expect(dashboard.tags, contains('rome'));
      expect(dashboard.tags, contains('ships'));
      expect(
        dashboard.tags.map((tag) => tag.toLowerCase()).toList(),
        equals(
          [...dashboard.tags.map((tag) => tag.toLowerCase())]..sort(),
        ),
      );
    });

    test('recent lists the most recently updated entries, newest first',
        () async {
      await seed('old', 'Older entry', minute: 0);
      await seed('mid', 'Middle entry', minute: 5);
      await seed('new', 'Newest entry', minute: 9);

      final dashboard = await research.dashboard();

      expect(dashboard.recent.first.id, 'new');
      expect(dashboard.recent.last.id, 'old');
    });

    test('the dashboard writes nothing back to the database', () async {
      await seed('r1', 'Roman roads', kind: 'Source');
      final before = await repository.recordById('r1');

      await research.dashboard();
      await research.dashboard();

      final after = await repository.recordById('r1');
      expect(after!.revision, before!.revision);
      expect(after.updatedAt, before.updatedAt);
    });
  });

  group('Unresolved research is derived, never stored', () {
    test('New and In Progress entries are unresolved', () async {
      final fresh = await seed('r1', 'Fresh', status: 'New');
      final working = await seed('r2', 'Working', status: 'In Progress');

      expect(ResearchService.isUnresolved(fresh), isTrue);
      expect(ResearchService.isUnresolved(working), isTrue);
    });

    test('Reviewed and Verified entries are resolved', () async {
      final reviewed = await seed('r1', 'Reviewed', status: 'Reviewed');
      final verified = await seed('r2', 'Verified', status: 'Verified');

      expect(ResearchService.isUnresolved(reviewed), isFalse);
      expect(ResearchService.isUnresolved(verified), isFalse);
    });

    test('a Source claiming no source stays unresolved even when verified',
        () async {
      final unsourced =
          await seed('r1', 'Unsourced', kind: 'Source', status: 'Verified');

      expect(ResearchService.hasAnySource(unsourced), isFalse);
      expect(ResearchService.isUnresolved(unsourced), isTrue);
    });

    test('a citation alone resolves a verified Source', () async {
      final cited = await seed(
        'r1',
        'Cited',
        kind: 'Source',
        status: 'Verified',
        citation: 'Gibbon, 1776',
      );

      expect(ResearchService.hasAnySource(cited), isTrue);
      expect(ResearchService.isUnresolved(cited), isFalse);
    });

    test('archiving settles an entry without changing its stored status',
        () async {
      await seed('r1', 'Fresh', status: 'New');
      final archived = await research.archiveResearch('r1');

      expect(ResearchService.storedStatusOf(archived), 'New');
      expect(ResearchService.isUnresolved(archived), isFalse);
    });

    test('no unresolved flag is ever written to the record', () async {
      await seed('r1', 'Fresh', status: 'New');
      final record = await repository.recordById('r1');

      expect(
        record!.fields.keys.where(
          (key) => key.toLowerCase().contains('unresolved'),
        ),
        isEmpty,
      );
    });

    test('the dashboard surfaces the unresolved entries', () async {
      await seed('r1', 'Needs work', status: 'New');
      await seed('r2', 'Done', status: 'Verified');

      final dashboard = await research.dashboard();

      expect(dashboard.unresolved.map((record) => record.id), ['r1']);
    });
  });

  group('Structured sources reuse the Codex source shape', () {
    test('sources are stored on the inherited sourceReferences field',
        () async {
      await seed('r1', 'Roman roads', kind: 'Source');

      await research.addSource(
        'r1',
        const CodexSourceReference(
          recordId: '',
          kind: 'external',
          label: 'Gibbon',
          location: 'ch. 4',
        ),
      );

      final record = await repository.recordById('r1');
      expect(record!.fields.containsKey(CodexFields.sources), isTrue);
      final stored = record.fields[CodexFields.sources];
      expect(stored, isA<List<Object?>>());
    });

    test('sources round-trip through the canonical record', () async {
      await seed('r1', 'Roman roads', kind: 'Source');
      await research.addSource(
        'r1',
        const CodexSourceReference(
          recordId: '',
          kind: 'external',
          label: 'Gibbon',
          location: 'ch. 4',
          notes: 'Vol. I',
        ),
      );

      final reloaded = await research.getResearch('r1');
      final sources = ResearchService.sourcesOf(reloaded!);

      expect(sources, hasLength(1));
      expect(sources.single.label, 'Gibbon');
      expect(sources.single.location, 'ch. 4');
      expect(sources.single.notes, 'Vol. I');
    });

    test('several sources accumulate in order', () async {
      await seed('r1', 'Roman roads', kind: 'Source');
      await research.addSource('r1',
          const CodexSourceReference(recordId: '', kind: 'external', label: 'A'));
      await research.addSource('r1',
          const CodexSourceReference(recordId: '', kind: 'external', label: 'B'));

      final record = await research.getResearch('r1');
      expect(
        ResearchService.sourcesOf(record!).map((source) => source.label),
        ['A', 'B'],
      );
    });

    test('a source is removed by its stable id', () async {
      await seed('r1', 'Roman roads', kind: 'Source');
      await research.addSource('r1',
          const CodexSourceReference(recordId: '', kind: 'external', label: 'A'));
      await research.addSource('r1',
          const CodexSourceReference(recordId: '', kind: 'external', label: 'B'));

      final record = await research.getResearch('r1');
      final first = ResearchService.sourcesOf(record!).first;
      final after = await research.removeSource('r1', first.stableId);

      expect(
        ResearchService.sourcesOf(after).map((source) => source.label),
        ['B'],
      );
    });

    test('adding a source resolves an otherwise unsourced Source entry',
        () async {
      await seed('r1', 'Roman roads', kind: 'Source', status: 'Verified');
      final before = await research.getResearch('r1');
      expect(ResearchService.isUnresolved(before!), isTrue);

      final after = await research.addSource(
        'r1',
        const CodexSourceReference(
          recordId: '',
          kind: 'external',
          label: 'Gibbon',
        ),
      );

      expect(ResearchService.isUnresolved(after), isFalse);
    });

    test('editing an entry leaves its sources untouched', () async {
      await seed('r1', 'Roman roads', kind: 'Source');
      await research.addSource('r1',
          const CodexSourceReference(recordId: '', kind: 'external', label: 'A'));

      final current = await research.getResearch('r1');
      await research.updateResearch(
        ResearchDraft.fromRecord(current!).copyTitle('Roman roads, revised'),
      );

      final after = await research.getResearch('r1');
      expect(after!.title, 'Roman roads, revised');
      expect(ResearchService.sourcesOf(after), hasLength(1));
    });

    test('plain string sources written elsewhere are preserved as references',
        () async {
      await seed('r1', 'Roman roads');
      final record = await repository.recordById('r1');
      await repository.putRecord(
        record!.copyWith(
          fields: {...record.fields, CodexFields.sources: const ['A legacy note']},
        ),
      );

      final reloaded = await research.getResearch('r1');
      final sources = ResearchService.sourcesOf(reloaded!);

      expect(sources, hasLength(1));
      expect(sources.single.label, 'A legacy note');
    });

    test('sources cannot be set on a record outside the project', () async {
      expect(
        () => research.setSources('missing', const []),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Saved views reuse the Codex collection record', () {
    test('a saved view stores its filter and reads back', () async {
      await research.saveView(
        id: 'view-1',
        name: 'Unverified history',
        filter: const ResearchViewFilter(
          query: 'rome',
          shelf: ResearchShelf.sources,
          category: 'History',
          sort: ResearchSort.alphabetical,
        ),
      );

      final views = await research.savedViews();
      expect(views, hasLength(1));
      expect(views.single.name, 'Unverified history');
      expect(views.single.filter.query, 'rome');
      expect(views.single.filter.shelf, ResearchShelf.sources);
      expect(views.single.filter.category, 'History');
      expect(views.single.filter.sort, ResearchSort.alphabetical);
    });

    test('it is a codexCollection record, not a new type', () async {
      await research.saveView(
        id: 'view-1',
        name: 'A view',
        filter: const ResearchViewFilter(),
      );

      final record = await repository.recordById('view-1');
      expect(record!.typeId, 'codexCollection');
      expect(record.fields['kind'], 'savedView');
      expect(record.fields['studioId'], 'research');
    });

    test('research views never appear in the Story Codex saved views',
        () async {
      final codex = StoryCodexService(
        projectId: projectId,
        repository: repository,
      );
      await codex.saveView(
        name: 'A Codex view',
        filter: const CodexEntryFilter(query: 'codex'),
      );
      await research.saveView(
        id: 'view-research',
        name: 'A Research view',
        filter: const ResearchViewFilter(query: 'research'),
      );

      final codexViews = await codex.getSavedViews();
      final researchViews = await research.savedViews();

      expect(codexViews.map((view) => view.name), ['A Codex view']);
      expect(researchViews.map((view) => view.name), ['A Research view']);
    });

    test('saving over an existing id replaces the filter', () async {
      await research.saveView(
        id: 'view-1',
        name: 'First',
        filter: const ResearchViewFilter(query: 'one'),
      );
      await research.saveView(
        id: 'view-1',
        name: 'Second',
        filter: const ResearchViewFilter(query: 'two'),
      );

      final views = await research.savedViews();
      expect(views, hasLength(1));
      expect(views.single.name, 'Second');
      expect(views.single.filter.query, 'two');
    });

    test('an unnamed view is rejected', () async {
      expect(
        () => research.saveView(
          id: 'view-1',
          name: '   ',
          filter: const ResearchViewFilter(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a deleted view leaves the list', () async {
      await research.saveView(
        id: 'view-1',
        name: 'A view',
        filter: const ResearchViewFilter(),
      );
      await research.deleteSavedView('view-1');

      expect(await research.savedViews(), isEmpty);
    });

    test('a Codex view cannot be deleted through Research', () async {
      final codex = StoryCodexService(
        projectId: projectId,
        repository: repository,
      );
      final view = await codex.saveView(
        name: 'A Codex view',
        filter: const CodexEntryFilter(),
      );

      // The Codex stores its collections under a prefixed record id; that
      // record, not the bare view id, is what Research must refuse.
      await expectLater(
        research.deleteSavedView('codex-collection-${view.id}'),
        throwsA(isA<StateError>()),
      );
    });

    test('the filter is stored as ordinary record fields, not a blob',
        () async {
      await research.saveView(
        id: 'view-1',
        name: 'A view',
        filter: const ResearchViewFilter(
          query: 'rome',
          shelf: ResearchShelf.sources,
        ),
      );

      final record = await repository.recordById('view-1');
      expect(record!.fields['viewQuery'], 'rome');
      expect(record.fields['viewShelf'], 'sources');
      expect(record.fields.containsKey('filter'), isFalse);
    });

    test('an unrecognised stored shelf falls back instead of losing the view',
        () async {
      await research.saveView(
        id: 'view-1',
        name: 'A view',
        filter: const ResearchViewFilter(shelf: ResearchShelf.sources),
      );
      final record = await repository.recordById('view-1');
      await repository.putRecord(
        record!.copyWith(
          fields: {...record.fields, 'viewShelf': 'a-shelf-from-the-future'},
        ),
      );

      final views = await research.savedViews();
      expect(views, hasLength(1));
      expect(views.single.filter.shelf, ResearchShelf.all);
    });
  });

  group('Connection surface', () {
    test('the registry decides which link types are offered', () async {
      await seed('r1', 'Roman roads');

      final types = await research.connectionTypesBetween(
        sourceTypeId: 'research-entry',
        targetTypeId: 'character',
      );

      expect(types.map((type) => type.id), contains('documents'));
    });

    test('connectable records span the project and exclude the entry itself',
        () async {
      await seed('r1', 'Roman roads');
      await seed('r2', 'Ship designs');

      final connectable = await research.connectableRecords(excludeId: 'r1');

      expect(connectable.map((record) => record.id), contains('r2'));
      expect(connectable.map((record) => record.id), isNot(contains('r1')));
    });

    test('saved views are not offered as connection targets', () async {
      await seed('r1', 'Roman roads');
      await research.saveView(
        id: 'view-1',
        name: 'A view',
        filter: const ResearchViewFilter(),
      );

      final connectable = await research.connectableRecords(excludeId: 'r1');

      expect(connectable.map((record) => record.id), isNot(contains('view-1')));
    });

    test('a connection is made and read back through the shared engine',
        () async {
      await seed('r1', 'Roman roads');
      await seed('r2', 'Ship designs');

      await research.connect(
        sourceId: 'r1',
        targetId: 'r2',
        typeId: 'documents',
      );

      final connections = await research.connectedRecords('r1');
      expect(connections.map((view) => view.record.id), ['r2']);
    });

    test('a disconnected link disappears from both ends', () async {
      await seed('r1', 'Roman roads');
      await seed('r2', 'Ship designs');
      final link = await research.connect(
        sourceId: 'r1',
        targetId: 'r2',
        typeId: 'documents',
      );

      await research.disconnect(link.id);

      expect(await research.connectedRecords('r1'), isEmpty);
      expect(await research.connectedRecords('r2'), isEmpty);
    });
  });
}

/// Small helper so a source-preservation test can rename without restating
/// every draft field.
extension on ResearchDraft {
  ResearchDraft copyTitle(String title) => ResearchDraft(
        id: id,
        title: title,
        typeId: typeId,
        kind: kind,
        category: category,
        status: status,
        important: important,
        summary: summary,
        notes: notes,
        sourceUrl: sourceUrl,
        citation: citation,
        tags: tags,
      );
}
