import 'dart:io';

import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/migrations/legacy_research_store.dart';
import 'package:author_studio_v1/migrations/research_migration.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final timestamp = DateTime.utc(2026, 8, 21, 9);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDown(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  test('migrated research survives a database close and reopen', () async {
    final directory = await Directory.systemTemp.createTemp('research-mig');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/authoros.sqlite');

    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(
          title: 'Salt roads',
          detail: 'Carts leave before the tide.',
          tag: 'World',
        ),
      ],
    });

    final first = AuthorOsDatabase(NativeDatabase(file));
    await LegacyResearchMigrationService(
      projectId: 'project-a',
      repository: DriftConnectedDomainRepository(first),
    ).migrate(timestamp: timestamp);
    await first.close();

    final second = AuthorOsDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final reopened =
        await DriftConnectedDomainRepository(second).recordsByScope('project-a');

    expect(reopened.single.title, 'Salt roads');
    expect(reopened.single.fields['summary'], 'Carts leave before the tide.');
    expect(isMigratedResearchRecord(reopened.single), isTrue);
  });

  test('project isolation holds after a reload', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);

    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Ledger', detail: 'A side.', tag: ''),
      ],
    });
    await _seed('project-b', {
      ResearchTab.research: const [
        ResearchReference(title: 'Ledger', detail: 'B side.', tag: ''),
      ],
    });

    await LegacyResearchMigrationService(
      projectId: 'project-a',
      repository: repository,
    ).migrate(timestamp: timestamp);
    await LegacyResearchMigrationService(
      projectId: 'project-b',
      repository: repository,
    ).migrate(timestamp: timestamp);

    final aRecords =
        RecordService(projectId: 'project-a', repository: repository);
    final bRecords =
        RecordService(projectId: 'project-b', repository: repository);
    final a = (await repository.recordsByScope('project-a')).single;
    final b = (await repository.recordsByScope('project-b')).single;

    expect(await aRecords.getRecord(b.id), isNull);
    expect(await bRecords.getRecord(a.id), isNull);
    expect((await aRecords.searchRecords('Ledger')).single.id, a.id);
    expect((await bRecords.searchRecords('Ledger')).single.id, b.id);
  });

  test('migrated research archives, restores, edits, duplicates, and deletes',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);
    final records =
        RecordService(projectId: 'project-a', repository: repository);

    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Tide tables', detail: 'Spring.', tag: 'sea'),
      ],
    });
    await LegacyResearchMigrationService(
      projectId: 'project-a',
      repository: repository,
    ).migrate(timestamp: timestamp);
    final id = (await repository.recordsByScope('project-a')).single.id;

    final archived = await records.archiveRecord(id, timestamp: timestamp);
    expect(archived.status, AuthorRecordStatus.archived);

    final restored = await records.restoreRecord(id, timestamp: timestamp);
    expect(restored.status, AuthorRecordStatus.active);

    final edited = await records.updateRecord(
      restored.copyWith(
        title: 'Tide tables, revised',
        fields: {...restored.fields, 'summary': 'Spring and neap.'},
        tags: [...restored.tags, 'revised'],
        updatedAt: timestamp.add(const Duration(minutes: 1)),
      ),
    );
    expect(edited.title, 'Tide tables, revised');
    expect(edited.fields['summary'], 'Spring and neap.');
    expect(edited.tags, ['sea', 'revised']);
    // Editing must not strip the provenance the migration relies on.
    expect(isMigratedResearchRecord(edited), isTrue);

    final duplicate = await records.duplicateRecord(
      id,
      newId: '$id-copy',
      timestamp: timestamp.add(const Duration(minutes: 2)),
    );
    expect(duplicate.typeId, researchRecordTypeId);
    expect(duplicate.fields['summary'], 'Spring and neap.');

    final deleted = await records.deleteRecord(
      id,
      timestamp: timestamp.add(const Duration(minutes: 3)),
    );
    expect(deleted.status, AuthorRecordStatus.deleted);
  });

  test('a deleted migrated record is not resurrected by a re-run', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);
    final records =
        RecordService(projectId: 'project-a', repository: repository);

    await _seed('project-a', {
      ResearchTab.research: const [
        ResearchReference(title: 'Discarded', detail: '', tag: ''),
      ],
    });
    final service = LegacyResearchMigrationService(
      projectId: 'project-a',
      repository: repository,
    );
    await service.migrate(timestamp: timestamp);
    final id = (await repository.recordsByScope('project-a')).single.id;
    await records.deleteRecord(id, timestamp: timestamp);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(
      const ResearchMigrationState(projectId: 'project-a').storageKey,
    );
    final rerun = await service.migrate(timestamp: timestamp);

    expect(rerun.migratedCount, 0);
    expect(rerun.skippedCount, 1);
    expect(
      (await repository.recordById(id))!.status,
      AuthorRecordStatus.deleted,
    );
  });

  test('migrated research is exported and restored by the project archive',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftConnectedDomainRepository(database);

    await _seed('project-a', {
      ResearchTab.notes: const [
        ResearchReference(
          title: 'Harbour customs',
          detail: 'Tolls doubled after the flood.',
          tag: 'World',
        ),
      ],
    });
    await LegacyResearchMigrationService(
      projectId: 'project-a',
      repository: repository,
    ).migrate(timestamp: timestamp);

    const archive = AuthorOsArchiveService();
    final bytes = archive.exportSnapshot(
      await repository.snapshot(),
      archiveId: 'archive-1',
      rootId: 'project-a',
      applicationVersion: '1.0.0',
      platform: 'linux',
      createdAt: timestamp,
    );
    final restored = archive.importSnapshot(bytes);
    final exported = restored.records
        .where((record) => record.typeId == researchRecordTypeId)
        .toList();

    expect(exported, hasLength(1));
    expect(exported.single.title, 'Harbour customs');
    expect(exported.single.fields['summary'], 'Tolls doubled after the flood.');
    expect(exported.single.tags, ['World']);
    expect(isMigratedResearchRecord(exported.single), isTrue);
    expect(migratedResearchLegacyTab(exported.single), 'notes');

    // And the same records come back when the snapshot is restored.
    final target = AuthorOsDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    final targetRepository = DriftConnectedDomainRepository(target);
    await targetRepository.replaceSnapshot(restored);

    final reloaded = await targetRepository.recordsByScope('project-a');
    expect(reloaded.single.title, 'Harbour customs');
    expect(reloaded.single.fields['summary'], 'Tolls doubled after the flood.');
  });
}

Future<void> _seed(
  String projectId,
  Map<ResearchTab, List<ResearchReference>> references,
) =>
    ProjectResearchStore(projectId: projectId).save(references);
