import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom definition preserves schema and extension data', () {
    const definition = RecordTypeDefinition(
      id: 'magic-spell',
      name: 'Magic Spell',
      categoryId: 'magic',
      description: 'A reusable spell definition.',
      icon: 'auto_fix_high',
      fields: [
        RecordFieldDefinition(
          id: 'cost',
          label: 'Cost',
          type: RecordFieldType.shortText,
          order: 0,
          required: true,
        ),
        RecordFieldDefinition(
          id: 'difficulty',
          label: 'Difficulty',
          type: RecordFieldType.rating,
          order: 1,
          defaultValue: 3,
        ),
      ],
      sections: [
        RecordTemplateSection(
          id: 'rules',
          title: 'Rules',
          order: 0,
          fieldIds: ['cost', 'difficulty'],
        ),
      ],
      tags: ['fantasy'],
      suggestedLinkTypeIds: ['usedBy'],
      scopeType: RecordScopeType.project,
      scopeId: 'project-1',
      allowedScopeTypes: [RecordScopeType.series, RecordScopeType.project],
      permissions: {'editable': true},
      exportBehavior: {'includeNotes': false},
      sourcePackId: 'fantasy-pack',
      extensionData: {'futureSetting': 'preserved'},
    );

    final restored = RecordTypeDefinition.fromJson(definition.toJson());

    expect(restored.id, definition.id);
    expect(restored.fields.last.defaultValue, 3);
    expect(restored.sections.single.fieldIds, ['cost', 'difficulty']);
    expect(restored.scopeType, RecordScopeType.project);
    expect(restored.scopeId, 'project-1');
    expect(restored.permissions['editable'], isTrue);
    expect(restored.allowedScopeTypes, [
      RecordScopeType.series,
      RecordScopeType.project,
    ]);
    expect(restored.extensionData['futureSetting'], 'preserved');
    expect(RecordTypeRegistry([restored]).resolve(restored.id).id, restored.id);
  });

  test('inheritance adds fields, overrides defaults, and merges suggestions',
      () {
    const base = RecordTypeDefinition(
      id: 'base-location',
      name: 'Base Location',
      categoryId: 'places',
      fields: [
        RecordFieldDefinition(
          id: 'population',
          label: 'Population',
          type: RecordFieldType.number,
          order: 0,
          defaultValue: 0,
        ),
      ],
      sections: [
        RecordTemplateSection(
          id: 'overview',
          title: 'Overview',
          order: 0,
          fieldIds: ['population'],
        ),
      ],
      suggestedLinkTypeIds: ['locatedIn'],
    );
    const city = RecordTypeDefinition(
      id: 'city',
      name: 'City',
      categoryId: 'places',
      baseTypeId: 'base-location',
      fields: [
        RecordFieldDefinition(
          id: 'population',
          label: 'Population',
          type: RecordFieldType.number,
          order: 0,
          defaultValue: 1000,
        ),
        RecordFieldDefinition(
          id: 'districts',
          label: 'Districts',
          type: RecordFieldType.list,
          order: 1,
          defaultValue: [],
        ),
      ],
      sections: [
        RecordTemplateSection(
          id: 'overview',
          title: 'Overview',
          order: 0,
          fieldIds: ['population', 'districts'],
        ),
      ],
      suggestedLinkTypeIds: ['governedBy'],
    );
    const capital = RecordTypeDefinition(
      id: 'capital-city',
      name: 'Capital City',
      categoryId: 'places',
      baseTypeId: 'city',
      fields: [
        RecordFieldDefinition(
          id: 'seatOfPower',
          label: 'Seat of power',
          type: RecordFieldType.recordReference,
          order: 2,
        ),
      ],
      sections: [
        RecordTemplateSection(
          id: 'government',
          title: 'Government',
          order: 1,
          fieldIds: ['seatOfPower'],
        ),
      ],
      suggestedLinkTypeIds: ['capitalOf'],
    );

    final resolved = RecordTypeRegistry([base, city, capital]).resolve(
      'capital-city',
    );

    expect(resolved.fields.map((field) => field.id), [
      'population',
      'districts',
      'seatOfPower',
    ]);
    expect(resolved.fields.first.defaultValue, 1000);
    expect(resolved.sections.map((section) => section.id), [
      'overview',
      'government',
    ]);
    expect(resolved.suggestedLinkTypeIds.toSet(), {
      'locatedIn',
      'governedBy',
      'capitalOf',
    });
    expect(base.fields.single.defaultValue, 0);
  });

  test('invalid inheritance and field schemas are rejected', () {
    const first = RecordTypeDefinition(
      id: 'first',
      name: 'First',
      categoryId: 'custom',
      baseTypeId: 'second',
      fields: [],
      sections: [],
    );
    const second = RecordTypeDefinition(
      id: 'second',
      name: 'Second',
      categoryId: 'custom',
      baseTypeId: 'first',
      fields: [],
      sections: [],
    );

    final cyclic = RecordTypeRegistry([first, second]);
    expect(() => cyclic.resolve('first'), throwsStateError);
    expect(
      () => RecordTypeRegistry(const [
        RecordTypeDefinition(
          id: 'invalid-choice',
          name: 'Invalid Choice',
          categoryId: 'custom',
          fields: [
            RecordFieldDefinition(
              id: 'kind',
              label: 'Kind',
              type: RecordFieldType.singleChoice,
              order: 0,
            ),
          ],
          sections: [],
        ),
      ]),
      throwsFormatException,
    );
  });

  test('core catalogue resolves every directive entry type as data', () {
    final registry = BuiltInRecordTypes.registry();
    const requiredTypes = {
      'world',
      'character',
      'location',
      'faction',
      'organisation',
      'religion',
      'culture',
      'magic-system',
      'technology',
      'species',
      'creature',
      'language',
      'item',
      'artefact',
      'weapon',
      'currency',
      'resource',
      'government',
      'political-system',
      'historical-event',
      'era',
      'myth',
      'legend',
      'folklore',
      'custom-tradition',
      'law',
      'rule',
      'concept',
      'theory',
      'secret',
      'mystery',
      'clue',
      'plot-thread',
      'theme',
      'symbol',
      'motif',
      'disease',
      'medicine',
      'plant',
      'animal',
      'food',
      'location-type',
      'architectural-feature',
      'organisation-role',
      'occupation',
      'festival',
      'holiday',
      'calendar-system',
      'calendar-event',
      'technology-system',
      'magic-rule',
      'magic-limitation',
      'world-rule',
      'research-entry',
      'reference',
      'glossary-term',
      'author-note',
      'custom-entry',
      'general',
      'research',
      'glossary',
      'custom',
    };

    expect(
      BuiltInRecordTypes.definitions.map((definition) => definition.id).toSet(),
      containsAll(requiredTypes),
    );
    for (final id in requiredTypes) {
      final resolved = registry.resolve(id);
      expect(resolved.fields, isNotEmpty, reason: id);
      expect(resolved.sections, isNotEmpty, reason: id);
      expect(resolved.sourcePackId, startsWith('authoros-'), reason: id);
    }
  });

  test('legacy codex types resolve without becoming new-record templates', () {
    final registry = BuiltInRecordTypes.registry();

    expect(registry.resolve('place').fields, isNotEmpty);
    expect(registry.resolve('object').fields, isNotEmpty);
    expect(registry.resolve('lore').fields, isNotEmpty);
    expect(
      registry.resolve('place').extensionData['selectableForNewRecords'],
      isFalse,
    );
  });
}
