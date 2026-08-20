import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/core/universal_search.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late UniversalSearchService searchA;
  final timestamp = DateTime.utc(2026, 8, 19);

  setUp(() async {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    await repository.replaceSnapshot(_fixture(timestamp));
    searchA = UniversalSearchService(
      projectId: 'project-a',
      repository: repository,
    );
  });

  tearDown(() => database.close());

  test('basic, exact title, content, tag, and multiple-type FTS search',
      () async {
    final shared = await searchA.searchAll('Noxmere');
    final exact = await searchA.searchAll('Kali Vale');
    final content = await searchA.searchAll('cartographer');
    final tags = await searchA.searchAll('protagonist');

    expect(
        shared.map((result) => result.recordType).toSet(),
        containsAll({
          'character',
          'location',
          'faction',
          'general-lore',
          'historical-event',
          'scene',
          'chapter',
        }));
    expect(exact.first.recordId, 'kali');
    expect(exact.first.matchedField, 'title');
    expect(content.single.recordId, 'kali');
    expect(tags.single.recordId, 'kali');
    expect(tags.single.matchedField, 'tags');
  });

  test('result metadata and navigation target identify owning studios',
      () async {
    final results = await searchA.searchAll('Noxmere');
    final character =
        results.singleWhere((result) => result.recordId == 'kali');
    final location =
        results.singleWhere((result) => result.recordId == 'noxmere-harbor');
    final codex =
        results.singleWhere((result) => result.recordId == 'noxmere-history');
    final event =
        results.singleWhere((result) => result.recordId == 'noxmere-fall');
    final scene =
        results.singleWhere((result) => result.recordId == 'scene-noxmere');

    expect(character.projectId, 'project-a');
    expect(character.seriesId, 'series-a');
    expect(character.bookId, 'book-1');
    expect(character.templateId, 'character');
    expect(character.category, 'characters');
    expect(character.tags, contains('protagonist'));
    expect(character.snippet, isNotEmpty);
    expect(character.navigationTarget.destination,
        SearchDestination.characterStudio);
    expect(
        location.navigationTarget.destination, SearchDestination.worldStudio);
    expect(codex.navigationTarget.destination, SearchDestination.storyCodex);
    expect(
        event.navigationTarget.destination, SearchDestination.timelineStudio);
    expect(
        scene.navigationTarget.destination, SearchDestination.manuscriptStudio);
  });

  test('type, project, series, book, and canon filters are database-backed',
      () async {
    expect(
      (await searchA.searchByType('Noxmere', 'location')).single.recordId,
      'noxmere-harbor',
    );
    expect(
      (await searchA.searchBySeries('Noxmere', 'series-a'))
          .map((result) => result.recordId),
      containsAll(['kali', 'noxmere-harbor', 'widow-network']),
    );
    expect(
      (await searchA.searchByBook('Noxmere', 'book-1'))
          .map((result) => result.recordId),
      containsAll(['kali', 'noxmere-harbor']),
    );
    expect(
      (await searchA.searchByStatus('Noxmere', CanonStatus.draft))
          .single
          .recordId,
      'noxmere-harbor',
    );
    expect(
      () => searchA.searchByProject('Noxmere', 'project-b'),
      throwsStateError,
    );
  });

  test('all shared canon states use one filter model', () async {
    for (final status in CanonStatus.values) {
      final results = await searchA.searchByStatus('statusprobe', status);
      expect(results.single.canonStatus, status, reason: status.name);
    }
  });

  test('project isolation prevents identical terms leaking across projects',
      () async {
    final searchB = UniversalSearchService(
      projectId: 'project-b',
      repository: repository,
    );

    expect(
      (await searchA.searchAll('sharedsecret'))
          .map((result) => result.recordId),
      ['project-a-secret'],
    );
    expect(
      (await searchB.searchAll('sharedsecret'))
          .map((result) => result.recordId),
      ['project-b-secret'],
    );
  });

  test('branch search resolves overrides, created records, and hidden records',
      () async {
    final override = await searchA.searchByBranch('neverleft', 'branch-a');
    final created = await searchA.searchByBranch('branchrelic', 'branch-a');
    final inherited = await searchA.searchByBranch('Noxmere', 'branch-a');

    expect(override.single.recordId, 'kali');
    expect(override.single.title, 'Kali Remained');
    expect(override.single.branchId, 'branch-a');
    expect(override.single.canonStatus, CanonStatus.alternate);
    expect(override.single.navigationTarget.branchId, 'branch-a');
    expect(created.single.recordId, 'branch-relic');
    expect(created.single.branchId, 'branch-a');
    expect(
      inherited.map((result) => result.recordId),
      isNot(contains('noxmere-harbor')),
    );
    expect(await searchA.searchAll('neverleft'), isEmpty);
  });

  test('branch isolation excludes unrelated branch content', () async {
    expect(await searchA.searchByBranch('foreignbranch', 'branch-a'), isEmpty);
    expect(
      (await searchA.searchByBranch('foreignbranch', 'branch-b'))
          .single
          .recordId,
      'widow-network',
    );
  });

  test('canonical edits refresh inherited branch index metadata', () async {
    final canonical = (await repository.recordById('kali'))!;
    await repository.putRecord(canonical.copyWith(
      tags: [...canonical.tags, 'freshsignal'],
      updatedAt: timestamp.add(const Duration(minutes: 1)),
    ));

    final result =
        (await searchA.searchByBranch('freshsignal', 'branch-a')).single;

    expect(result.recordId, 'kali');
    expect(result.tags, contains('freshsignal'));
    expect(result.matchedField, 'tags');
    expect(result.title, 'Kali Remained');
  });

  test('index survives close/reopen and archive restore', () async {
    await database.close();
    final directory = await Directory.systemTemp.createTemp('authoros-search-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        File('${directory.path}${Platform.pathSeparator}search.sqlite');
    final firstDatabase = AuthorOsDatabase(NativeDatabase(file));
    final firstRepository = DriftConnectedDomainRepository(firstDatabase);
    await firstRepository.replaceSnapshot(_fixture(timestamp));
    await firstDatabase.close();

    final reopenedDatabase = AuthorOsDatabase(NativeDatabase(file));
    final reopenedRepository = DriftConnectedDomainRepository(reopenedDatabase);
    final reopened = UniversalSearchService(
      projectId: 'project-a',
      repository: reopenedRepository,
    );
    expect((await reopened.searchAll('cartographer')).single.recordId, 'kali');
    expect(
      (await reopened.searchByBranch('branchrelic', 'branch-a'))
          .single
          .recordId,
      'branch-relic',
    );

    const archives = AuthorOsArchiveService();
    final bytes = archives.exportSnapshot(
      await reopenedRepository.snapshot(),
      archiveId: 'search-archive',
      rootId: 'project-a',
      applicationVersion: '2.0.0',
      platform: 'windows',
      createdAt: timestamp,
    );
    final restoredDatabase = AuthorOsDatabase(NativeDatabase.memory());
    final restoredRepository = DriftConnectedDomainRepository(restoredDatabase);
    await restoredRepository.replaceSnapshot(archives.importSnapshot(bytes));
    final restored = UniversalSearchService(
      projectId: 'project-a',
      repository: restoredRepository,
    );
    expect((await restored.searchAll('Noxmere')),
        hasLength(greaterThanOrEqualTo(7)));
    expect(
      (await restored.searchByBranch('neverleft', 'branch-a')).single.title,
      'Kali Remained',
    );
    await restoredDatabase.close();
    await reopenedDatabase.close();
  });
}

