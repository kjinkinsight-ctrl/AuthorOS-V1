import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_service.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/record_validation.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late RecordService records;

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    records = RecordService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  test('shared CRUD preserves identity, lifecycle, and duplicate provenance',
      () async {
    final timestamp = DateTime.utc(2026, 8, 19);
    final created = await records.createRecord(_character(
      id: 'kali',
      projectId: 'project-a',
      name: 'Kali Vale',
      timestamp: timestamp,
    ));
    final updated = await records.updateRecord(created.copyWith(
      title: 'Kali Vale Revised',
      updatedAt: timestamp.add(const Duration(minutes: 1)),
    ));
    final archived = await records.archiveRecord(
      created.id,
      timestamp: timestamp.add(const Duration(minutes: 2)),
    );
    final restored = await records.restoreRecord(
      created.id,
      timestamp: timestamp.add(const Duration(minutes: 3)),
    );
    final duplicate = await records.duplicateRecord(
      created.id,
      newId: 'kali-copy',
      timestamp: timestamp.add(const Duration(minutes: 4)),
    );
    final deleted = await records.deleteRecord(
      created.id,
      timestamp: timestamp.add(const Duration(minutes: 5)),
    );

    expect(updated.id, created.id);
    expect(updated.createdAt, created.createdAt);
    expect(updated.revision, 2);
    expect(archived.status, AuthorRecordStatus.archived);
    expect(restored.status, AuthorRecordStatus.active);
    expect(duplicate.extensionData['duplicatedFrom'], created.id);
    expect(duplicate.revision, 1);
    expect(deleted.status, AuthorRecordStatus.deleted);
    expect((await records.searchRecords('Kali')).single.id, 'kali-copy');
  });

  test('validation rejects unknown types, missing fields, and other projects',
      () async {
    final timestamp = DateTime.utc(2026, 8, 19);
    final missingName = _character(
      id: 'invalid',
      projectId: 'project-a',
      name: '',
      timestamp: timestamp,
    );

    await expectLater(
      records.createRecord(missingName),
      throwsA(isA<RecordValidationException>()),
    );
    await expectLater(
      records.createRecord(AuthorRecord(
        id: 'unknown',
        typeId: 'unknown-type',
        scopeType: RecordScopeType.project,
        scopeId: 'project-a',
        title: 'Unknown',
        createdAt: timestamp,
        updatedAt: timestamp,
      )),
      throwsA(isA<RecordValidationException>()),
    );
    await expectLater(
      records.createRecord(_character(
        id: 'project-b-character',
        projectId: 'project-b',
        name: 'Other Project',
        timestamp: timestamp,
      )),
      throwsA(isA<RecordValidationException>()),
    );
  });

  test('record and links save atomically and reject unrelated links', () async {
    final timestamp = DateTime.utc(2026, 8, 19);
    await records.createRecord(_character(
      id: 'cassian',
      projectId: 'project-a',
      name: 'Cassian',
      timestamp: timestamp,
    ));
    final kali = _character(
      id: 'kali',
      projectId: 'project-a',
      name: 'Kali',
      timestamp: timestamp,
    );
    final link = RecordLink(
      id: 'related-kali-cassian',
      sourceId: 'kali',
      targetId: 'cassian',
      typeId: 'relatedTo',
      scopeId: 'project-a',
      direction: RecordLinkDirection.undirected,
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    await records.createRecord(kali, links: [link]);
    expect((await repository.backlinks('kali')).single.id, link.id);

    await expectLater(
      records.createRecord(
        _character(
          id: 'third',
          projectId: 'project-a',
          name: 'Third',
          timestamp: timestamp,
        ),
        links: [link],
      ),
      throwsStateError,
    );
    expect(await repository.recordById('third'), isNull);
  });

  test('invalid typed connection rolls back the candidate record', () async {
    final timestamp = DateTime.utc(2026, 8, 19);
    await records.createRecord(_character(
      id: 'cassian',
      projectId: 'project-a',
      name: 'Cassian',
      timestamp: timestamp,
    ));
    final invalid = RecordLink(
      id: 'invalid-residence',
      sourceId: 'kali',
      targetId: 'cassian',
      typeId: 'livesIn',
      scopeId: 'project-a',
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    await expectLater(
      records.createRecord(
        _character(
          id: 'kali',
          projectId: 'project-a',
          name: 'Kali',
          timestamp: timestamp,
        ),
        links: [invalid],
      ),
      throwsStateError,
    );
    expect(await repository.recordById('kali'), isNull);
    expect(await repository.backlinks('cassian'), isEmpty);
  });

  test('explicit child template requirements are validated', () async {
    const protagonist = RecordTypeDefinition(
      id: 'protagonist',
      name: 'Protagonist',
      categoryId: 'characters',
      baseTypeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      fields: [
        RecordFieldDefinition(
          id: 'centralGoal',
          label: 'Central goal',
          type: RecordFieldType.longText,
          order: 200,
          required: true,
        ),
      ],
      sections: [],
      templateVersion: 2,
    );
    await repository.putRecordTypeDefinition(protagonist);
    final timestamp = DateTime.utc(2026, 8, 19);
    final candidate = AuthorRecord(
      id: 'kali',
      typeId: 'character',
      templateId: 'protagonist',
      templateVersion: 1,
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      title: 'Kali Vale',
      fields: const {'identity.fullName': 'Kali Vale'},
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    await expectLater(
      records.createRecord(candidate),
      throwsA(
        isA<RecordValidationException>().having(
          (error) => error.result.errors.map((issue) => issue.fieldId),
          'invalid fields',
          contains('centralGoal'),
        ),
      ),
    );
    expect(await repository.recordById('kali'), isNull);
  });
}

AuthorRecord _character({
  required String id,
  required String projectId,
  required String name,
  required DateTime timestamp,
}) =>
    AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      title: name.isEmpty ? 'Untitled Character' : name,
      fields: {'identity.fullName': name},
      createdAt: timestamp,
      updatedAt: timestamp,
    );
