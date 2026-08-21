import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/core/version_audit.dart';
import 'package:author_studio_v1/migrations/legacy_research_store.dart';
import 'package:author_studio_v1/migrations/research_migration.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 8, 21, 9);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
  });

  tearDown(() => database.close());

  LegacyResearchMigrationService serviceFor(
    String projectId, {
    DriftConnectedDomainRepository? overrideRepository,
  }) =>
      LegacyResearchMigrationService(
        projectId: projectId,
        repository: overrideRepository ?? repository,
      );

  test('an empty legacy store migrates cleanly and creates no records',
      () async {
    final outcome = await serviceFor('project-a').migrate(timestamp: timestamp);

    expect(outcome.legacyEntryCount, 0);
    expect(outcome.migratedCount, 0);
    expect(outcome.failures, isEmpty);
    expect(outcome.completed, isTrue);
    expect(await repository.recordsByScope('project-a'), isEmpty);
    expect(
      await const ResearchMigrationState(projectId: 'project-a').isComplete(),
      isTrue,
    );
  });

  test('one legacy entry becomes one canonical research-entry record',
      () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(
          title: 'Bridge district lore',
          detail: 'Lanterns and rain on slate roads.',
          tag: 'World',
        ),
      ],
    });

    final outcome = await serviceFor('project-a').migrate(timestamp: timestamp);
    final record = (await repository.recordsByScope('project-a')).single;

    expect(outcome.migratedCount, 1);
    expect(outcome.completed, isTrue);
    expect(record.typeId, researchRecordTypeId);
    expect(record.title, 'Bridge district lore');
    expect(record.fields['name'], 'Bridge district lore');
    expect(record.fields['summary'], 'Lanterns and rain on slate roads.');
    expect(
      record.fields[CodexFields.summary],
      'Lanterns and rain on slate roads.',
    );
    expect(record.tags, ['World']);
    expect(record.scopeType, RecordScopeType.project);
    expect(record.scopeId, 'project-a');
    expect(record.projectId, 'project-a');
    expect(record.status, AuthorRecordStatus.active);
    expect(isMigratedResearchRecord(record), isTrue);
    expect(migratedResearchLegacyTab(record), 'research');
  });

  test('every legacy entry across every tab is migrated', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'A', detail: 'a', tag: 'research'),
        ResearchReference(title: 'B', detail: 'b', tag: 'research'),
      ],
      ResearchTab.notes: const [
        ResearchReference(title: 'C', detail: 'c', tag: 'notes'),
      ],
      ResearchTab.timeline: const [
        ResearchReference(title: 'D', detail: 'd', tag: 'timeline'),
      ],
    });

    final outcome = await serviceFor('project-a').migrate(timestamp: timestamp);
    final records = await repository.recordsByScope('project-a');

    expect(outcome.legacyEntryCount, 4);
    expect(outcome.migratedCount, 4);
    expect(records.map((record) => record.title), ['A', 'B', 'C', 'D']);
    expect(
      records.map(migratedResearchLegacyTab),
      ['research', 'research', 'notes', 'timeline'],
    );
  });

  test('the legacy tab is preserved because the schema has no field for it',
      () async {
    await _seed('project-a', {
      ResearchTab.timeline: const [
        ResearchReference(title: 'Fall of the bridge', detail: '', tag: ''),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    final record = (await repository.recordsByScope('project-a')).single;
    final provenance =
        record.extensionData[researchMigrationExtensionKey] as Map;

    expect(provenance['legacyTab'], 'timeline');
    expect(provenance['legacyTag'], '');
    expect(provenance['version'], researchMigrationVersion);
    expect(provenance['source'], ProjectResearchStore.keyPrefix);
    expect(provenance['legacyKey'], isNotEmpty);
  });

  test('separate projects never receive each other\'s research', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(
          title: 'Shared title',
          detail: 'Belongs to A.',
          tag: 'A',
        ),
      ],
    });
    await _seed('project-b', {
      ResearchTab.research: const [
        ResearchReference(
          title: 'Shared title',
          detail: 'Belongs to B.',
          tag: 'B',
        ),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    await serviceFor('project-b').migrate(timestamp: timestamp);

    final a = await repository.recordsByScope('project-a');
    final b = await repository.recordsByScope('project-b');

    expect(a.single.fields['summary'], 'Belongs to A.');
    expect(b.single.fields['summary'], 'Belongs to B.');
    expect(a.single.id, isNot(b.single.id));
    expect(a.single.projectId, 'project-a');
    expect(b.single.projectId, 'project-b');
  });

  test('migrating one project leaves another project unmigrated', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'A only', detail: '', tag: ''),
      ],
    });
    await _seed('project-b', {
      ResearchTab.research: const [
        ResearchReference(title: 'B only', detail: '', tag: ''),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);

    expect(await repository.recordsByScope('project-b'), isEmpty);
    expect(
      await const ResearchMigrationState(projectId: 'project-b').isComplete(),
      isFalse,
    );
  });

  test('entries sharing a title both survive as distinct records', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Notes', detail: 'First.', tag: ''),
        ResearchReference(title: 'Notes', detail: 'Second.', tag: ''),
      ],
    });

    final outcome = await serviceFor('project-a').migrate(timestamp: timestamp);
    final records = await repository.recordsByScope('project-a');

    expect(outcome.migratedCount, 2);
    expect(records, hasLength(2));
    expect(
      records.map((record) => record.fields['summary']).toSet(),
      {'First.', 'Second.'},
    );
  });

  test('byte-identical entries both survive and keep stable identities',
      () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Same', detail: 'Same.', tag: 'same'),
        ResearchReference(title: 'Same', detail: 'Same.', tag: 'same'),
      ],
    });

    final first = await serviceFor('project-a').migrate(timestamp: timestamp);
    expect(first.migratedCount, 2);

    // Re-run against a cleared marker: the same two identities resolve to the
    // same two records, so nothing is duplicated.
    await _clearMarker('project-a');
    final second = await serviceFor('project-a').migrate(timestamp: timestamp);

    expect(second.migratedCount, 0);
    expect(second.skippedCount, 2);
    expect(await repository.recordsByScope('project-a'), hasLength(2));
  });

  test('an entry with no title falls back rather than failing validation',
      () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: '   ', detail: 'Detail survives.', tag: ''),
      ],
    });

    final outcome = await serviceFor('project-a').migrate(timestamp: timestamp);
    final record = (await repository.recordsByScope('project-a')).single;

    expect(outcome.failures, isEmpty);
    expect(record.title, researchMigrationFallbackTitle);
    expect(record.fields['summary'], 'Detail survives.');
  });

  test('an empty detail is allowed and an empty tag creates no phantom tag',
      () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Bare entry', detail: '', tag: '  '),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    final record = (await repository.recordsByScope('project-a')).single;

    expect(record.tags, isEmpty);
    expect(record.fields.containsKey('summary'), isFalse);
    expect(record.fields.containsKey(CodexFields.summary), isFalse);
    expect(record.title, 'Bare entry');
  });

  test('special characters, unicode, and line breaks survive verbatim',
      () async {
    const title = 'The "Ashfall" Ledger — Sørensen\'s copy ✦';
    const detail = 'Line one.\nLine two: «quoted», 100% — ünïcode ✧\n\tTabbed.';
    await _seed('project-a', {
      ResearchTab.notes: const [
        ResearchReference(title: title, detail: detail, tag: 'réf'),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    final record = (await repository.recordsByScope('project-a')).single;

    expect(record.title, title);
    expect(record.fields['summary'], detail);
    expect(record.tags, ['réf']);
  });

  test('very long research notes are stored without truncation', () async {
    final detail = List<String>.generate(
      4000,
      (index) => 'paragraph-$index',
    ).join('\n');
    await _seed('project-a', {
      ResearchTab.research: [
        ResearchReference(title: 'Long', detail: detail, tag: ''),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    final record = (await repository.recordsByScope('project-a')).single;

    expect((record.fields['summary'] as String).length, detail.length);
    expect(record.fields['summary'], detail);
  });

  test('a legacy entry always resolves to the same record id', () async {
    const reference = ResearchReference(
      title: 'Deterministic',
      detail: 'Same input, same id.',
      tag: 'x',
    );
    await _seed('project-a', {
      ResearchTab.research: const [reference],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    final firstId = (await repository.recordsByScope('project-a')).single.id;

    // A fresh database and a fresh marker, same legacy payload. Two database
    // instances in one test is deliberate here, not the race drift warns about.
    final warned = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = warned,
    );
    final second = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(second.close);
    final secondRepository = DriftConnectedDomainRepository(second);
    await _clearMarker('project-a');
    await LegacyResearchMigrationService(
      projectId: 'project-a',
      repository: secondRepository,
    ).migrate(timestamp: timestamp.add(const Duration(days: 30)));

    expect(
      (await secondRepository.recordsByScope('project-a')).single.id,
      firstId,
    );
    expect(firstId, startsWith('research-legacy-'));
  });

  test('the identity is not title-based', () {
    final sameTitle = legacyResearchKey(
      projectId: 'project-a',
      tab: ResearchTab.research,
      contentDigest: 'digest-one',
      occurrence: 0,
    );
    final otherContent = legacyResearchKey(
      projectId: 'project-a',
      tab: ResearchTab.research,
      contentDigest: 'digest-two',
      occurrence: 0,
    );
    final otherProject = legacyResearchKey(
      projectId: 'project-b',
      tab: ResearchTab.research,
      contentDigest: 'digest-one',
      occurrence: 0,
    );
    final otherTab = legacyResearchKey(
      projectId: 'project-a',
      tab: ResearchTab.notes,
      contentDigest: 'digest-one',
      occurrence: 0,
    );
    final otherOccurrence = legacyResearchKey(
      projectId: 'project-a',
      tab: ResearchTab.research,
      contentDigest: 'digest-one',
      occurrence: 1,
    );

    expect(
      {
        researchRecordIdFor(sameTitle),
        researchRecordIdFor(otherContent),
        researchRecordIdFor(otherProject),
        researchRecordIdFor(otherTab),
        researchRecordIdFor(otherOccurrence),
      },
      hasLength(5),
    );
  });

  test('running the migration twice creates no duplicate records', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'One', detail: '1', tag: 'a'),
        ResearchReference(title: 'Two', detail: '2', tag: 'b'),
      ],
    });

    final first = await serviceFor('project-a').migrate(timestamp: timestamp);
    final second = await serviceFor('project-a').migrate(timestamp: timestamp);

    expect(first.migratedCount, 2);
    expect(second.alreadyComplete, isTrue);
    expect(second.migratedCount, 0);
    expect(await repository.recordsByScope('project-a'), hasLength(2));
  });

  test('a lost marker still does not duplicate migrated records', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'One', detail: '1', tag: 'a'),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    await _clearMarker('project-a');
    final second = await serviceFor('project-a').migrate(timestamp: timestamp);

    expect(second.alreadyComplete, isFalse);
    expect(second.migratedCount, 0);
    expect(second.skippedCount, 1);
    expect(second.completed, isTrue);
    expect(await repository.recordsByScope('project-a'), hasLength(1));
  });

  test('a partial failure leaves the migration incomplete and resumable',
      () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Keeps', detail: 'ok', tag: ''),
        ResearchReference(title: 'Breaks', detail: 'boom', tag: ''),
        ResearchReference(title: 'Also keeps', detail: 'ok', tag: ''),
      ],
    });
    final flaky = _FlakyRepository(database, failingTitles: {'Breaks'});

    final first = await serviceFor(
      'project-a',
      overrideRepository: flaky,
    ).migrate(timestamp: timestamp);

    expect(first.migratedCount, 2);
    expect(first.failureCount, 1);
    expect(first.completed, isFalse);
    expect(first.failures.single.title, 'Breaks');
    expect(
      await const ResearchMigrationState(projectId: 'project-a').isComplete(),
      isFalse,
    );
    expect(await repository.recordsByScope('project-a'), hasLength(2));

    // Retry: the two that landed are skipped, the third is created.
    flaky.armed = false;
    final second = await serviceFor(
      'project-a',
      overrideRepository: flaky,
    ).migrate(timestamp: timestamp);

    expect(second.skippedCount, 2);
    expect(second.migratedCount, 1);
    expect(second.completed, isTrue);
    expect(
      await const ResearchMigrationState(projectId: 'project-a').isComplete(),
      isTrue,
    );
    final titles =
        (await repository.recordsByScope('project-a')).map((r) => r.title);
    expect(titles, containsAll(['Keeps', 'Breaks', 'Also keeps']));
  });

  test('a failed migration never deletes the legacy data', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Breaks', detail: 'boom', tag: ''),
      ],
    });
    final flaky = _FlakyRepository(database, failingTitles: {'Breaks'});

    await serviceFor('project-a', overrideRepository: flaky)
        .migrate(timestamp: timestamp);
    final legacy =
        await const ProjectResearchStore(projectId: 'project-a').load();

    expect(legacy[ResearchTab.research], hasLength(1));
    expect(legacy[ResearchTab.research]!.single.title, 'Breaks');
  });

  test('a successful migration also retains the legacy data', () async {
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Kept', detail: 'Still here.', tag: 'a'),
      ],
    });

    await serviceFor('project-a').migrate(timestamp: timestamp);
    final legacy =
        await const ProjectResearchStore(projectId: 'project-a').load();

    expect(legacy[ResearchTab.research], hasLength(1));
    expect(legacy[ResearchTab.research]!.single.detail, 'Still here.');
  });

  test('research the author created independently is never touched', () async {
    final records =
        RecordService(projectId: 'project-a', repository: repository);
    final authored = await records.createRecord(_authoredResearch());
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Legacy entry', detail: 'legacy', tag: ''),
      ],
    });

    final outcome = await serviceFor('project-a').migrate(timestamp: timestamp);
    final reloaded = await repository.recordById(authored.id);

    expect(outcome.migratedCount, 1);
    expect(reloaded!.title, authored.title);
    expect(reloaded.revision, authored.revision);
    expect(reloaded.fields['summary'], 'Written in the record system.');
    expect(isMigratedResearchRecord(reloaded), isFalse);
    expect(await repository.recordsByScope('project-a'), hasLength(2));
  });

  test('the marker records the migration version and gates re-reads', () async {
    const state = ResearchMigrationState(projectId: 'project-a');

    expect(state.storageKey, 'author_studio.research_migration.project-a');
    expect(await state.completedVersion(), 0);

    await serviceFor('project-a').migrate(timestamp: timestamp);

    expect(await state.completedVersion(), researchMigrationVersion);
    expect(await state.isComplete(), isTrue);
  });

  test('migratedRecords reports only records this migration created',
      () async {
    final records =
        RecordService(projectId: 'project-a', repository: repository);
    await records.createRecord(_authoredResearch());
    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'From the panel', detail: '', tag: ''),
      ],
    });

    final service = serviceFor('project-a');
    await service.migrate(timestamp: timestamp);

    expect(
      (await service.migratedRecords()).map((record) => record.title),
      ['From the panel'],
    );
  });
}

