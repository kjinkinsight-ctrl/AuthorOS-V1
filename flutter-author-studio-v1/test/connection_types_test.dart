import 'package:author_studio_v1/core/connection_types.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('typed connection validates endpoints, metadata, and inverse semantics',
      () {
    const memberOf = ConnectionTypeDefinition(
      id: 'memberOf',
      displayName: 'Member of',
      sourceTypeIds: ['character'],
      targetTypeIds: ['faction', 'organisation'],
      inverseLabel: 'Has member',
      cardinality: ConnectionCardinality.manyToMany,
      temporalSupport: true,
      metadataFields: [
        RecordFieldDefinition(
          id: 'rank',
          label: 'Rank',
          type: RecordFieldType.shortText,
          order: 0,
          required: true,
        ),
      ],
      extensionData: {'futureRule': true},
    );
    final registry = ConnectionTypeRegistry([memberOf]);

    registry.validateConnection(
      typeId: 'memberOf',
      sourceTypeId: 'character',
      targetTypeId: 'faction',
      metadata: const {'rank': 'Founder'},
    );

    expect(registry.resolve('memberOf').inverseLabel, 'Has member');
    expect(
      () => registry.validateConnection(
        typeId: 'memberOf',
        sourceTypeId: 'character',
        targetTypeId: 'character',
        metadata: const {'rank': 'Founder'},
      ),
      throwsStateError,
    );
    expect(
      () => registry.validateConnection(
        typeId: 'memberOf',
        sourceTypeId: 'character',
        targetTypeId: 'faction',
      ),
      throwsStateError,
    );

    final restored = ConnectionTypeDefinition.fromJson(memberOf.toJson());
    expect(restored.temporalSupport, isTrue);
    expect(restored.metadataFields.single.id, 'rank');
    expect(restored.extensionData['futureRule'], isTrue);
  });

  test('custom wildcard connection types are data-driven', () {
    const custom = ConnectionTypeDefinition(
      id: 'custom-related',
      displayName: 'Bound by oath to',
      sourceTypeIds: ['*'],
      targetTypeIds: ['*'],
      inverseLabel: 'Has oath with',
      direction: ConnectionDirection.undirected,
      scopeId: 'project-1',
      sourcePackId: 'user',
    );
    final registry = ConnectionTypeRegistry([custom]);

    registry.validateConnection(
      typeId: 'custom-related',
      sourceTypeId: 'character',
      targetTypeId: 'artefact',
    );
    expect(registry.resolve('custom-related').scopeId, 'project-1');
    expect(registry.resolve('custom-related').sourcePackId, 'user');
  });
}
