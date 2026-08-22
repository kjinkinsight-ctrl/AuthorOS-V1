/// The shared recogniser.
///
/// Before this existed the same predicate was written three times, in the
/// Manuscript, Codex and World analyzers. These tests pin the behaviour all
/// three depended on, so collapsing them into one definition cannot quietly
/// change what counts as a mention.
library;

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/entity_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