ConnectedDomainSnapshot _fixture(DateTime timestamp) {
  final records = <AuthorRecord>[
    _record(
      'kali',
      'character',
      'Kali Vale',
      timestamp,
      fields: const {
        'identity.fullName': 'Kali Vale',
        'summary': 'A Noxmere cartographer following the ember signal.',
      },
      tags: const ['protagonist', 'noxmere'],
      seriesId: 'series-a',
      bookId: 'book-1',
      templateId: 'character',
    ),
    _record(
      'noxmere-harbor',
      'location',
      'Noxmere Harbor',
      timestamp,
      fields: const {'summary': 'Fog-bound Noxmere docks.'},
      seriesId: 'series-a',
      bookId: 'book-1',
      canonStatus: CanonStatus.draft,
    ),
    _record(
      'widow-network',
      'faction',
      'Widow Network',
      timestamp,
      fields: const {'summary': 'Guards the Noxmere routes.'},
      seriesId: 'series-a',
      bookId: 'book-2',
      canonStatus: CanonStatus.proposed,
    ),
    _record(
      'noxmere-history',
      'general-lore',
      'Noxmere History',
      timestamp,
      fields: const {'content': 'The complete Noxmere coastal chronicle.'},
      canonStatus: CanonStatus.deprecated,
    ),
    _record(
      'noxmere-fall',
      'historical-event',
      'Fall of Noxmere',
      timestamp,
      fields: const {'summary': 'A Noxmere timeline event.'},
      canonStatus: CanonStatus.alternate,
    ),
    _record(
      'project-a-secret',
      'secret',
      'Project A Secret',
      timestamp,
      fields: const {'content': 'sharedsecret'},
    ),
    for (final status in CanonStatus.values)
      _record(
        'status-${status.name}',
        'general-lore',
        'Status ${status.name}',
        timestamp,
        fields: const {'content': 'statusprobe'},
        canonStatus: status,
      ),
    _record(
      'project-b-secret',
      'secret',
      'Project B Secret',
      timestamp,
      projectId: 'project-b',
      fields: const {'content': 'sharedsecret Noxmere'},
    ),
  ];
  final branchRelic = _record(
    'branch-relic',
    'item',
    'Branch Relic',
    timestamp,
    scopeType: RecordScopeType.branch,
    scopeId: 'branch-a',
    branchId: 'branch-a',
    canonStatus: CanonStatus.alternate,
    fields: const {'summary': 'branchrelic carried in the alternate ending.'},
  );
  return ConnectedDomainSnapshot(
    records: records,
    manuscriptNodes: [
      ManuscriptNodeReference(
        id: 'scene-noxmere',
        projectId: 'project-a',
        nodeType: 'scene',
        title: 'Noxmere Meeting',
        createdAt: timestamp,
        updatedAt: timestamp,
        extensionData: const {'content': 'The ember meeting at Noxmere.'},
      ),
      ManuscriptNodeReference(
        id: 'chapter-noxmere',
        projectId: 'project-a',
        nodeType: 'chapter',
        title: 'Noxmere Chapter',
        createdAt: timestamp,
        updatedAt: timestamp,
        extensionData: const {'prompt': 'Return to Noxmere.'},
      ),
    ],
    links: const [],
    branches: [
      StoryBranch(
        id: 'branch-a',
        projectId: 'project-a',
        name: 'What if Kali never left?',
        kind: BranchKind.whatIf,
        createdAt: timestamp,
      ),
      StoryBranch(
        id: 'branch-b',
        projectId: 'project-a',
        name: 'Alternate ending',
        kind: BranchKind.alternateEnding,
        createdAt: timestamp,
      ),
    ],
    branchRecordOverlays: [
      BranchRecordOverlay(
        branchId: 'branch-a',
        recordId: 'kali',
        state: BranchRecordState.overridden,
        title: 'Kali Remained',
        fields: const {'alternatePath': 'neverleft Endovier'},
        canonStatus: CanonStatus.alternate,
        updatedAt: timestamp,
      ),
      BranchRecordOverlay(
        branchId: 'branch-a',
        recordId: 'noxmere-harbor',
        state: BranchRecordState.hidden,
        updatedAt: timestamp,
      ),
      BranchRecordOverlay(
        branchId: 'branch-a',
        recordId: branchRelic.id,
        state: BranchRecordState.created,
        createdRecord: branchRelic,
        updatedAt: timestamp,
      ),
      BranchRecordOverlay(
        branchId: 'branch-b',
        recordId: 'widow-network',
        state: BranchRecordState.overridden,
        fields: const {'alternatePath': 'foreignbranch conclusion'},
        updatedAt: timestamp,
      ),
    ],
    branchLinkOverlays: const [],
  );
}

AuthorRecord _record(
  String id,
  String typeId,
  String title,
  DateTime timestamp, {
  String projectId = 'project-a',
  RecordScopeType scopeType = RecordScopeType.project,
  String? scopeId,
  String? seriesId,
  String? bookId,
  String? branchId,
  CanonStatus canonStatus = CanonStatus.canon,
  String? templateId,
  Map<String, Object?> fields = const {},
  List<String> tags = const [],
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: scopeType,
      scopeId: scopeId ?? projectId,
      projectId: projectId,
      seriesId: seriesId,
      bookId: bookId,
      branchId: branchId,
      canonStatus: canonStatus,
      title: title,
      templateId: templateId,
      templateVersion: templateId == null ? null : 1,
      fields: fields,
      tags: tags,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
