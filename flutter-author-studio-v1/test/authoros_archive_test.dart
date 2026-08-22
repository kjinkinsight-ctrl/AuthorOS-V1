import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_types.dart';
import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/scene_prose.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AuthorOsArchiveService();

  test('archive round trip preserves IDs, links, and unknown extension data',
      () {
    final source = _snapshot();
    final bytes = _export(service, source, archiveId: 'archive-1');
    final restored = service.importSnapshot(bytes);

    expect(restored.records.single.id, 'character-ari');
    expect(restored.records.single.templateId, 'protagonist');
    expect(restored.records.single.templateVersion, 1);
    expect(restored.manuscriptNodes.single.id, 'scene-opening');
    expect(restored.links.single.id, 'link-ari-opening');
    expect(
      restored.recordTypeDefinitions.map((definition) => definition.id),
      ['case', 'magic-spell'],
    );
    expect(
      restored
          .recordTypeDefinitions.last.extensionData['futureTemplateSetting'],
      isTrue,
    );
    expect(
      restored.records.single.extensionData['futureField'],
      {'retained': true},
    );
    expect(restored.connectionTypeDefinitions.single.id, 'swornTo');
    expect(restored.connectionTypeDefinitions.single.scopeId, 'project-1');
  });

  test('an archive carries the book, not only the graph describing it', () {
    // A backup that restored every fact about a manuscript except its words
    // would not be a backup.
    final restored = service.importSnapshot(
      _export(service, _snapshot(), archiveId: 'archive-prose'),
    );

    final prose = restored.sceneProse.single;
    expect(prose.sceneId, 'scene-opening');
    expect(prose.chapterId, 'chapter-1');
    expect(prose.revision, 3);
    expect(
      prose.plainText,
      'The message arrived at dawn.\n\nAri did not open it.',
    );
    expect(prose.wordCount, 10);
  });

  test('an archive written before prose moved into the database still loads',
      () {
    // Round-tripping a snapshot that has no prose entry at all is what an
    // older archive looks like on import.
    final legacy = ConnectedDomainSnapshot(
      records: _snapshot().records,
      manuscriptNodes: _snapshot().manuscriptNodes,
      links: _snapshot().links,
    );
    final restored = service.importSnapshot(
      _export(service, legacy, archiveId: 'archive-legacy'),
    );
    expect(restored.sceneProse, isEmpty);
    expect(restored.manuscriptNodes.single.id, 'scene-opening');
  });

  test('unchanged creative content has a stable fingerprint', () {
    final source = _snapshot();
    final first = _manifest(
      _export(service, source, archiveId: 'archive-1'),
    );
    final second = _manifest(
      service.exportSnapshot(
        source,
        archiveId: 'archive-2',
        rootId: 'project-1',
        applicationVersion: '2.0.0',
        platform: 'android',
        createdAt: DateTime.utc(2026, 8, 18),
      ),
    );

    expect(first['archiveId'], isNot(second['archiveId']));
    expect(first['createdAt'], isNot(second['createdAt']));
    expect(first['contentFingerprint'], second['contentFingerprint']);
  });

  test('checksum corruption is rejected before commit', () async {
    final valid = _export(service, _snapshot(), archiveId: 'archive-1');
    final archive = ZipDecoder().decodeBytes(valid);
    final records = archive.find('data/records.jsonl')!;
    archive.add(ArchiveFile.string(
      records.name,
      '${utf8.decode(records.readBytes()!)}\n{"id":"injected"}',
    ));
    final corrupted = ZipEncoder().encodeBytes(archive);
    var committed = false;

    await expectLater(
      service.importAndCommit(corrupted, (snapshot) async {
        committed = true;
      }),
      throwsFormatException,
    );
    expect(committed, isFalse);
  });

  test('path traversal is rejected', () {
    final archive = Archive()
      ..add(ArchiveFile.string('../outside.txt', 'unsafe'));
    final bytes = ZipEncoder().encodeBytes(archive);

    expect(() => service.importSnapshot(bytes), throwsFormatException);
  });

  test('dangling canonical links are rejected after integrity validation', () {
    final source = _snapshot();
    final invalid = ConnectedDomainSnapshot(
      records: source.records,
      manuscriptNodes: const [],
      links: source.links,
    );

    expect(
      () => _export(service, invalid, archiveId: 'archive-invalid'),
      throwsStateError,
    );
  });

  test('corrupted import leaves an already restored Drift database unchanged',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    final repository = DriftConnectedDomainRepository(database);
    final valid = _export(service, _snapshot(), archiveId: 'archive-valid');

    await service.importAndCommit(valid, repository.replaceSnapshot);
    expect(
      (await repository.recordById('character-ari'))?.title,
      'Ari Vale',
    );

    final archive = ZipDecoder().decodeBytes(valid);
    archive.add(
      ArchiveFile.string('data/links.jsonl', '{"id":"corrupt"}\n'),
    );
    final corrupted = ZipEncoder().encodeBytes(archive);
    await expectLater(
      service.importAndCommit(corrupted, repository.replaceSnapshot),
      throwsFormatException,
    );

    final unchanged = await repository.snapshot();
    expect(unchanged.records.single.id, 'character-ari');
    expect(unchanged.links.single.id, 'link-ari-opening');
    await database.close();
  });
}

