import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/connected_domain.dart';
import '../core/connection_types.dart';
import '../core/record_types.dart';
import '../core/relationship_validation.dart';
import '../core/branch_domain.dart';
import '../core/search_models.dart';
import '../core/version_audit.dart';
import '../core/writing_session.dart';

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
@TableIndex(name: 'author_records_project', columns: {#projectId})
@TableIndex(name: 'author_records_series_book', columns: {#seriesId, #bookId})
@TableIndex(name: 'author_records_branch', columns: {#branchId})
class AuthorRecordRows extends Table {
  TextColumn get id => text().references(ConnectedEntities, #id)();
  TextColumn get typeId => text()();
  TextColumn get scopeType => text()();
  TextColumn get scopeId => text()();
  TextColumn get projectId => text().nullable()();
  TextColumn get seriesId => text().nullable()();
  TextColumn get bookId => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get canonStatus => text().nullable()();
  TextColumn get title => text()();
  TextColumn get status => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get templateId => text().nullable()();
  IntColumn get templateVersion => integer().nullable()();
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

@TableIndex(name: 'record_type_definitions_category', columns: {#categoryId})
@TableIndex(
  name: 'record_type_definitions_scope',
  columns: {#scopeType, #scopeId},
)
class RecordTypeDefinitionRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text()();
  TextColumn get baseTypeId => text().nullable()();
  TextColumn get scopeType => text()();
  TextColumn get scopeId => text()();
  IntColumn get templateVersion => integer()();
  BoolColumn get builtIn => boolean()();
  TextColumn get definitionJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'connection_type_definitions_scope', columns: {#scopeId})
class ConnectionTypeDefinitionRows extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get scopeId => text()();
  BoolColumn get builtIn => boolean()();
  TextColumn get definitionJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id, scopeId};
}

@TableIndex(name: 'story_branches_project', columns: {#projectId})
@TableIndex(name: 'story_branches_parent', columns: {#parentBranchId})
class StoryBranchRows extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  TextColumn get parentBranchId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get status => text()();
  TextColumn get branchJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'branch_record_overlays_branch', columns: {#branchId})
class BranchRecordOverlayRows extends Table {
  TextColumn get branchId => text().references(StoryBranchRows, #id)();
  TextColumn get recordId => text()();
  TextColumn get state => text()();
  TextColumn get overlayJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {branchId, recordId};
}

@TableIndex(name: 'branch_link_overlays_branch', columns: {#branchId})
class BranchLinkOverlayRows extends Table {
  TextColumn get branchId => text().references(StoryBranchRows, #id)();
  TextColumn get linkId => text()();
  TextColumn get state => text()();
  TextColumn get overlayJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {branchId, linkId};
}

@TableIndex(name: 'record_versions_entity', columns: {#projectId, #entityId})
@TableIndex(name: 'record_versions_record', columns: {#projectId, #recordId})
@TableIndex(name: 'record_versions_branch', columns: {#projectId, #branchId})
@TableIndex(name: 'record_versions_created', columns: {#projectId, #createdAt})
class RecordVersionRows extends Table {
  TextColumn get id => text()();
  TextColumn get entityId => text()();
  TextColumn get entityKind => text()();
  TextColumn get recordId => text()();
  TextColumn get recordType => text()();
  TextColumn get projectId => text()();
  TextColumn get seriesId => text().nullable()();
  TextColumn get bookId => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get changeType => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get previousVersionId => text().nullable()();
  TextColumn get versionJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'audit_events_entity', columns: {#projectId, #entityId})
@TableIndex(name: 'audit_events_record', columns: {#projectId, #recordId})
@TableIndex(
    name: 'audit_events_series_book', columns: {#projectId, #seriesId, #bookId})
@TableIndex(name: 'audit_events_branch', columns: {#projectId, #branchId})
@TableIndex(name: 'audit_events_change', columns: {#projectId, #changeType})
@TableIndex(name: 'audit_events_created', columns: {#projectId, #createdAt})
class AuditEventRows extends Table {
  TextColumn get id => text()();
  TextColumn get versionId => text()();
  TextColumn get entityId => text()();
  TextColumn get entityKind => text()();
  TextColumn get recordId => text()();
  TextColumn get recordType => text()();
  TextColumn get projectId => text()();
  TextColumn get seriesId => text().nullable()();
  TextColumn get bookId => text().nullable()();
  TextColumn get branchId => text().nullable()();
  TextColumn get changeType => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get eventJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Durable writing-session history.
///
/// Dedicated to that one job: it holds no manuscript text, joins to no
/// record, and is never rewritten. Rows are project-scoped and immutable —
/// a session is what happened, not a view of current state — so writes use
/// insert-or-ignore and later manuscript edits can never revise history.
///
/// Timestamps use drift's `dateTime()` representation: an absolute instant
/// stored as Unix epoch seconds, read back as a local `DateTime`. Calendar
/// questions (today, this week, streaks) are then answered in the author's
/// own local time by `WritingCalendar`.
@TableIndex(name: 'writing_sessions_project', columns: {#projectId})
@TableIndex(
  name: 'writing_sessions_project_started',
  columns: {#projectId, #startedAt},
)
class WritingSessionRows extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationSeconds => integer()();
  IntColumn get startingWordCount => integer()();
  IntColumn get endingWordCount => integer()();
  IntColumn get wordsAdded => integer()();
  IntColumn get wordsRemoved => integer()();
  TextColumn get chapterId => text().nullable()();
  TextColumn get sceneId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ConnectedEntities,
    AuthorRecordRows,
    ManuscriptNodeRows,
    RecordLinkRows,
    RecordTypeDefinitionRows,
    ConnectionTypeDefinitionRows,
    StoryBranchRows,
    BranchRecordOverlayRows,
    BranchLinkOverlayRows,
    RecordVersionRows,
    AuditEventRows,
    WritingSessionRows,
  ],
)
class AuthorOsDatabase extends _$AuthorOsDatabase {
  AuthorOsDatabase(
    super.executor, {
    int schemaVersion = currentSchemaVersion,
  }) : _schemaVersion = schemaVersion;

  AuthorOsDatabase.defaults()
      : _schemaVersion = currentSchemaVersion,
        super(driftDatabase(
          name: 'authoros_creative',
          web: webOptions,
        ));

  /// Where the browser build finds sqlite.
  ///
  /// On Windows, macOS, Linux and mobile, drift opens a SQLite file through
  /// the platform's own bindings and these options are ignored. The browser
  /// has no such bindings, so drift runs SQLite as WebAssembly instead, backed
  /// by OPFS or IndexedDB. It needs two files served next to `index.html` to
  /// do it, and `driftDatabase` throws without them — which is what left every
  /// Drift-backed Studio reporting "unavailable" on the web.
  ///
  /// Both files are copied out of the resolved `drift` package by
  /// `scripts/provision-drift-web-assets.sh`, so they always match the version
  /// in `pubspec.lock`. Nothing above this line changes: the Studios still
  /// talk to the same [DriftConnectedDomainRepository] on every platform.
  static final DriftWebOptions webOptions = DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  );

  static const currentSchemaVersion = 9;
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
          if (from < 3 && to >= 3) {
            await migrator.createTable(recordTypeDefinitionRows);
          }
          if (from < 4 && to >= 4) {
            await migrator.createTable(connectionTypeDefinitionRows);
          }
          if (from < 5 && to >= 5) {
            final columns = await customSelect(
              'PRAGMA table_info(author_record_rows)',
            ).get();
            final names =
                columns.map((row) => row.read<String>('name')).toSet();
            if (!names.contains('template_id')) {
              await migrator.addColumn(
                authorRecordRows,
                authorRecordRows.templateId,
              );
            }
            if (!names.contains('template_version')) {
              await migrator.addColumn(
                authorRecordRows,
                authorRecordRows.templateVersion,
              );
            }
          }
          if (from < 6 && to >= 6) {
            final columns = await customSelect(
              'PRAGMA table_info(author_record_rows)',
            ).get();
            final names =
                columns.map((row) => row.read<String>('name')).toSet();
            final additions = <String, GeneratedColumn>{
              'project_id': authorRecordRows.projectId,
              'series_id': authorRecordRows.seriesId,
              'book_id': authorRecordRows.bookId,
              'branch_id': authorRecordRows.branchId,
              'canon_status': authorRecordRows.canonStatus,
            };
            for (final entry in additions.entries) {
              if (!names.contains(entry.key)) {
                await migrator.addColumn(authorRecordRows, entry.value);
              }
            }
            await migrator.createTable(storyBranchRows);
            await migrator.createTable(branchRecordOverlayRows);
            await migrator.createTable(branchLinkOverlayRows);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS author_records_project '
              'ON author_record_rows(project_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS author_records_series_book '
              'ON author_record_rows(series_id, book_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS author_records_branch '
              'ON author_record_rows(branch_id)',
            );
          }
          if (from < 7 && to >= 7) {
            await customStatement('DROP TABLE IF EXISTS author_search');
            await _createSearchIndex();
            await _rebuildSearchIndex();
          }
          if (from < 8 && to >= 8) {
            await migrator.createTable(recordVersionRows);
            await migrator.createTable(auditEventRows);
          }
          if (from < 9 && to >= 9) {
            await migrator.createTable(writingSessionRows);
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
        entity_kind UNINDEXED,
        project_id UNINDEXED,
        series_id UNINDEXED,
        book_id UNINDEXED,
        branch_id UNINDEXED,
        canon_status UNINDEXED,
        lifecycle_status UNINDEXED,
        type_id UNINDEXED,
        template_id UNINDEXED,
        title,
        body,
        tags
      )
    ''');
  }

  Future<void> _rebuildSearchIndex() async {
    await customStatement('DELETE FROM author_search');
    await customStatement('''
      INSERT INTO author_search(
        entity_id, entity_kind, project_id, series_id, book_id, branch_id,
        canon_status, lifecycle_status, type_id, template_id, title, body, tags
      )
      SELECT id, 'record', COALESCE(project_id, scope_id), series_id, book_id,
        branch_id, COALESCE(canon_status, 'draft'), status, type_id,
        template_id, title, fields_json, tags_json
      FROM author_record_rows
    ''');
    await customStatement('''
      INSERT INTO author_search(
        entity_id, entity_kind, project_id, canon_status, lifecycle_status,
        type_id, title, body, tags
      )
      SELECT id, 'manuscriptNode', project_id, 'canon', 'active', node_type,
        title, extension_json, '[]'
      FROM manuscript_node_rows
    ''');
    final overlays = await customSelect('''
      SELECT o.overlay_json, b.project_id
      FROM branch_record_overlay_rows o
      JOIN story_branch_rows b ON b.id = o.branch_id
    ''').get();
    for (final row in overlays) {
      final overlay = BranchRecordOverlay.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(row.read<String>('overlay_json')) as Map,
        ),
      );
      await _indexBranchOverlay(overlay, row.read<String>('project_id'));
    }
  }

  Future<void> _indexBranchOverlay(
    BranchRecordOverlay overlay,
    String projectId,
  ) async {
    final created = overlay.createdRecord;
    final canonical = await customSelect('''
      SELECT series_id, book_id, canon_status, status, type_id, template_id,
        title, tags_json
      FROM author_record_rows WHERE id = ?
    ''', variables: [Variable<String>(overlay.recordId)]).getSingleOrNull();
    final entityId = branchSearchEntityId(overlay.branchId, overlay.recordId);
    await customStatement(
      'DELETE FROM author_search WHERE entity_id = ?',
      [entityId],
    );
    if (overlay.state == BranchRecordState.hidden) return;
    await customStatement('''
      INSERT INTO author_search(
        entity_id, entity_kind, project_id, series_id, book_id, branch_id,
        canon_status, lifecycle_status, type_id, template_id, title, body, tags
      ) VALUES (?, 'branchRecord', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      entityId,
      projectId,
      created?.seriesId ?? canonical?.readNullable<String>('series_id'),
      created?.bookId ?? canonical?.readNullable<String>('book_id'),
      overlay.branchId,
      (overlay.canonStatus ?? created?.canonStatus)?.name ??
          canonical?.readNullable<String>('canon_status') ??
          CanonStatus.draft.name,
      created?.status.name ??
          canonical?.readNullable<String>('status') ??
          AuthorRecordStatus.active.name,
      created?.typeId ?? canonical?.readNullable<String>('type_id'),
      created?.templateId ?? canonical?.readNullable<String>('template_id'),
      overlay.title ??
          created?.title ??
          canonical?.readNullable<String>('title') ??
          '',
      jsonEncode({
        ...?created?.fields,
        ...overlay.fields,
        'removedFieldIds': overlay.removedFieldIds,
      }),
      jsonEncode(
        overlay.tags ??
            created?.tags ??
            _decodeStringList(canonical?.readNullable<String>('tags_json')),
      ),
    ]);
  }
}

class DriftConnectedDomainRepository {
  const DriftConnectedDomainRepository(this.database);

  final AuthorOsDatabase database;

  Future<void> putManuscriptNodes(
    Iterable<ManuscriptNodeReference> nodes,
  ) async {
    final nodeList = nodes.toList();
    await database.transaction(() async {
      for (final node in nodeList) {
        await _putEntity(node.id, 'manuscriptNode', node.projectId);
        await _putManuscriptNode(node);
      }
    });
  }

  /// Removes a manuscript node from the connected store.
  ///
  /// Chapters and scenes are shared entities, so deleting one has to clear its
  /// entity row and its entry in the shared search index too, or a deleted
  /// scene would keep answering searches and connection lookups.
  Future<void> removeManuscriptNodes(Iterable<String> nodeIds) async {
    final ids = nodeIds.toSet().toList();
    if (ids.isEmpty) return;
    await database.transaction(() async {
      for (final id in ids) {
        // Edges reference the entity row, so they have to go first. The
        // foreign key would otherwise refuse the delete outright, and a node
        // whose links were not disconnected beforehand could not be removed
        // at all -- which is how a deleted scene became a permanent ghost.
        await (database.delete(database.recordLinkRows)
              ..where((table) =>
                  table.sourceId.equals(id) | table.targetId.equals(id)))
            .go();
        await (database.delete(database.manuscriptNodeRows)
              ..where((table) => table.id.equals(id)))
            .go();
        await (database.delete(database.connectedEntities)
              ..where((table) => table.id.equals(id)))
            .go();
        if (database.schemaVersion >= 2) {
          await database.customStatement(
            'DELETE FROM author_search WHERE entity_id = ? AND entity_kind = ?',
            [id, SearchEntityKind.manuscriptNode.name],
          );
        }
      }
    });
  }

  Future<void> putRecordsAndLinks({
    required Iterable<AuthorRecord> records,
    required Iterable<RecordLink> links,
  }) async {
    final recordList = records.toList();
    final linkList = links.toList();
    await database.transaction(() async {
      for (final record in recordList) {
        await _putEntity(record.id, 'record', record.scopeId);
        await _putRecord(record);
      }
      for (final link in linkList) {
        await _putLink(link);
      }
    });
  }

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

  Future<void> putRecordWithHistory({
    required AuthorRecord record,
    required Iterable<RecordLink> links,
    required RecordVersion version,
    required AuditEvent auditEvent,
  }) async {
    await database.transaction(() async {
      await _putEntity(record.id, 'record', record.scopeId);
      await _putRecord(record);
      for (final link in links) {
        await _putLink(link);
      }
      await _appendHistory(version, auditEvent);
    });
  }

  Future<void> putLinkWithHistory({
    required RecordLink link,
    required RecordVersion version,
    required AuditEvent auditEvent,
  }) async {
    await database.transaction(() async {
      await _putLink(link);
      await _appendHistory(version, auditEvent);
    });
  }

  Future<void> deleteLinkWithHistory({
    required String linkId,
    required RecordVersion version,
    required AuditEvent auditEvent,
  }) async {
    await database.transaction(() async {
      await (database.delete(database.recordLinkRows)
            ..where((table) => table.id.equals(linkId)))
          .go();
      await _appendHistory(version, auditEvent);
    });
  }

  Future<void> putBranchWithHistory({
    required StoryBranch branch,
    required RecordVersion version,
    required AuditEvent auditEvent,
  }) async {
    await database.transaction(() async {
      await putBranch(branch);
      await _appendHistory(version, auditEvent);
    });
  }

  Future<void> putBranchRecordOverlayWithHistory({
    required BranchRecordOverlay overlay,
    required RecordVersion version,
    required AuditEvent auditEvent,
  }) async {
    await database.transaction(() async {
      await putBranchRecordOverlay(overlay);
      await _appendHistory(version, auditEvent);
    });
  }

  Future<void> putBranchLinkOverlayWithHistory({
    required BranchLinkOverlay overlay,
    required RecordVersion version,
    required AuditEvent auditEvent,
  }) async {
    await database.transaction(() async {
      await putBranchLinkOverlay(overlay);
      await _appendHistory(version, auditEvent);
    });
  }

  Future<void> appendHistory(
    RecordVersion version,
    AuditEvent auditEvent,
  ) =>
      database.transaction(() => _appendHistory(version, auditEvent));

  Future<RecordVersion?> versionById(String id, String projectId) async {
    final row = await (database.select(database.recordVersionRows)
          ..where((table) =>
              table.id.equals(id) & table.projectId.equals(projectId)))
        .getSingleOrNull();
    return row == null ? null : _versionFromRow(row);
  }

  Future<List<RecordVersion>> versionHistory(HistoryFilter filter) async {
    final query = database.select(database.recordVersionRows)
      ..where((table) {
        var predicate = table.projectId.equals(filter.projectId);
        if (filter.recordId != null) {
          predicate = predicate & table.recordId.equals(filter.recordId!);
        }
        if (filter.recordType != null) {
          predicate = predicate & table.recordType.equals(filter.recordType!);
        }
        if (filter.seriesId != null) {
          predicate = predicate & table.seriesId.equals(filter.seriesId!);
        }
        if (filter.bookId != null) {
          predicate = predicate & table.bookId.equals(filter.bookId!);
        }
        if (filter.seriesId != null) {
          predicate = predicate & table.seriesId.equals(filter.seriesId!);
        }
        if (filter.bookId != null) {
          predicate = predicate & table.bookId.equals(filter.bookId!);
        }
        if (filter.branchId != null) {
          predicate = predicate & table.branchId.equals(filter.branchId!);
        } else if (filter.recordId != null) {
          predicate = predicate & table.branchId.isNull();
        }
        if (filter.changeType != null) {
          predicate =
              predicate & table.changeType.equals(filter.changeType!.name);
        }
        if (filter.from != null) {
          predicate =
              predicate & table.createdAt.isBiggerOrEqualValue(filter.from!);
        }
        if (filter.to != null) {
          predicate =
              predicate & table.createdAt.isSmallerOrEqualValue(filter.to!);
        }
        return predicate;
      })
      ..orderBy([
        (table) => OrderingTerm.asc(table.createdAt),
        (table) => OrderingTerm.asc(table.id),
      ])
      ..limit(filter.limit);
    return (await query.get()).map(_versionFromRow).toList();
  }

  Future<List<AuditEvent>> auditHistory(HistoryFilter filter) async {
    final query = database.select(database.auditEventRows)
      ..where((table) {
        var predicate = table.projectId.equals(filter.projectId);
        if (filter.recordId != null) {
          predicate = predicate & table.recordId.equals(filter.recordId!);
        }
        if (filter.recordType != null) {
          predicate = predicate & table.recordType.equals(filter.recordType!);
        }
        if (filter.branchId != null) {
          predicate = predicate & table.branchId.equals(filter.branchId!);
        } else if (filter.recordId != null) {
          predicate = predicate & table.branchId.isNull();
        }
        if (filter.changeType != null) {
          predicate =
              predicate & table.changeType.equals(filter.changeType!.name);
        }
        if (filter.from != null) {
          predicate =
              predicate & table.createdAt.isBiggerOrEqualValue(filter.from!);
        }
        if (filter.to != null) {
          predicate =
              predicate & table.createdAt.isSmallerOrEqualValue(filter.to!);
        }
        return predicate;
      })
      ..orderBy([
        (table) => OrderingTerm.asc(table.createdAt),
        (table) => OrderingTerm.asc(table.id),
      ])
      ..limit(filter.limit);
    return (await query.get()).map(_auditFromRow).toList();
  }

  Future<RecordVersion?> latestVersion({
    required String projectId,
    required String entityId,
    String? branchId,
  }) async {
    final query = database.select(database.recordVersionRows)
      ..where((table) {
        var predicate =
            table.projectId.equals(projectId) & table.entityId.equals(entityId);
        predicate = branchId == null
            ? predicate & table.branchId.isNull()
            : predicate & table.branchId.equals(branchId);
        return predicate;
      })
      ..orderBy([
        (table) => OrderingTerm.desc(table.createdAt),
        (table) => OrderingTerm.desc(table.id),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _versionFromRow(row);
  }

  // --- Writing session history -------------------------------------------

  /// Appends one finished writing session.
  ///
  /// Insert-or-ignore, deliberately: a session is a historical fact, so a
  /// repeated write — a re-fired lifecycle event, a finalize that ran twice,
  /// a replayed id — leaves the original row untouched instead of rewriting
  /// what the author actually did.
  Future<void> putWritingSession(WritingSession session) async {
    await database.into(database.writingSessionRows).insert(
          _writingSessionCompanion(session),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// Appends several sessions in one transaction, with the same
  /// insert-or-ignore semantics as [putWritingSession].
  Future<void> putWritingSessions(Iterable<WritingSession> sessions) async {
    final sessionList = sessions.toList();
    if (sessionList.isEmpty) return;
    await database.transaction(() async {
      for (final session in sessionList) {
        await database.into(database.writingSessionRows).insert(
              _writingSessionCompanion(session),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  /// Every session recorded for one project, oldest first.
  ///
  /// Project-scoped by the `where` clause, so one project's history can never
  /// surface in another's analytics. [from] and [to] bound the query by start
  /// instant for callers that only need a window; analytics loads the whole
  /// history once and derives its metrics in memory.
  Future<List<WritingSession>> writingSessionsForProject(
    String projectId, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final query = database.select(database.writingSessionRows)
      ..where((table) {
        var predicate = table.projectId.equals(projectId);
        if (from != null) {
          predicate = predicate & table.startedAt.isBiggerOrEqualValue(from);
        }
        if (to != null) {
          predicate = predicate & table.startedAt.isSmallerOrEqualValue(to);
        }
        return predicate;
      })
      ..orderBy([
        (table) => OrderingTerm.asc(table.startedAt),
        (table) => OrderingTerm.asc(table.id),
      ]);
    if (limit != null) query.limit(limit);
    return (await query.get()).map(_writingSessionFromRow).toList();
  }

  /// Removes one project's writing history. Cleanup only — nothing in the
  /// recording or analytics path calls this.
  Future<int> deleteWritingSessionsForProject(String projectId) =>
      (database.delete(database.writingSessionRows)
            ..where((table) => table.projectId.equals(projectId)))
          .go();

  WritingSessionRowsCompanion _writingSessionCompanion(
    WritingSession session,
  ) =>
      WritingSessionRowsCompanion.insert(
        id: session.id,
        projectId: session.projectId,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        durationSeconds: session.duration.inSeconds,
        startingWordCount: session.startingWordCount,
        endingWordCount: session.endingWordCount,
        wordsAdded: session.wordsAdded,
        wordsRemoved: session.wordsRemoved,
        chapterId: Value(session.chapterId),
        sceneId: Value(session.sceneId),
      );

  WritingSession _writingSessionFromRow(WritingSessionRow row) =>
      WritingSession(
        id: row.id,
        projectId: row.projectId,
        startedAt: row.startedAt,
        endedAt: row.endedAt,
        duration: Duration(seconds: row.durationSeconds),
        startingWordCount: row.startingWordCount,
        endingWordCount: row.endingWordCount,
        wordsAdded: row.wordsAdded,
        wordsRemoved: row.wordsRemoved,
        chapterId: row.chapterId,
        sceneId: row.sceneId,
      );

  Future<void> putRecordTypeDefinition(
    RecordTypeDefinition definition,
  ) async {
    RecordTypeRegistry([definition]);
    await database
        .into(database.recordTypeDefinitionRows)
        .insertOnConflictUpdate(
          RecordTypeDefinitionRowsCompanion.insert(
            id: definition.id,
            name: definition.name,
            categoryId: definition.categoryId,
            baseTypeId: Value(definition.baseTypeId),
            scopeType: definition.scopeType.name,
            scopeId: definition.scopeId,
            templateVersion: definition.templateVersion,
            builtIn: definition.builtIn,
            definitionJson: jsonEncode(definition.toJson()),
          ),
        );
  }

  Future<RecordTypeDefinition?> recordTypeDefinitionById(String id) async {
    final row = await (database.select(database.recordTypeDefinitionRows)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _definitionFromRow(row);
  }

  Future<void> putConnectionTypeDefinition(
    ConnectionTypeDefinition definition,
  ) async {
    ConnectionTypeRegistry([definition]);
    await database
        .into(database.connectionTypeDefinitionRows)
        .insertOnConflictUpdate(
          ConnectionTypeDefinitionRowsCompanion.insert(
            id: definition.id,
            displayName: definition.displayName,
            scopeId: definition.scopeId,
            builtIn: definition.builtIn,
            definitionJson: jsonEncode(definition.toJson()),
          ),
        );
  }

  Future<List<ConnectionTypeDefinition>> connectionTypeDefinitionsByScope(
    String scopeId,
  ) async {
    final rows = await (database.select(database.connectionTypeDefinitionRows)
          ..where((table) => table.scopeId.equals(scopeId))
          ..orderBy([(table) => OrderingTerm.asc(table.displayName)]))
        .get();
    return rows.map(_connectionDefinitionFromRow).toList();
  }

  Future<void> putBranch(StoryBranch branch) async {
    await database.into(database.storyBranchRows).insertOnConflictUpdate(
          StoryBranchRowsCompanion.insert(
            id: branch.id,
            projectId: branch.projectId,
            parentBranchId: Value(branch.parentBranchId),
            name: branch.name,
            kind: branch.kind.name,
            status: branch.status.name,
            branchJson: jsonEncode(branch.toJson()),
          ),
        );
  }

  Future<void> putBranchRecordOverlay(BranchRecordOverlay overlay) async {
    await database
        .into(database.branchRecordOverlayRows)
        .insertOnConflictUpdate(
          BranchRecordOverlayRowsCompanion.insert(
            branchId: overlay.branchId,
            recordId: overlay.recordId,
            state: overlay.state.name,
            overlayJson: jsonEncode(overlay.toJson()),
          ),
        );
    final branch = await (database.select(database.storyBranchRows)
          ..where((table) => table.id.equals(overlay.branchId)))
        .getSingle();
    await database._indexBranchOverlay(overlay, branch.projectId);
  }

  Future<void> putBranchLinkOverlay(BranchLinkOverlay overlay) async {
    await database.into(database.branchLinkOverlayRows).insertOnConflictUpdate(
          BranchLinkOverlayRowsCompanion.insert(
            branchId: overlay.branchId,
            linkId: overlay.linkId,
            state: overlay.state.name,
            overlayJson: jsonEncode(overlay.toJson()),
          ),
        );
  }

  Future<List<StoryBranch>> branchesByProject(String projectId) async {
    final rows = await (database.select(database.storyBranchRows)
          ..where((table) => table.projectId.equals(projectId))
          ..orderBy([(table) => OrderingTerm.asc(table.name)]))
        .get();
    return rows.map(_branchFromRow).toList();
  }

  Future<List<BranchRecordOverlay>> branchRecordOverlays(
    Iterable<String> branchIds,
  ) async {
    final ids = branchIds.toList();
    if (ids.isEmpty) return [];
    final rows = await (database.select(database.branchRecordOverlayRows)
          ..where((table) => table.branchId.isIn(ids)))
        .get();
    return rows.map(_branchRecordOverlayFromRow).toList();
  }

  Future<List<BranchLinkOverlay>> branchLinkOverlays(
    Iterable<String> branchIds,
  ) async {
    final ids = branchIds.toList();
    if (ids.isEmpty) return [];
    final rows = await (database.select(database.branchLinkOverlayRows)
          ..where((table) => table.branchId.isIn(ids)))
        .get();
    return rows.map(_branchLinkOverlayFromRow).toList();
  }

  Future<List<RecordTypeDefinition>> recordTypeDefinitionsByScope({
    required RecordScopeType scopeType,
    required String scopeId,
  }) async {
    final rows = await (database.select(database.recordTypeDefinitionRows)
          ..where(
            (table) =>
                table.scopeType.equals(scopeType.name) &
                table.scopeId.equals(scopeId),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.name)]))
        .get();
    return rows.map(_definitionFromRow).toList();
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

  Future<List<AuthorRecord>> recordsByScope(String scopeId) async {
    final rows = await (database.select(database.authorRecordRows)
          ..where((table) => table.scopeId.equals(scopeId))
          ..orderBy([(table) => OrderingTerm.asc(table.title)]))
        .get();
    return rows.map(_recordFromRow).toList();
  }

  Future<List<AuthorRecord>> recordsByProject(String projectId) async {
    final rows = await (database.select(database.authorRecordRows)
          ..where(
            (table) =>
                table.projectId.equals(projectId) |
                table.scopeId.equals(projectId),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.title)]))
        .get();
    return rows.map(_recordFromRow).toList();
  }

  Future<List<AuthorRecord>> recordsByTagAndScope({
    required String tagId,
    required String scopeId,
  }) async {
    final records = await recordsByScope(scopeId);
    return records.where((record) => record.tags.contains(tagId)).toList();
  }

  Future<void> replaceSnapshot(ConnectedDomainSnapshot snapshot) async {
    InMemoryConnectedDomainRepository(initial: snapshot);
    await database.transaction(() async {
      await database.delete(database.auditEventRows).go();
      await database.delete(database.recordVersionRows).go();
      await database.delete(database.recordLinkRows).go();
      await database.delete(database.branchLinkOverlayRows).go();
      await database.delete(database.branchRecordOverlayRows).go();
      await database.delete(database.storyBranchRows).go();
      await database.delete(database.connectionTypeDefinitionRows).go();
      await database.delete(database.recordTypeDefinitionRows).go();
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

  /// Hydrates many records in one pass.
  ///
  /// A graph read resolves a whole neighbourhood at once, and doing that
  /// through [recordById] costs one query per edge. Missing ids are simply
  /// absent from the result: an id may name a manuscript node rather than a
  /// record, and asking for both kinds is normal.
  Future<List<AuthorRecord>> recordsByIds(Iterable<String> ids) async {
    final rows = await _rowsByIds(
      ids,
      (chunk) => (database.select(database.authorRecordRows)
            ..where((table) => table.id.isIn(chunk))
            ..orderBy([(table) => OrderingTerm.asc(table.id)]))
          .get(),
    );
    return rows.map(_recordFromRow).toList();
  }

  /// The manuscript-node half of [recordsByIds].
  ///
  /// Scenes and chapters are a second node kind (decision D-3), so a graph read
  /// that hydrated only records would silently drop half the manuscript spine.
  Future<List<ManuscriptNodeReference>> manuscriptNodesByIds(
    Iterable<String> ids,
  ) async {
    final rows = await _rowsByIds(
      ids,
      (chunk) => (database.select(database.manuscriptNodeRows)
            ..where((table) => table.id.isIn(chunk))
            ..orderBy([(table) => OrderingTerm.asc(table.id)]))
          .get(),
    );
    return rows.map(_nodeFromRow).toList();
  }

  /// Every link touching any of [ids], in either direction.
  ///
  /// [typeIds] filters in SQL rather than in the caller. That matters because
  /// `relatedTo` is suggested on every record type: excluding it here keeps the
  /// rows out of memory instead of discarding them after the fact.
  Future<List<RecordLink>> linksForEntities(
    Iterable<String> ids, {
    Set<String>? typeIds,
  }) async {
    if (typeIds != null && typeIds.isEmpty) return const [];
    final rows = await _rowsByIds(
      ids,
      (chunk) => (database.select(database.recordLinkRows)
            ..where((table) {
              final touches =
                  table.sourceId.isIn(chunk) | table.targetId.isIn(chunk);
              return typeIds == null
                  ? touches
                  : touches & table.typeId.isIn(typeIds.toList());
            })
            ..orderBy([(table) => OrderingTerm.asc(table.id)]))
          .get(),
    );
    // A link between two ids in the same chunk is returned once, but a link
    // spanning two chunks comes back from both, so the id set is the authority.
    final seen = <String>{};
    return [
      for (final row in rows)
        if (seen.add(row.id)) _linkFromRow(row),
    ];
  }

  /// Runs [query] over [ids] in chunks, so a large neighbourhood cannot exceed
  /// SQLite's bound-variable limit.
  Future<List<T>> _rowsByIds<T>(
    Iterable<String> ids,
    Future<List<T>> Function(List<String> chunk) query,
  ) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const [];
    const chunkSize = 400;
    final rows = <T>[];
    for (var start = 0; start < unique.length; start += chunkSize) {
      final end =
          start + chunkSize < unique.length ? start + chunkSize : unique.length;
      rows.addAll(await query(unique.sublist(start, end)));
    }
    return rows;
  }

  /// Every manuscript node the project owns.
  ///
  /// A project's manuscript is authoritative for its own chapters and scenes,
  /// so saving one has to be able to see which nodes already exist in order to
  /// retire the ones the manuscript no longer contains.
  Future<List<ManuscriptNodeReference>> manuscriptNodesForProject(
    String projectId,
  ) async {
    final rows = await (database.select(database.manuscriptNodeRows)
          ..where((table) => table.projectId.equals(projectId))
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    return rows.map(_nodeFromRow).toList();
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

  Future<List<RecordLink>> outgoingLinks(String entityId) async {
    final rows = await (database.select(database.recordLinkRows)
          ..where((table) => table.sourceId.equals(entityId))
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    return rows.map(_linkFromRow).toList();
  }

  Future<List<RecordLink>> incomingLinks(String entityId) async {
    final rows = await (database.select(database.recordLinkRows)
          ..where((table) => table.targetId.equals(entityId))
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    return rows.map(_linkFromRow).toList();
  }

  Future<RecordLink?> linkById(String id) async {
    final row = await (database.select(database.recordLinkRows)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _linkFromRow(row);
  }

  Future<List<RecordLink>> linksByScope(String scopeId) async {
    final rows = await (database.select(database.recordLinkRows)
          ..where((table) => table.scopeId.equals(scopeId))
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    return rows.map(_linkFromRow).toList();
  }

  Future<String?> entityScopeId(String entityId) async {
    final row = await (database.select(database.connectedEntities)
          ..where((table) => table.id.equals(entityId)))
        .getSingleOrNull();
    return row?.scopeId;
  }

  Future<String?> entityTypeId(String entityId) async {
    final record = await recordById(entityId);
    if (record != null) {
      return record.typeId;
    }
    return (await manuscriptNodeById(entityId))?.nodeType;
  }

  Future<String?> entityProjectId(String entityId) async {
    final record = await recordById(entityId);
    if (record != null) {
      return record.projectId ??
          record.fields['projectId'] as String? ??
          record.fields['_codex.projectId'] as String? ??
          record.scopeId;
    }
    return (await manuscriptNodeById(entityId))?.projectId;
  }

  /// Resolves the endpoint facts a relationship validator needs for
  /// [entityId], without deciding whether the entity may be linked.
  Future<RelationshipEndpoint> relationshipEndpoint(String entityId) async {
    final record = await recordById(entityId);
    if (record != null) {
      return RelationshipEndpoint.fromRecord(record);
    }
    final node = await manuscriptNodeById(entityId);
    if (node != null) {
      return RelationshipEndpoint.fromManuscriptNode(node);
    }
    return RelationshipEndpoint.missing(entityId);
  }

  Future<void> deleteLink(String linkId) async {
    await (database.delete(database.recordLinkRows)
          ..where((table) => table.id.equals(linkId)))
        .go();
  }

  Future<List<SearchIndexHit>> searchIndex(
    String query, {
    required String exactQuery,
    required UniversalSearchFilter filter,
  }) async {
    if (database.schemaVersion < 2 || query.trim().isEmpty) {
      return [];
    }
    final conditions = <String>[
      'author_search MATCH ?',
      'project_id = ?',
      filter.branchId == null
          ? "entity_kind != 'branchRecord' AND branch_id IS NULL"
          : "(entity_kind = 'branchRecord' AND branch_id = ? OR "
              "entity_kind != 'branchRecord' AND branch_id IS NULL)",
    ];
    final variables = <Variable>[
      Variable<String>(query.trim()),
      Variable<String>(filter.projectId),
      if (filter.branchId != null) Variable<String>(filter.branchId!),
    ];
    void addFilter(String column, String? value) {
      if (value == null) return;
      conditions.add('$column = ?');
      variables.add(Variable<String>(value));
    }

    addFilter('type_id', filter.recordType);
    addFilter('series_id', filter.seriesId);
    addFilter('book_id', filter.bookId);
    if (filter.branchId == null) {
      addFilter('canon_status', filter.canonStatus?.name);
    }
    addFilter('lifecycle_status', filter.lifecycleStatus?.name);
    final rows = await database.customSelect('''
      SELECT entity_id, entity_kind, title,
        snippet(author_search, 11, '<b>', '</b>', '...', 20) AS snippet,
        CASE WHEN lower(title) = lower(?) THEN -1000.0
          ELSE bm25(author_search) END AS search_rank,
        CASE
          WHEN lower(title) = lower(?) THEN 'title'
          ELSE 'content'
        END AS matched_field
      FROM author_search
      WHERE ${conditions.join(' AND ')}
      ORDER BY CASE WHEN lower(title) = lower(?) THEN 0 ELSE 1 END,
        search_rank
      LIMIT ?
    ''', variables: [
      Variable<String>(exactQuery.trim()),
      Variable<String>(exactQuery.trim()),
      ...variables,
      Variable<String>(exactQuery.trim()),
      Variable<int>(
        filter.branchId != null && filter.canonStatus != null
            ? filter.limit * 5
            : filter.limit,
      ),
    ]).get();
    return rows.map((row) {
      final rawKind = row.read<String>('entity_kind');
      return SearchIndexHit(
        entityId: row.read<String>('entity_id'),
        kind: SearchEntityKind.values.firstWhere(
          (kind) => kind.name == rawKind,
        ),
        title: row.read<String>('title'),
        snippet: row.read<String>('snippet'),
        rank: row.read<double>('search_rank'),
        matchedField: row.read<String>('matched_field'),
      );
    }).toList();
  }

  Future<List<String>> searchEntityIds(String query) async {
    if (database.schemaVersion < 2 || query.trim().isEmpty) return [];
    final rows = await database.customSelect(
      "SELECT entity_id FROM author_search WHERE author_search MATCH ? "
      "AND entity_kind != 'branchRecord' ORDER BY rank",
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
    final definitionRows =
        await (database.select(database.recordTypeDefinitionRows)
              ..orderBy([(table) => OrderingTerm.asc(table.id)]))
            .get();
    final connectionDefinitionRows =
        await (database.select(database.connectionTypeDefinitionRows)
              ..orderBy([
                (table) => OrderingTerm.asc(table.scopeId),
                (table) => OrderingTerm.asc(table.id),
              ]))
            .get();
    final branchRows = await (database.select(database.storyBranchRows)
          ..orderBy([(table) => OrderingTerm.asc(table.id)]))
        .get();
    final branchRecordRows =
        await database.select(database.branchRecordOverlayRows).get();
    final branchLinkRows =
        await database.select(database.branchLinkOverlayRows).get();
    final versionRows = await (database.select(database.recordVersionRows)
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .get();
    final auditRows = await (database.select(database.auditEventRows)
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .get();
    return ConnectedDomainSnapshot(
      records: recordRows.map(_recordFromRow).toList(),
      manuscriptNodes: nodeRows.map(_nodeFromRow).toList(),
      links: linkRows.map(_linkFromRow).toList(),
      recordTypeDefinitions: definitionRows.map(_definitionFromRow).toList(),
      connectionTypeDefinitions:
          connectionDefinitionRows.map(_connectionDefinitionFromRow).toList(),
      branches: branchRows.map(_branchFromRow).toList(),
      branchRecordOverlays:
          branchRecordRows.map(_branchRecordOverlayFromRow).toList(),
      branchLinkOverlays:
          branchLinkRows.map(_branchLinkOverlayFromRow).toList(),
      versions: versionRows.map(_versionFromRow).toList(),
      auditEvents: auditRows.map(_auditFromRow).toList(),
    );
  }

  Future<void> _insertSnapshot(ConnectedDomainSnapshot snapshot) async {
    for (final branch in snapshot.branches) {
      await putBranch(branch);
    }
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
    for (final definition in snapshot.recordTypeDefinitions) {
      await putRecordTypeDefinition(definition);
    }
    for (final definition in snapshot.connectionTypeDefinitions) {
      await putConnectionTypeDefinition(definition);
    }
    for (final overlay in snapshot.branchRecordOverlays) {
      await putBranchRecordOverlay(overlay);
    }
    for (final overlay in snapshot.branchLinkOverlays) {
      await putBranchLinkOverlay(overlay);
    }
    for (final version in snapshot.versions) {
      await _insertVersion(version);
    }
    for (final event in snapshot.auditEvents) {
      await _insertAuditEvent(event);
    }
  }

  Future<void> _appendHistory(
    RecordVersion version,
    AuditEvent auditEvent,
  ) async {
    if (auditEvent.versionId != version.id ||
        auditEvent.projectId != version.projectId ||
        auditEvent.entityId != version.entityId) {
      throw StateError('Audit event does not match its version.');
    }
    await _insertVersion(version);
    await _insertAuditEvent(auditEvent);
  }

  Future<void> _insertVersion(RecordVersion version) => database
      .into(database.recordVersionRows)
      .insert(RecordVersionRowsCompanion.insert(
        id: version.id,
        entityId: version.entityId,
        entityKind: version.entityKind.name,
        recordId: version.recordId,
        recordType: version.recordType,
        projectId: version.projectId,
        seriesId: Value(version.seriesId),
        bookId: Value(version.bookId),
        branchId: Value(version.branchId),
        changeType: version.changeType.name,
        createdAt: version.createdAt,
        previousVersionId: Value(version.previousVersionId),
        versionJson: jsonEncode(version.toJson()),
      ));

  Future<void> _insertAuditEvent(AuditEvent event) => database
      .into(database.auditEventRows)
      .insert(AuditEventRowsCompanion.insert(
        id: event.id,
        versionId: event.versionId,
        entityId: event.entityId,
        entityKind: event.entityKind.name,
        recordId: event.recordId,
        recordType: event.recordType,
        projectId: event.projectId,
        seriesId: Value(event.seriesId),
        bookId: Value(event.bookId),
        branchId: Value(event.branchId),
        changeType: event.changeType.name,
        createdAt: event.createdAt,
        eventJson: jsonEncode(event.toJson()),
      ));

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
            projectId: Value(record.projectId),
            seriesId: Value(record.seriesId),
            bookId: Value(record.bookId),
            branchId: Value(record.branchId),
            canonStatus: Value(record.canonStatus.name),
            title: record.title,
            status: record.status.name,
            schemaVersion: record.schemaVersion,
            templateId: Value(record.templateId),
            templateVersion: Value(record.templateVersion),
            revision: record.revision,
            fieldsJson: jsonEncode(record.fields),
            tagsJson: jsonEncode(record.tags),
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            extensionJson: jsonEncode(record.extensionData),
          ),
        );
    await _indexEntity(
      entityId: record.id,
      kind: SearchEntityKind.record,
      projectId: record.projectId ?? record.scopeId,
      seriesId: record.seriesId,
      bookId: record.bookId,
      branchId: record.branchId,
      canonStatus: record.canonStatus,
      lifecycleStatus: record.status,
      typeId: record.typeId,
      templateId: record.templateId,
      title: record.title,
      body: jsonEncode(record.fields),
      tags: record.tags,
    );
    if (database.schemaVersion >= 7) {
      final overlays = await database.customSelect('''
        SELECT o.overlay_json, b.project_id
        FROM branch_record_overlay_rows o
        JOIN story_branch_rows b ON b.id = o.branch_id
        WHERE o.record_id = ?
      ''', variables: [Variable<String>(record.id)]).get();
      for (final row in overlays) {
        await database._indexBranchOverlay(
          BranchRecordOverlay.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(row.read<String>('overlay_json')) as Map,
            ),
          ),
          row.read<String>('project_id'),
        );
      }
    }
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
      entityId: node.id,
      kind: SearchEntityKind.manuscriptNode,
      projectId: node.projectId,
      canonStatus: CanonStatus.canon,
      lifecycleStatus: AuthorRecordStatus.active,
      typeId: node.nodeType,
      title: node.title,
      body: jsonEncode(node.extensionData),
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

  Future<void> _indexEntity({
    required String entityId,
    required SearchEntityKind kind,
    required String projectId,
    required CanonStatus canonStatus,
    required AuthorRecordStatus lifecycleStatus,
    required String typeId,
    required String title,
    required String body,
    String? seriesId,
    String? bookId,
    String? branchId,
    String? templateId,
    List<String> tags = const [],
  }) async {
    if (database.schemaVersion < 2) {
      return;
    }
    await database.customStatement(
      'DELETE FROM author_search WHERE entity_id = ? AND entity_kind = ?',
      [entityId, kind.name],
    );
    await database.customStatement('''
      INSERT INTO author_search(
        entity_id, entity_kind, project_id, series_id, book_id, branch_id,
        canon_status, lifecycle_status, type_id, template_id, title, body, tags
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      entityId,
      kind.name,
      projectId,
      seriesId,
      bookId,
      branchId,
      canonStatus.name,
      lifecycleStatus.name,
      typeId,
      templateId,
      title,
      body,
      jsonEncode(tags),
    ]);
  }

  AuthorRecord _recordFromRow(AuthorRecordRow row) => AuthorRecord.fromJson({
        'id': row.id,
        'typeId': row.typeId,
        'scopeType': row.scopeType,
        'scopeId': row.scopeId,
        'projectId': row.projectId,
        'seriesId': row.seriesId,
        'bookId': row.bookId,
        'branchId': row.branchId,
        'canonStatus': row.canonStatus,
        'title': row.title,
        'status': row.status,
        'schemaVersion': row.schemaVersion,
        'templateId': row.templateId,
        'templateVersion': row.templateVersion,
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

  RecordTypeDefinition _definitionFromRow(RecordTypeDefinitionRow row) =>
      RecordTypeDefinition.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.definitionJson) as Map),
      );

  ConnectionTypeDefinition _connectionDefinitionFromRow(
    ConnectionTypeDefinitionRow row,
  ) =>
      ConnectionTypeDefinition.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.definitionJson) as Map),
      );

  StoryBranch _branchFromRow(StoryBranchRow row) => StoryBranch.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.branchJson) as Map),
      );

  BranchRecordOverlay _branchRecordOverlayFromRow(
    BranchRecordOverlayRow row,
  ) =>
      BranchRecordOverlay.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.overlayJson) as Map),
      );

  BranchLinkOverlay _branchLinkOverlayFromRow(BranchLinkOverlayRow row) =>
      BranchLinkOverlay.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.overlayJson) as Map),
      );

  RecordVersion _versionFromRow(RecordVersionRow row) => RecordVersion.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.versionJson) as Map),
      );

  AuditEvent _auditFromRow(AuditEventRow row) => AuditEvent.fromJson(
        Map<String, dynamic>.from(jsonDecode(row.eventJson) as Map),
      );
}

final AuthorOsDatabase authorOsDatabase = AuthorOsDatabase.defaults();
final DriftConnectedDomainRepository authorOsRepository =
    DriftConnectedDomainRepository(authorOsDatabase);

List<String> _decodeStringList(String? value) {
  if (value == null) return const [];
  final decoded = jsonDecode(value);
  return decoded is List
      ? decoded.map((item) => item.toString()).toList()
      : const [];
}
