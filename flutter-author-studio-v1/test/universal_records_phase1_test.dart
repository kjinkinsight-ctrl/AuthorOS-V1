import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_types.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/universal_records.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('record identity', () {
    test('ids are immutable, comparable, and independent of titles', () {
      final first = RecordId.parse('kali');
      final second = RecordId.parse('  kali  ');
      final other = RecordId.parse('mira');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first == other, isFalse);
      expect(first.compareTo(other), lessThan(0));
      expect(<RecordId>{first, second, other}, hasLength(2));
      expect(
        (<RecordId>[other, first]..sort()).map((id) => id.value),
        ['kali', 'mira'],
      );
    });

    test('two records may share a title without sharing identity', () {
      final timestamp = DateTime.utc(2026, 8, 20);
      final first = _record('kali-1', 'Kali', 'project-a', timestamp);
      final second = _record('kali-2', 'Kali', 'project-a', timestamp);

      expect(first.title, second.title);
      expect(first.recordId == second.recordId, isFalse);
    });

    test('ids round-trip through JSON without changing', () {
      final id = RecordId.parse('kali');
      final relationshipId = RelationshipId.parse('link-kali-mira');
      final encoded = jsonEncode({
        'record': id.toJson(),
        'relationship': relationshipId.toJson(),
      });
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(RecordId.fromJson(decoded['record']), id);
      expect(
        RelationshipId.fromJson(decoded['relationship']),
        relationshipId,
      );
    });

    test('malformed identities fail instead of becoming phantom ids', () {
      expect(() => RecordId.parse(''), throwsFormatException);
      expect(() => RecordId.parse('   '), throwsFormatException);
      expect(() => RecordId.parse('kali\nmira'), throwsFormatException);
      expect(() => RecordId.parse(42), throwsFormatException);
      expect(() => RecordId.parse(null), throwsFormatException);
      expect(RecordId.tryParse(''), isNull);
      expect(RecordId.tryParse('kali')?.value, 'kali');
      expect(() => RelationshipId.parse(''), throwsFormatException);
      expect(RelationshipId.tryParse('link-1')?.value, 'link-1');
    });
  });

  group('record and relationship type registries', () {
    test('every foundation record type resolves in the one registry', () {
      final registry = BuiltInRecordTypes.registry();

      for (final id in BuiltInRecordTypes.foundationTypeIds) {
        final definition = registry.resolve(id);
        expect(definition.id, id);
        expect(definition.fields, isNotEmpty, reason: id);
        expect(definition.builtIn, isTrue, reason: id);
      }
    });

    test('every foundation relationship type resolves in the one registry',
        () {
      final registry = BuiltInConnectionTypes.registry();

      for (final id in BuiltInConnectionTypes.foundationTypeIds) {
        final definition = registry.resolve(id);
        expect(definition.id, id);
        expect(definition.builtIn, isTrue, reason: id);
        expect(definition.inverseLabel, isNotEmpty, reason: id);
      }
    });

    test('the registries stay extensible for custom types', () {
      final records = BuiltInRecordTypes.registry(
        additionalDefinitions: [
          const RecordTypeDefinition(
            id: 'ship-log',
            name: 'Ship Log',
            categoryId: 'custom',
            baseTypeId: 'general-lore',
            fields: [],
            sections: [],
          ),
        ],
      );
      final relationships = BuiltInConnectionTypes.registry(
        additionalDefinitions: [
          const ConnectionTypeDefinition(
            id: 'crews',
            displayName: 'Crews',
            sourceTypeIds: ['character'],
            targetTypeIds: ['ship-log'],
            inverseLabel: 'Crewed by',
          ),
        ],
      );

      expect(records.resolve('ship-log').fields, isNotEmpty);
      expect(relationships.resolve('crews').displayName, 'Crews');
      expect(() => records.resolve('no-such-type'), throwsStateError);
      expect(() => relationships.resolve('no-such-link'), throwsStateError);
    });
  });

  group('serialization', () {
    test('records round-trip with ids, scope, canon, status and timestamps',
        () {
      final created = DateTime.utc(2026, 8, 18, 9, 30);
      final updated = DateTime.utc(2026, 8, 20, 11, 15);
      final record = AuthorRecord(
        id: 'kali',
        typeId: 'character',
        scopeType: RecordScopeType.book,
        scopeId: 'book-1',
        projectId: 'project-a',
        seriesId: 'series-1',
        bookId: 'book-1',
        canonStatus: CanonStatus.canon,
        title: 'Kali',
        status: AuthorRecordStatus.archived,
        tags: const ['pov'],
        fields: const {'summary': 'A widow with a plan.'},
        createdAt: created,
        updatedAt: updated,
        extensionData: const {'unknownFutureField': 'preserved'},
      );

      final decoded = AuthorRecord.fromJson(_roundTrip(record.toJson()));

      expect(decoded.id, record.id);
      expect(decoded.typeId, record.typeId);
      expect(decoded.scopeType, RecordScopeType.book);
      expect(decoded.scopeId, 'book-1');
      expect(decoded.projectId, 'project-a');
      expect(decoded.seriesId, 'series-1');
      expect(decoded.bookId, 'book-1');
      expect(decoded.canonStatus, CanonStatus.canon);
      expect(decoded.status, AuthorRecordStatus.archived);
      expect(decoded.tags, ['pov']);
      expect(decoded.createdAt.toUtc(), created);
      expect(decoded.updatedAt.toUtc(), updated);
      expect(decoded.extensionData['unknownFutureField'], 'preserved');
      expect(_roundTrip(decoded.toJson()), _roundTrip(record.toJson()));
    });

    test('relationships round-trip with type, endpoints and timestamps', () {
      final timestamp = DateTime.utc(2026, 8, 20, 12);
      final link = RecordLink(
        id: 'link-kali-widow',
        sourceId: 'kali',
        targetId: 'widow-network',
        typeId: 'memberOf',
        scopeId: 'project-a',
        label: 'Founder',
        metadata: const {'rank': 'Founder'},
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      final decoded = RecordLink.fromJson(_roundTrip(link.toJson()));

      expect(decoded.relationshipId, link.relationshipId);
      expect(decoded.sourceRecordId, RecordId.parse('kali'));
      expect(decoded.targetRecordId, RecordId.parse('widow-network'));
      expect(decoded.typeId, 'memberOf');
      expect(decoded.scopeId, 'project-a');
      expect(decoded.direction, RecordLinkDirection.directed);
      expect(decoded.metadata['rank'], 'Founder');
      expect(decoded.createdAt.toUtc(), timestamp);
      expect(_roundTrip(decoded.toJson()), _roundTrip(link.toJson()));
    });

    test('malformed serialized data is rejected', () {
      expect(
        () => AuthorRecord.fromJson(const {'id': '', 'typeId': 'character'}),
        throwsFormatException,
      );
      expect(
        () => RecordLink.fromJson(const {
          'id': 'link-1',
          'sourceId': 'kali',
          'targetId': 'mira',
          'typeId': 'relatedTo',
          'scopeId': 'project-a',
          'createdAt': 'not-a-date',
          'updatedAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });

  group('record lifecycle and graph queries', () {
    test('records are created, typed, listed and soft-deleted', () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);

      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp),
        _record('mira', 'Mira', 'project-a', timestamp),
        _record(
          'widow-network',
          'Widow Network',
          'project-a',
          timestamp,
          typeId: 'faction',
        ),
      ]);

      final records = harness.projectA;
      expect(await records.getRecord(RecordId.parse('kali')), isNotNull);
      expect(
        (await records.findRecords(typeId: 'character'))
            .map((record) => record.id),
        ['kali', 'mira'],
      );
      expect(
        (await records.findRecords(typeId: 'faction')).single.id,
        'widow-network',
      );

      await records.archiveRecord(
        RecordId.parse('mira'),
        timestamp: timestamp,
      );
      expect(
        (await records.listRecords(includeArchived: false))
            .map((record) => record.id),
        ['kali', 'widow-network'],
      );

      await records.deleteRecord(
        RecordId.parse('mira'),
        timestamp: timestamp,
      );
      expect(
        (await records.listRecords()).map((record) => record.id),
        ['kali', 'widow-network'],
      );
      expect(
        (await records.listRecords(includeDeleted: true))
            .map((record) => record.id),
        ['kali', 'mira', 'widow-network'],
      );

      await harness.close();
    });

    test('relationships answer incoming, outgoing and related queries',
        () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp),
        _record(
          'widow-network',
          'Widow Network',
          'project-a',
          timestamp,
          typeId: 'faction',
        ),
        _record(
          'ash-harbour',
          'Ash Harbour',
          'project-a',
          timestamp,
          typeId: 'location',
        ),
      ]);
      final records = harness.projectA;

      final membership = await records.createRelationship(
        sourceId: RecordId.parse('kali'),
        targetId: RecordId.parse('widow-network'),
        typeId: 'memberOf',
        metadata: const {'rank': 'Founder'},
        timestamp: timestamp,
      );
      final home = await records.createRelationship(
        sourceId: RecordId.parse('kali'),
        targetId: RecordId.parse('ash-harbour'),
        typeId: 'locatedAt',
        timestamp: timestamp,
      );

      expect(
        (await records.findOutgoing(RecordId.parse('kali')))
            .map((link) => link.id),
        containsAll([membership.id, home.id]),
      );
      expect(
        (await records.findIncoming(RecordId.parse('widow-network')))
            .single
            .id,
        membership.id,
      );
      expect(
        (await records.findRelated(RecordId.parse('kali')))
            .map((related) => related.record.id),
        ['ash-harbour', 'widow-network'],
      );
      expect(
        (await records.findRelated(
          RecordId.parse('kali'),
          relationshipTypeIds: const {'memberOf'},
        ))
            .single
            .record
            .id,
        'widow-network',
      );
      expect(
        (await records.findRelated(
          RecordId.parse('kali'),
          recordTypeIds: const {'location'},
        ))
            .single
            .record
            .id,
        'ash-harbour',
      );
      expect(
        (await records.findRelated(
          RecordId.parse('widow-network'),
          direction: RelationshipDirection.incoming,
        ))
            .single
            .direction,
        RelationshipDirection.incoming,
      );
      expect(
        await records.findRelated(
          RecordId.parse('widow-network'),
          direction: RelationshipDirection.outgoing,
        ),
        isEmpty,
      );

      expect(
        (await records.getRelationship(membership.relationshipId))?.typeId,
        'memberOf',
      );
      expect(
        (await records.listRelationships()).map((link) => link.id),
        containsAll([membership.id, home.id]),
      );

      await records.deleteRelationship(
        membership.relationshipId,
        timestamp: timestamp,
      );
      expect(await records.getRelationship(membership.relationshipId), isNull);

      await harness.close();
    });

    test('deleting a record removes the relationships that reference it',
        () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp),
        _record('mira', 'Mira', 'project-a', timestamp),
        _record(
          'widow-network',
          'Widow Network',
          'project-a',
          timestamp,
          typeId: 'faction',
        ),
      ]);
      final records = harness.projectA;
      await records.createRelationship(
        sourceId: RecordId.parse('kali'),
        targetId: RecordId.parse('widow-network'),
        typeId: 'memberOf',
        timestamp: timestamp,
      );
      await records.createRelationship(
        sourceId: RecordId.parse('mira'),
        targetId: RecordId.parse('widow-network'),
        typeId: 'memberOf',
        timestamp: timestamp,
      );

      await records.deleteRecord(
        RecordId.parse('kali'),
        timestamp: timestamp,
      );

      expect(
        (await records.listRelationships()).map((link) => link.sourceId),
        ['mira'],
      );
      expect(
        (await records.findRelated(RecordId.parse('widow-network')))
            .map((related) => related.record.id),
        ['mira'],
      );
      // Deleting one record never removes another record.
      expect(await records.getRecord(RecordId.parse('widow-network')), isNotNull);
      expect(await records.getRecord(RecordId.parse('mira')), isNotNull);
      // The deleted record itself is preserved as a soft delete.
      final deleted = (await records.listRecords(includeDeleted: true))
          .firstWhere((record) => record.id == 'kali');
      expect(deleted.status, AuthorRecordStatus.deleted);

      await harness.close();
    });

    test('relationships may be kept deliberately when a record is deleted',
        () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp),
        _record(
          'widow-network',
          'Widow Network',
          'project-a',
          timestamp,
          typeId: 'faction',
        ),
      ]);
      final records = harness.projectA;
      final link = await records.createRelationship(
        sourceId: RecordId.parse('kali'),
        targetId: RecordId.parse('widow-network'),
        typeId: 'memberOf',
        timestamp: timestamp,
      );

      await records.deleteRecord(
        RecordId.parse('kali'),
        detachRelationships: false,
        timestamp: timestamp,
      );

      expect(await records.getRelationship(link.relationshipId), isNotNull);

      await harness.close();
    });
  });

  group('relationship validation', () {
    test('invalid endpoints and types fail without creating phantom records',
        () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp),
        _record(
          'widow-network',
          'Widow Network',
          'project-a',
          timestamp,
          typeId: 'faction',
        ),
      ]);
      final records = harness.projectA;

      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('ghost'),
          targetId: RecordId.parse('widow-network'),
          typeId: 'memberOf',
        ),
        throwsStateError,
      );
      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('kali'),
          targetId: RecordId.parse('ghost'),
          typeId: 'memberOf',
        ),
        throwsStateError,
      );
      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('kali'),
          targetId: RecordId.parse('widow-network'),
          typeId: 'noSuchRelationship',
        ),
        throwsStateError,
      );
      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('kali'),
          targetId: RecordId.parse('kali'),
          typeId: 'references',
        ),
        throwsArgumentError,
      );
      // A wrong endpoint type for a typed relationship is rejected too.
      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('widow-network'),
          targetId: RecordId.parse('kali'),
          typeId: 'memberOf',
        ),
        throwsStateError,
      );

      expect(await records.listRelationships(), isEmpty);
      expect(await records.getRecord(RecordId.parse('ghost')), isNull);

      await harness.close();
    });

    test('self reference is rejected unless the type opts in', () {
      final timestamp = DateTime.utc(2026, 8, 20);
      final registry = BuiltInConnectionTypes.registry(
        additionalDefinitions: const [
          ConnectionTypeDefinition(
            id: 'mirrors',
            displayName: 'Mirrors',
            sourceTypeIds: ['*'],
            targetTypeIds: ['*'],
            inverseLabel: 'Mirrored by',
            extensionData: {'allowSelfReference': true},
          ),
        ],
      );
      final validator = RelationshipValidator(registry);
      final endpoint = RelationshipEndpoint.fromRecord(
        _record('kali', 'Kali', 'project-a', timestamp),
      );

      expect(
        validator
            .validate(
              relationship: _link('references', timestamp, targetId: 'kali'),
              projectId: 'project-a',
              source: endpoint,
              target: endpoint,
            )
            .errors
            .map((issue) => issue.code),
        contains('relationship-self-reference'),
      );
      expect(
        validator
            .validate(
              relationship: _link('mirrors', timestamp, targetId: 'kali'),
              projectId: 'project-a',
              source: endpoint,
              target: endpoint,
            )
            .isValid,
        isTrue,
      );
    });

    test('deleted endpoints fail and archived endpoints warn', () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp),
        _record('mira', 'Mira', 'project-a', timestamp),
        _record('rho', 'Rho', 'project-a', timestamp),
      ]);
      final records = harness.projectA;
      await records.deleteRecord(RecordId.parse('mira'), timestamp: timestamp);
      await records.archiveRecord(RecordId.parse('rho'), timestamp: timestamp);

      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('kali'),
          targetId: RecordId.parse('mira'),
          typeId: 'references',
          timestamp: timestamp,
        ),
        throwsStateError,
      );

      final archivedLink = await records.createRelationship(
        sourceId: RecordId.parse('kali'),
        targetId: RecordId.parse('rho'),
        typeId: 'references',
        timestamp: timestamp,
      );
      expect(archivedLink.targetId, 'rho');

      final validator = RelationshipValidator(await records.relationshipTypes());
      final result = validator.validate(
        relationship: archivedLink,
        projectId: 'project-a',
        source: RelationshipEndpoint.fromRecord(
          (await records.getRecord(RecordId.parse('kali')))!,
        ),
        target: RelationshipEndpoint.fromRecord(
          (await records.getRecord(RecordId.parse('rho')))!,
        ),
      );
      expect(result.isValid, isTrue);
      expect(
        result.warnings.map((issue) => issue.code),
        contains('relationship-endpoint-archived'),
      );

      await harness.close();
    });
  });

  group('project isolation', () {
    test('two projects never expose each other\'s records or relationships',
        () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp),
        _record('mira', 'Mira', 'project-a', timestamp),
        _record('borrowed', 'Borrowed', 'project-b', timestamp),
      ]);
      final projectA = harness.projectA;
      final projectB = harness.projectB;

      await projectA.createRelationship(
        sourceId: RecordId.parse('kali'),
        targetId: RecordId.parse('mira'),
        typeId: 'references',
        timestamp: timestamp,
      );

      expect(
        (await projectA.listRecords()).map((record) => record.id),
        ['kali', 'mira'],
      );
      expect(
        (await projectB.listRecords()).map((record) => record.id),
        ['borrowed'],
      );
      expect(await projectA.getRecord(RecordId.parse('borrowed')), isNull);
      expect(await projectB.getRecord(RecordId.parse('kali')), isNull);
      expect(await projectB.listRelationships(), isEmpty);
      await expectLater(
        projectB.findRelated(RecordId.parse('kali')),
        throwsStateError,
      );
      await expectLater(
        projectA.createRelationship(
          sourceId: RecordId.parse('kali'),
          targetId: RecordId.parse('borrowed'),
          typeId: 'references',
        ),
        throwsStateError,
      );

      await harness.close();
    });
  });

  group('canon and branch isolation', () {
    test('canon connects to canon and a branch connects within itself',
        () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp,
            canonStatus: CanonStatus.canon),
        _record('mira', 'Mira', 'project-a', timestamp,
            canonStatus: CanonStatus.canon),
        _branchRecord('kali-alt', 'Kali (alt)', 'branch-a', timestamp),
        _branchRecord('mira-alt', 'Mira (alt)', 'branch-a', timestamp),
        _branchRecord('kali-beta', 'Kali (beta)', 'branch-b', timestamp),
      ]);
      final records = harness.projectA;

      final canonLink = await records.createRelationship(
        sourceId: RecordId.parse('kali'),
        targetId: RecordId.parse('mira'),
        typeId: 'references',
        timestamp: timestamp,
      );
      expect(canonLink.sourceId, 'kali');

      final branchLink = await records.createRelationship(
        sourceId: RecordId.parse('kali-alt'),
        targetId: RecordId.parse('mira-alt'),
        typeId: 'references',
        timestamp: timestamp,
      );
      expect(branchLink.targetId, 'mira-alt');

      await harness.close();
    });

    test('canon does not connect to a branch, and branches stay separate',
        () async {
      final harness = await _Harness.create();
      final timestamp = DateTime.utc(2026, 8, 20);
      await harness.seed([
        _record('kali', 'Kali', 'project-a', timestamp,
            canonStatus: CanonStatus.canon),
        _branchRecord('kali-alt', 'Kali (alt)', 'branch-a', timestamp),
        _branchRecord('kali-beta', 'Kali (beta)', 'branch-b', timestamp),
      ]);
      final records = harness.projectA;

      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('kali'),
          targetId: RecordId.parse('kali-alt'),
          typeId: 'references',
          timestamp: timestamp,
        ),
        throwsStateError,
      );
      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('kali-alt'),
          targetId: RecordId.parse('kali'),
          typeId: 'references',
          timestamp: timestamp,
        ),
        throwsStateError,
      );
      await expectLater(
        records.createRelationship(
          sourceId: RecordId.parse('kali-alt'),
          targetId: RecordId.parse('kali-beta'),
          typeId: 'references',
          timestamp: timestamp,
        ),
        throwsStateError,
      );
      expect(await records.listRelationships(), isEmpty);

      await harness.close();
    });

    test('the branch rule names the incompatible contexts', () {
      final timestamp = DateTime.utc(2026, 8, 20);
      final validator = RelationshipValidator(
        BuiltInConnectionTypes.registry(),
      );
      final result = validator.validate(
        relationship: _link('references', timestamp, targetId: 'kali-alt'),
        projectId: 'project-a',
        source: RelationshipEndpoint.fromRecord(
          _record('kali', 'Kali', 'project-a', timestamp),
        ),
        target: RelationshipEndpoint.fromRecord(
          _branchRecord('kali-alt', 'Kali (alt)', 'branch-a', timestamp),
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((issue) => issue.code),
        contains('relationship-branch-mismatch'),
      );
      expect(result.errorSummary, contains('branch branch-a'));
      expect(
        const RelationshipValidationException(
          RelationshipValidationResult([
            RelationshipValidationIssue(
              code: 'relationship-branch-mismatch',
              message: 'canon to branch branch-a',
            ),
          ]),
        ).toString(),
        contains('canon to branch branch-a'),
      );
    });
  });

  group('dependency direction', () {
    test('the core record and relationship model has no outward imports', () {
      const coreModelFiles = [
        'lib/core/record_id.dart',
        'lib/core/record_scope.dart',
        'lib/core/record_types.dart',
        'lib/core/connection_types.dart',
        'lib/core/connected_domain.dart',
        'lib/core/relationship_validation.dart',
        'lib/core/branch_domain.dart',
      ];
      const forbidden = [
        'package:flutter/',
        'dart:ui',
        'package:drift',
        '../manuscript_studio.dart',
        '../character_studio.dart',
        '../world_studio.dart',
        '../timeline.dart',
        '../visual_planning.dart',
        '../theme/',
        '../persistence/',
      ];

      for (final path in coreModelFiles) {
        final source = File(path).readAsStringSync();
        final imports = source
            .split('\n')
            .where((line) => line.trimLeft().startsWith('import '))
            .toList();
        for (final import in imports) {
          for (final marker in forbidden) {
            expect(
              import.contains(marker),
              isFalse,
              reason: '$path must not import $marker',
            );
          }
        }
      }
    });

    test('record_id.dart depends on nothing at all', () {
      final source = File('lib/core/record_id.dart').readAsStringSync();

      expect(source.contains('\nimport '), isFalse);
      expect(source.startsWith('import '), isFalse);
    });
  });
}

