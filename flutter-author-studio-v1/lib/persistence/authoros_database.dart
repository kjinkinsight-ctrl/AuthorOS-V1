import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/connected_domain.dart';

part 'authoros_database.g.dart';

class ConnectedEntities extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get scopeId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'author_records_type', columns: {#typeId})
@TableIndex(name: 'author_records_scope', columns: {#scopeId})
class AuthorRecordRows extends Table {
  TextColumn get id => text().references(ConnectedEntities, #id)();
  TextColumn get typeId => text()();
  TextColumn get scopeType => text()();
  TextColumn get scopeId => text()();
  TextColumn get title => text()();
  TextColumn get status => text()();
  IntColumn get schemaVersion => integer()();
  IntColumn get revision => integer()();
  TextColumn get fieldsJson => text()();
  TextColumn get tagsJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get extensionJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'manuscript_nodes_project', columns: {#projectId})
class ManuscriptNodeRows extends Table {
  TextColumn get id => text().references(ConnectedEntities, #id)();
  TextColumn get projectId => text()();
  TextColumn get nodeType => text()();
  TextColumn get title => text()();
  IntColumn get revision => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get extensionJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'record_links_source', columns: {#sourceId})
@TableIndex(name: 'record_links_target', columns: {#targetId})
@TableIndex(name: 'record_links_scope', columns: {#scopeId})
class RecordLinkRows extends Table {
  TextColumn get id => text()();
  @ReferenceName('sourceLinks')
  TextColumn get sourceId => text().references(ConnectedEntities, #id)();
  @ReferenceName('targetLinks')
  TextColumn get targetId => text().references(ConnectedEntities, #id)();
  TextColumn get typeId => text()();
  TextColumn get scopeId => text()();
  TextColumn get direction => text()();
  TextColumn get label => text()();
  IntColumn get revision => integer()();
  TextColumn get metadataJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get extensionJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ConnectedEntities,
    AuthorRecordRows,
    ManuscriptNodeRows,
    RecordLinkRows,
  ],
)
class AuthorOsDatabase extends _$AuthorOsDatabase {
  AuthorOsDatabase(
    super.executor, {
    int schemaVersion = currentSchemaVersion,
  }) : _schemaVersion = schemaVersion;

  AuthorOsDatabase.defaults()
      : _schemaVersion = currentSchemaVersion,
        super(driftDatabase(name: 'authoros_creative'));

  static const currentSchemaVersion = 2;
  final int _schemaVersion;

  @override
  int get schemaVersion => _schemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          if (schemaVersion >= 2) {
            await _createSearchIndex();
          }
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2 && to >= 2) {
            await _createSearchIndex();
            await _rebuildSearchIndex();
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = FULL');
        },
      );

  Future<void> _createSearchIndex() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS author_search USING fts5(
        entity_id UNINDEXED,
        title,
        body
      )
    ''');
  }

  Future<void> _rebuildSearchIndex() async {
    await customStatement('DELETE FROM author_search');
    await customStatement('''
      INSERT INTO author_search(entity_id, title, body)
      SELECT id, title, fields_json || ' ' || tags_json
      FROM author_record_rows
    ''');
    await customStatement('''
      INSERT INTO author_search(entity_id, title, body)
      SELECT id, title, extension_json
      FROM manuscript_node_rows
    ''');
  }
}

class DriftConnectedDomainRepository {
  const DriftConnectedDomainRepository(this.database);

  final AuthorOsDatabase database;

  Future<void> putRecord(AuthorRecord record) async {
    await database.transaction(() async {
      await _putEntity(record.id, 'record', record.scopeId);
      await _putRecord(record);
    });
  }

  Future<void> putLink(RecordLink link) async {
    await database.transaction(() async {
      await _putLink(link);
    });
  }

  Future<List<AuthorRecord>> recordsByTypeAndScope({
    required String typeId,
    required String scopeId,
  }) async {
    final rows = await (database.select(database.authorRecordRows)
          ..where(
            (table) =>
                table.typeId.equals(typeId) & table.scopeId.equals(scopeId),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.title)]))
        .get();
    return rows.map(_recordFromRow).toList();
  }

  Future<void> replaceSnapshot(ConnectedDomainSnapshot snapshot) async {
    InMemoryConnectedDomainRepository(initial: snapshot);
    await database.transaction(() async {
      await database.delete(database.recordLinkRows).go();
      await database.delete(database.authorRecordRows).go();
      await database.delete(database.manuscriptNodeRows).go();
      await database.delete(database.connectedEntities).go();
      if (database.schemaVersion >= 2) {
        await database.customStatement('DELETE FROM author_search');
      }
      await _insertSnapshot(snapshot);
    });
  }

  Future<void> putConnectedSlice({
    required AuthorRecord record,
    required ManuscriptNodeReference manuscriptNode,
    required RecordLink link,
  }) async {
    final snapshot = ConnectedDomainSnapshot(
      records: [record],
      manuscriptNodes: [manuscriptNode],
      links: [link],
    );
    InMemoryConnectedDomainRepository(initial: snapshot);
    await database.transaction(() async {
      await _putEntity(record.id, 'record', record.scopeId);
      await _putRecord(record);
      await _putEntity(
        manuscriptNode.id,
        'manuscriptNode',
        manuscriptNode.projectId,
      );
      await _putManuscriptNode(manuscriptNode);
      await _putLink(link);
    });
  }

  Future<AuthorRecord?> recordById(String id) async {
    final row = await (database.select(database.authorRecordRows)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _recordFromRow(row);
  }

  Future<ManuscriptNodeReference?> manuscriptNodeById(String id) async {
    final row = await (database.select(database.manuscriptNodeRows)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _nodeFromRow(row);
  }

  Future<List<RecordLink>> backlinks(String entityId) async {
    final rows = await (database.select(database.recordLinkRows)
          ..where((table) =>
              table.sourceId.equals(entityId) | table.targetId.equals(entityId))
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    return rows.map(_linkFromRow).toList();
  }

  Future<List<String>> searchEntityIds(String query) async {
    if (database.schemaVersion < 2 || query.trim().isEmpty) {
      return [];
    }
    final rows = await database.customSelect(
      'SELECT entity_id FROM author_search WHERE author_search MATCH ? '
      'ORDER BY rank',
      variables: [Variable<String>(query.trim())],
    ).get();
    return rows.map((row) => row.read<String>('entity_id')).toList();
  }

  Future<ConnectedDomainSnapshot> snapshot() async {
    final recordRows = await (database.select(database.authorRecordRows)
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    final nodeRows = await (database.select(database.manuscriptNodeRows)
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    final linkRows = await (database.select(database.recordLinkRows)
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    return ConnectedDomainSnapshot(
      records: recordRows.map(_recordFromRow).toList(),
      manuscriptNodes: nodeRows.map(_nodeFromRow).toList(),
      links: linkRows.map(_linkFromRow).toList(),
    );
  }

  Future<void> _insertSnapshot(ConnectedDomainSnapshot snapshot) async {
    for (final record in snapshot.records) {
      await _putEntity(record.id, 'record', record.scopeId);
      await _putRecord(record);
    }
    for (final node in snapshot.manuscriptNodes) {
      await _putEntity(node.id, 'manuscriptNode', node.projectId);
      await _putManuscriptNode(node);
    }
    for (final link in snapshot.links) {
      await _putLink(link);
    }
  }

  Future<void> _putEntity(String id, String kind, String scopeId) =>
      database.into(database.connectedEntities).insertOnConflictUpdate(
            ConnectedEntitiesCompanion.insert(
              id: id,
              kind: kind,
              scopeId: scopeId,
            ),
          );

  Future<void> _putRecord(AuthorRecord record) async {
    await database.into(database.authorRecordRows).insertOnConflictUpdate(
          AuthorRecordRowsCompanion.insert(
            id: record.id,
            typeId: record.typeId,
            scopeType: record.scopeType.name,
            scopeId: record.scopeId,
            title: record.title,
            status: record.status.name,
            schemaVersion: record.schemaVersion,
            revision: record.revision,
            fieldsJson: jsonEncode(record.fields),
            tagsJson: jsonEncode(record.tags),
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            extensionJson: jsonEncode(record.extensionData),
          ),
        );
    await _indexEntity(
      record.id,
      record.title,
      '${record.fields.values.join(' ')} ${record.tags.join(' ')}',
    );
  }

  Future<void> _putManuscriptNode(ManuscriptNodeReference node) async {
    await database.into(database.manuscriptNodeRows).insertOnConflictUpdate(
          ManuscriptNodeRowsCompanion.insert(
            id: node.id,
            projectId: node.projectId,
            nodeType: node.nodeType,
            title: node.title,
            revision: node.revision,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
            extensionJson: jsonEncode(node.extensionData),
          ),
        );
    await _indexEntity(
      node.id,
      node.title,
      node.extensionData.values.join(' '),
    );
  }

  Future<void> _putLink(RecordLink link) =>
      database.into(database.recordLinkRows).insertOnConflictUpdate(
            RecordLinkRowsCompanion.insert(
              id: link.id,
              sourceId: link.sourceId,
              targetId: link.targetId,
              typeId: link.typeId,
              scopeId: link.scopeId,
              direction: link.direction.name,
              label: link.label,
              revision: link.revision,
              metadataJson: jsonEncode(link.metadata),
              createdAt: link.createdAt,
              updatedAt: link.updatedAt,
              extensionJson: jsonEncode(link.extensionData),
            ),
          );

  Future<void> _indexEntity(String id, String title, String body) async {
    if (database.schemaVersion < 2) {
      return;
    }
    await database.customStatement(
      'DELETE FROM author_search WHERE entity_id = ?',
      [id],
    );
    await database.customStatement(
      'INSERT INTO author_search(entity_id, title, body) VALUES (?, ?, ?)',
      [id, title, body],
    );
  }

  AuthorRecord _recordFromRow(AuthorRecordRow row) => AuthorRecord.fromJson({
        'id': row.id,
        'typeId': row.typeId,
        'scopeType': row.scopeType,
        'scopeId': row.scopeId,
        'title': row.title,
        'status': row.status,
        'schemaVersion': row.schemaVersion,
        'revision': row.revision,
        'fields': jsonDecode(row.fieldsJson),
        'tags': jsonDecode(row.tagsJson),
        'createdAt': row.createdAt.toUtc().toIso8601String(),
        'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        'extensionData': jsonDecode(row.extensionJson),
      });

  ManuscriptNodeReference _nodeFromRow(ManuscriptNodeRow row) =>
      ManuscriptNodeReference.fromJson({
        'id': row.id,
        'projectId': row.projectId,
        'nodeType': row.nodeType,
        'title': row.title,
        'revision': row.revision,
        'createdAt': row.createdAt.toUtc().toIso8601String(),
        'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        'extensionData': jsonDecode(row.extensionJson),
      });

  RecordLink _linkFromRow(RecordLinkRow row) => RecordLink.fromJson({
        'id': row.id,
        'sourceId': row.sourceId,
        'targetId': row.targetId,
        'typeId': row.typeId,
        'scopeId': row.scopeId,
        'direction': row.direction,
        'label': row.label,
        'revision': row.revision,
        'metadata': jsonDecode(row.metadataJson),
        'createdAt': row.createdAt.toUtc().toIso8601String(),
        'updatedAt': row.updatedAt.toUtc().toIso8601String(),
        'extensionData': jsonDecode(row.extensionJson),
      });
}
