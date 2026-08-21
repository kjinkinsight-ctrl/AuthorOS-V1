import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/entity_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
