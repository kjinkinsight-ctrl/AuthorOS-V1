import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:isar_community/isar.dart';
import 'package:sqlite3/sqlite3.dart';

part 'storage_benchmark.g.dart';

const recordCount = 2500;
const linkCount = 15000;
const lookupCount = 1000;

@collection
class IsarBenchmarkRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, type: IndexType.value)
  late String canonicalId;

  @Index(type: IndexType.value)
  late String typeId;

  late String scopeId;
  late String title;
  late String payload;
  late int revision;
}

@collection
class IsarBenchmarkLink {
  Id id = Isar.autoIncrement;

  @Index(unique: true, type: IndexType.value)
  late String canonicalId;

  @Index(type: IndexType.value)
  late String sourceId;

  @Index(type: IndexType.value)
  late String targetId;

  late String typeId;
  late String scopeId;
  late String metadata;
  late int revision;
}

Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('authoros-storage-');
  try {
    await Isar.initializeIsarCore(download: true);
    final workload = BenchmarkWorkload.create();
    final sqlite = _benchmarkSqlite(root, workload);
    final isar = await _benchmarkIsar(root, workload);
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'benchmarkVersion': 1,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'durability': {
          'sqlite': 'WAL, synchronous FULL',
          'isar': 'relaxedDurability false',
        },
        'workload': {
          'records': recordCount,
          'links': linkCount,
          'indexedLookups': lookupCount,
          'backlinkQueries': lookupCount,
        },
        'results': [sqlite, isar],
        'note': 'Run multiple times in release mode on each target platform. '
            'Microbenchmarks inform but do not replace migration, FTS, '
            'tooling, and maintainability evaluation.',
      }),
    );
  } finally {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  }
}

Map<String, Object> _benchmarkSqlite(
  Directory root,
  BenchmarkWorkload workload,
) {
  final path = '${root.path}${Platform.pathSeparator}authoros.sqlite';
  final database = sqlite3.open(path);
  database.execute('PRAGMA journal_mode = WAL;');
  database.execute('PRAGMA synchronous = FULL;');
  database.execute('PRAGMA foreign_keys = ON;');
  database.execute('''
    CREATE TABLE records (
      canonical_id TEXT PRIMARY KEY,
      type_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      title TEXT NOT NULL,
      payload TEXT NOT NULL,
      revision INTEGER NOT NULL
    );
    CREATE INDEX records_type_id ON records(type_id);
    CREATE TABLE links (
      canonical_id TEXT PRIMARY KEY,
      source_id TEXT NOT NULL REFERENCES records(canonical_id),
      target_id TEXT NOT NULL REFERENCES records(canonical_id),
      type_id TEXT NOT NULL,
      scope_id TEXT NOT NULL,
      metadata TEXT NOT NULL,
      revision INTEGER NOT NULL
    );
    CREATE INDEX links_source_id ON links(source_id);
    CREATE INDEX links_target_id ON links(target_id);
  ''');

  final insertWatch = Stopwatch()..start();
  database.execute('BEGIN IMMEDIATE;');
  try {
    final insertRecord = database.prepare(
      'INSERT INTO records VALUES (?, ?, ?, ?, ?, ?)',
    );
    final insertLink = database.prepare(
      'INSERT INTO links VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    try {
      for (final record in workload.records) {
        insertRecord.execute([
          record.id,
          record.typeId,
          record.scopeId,
          record.title,
          record.payload,
          record.revision,
        ]);
      }
      for (final link in workload.links) {
        insertLink.execute([
          link.id,
          link.sourceId,
          link.targetId,
          link.typeId,
          link.scopeId,
          link.metadata,
          link.revision,
        ]);
      }
    } finally {
      insertRecord.close();
      insertLink.close();
    }
    database.execute('COMMIT;');
  } catch (_) {
    database.execute('ROLLBACK;');
    rethrow;
  }
  insertWatch.stop();

  final lookup = database.prepare(
    'SELECT title FROM records WHERE canonical_id = ?',
  );
  final lookupWatch = Stopwatch()..start();
  var lookupChecksum = 0;
  try {
    for (final id in workload.lookupIds) {
      final rows = lookup.select([id]);
      lookupChecksum += (rows.single['title'] as String).length;
    }
  } finally {
    lookup.close();
  }
  lookupWatch.stop();

  final backlinks = database.prepare('''
    SELECT canonical_id FROM links
    WHERE source_id = ? OR target_id = ?
  ''');
  final backlinkWatch = Stopwatch()..start();
  var backlinkChecksum = 0;
  try {
    for (final id in workload.lookupIds) {
      backlinkChecksum += backlinks.select([id, id]).length;
    }
  } finally {
    backlinks.close();
  }
  backlinkWatch.stop();

  final transactionWatch = Stopwatch()..start();
  database.execute('BEGIN IMMEDIATE;');
  try {
    database.execute(
      "UPDATE records SET title = 'Updated', revision = revision + 1 "
      "WHERE canonical_id = 'record-0'",
    );
    database.execute(
      "UPDATE links SET revision = revision + 1 "
      "WHERE canonical_id = 'link-0'",
    );
    database.execute('COMMIT;');
  } catch (_) {
    database.execute('ROLLBACK;');
    rethrow;
  }
  transactionWatch.stop();
  database.execute('PRAGMA wal_checkpoint(TRUNCATE);');
  database.close();

  return {
    'candidate': 'Drift/SQLite engine',
    'insertMilliseconds': insertWatch.elapsedMilliseconds,
    'lookupMilliseconds': lookupWatch.elapsedMilliseconds,
    'backlinkMilliseconds': backlinkWatch.elapsedMilliseconds,
    'transactionMicroseconds': transactionWatch.elapsedMicroseconds,
    'fileBytes': File(path).lengthSync(),
    'lookupChecksum': lookupChecksum,
    'backlinkChecksum': backlinkChecksum,
  };
}

