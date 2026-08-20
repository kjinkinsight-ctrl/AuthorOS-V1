import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/connection_engine.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one canonical link supports reverse discovery and project isolation',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    final repository = DriftConnectedDomainRepository(database);
    final projectA =
        ConnectionEngine(scopeId: 'project-a', repository: repository);
    final projectB =
        ConnectionEngine(scopeId: 'project-b', repository: repository);
    final timestamp = DateTime.utc(2026, 8, 18);
    await repository.putRecordsAndLinks(records: [
      _record('kali', 'Kali', 'project-a', timestamp),
      _record(
        'widow-network',
        'Widow Network',
        'project-a',
        timestamp,
        typeId: 'faction',
      ),
      _record('other-project', 'Other Project', 'project-b', timestamp),
    ], links: const []);

    final link = await projectA.connect(
      sourceId: 'kali',
      targetId: 'widow-network',
      typeId: 'memberOf',
      label: 'Member of',
      metadata: const {'rank': 'Founder'},
      timestamp: timestamp,
    );

    expect((await projectA.outgoing('kali')).single.id, link.id);
    expect((await projectA.incoming('widow-network')).single.id, link.id);
    expect((await projectA.linkedRecords('widow-network')).single.id, 'kali');
    expect(
      () => projectA.connect(
        sourceId: 'kali',
        targetId: 'other-project',
        typeId: 'relatedTo',
      ),
      throwsStateError,
    );
    expect(() => projectB.connections('kali'), throwsStateError);
    expect(
      () => projectA.connect(
        sourceId: 'kali',
        targetId: 'widow-network',
        typeId: 'livesIn',
      ),
      throwsStateError,
    );

    await projectA.disconnect(link.id);
    expect(await projectA.connections('kali'), isEmpty);
    expect(await repository.recordById('widow-network'), isNotNull);
    await database.close();
  });
}

AuthorRecord _record(
  String id,
  String title,
  String scopeId,
  DateTime timestamp, {
  String typeId = 'character',
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: scopeId,
      title: title,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
