import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the Codex's universal entity vocabulary (directive §1.1) and the
/// series spine the cross-book work is built on.
///
/// The Codex claims to hold "everything my story knows". That claim is only
/// true if every category the directive names resolves to a real registered
/// type, so this file asserts the claim rather than leaving it to prose.
void main() {
  final registry = BuiltInRecordTypes.registry();
  final connections = BuiltInConnectionTypes.registry();

  /// Every category from directive §1.1, and the type each one resolves to.
  const universalEntityCoverage = <String, List<String>>{
    'People': [
      'character',
      'person',
      'historical-figure',
      'public-figure',
      'deity',
      'profession',
      'occupation',
    ],
    'Places': [
      'world',
      'location',
      'region',
      'country',
      'city',
      'settlement',
      'district',
      'building',
      'room',
      'map',
      'map-marker',
    ],
    'Organizations': [
      'faction',
      'organisation',
      'house',
      'clan',
      'guild',
      'company',
      'military-unit',
      'government',
      'institution',
      'religion',
    ],
    'Concepts': [
      'magic-system',
      'technology',
      'religion',
      'language',
      'political-system',
      'custom-tradition',
      'species',
      'race',
      'culture',
      'concept',
    ],
    'Story Objects': [
      'item',
      'artefact',
      'weapon',
      'armour',
      'vehicle',
      'document',
      'currency',
    ],
    'Events': [
      'historical-event',
      'historical-period',
      'era',
      'timeline-event',
      'calendar-event',
      'story-event',
      'event',
    ],
  };

  group('universal entity coverage', () {
    for (final entry in universalEntityCoverage.entries) {
      test('${entry.key} resolves to registered types', () {
        for (final typeId in entry.value) {
          expect(
            () => registry.resolve(typeId),
            returnsNormally,
            reason: '${entry.key} needs a "$typeId" record type.',
          );
        }
      });
    }

    test('every universal type inherits the shared knowledge fields', () {
      // Aliases and knowledge status are what make an entity recognisable in
      // prose and reviewable as canon. A type that does not inherit them is
      // invisible to entity recognition.
      for (final ids in universalEntityCoverage.values) {
        for (final typeId in ids) {
          final fieldIds =
              registry.resolve(typeId).fields.map((field) => field.id).toSet();
          expect(
            fieldIds,
            containsAll(<String>{
              'name',
              'aliases',
              'summary',
              'knowledgeStatus',
              'sourceReferences',
            }),
            reason: '$typeId is missing an inherited knowledge field.',
          );
        }
      }
    });
  });

  group('series spine', () {
    test('series and book carry real fields, not just the lore defaults', () {
      final book = registry.resolve('book');
      expect(
        book.fields.map((field) => field.id),
        containsAll(<String>{
          'order',
          'subtitle',
          'status',
          'wordGoal',
          'blurb',
          'publicationDate',
        }),
      );

      final series = registry.resolve('series');
      expect(
        series.fields.map((field) => field.id),
        containsAll(<String>{'status', 'plannedBooks', 'blurb'}),
      );
    });

    test('entity-state declares only its own frame', () {
      // A book state carries the entity's *differing* field values, and those
      // field ids belong to the entity's type, not to this one. The definition
      // therefore declares only the frame; RecordValidator validates the ids a
      // definition declares and preserves the rest, which is what lets one
      // state record hold any field of any entity type.
      final state = registry.resolve('entity-state');
      expect(
        state.fields.map((field) => field.id),
        containsAll(<String>{
          'canonicalRecordId',
          'removedFieldIds',
          'changeReason',
        }),
      );
      expect(
        state.fields.firstWhere((field) => field.id == 'canonicalRecordId')
            .required,
        isTrue,
      );
    });

    test('the series spine is typed on both endpoints', () {
      // Deliberately not the wildcard `partOf`: a book's place in its series
      // is checkable, and a state can only ever hang off a book.
      expect(connections.resolve('bookInSeries').permits('book', 'series'),
          isTrue);
      expect(connections.resolve('bookInSeries').permits('character', 'series'),
          isFalse);
      expect(
        connections.resolve('stateInBook').permits('entity-state', 'book'),
        isTrue,
      );
      expect(
        connections.resolve('stateInBook').permits('character', 'book'),
        isFalse,
      );
    });
  });

  group('book usage', () {
    test('any universal entity can appear in a book', () {
      final appearsIn = connections.resolve('appearsIn');
      for (final typeId in const [
        'character',
        'person',
        'historical-figure',
        'faction',
        'guild',
        'item',
        'vehicle',
        'location',
        'magic-system',
        'historical-event',
        'entity-state',
      ]) {
        expect(
          appearsIn.permits(typeId, 'book'),
          isTrue,
          reason: '$typeId cannot record a book appearance.',
        );
      }
      expect(appearsIn.permits('character', 'chapter'), isTrue);
      expect(appearsIn.permits('character', 'scene'), isTrue);
    });

    test('appearsIn is still typed, not a wildcard', () {
      final appearsIn = connections.resolve('appearsIn');
      expect(appearsIn.sourceTypeIds, isNot(contains('*')));
      expect(appearsIn.targetTypeIds, ['scene', 'chapter', 'book']);
      expect(appearsIn.permits('character', 'faction'), isFalse);
    });

    test('an appearance carries usage detail and rejects anything else', () {
      // ConnectionTypeRegistry rejects undeclared metadata keys, so the five
      // declared fields are the whole book-usage vocabulary.
      connections.validateConnection(
        typeId: 'appearsIn',
        sourceTypeId: 'character',
        targetTypeId: 'book',
        metadata: const {
          'role': 'protagonist',
          'firstAppearance': 'chapter-1',
          'lastAppearance': 'chapter-40',
          'status': 'alive',
          'notes': 'Carries the Red Widow arc.',
        },
      );

      expect(
        () => connections.validateConnection(
          typeId: 'appearsIn',
          sourceTypeId: 'character',
          targetTypeId: 'book',
          metadata: const {'mood': 'ominous'},
        ),
        throwsStateError,
      );
    });

    test('a state record documents the entity it varies', () {
      expect(
        connections.resolve('documents').permits('entity-state', 'character'),
        isTrue,
      );
    });
  });

  test('"universe" stays a place, not a canon container', () {
    // RecordScopeType.universe means a canon container, but 'universe' is
    // already a cosmic *place* type. Anything building the master plan's M4
    // universe scope must pick a different id — 'story-universe' is reserved.
    expect(registry.resolve('universe').categoryId, isNot('manuscript'));
    expect(
      () => registry.resolve('story-universe'),
      throwsStateError,
      reason: 'story-universe is reserved for the M4 canon container.',
    );
  });
}
