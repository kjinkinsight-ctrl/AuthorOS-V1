/// The Command System's grammar.
///
/// These tests are deliberately database-free. The grammar is a pure function
/// of a phrase and a vocabulary, and keeping it that way is what lets the
/// eleven phrases an author actually types be pinned cheaply and exactly.
library;

import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/command_grammar.dart';
import 'package:author_studio_v1/core/command_query.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:flutter_test/flutter_test.dart';

CommandGrammar _grammar({
  List<RecordTypeDefinition> extraRecordTypes = const [],
}) =>
    CommandGrammar(
      CommandVocabulary.fromRegistries(
        records: BuiltInRecordTypes.registry(
          additionalDefinitions: extraRecordTypes,
        ),
        connections: BuiltInConnectionTypes.registry(),
      ),
    );

void main() {
  late CommandGrammar grammar;

  setUp(() => grammar = _grammar());

  group('the author\'s own phrases', () {
    test('"Show me Kali" anchors on a name it has never heard of', () {
      final query = grammar.parse('Show me Kali');
      expect(query.isFreeText, isFalse);
      expect(query.verb, CommandVerb.show);
      expect(query.anchorPhrase, 'Kali');
      expect(query.relation, isNull);
    });

    test('"Show everything connected to Kali" traverses any edge', () {
      final query = grammar.parse('Show everything connected to Kali');
      expect(query.subject.everything, isTrue);
      expect(query.relation?.isAny, isTrue);
      expect(query.anchorPhrase, 'Kali');
    });

    test('"Show all unresolved plot threads" reads the adjective first', () {
      final query = grammar.parse('Show all unresolved plot threads');
      expect(query.hasPredicate(CommandPredicateKind.unresolved), isTrue);
      expect(query.subject.recordTypeIds, contains('plot-thread'));
      expect(query.anchorPhrase, isNull);
    });

    test('"Show characters appearing in Chapter 20" inflects the verb', () {
      final query = grammar.parse('Show characters appearing in Chapter 20');
      expect(query.subject.recordTypeIds, contains('character'));
      expect(query.relation?.typeId, 'appearsIn');
      expect(query.anchorPhrase, 'Chapter 20');
    });

    test('"Show all events occurring before Chapter 15" orders', () {
      final query = grammar.parse('Show all events occurring before Chapter 15');
      final predicate = query.predicates.single;
      expect(predicate.kind, CommandPredicateKind.before);
      expect(predicate.anchorPhrase, 'Chapter 15');
      expect(query.subject.recordTypeIds, contains('timeline-event'));
    });

    test('"Show every location on the map used in Book 1" scopes', () {
      final query =
          grammar.parse('Show every location on the map used in Book 1');
      expect(query.subject.recordTypeIds, contains('location'));
      expect(query.hasPredicate(CommandPredicateKind.onMap), isTrue);
      final scope = query.predicates
          .firstWhere((p) => p.kind == CommandPredicateKind.inBook);
      expect(scope.anchorPhrase, 'book 1');
    });

    test('"Show research connected to House Noxmere" keeps the name', () {
      final query = grammar.parse('Show research connected to House Noxmere');
      expect(query.subject.recordTypeIds, contains('research-entry'));
      expect(query.relation?.isAny, isTrue);
      expect(query.anchorPhrase, 'House Noxmere');
    });

    test('"Show canon conflicts" is the report, not canon `conflict` records',
        () {
      final query = grammar.parse('Show canon conflicts');
      expect(query.subject.isReport, isTrue);
      expect(query.subject.reportId, CommandSubject.canonConflictsReportId);
      expect(query.predicates, isEmpty);
    });

    test('"Show characters not yet assigned to a plot" negates', () {
      final query = grammar.parse('Show characters not yet assigned to a plot');
      final predicate = query.predicates.single;
      expect(predicate.kind, CommandPredicateKind.missingRelation);
      expect(predicate.target?.recordTypeIds, contains('plot-thread'));
      expect(query.subject.recordTypeIds, contains('character'));
    });

    test('"Show scenes with no location" spans both node kinds', () {
      final query = grammar.parse('Show scenes with no location');
      expect(query.subject.nodeTypes, contains('scene'));
      final predicate = query.predicates.single;
      expect(predicate.kind, CommandPredicateKind.missingRelation);
      expect(predicate.target?.recordTypeIds, contains('location'));
    });

    test('"Show timeline events with no chapter" targets a node kind', () {
      final query = grammar.parse('Show timeline events with no chapter');
      expect(query.subject.recordTypeIds, contains('timeline-event'));
      final predicate = query.predicates.single;
      expect(predicate.target?.nodeTypes, contains('chapter'));
    });
  });

  group('reading itself back', () {
    test('every recognised word becomes a chip the author can check', () {
      final query = grammar.parse('Show characters appearing in Chapter 20');
      final kinds = query.terms.map((term) => term.kind).toList();
      expect(kinds, contains(CommandTermKind.verb));
      expect(kinds, contains(CommandTermKind.subject));
      expect(kinds, contains(CommandTermKind.relation));
      expect(kinds, contains(CommandTermKind.anchor));
      expect(
        query.terms.firstWhere((t) => t.kind == CommandTermKind.relation).label,
        'Appears in',
      );
    });

    test('a phrase with no command in it searches instead of failing', () {
      final query = grammar.parse('the blood price');
      expect(query.isFreeText, isTrue);
      expect(query.text, 'the blood price');
    });

    test('nonsense never throws', () {
      for (final phrase in const ['', '   ', '?!', 'show', 'link', 'with no']) {
        expect(() => grammar.parse(phrase), returnsNormally);
      }
    });

    test('number is never load-bearing', () {
      expect(
        grammar.parse('show character').subject.recordTypeIds,
        grammar.parse('show characters').subject.recordTypeIds,
      );
    });
  });

  group('actions', () {
    test('"link Kali to Endovier" splits on the preposition', () {
      final query = grammar.parse('link Kali to Endovier');
      expect(query.verb, CommandVerb.link);
      expect(query.anchorPhrase, 'Kali');
      expect(query.linkTargetPhrase, 'Endovier');
      expect(query.isAction, isTrue);
    });

    test('"create character Cassian" names the type and the title', () {
      final query = grammar.parse('create character Cassian');
      expect(query.verb, CommandVerb.create);
      expect(query.subject.recordTypeIds, contains('character'));
      expect(query.anchorPhrase, 'Cassian');
    });
  });

  test('a type invented by a project is queryable without a code change', () {
    final custom = _grammar(
      extraRecordTypes: const [
        RecordTypeDefinition(
          id: 'blood-rite',
          name: 'Blood Rite',
          categoryId: 'magic',
          baseTypeId: 'general-lore',
          fields: [],
          sections: [],
        ),
      ],
    );

    expect(grammar.parse('show all blood rites').subject.recordTypeIds,
        isNot(contains('blood-rite')));
    expect(custom.parse('show all blood rites').subject.recordTypeIds,
        contains('blood-rite'));
    expect(custom.parse('show blood rite').subject.label, 'Blood Rite');
  });
}