Future<void> _seed(
  String projectId,
  Map<ResearchTab, List<ResearchReference>> references,
) =>
    ProjectResearchStore(projectId: projectId).save(references);

Future<void> _clearMarker(String projectId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(ResearchMigrationState(projectId: projectId).storageKey);
}

AuthorRecord _authoredResearch() => AuthorRecord(
      id: 'authored-research',
      typeId: researchRecordTypeId,
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      title: 'Author written research',
      templateId: researchRecordTypeId,
      templateVersion: 1,
      fields: const {
        'name': 'Author written research',
        'summary': 'Written in the record system.',
      },
      createdAt: timestamp,
      updatedAt: timestamp,
    );

/// A repository that refuses to persist named records, so a partial migration
/// can be observed without corrupting the database.
class _FlakyRepository extends DriftConnectedDomainRepository {
  _FlakyRepository(super.database, {required this.failingTitles});

  final Set<String> failingTitles;
  bool armed = true;

  @override
  Future<void> putRecordWithHistory({
    required AuthorRecord record,
    required Iterable<RecordLink> links,
    required RecordVersion version,
    required AuditEvent auditEvent,
  }) {
    if (armed && failingTitles.contains(record.title)) {
      throw StateError('Simulated write failure for ${record.title}.');
    }
    return super.putRecordWithHistory(
      record: record,
      links: links,
      version: version,
      auditEvent: auditEvent,
    );
  }
}