class _Harness {
  _Harness(this.database)
      : repository = DriftConnectedDomainRepository(database);

  static Future<_Harness> create() async =>
      _Harness(AuthorOsDatabase(NativeDatabase.memory()));

  final AuthorOsDatabase database;
  final DriftConnectedDomainRepository repository;

  UniversalRecordsRepository get projectA => UniversalRecordsRepository(
        projectId: 'project-a',
        repository: repository,
      );

  UniversalRecordsRepository get projectB => UniversalRecordsRepository(
        projectId: 'project-b',
        repository: repository,
      );

  Future<void> seed(List<AuthorRecord> records) =>
      repository.putRecordsAndLinks(records: records, links: const []);

  Future<void> close() => database.close();
}

AuthorRecord _record(
  String id,
  String title,
  String scopeId,
  DateTime timestamp, {
  String typeId = 'character',
  CanonStatus canonStatus = CanonStatus.draft,
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: scopeId,
      projectId: scopeId,
      canonStatus: canonStatus,
      title: title,
      fields: _templateFields(title),
      createdAt: timestamp,
      updatedAt: timestamp,
    );

/// Values every built-in template used by these tests marks as required.
Map<String, Object?> _templateFields(String title) => {
      'name': title,
      'identity.fullName': title,
    };

AuthorRecord _branchRecord(
  String id,
  String title,
  String branchId,
  DateTime timestamp, {
  String typeId = 'character',
  String projectId = 'project-a',
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.branch,
      scopeId: branchId,
      projectId: projectId,
      branchId: branchId,
      canonStatus: CanonStatus.alternate,
      title: title,
      fields: _templateFields(title),
      createdAt: timestamp,
      updatedAt: timestamp,
    );

RecordLink _link(
  String typeId,
  DateTime timestamp, {
  String sourceId = 'kali',
  required String targetId,
}) =>
    RecordLink(
      id: 'link-$sourceId-$typeId-$targetId',
      sourceId: sourceId,
      targetId: targetId,
      typeId: typeId,
      scopeId: 'project-a',
      createdAt: timestamp,
      updatedAt: timestamp,
    );

Map<String, dynamic> _roundTrip(Map<String, Object?> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