Future<Map<String, Object>> _benchmarkIsar(
  Directory root,
  BenchmarkWorkload workload,
) async {
  final isar = Isar.openSync(
    [IsarBenchmarkRecordSchema, IsarBenchmarkLinkSchema],
    directory: root.path,
    name: 'authoros_isar',
    relaxedDurability: false,
    inspector: false,
  );
  final records = isar.collection<IsarBenchmarkRecord>();
  final links = isar.collection<IsarBenchmarkLink>();

  final isarRecords = [
    for (final record in workload.records)
      IsarBenchmarkRecord()
        ..canonicalId = record.id
        ..typeId = record.typeId
        ..scopeId = record.scopeId
        ..title = record.title
        ..payload = record.payload
        ..revision = record.revision,
  ];
  final isarLinks = [
    for (final link in workload.links)
      IsarBenchmarkLink()
        ..canonicalId = link.id
        ..sourceId = link.sourceId
        ..targetId = link.targetId
        ..typeId = link.typeId
        ..scopeId = link.scopeId
        ..metadata = link.metadata
        ..revision = link.revision,
  ];

  final insertWatch = Stopwatch()..start();
  isar.writeTxnSync(() {
    records.putAllSync(isarRecords);
    links.putAllSync(isarLinks);
  });
  insertWatch.stop();

  final lookupWatch = Stopwatch()..start();
  var lookupChecksum = 0;
  for (final id in workload.lookupIds) {
    final record = records.getByCanonicalIdSync(id);
    lookupChecksum += record!.title.length;
  }
  lookupWatch.stop();

  final backlinkWatch = Stopwatch()..start();
  var backlinkChecksum = 0;
  for (final id in workload.lookupIds) {
    backlinkChecksum +=
        links.filter().sourceIdEqualTo(id).or().targetIdEqualTo(id).countSync();
  }
  backlinkWatch.stop();

  final transactionWatch = Stopwatch()..start();
  isar.writeTxnSync(() {
    final record = records.getByCanonicalIdSync('record-0')!
      ..title = 'Updated'
      ..revision += 1;
    final link = links.getByCanonicalIdSync('link-0')!..revision += 1;
    records.putSync(record);
    links.putSync(link);
  });
  transactionWatch.stop();
  final size = isar.getSizeSync(includeIndexes: true, includeLinks: true);
  await isar.close(deleteFromDisk: false);

  return {
    'candidate': 'Isar Community',
    'insertMilliseconds': insertWatch.elapsedMilliseconds,
    'lookupMilliseconds': lookupWatch.elapsedMilliseconds,
    'backlinkMilliseconds': backlinkWatch.elapsedMilliseconds,
    'transactionMicroseconds': transactionWatch.elapsedMicroseconds,
    'fileBytes': size,
    'lookupChecksum': lookupChecksum,
    'backlinkChecksum': backlinkChecksum,
  };
}

class BenchmarkWorkload {
  const BenchmarkWorkload({
    required this.records,
    required this.links,
    required this.lookupIds,
  });

  factory BenchmarkWorkload.create() {
    final random = Random(20260817);
    final records = [
      for (var index = 0; index < recordCount; index++)
        BenchmarkRecord(
          id: 'record-$index',
          typeId: switch (index % 5) {
            0 => 'character',
            1 => 'location',
            2 => 'scene',
            3 => 'event',
            _ => 'lore',
          },
          scopeId: 'fixture-project-large',
          title: 'Record $index',
          payload: jsonEncode({
            'summary': 'Deterministic benchmark content for record $index.',
            'tags': ['tag-${index % 20}', 'group-${index % 7}'],
          }),
          revision: 1,
        ),
    ];
    final links = [
      for (var index = 0; index < linkCount; index++)
        BenchmarkLink(
          id: 'link-$index',
          sourceId: 'record-${random.nextInt(recordCount)}',
          targetId: 'record-${random.nextInt(recordCount)}',
          typeId: 'relationship-${index % 8}',
          scopeId: 'fixture-project-large',
          metadata: jsonEncode({'order': index, 'active': true}),
          revision: 1,
        ),
    ];
    final lookupIds = [
      for (var index = 0; index < lookupCount; index++)
        'record-${random.nextInt(recordCount)}',
    ];
    return BenchmarkWorkload(
      records: records,
      links: links,
      lookupIds: lookupIds,
    );
  }

  final List<BenchmarkRecord> records;
  final List<BenchmarkLink> links;
  final List<String> lookupIds;
}

class BenchmarkRecord {
  const BenchmarkRecord({
    required this.id,
    required this.typeId,
    required this.scopeId,
    required this.title,
    required this.payload,
    required this.revision,
  });

  final String id;
  final String typeId;
  final String scopeId;
  final String title;
  final String payload;
  final int revision;
}

class BenchmarkLink {
  const BenchmarkLink({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.typeId,
    required this.scopeId,
    required this.metadata,
    required this.revision,
  });

  final String id;
  final String sourceId;
  final String targetId;
  final String typeId;
  final String scopeId;
  final String metadata;
  final int revision;
}