Uint8List _export(
  AuthorOsArchiveService service,
  ConnectedDomainSnapshot snapshot, {
  required String archiveId,
}) =>
    service.exportSnapshot(
      snapshot,
      archiveId: archiveId,
      rootId: 'project-1',
      applicationVersion: '2.0.0',
      platform: 'windows',
      createdAt: DateTime.utc(2026, 8, 17),
    );

Map<String, dynamic> _manifest(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  return Map<String, dynamic>.from(
    jsonDecode(utf8.decode(archive.find('manifest.json')!.readBytes()!)) as Map,
  );
}

ConnectedDomainSnapshot _snapshot() {
  final timestamp = DateTime.utc(2026, 8, 17);
  return ConnectedDomainSnapshot(
    records: [
      AuthorRecord(
        id: 'character-ari',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: 'project-1',
        title: 'Ari Vale',
        templateId: 'protagonist',
        templateVersion: 1,
        fields: const {'summary': 'A harbor cartographer.'},
        tags: const ['protagonist'],
        createdAt: timestamp,
        updatedAt: timestamp,
        extensionData: const {
          'futureField': {'retained': true},
        },
      ),
    ],
    manuscriptNodes: [
      ManuscriptNodeReference(
        id: 'scene-opening',
        projectId: 'project-1',
        nodeType: 'scene',
        title: 'The Message',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ],
    sceneProse: [
      SceneProse(
        sceneId: 'scene-opening',
        projectId: 'project-1',
        chapterId: 'chapter-1',
        document: ProseDocument.fromPlainText(
          'The message arrived at dawn.\n\nAri did not open it.',
        ),
        updatedAt: timestamp,
        revision: 3,
      ),
    ],
    links: [
      RecordLink(
        id: 'link-ari-opening',
        sourceId: 'character-ari',
        targetId: 'scene-opening',
        typeId: 'appearsIn',
        scopeId: 'project-1',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ],
    recordTypeDefinitions: const [
      RecordTypeDefinition(
        id: 'magic-spell',
        name: 'Magic Spell',
        categoryId: 'magic',
        fields: [
          RecordFieldDefinition(
            id: 'cost',
            label: 'Cost',
            type: RecordFieldType.shortText,
            order: 0,
            required: true,
          ),
        ],
        sections: [
          RecordTemplateSection(
            id: 'rules',
            title: 'Rules',
            order: 0,
            fieldIds: ['cost'],
          ),
        ],
        extensionData: {'futureTemplateSetting': true},
      ),
      RecordTypeDefinition(
        id: 'case',
        name: 'Case',
        categoryId: 'plot',
        fields: [
          RecordFieldDefinition(
            id: 'caseNumber',
            label: 'Case number',
            type: RecordFieldType.shortText,
            order: 0,
            required: true,
          ),
        ],
        sections: [
          RecordTemplateSection(
            id: 'identity',
            title: 'Identity',
            order: 0,
            fieldIds: ['caseNumber'],
          ),
        ],
      ),
    ],
    connectionTypeDefinitions: const [
      ConnectionTypeDefinition(
        id: 'swornTo',
        displayName: 'Sworn to',
        sourceTypeIds: ['character'],
        targetTypeIds: ['character', 'faction'],
        inverseLabel: 'Holds oath from',
        scopeId: 'project-1',
        sourcePackId: 'user',
        extensionData: {'futureRule': true},
      ),
    ],
  );
}
