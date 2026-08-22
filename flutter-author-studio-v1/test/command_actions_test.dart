/// Commands that change the project.
///
/// The property that matters most here is negative: preparing a command must
/// leave the database exactly as it found it. These tests check the database
/// itself rather than the returned status, because a status is easy to get
/// right while still having written something.
library;

import 'package:author_studio_v1/command_actions.dart';
import 'package:author_studio_v1/command_service.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _project = 'project-noxmere';
final _timestamp = DateTime.utc(2026, 8, 22, 9);

AuthorRecord _record(String id, String title, String typeId) => AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: _project,
      projectId: _project,
      canonStatus: CanonStatus.canon,
      title: title,
      createdAt: _timestamp,
      updatedAt: _timestamp,
    );

Future<CommandActionService> _seed() async {
  final database = AuthorOsDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final repository = DriftConnectedDomainRepository(database);
  await repository.putManuscriptNodes([
    ManuscriptNodeReference(
      id: 'chapter-20',
      projectId: _project,
      nodeType: 'chapter',
      title: 'Widow\'s Knife',
      createdAt: _timestamp,
      updatedAt: _timestamp,
      extensionData: const {'order': 20},
    ),
  ]);
  await repository.putRecordsAndLinks(
    records: [
      _record('kali', 'Kali', 'character'),
      _record('endovier', 'Endovier', 'location'),
      _record('noxmere', 'House Noxmere', 'faction'),
    ],
    links: const [],
  );
  return CommandActionService(
    commands: CommandService(projectId: _project, repository: repository),
  );
}

void main() {
  test('preparing a link writes nothing at all', () async {
    final actions = await _seed();
    final before = await actions.repository.snapshot();

    final query = await actions.commands.parse('link Kali to Endovier');
    final preview = await actions.prepare(query);

    expect(preview.isRefused, isFalse);
    expect(preview.summary, contains('Kali'));
    expect(preview.summary, contains('Endovier'));

    final after = await actions.repository.snapshot();
    expect(after.links, hasLength(before.links.length));
    expect(after.versions, hasLength(before.versions.length));
    expect(after.auditEvents, hasLength(before.auditEvents.length));
  });

  test('declining writes nothing', () async {
    final actions = await _seed();
    final query = await actions.commands.parse('link Kali to Endovier');
    final preview = await actions.prepare(query);

    final result = await actions.apply(preview, confirmed: false);

    expect(result.status, CommandActionStatus.cancelled);
    expect((await actions.repository.snapshot()).links, isEmpty);
  });

  test('an unguessable relationship is offered, not chosen', () async {
    final actions = await _seed();
    final query = await actions.commands.parse('link Kali to Endovier');
    final preview = await actions.prepare(query);

    // A character can live in, be born in, work in or visit a location. With
    // no way to tell which was meant, the command asks.
    expect(preview.needsConnectionChoice, isTrue);
    expect(preview.canApply, isFalse);
    expect(
      preview.connectionChoices.map((choice) => choice.typeId),
      contains('livesIn'),
    );

    final refused = await actions.apply(preview, confirmed: true);
    expect(refused.status, CommandActionStatus.refused);
    expect((await actions.repository.snapshot()).links, isEmpty);
  });

  test('confirming writes the edge, its version and its audit event', () async {
    final actions = await _seed();
    final query = await actions.commands.parse('link Kali to Endovier');
    final preview = await actions.prepare(query, connectionTypeId: 'livesIn');

    final result =
        await actions.apply(preview, confirmed: true, timestamp: _timestamp);
    expect(result.status, CommandActionStatus.applied);

    final snapshot = await actions.repository.snapshot();
    expect(snapshot.links, hasLength(1));
    expect(snapshot.links.single.id, result.linkId);
    // Proof the engine was used rather than bypassed: history came with it.
    expect(snapshot.versions, isNotEmpty);
    expect(snapshot.auditEvents, isNotEmpty);
  });

  test('the same link twice is refused, not duplicated', () async {
    final actions = await _seed();
    final query = await actions.commands.parse('link Kali to Endovier');
    await actions.apply(
      await actions.prepare(query, connectionTypeId: 'livesIn'),
      confirmed: true,
      timestamp: _timestamp,
    );

    final second = await actions.prepare(query, connectionTypeId: 'livesIn');
    expect(second.isRefused, isTrue);
    expect(second.refusal, contains('already connected'));
    expect((await actions.repository.snapshot()).links, hasLength(1));
  });

  test('linking a record to a scene or chapter goes through Manuscript Studio',
      () async {
    final actions = await _seed();
    final query = await actions.commands.parse('link Kali to Widow\'s Knife');
    final preview = await actions.prepare(
      query,
      connectionTypeId: 'appearsIn',
    );

    expect(preview.target?.isManuscriptNode, isTrue);
    final result =
        await actions.apply(preview, confirmed: true, timestamp: _timestamp);

    expect(result.status, CommandActionStatus.applied);
    final link = (await actions.repository.snapshot()).links.single;
    // Manuscript Studio owns the direction rule: `appearsIn` runs from the
    // record to the node, whichever way the author phrased it.
    expect(link.sourceId, 'kali');
    expect(link.targetId, 'chapter-20');
  });

  test('an unknown name is refused with the name in the reason', () async {
    final actions = await _seed();
    final query = await actions.commands.parse('link Kali to Nowhere');
    final preview = await actions.prepare(query);

    expect(preview.isRefused, isTrue);
    expect(preview.refusal, contains('Nowhere'));
    expect((await actions.repository.snapshot()).links, isEmpty);
  });

  test('a record cannot be connected to itself', () async {
    final actions = await _seed();
    final preview =
        await actions.prepare(await actions.commands.parse('link Kali to Kali'));

    expect(preview.isRefused, isTrue);
    expect(preview.refusal, contains('itself'));
  });

  group('creating', () {
    test('a character goes through Character Studio and is audited', () async {
      final actions = await _seed();
      final query = await actions.commands.parse('create character Cassian');
      final preview = await actions.prepare(query);

      expect(preview.summary, contains('Cassian'));
      expect((await actions.repository.snapshot()).records, hasLength(3));

      final result =
          await actions.apply(preview, confirmed: true, timestamp: _timestamp);
      expect(result.status, CommandActionStatus.applied);

      final created =
          await actions.repository.recordById(result.recordId!);
      expect(created?.title, 'Cassian');
      expect(created?.typeId, 'character');
      // Character Studio's template wiring, not a bare record.
      expect(created?.templateId, isNotNull);
      expect(created?.fields['identity.displayName'], 'Cassian');
      expect((await actions.repository.snapshot()).auditEvents, isNotEmpty);
    });

    test('a duplicate is refused and suggests connecting instead', () async {
      final actions = await _seed();
      final preview = await actions
          .prepare(await actions.commands.parse('create character Kali'));

      expect(preview.isRefused, isTrue);
      expect(preview.refusal, contains('already exists'));
    });

    test('a nameless create is refused', () async {
      final actions = await _seed();
      final preview = await actions
          .prepare(await actions.commands.parse('create character'));

      expect(preview.isRefused, isTrue);
    });
  });

  test('a read command is never treated as a write', () async {
    final actions = await _seed();
    final preview =
        await actions.prepare(await actions.commands.parse('Show me Kali'));

    expect(preview.isRefused, isTrue);
    expect(preview.refusal, contains('only reads'));
  });
}
