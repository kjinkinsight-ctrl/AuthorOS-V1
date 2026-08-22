/// The Command System, end to end.
///
/// Each test seeds a small world and asks one of the questions from the
/// feature's brief, then asserts on the exact ids that come back. The point is
/// not that a query runs — it is that the answer is the *right* answer,
/// including the awkward cases where the truth spans both Universal Records and
/// manuscript-domain nodes.
library;

import 'package:author_studio_v1/command_service.dart';
import 'package:author_studio_v1/core/command_query.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/search_models.dart';
import 'package:author_studio_v1/map_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _project = 'project-noxmere';
final _timestamp = DateTime.utc(2026, 8, 22, 9);

AuthorRecord _record(
  String id,
  String title, {
  required String typeId,
  Map<String, Object?> fields = const {},
  CanonStatus canonStatus = CanonStatus.canon,
  AuthorRecordStatus status = AuthorRecordStatus.active,
  String? bookId,
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: _project,
      projectId: _project,
      bookId: bookId,
      canonStatus: canonStatus,
      status: status,
      title: title,
      fields: fields,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    );

ManuscriptNodeReference _node(
  String id,
  String title, {
  required String nodeType,
  required int order,
  String? chapterId,
  String location = '',
}) =>
    ManuscriptNodeReference(
      id: id,
      projectId: _project,
      nodeType: nodeType,
      title: title,
      createdAt: _timestamp,
      updatedAt: _timestamp,
      extensionData: {
        'order': order,
        if (chapterId != null) 'chapterId': chapterId,
        if (nodeType == 'scene') 'location': location,
      },
    );

RecordLink _link(String source, String target, String typeId) => RecordLink(
      id: 'link-$source-$typeId-$target',
      sourceId: source,
      targetId: target,
      typeId: typeId,
      scopeId: _project,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    );

/// A world small enough to reason about and broad enough to exercise every
/// question: two node kinds, a map, a book, canon disagreement, and a plot
/// thread that was never resolved.
Future<CommandService> _seed() async {
  final database = AuthorOsDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final repository = DriftConnectedDomainRepository(database);

  await repository.putManuscriptNodes([
    _node('chapter-15', 'The Blood Price', nodeType: 'chapter', order: 15),
    _node('chapter-20', 'Widow\'s Knife', nodeType: 'chapter', order: 20),
    _node('scene-15a', 'The Cellar',
        nodeType: 'scene', order: 1, chapterId: 'chapter-15',
        location: 'Endovier'),
    _node('scene-20a', 'The Long Table',
        nodeType: 'scene', order: 1, chapterId: 'chapter-20'),
    _node('scene-20b', 'After',
        nodeType: 'scene', order: 2, chapterId: 'chapter-20'),
  ]);

  await repository.putRecordsAndLinks(
    records: [
      _record('book-1', 'Book 1', typeId: 'book'),
      _record('kali', 'Kali', typeId: 'character'),
      _record('cassian', 'Cassian', typeId: 'character'),
      _record('vincenzo', 'Vincenzo', typeId: 'character'),
      _record('lucia', 'Lucia', typeId: 'character'),
      _record('noxmere', 'House Noxmere', typeId: 'faction'),
      _record('map-endovier', 'Map of Endovier', typeId: 'map',
          bookId: 'book-1'),
      _record(
        'endovier',
        'Endovier',
        typeId: 'location',
        bookId: 'book-1',
        fields: {MapFields.mapId: 'map-endovier'},
      ),
      _record('undercity', 'The Undercity', typeId: 'location'),
      _record('blood-magic', 'Blood Magic', typeId: 'research-entry'),
      _record('red-widow', 'The Red Widow', typeId: 'plotline'),
      _record('the-debt', 'The Debt', typeId: 'plotline',
          fields: {'plotStatus': 'resolved'}),
      _record('blood-moon', 'The Blood Moon', typeId: 'timeline-event'),
      _record('the-fall', 'The Fall of Noxmere', typeId: 'timeline-event'),
      _record('unplaced', 'A Rumour', typeId: 'timeline-event'),
      _record('heresy', 'The Heresy', typeId: 'general-lore',
          canonStatus: CanonStatus.nonCanon),
    ],
    links: [
      // Kali's world.
      _link('kali', 'noxmere', 'memberOf'),
      _link('kali', 'endovier', 'livesIn'),
      _link('kali', 'scene-20a', 'appearsIn'),
      _link('kali', 'red-widow', 'pursues'),
      _link('cassian', 'scene-20a', 'appearsIn'),
      _link('vincenzo', 'scene-15a', 'appearsIn'),
      // Lucia is in no scene and on no plot.
      _link('blood-magic', 'noxmere', 'documents'),
      // Timeline anchoring: one event before chapter 15, one after chapter 20.
      _link('blood-moon', 'chapter-15', 'occursAt'),
      _link('the-fall', 'chapter-20', 'occursAt'),
      // A canon record joined to one the project has ruled out of canon.
      _link('kali', 'heresy', 'relatedTo'),
    ],
  );

  return CommandService(projectId: _project, repository: repository);
}

Set<String> _ids(CommandResult result) => {
      for (final group in result.groups)
        for (final row in group.rows) row.id,
    };

void main() {
  test('"Show me Kali" finds her and offers a way in', () async {
    final service = await _seed();
    final result = await service.run('Show me Kali');

    expect(_ids(result), contains('kali'));
    final row = result.groups
        .expand((group) => group.rows)
        .firstWhere((row) => row.id == 'kali');
    expect(row.navigationTarget?.destination,
        SearchDestination.characterStudio);
  });

  test('"Show everything connected to Kali" crosses both node kinds', () async {
    final service = await _seed();
    final result = await service.run('Show everything connected to Kali');

    // Records and a manuscript scene, from one question.
    expect(
      _ids(result),
      containsAll(<String>['noxmere', 'endovier', 'red-widow', 'scene-20a']),
    );
    final scene = result.groups
        .expand((group) => group.rows)
        .firstWhere((row) => row.id == 'scene-20a');
    expect(scene.kind, CommandRowKind.manuscriptNode);
    expect(scene.navigationTarget?.destination,
        SearchDestination.manuscriptStudio);
  });

  test('"Show all unresolved plot threads" excludes the resolved one',
      () async {
    final service = await _seed();
    final result = await service.run('Show all unresolved plot threads');

    expect(_ids(result), contains('red-widow'));
    expect(_ids(result), isNot(contains('the-debt')));
  });

  test('"Show characters appearing in Chapter 20" resolves the ordinal',
      () async {
    final service = await _seed();
    final result = await service.run('Show characters appearing in Chapter 20');

    expect(_ids(result), <String>{'kali', 'cassian'});
    expect(_ids(result), isNot(contains('vincenzo')));
  });

  test('"Show all events occurring before Chapter 15" orders by the manuscript',
      () async {
    final service = await _seed();
    final result =
        await service.run('Show all events occurring after Chapter 15');

    expect(_ids(result), contains('the-fall'));
    expect(_ids(result), isNot(contains('blood-moon')));
    // An event attached to no chapter has no position, and is left out rather
    // than guessed at.
    expect(_ids(result), isNot(contains('unplaced')));
  });

  test('"Show every location on the map used in Book 1" scopes twice',
      () async {
    final service = await _seed();
    final result =
        await service.run('Show every location on the map used in Book 1');

    expect(_ids(result), <String>{'endovier'});
    expect(_ids(result), isNot(contains('undercity')));
  });

  test('"Show research connected to House Noxmere" traverses inward', () async {
    final service = await _seed();
    final result =
        await service.run('Show research connected to House Noxmere');

    expect(_ids(result), <String>{'blood-magic'});
  });

  test('"Show characters not yet assigned to a plot" finds the forgotten one',
      () async {
    final service = await _seed();
    final result =
        await service.run('Show characters not yet assigned to a plot');

    expect(_ids(result), contains('lucia'));
    expect(_ids(result), isNot(contains('kali')));
  });

  test('"Show scenes with no location" respects the prose field too', () async {
    final service = await _seed();
    final result = await service.run('Show scenes with no location');

    // scene-20a and scene-20b have neither a location link nor a location
    // named in the manuscript; scene-15a names Endovier in prose.
    expect(_ids(result), <String>{'scene-20a', 'scene-20b'});
    expect(_ids(result), isNot(contains('scene-15a')));
  });

  test('"Show timeline events with no chapter" targets a node kind', () async {
    final service = await _seed();
    final result = await service.run('Show timeline events with no chapter');

    expect(_ids(result), contains('unplaced'));
    expect(_ids(result), isNot(contains('blood-moon')));
  });

  test('"Show canon conflicts" reports a canon record joined to a non-canon one',
      () async {
    final service = await _seed();
    final result = await service.run('Show canon conflicts');

    final details = result.groups
        .expand((group) => group.rows)
        .map((row) => row.detail)
        .join('\n');
    expect(details, contains('Kali'));
    expect(details, contains('The Heresy'));
  });

  group('when it cannot be sure', () {
    test('an unknown name says so rather than inventing a result', () async {
      final service = await _seed();
      final result = await service.run('Show everything connected to Nobody');

      expect(result.isEmpty, isTrue);
      expect(result.message, contains('Nobody'));
    });

    test('an ambiguous name asks instead of guessing', () async {
      final service = await _seed();
      final repository = service.repository;
      await repository.putRecordsAndLinks(
        records: [_record('kali-2', 'Kali', typeId: 'location')],
        links: const [],
      );

      final result = await service.run('Show everything connected to Kali');
      expect(result.needsDisambiguation, isTrue);
      expect(result.candidates.map((c) => c.id), containsAll(['kali', 'kali-2']));

      // Once the author picks, the same query runs against that entity.
      final resolved = await service.execute(
        await service.parse('Show everything connected to Kali'),
        anchorId: 'kali',
      );
      expect(resolved.needsDisambiguation, isFalse);
      expect(_ids(resolved), contains('noxmere'));
    });

    test('a phrase with no command in it still searches', () async {
      final service = await _seed();
      final result = await service.run('Endovier');

      expect(result.query.isFreeText, isTrue);
      expect(_ids(result), contains('endovier'));
    });
  });

  test('reading never writes', () async {
    final service = await _seed();
    final before = await service.repository.snapshot();

    for (final phrase in const [
      'Show me Kali',
      'Show everything connected to Kali',
      'Show scenes with no location',
      'Show canon conflicts',
    ]) {
      await service.run(phrase);
    }

    final after = await service.repository.snapshot();
    expect(after.records.length, before.records.length);
    expect(after.links.length, before.links.length);
    expect(after.manuscriptNodes.length, before.manuscriptNodes.length);
    expect(after.versions.length, before.versions.length);
    expect(after.auditEvents.length, before.auditEvents.length);
  });
}
