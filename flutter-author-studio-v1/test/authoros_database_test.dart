import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('authoros-db-');
    databaseFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}authoros.sqlite',
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('version 1 reopens at version 2 with data, extensions, and FTS',
      () async {
    final versionOne = AuthorOsDatabase(
      NativeDatabase(databaseFile),
      schemaVersion: 1,
    );
    final versionOneRepository = DriftConnectedDomainRepository(versionOne);
    final initial = _connectedSlice();

    await versionOneRepository.replaceSnapshot(initial);
    expect(await versionOneRepository.searchEntityIds('cartographer'), isEmpty);
    await versionOne.close();

    final versionTwo = AuthorOsDatabase(NativeDatabase(databaseFile));
    final versionTwoRepository = DriftConnectedDomainRepository(versionTwo);
    final restored = await versionTwoRepository.snapshot();

    expect(restored.records.single.id, 'character-ari');
    expect(
      restored.records.single.extensionData['futureField'],
      {'retained': true},
    );
    expect(restored.manuscriptNodes.single.id, 'scene-opening');
    expect(restored.links.single.id, 'link-ari-opening');
    expect(
      await versionTwoRepository.searchEntityIds('cartographer'),
      ['character-ari'],
    );
    await versionTwo.close();
  });

  test('repository persists one canonical backlink from either entity',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());
    final repository = DriftConnectedDomainRepository(database);
    final slice = _connectedSlice();

    await repository.putConnectedSlice(
      record: slice.records.single,
      manuscriptNode: slice.manuscriptNodes.single,
      link: slice.links.single,
    );

    expect(
      (await repository.backlinks('character-ari')).single.id,
      'link-ari-opening',
    );
    expect(
      (await repository.backlinks('scene-opening')).single.id,
      'link-ari-opening',
    );
    await database.close();
  });

  test('foreign keys reject dangling links', () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());

    await expectLater(
      database.into(database.recordLinkRows).insert(
            RecordLinkRowsCompanion.insert(
              id: 'dangling-link',
              sourceId: 'missing-source',
              targetId: 'missing-target',
              typeId: 'appearsIn',
              scopeId: 'project-1',
              direction: 'directed',
              label: 'Appears in',
              revision: 1,
              metadataJson: '{}',
              createdAt: DateTime.utc(2026, 8, 17),
              updatedAt: DateTime.utc(2026, 8, 17),
              extensionJson: '{}',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
    expect(await database.select(database.recordLinkRows).get(), isEmpty);
    await database.close();
  });

  test('failed database transaction rolls back every inserted entity',
      () async {
    final database = AuthorOsDatabase(NativeDatabase.memory());

    await expectLater(
      database.transaction(() async {
        await database.into(database.connectedEntities).insert(
              const ConnectedEntitiesCompanion(
                id: Value('character-ari'),
                kind: Value('record'),
                scopeId: Value('project-1'),
              ),
            );
        throw StateError('forced failure');
      }),
      throwsStateError,
    );

    expect(await database.select(database.connectedEntities).get(), isEmpty);
    await database.close();
  });

  test('WAL recovery removes an uncommitted row after process termination',
      () async {
    final initialDatabase = AuthorOsDatabase(NativeDatabase(databaseFile));
    await initialDatabase.customSelect('SELECT 1').get();
    await initialDatabase.close();

    final readyFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}writer-ready',
    );
    final process = await Process.start(
      _dartExecutable(),
      [
        'run',
        'tool/wal_crash_writer.dart',
        databaseFile.path,
        readyFile.path,
      ],
      workingDirectory: Directory.current.path,
    );
    addTearDown(() => _terminateProcess(process));

    for (var attempt = 0; attempt < 600 && !readyFile.existsSync(); attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    if (!readyFile.existsSync()) {
      await _terminateProcess(process);
      final errors = await process.stderr
          .transform(const SystemEncoding().decoder)
          .join()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => 'No crash-writer diagnostics were available.',
          );
      fail('Crash writer did not reach its transaction: $errors');
    }
    await _terminateProcess(process);
    await process.exitCode.timeout(const Duration(seconds: 10));

    final recoveredDatabase = AuthorOsDatabase(NativeDatabase(databaseFile));
    final recoveredRepository =
        DriftConnectedDomainRepository(recoveredDatabase);
    final crashedRows =
        await (recoveredDatabase.select(recoveredDatabase.connectedEntities)
              ..where((table) => table.id.equals('uncommitted-crash-row')))
            .get();
    expect(crashedRows, isEmpty);

    await recoveredRepository.replaceSnapshot(_connectedSlice());
    expect(
      (await recoveredRepository.recordById('character-ari'))?.title,
      'Ari Vale',
    );
    await recoveredDatabase.close();
  }, timeout: const Timeout(Duration(minutes: 1)));
}

Future<void> _terminateProcess(Process process) async {
  if (Platform.isWindows) {
    await Process.run(
      'taskkill',
      ['/PID', '${process.pid}', '/T', '/F'],
      runInShell: true,
    );
  } else {
    process.kill(ProcessSignal.sigkill);
  }
}

String _dartExecutable() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (directory.parent.path != directory.path) {
    final executableName = Platform.isWindows ? 'dart.exe' : 'dart';
    final candidate = File(
      '${directory.path}${Platform.pathSeparator}dart-sdk'
      '${Platform.pathSeparator}bin${Platform.pathSeparator}$executableName',
    );
    if (candidate.existsSync()) {
      return candidate.path;
    }
    directory = directory.parent;
  }
  throw StateError('Unable to locate the Dart SDK executable.');
}

ConnectedDomainSnapshot _connectedSlice() {
  final timestamp = DateTime.utc(2026, 8, 17);
  return ConnectedDomainSnapshot(
    records: [
      AuthorRecord(
        id: 'character-ari',
        typeId: 'character',
        scopeType: RecordScopeType.project,
        scopeId: 'project-1',
        title: 'Ari Vale',
        fields: const {
          'summary': 'A harbor cartographer.',
        },
        tags: const ['protagonist'],
        createdAt: timestamp,
        updatedAt: timestamp,
        extensionData: const {
          'futureField': {'retained': true},
        },
      ),
    ],
    manuscriptNodes: [
      ManuscriptNodeReference(
        id: 'scene-opening',
        projectId: 'project-1',
        nodeType: 'scene',
        title: 'The Message',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ],
    links: [
      RecordLink(
        id: 'link-ari-opening',
        sourceId: 'character-ari',
        targetId: 'scene-opening',
        typeId: 'appearsIn',
        scopeId: 'project-1',
        label: 'Appears in',
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ],
  );
}
