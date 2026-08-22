import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/entity_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shared recogniser.
///
/// Before this existed the same predicate was written three times, in the
/// Manuscript, Codex and World analyzers. These tests pin the behaviour all
/// three depended on — in both the shapes it is offered in, the matcher class
/// and the one-shot functions — so collapsing them into one definition cannot
/// quietly change what counts as a mention.

AuthorRecord _record(
  String id,
  String title, {
  Map<String, Object?> fields = const {},
  AuthorRecordStatus status = AuthorRecordStatus.active,
}) =>
    AuthorRecord(
      id: id,
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      title: title,
      status: status,
      fields: {'name': title, ...fields},
      createdAt: DateTime.utc(2026, 8, 21),
      updatedAt: DateTime.utc(2026, 8, 21),
    );

void main() {
  group('matching', () {
    const matcher = EntityNameMatcher();

    test('a name is matched on word boundaries, not inside another word', () {
      expect(matcher.mentions('Kali entered the room.', 'Kali'), isTrue);
      expect(matcher.mentions('"Kali," he said.', 'Kali'), isTrue);
      expect(matcher.mentions('kali entered', 'Kali'), isTrue);
      expect(matcher.mentions('Kalinda entered', 'Kali'), isFalse);
      expect(matcher.mentions('The Kali.', 'Kali'), isTrue);
    });

    test('short names are ignored so common words produce no noise', () {
      expect(matcher.isLongEnough('Kali'), isTrue);
      expect(matcher.isLongEnough('Ari'), isFalse);
      expect(const EntityNameMatcher(minimumLength: 3).isLongEnough('Ari'),
          isTrue);
    });

    test('spans locate every mention, including adjacent ones', () {
      final spans = matcher.spans('Kali and Kali again.', 'Kali');
      expect(spans, hasLength(2));
      expect(spans.first.start, 0);
      expect(spans.first.end, 4);
      expect(spans.last.start, 9);
    });

    test('an empty name matches nothing', () {
      expect(matcher.mentions('Kali entered.', '   '), isFalse);
      expect(matcher.spans('Kali entered.', ''), isEmpty);
    });
  });

  group('names', () {
    test('aliases are read from every field an author might use', () {
      // The union of what Manuscript, Codex and World each read separately.
      final record = _record('kali', 'Kali Vale', fields: const {
        'aliases': ['Red Widow'],
        'alternateNames': 'The Widow',
        'historicalNames': 'Kali of Endovier',
        'nicknames': ['Vale'],
      });

      expect(
        EntityNames.aliasesOf(record),
        ['Red Widow', 'The Widow', 'Kali of Endovier', 'Vale'],
      );
      expect(EntityNames.namesOf(record).first, 'Kali Vale');
    });

    test('a stored value is split whether it is a list or a string', () {
      expect(EntityNames.split(['a', 'b']), ['a', 'b']);
      expect(EntityNames.split('a, b; c\nd'), ['a', 'b', 'c', 'd']);
      expect(EntityNames.split('  '), isEmpty);
      expect(EntityNames.split(null), isEmpty);
      expect(EntityNames.split(7), isEmpty);
    });

    test('a duplicate alias is recorded once', () {
      final record = _record('kali', 'Kali Vale', fields: const {
        'aliases': ['Red Widow'],
        'alternateNames': ['red widow'],
      });
      expect(EntityNames.aliasesOf(record), ['Red Widow']);
    });

    test('knownNames spans every studio so nothing is reported missing', () {
      final names = EntityNames.knownNames([
        _record('kali', 'Kali Vale', fields: const {
          'aliases': ['Red Widow']
        }),
        _record('endovier', 'Endovier'),
      ]);
      expect(names, containsAll(<String>{'Kali Vale', 'Red Widow', 'Endovier'}));
    });
  });

  group('index', () {
    final index = EntityNameIndex.fromRecords([
      _record('kali', 'Kali Vale', fields: const {
        'aliases': ['Red Widow', 'Kali']
      }),
      _record('noxmere', 'House Noxmere'),
      _record('estate', 'Noxmere'),
      _record('gone', 'Deleted One', status: AuthorRecordStatus.deleted),
    ]);

    test('a deleted record is not recognised', () {
      expect(index.idsFor('Deleted One'), isEmpty);
      expect(index.isKnown('Deleted One'), isFalse);
    });

    test('a title and an alias both resolve to the entity', () {
      expect(index.idsFor('Kali Vale'), ['kali']);
      expect(index.idsFor('red widow'), ['kali']);
      expect(index.titleOf('kali'), 'Kali Vale');
    });

    test('the longer name wins, so a sub-name is not double-reported', () {
      final mentions = index.scan('She walked toward the House Noxmere estate.');
      expect(mentions, hasLength(1));
      expect(mentions.single.matchedName, 'House Noxmere');
      expect(mentions.single.entityId, 'noxmere');
    });

    test('a name meaning two entities is reported as ambiguous', () {
      // "Kali" is Kali Vale's alias. Add a second entity with that title and
      // the name stops being answerable — which the author has to resolve, not
      // the software.
      final ambiguous = EntityNameIndex.fromRecords([
        _record('kali', 'Kali Vale', fields: const {
          'aliases': ['Kali']
        }),
        _record('ship', 'Kali'),
      ]);
      final mention = ambiguous.scan('Kali entered the room.').single;
      expect(mention.isAmbiguous, isTrue);
      expect(mention.entityId, isNull);
      expect(mention.entityIds, containsAll(<String>{'kali', 'ship'}));
    });

    test('a scan reports where each name sits and whether it was an alias', () {
      final mentions = index.scan('The Red Widow met Kali Vale.');
      expect(mentions.map((each) => each.matchedName),
          ['Red Widow', 'Kali Vale']);
      expect(mentions.first.isAlias, isTrue);
      expect(mentions.last.isAlias, isFalse);
      expect(
        'The Red Widow met Kali Vale.'
            .substring(mentions.first.start, mentions.first.end),
        'Red Widow',
      );
    });

    test('mentions come back in reading order', () {
      final mentions = index.scan('House Noxmere, then Kali Vale.');
      expect(mentions.map((each) => each.start),
          [0, 'House Noxmere, then '.length]);
    });

    test('a limit caps a long scan', () {
      expect(index.scan('Kali Vale and House Noxmere.', limit: 1), hasLength(1));
    });

    test('empty prose scans to nothing', () {
      expect(index.scan('   '), isEmpty);
    });
  });

  test('there is exactly one mention matcher in lib/', () {
    // Manuscript, Codex and World each carried a byte-identical private
    // `_mentions`. One matcher means a name resolves the same way everywhere;
    // a fourth copy is how they drift apart again.
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('core/entity_recognition.dart'))
        .where((file) =>
            file.readAsStringSync().contains('bool _mentions(String prose'))
        .map((file) => file.path)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'Use EntityNameMatcher in core/entity_recognition.dart instead '
          'of adding another private matcher.',
    );
  });

  group('mentionsName', () {
    test('matches a whole word regardless of case', () {
      expect(mentionsName('kali walked north', 'Kali'), isTrue);
      expect(mentionsName('kali walked north', 'KALI'), isTrue);
    });

    test('does not match a substring', () {
      expect(mentionsName('kalina walked north', 'Kali'), isFalse);
      expect(mentionsName('the harbourmaster', 'harbour'), isFalse);
    });

    test('treats punctuation and possessives as boundaries', () {
      expect(mentionsName("kali's blade", 'Kali'), isTrue);
      expect(mentionsName('kali, then endovier', 'Kali'), isTrue);
      expect(mentionsName('"kali"', 'Kali'), isTrue);
      expect(mentionsName('kali', 'Kali'), isTrue);
    });

    test('matches multi-word names', () {
      expect(mentionsName('house noxmere holds the pass', 'House Noxmere'),
          isTrue);
      expect(mentionsName('house holds the pass', 'House Noxmere'), isFalse);
    });

    test('an empty or blank name never matches', () {
      expect(mentionsName('anything at all', ''), isFalse);
      expect(mentionsName('anything at all', '   '), isFalse);
    });

    test('a regex metacharacter in a name is matched literally', () {
      expect(mentionsName('the c.o.g. guild', 'c.o.g.'), isTrue);
      expect(mentionsName('the cxoxgx guild', 'c.o.g.'), isFalse,
          reason: 'an unescaped dot would match any character');
    });
  });

  group('firstMention', () {
    test('returns the matched name so a recommendation can quote it', () {
      expect(
        firstMention('the red widow crossed the ice', ['Kali', 'The Red Widow']),
        'The Red Widow',
      );
    });

    test('ignores names shorter than the minimum', () {
      expect(firstMention('vex walked north', ['Vex']), isNull,
          reason: 'short names are common words more often than entities');
      expect(firstMention('vex walked north', ['Vex'], minimumLength: 3), 'Vex');
    });

    test('returns null when nothing matches', () {
      expect(firstMention('nobody here', ['Kali', 'Endovier']), isNull);
    });
  });

  group('splitNames', () {
    test('splits a delimited string', () {
      expect(splitNames('Kali, The Red Widow; Vale'),
          ['Kali', 'The Red Widow', 'Vale']);
    });

    test('accepts a list and drops blanks', () {
      expect(splitNames(['Kali', '  ', 'Vale']), ['Kali', 'Vale']);
    });

    test('anything else is no names at all', () {
      expect(splitNames(null), isEmpty);
      expect(splitNames(42), isEmpty);
    });
  });

  group('aliasesOfRecord', () {
    AuthorRecord recordWith(Map<String, Object?> fields) {
      final now = DateTime.utc(2026, 8, 22);
      return AuthorRecord(
        id: 'kali',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: 'book-1',
        projectId: 'book-1',
        title: 'Kali Vale',
        fields: fields,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('reads every alias field any Studio writes', () {
      final record = recordWith({
        'aliases': 'The Red Widow',
        'alternateNames': ['Kali of Vale'],
        'historicalNames': 'The Widow',
        'nicknames': 'Red',
        'identity.aliases': 'Vale',
      });

      expect(
        aliasesOfRecord(record),
        containsAll(<String>[
          'The Red Widow',
          'Kali of Vale',
          'The Widow',
          'Red',
          'Vale',
        ]),
      );
    });

    test('the same alias written twice is returned once', () {
      final record = recordWith({
        'aliases': 'The Red Widow',
        'nicknames': 'The Red Widow',
      });

      expect(aliasesOfRecord(record), ['The Red Widow']);
    });

    test('a record with no alias fields has no aliases', () {
      expect(aliasesOfRecord(recordWith(const {})), isEmpty);
    });
  });
}
