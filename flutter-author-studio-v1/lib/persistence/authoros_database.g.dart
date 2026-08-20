// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'authoros_database.dart';

// ignore_for_file: type=lint
class $ConnectedEntitiesTable extends ConnectedEntities
    with TableInfo<$ConnectedEntitiesTable, ConnectedEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectedEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeIdMeta =
      const VerificationMeta('scopeId');
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
      'scope_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, kind, scopeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connected_entities';
  @override
  VerificationContext validateIntegrity(Insertable<ConnectedEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(_scopeIdMeta,
          scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta));
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnectedEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectedEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      scopeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_id'])!,
    );
  }

  @override
  $ConnectedEntitiesTable createAlias(String alias) {
    return $ConnectedEntitiesTable(attachedDatabase, alias);
  }
}

class ConnectedEntity extends DataClass implements Insertable<ConnectedEntity> {
  final String id;
  final String kind;
  final String scopeId;
  const ConnectedEntity(
      {required this.id, required this.kind, required this.scopeId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['scope_id'] = Variable<String>(scopeId);
    return map;
  }

  ConnectedEntitiesCompanion toCompanion(bool nullToAbsent) {
    return ConnectedEntitiesCompanion(
      id: Value(id),
      kind: Value(kind),
      scopeId: Value(scopeId),
    );
  }

  factory ConnectedEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectedEntity(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'scopeId': serializer.toJson<String>(scopeId),
    };
  }

  ConnectedEntity copyWith({String? id, String? kind, String? scopeId}) =>
      ConnectedEntity(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        scopeId: scopeId ?? this.scopeId,
      );
  ConnectedEntity copyWithCompanion(ConnectedEntitiesCompanion data) {
    return ConnectedEntity(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectedEntity(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scopeId: $scopeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, scopeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectedEntity &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.scopeId == this.scopeId);
}

class ConnectedEntitiesCompanion extends UpdateCompanion<ConnectedEntity> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> scopeId;
  final Value<int> rowid;
  const ConnectedEntitiesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConnectedEntitiesCompanion.insert({
    required String id,
    required String kind,
    required String scopeId,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        kind = Value(kind),
        scopeId = Value(scopeId);
  static Insertable<ConnectedEntity> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? scopeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (scopeId != null) 'scope_id': scopeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConnectedEntitiesCompanion copyWith(
      {Value<String>? id,
      Value<String>? kind,
      Value<String>? scopeId,
      Value<int>? rowid}) {
    return ConnectedEntitiesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      scopeId: scopeId ?? this.scopeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectedEntitiesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('scopeId: $scopeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuthorRecordRowsTable extends AuthorRecordRows
    with TableInfo<$AuthorRecordRowsTable, AuthorRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuthorRecordRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES connected_entities (id)'));
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
      'type_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeTypeMeta =
      const VerificationMeta('scopeType');
  @override
  late final GeneratedColumn<String> scopeType = GeneratedColumn<String>(
      'scope_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeIdMeta =
      const VerificationMeta('scopeId');
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
      'scope_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seriesIdMeta =
      const VerificationMeta('seriesId');
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
      'series_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _canonStatusMeta =
      const VerificationMeta('canonStatus');
  @override
  late final GeneratedColumn<String> canonStatus = GeneratedColumn<String>(
      'canon_status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _schemaVersionMeta =
      const VerificationMeta('schemaVersion');
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
      'schema_version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _templateIdMeta =
      const VerificationMeta('templateId');
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
      'template_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _templateVersionMeta =
      const VerificationMeta('templateVersion');
  @override
  late final GeneratedColumn<int> templateVersion = GeneratedColumn<int>(
      'template_version', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fieldsJsonMeta =
      const VerificationMeta('fieldsJson');
  @override
  late final GeneratedColumn<String> fieldsJson = GeneratedColumn<String>(
      'fields_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagsJsonMeta =
      const VerificationMeta('tagsJson');
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
      'tags_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _extensionJsonMeta =
      const VerificationMeta('extensionJson');
  @override
  late final GeneratedColumn<String> extensionJson = GeneratedColumn<String>(
      'extension_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        typeId,
        scopeType,
        scopeId,
        projectId,
        seriesId,
        bookId,
        branchId,
        canonStatus,
        title,
        status,
        schemaVersion,
        templateId,
        templateVersion,
        revision,
        fieldsJson,
        tagsJson,
        createdAt,
        updatedAt,
        extensionJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'author_record_rows';
  @override
  VerificationContext validateIntegrity(Insertable<AuthorRecordRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(_typeIdMeta,
          typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta));
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('scope_type')) {
      context.handle(_scopeTypeMeta,
          scopeType.isAcceptableOrUnknown(data['scope_type']!, _scopeTypeMeta));
    } else if (isInserting) {
      context.missing(_scopeTypeMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(_scopeIdMeta,
          scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta));
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    }
    if (data.containsKey('series_id')) {
      context.handle(_seriesIdMeta,
          seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('canon_status')) {
      context.handle(
          _canonStatusMeta,
          canonStatus.isAcceptableOrUnknown(
              data['canon_status']!, _canonStatusMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
          _schemaVersionMeta,
          schemaVersion.isAcceptableOrUnknown(
              data['schema_version']!, _schemaVersionMeta));
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
          _templateIdMeta,
          templateId.isAcceptableOrUnknown(
              data['template_id']!, _templateIdMeta));
    }
    if (data.containsKey('template_version')) {
      context.handle(
          _templateVersionMeta,
          templateVersion.isAcceptableOrUnknown(
              data['template_version']!, _templateVersionMeta));
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('fields_json')) {
      context.handle(
          _fieldsJsonMeta,
          fieldsJson.isAcceptableOrUnknown(
              data['fields_json']!, _fieldsJsonMeta));
    } else if (isInserting) {
      context.missing(_fieldsJsonMeta);
    }
    if (data.containsKey('tags_json')) {
      context.handle(_tagsJsonMeta,
          tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta));
    } else if (isInserting) {
      context.missing(_tagsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('extension_json')) {
      context.handle(
          _extensionJsonMeta,
          extensionJson.isAcceptableOrUnknown(
              data['extension_json']!, _extensionJsonMeta));
    } else if (isInserting) {
      context.missing(_extensionJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuthorRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuthorRecordRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      typeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type_id'])!,
      scopeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_type'])!,
      scopeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id']),
      seriesId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}series_id']),
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id']),
      canonStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}canon_status']),
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      schemaVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}schema_version'])!,
      templateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}template_id']),
      templateVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}template_version']),
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      fieldsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fields_json'])!,
      tagsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      extensionJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extension_json'])!,
    );
  }

  @override
  $AuthorRecordRowsTable createAlias(String alias) {
    return $AuthorRecordRowsTable(attachedDatabase, alias);
  }
}

class AuthorRecordRow extends DataClass implements Insertable<AuthorRecordRow> {
  final String id;
  final String typeId;
  final String scopeType;
  final String scopeId;
  final String? projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final String? canonStatus;
  final String title;
  final String status;
  final int schemaVersion;
  final String? templateId;
  final int? templateVersion;
  final int revision;
  final String fieldsJson;
  final String tagsJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String extensionJson;
  const AuthorRecordRow(
      {required this.id,
      required this.typeId,
      required this.scopeType,
      required this.scopeId,
      this.projectId,
      this.seriesId,
      this.bookId,
      this.branchId,
      this.canonStatus,
      required this.title,
      required this.status,
      required this.schemaVersion,
      this.templateId,
      this.templateVersion,
      required this.revision,
      required this.fieldsJson,
      required this.tagsJson,
      required this.createdAt,
      required this.updatedAt,
      required this.extensionJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type_id'] = Variable<String>(typeId);
    map['scope_type'] = Variable<String>(scopeType);
    map['scope_id'] = Variable<String>(scopeId);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    if (!nullToAbsent || canonStatus != null) {
      map['canon_status'] = Variable<String>(canonStatus);
    }
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['schema_version'] = Variable<int>(schemaVersion);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    if (!nullToAbsent || templateVersion != null) {
      map['template_version'] = Variable<int>(templateVersion);
    }
    map['revision'] = Variable<int>(revision);
    map['fields_json'] = Variable<String>(fieldsJson);
    map['tags_json'] = Variable<String>(tagsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['extension_json'] = Variable<String>(extensionJson);
    return map;
  }

  AuthorRecordRowsCompanion toCompanion(bool nullToAbsent) {
    return AuthorRecordRowsCompanion(
      id: Value(id),
      typeId: Value(typeId),
      scopeType: Value(scopeType),
      scopeId: Value(scopeId),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      bookId:
          bookId == null && nullToAbsent ? const Value.absent() : Value(bookId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      canonStatus: canonStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(canonStatus),
      title: Value(title),
      status: Value(status),
      schemaVersion: Value(schemaVersion),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      templateVersion: templateVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(templateVersion),
      revision: Value(revision),
      fieldsJson: Value(fieldsJson),
      tagsJson: Value(tagsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extensionJson: Value(extensionJson),
    );
  }

  factory AuthorRecordRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuthorRecordRow(
      id: serializer.fromJson<String>(json['id']),
      typeId: serializer.fromJson<String>(json['typeId']),
      scopeType: serializer.fromJson<String>(json['scopeType']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      canonStatus: serializer.fromJson<String?>(json['canonStatus']),
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      templateId: serializer.fromJson<String?>(json['templateId']),
      templateVersion: serializer.fromJson<int?>(json['templateVersion']),
      revision: serializer.fromJson<int>(json['revision']),
      fieldsJson: serializer.fromJson<String>(json['fieldsJson']),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      extensionJson: serializer.fromJson<String>(json['extensionJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'typeId': serializer.toJson<String>(typeId),
      'scopeType': serializer.toJson<String>(scopeType),
      'scopeId': serializer.toJson<String>(scopeId),
      'projectId': serializer.toJson<String?>(projectId),
      'seriesId': serializer.toJson<String?>(seriesId),
      'bookId': serializer.toJson<String?>(bookId),
      'branchId': serializer.toJson<String?>(branchId),
      'canonStatus': serializer.toJson<String?>(canonStatus),
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'templateId': serializer.toJson<String?>(templateId),
      'templateVersion': serializer.toJson<int?>(templateVersion),
      'revision': serializer.toJson<int>(revision),
      'fieldsJson': serializer.toJson<String>(fieldsJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'extensionJson': serializer.toJson<String>(extensionJson),
    };
  }

  AuthorRecordRow copyWith(
          {String? id,
          String? typeId,
          String? scopeType,
          String? scopeId,
          Value<String?> projectId = const Value.absent(),
          Value<String?> seriesId = const Value.absent(),
          Value<String?> bookId = const Value.absent(),
          Value<String?> branchId = const Value.absent(),
          Value<String?> canonStatus = const Value.absent(),
          String? title,
          String? status,
          int? schemaVersion,
          Value<String?> templateId = const Value.absent(),
          Value<int?> templateVersion = const Value.absent(),
          int? revision,
          String? fieldsJson,
          String? tagsJson,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? extensionJson}) =>
      AuthorRecordRow(
        id: id ?? this.id,
        typeId: typeId ?? this.typeId,
        scopeType: scopeType ?? this.scopeType,
        scopeId: scopeId ?? this.scopeId,
        projectId: projectId.present ? projectId.value : this.projectId,
        seriesId: seriesId.present ? seriesId.value : this.seriesId,
        bookId: bookId.present ? bookId.value : this.bookId,
        branchId: branchId.present ? branchId.value : this.branchId,
        canonStatus: canonStatus.present ? canonStatus.value : this.canonStatus,
        title: title ?? this.title,
        status: status ?? this.status,
        schemaVersion: schemaVersion ?? this.schemaVersion,
        templateId: templateId.present ? templateId.value : this.templateId,
        templateVersion: templateVersion.present
            ? templateVersion.value
            : this.templateVersion,
        revision: revision ?? this.revision,
        fieldsJson: fieldsJson ?? this.fieldsJson,
        tagsJson: tagsJson ?? this.tagsJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        extensionJson: extensionJson ?? this.extensionJson,
      );
  AuthorRecordRow copyWithCompanion(AuthorRecordRowsCompanion data) {
    return AuthorRecordRow(
      id: data.id.present ? data.id.value : this.id,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      scopeType: data.scopeType.present ? data.scopeType.value : this.scopeType,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      canonStatus:
          data.canonStatus.present ? data.canonStatus.value : this.canonStatus,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      templateId:
          data.templateId.present ? data.templateId.value : this.templateId,
      templateVersion: data.templateVersion.present
          ? data.templateVersion.value
          : this.templateVersion,
      revision: data.revision.present ? data.revision.value : this.revision,
      fieldsJson:
          data.fieldsJson.present ? data.fieldsJson.value : this.fieldsJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extensionJson: data.extensionJson.present
          ? data.extensionJson.value
          : this.extensionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuthorRecordRow(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('projectId: $projectId, ')
          ..write('seriesId: $seriesId, ')
          ..write('bookId: $bookId, ')
          ..write('branchId: $branchId, ')
          ..write('canonStatus: $canonStatus, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('revision: $revision, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extensionJson: $extensionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      typeId,
      scopeType,
      scopeId,
      projectId,
      seriesId,
      bookId,
      branchId,
      canonStatus,
      title,
      status,
      schemaVersion,
      templateId,
      templateVersion,
      revision,
      fieldsJson,
      tagsJson,
      createdAt,
      updatedAt,
      extensionJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthorRecordRow &&
          other.id == this.id &&
          other.typeId == this.typeId &&
          other.scopeType == this.scopeType &&
          other.scopeId == this.scopeId &&
          other.projectId == this.projectId &&
          other.seriesId == this.seriesId &&
          other.bookId == this.bookId &&
          other.branchId == this.branchId &&
          other.canonStatus == this.canonStatus &&
          other.title == this.title &&
          other.status == this.status &&
          other.schemaVersion == this.schemaVersion &&
          other.templateId == this.templateId &&
          other.templateVersion == this.templateVersion &&
          other.revision == this.revision &&
          other.fieldsJson == this.fieldsJson &&
          other.tagsJson == this.tagsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extensionJson == this.extensionJson);
}

class AuthorRecordRowsCompanion extends UpdateCompanion<AuthorRecordRow> {
  final Value<String> id;
  final Value<String> typeId;
  final Value<String> scopeType;
  final Value<String> scopeId;
  final Value<String?> projectId;
  final Value<String?> seriesId;
  final Value<String?> bookId;
  final Value<String?> branchId;
  final Value<String?> canonStatus;
  final Value<String> title;
  final Value<String> status;
  final Value<int> schemaVersion;
  final Value<String?> templateId;
  final Value<int?> templateVersion;
  final Value<int> revision;
  final Value<String> fieldsJson;
  final Value<String> tagsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> extensionJson;
  final Value<int> rowid;
  const AuthorRecordRowsCompanion({
    this.id = const Value.absent(),
    this.typeId = const Value.absent(),
    this.scopeType = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.canonStatus = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.templateId = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.revision = const Value.absent(),
    this.fieldsJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extensionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuthorRecordRowsCompanion.insert({
    required String id,
    required String typeId,
    required String scopeType,
    required String scopeId,
    this.projectId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.canonStatus = const Value.absent(),
    required String title,
    required String status,
    required int schemaVersion,
    this.templateId = const Value.absent(),
    this.templateVersion = const Value.absent(),
    required int revision,
    required String fieldsJson,
    required String tagsJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String extensionJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        typeId = Value(typeId),
        scopeType = Value(scopeType),
        scopeId = Value(scopeId),
        title = Value(title),
        status = Value(status),
        schemaVersion = Value(schemaVersion),
        revision = Value(revision),
        fieldsJson = Value(fieldsJson),
        tagsJson = Value(tagsJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        extensionJson = Value(extensionJson);
  static Insertable<AuthorRecordRow> custom({
    Expression<String>? id,
    Expression<String>? typeId,
    Expression<String>? scopeType,
    Expression<String>? scopeId,
    Expression<String>? projectId,
    Expression<String>? seriesId,
    Expression<String>? bookId,
    Expression<String>? branchId,
    Expression<String>? canonStatus,
    Expression<String>? title,
    Expression<String>? status,
    Expression<int>? schemaVersion,
    Expression<String>? templateId,
    Expression<int>? templateVersion,
    Expression<int>? revision,
    Expression<String>? fieldsJson,
    Expression<String>? tagsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? extensionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (typeId != null) 'type_id': typeId,
      if (scopeType != null) 'scope_type': scopeType,
      if (scopeId != null) 'scope_id': scopeId,
      if (projectId != null) 'project_id': projectId,
      if (seriesId != null) 'series_id': seriesId,
      if (bookId != null) 'book_id': bookId,
      if (branchId != null) 'branch_id': branchId,
      if (canonStatus != null) 'canon_status': canonStatus,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (templateId != null) 'template_id': templateId,
      if (templateVersion != null) 'template_version': templateVersion,
      if (revision != null) 'revision': revision,
      if (fieldsJson != null) 'fields_json': fieldsJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extensionJson != null) 'extension_json': extensionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuthorRecordRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? typeId,
      Value<String>? scopeType,
      Value<String>? scopeId,
      Value<String?>? projectId,
      Value<String?>? seriesId,
      Value<String?>? bookId,
      Value<String?>? branchId,
      Value<String?>? canonStatus,
      Value<String>? title,
      Value<String>? status,
      Value<int>? schemaVersion,
      Value<String?>? templateId,
      Value<int?>? templateVersion,
      Value<int>? revision,
      Value<String>? fieldsJson,
      Value<String>? tagsJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? extensionJson,
      Value<int>? rowid}) {
    return AuthorRecordRowsCompanion(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      projectId: projectId ?? this.projectId,
      seriesId: seriesId ?? this.seriesId,
      bookId: bookId ?? this.bookId,
      branchId: branchId ?? this.branchId,
      canonStatus: canonStatus ?? this.canonStatus,
      title: title ?? this.title,
      status: status ?? this.status,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      templateId: templateId ?? this.templateId,
      templateVersion: templateVersion ?? this.templateVersion,
      revision: revision ?? this.revision,
      fieldsJson: fieldsJson ?? this.fieldsJson,
      tagsJson: tagsJson ?? this.tagsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extensionJson: extensionJson ?? this.extensionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (scopeType.present) {
      map['scope_type'] = Variable<String>(scopeType.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (canonStatus.present) {
      map['canon_status'] = Variable<String>(canonStatus.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (templateVersion.present) {
      map['template_version'] = Variable<int>(templateVersion.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (fieldsJson.present) {
      map['fields_json'] = Variable<String>(fieldsJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (extensionJson.present) {
      map['extension_json'] = Variable<String>(extensionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuthorRecordRowsCompanion(')
          ..write('id: $id, ')
          ..write('typeId: $typeId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('projectId: $projectId, ')
          ..write('seriesId: $seriesId, ')
          ..write('bookId: $bookId, ')
          ..write('branchId: $branchId, ')
          ..write('canonStatus: $canonStatus, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('templateId: $templateId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('revision: $revision, ')
          ..write('fieldsJson: $fieldsJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extensionJson: $extensionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ManuscriptNodeRowsTable extends ManuscriptNodeRows
    with TableInfo<$ManuscriptNodeRowsTable, ManuscriptNodeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ManuscriptNodeRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES connected_entities (id)'));
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nodeTypeMeta =
      const VerificationMeta('nodeType');
  @override
  late final GeneratedColumn<String> nodeType = GeneratedColumn<String>(
      'node_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _extensionJsonMeta =
      const VerificationMeta('extensionJson');
  @override
  late final GeneratedColumn<String> extensionJson = GeneratedColumn<String>(
      'extension_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        projectId,
        nodeType,
        title,
        revision,
        createdAt,
        updatedAt,
        extensionJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manuscript_node_rows';
  @override
  VerificationContext validateIntegrity(Insertable<ManuscriptNodeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('node_type')) {
      context.handle(_nodeTypeMeta,
          nodeType.isAcceptableOrUnknown(data['node_type']!, _nodeTypeMeta));
    } else if (isInserting) {
      context.missing(_nodeTypeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('extension_json')) {
      context.handle(
          _extensionJsonMeta,
          extensionJson.isAcceptableOrUnknown(
              data['extension_json']!, _extensionJsonMeta));
    } else if (isInserting) {
      context.missing(_extensionJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ManuscriptNodeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ManuscriptNodeRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      nodeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      extensionJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extension_json'])!,
    );
  }

  @override
  $ManuscriptNodeRowsTable createAlias(String alias) {
    return $ManuscriptNodeRowsTable(attachedDatabase, alias);
  }
}

class ManuscriptNodeRow extends DataClass
    implements Insertable<ManuscriptNodeRow> {
  final String id;
  final String projectId;
  final String nodeType;
  final String title;
  final int revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String extensionJson;
  const ManuscriptNodeRow(
      {required this.id,
      required this.projectId,
      required this.nodeType,
      required this.title,
      required this.revision,
      required this.createdAt,
      required this.updatedAt,
      required this.extensionJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['node_type'] = Variable<String>(nodeType);
    map['title'] = Variable<String>(title);
    map['revision'] = Variable<int>(revision);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['extension_json'] = Variable<String>(extensionJson);
    return map;
  }

  ManuscriptNodeRowsCompanion toCompanion(bool nullToAbsent) {
    return ManuscriptNodeRowsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      nodeType: Value(nodeType),
      title: Value(title),
      revision: Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extensionJson: Value(extensionJson),
    );
  }

  factory ManuscriptNodeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ManuscriptNodeRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      nodeType: serializer.fromJson<String>(json['nodeType']),
      title: serializer.fromJson<String>(json['title']),
      revision: serializer.fromJson<int>(json['revision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      extensionJson: serializer.fromJson<String>(json['extensionJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'nodeType': serializer.toJson<String>(nodeType),
      'title': serializer.toJson<String>(title),
      'revision': serializer.toJson<int>(revision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'extensionJson': serializer.toJson<String>(extensionJson),
    };
  }

  ManuscriptNodeRow copyWith(
          {String? id,
          String? projectId,
          String? nodeType,
          String? title,
          int? revision,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? extensionJson}) =>
      ManuscriptNodeRow(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        nodeType: nodeType ?? this.nodeType,
        title: title ?? this.title,
        revision: revision ?? this.revision,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        extensionJson: extensionJson ?? this.extensionJson,
      );
  ManuscriptNodeRow copyWithCompanion(ManuscriptNodeRowsCompanion data) {
    return ManuscriptNodeRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      nodeType: data.nodeType.present ? data.nodeType.value : this.nodeType,
      title: data.title.present ? data.title.value : this.title,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extensionJson: data.extensionJson.present
          ? data.extensionJson.value
          : this.extensionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ManuscriptNodeRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('nodeType: $nodeType, ')
          ..write('title: $title, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extensionJson: $extensionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, projectId, nodeType, title, revision,
      createdAt, updatedAt, extensionJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ManuscriptNodeRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.nodeType == this.nodeType &&
          other.title == this.title &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extensionJson == this.extensionJson);
}

class ManuscriptNodeRowsCompanion extends UpdateCompanion<ManuscriptNodeRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> nodeType;
  final Value<String> title;
  final Value<int> revision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> extensionJson;
  final Value<int> rowid;
  const ManuscriptNodeRowsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.nodeType = const Value.absent(),
    this.title = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extensionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ManuscriptNodeRowsCompanion.insert({
    required String id,
    required String projectId,
    required String nodeType,
    required String title,
    required int revision,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String extensionJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        nodeType = Value(nodeType),
        title = Value(title),
        revision = Value(revision),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        extensionJson = Value(extensionJson);
  static Insertable<ManuscriptNodeRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? nodeType,
    Expression<String>? title,
    Expression<int>? revision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? extensionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (nodeType != null) 'node_type': nodeType,
      if (title != null) 'title': title,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extensionJson != null) 'extension_json': extensionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ManuscriptNodeRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String>? nodeType,
      Value<String>? title,
      Value<int>? revision,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? extensionJson,
      Value<int>? rowid}) {
    return ManuscriptNodeRowsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      nodeType: nodeType ?? this.nodeType,
      title: title ?? this.title,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extensionJson: extensionJson ?? this.extensionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (nodeType.present) {
      map['node_type'] = Variable<String>(nodeType.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (extensionJson.present) {
      map['extension_json'] = Variable<String>(extensionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ManuscriptNodeRowsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('nodeType: $nodeType, ')
          ..write('title: $title, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extensionJson: $extensionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordLinkRowsTable extends RecordLinkRows
    with TableInfo<$RecordLinkRowsTable, RecordLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordLinkRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceIdMeta =
      const VerificationMeta('sourceId');
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
      'source_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES connected_entities (id)'));
  static const VerificationMeta _targetIdMeta =
      const VerificationMeta('targetId');
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
      'target_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES connected_entities (id)'));
  static const VerificationMeta _typeIdMeta = const VerificationMeta('typeId');
  @override
  late final GeneratedColumn<String> typeId = GeneratedColumn<String>(
      'type_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeIdMeta =
      const VerificationMeta('scopeId');
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
      'scope_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _directionMeta =
      const VerificationMeta('direction');
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
      'direction', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _revisionMeta =
      const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
      'revision', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _metadataJsonMeta =
      const VerificationMeta('metadataJson');
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
      'metadata_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _extensionJsonMeta =
      const VerificationMeta('extensionJson');
  @override
  late final GeneratedColumn<String> extensionJson = GeneratedColumn<String>(
      'extension_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sourceId,
        targetId,
        typeId,
        scopeId,
        direction,
        label,
        revision,
        metadataJson,
        createdAt,
        updatedAt,
        extensionJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_link_rows';
  @override
  VerificationContext validateIntegrity(Insertable<RecordLinkRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(_sourceIdMeta,
          sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta));
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(_targetIdMeta,
          targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta));
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('type_id')) {
      context.handle(_typeIdMeta,
          typeId.isAcceptableOrUnknown(data['type_id']!, _typeIdMeta));
    } else if (isInserting) {
      context.missing(_typeIdMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(_scopeIdMeta,
          scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta));
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta,
          revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
          _metadataJsonMeta,
          metadataJson.isAcceptableOrUnknown(
              data['metadata_json']!, _metadataJsonMeta));
    } else if (isInserting) {
      context.missing(_metadataJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('extension_json')) {
      context.handle(
          _extensionJsonMeta,
          extensionJson.isAcceptableOrUnknown(
              data['extension_json']!, _extensionJsonMeta));
    } else if (isInserting) {
      context.missing(_extensionJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordLinkRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sourceId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_id'])!,
      targetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_id'])!,
      typeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type_id'])!,
      scopeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_id'])!,
      direction: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}direction'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      revision: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      metadataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      extensionJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}extension_json'])!,
    );
  }

  @override
  $RecordLinkRowsTable createAlias(String alias) {
    return $RecordLinkRowsTable(attachedDatabase, alias);
  }
}

class RecordLinkRow extends DataClass implements Insertable<RecordLinkRow> {
  final String id;
  final String sourceId;
  final String targetId;
  final String typeId;
  final String scopeId;
  final String direction;
  final String label;
  final int revision;
  final String metadataJson;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String extensionJson;
  const RecordLinkRow(
      {required this.id,
      required this.sourceId,
      required this.targetId,
      required this.typeId,
      required this.scopeId,
      required this.direction,
      required this.label,
      required this.revision,
      required this.metadataJson,
      required this.createdAt,
      required this.updatedAt,
      required this.extensionJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['target_id'] = Variable<String>(targetId);
    map['type_id'] = Variable<String>(typeId);
    map['scope_id'] = Variable<String>(scopeId);
    map['direction'] = Variable<String>(direction);
    map['label'] = Variable<String>(label);
    map['revision'] = Variable<int>(revision);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['extension_json'] = Variable<String>(extensionJson);
    return map;
  }

  RecordLinkRowsCompanion toCompanion(bool nullToAbsent) {
    return RecordLinkRowsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      targetId: Value(targetId),
      typeId: Value(typeId),
      scopeId: Value(scopeId),
      direction: Value(direction),
      label: Value(label),
      revision: Value(revision),
      metadataJson: Value(metadataJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      extensionJson: Value(extensionJson),
    );
  }

  factory RecordLinkRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordLinkRow(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      targetId: serializer.fromJson<String>(json['targetId']),
      typeId: serializer.fromJson<String>(json['typeId']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      direction: serializer.fromJson<String>(json['direction']),
      label: serializer.fromJson<String>(json['label']),
      revision: serializer.fromJson<int>(json['revision']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      extensionJson: serializer.fromJson<String>(json['extensionJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'targetId': serializer.toJson<String>(targetId),
      'typeId': serializer.toJson<String>(typeId),
      'scopeId': serializer.toJson<String>(scopeId),
      'direction': serializer.toJson<String>(direction),
      'label': serializer.toJson<String>(label),
      'revision': serializer.toJson<int>(revision),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'extensionJson': serializer.toJson<String>(extensionJson),
    };
  }

  RecordLinkRow copyWith(
          {String? id,
          String? sourceId,
          String? targetId,
          String? typeId,
          String? scopeId,
          String? direction,
          String? label,
          int? revision,
          String? metadataJson,
          DateTime? createdAt,
          DateTime? updatedAt,
          String? extensionJson}) =>
      RecordLinkRow(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        targetId: targetId ?? this.targetId,
        typeId: typeId ?? this.typeId,
        scopeId: scopeId ?? this.scopeId,
        direction: direction ?? this.direction,
        label: label ?? this.label,
        revision: revision ?? this.revision,
        metadataJson: metadataJson ?? this.metadataJson,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        extensionJson: extensionJson ?? this.extensionJson,
      );
  RecordLinkRow copyWithCompanion(RecordLinkRowsCompanion data) {
    return RecordLinkRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      typeId: data.typeId.present ? data.typeId.value : this.typeId,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      direction: data.direction.present ? data.direction.value : this.direction,
      label: data.label.present ? data.label.value : this.label,
      revision: data.revision.present ? data.revision.value : this.revision,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      extensionJson: data.extensionJson.present
          ? data.extensionJson.value
          : this.extensionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordLinkRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId, ')
          ..write('typeId: $typeId, ')
          ..write('scopeId: $scopeId, ')
          ..write('direction: $direction, ')
          ..write('label: $label, ')
          ..write('revision: $revision, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extensionJson: $extensionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sourceId,
      targetId,
      typeId,
      scopeId,
      direction,
      label,
      revision,
      metadataJson,
      createdAt,
      updatedAt,
      extensionJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordLinkRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.targetId == this.targetId &&
          other.typeId == this.typeId &&
          other.scopeId == this.scopeId &&
          other.direction == this.direction &&
          other.label == this.label &&
          other.revision == this.revision &&
          other.metadataJson == this.metadataJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.extensionJson == this.extensionJson);
}

class RecordLinkRowsCompanion extends UpdateCompanion<RecordLinkRow> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> targetId;
  final Value<String> typeId;
  final Value<String> scopeId;
  final Value<String> direction;
  final Value<String> label;
  final Value<int> revision;
  final Value<String> metadataJson;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> extensionJson;
  final Value<int> rowid;
  const RecordLinkRowsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.targetId = const Value.absent(),
    this.typeId = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.direction = const Value.absent(),
    this.label = const Value.absent(),
    this.revision = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.extensionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordLinkRowsCompanion.insert({
    required String id,
    required String sourceId,
    required String targetId,
    required String typeId,
    required String scopeId,
    required String direction,
    required String label,
    required int revision,
    required String metadataJson,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String extensionJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sourceId = Value(sourceId),
        targetId = Value(targetId),
        typeId = Value(typeId),
        scopeId = Value(scopeId),
        direction = Value(direction),
        label = Value(label),
        revision = Value(revision),
        metadataJson = Value(metadataJson),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt),
        extensionJson = Value(extensionJson);
  static Insertable<RecordLinkRow> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? targetId,
    Expression<String>? typeId,
    Expression<String>? scopeId,
    Expression<String>? direction,
    Expression<String>? label,
    Expression<int>? revision,
    Expression<String>? metadataJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? extensionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (targetId != null) 'target_id': targetId,
      if (typeId != null) 'type_id': typeId,
      if (scopeId != null) 'scope_id': scopeId,
      if (direction != null) 'direction': direction,
      if (label != null) 'label': label,
      if (revision != null) 'revision': revision,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (extensionJson != null) 'extension_json': extensionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordLinkRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sourceId,
      Value<String>? targetId,
      Value<String>? typeId,
      Value<String>? scopeId,
      Value<String>? direction,
      Value<String>? label,
      Value<int>? revision,
      Value<String>? metadataJson,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<String>? extensionJson,
      Value<int>? rowid}) {
    return RecordLinkRowsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      targetId: targetId ?? this.targetId,
      typeId: typeId ?? this.typeId,
      scopeId: scopeId ?? this.scopeId,
      direction: direction ?? this.direction,
      label: label ?? this.label,
      revision: revision ?? this.revision,
      metadataJson: metadataJson ?? this.metadataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extensionJson: extensionJson ?? this.extensionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (typeId.present) {
      map['type_id'] = Variable<String>(typeId.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (extensionJson.present) {
      map['extension_json'] = Variable<String>(extensionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordLinkRowsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('targetId: $targetId, ')
          ..write('typeId: $typeId, ')
          ..write('scopeId: $scopeId, ')
          ..write('direction: $direction, ')
          ..write('label: $label, ')
          ..write('revision: $revision, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('extensionJson: $extensionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordTypeDefinitionRowsTable extends RecordTypeDefinitionRows
    with TableInfo<$RecordTypeDefinitionRowsTable, RecordTypeDefinitionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordTypeDefinitionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
      'category_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _baseTypeIdMeta =
      const VerificationMeta('baseTypeId');
  @override
  late final GeneratedColumn<String> baseTypeId = GeneratedColumn<String>(
      'base_type_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _scopeTypeMeta =
      const VerificationMeta('scopeType');
  @override
  late final GeneratedColumn<String> scopeType = GeneratedColumn<String>(
      'scope_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeIdMeta =
      const VerificationMeta('scopeId');
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
      'scope_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _templateVersionMeta =
      const VerificationMeta('templateVersion');
  @override
  late final GeneratedColumn<int> templateVersion = GeneratedColumn<int>(
      'template_version', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _builtInMeta =
      const VerificationMeta('builtIn');
  @override
  late final GeneratedColumn<bool> builtIn = GeneratedColumn<bool>(
      'built_in', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("built_in" IN (0, 1))'));
  static const VerificationMeta _definitionJsonMeta =
      const VerificationMeta('definitionJson');
  @override
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
      'definition_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        categoryId,
        baseTypeId,
        scopeType,
        scopeId,
        templateVersion,
        builtIn,
        definitionJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_type_definition_rows';
  @override
  VerificationContext validateIntegrity(
      Insertable<RecordTypeDefinitionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('base_type_id')) {
      context.handle(
          _baseTypeIdMeta,
          baseTypeId.isAcceptableOrUnknown(
              data['base_type_id']!, _baseTypeIdMeta));
    }
    if (data.containsKey('scope_type')) {
      context.handle(_scopeTypeMeta,
          scopeType.isAcceptableOrUnknown(data['scope_type']!, _scopeTypeMeta));
    } else if (isInserting) {
      context.missing(_scopeTypeMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(_scopeIdMeta,
          scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta));
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('template_version')) {
      context.handle(
          _templateVersionMeta,
          templateVersion.isAcceptableOrUnknown(
              data['template_version']!, _templateVersionMeta));
    } else if (isInserting) {
      context.missing(_templateVersionMeta);
    }
    if (data.containsKey('built_in')) {
      context.handle(_builtInMeta,
          builtIn.isAcceptableOrUnknown(data['built_in']!, _builtInMeta));
    } else if (isInserting) {
      context.missing(_builtInMeta);
    }
    if (data.containsKey('definition_json')) {
      context.handle(
          _definitionJsonMeta,
          definitionJson.isAcceptableOrUnknown(
              data['definition_json']!, _definitionJsonMeta));
    } else if (isInserting) {
      context.missing(_definitionJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordTypeDefinitionRow map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordTypeDefinitionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category_id'])!,
      baseTypeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}base_type_id']),
      scopeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_type'])!,
      scopeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_id'])!,
      templateVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}template_version'])!,
      builtIn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}built_in'])!,
      definitionJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}definition_json'])!,
    );
  }

  @override
  $RecordTypeDefinitionRowsTable createAlias(String alias) {
    return $RecordTypeDefinitionRowsTable(attachedDatabase, alias);
  }
}

class RecordTypeDefinitionRow extends DataClass
    implements Insertable<RecordTypeDefinitionRow> {
  final String id;
  final String name;
  final String categoryId;
  final String? baseTypeId;
  final String scopeType;
  final String scopeId;
  final int templateVersion;
  final bool builtIn;
  final String definitionJson;
  const RecordTypeDefinitionRow(
      {required this.id,
      required this.name,
      required this.categoryId,
      this.baseTypeId,
      required this.scopeType,
      required this.scopeId,
      required this.templateVersion,
      required this.builtIn,
      required this.definitionJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || baseTypeId != null) {
      map['base_type_id'] = Variable<String>(baseTypeId);
    }
    map['scope_type'] = Variable<String>(scopeType);
    map['scope_id'] = Variable<String>(scopeId);
    map['template_version'] = Variable<int>(templateVersion);
    map['built_in'] = Variable<bool>(builtIn);
    map['definition_json'] = Variable<String>(definitionJson);
    return map;
  }

  RecordTypeDefinitionRowsCompanion toCompanion(bool nullToAbsent) {
    return RecordTypeDefinitionRowsCompanion(
      id: Value(id),
      name: Value(name),
      categoryId: Value(categoryId),
      baseTypeId: baseTypeId == null && nullToAbsent
          ? const Value.absent()
          : Value(baseTypeId),
      scopeType: Value(scopeType),
      scopeId: Value(scopeId),
      templateVersion: Value(templateVersion),
      builtIn: Value(builtIn),
      definitionJson: Value(definitionJson),
    );
  }

  factory RecordTypeDefinitionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordTypeDefinitionRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      baseTypeId: serializer.fromJson<String?>(json['baseTypeId']),
      scopeType: serializer.fromJson<String>(json['scopeType']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      templateVersion: serializer.fromJson<int>(json['templateVersion']),
      builtIn: serializer.fromJson<bool>(json['builtIn']),
      definitionJson: serializer.fromJson<String>(json['definitionJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String>(categoryId),
      'baseTypeId': serializer.toJson<String?>(baseTypeId),
      'scopeType': serializer.toJson<String>(scopeType),
      'scopeId': serializer.toJson<String>(scopeId),
      'templateVersion': serializer.toJson<int>(templateVersion),
      'builtIn': serializer.toJson<bool>(builtIn),
      'definitionJson': serializer.toJson<String>(definitionJson),
    };
  }

  RecordTypeDefinitionRow copyWith(
          {String? id,
          String? name,
          String? categoryId,
          Value<String?> baseTypeId = const Value.absent(),
          String? scopeType,
          String? scopeId,
          int? templateVersion,
          bool? builtIn,
          String? definitionJson}) =>
      RecordTypeDefinitionRow(
        id: id ?? this.id,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        baseTypeId: baseTypeId.present ? baseTypeId.value : this.baseTypeId,
        scopeType: scopeType ?? this.scopeType,
        scopeId: scopeId ?? this.scopeId,
        templateVersion: templateVersion ?? this.templateVersion,
        builtIn: builtIn ?? this.builtIn,
        definitionJson: definitionJson ?? this.definitionJson,
      );
  RecordTypeDefinitionRow copyWithCompanion(
      RecordTypeDefinitionRowsCompanion data) {
    return RecordTypeDefinitionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      baseTypeId:
          data.baseTypeId.present ? data.baseTypeId.value : this.baseTypeId,
      scopeType: data.scopeType.present ? data.scopeType.value : this.scopeType,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      templateVersion: data.templateVersion.present
          ? data.templateVersion.value
          : this.templateVersion,
      builtIn: data.builtIn.present ? data.builtIn.value : this.builtIn,
      definitionJson: data.definitionJson.present
          ? data.definitionJson.value
          : this.definitionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordTypeDefinitionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('baseTypeId: $baseTypeId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('builtIn: $builtIn, ')
          ..write('definitionJson: $definitionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, categoryId, baseTypeId, scopeType,
      scopeId, templateVersion, builtIn, definitionJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordTypeDefinitionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.baseTypeId == this.baseTypeId &&
          other.scopeType == this.scopeType &&
          other.scopeId == this.scopeId &&
          other.templateVersion == this.templateVersion &&
          other.builtIn == this.builtIn &&
          other.definitionJson == this.definitionJson);
}

class RecordTypeDefinitionRowsCompanion
    extends UpdateCompanion<RecordTypeDefinitionRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> categoryId;
  final Value<String?> baseTypeId;
  final Value<String> scopeType;
  final Value<String> scopeId;
  final Value<int> templateVersion;
  final Value<bool> builtIn;
  final Value<String> definitionJson;
  final Value<int> rowid;
  const RecordTypeDefinitionRowsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.baseTypeId = const Value.absent(),
    this.scopeType = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.templateVersion = const Value.absent(),
    this.builtIn = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordTypeDefinitionRowsCompanion.insert({
    required String id,
    required String name,
    required String categoryId,
    this.baseTypeId = const Value.absent(),
    required String scopeType,
    required String scopeId,
    required int templateVersion,
    required bool builtIn,
    required String definitionJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        categoryId = Value(categoryId),
        scopeType = Value(scopeType),
        scopeId = Value(scopeId),
        templateVersion = Value(templateVersion),
        builtIn = Value(builtIn),
        definitionJson = Value(definitionJson);
  static Insertable<RecordTypeDefinitionRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<String>? baseTypeId,
    Expression<String>? scopeType,
    Expression<String>? scopeId,
    Expression<int>? templateVersion,
    Expression<bool>? builtIn,
    Expression<String>? definitionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (baseTypeId != null) 'base_type_id': baseTypeId,
      if (scopeType != null) 'scope_type': scopeType,
      if (scopeId != null) 'scope_id': scopeId,
      if (templateVersion != null) 'template_version': templateVersion,
      if (builtIn != null) 'built_in': builtIn,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordTypeDefinitionRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? categoryId,
      Value<String?>? baseTypeId,
      Value<String>? scopeType,
      Value<String>? scopeId,
      Value<int>? templateVersion,
      Value<bool>? builtIn,
      Value<String>? definitionJson,
      Value<int>? rowid}) {
    return RecordTypeDefinitionRowsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      baseTypeId: baseTypeId ?? this.baseTypeId,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      templateVersion: templateVersion ?? this.templateVersion,
      builtIn: builtIn ?? this.builtIn,
      definitionJson: definitionJson ?? this.definitionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (baseTypeId.present) {
      map['base_type_id'] = Variable<String>(baseTypeId.value);
    }
    if (scopeType.present) {
      map['scope_type'] = Variable<String>(scopeType.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (templateVersion.present) {
      map['template_version'] = Variable<int>(templateVersion.value);
    }
    if (builtIn.present) {
      map['built_in'] = Variable<bool>(builtIn.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordTypeDefinitionRowsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('baseTypeId: $baseTypeId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('templateVersion: $templateVersion, ')
          ..write('builtIn: $builtIn, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConnectionTypeDefinitionRowsTable extends ConnectionTypeDefinitionRows
    with
        TableInfo<$ConnectionTypeDefinitionRowsTable,
            ConnectionTypeDefinitionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectionTypeDefinitionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scopeIdMeta =
      const VerificationMeta('scopeId');
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
      'scope_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _builtInMeta =
      const VerificationMeta('builtIn');
  @override
  late final GeneratedColumn<bool> builtIn = GeneratedColumn<bool>(
      'built_in', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("built_in" IN (0, 1))'));
  static const VerificationMeta _definitionJsonMeta =
      const VerificationMeta('definitionJson');
  @override
  late final GeneratedColumn<String> definitionJson = GeneratedColumn<String>(
      'definition_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, displayName, scopeId, builtIn, definitionJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connection_type_definition_rows';
  @override
  VerificationContext validateIntegrity(
      Insertable<ConnectionTypeDefinitionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(_scopeIdMeta,
          scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta));
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('built_in')) {
      context.handle(_builtInMeta,
          builtIn.isAcceptableOrUnknown(data['built_in']!, _builtInMeta));
    } else if (isInserting) {
      context.missing(_builtInMeta);
    }
    if (data.containsKey('definition_json')) {
      context.handle(
          _definitionJsonMeta,
          definitionJson.isAcceptableOrUnknown(
              data['definition_json']!, _definitionJsonMeta));
    } else if (isInserting) {
      context.missing(_definitionJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, scopeId};
  @override
  ConnectionTypeDefinitionRow map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectionTypeDefinitionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      scopeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope_id'])!,
      builtIn: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}built_in'])!,
      definitionJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}definition_json'])!,
    );
  }

  @override
  $ConnectionTypeDefinitionRowsTable createAlias(String alias) {
    return $ConnectionTypeDefinitionRowsTable(attachedDatabase, alias);
  }
}

class ConnectionTypeDefinitionRow extends DataClass
    implements Insertable<ConnectionTypeDefinitionRow> {
  final String id;
  final String displayName;
  final String scopeId;
  final bool builtIn;
  final String definitionJson;
  const ConnectionTypeDefinitionRow(
      {required this.id,
      required this.displayName,
      required this.scopeId,
      required this.builtIn,
      required this.definitionJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['scope_id'] = Variable<String>(scopeId);
    map['built_in'] = Variable<bool>(builtIn);
    map['definition_json'] = Variable<String>(definitionJson);
    return map;
  }

  ConnectionTypeDefinitionRowsCompanion toCompanion(bool nullToAbsent) {
    return ConnectionTypeDefinitionRowsCompanion(
      id: Value(id),
      displayName: Value(displayName),
      scopeId: Value(scopeId),
      builtIn: Value(builtIn),
      definitionJson: Value(definitionJson),
    );
  }

  factory ConnectionTypeDefinitionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectionTypeDefinitionRow(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      builtIn: serializer.fromJson<bool>(json['builtIn']),
      definitionJson: serializer.fromJson<String>(json['definitionJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'scopeId': serializer.toJson<String>(scopeId),
      'builtIn': serializer.toJson<bool>(builtIn),
      'definitionJson': serializer.toJson<String>(definitionJson),
    };
  }

  ConnectionTypeDefinitionRow copyWith(
          {String? id,
          String? displayName,
          String? scopeId,
          bool? builtIn,
          String? definitionJson}) =>
      ConnectionTypeDefinitionRow(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        scopeId: scopeId ?? this.scopeId,
        builtIn: builtIn ?? this.builtIn,
        definitionJson: definitionJson ?? this.definitionJson,
      );
  ConnectionTypeDefinitionRow copyWithCompanion(
      ConnectionTypeDefinitionRowsCompanion data) {
    return ConnectionTypeDefinitionRow(
      id: data.id.present ? data.id.value : this.id,
      displayName:
          data.displayName.present ? data.displayName.value : this.displayName,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      builtIn: data.builtIn.present ? data.builtIn.value : this.builtIn,
      definitionJson: data.definitionJson.present
          ? data.definitionJson.value
          : this.definitionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionTypeDefinitionRow(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('scopeId: $scopeId, ')
          ..write('builtIn: $builtIn, ')
          ..write('definitionJson: $definitionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, displayName, scopeId, builtIn, definitionJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectionTypeDefinitionRow &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.scopeId == this.scopeId &&
          other.builtIn == this.builtIn &&
          other.definitionJson == this.definitionJson);
}

class ConnectionTypeDefinitionRowsCompanion
    extends UpdateCompanion<ConnectionTypeDefinitionRow> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> scopeId;
  final Value<bool> builtIn;
  final Value<String> definitionJson;
  final Value<int> rowid;
  const ConnectionTypeDefinitionRowsCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.builtIn = const Value.absent(),
    this.definitionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConnectionTypeDefinitionRowsCompanion.insert({
    required String id,
    required String displayName,
    required String scopeId,
    required bool builtIn,
    required String definitionJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        displayName = Value(displayName),
        scopeId = Value(scopeId),
        builtIn = Value(builtIn),
        definitionJson = Value(definitionJson);
  static Insertable<ConnectionTypeDefinitionRow> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? scopeId,
    Expression<bool>? builtIn,
    Expression<String>? definitionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (scopeId != null) 'scope_id': scopeId,
      if (builtIn != null) 'built_in': builtIn,
      if (definitionJson != null) 'definition_json': definitionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConnectionTypeDefinitionRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<String>? scopeId,
      Value<bool>? builtIn,
      Value<String>? definitionJson,
      Value<int>? rowid}) {
    return ConnectionTypeDefinitionRowsCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      scopeId: scopeId ?? this.scopeId,
      builtIn: builtIn ?? this.builtIn,
      definitionJson: definitionJson ?? this.definitionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (builtIn.present) {
      map['built_in'] = Variable<bool>(builtIn.value);
    }
    if (definitionJson.present) {
      map['definition_json'] = Variable<String>(definitionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectionTypeDefinitionRowsCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('scopeId: $scopeId, ')
          ..write('builtIn: $builtIn, ')
          ..write('definitionJson: $definitionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoryBranchRowsTable extends StoryBranchRows
    with TableInfo<$StoryBranchRowsTable, StoryBranchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoryBranchRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parentBranchIdMeta =
      const VerificationMeta('parentBranchId');
  @override
  late final GeneratedColumn<String> parentBranchId = GeneratedColumn<String>(
      'parent_branch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _branchJsonMeta =
      const VerificationMeta('branchJson');
  @override
  late final GeneratedColumn<String> branchJson = GeneratedColumn<String>(
      'branch_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, projectId, parentBranchId, name, kind, status, branchJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'story_branch_rows';
  @override
  VerificationContext validateIntegrity(Insertable<StoryBranchRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('parent_branch_id')) {
      context.handle(
          _parentBranchIdMeta,
          parentBranchId.isAcceptableOrUnknown(
              data['parent_branch_id']!, _parentBranchIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('branch_json')) {
      context.handle(
          _branchJsonMeta,
          branchJson.isAcceptableOrUnknown(
              data['branch_json']!, _branchJsonMeta));
    } else if (isInserting) {
      context.missing(_branchJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoryBranchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoryBranchRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      parentBranchId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}parent_branch_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      branchJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_json'])!,
    );
  }

  @override
  $StoryBranchRowsTable createAlias(String alias) {
    return $StoryBranchRowsTable(attachedDatabase, alias);
  }
}

class StoryBranchRow extends DataClass implements Insertable<StoryBranchRow> {
  final String id;
  final String projectId;
  final String? parentBranchId;
  final String name;
  final String kind;
  final String status;
  final String branchJson;
  const StoryBranchRow(
      {required this.id,
      required this.projectId,
      this.parentBranchId,
      required this.name,
      required this.kind,
      required this.status,
      required this.branchJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || parentBranchId != null) {
      map['parent_branch_id'] = Variable<String>(parentBranchId);
    }
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    map['branch_json'] = Variable<String>(branchJson);
    return map;
  }

  StoryBranchRowsCompanion toCompanion(bool nullToAbsent) {
    return StoryBranchRowsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      parentBranchId: parentBranchId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentBranchId),
      name: Value(name),
      kind: Value(kind),
      status: Value(status),
      branchJson: Value(branchJson),
    );
  }

  factory StoryBranchRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoryBranchRow(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      parentBranchId: serializer.fromJson<String?>(json['parentBranchId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      branchJson: serializer.fromJson<String>(json['branchJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'parentBranchId': serializer.toJson<String?>(parentBranchId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'branchJson': serializer.toJson<String>(branchJson),
    };
  }

  StoryBranchRow copyWith(
          {String? id,
          String? projectId,
          Value<String?> parentBranchId = const Value.absent(),
          String? name,
          String? kind,
          String? status,
          String? branchJson}) =>
      StoryBranchRow(
        id: id ?? this.id,
        projectId: projectId ?? this.projectId,
        parentBranchId:
            parentBranchId.present ? parentBranchId.value : this.parentBranchId,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        status: status ?? this.status,
        branchJson: branchJson ?? this.branchJson,
      );
  StoryBranchRow copyWithCompanion(StoryBranchRowsCompanion data) {
    return StoryBranchRow(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      parentBranchId: data.parentBranchId.present
          ? data.parentBranchId.value
          : this.parentBranchId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      branchJson:
          data.branchJson.present ? data.branchJson.value : this.branchJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoryBranchRow(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('parentBranchId: $parentBranchId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('branchJson: $branchJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, projectId, parentBranchId, name, kind, status, branchJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoryBranchRow &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.parentBranchId == this.parentBranchId &&
          other.name == this.name &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.branchJson == this.branchJson);
}

class StoryBranchRowsCompanion extends UpdateCompanion<StoryBranchRow> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String?> parentBranchId;
  final Value<String> name;
  final Value<String> kind;
  final Value<String> status;
  final Value<String> branchJson;
  final Value<int> rowid;
  const StoryBranchRowsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.parentBranchId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.branchJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoryBranchRowsCompanion.insert({
    required String id,
    required String projectId,
    this.parentBranchId = const Value.absent(),
    required String name,
    required String kind,
    required String status,
    required String branchJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        projectId = Value(projectId),
        name = Value(name),
        kind = Value(kind),
        status = Value(status),
        branchJson = Value(branchJson);
  static Insertable<StoryBranchRow> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? parentBranchId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? branchJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (parentBranchId != null) 'parent_branch_id': parentBranchId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (branchJson != null) 'branch_json': branchJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoryBranchRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? projectId,
      Value<String?>? parentBranchId,
      Value<String>? name,
      Value<String>? kind,
      Value<String>? status,
      Value<String>? branchJson,
      Value<int>? rowid}) {
    return StoryBranchRowsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      parentBranchId: parentBranchId ?? this.parentBranchId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      branchJson: branchJson ?? this.branchJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (parentBranchId.present) {
      map['parent_branch_id'] = Variable<String>(parentBranchId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (branchJson.present) {
      map['branch_json'] = Variable<String>(branchJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoryBranchRowsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('parentBranchId: $parentBranchId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('branchJson: $branchJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BranchRecordOverlayRowsTable extends BranchRecordOverlayRows
    with TableInfo<$BranchRecordOverlayRowsTable, BranchRecordOverlayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BranchRecordOverlayRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES story_branch_rows (id)'));
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _overlayJsonMeta =
      const VerificationMeta('overlayJson');
  @override
  late final GeneratedColumn<String> overlayJson = GeneratedColumn<String>(
      'overlay_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [branchId, recordId, state, overlayJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'branch_record_overlay_rows';
  @override
  VerificationContext validateIntegrity(
      Insertable<BranchRecordOverlayRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('overlay_json')) {
      context.handle(
          _overlayJsonMeta,
          overlayJson.isAcceptableOrUnknown(
              data['overlay_json']!, _overlayJsonMeta));
    } else if (isInserting) {
      context.missing(_overlayJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {branchId, recordId};
  @override
  BranchRecordOverlayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BranchRecordOverlayRow(
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      overlayJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}overlay_json'])!,
    );
  }

  @override
  $BranchRecordOverlayRowsTable createAlias(String alias) {
    return $BranchRecordOverlayRowsTable(attachedDatabase, alias);
  }
}

class BranchRecordOverlayRow extends DataClass
    implements Insertable<BranchRecordOverlayRow> {
  final String branchId;
  final String recordId;
  final String state;
  final String overlayJson;
  const BranchRecordOverlayRow(
      {required this.branchId,
      required this.recordId,
      required this.state,
      required this.overlayJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['branch_id'] = Variable<String>(branchId);
    map['record_id'] = Variable<String>(recordId);
    map['state'] = Variable<String>(state);
    map['overlay_json'] = Variable<String>(overlayJson);
    return map;
  }

  BranchRecordOverlayRowsCompanion toCompanion(bool nullToAbsent) {
    return BranchRecordOverlayRowsCompanion(
      branchId: Value(branchId),
      recordId: Value(recordId),
      state: Value(state),
      overlayJson: Value(overlayJson),
    );
  }

  factory BranchRecordOverlayRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BranchRecordOverlayRow(
      branchId: serializer.fromJson<String>(json['branchId']),
      recordId: serializer.fromJson<String>(json['recordId']),
      state: serializer.fromJson<String>(json['state']),
      overlayJson: serializer.fromJson<String>(json['overlayJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'branchId': serializer.toJson<String>(branchId),
      'recordId': serializer.toJson<String>(recordId),
      'state': serializer.toJson<String>(state),
      'overlayJson': serializer.toJson<String>(overlayJson),
    };
  }

  BranchRecordOverlayRow copyWith(
          {String? branchId,
          String? recordId,
          String? state,
          String? overlayJson}) =>
      BranchRecordOverlayRow(
        branchId: branchId ?? this.branchId,
        recordId: recordId ?? this.recordId,
        state: state ?? this.state,
        overlayJson: overlayJson ?? this.overlayJson,
      );
  BranchRecordOverlayRow copyWithCompanion(
      BranchRecordOverlayRowsCompanion data) {
    return BranchRecordOverlayRow(
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      state: data.state.present ? data.state.value : this.state,
      overlayJson:
          data.overlayJson.present ? data.overlayJson.value : this.overlayJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BranchRecordOverlayRow(')
          ..write('branchId: $branchId, ')
          ..write('recordId: $recordId, ')
          ..write('state: $state, ')
          ..write('overlayJson: $overlayJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(branchId, recordId, state, overlayJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BranchRecordOverlayRow &&
          other.branchId == this.branchId &&
          other.recordId == this.recordId &&
          other.state == this.state &&
          other.overlayJson == this.overlayJson);
}

class BranchRecordOverlayRowsCompanion
    extends UpdateCompanion<BranchRecordOverlayRow> {
  final Value<String> branchId;
  final Value<String> recordId;
  final Value<String> state;
  final Value<String> overlayJson;
  final Value<int> rowid;
  const BranchRecordOverlayRowsCompanion({
    this.branchId = const Value.absent(),
    this.recordId = const Value.absent(),
    this.state = const Value.absent(),
    this.overlayJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BranchRecordOverlayRowsCompanion.insert({
    required String branchId,
    required String recordId,
    required String state,
    required String overlayJson,
    this.rowid = const Value.absent(),
  })  : branchId = Value(branchId),
        recordId = Value(recordId),
        state = Value(state),
        overlayJson = Value(overlayJson);
  static Insertable<BranchRecordOverlayRow> custom({
    Expression<String>? branchId,
    Expression<String>? recordId,
    Expression<String>? state,
    Expression<String>? overlayJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (branchId != null) 'branch_id': branchId,
      if (recordId != null) 'record_id': recordId,
      if (state != null) 'state': state,
      if (overlayJson != null) 'overlay_json': overlayJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BranchRecordOverlayRowsCompanion copyWith(
      {Value<String>? branchId,
      Value<String>? recordId,
      Value<String>? state,
      Value<String>? overlayJson,
      Value<int>? rowid}) {
    return BranchRecordOverlayRowsCompanion(
      branchId: branchId ?? this.branchId,
      recordId: recordId ?? this.recordId,
      state: state ?? this.state,
      overlayJson: overlayJson ?? this.overlayJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (overlayJson.present) {
      map['overlay_json'] = Variable<String>(overlayJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BranchRecordOverlayRowsCompanion(')
          ..write('branchId: $branchId, ')
          ..write('recordId: $recordId, ')
          ..write('state: $state, ')
          ..write('overlayJson: $overlayJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BranchLinkOverlayRowsTable extends BranchLinkOverlayRows
    with TableInfo<$BranchLinkOverlayRowsTable, BranchLinkOverlayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BranchLinkOverlayRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES story_branch_rows (id)'));
  static const VerificationMeta _linkIdMeta = const VerificationMeta('linkId');
  @override
  late final GeneratedColumn<String> linkId = GeneratedColumn<String>(
      'link_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
      'state', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _overlayJsonMeta =
      const VerificationMeta('overlayJson');
  @override
  late final GeneratedColumn<String> overlayJson = GeneratedColumn<String>(
      'overlay_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [branchId, linkId, state, overlayJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'branch_link_overlay_rows';
  @override
  VerificationContext validateIntegrity(
      Insertable<BranchLinkOverlayRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    } else if (isInserting) {
      context.missing(_branchIdMeta);
    }
    if (data.containsKey('link_id')) {
      context.handle(_linkIdMeta,
          linkId.isAcceptableOrUnknown(data['link_id']!, _linkIdMeta));
    } else if (isInserting) {
      context.missing(_linkIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('overlay_json')) {
      context.handle(
          _overlayJsonMeta,
          overlayJson.isAcceptableOrUnknown(
              data['overlay_json']!, _overlayJsonMeta));
    } else if (isInserting) {
      context.missing(_overlayJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {branchId, linkId};
  @override
  BranchLinkOverlayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BranchLinkOverlayRow(
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id'])!,
      linkId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}link_id'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}state'])!,
      overlayJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}overlay_json'])!,
    );
  }

  @override
  $BranchLinkOverlayRowsTable createAlias(String alias) {
    return $BranchLinkOverlayRowsTable(attachedDatabase, alias);
  }
}

class BranchLinkOverlayRow extends DataClass
    implements Insertable<BranchLinkOverlayRow> {
  final String branchId;
  final String linkId;
  final String state;
  final String overlayJson;
  const BranchLinkOverlayRow(
      {required this.branchId,
      required this.linkId,
      required this.state,
      required this.overlayJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['branch_id'] = Variable<String>(branchId);
    map['link_id'] = Variable<String>(linkId);
    map['state'] = Variable<String>(state);
    map['overlay_json'] = Variable<String>(overlayJson);
    return map;
  }

  BranchLinkOverlayRowsCompanion toCompanion(bool nullToAbsent) {
    return BranchLinkOverlayRowsCompanion(
      branchId: Value(branchId),
      linkId: Value(linkId),
      state: Value(state),
      overlayJson: Value(overlayJson),
    );
  }

  factory BranchLinkOverlayRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BranchLinkOverlayRow(
      branchId: serializer.fromJson<String>(json['branchId']),
      linkId: serializer.fromJson<String>(json['linkId']),
      state: serializer.fromJson<String>(json['state']),
      overlayJson: serializer.fromJson<String>(json['overlayJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'branchId': serializer.toJson<String>(branchId),
      'linkId': serializer.toJson<String>(linkId),
      'state': serializer.toJson<String>(state),
      'overlayJson': serializer.toJson<String>(overlayJson),
    };
  }

  BranchLinkOverlayRow copyWith(
          {String? branchId,
          String? linkId,
          String? state,
          String? overlayJson}) =>
      BranchLinkOverlayRow(
        branchId: branchId ?? this.branchId,
        linkId: linkId ?? this.linkId,
        state: state ?? this.state,
        overlayJson: overlayJson ?? this.overlayJson,
      );
  BranchLinkOverlayRow copyWithCompanion(BranchLinkOverlayRowsCompanion data) {
    return BranchLinkOverlayRow(
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      linkId: data.linkId.present ? data.linkId.value : this.linkId,
      state: data.state.present ? data.state.value : this.state,
      overlayJson:
          data.overlayJson.present ? data.overlayJson.value : this.overlayJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BranchLinkOverlayRow(')
          ..write('branchId: $branchId, ')
          ..write('linkId: $linkId, ')
          ..write('state: $state, ')
          ..write('overlayJson: $overlayJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(branchId, linkId, state, overlayJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BranchLinkOverlayRow &&
          other.branchId == this.branchId &&
          other.linkId == this.linkId &&
          other.state == this.state &&
          other.overlayJson == this.overlayJson);
}

class BranchLinkOverlayRowsCompanion
    extends UpdateCompanion<BranchLinkOverlayRow> {
  final Value<String> branchId;
  final Value<String> linkId;
  final Value<String> state;
  final Value<String> overlayJson;
  final Value<int> rowid;
  const BranchLinkOverlayRowsCompanion({
    this.branchId = const Value.absent(),
    this.linkId = const Value.absent(),
    this.state = const Value.absent(),
    this.overlayJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BranchLinkOverlayRowsCompanion.insert({
    required String branchId,
    required String linkId,
    required String state,
    required String overlayJson,
    this.rowid = const Value.absent(),
  })  : branchId = Value(branchId),
        linkId = Value(linkId),
        state = Value(state),
        overlayJson = Value(overlayJson);
  static Insertable<BranchLinkOverlayRow> custom({
    Expression<String>? branchId,
    Expression<String>? linkId,
    Expression<String>? state,
    Expression<String>? overlayJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (branchId != null) 'branch_id': branchId,
      if (linkId != null) 'link_id': linkId,
      if (state != null) 'state': state,
      if (overlayJson != null) 'overlay_json': overlayJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BranchLinkOverlayRowsCompanion copyWith(
      {Value<String>? branchId,
      Value<String>? linkId,
      Value<String>? state,
      Value<String>? overlayJson,
      Value<int>? rowid}) {
    return BranchLinkOverlayRowsCompanion(
      branchId: branchId ?? this.branchId,
      linkId: linkId ?? this.linkId,
      state: state ?? this.state,
      overlayJson: overlayJson ?? this.overlayJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (linkId.present) {
      map['link_id'] = Variable<String>(linkId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (overlayJson.present) {
      map['overlay_json'] = Variable<String>(overlayJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BranchLinkOverlayRowsCompanion(')
          ..write('branchId: $branchId, ')
          ..write('linkId: $linkId, ')
          ..write('state: $state, ')
          ..write('overlayJson: $overlayJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordVersionRowsTable extends RecordVersionRows
    with TableInfo<$RecordVersionRowsTable, RecordVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordVersionRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityKindMeta =
      const VerificationMeta('entityKind');
  @override
  late final GeneratedColumn<String> entityKind = GeneratedColumn<String>(
      'entity_kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordTypeMeta =
      const VerificationMeta('recordType');
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
      'record_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seriesIdMeta =
      const VerificationMeta('seriesId');
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
      'series_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changeTypeMeta =
      const VerificationMeta('changeType');
  @override
  late final GeneratedColumn<String> changeType = GeneratedColumn<String>(
      'change_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _previousVersionIdMeta =
      const VerificationMeta('previousVersionId');
  @override
  late final GeneratedColumn<String> previousVersionId =
      GeneratedColumn<String>('previous_version_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _versionJsonMeta =
      const VerificationMeta('versionJson');
  @override
  late final GeneratedColumn<String> versionJson = GeneratedColumn<String>(
      'version_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entityId,
        entityKind,
        recordId,
        recordType,
        projectId,
        seriesId,
        bookId,
        branchId,
        changeType,
        createdAt,
        previousVersionId,
        versionJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_version_rows';
  @override
  VerificationContext validateIntegrity(Insertable<RecordVersionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_kind')) {
      context.handle(
          _entityKindMeta,
          entityKind.isAcceptableOrUnknown(
              data['entity_kind']!, _entityKindMeta));
    } else if (isInserting) {
      context.missing(_entityKindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
          _recordTypeMeta,
          recordType.isAcceptableOrUnknown(
              data['record_type']!, _recordTypeMeta));
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(_seriesIdMeta,
          seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('change_type')) {
      context.handle(
          _changeTypeMeta,
          changeType.isAcceptableOrUnknown(
              data['change_type']!, _changeTypeMeta));
    } else if (isInserting) {
      context.missing(_changeTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('previous_version_id')) {
      context.handle(
          _previousVersionIdMeta,
          previousVersionId.isAcceptableOrUnknown(
              data['previous_version_id']!, _previousVersionIdMeta));
    }
    if (data.containsKey('version_json')) {
      context.handle(
          _versionJsonMeta,
          versionJson.isAcceptableOrUnknown(
              data['version_json']!, _versionJsonMeta));
    } else if (isInserting) {
      context.missing(_versionJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordVersionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      entityKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_kind'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      recordType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_type'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      seriesId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}series_id']),
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id']),
      changeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}change_type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      previousVersionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}previous_version_id']),
      versionJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version_json'])!,
    );
  }

  @override
  $RecordVersionRowsTable createAlias(String alias) {
    return $RecordVersionRowsTable(attachedDatabase, alias);
  }
}

class RecordVersionRow extends DataClass
    implements Insertable<RecordVersionRow> {
  final String id;
  final String entityId;
  final String entityKind;
  final String recordId;
  final String recordType;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final String changeType;
  final DateTime createdAt;
  final String? previousVersionId;
  final String versionJson;
  const RecordVersionRow(
      {required this.id,
      required this.entityId,
      required this.entityKind,
      required this.recordId,
      required this.recordType,
      required this.projectId,
      this.seriesId,
      this.bookId,
      this.branchId,
      required this.changeType,
      required this.createdAt,
      this.previousVersionId,
      required this.versionJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_kind'] = Variable<String>(entityKind);
    map['record_id'] = Variable<String>(recordId);
    map['record_type'] = Variable<String>(recordType);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['change_type'] = Variable<String>(changeType);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || previousVersionId != null) {
      map['previous_version_id'] = Variable<String>(previousVersionId);
    }
    map['version_json'] = Variable<String>(versionJson);
    return map;
  }

  RecordVersionRowsCompanion toCompanion(bool nullToAbsent) {
    return RecordVersionRowsCompanion(
      id: Value(id),
      entityId: Value(entityId),
      entityKind: Value(entityKind),
      recordId: Value(recordId),
      recordType: Value(recordType),
      projectId: Value(projectId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      bookId:
          bookId == null && nullToAbsent ? const Value.absent() : Value(bookId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      changeType: Value(changeType),
      createdAt: Value(createdAt),
      previousVersionId: previousVersionId == null && nullToAbsent
          ? const Value.absent()
          : Value(previousVersionId),
      versionJson: Value(versionJson),
    );
  }

  factory RecordVersionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordVersionRow(
      id: serializer.fromJson<String>(json['id']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entityKind: serializer.fromJson<String>(json['entityKind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      recordType: serializer.fromJson<String>(json['recordType']),
      projectId: serializer.fromJson<String>(json['projectId']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      changeType: serializer.fromJson<String>(json['changeType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      previousVersionId:
          serializer.fromJson<String?>(json['previousVersionId']),
      versionJson: serializer.fromJson<String>(json['versionJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityId': serializer.toJson<String>(entityId),
      'entityKind': serializer.toJson<String>(entityKind),
      'recordId': serializer.toJson<String>(recordId),
      'recordType': serializer.toJson<String>(recordType),
      'projectId': serializer.toJson<String>(projectId),
      'seriesId': serializer.toJson<String?>(seriesId),
      'bookId': serializer.toJson<String?>(bookId),
      'branchId': serializer.toJson<String?>(branchId),
      'changeType': serializer.toJson<String>(changeType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'previousVersionId': serializer.toJson<String?>(previousVersionId),
      'versionJson': serializer.toJson<String>(versionJson),
    };
  }

  RecordVersionRow copyWith(
          {String? id,
          String? entityId,
          String? entityKind,
          String? recordId,
          String? recordType,
          String? projectId,
          Value<String?> seriesId = const Value.absent(),
          Value<String?> bookId = const Value.absent(),
          Value<String?> branchId = const Value.absent(),
          String? changeType,
          DateTime? createdAt,
          Value<String?> previousVersionId = const Value.absent(),
          String? versionJson}) =>
      RecordVersionRow(
        id: id ?? this.id,
        entityId: entityId ?? this.entityId,
        entityKind: entityKind ?? this.entityKind,
        recordId: recordId ?? this.recordId,
        recordType: recordType ?? this.recordType,
        projectId: projectId ?? this.projectId,
        seriesId: seriesId.present ? seriesId.value : this.seriesId,
        bookId: bookId.present ? bookId.value : this.bookId,
        branchId: branchId.present ? branchId.value : this.branchId,
        changeType: changeType ?? this.changeType,
        createdAt: createdAt ?? this.createdAt,
        previousVersionId: previousVersionId.present
            ? previousVersionId.value
            : this.previousVersionId,
        versionJson: versionJson ?? this.versionJson,
      );
  RecordVersionRow copyWithCompanion(RecordVersionRowsCompanion data) {
    return RecordVersionRow(
      id: data.id.present ? data.id.value : this.id,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityKind:
          data.entityKind.present ? data.entityKind.value : this.entityKind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      recordType:
          data.recordType.present ? data.recordType.value : this.recordType,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      changeType:
          data.changeType.present ? data.changeType.value : this.changeType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      previousVersionId: data.previousVersionId.present
          ? data.previousVersionId.value
          : this.previousVersionId,
      versionJson:
          data.versionJson.present ? data.versionJson.value : this.versionJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordVersionRow(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityKind: $entityKind, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('projectId: $projectId, ')
          ..write('seriesId: $seriesId, ')
          ..write('bookId: $bookId, ')
          ..write('branchId: $branchId, ')
          ..write('changeType: $changeType, ')
          ..write('createdAt: $createdAt, ')
          ..write('previousVersionId: $previousVersionId, ')
          ..write('versionJson: $versionJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      entityId,
      entityKind,
      recordId,
      recordType,
      projectId,
      seriesId,
      bookId,
      branchId,
      changeType,
      createdAt,
      previousVersionId,
      versionJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordVersionRow &&
          other.id == this.id &&
          other.entityId == this.entityId &&
          other.entityKind == this.entityKind &&
          other.recordId == this.recordId &&
          other.recordType == this.recordType &&
          other.projectId == this.projectId &&
          other.seriesId == this.seriesId &&
          other.bookId == this.bookId &&
          other.branchId == this.branchId &&
          other.changeType == this.changeType &&
          other.createdAt == this.createdAt &&
          other.previousVersionId == this.previousVersionId &&
          other.versionJson == this.versionJson);
}

class RecordVersionRowsCompanion extends UpdateCompanion<RecordVersionRow> {
  final Value<String> id;
  final Value<String> entityId;
  final Value<String> entityKind;
  final Value<String> recordId;
  final Value<String> recordType;
  final Value<String> projectId;
  final Value<String?> seriesId;
  final Value<String?> bookId;
  final Value<String?> branchId;
  final Value<String> changeType;
  final Value<DateTime> createdAt;
  final Value<String?> previousVersionId;
  final Value<String> versionJson;
  final Value<int> rowid;
  const RecordVersionRowsCompanion({
    this.id = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.recordType = const Value.absent(),
    this.projectId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.changeType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.previousVersionId = const Value.absent(),
    this.versionJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordVersionRowsCompanion.insert({
    required String id,
    required String entityId,
    required String entityKind,
    required String recordId,
    required String recordType,
    required String projectId,
    this.seriesId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.branchId = const Value.absent(),
    required String changeType,
    required DateTime createdAt,
    this.previousVersionId = const Value.absent(),
    required String versionJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        entityId = Value(entityId),
        entityKind = Value(entityKind),
        recordId = Value(recordId),
        recordType = Value(recordType),
        projectId = Value(projectId),
        changeType = Value(changeType),
        createdAt = Value(createdAt),
        versionJson = Value(versionJson);
  static Insertable<RecordVersionRow> custom({
    Expression<String>? id,
    Expression<String>? entityId,
    Expression<String>? entityKind,
    Expression<String>? recordId,
    Expression<String>? recordType,
    Expression<String>? projectId,
    Expression<String>? seriesId,
    Expression<String>? bookId,
    Expression<String>? branchId,
    Expression<String>? changeType,
    Expression<DateTime>? createdAt,
    Expression<String>? previousVersionId,
    Expression<String>? versionJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityId != null) 'entity_id': entityId,
      if (entityKind != null) 'entity_kind': entityKind,
      if (recordId != null) 'record_id': recordId,
      if (recordType != null) 'record_type': recordType,
      if (projectId != null) 'project_id': projectId,
      if (seriesId != null) 'series_id': seriesId,
      if (bookId != null) 'book_id': bookId,
      if (branchId != null) 'branch_id': branchId,
      if (changeType != null) 'change_type': changeType,
      if (createdAt != null) 'created_at': createdAt,
      if (previousVersionId != null) 'previous_version_id': previousVersionId,
      if (versionJson != null) 'version_json': versionJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordVersionRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? entityId,
      Value<String>? entityKind,
      Value<String>? recordId,
      Value<String>? recordType,
      Value<String>? projectId,
      Value<String?>? seriesId,
      Value<String?>? bookId,
      Value<String?>? branchId,
      Value<String>? changeType,
      Value<DateTime>? createdAt,
      Value<String?>? previousVersionId,
      Value<String>? versionJson,
      Value<int>? rowid}) {
    return RecordVersionRowsCompanion(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      entityKind: entityKind ?? this.entityKind,
      recordId: recordId ?? this.recordId,
      recordType: recordType ?? this.recordType,
      projectId: projectId ?? this.projectId,
      seriesId: seriesId ?? this.seriesId,
      bookId: bookId ?? this.bookId,
      branchId: branchId ?? this.branchId,
      changeType: changeType ?? this.changeType,
      createdAt: createdAt ?? this.createdAt,
      previousVersionId: previousVersionId ?? this.previousVersionId,
      versionJson: versionJson ?? this.versionJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(entityKind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (changeType.present) {
      map['change_type'] = Variable<String>(changeType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (previousVersionId.present) {
      map['previous_version_id'] = Variable<String>(previousVersionId.value);
    }
    if (versionJson.present) {
      map['version_json'] = Variable<String>(versionJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordVersionRowsCompanion(')
          ..write('id: $id, ')
          ..write('entityId: $entityId, ')
          ..write('entityKind: $entityKind, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('projectId: $projectId, ')
          ..write('seriesId: $seriesId, ')
          ..write('bookId: $bookId, ')
          ..write('branchId: $branchId, ')
          ..write('changeType: $changeType, ')
          ..write('createdAt: $createdAt, ')
          ..write('previousVersionId: $previousVersionId, ')
          ..write('versionJson: $versionJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditEventRowsTable extends AuditEventRows
    with TableInfo<$AuditEventRowsTable, AuditEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditEventRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionIdMeta =
      const VerificationMeta('versionId');
  @override
  late final GeneratedColumn<String> versionId = GeneratedColumn<String>(
      'version_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityKindMeta =
      const VerificationMeta('entityKind');
  @override
  late final GeneratedColumn<String> entityKind = GeneratedColumn<String>(
      'entity_kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordIdMeta =
      const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
      'record_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recordTypeMeta =
      const VerificationMeta('recordType');
  @override
  late final GeneratedColumn<String> recordType = GeneratedColumn<String>(
      'record_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _projectIdMeta =
      const VerificationMeta('projectId');
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
      'project_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seriesIdMeta =
      const VerificationMeta('seriesId');
  @override
  late final GeneratedColumn<String> seriesId = GeneratedColumn<String>(
      'series_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
      'book_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _branchIdMeta =
      const VerificationMeta('branchId');
  @override
  late final GeneratedColumn<String> branchId = GeneratedColumn<String>(
      'branch_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _changeTypeMeta =
      const VerificationMeta('changeType');
  @override
  late final GeneratedColumn<String> changeType = GeneratedColumn<String>(
      'change_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _eventJsonMeta =
      const VerificationMeta('eventJson');
  @override
  late final GeneratedColumn<String> eventJson = GeneratedColumn<String>(
      'event_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        versionId,
        entityId,
        entityKind,
        recordId,
        recordType,
        projectId,
        seriesId,
        bookId,
        branchId,
        changeType,
        createdAt,
        eventJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_event_rows';
  @override
  VerificationContext validateIntegrity(Insertable<AuditEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version_id')) {
      context.handle(_versionIdMeta,
          versionId.isAcceptableOrUnknown(data['version_id']!, _versionIdMeta));
    } else if (isInserting) {
      context.missing(_versionIdMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('entity_kind')) {
      context.handle(
          _entityKindMeta,
          entityKind.isAcceptableOrUnknown(
              data['entity_kind']!, _entityKindMeta));
    } else if (isInserting) {
      context.missing(_entityKindMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta,
          recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('record_type')) {
      context.handle(
          _recordTypeMeta,
          recordType.isAcceptableOrUnknown(
              data['record_type']!, _recordTypeMeta));
    } else if (isInserting) {
      context.missing(_recordTypeMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(_projectIdMeta,
          projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta));
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('series_id')) {
      context.handle(_seriesIdMeta,
          seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta));
    }
    if (data.containsKey('book_id')) {
      context.handle(_bookIdMeta,
          bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta));
    }
    if (data.containsKey('branch_id')) {
      context.handle(_branchIdMeta,
          branchId.isAcceptableOrUnknown(data['branch_id']!, _branchIdMeta));
    }
    if (data.containsKey('change_type')) {
      context.handle(
          _changeTypeMeta,
          changeType.isAcceptableOrUnknown(
              data['change_type']!, _changeTypeMeta));
    } else if (isInserting) {
      context.missing(_changeTypeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('event_json')) {
      context.handle(_eventJsonMeta,
          eventJson.isAcceptableOrUnknown(data['event_json']!, _eventJsonMeta));
    } else if (isInserting) {
      context.missing(_eventJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      versionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version_id'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id'])!,
      entityKind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_kind'])!,
      recordId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      recordType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_type'])!,
      projectId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}project_id'])!,
      seriesId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}series_id']),
      bookId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}book_id']),
      branchId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}branch_id']),
      changeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}change_type'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      eventJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event_json'])!,
    );
  }

  @override
  $AuditEventRowsTable createAlias(String alias) {
    return $AuditEventRowsTable(attachedDatabase, alias);
  }
}

class AuditEventRow extends DataClass implements Insertable<AuditEventRow> {
  final String id;
  final String versionId;
  final String entityId;
  final String entityKind;
  final String recordId;
  final String recordType;
  final String projectId;
  final String? seriesId;
  final String? bookId;
  final String? branchId;
  final String changeType;
  final DateTime createdAt;
  final String eventJson;
  const AuditEventRow(
      {required this.id,
      required this.versionId,
      required this.entityId,
      required this.entityKind,
      required this.recordId,
      required this.recordType,
      required this.projectId,
      this.seriesId,
      this.bookId,
      this.branchId,
      required this.changeType,
      required this.createdAt,
      required this.eventJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version_id'] = Variable<String>(versionId);
    map['entity_id'] = Variable<String>(entityId);
    map['entity_kind'] = Variable<String>(entityKind);
    map['record_id'] = Variable<String>(recordId);
    map['record_type'] = Variable<String>(recordType);
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<String>(seriesId);
    }
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || branchId != null) {
      map['branch_id'] = Variable<String>(branchId);
    }
    map['change_type'] = Variable<String>(changeType);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['event_json'] = Variable<String>(eventJson);
    return map;
  }

  AuditEventRowsCompanion toCompanion(bool nullToAbsent) {
    return AuditEventRowsCompanion(
      id: Value(id),
      versionId: Value(versionId),
      entityId: Value(entityId),
      entityKind: Value(entityKind),
      recordId: Value(recordId),
      recordType: Value(recordType),
      projectId: Value(projectId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      bookId:
          bookId == null && nullToAbsent ? const Value.absent() : Value(bookId),
      branchId: branchId == null && nullToAbsent
          ? const Value.absent()
          : Value(branchId),
      changeType: Value(changeType),
      createdAt: Value(createdAt),
      eventJson: Value(eventJson),
    );
  }

  factory AuditEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditEventRow(
      id: serializer.fromJson<String>(json['id']),
      versionId: serializer.fromJson<String>(json['versionId']),
      entityId: serializer.fromJson<String>(json['entityId']),
      entityKind: serializer.fromJson<String>(json['entityKind']),
      recordId: serializer.fromJson<String>(json['recordId']),
      recordType: serializer.fromJson<String>(json['recordType']),
      projectId: serializer.fromJson<String>(json['projectId']),
      seriesId: serializer.fromJson<String?>(json['seriesId']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      branchId: serializer.fromJson<String?>(json['branchId']),
      changeType: serializer.fromJson<String>(json['changeType']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      eventJson: serializer.fromJson<String>(json['eventJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'versionId': serializer.toJson<String>(versionId),
      'entityId': serializer.toJson<String>(entityId),
      'entityKind': serializer.toJson<String>(entityKind),
      'recordId': serializer.toJson<String>(recordId),
      'recordType': serializer.toJson<String>(recordType),
      'projectId': serializer.toJson<String>(projectId),
      'seriesId': serializer.toJson<String?>(seriesId),
      'bookId': serializer.toJson<String?>(bookId),
      'branchId': serializer.toJson<String?>(branchId),
      'changeType': serializer.toJson<String>(changeType),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'eventJson': serializer.toJson<String>(eventJson),
    };
  }

  AuditEventRow copyWith(
          {String? id,
          String? versionId,
          String? entityId,
          String? entityKind,
          String? recordId,
          String? recordType,
          String? projectId,
          Value<String?> seriesId = const Value.absent(),
          Value<String?> bookId = const Value.absent(),
          Value<String?> branchId = const Value.absent(),
          String? changeType,
          DateTime? createdAt,
          String? eventJson}) =>
      AuditEventRow(
        id: id ?? this.id,
        versionId: versionId ?? this.versionId,
        entityId: entityId ?? this.entityId,
        entityKind: entityKind ?? this.entityKind,
        recordId: recordId ?? this.recordId,
        recordType: recordType ?? this.recordType,
        projectId: projectId ?? this.projectId,
        seriesId: seriesId.present ? seriesId.value : this.seriesId,
        bookId: bookId.present ? bookId.value : this.bookId,
        branchId: branchId.present ? branchId.value : this.branchId,
        changeType: changeType ?? this.changeType,
        createdAt: createdAt ?? this.createdAt,
        eventJson: eventJson ?? this.eventJson,
      );
  AuditEventRow copyWithCompanion(AuditEventRowsCompanion data) {
    return AuditEventRow(
      id: data.id.present ? data.id.value : this.id,
      versionId: data.versionId.present ? data.versionId.value : this.versionId,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityKind:
          data.entityKind.present ? data.entityKind.value : this.entityKind,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      recordType:
          data.recordType.present ? data.recordType.value : this.recordType,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      branchId: data.branchId.present ? data.branchId.value : this.branchId,
      changeType:
          data.changeType.present ? data.changeType.value : this.changeType,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      eventJson: data.eventJson.present ? data.eventJson.value : this.eventJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditEventRow(')
          ..write('id: $id, ')
          ..write('versionId: $versionId, ')
          ..write('entityId: $entityId, ')
          ..write('entityKind: $entityKind, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('projectId: $projectId, ')
          ..write('seriesId: $seriesId, ')
          ..write('bookId: $bookId, ')
          ..write('branchId: $branchId, ')
          ..write('changeType: $changeType, ')
          ..write('createdAt: $createdAt, ')
          ..write('eventJson: $eventJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      versionId,
      entityId,
      entityKind,
      recordId,
      recordType,
      projectId,
      seriesId,
      bookId,
      branchId,
      changeType,
      createdAt,
      eventJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditEventRow &&
          other.id == this.id &&
          other.versionId == this.versionId &&
          other.entityId == this.entityId &&
          other.entityKind == this.entityKind &&
          other.recordId == this.recordId &&
          other.recordType == this.recordType &&
          other.projectId == this.projectId &&
          other.seriesId == this.seriesId &&
          other.bookId == this.bookId &&
          other.branchId == this.branchId &&
          other.changeType == this.changeType &&
          other.createdAt == this.createdAt &&
          other.eventJson == this.eventJson);
}

class AuditEventRowsCompanion extends UpdateCompanion<AuditEventRow> {
  final Value<String> id;
  final Value<String> versionId;
  final Value<String> entityId;
  final Value<String> entityKind;
  final Value<String> recordId;
  final Value<String> recordType;
  final Value<String> projectId;
  final Value<String?> seriesId;
  final Value<String?> bookId;
  final Value<String?> branchId;
  final Value<String> changeType;
  final Value<DateTime> createdAt;
  final Value<String> eventJson;
  final Value<int> rowid;
  const AuditEventRowsCompanion({
    this.id = const Value.absent(),
    this.versionId = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityKind = const Value.absent(),
    this.recordId = const Value.absent(),
    this.recordType = const Value.absent(),
    this.projectId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.branchId = const Value.absent(),
    this.changeType = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.eventJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditEventRowsCompanion.insert({
    required String id,
    required String versionId,
    required String entityId,
    required String entityKind,
    required String recordId,
    required String recordType,
    required String projectId,
    this.seriesId = const Value.absent(),
    this.bookId = const Value.absent(),
    this.branchId = const Value.absent(),
    required String changeType,
    required DateTime createdAt,
    required String eventJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        versionId = Value(versionId),
        entityId = Value(entityId),
        entityKind = Value(entityKind),
        recordId = Value(recordId),
        recordType = Value(recordType),
        projectId = Value(projectId),
        changeType = Value(changeType),
        createdAt = Value(createdAt),
        eventJson = Value(eventJson);
  static Insertable<AuditEventRow> custom({
    Expression<String>? id,
    Expression<String>? versionId,
    Expression<String>? entityId,
    Expression<String>? entityKind,
    Expression<String>? recordId,
    Expression<String>? recordType,
    Expression<String>? projectId,
    Expression<String>? seriesId,
    Expression<String>? bookId,
    Expression<String>? branchId,
    Expression<String>? changeType,
    Expression<DateTime>? createdAt,
    Expression<String>? eventJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versionId != null) 'version_id': versionId,
      if (entityId != null) 'entity_id': entityId,
      if (entityKind != null) 'entity_kind': entityKind,
      if (recordId != null) 'record_id': recordId,
      if (recordType != null) 'record_type': recordType,
      if (projectId != null) 'project_id': projectId,
      if (seriesId != null) 'series_id': seriesId,
      if (bookId != null) 'book_id': bookId,
      if (branchId != null) 'branch_id': branchId,
      if (changeType != null) 'change_type': changeType,
      if (createdAt != null) 'created_at': createdAt,
      if (eventJson != null) 'event_json': eventJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditEventRowsCompanion copyWith(
      {Value<String>? id,
      Value<String>? versionId,
      Value<String>? entityId,
      Value<String>? entityKind,
      Value<String>? recordId,
      Value<String>? recordType,
      Value<String>? projectId,
      Value<String?>? seriesId,
      Value<String?>? bookId,
      Value<String?>? branchId,
      Value<String>? changeType,
      Value<DateTime>? createdAt,
      Value<String>? eventJson,
      Value<int>? rowid}) {
    return AuditEventRowsCompanion(
      id: id ?? this.id,
      versionId: versionId ?? this.versionId,
      entityId: entityId ?? this.entityId,
      entityKind: entityKind ?? this.entityKind,
      recordId: recordId ?? this.recordId,
      recordType: recordType ?? this.recordType,
      projectId: projectId ?? this.projectId,
      seriesId: seriesId ?? this.seriesId,
      bookId: bookId ?? this.bookId,
      branchId: branchId ?? this.branchId,
      changeType: changeType ?? this.changeType,
      createdAt: createdAt ?? this.createdAt,
      eventJson: eventJson ?? this.eventJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (versionId.present) {
      map['version_id'] = Variable<String>(versionId.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityKind.present) {
      map['entity_kind'] = Variable<String>(entityKind.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (recordType.present) {
      map['record_type'] = Variable<String>(recordType.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<String>(seriesId.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (branchId.present) {
      map['branch_id'] = Variable<String>(branchId.value);
    }
    if (changeType.present) {
      map['change_type'] = Variable<String>(changeType.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (eventJson.present) {
      map['event_json'] = Variable<String>(eventJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditEventRowsCompanion(')
          ..write('id: $id, ')
          ..write('versionId: $versionId, ')
          ..write('entityId: $entityId, ')
          ..write('entityKind: $entityKind, ')
          ..write('recordId: $recordId, ')
          ..write('recordType: $recordType, ')
          ..write('projectId: $projectId, ')
          ..write('seriesId: $seriesId, ')
          ..write('bookId: $bookId, ')
          ..write('branchId: $branchId, ')
          ..write('changeType: $changeType, ')
          ..write('createdAt: $createdAt, ')
          ..write('eventJson: $eventJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AuthorOsDatabase extends GeneratedDatabase {
  _$AuthorOsDatabase(QueryExecutor e) : super(e);
  $AuthorOsDatabaseManager get managers => $AuthorOsDatabaseManager(this);
  late final $ConnectedEntitiesTable connectedEntities =
      $ConnectedEntitiesTable(this);
  late final $AuthorRecordRowsTable authorRecordRows =
      $AuthorRecordRowsTable(this);
  late final $ManuscriptNodeRowsTable manuscriptNodeRows =
      $ManuscriptNodeRowsTable(this);
  late final $RecordLinkRowsTable recordLinkRows = $RecordLinkRowsTable(this);
  late final $RecordTypeDefinitionRowsTable recordTypeDefinitionRows =
      $RecordTypeDefinitionRowsTable(this);
  late final $ConnectionTypeDefinitionRowsTable connectionTypeDefinitionRows =
      $ConnectionTypeDefinitionRowsTable(this);
  late final $StoryBranchRowsTable storyBranchRows =
      $StoryBranchRowsTable(this);
  late final $BranchRecordOverlayRowsTable branchRecordOverlayRows =
      $BranchRecordOverlayRowsTable(this);
  late final $BranchLinkOverlayRowsTable branchLinkOverlayRows =
      $BranchLinkOverlayRowsTable(this);
  late final $RecordVersionRowsTable recordVersionRows =
      $RecordVersionRowsTable(this);
  late final $AuditEventRowsTable auditEventRows = $AuditEventRowsTable(this);
  late final Index authorRecordsType = Index('author_records_type',
      'CREATE INDEX author_records_type ON author_record_rows (type_id)');
  late final Index authorRecordsScope = Index('author_records_scope',
      'CREATE INDEX author_records_scope ON author_record_rows (scope_id)');
  late final Index authorRecordsProject = Index('author_records_project',
      'CREATE INDEX author_records_project ON author_record_rows (project_id)');
  late final Index authorRecordsSeriesBook = Index('author_records_series_book',
      'CREATE INDEX author_records_series_book ON author_record_rows (series_id, book_id)');
  late final Index authorRecordsBranch = Index('author_records_branch',
      'CREATE INDEX author_records_branch ON author_record_rows (branch_id)');
  late final Index manuscriptNodesProject = Index('manuscript_nodes_project',
      'CREATE INDEX manuscript_nodes_project ON manuscript_node_rows (project_id)');
  late final Index recordLinksSource = Index('record_links_source',
      'CREATE INDEX record_links_source ON record_link_rows (source_id)');
  late final Index recordLinksTarget = Index('record_links_target',
      'CREATE INDEX record_links_target ON record_link_rows (target_id)');
  late final Index recordLinksScope = Index('record_links_scope',
      'CREATE INDEX record_links_scope ON record_link_rows (scope_id)');
  late final Index recordTypeDefinitionsCategory = Index(
      'record_type_definitions_category',
      'CREATE INDEX record_type_definitions_category ON record_type_definition_rows (category_id)');
  late final Index recordTypeDefinitionsScope = Index(
      'record_type_definitions_scope',
      'CREATE INDEX record_type_definitions_scope ON record_type_definition_rows (scope_type, scope_id)');
  late final Index connectionTypeDefinitionsScope = Index(
      'connection_type_definitions_scope',
      'CREATE INDEX connection_type_definitions_scope ON connection_type_definition_rows (scope_id)');
  late final Index storyBranchesProject = Index('story_branches_project',
      'CREATE INDEX story_branches_project ON story_branch_rows (project_id)');
  late final Index storyBranchesParent = Index('story_branches_parent',
      'CREATE INDEX story_branches_parent ON story_branch_rows (parent_branch_id)');
  late final Index branchRecordOverlaysBranch = Index(
      'branch_record_overlays_branch',
      'CREATE INDEX branch_record_overlays_branch ON branch_record_overlay_rows (branch_id)');
  late final Index branchLinkOverlaysBranch = Index(
      'branch_link_overlays_branch',
      'CREATE INDEX branch_link_overlays_branch ON branch_link_overlay_rows (branch_id)');
  late final Index recordVersionsEntity = Index('record_versions_entity',
      'CREATE INDEX record_versions_entity ON record_version_rows (project_id, entity_id)');
  late final Index recordVersionsRecord = Index('record_versions_record',
      'CREATE INDEX record_versions_record ON record_version_rows (project_id, record_id)');
  late final Index recordVersionsBranch = Index('record_versions_branch',
      'CREATE INDEX record_versions_branch ON record_version_rows (project_id, branch_id)');
  late final Index recordVersionsCreated = Index('record_versions_created',
      'CREATE INDEX record_versions_created ON record_version_rows (project_id, created_at)');
  late final Index auditEventsEntity = Index('audit_events_entity',
      'CREATE INDEX audit_events_entity ON audit_event_rows (project_id, entity_id)');
  late final Index auditEventsRecord = Index('audit_events_record',
      'CREATE INDEX audit_events_record ON audit_event_rows (project_id, record_id)');
  late final Index auditEventsSeriesBook = Index('audit_events_series_book',
      'CREATE INDEX audit_events_series_book ON audit_event_rows (project_id, series_id, book_id)');
  late final Index auditEventsBranch = Index('audit_events_branch',
      'CREATE INDEX audit_events_branch ON audit_event_rows (project_id, branch_id)');
  late final Index auditEventsChange = Index('audit_events_change',
      'CREATE INDEX audit_events_change ON audit_event_rows (project_id, change_type)');
  late final Index auditEventsCreated = Index('audit_events_created',
      'CREATE INDEX audit_events_created ON audit_event_rows (project_id, created_at)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        connectedEntities,
        authorRecordRows,
        manuscriptNodeRows,
        recordLinkRows,
        recordTypeDefinitionRows,
        connectionTypeDefinitionRows,
        storyBranchRows,
        branchRecordOverlayRows,
        branchLinkOverlayRows,
        recordVersionRows,
        auditEventRows,
        authorRecordsType,
        authorRecordsScope,
        authorRecordsProject,
        authorRecordsSeriesBook,
        authorRecordsBranch,
        manuscriptNodesProject,
        recordLinksSource,
        recordLinksTarget,
        recordLinksScope,
        recordTypeDefinitionsCategory,
        recordTypeDefinitionsScope,
        connectionTypeDefinitionsScope,
        storyBranchesProject,
        storyBranchesParent,
        branchRecordOverlaysBranch,
        branchLinkOverlaysBranch,
        recordVersionsEntity,
        recordVersionsRecord,
        recordVersionsBranch,
        recordVersionsCreated,
        auditEventsEntity,
        auditEventsRecord,
        auditEventsSeriesBook,
        auditEventsBranch,
        auditEventsChange,
        auditEventsCreated
      ];
}

typedef $$ConnectedEntitiesTableCreateCompanionBuilder
    = ConnectedEntitiesCompanion Function({
  required String id,
  required String kind,
  required String scopeId,
  Value<int> rowid,
});
typedef $$ConnectedEntitiesTableUpdateCompanionBuilder
    = ConnectedEntitiesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String> scopeId,
  Value<int> rowid,
});

final class $$ConnectedEntitiesTableReferences extends BaseReferences<
    _$AuthorOsDatabase, $ConnectedEntitiesTable, ConnectedEntity> {
  $$ConnectedEntitiesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AuthorRecordRowsTable, List<AuthorRecordRow>>
      _authorRecordRowsRefsTable(_$AuthorOsDatabase db) =>
          MultiTypedResultKey.fromTable(db.authorRecordRows,
              aliasName: 'connected_entities__id__author_record_rows__id');

  $$AuthorRecordRowsTableProcessedTableManager get authorRecordRowsRefs {
    final manager =
        $$AuthorRecordRowsTableTableManager($_db, $_db.authorRecordRows)
            .filter((f) => f.id.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_authorRecordRowsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ManuscriptNodeRowsTable, List<ManuscriptNodeRow>>
      _manuscriptNodeRowsRefsTable(_$AuthorOsDatabase db) =>
          MultiTypedResultKey.fromTable(db.manuscriptNodeRows,
              aliasName: 'connected_entities__id__manuscript_node_rows__id');

  $$ManuscriptNodeRowsTableProcessedTableManager get manuscriptNodeRowsRefs {
    final manager =
        $$ManuscriptNodeRowsTableTableManager($_db, $_db.manuscriptNodeRows)
            .filter((f) => f.id.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_manuscriptNodeRowsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$RecordLinkRowsTable, List<RecordLinkRow>>
      _sourceLinksTable(_$AuthorOsDatabase db) =>
          MultiTypedResultKey.fromTable(db.recordLinkRows,
              aliasName: 'connected_entities__id__record_link_rows__source_id');

  $$RecordLinkRowsTableProcessedTableManager get sourceLinks {
    final manager = $$RecordLinkRowsTableTableManager($_db, $_db.recordLinkRows)
        .filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourceLinksTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$RecordLinkRowsTable, List<RecordLinkRow>>
      _targetLinksTable(_$AuthorOsDatabase db) =>
          MultiTypedResultKey.fromTable(db.recordLinkRows,
              aliasName: 'connected_entities__id__record_link_rows__target_id');

  $$RecordLinkRowsTableProcessedTableManager get targetLinks {
    final manager = $$RecordLinkRowsTableTableManager($_db, $_db.recordLinkRows)
        .filter((f) => f.targetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_targetLinksTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ConnectedEntitiesTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $ConnectedEntitiesTable> {
  $$ConnectedEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnFilters(column));

  Expression<bool> authorRecordRowsRefs(
      Expression<bool> Function($$AuthorRecordRowsTableFilterComposer f) f) {
    final $$AuthorRecordRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.authorRecordRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AuthorRecordRowsTableFilterComposer(
              $db: $db,
              $table: $db.authorRecordRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> manuscriptNodeRowsRefs(
      Expression<bool> Function($$ManuscriptNodeRowsTableFilterComposer f) f) {
    final $$ManuscriptNodeRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.manuscriptNodeRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ManuscriptNodeRowsTableFilterComposer(
              $db: $db,
              $table: $db.manuscriptNodeRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> sourceLinks(
      Expression<bool> Function($$RecordLinkRowsTableFilterComposer f) f) {
    final $$RecordLinkRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordLinkRows,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordLinkRowsTableFilterComposer(
              $db: $db,
              $table: $db.recordLinkRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> targetLinks(
      Expression<bool> Function($$RecordLinkRowsTableFilterComposer f) f) {
    final $$RecordLinkRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordLinkRows,
        getReferencedColumn: (t) => t.targetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordLinkRowsTableFilterComposer(
              $db: $db,
              $table: $db.recordLinkRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ConnectedEntitiesTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $ConnectedEntitiesTable> {
  $$ConnectedEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnOrderings(column));
}

class $$ConnectedEntitiesTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $ConnectedEntitiesTable> {
  $$ConnectedEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  Expression<T> authorRecordRowsRefs<T extends Object>(
      Expression<T> Function($$AuthorRecordRowsTableAnnotationComposer a) f) {
    final $$AuthorRecordRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.authorRecordRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$AuthorRecordRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.authorRecordRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> manuscriptNodeRowsRefs<T extends Object>(
      Expression<T> Function($$ManuscriptNodeRowsTableAnnotationComposer a) f) {
    final $$ManuscriptNodeRowsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.manuscriptNodeRows,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ManuscriptNodeRowsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.manuscriptNodeRows,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> sourceLinks<T extends Object>(
      Expression<T> Function($$RecordLinkRowsTableAnnotationComposer a) f) {
    final $$RecordLinkRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordLinkRows,
        getReferencedColumn: (t) => t.sourceId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordLinkRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.recordLinkRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> targetLinks<T extends Object>(
      Expression<T> Function($$RecordLinkRowsTableAnnotationComposer a) f) {
    final $$RecordLinkRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recordLinkRows,
        getReferencedColumn: (t) => t.targetId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecordLinkRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.recordLinkRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ConnectedEntitiesTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $ConnectedEntitiesTable,
    ConnectedEntity,
    $$ConnectedEntitiesTableFilterComposer,
    $$ConnectedEntitiesTableOrderingComposer,
    $$ConnectedEntitiesTableAnnotationComposer,
    $$ConnectedEntitiesTableCreateCompanionBuilder,
    $$ConnectedEntitiesTableUpdateCompanionBuilder,
    (ConnectedEntity, $$ConnectedEntitiesTableReferences),
    ConnectedEntity,
    PrefetchHooks Function(
        {bool authorRecordRowsRefs,
        bool manuscriptNodeRowsRefs,
        bool sourceLinks,
        bool targetLinks})> {
  $$ConnectedEntitiesTableTableManager(
      _$AuthorOsDatabase db, $ConnectedEntitiesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectedEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectedEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectedEntitiesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> scopeId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConnectedEntitiesCompanion(
            id: id,
            kind: kind,
            scopeId: scopeId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String kind,
            required String scopeId,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConnectedEntitiesCompanion.insert(
            id: id,
            kind: kind,
            scopeId: scopeId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ConnectedEntitiesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {authorRecordRowsRefs = false,
              manuscriptNodeRowsRefs = false,
              sourceLinks = false,
              targetLinks = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (authorRecordRowsRefs) db.authorRecordRows,
                if (manuscriptNodeRowsRefs) db.manuscriptNodeRows,
                if (sourceLinks) db.recordLinkRows,
                if (targetLinks) db.recordLinkRows
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (authorRecordRowsRefs)
                    await $_getPrefetchedData<ConnectedEntity,
                            $ConnectedEntitiesTable, AuthorRecordRow>(
                        currentTable: table,
                        referencedTable: $$ConnectedEntitiesTableReferences
                            ._authorRecordRowsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConnectedEntitiesTableReferences(db, table, p0)
                                .authorRecordRowsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) =>
                                referencedItems.where((e) => e.id == item.id),
                        typedResults: items),
                  if (manuscriptNodeRowsRefs)
                    await $_getPrefetchedData<ConnectedEntity,
                            $ConnectedEntitiesTable, ManuscriptNodeRow>(
                        currentTable: table,
                        referencedTable: $$ConnectedEntitiesTableReferences
                            ._manuscriptNodeRowsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConnectedEntitiesTableReferences(db, table, p0)
                                .manuscriptNodeRowsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) =>
                                referencedItems.where((e) => e.id == item.id),
                        typedResults: items),
                  if (sourceLinks)
                    await $_getPrefetchedData<ConnectedEntity,
                            $ConnectedEntitiesTable, RecordLinkRow>(
                        currentTable: table,
                        referencedTable: $$ConnectedEntitiesTableReferences
                            ._sourceLinksTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConnectedEntitiesTableReferences(db, table, p0)
                                .sourceLinks,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.sourceId == item.id),
                        typedResults: items),
                  if (targetLinks)
                    await $_getPrefetchedData<ConnectedEntity,
                            $ConnectedEntitiesTable, RecordLinkRow>(
                        currentTable: table,
                        referencedTable: $$ConnectedEntitiesTableReferences
                            ._targetLinksTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ConnectedEntitiesTableReferences(db, table, p0)
                                .targetLinks,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.targetId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ConnectedEntitiesTableProcessedTableManager = ProcessedTableManager<
    _$AuthorOsDatabase,
    $ConnectedEntitiesTable,
    ConnectedEntity,
    $$ConnectedEntitiesTableFilterComposer,
    $$ConnectedEntitiesTableOrderingComposer,
    $$ConnectedEntitiesTableAnnotationComposer,
    $$ConnectedEntitiesTableCreateCompanionBuilder,
    $$ConnectedEntitiesTableUpdateCompanionBuilder,
    (ConnectedEntity, $$ConnectedEntitiesTableReferences),
    ConnectedEntity,
    PrefetchHooks Function(
        {bool authorRecordRowsRefs,
        bool manuscriptNodeRowsRefs,
        bool sourceLinks,
        bool targetLinks})>;
typedef $$AuthorRecordRowsTableCreateCompanionBuilder
    = AuthorRecordRowsCompanion Function({
  required String id,
  required String typeId,
  required String scopeType,
  required String scopeId,
  Value<String?> projectId,
  Value<String?> seriesId,
  Value<String?> bookId,
  Value<String?> branchId,
  Value<String?> canonStatus,
  required String title,
  required String status,
  required int schemaVersion,
  Value<String?> templateId,
  Value<int?> templateVersion,
  required int revision,
  required String fieldsJson,
  required String tagsJson,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String extensionJson,
  Value<int> rowid,
});
typedef $$AuthorRecordRowsTableUpdateCompanionBuilder
    = AuthorRecordRowsCompanion Function({
  Value<String> id,
  Value<String> typeId,
  Value<String> scopeType,
  Value<String> scopeId,
  Value<String?> projectId,
  Value<String?> seriesId,
  Value<String?> bookId,
  Value<String?> branchId,
  Value<String?> canonStatus,
  Value<String> title,
  Value<String> status,
  Value<int> schemaVersion,
  Value<String?> templateId,
  Value<int?> templateVersion,
  Value<int> revision,
  Value<String> fieldsJson,
  Value<String> tagsJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> extensionJson,
  Value<int> rowid,
});

final class $$AuthorRecordRowsTableReferences extends BaseReferences<
    _$AuthorOsDatabase, $AuthorRecordRowsTable, AuthorRecordRow> {
  $$AuthorRecordRowsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ConnectedEntitiesTable _idTable(_$AuthorOsDatabase db) =>
      db.connectedEntities
          .createAlias('author_record_rows__id__connected_entities__id');

  $$ConnectedEntitiesTableProcessedTableManager get id {
    final $_column = $_itemColumn<String>('id')!;

    final manager =
        $$ConnectedEntitiesTableTableManager($_db, $_db.connectedEntities)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_idTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AuthorRecordRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $AuthorRecordRowsTable> {
  $$AuthorRecordRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeType => $composableBuilder(
      column: $table.scopeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seriesId => $composableBuilder(
      column: $table.seriesId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get canonStatus => $composableBuilder(
      column: $table.canonStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get templateVersion => $composableBuilder(
      column: $table.templateVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fieldsJson => $composableBuilder(
      column: $table.fieldsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagsJson => $composableBuilder(
      column: $table.tagsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson, builder: (column) => ColumnFilters(column));

  $$ConnectedEntitiesTableFilterComposer get id {
    final $$ConnectedEntitiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableFilterComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AuthorRecordRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $AuthorRecordRowsTable> {
  $$AuthorRecordRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeType => $composableBuilder(
      column: $table.scopeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seriesId => $composableBuilder(
      column: $table.seriesId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get canonStatus => $composableBuilder(
      column: $table.canonStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get templateVersion => $composableBuilder(
      column: $table.templateVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fieldsJson => $composableBuilder(
      column: $table.fieldsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagsJson => $composableBuilder(
      column: $table.tagsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson,
      builder: (column) => ColumnOrderings(column));

  $$ConnectedEntitiesTableOrderingComposer get id {
    final $$ConnectedEntitiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableOrderingComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$AuthorRecordRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $AuthorRecordRowsTable> {
  $$AuthorRecordRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<String> get scopeType =>
      $composableBuilder(column: $table.scopeType, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get canonStatus => $composableBuilder(
      column: $table.canonStatus, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => column);

  GeneratedColumn<int> get templateVersion => $composableBuilder(
      column: $table.templateVersion, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get fieldsJson => $composableBuilder(
      column: $table.fieldsJson, builder: (column) => column);

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson, builder: (column) => column);

  $$ConnectedEntitiesTableAnnotationComposer get id {
    final $$ConnectedEntitiesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.connectedEntities,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ConnectedEntitiesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.connectedEntities,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$AuthorRecordRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $AuthorRecordRowsTable,
    AuthorRecordRow,
    $$AuthorRecordRowsTableFilterComposer,
    $$AuthorRecordRowsTableOrderingComposer,
    $$AuthorRecordRowsTableAnnotationComposer,
    $$AuthorRecordRowsTableCreateCompanionBuilder,
    $$AuthorRecordRowsTableUpdateCompanionBuilder,
    (AuthorRecordRow, $$AuthorRecordRowsTableReferences),
    AuthorRecordRow,
    PrefetchHooks Function({bool id})> {
  $$AuthorRecordRowsTableTableManager(
      _$AuthorOsDatabase db, $AuthorRecordRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuthorRecordRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuthorRecordRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuthorRecordRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> typeId = const Value.absent(),
            Value<String> scopeType = const Value.absent(),
            Value<String> scopeId = const Value.absent(),
            Value<String?> projectId = const Value.absent(),
            Value<String?> seriesId = const Value.absent(),
            Value<String?> bookId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<String?> canonStatus = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> schemaVersion = const Value.absent(),
            Value<String?> templateId = const Value.absent(),
            Value<int?> templateVersion = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> fieldsJson = const Value.absent(),
            Value<String> tagsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> extensionJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AuthorRecordRowsCompanion(
            id: id,
            typeId: typeId,
            scopeType: scopeType,
            scopeId: scopeId,
            projectId: projectId,
            seriesId: seriesId,
            bookId: bookId,
            branchId: branchId,
            canonStatus: canonStatus,
            title: title,
            status: status,
            schemaVersion: schemaVersion,
            templateId: templateId,
            templateVersion: templateVersion,
            revision: revision,
            fieldsJson: fieldsJson,
            tagsJson: tagsJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            extensionJson: extensionJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String typeId,
            required String scopeType,
            required String scopeId,
            Value<String?> projectId = const Value.absent(),
            Value<String?> seriesId = const Value.absent(),
            Value<String?> bookId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<String?> canonStatus = const Value.absent(),
            required String title,
            required String status,
            required int schemaVersion,
            Value<String?> templateId = const Value.absent(),
            Value<int?> templateVersion = const Value.absent(),
            required int revision,
            required String fieldsJson,
            required String tagsJson,
            required DateTime createdAt,
            required DateTime updatedAt,
            required String extensionJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              AuthorRecordRowsCompanion.insert(
            id: id,
            typeId: typeId,
            scopeType: scopeType,
            scopeId: scopeId,
            projectId: projectId,
            seriesId: seriesId,
            bookId: bookId,
            branchId: branchId,
            canonStatus: canonStatus,
            title: title,
            status: status,
            schemaVersion: schemaVersion,
            templateId: templateId,
            templateVersion: templateVersion,
            revision: revision,
            fieldsJson: fieldsJson,
            tagsJson: tagsJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            extensionJson: extensionJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$AuthorRecordRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({id = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.id,
                    referencedTable:
                        $$AuthorRecordRowsTableReferences._idTable(db),
                    referencedColumn:
                        $$AuthorRecordRowsTableReferences._idTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$AuthorRecordRowsTableProcessedTableManager = ProcessedTableManager<
    _$AuthorOsDatabase,
    $AuthorRecordRowsTable,
    AuthorRecordRow,
    $$AuthorRecordRowsTableFilterComposer,
    $$AuthorRecordRowsTableOrderingComposer,
    $$AuthorRecordRowsTableAnnotationComposer,
    $$AuthorRecordRowsTableCreateCompanionBuilder,
    $$AuthorRecordRowsTableUpdateCompanionBuilder,
    (AuthorRecordRow, $$AuthorRecordRowsTableReferences),
    AuthorRecordRow,
    PrefetchHooks Function({bool id})>;
typedef $$ManuscriptNodeRowsTableCreateCompanionBuilder
    = ManuscriptNodeRowsCompanion Function({
  required String id,
  required String projectId,
  required String nodeType,
  required String title,
  required int revision,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String extensionJson,
  Value<int> rowid,
});
typedef $$ManuscriptNodeRowsTableUpdateCompanionBuilder
    = ManuscriptNodeRowsCompanion Function({
  Value<String> id,
  Value<String> projectId,
  Value<String> nodeType,
  Value<String> title,
  Value<int> revision,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> extensionJson,
  Value<int> rowid,
});

final class $$ManuscriptNodeRowsTableReferences extends BaseReferences<
    _$AuthorOsDatabase, $ManuscriptNodeRowsTable, ManuscriptNodeRow> {
  $$ManuscriptNodeRowsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ConnectedEntitiesTable _idTable(_$AuthorOsDatabase db) =>
      db.connectedEntities
          .createAlias('manuscript_node_rows__id__connected_entities__id');

  $$ConnectedEntitiesTableProcessedTableManager get id {
    final $_column = $_itemColumn<String>('id')!;

    final manager =
        $$ConnectedEntitiesTableTableManager($_db, $_db.connectedEntities)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_idTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ManuscriptNodeRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $ManuscriptNodeRowsTable> {
  $$ManuscriptNodeRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeType => $composableBuilder(
      column: $table.nodeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson, builder: (column) => ColumnFilters(column));

  $$ConnectedEntitiesTableFilterComposer get id {
    final $$ConnectedEntitiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableFilterComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ManuscriptNodeRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $ManuscriptNodeRowsTable> {
  $$ManuscriptNodeRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeType => $composableBuilder(
      column: $table.nodeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson,
      builder: (column) => ColumnOrderings(column));

  $$ConnectedEntitiesTableOrderingComposer get id {
    final $$ConnectedEntitiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableOrderingComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ManuscriptNodeRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $ManuscriptNodeRowsTable> {
  $$ManuscriptNodeRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get nodeType =>
      $composableBuilder(column: $table.nodeType, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson, builder: (column) => column);

  $$ConnectedEntitiesTableAnnotationComposer get id {
    final $$ConnectedEntitiesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.connectedEntities,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ConnectedEntitiesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.connectedEntities,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$ManuscriptNodeRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $ManuscriptNodeRowsTable,
    ManuscriptNodeRow,
    $$ManuscriptNodeRowsTableFilterComposer,
    $$ManuscriptNodeRowsTableOrderingComposer,
    $$ManuscriptNodeRowsTableAnnotationComposer,
    $$ManuscriptNodeRowsTableCreateCompanionBuilder,
    $$ManuscriptNodeRowsTableUpdateCompanionBuilder,
    (ManuscriptNodeRow, $$ManuscriptNodeRowsTableReferences),
    ManuscriptNodeRow,
    PrefetchHooks Function({bool id})> {
  $$ManuscriptNodeRowsTableTableManager(
      _$AuthorOsDatabase db, $ManuscriptNodeRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ManuscriptNodeRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ManuscriptNodeRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ManuscriptNodeRowsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String> nodeType = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> extensionJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ManuscriptNodeRowsCompanion(
            id: id,
            projectId: projectId,
            nodeType: nodeType,
            title: title,
            revision: revision,
            createdAt: createdAt,
            updatedAt: updatedAt,
            extensionJson: extensionJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            required String nodeType,
            required String title,
            required int revision,
            required DateTime createdAt,
            required DateTime updatedAt,
            required String extensionJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              ManuscriptNodeRowsCompanion.insert(
            id: id,
            projectId: projectId,
            nodeType: nodeType,
            title: title,
            revision: revision,
            createdAt: createdAt,
            updatedAt: updatedAt,
            extensionJson: extensionJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ManuscriptNodeRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({id = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (id) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.id,
                    referencedTable:
                        $$ManuscriptNodeRowsTableReferences._idTable(db),
                    referencedColumn:
                        $$ManuscriptNodeRowsTableReferences._idTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ManuscriptNodeRowsTableProcessedTableManager = ProcessedTableManager<
    _$AuthorOsDatabase,
    $ManuscriptNodeRowsTable,
    ManuscriptNodeRow,
    $$ManuscriptNodeRowsTableFilterComposer,
    $$ManuscriptNodeRowsTableOrderingComposer,
    $$ManuscriptNodeRowsTableAnnotationComposer,
    $$ManuscriptNodeRowsTableCreateCompanionBuilder,
    $$ManuscriptNodeRowsTableUpdateCompanionBuilder,
    (ManuscriptNodeRow, $$ManuscriptNodeRowsTableReferences),
    ManuscriptNodeRow,
    PrefetchHooks Function({bool id})>;
typedef $$RecordLinkRowsTableCreateCompanionBuilder = RecordLinkRowsCompanion
    Function({
  required String id,
  required String sourceId,
  required String targetId,
  required String typeId,
  required String scopeId,
  required String direction,
  required String label,
  required int revision,
  required String metadataJson,
  required DateTime createdAt,
  required DateTime updatedAt,
  required String extensionJson,
  Value<int> rowid,
});
typedef $$RecordLinkRowsTableUpdateCompanionBuilder = RecordLinkRowsCompanion
    Function({
  Value<String> id,
  Value<String> sourceId,
  Value<String> targetId,
  Value<String> typeId,
  Value<String> scopeId,
  Value<String> direction,
  Value<String> label,
  Value<int> revision,
  Value<String> metadataJson,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<String> extensionJson,
  Value<int> rowid,
});

final class $$RecordLinkRowsTableReferences extends BaseReferences<
    _$AuthorOsDatabase, $RecordLinkRowsTable, RecordLinkRow> {
  $$RecordLinkRowsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $ConnectedEntitiesTable _sourceIdTable(_$AuthorOsDatabase db) =>
      db.connectedEntities
          .createAlias('record_link_rows__source_id__connected_entities__id');

  $$ConnectedEntitiesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager =
        $$ConnectedEntitiesTableTableManager($_db, $_db.connectedEntities)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ConnectedEntitiesTable _targetIdTable(_$AuthorOsDatabase db) =>
      db.connectedEntities
          .createAlias('record_link_rows__target_id__connected_entities__id');

  $$ConnectedEntitiesTableProcessedTableManager get targetId {
    final $_column = $_itemColumn<String>('target_id')!;

    final manager =
        $$ConnectedEntitiesTableTableManager($_db, $_db.connectedEntities)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RecordLinkRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $RecordLinkRowsTable> {
  $$RecordLinkRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson, builder: (column) => ColumnFilters(column));

  $$ConnectedEntitiesTableFilterComposer get sourceId {
    final $$ConnectedEntitiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableFilterComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ConnectedEntitiesTableFilterComposer get targetId {
    final $$ConnectedEntitiesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.targetId,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableFilterComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecordLinkRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $RecordLinkRowsTable> {
  $$RecordLinkRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get typeId => $composableBuilder(
      column: $table.typeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get direction => $composableBuilder(
      column: $table.direction, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision => $composableBuilder(
      column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson,
      builder: (column) => ColumnOrderings(column));

  $$ConnectedEntitiesTableOrderingComposer get sourceId {
    final $$ConnectedEntitiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sourceId,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableOrderingComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ConnectedEntitiesTableOrderingComposer get targetId {
    final $$ConnectedEntitiesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.targetId,
        referencedTable: $db.connectedEntities,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ConnectedEntitiesTableOrderingComposer(
              $db: $db,
              $table: $db.connectedEntities,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecordLinkRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $RecordLinkRowsTable> {
  $$RecordLinkRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get typeId =>
      $composableBuilder(column: $table.typeId, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
      column: $table.metadataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get extensionJson => $composableBuilder(
      column: $table.extensionJson, builder: (column) => column);

  $$ConnectedEntitiesTableAnnotationComposer get sourceId {
    final $$ConnectedEntitiesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.sourceId,
            referencedTable: $db.connectedEntities,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ConnectedEntitiesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.connectedEntities,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }

  $$ConnectedEntitiesTableAnnotationComposer get targetId {
    final $$ConnectedEntitiesTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.targetId,
            referencedTable: $db.connectedEntities,
            getReferencedColumn: (t) => t.id,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$ConnectedEntitiesTableAnnotationComposer(
                  $db: $db,
                  $table: $db.connectedEntities,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return composer;
  }
}

class $$RecordLinkRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $RecordLinkRowsTable,
    RecordLinkRow,
    $$RecordLinkRowsTableFilterComposer,
    $$RecordLinkRowsTableOrderingComposer,
    $$RecordLinkRowsTableAnnotationComposer,
    $$RecordLinkRowsTableCreateCompanionBuilder,
    $$RecordLinkRowsTableUpdateCompanionBuilder,
    (RecordLinkRow, $$RecordLinkRowsTableReferences),
    RecordLinkRow,
    PrefetchHooks Function({bool sourceId, bool targetId})> {
  $$RecordLinkRowsTableTableManager(
      _$AuthorOsDatabase db, $RecordLinkRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordLinkRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordLinkRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordLinkRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sourceId = const Value.absent(),
            Value<String> targetId = const Value.absent(),
            Value<String> typeId = const Value.absent(),
            Value<String> scopeId = const Value.absent(),
            Value<String> direction = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<int> revision = const Value.absent(),
            Value<String> metadataJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> extensionJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordLinkRowsCompanion(
            id: id,
            sourceId: sourceId,
            targetId: targetId,
            typeId: typeId,
            scopeId: scopeId,
            direction: direction,
            label: label,
            revision: revision,
            metadataJson: metadataJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            extensionJson: extensionJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sourceId,
            required String targetId,
            required String typeId,
            required String scopeId,
            required String direction,
            required String label,
            required int revision,
            required String metadataJson,
            required DateTime createdAt,
            required DateTime updatedAt,
            required String extensionJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordLinkRowsCompanion.insert(
            id: id,
            sourceId: sourceId,
            targetId: targetId,
            typeId: typeId,
            scopeId: scopeId,
            direction: direction,
            label: label,
            revision: revision,
            metadataJson: metadataJson,
            createdAt: createdAt,
            updatedAt: updatedAt,
            extensionJson: extensionJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RecordLinkRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sourceId = false, targetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sourceId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sourceId,
                    referencedTable:
                        $$RecordLinkRowsTableReferences._sourceIdTable(db),
                    referencedColumn:
                        $$RecordLinkRowsTableReferences._sourceIdTable(db).id,
                  ) as T;
                }
                if (targetId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.targetId,
                    referencedTable:
                        $$RecordLinkRowsTableReferences._targetIdTable(db),
                    referencedColumn:
                        $$RecordLinkRowsTableReferences._targetIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RecordLinkRowsTableProcessedTableManager = ProcessedTableManager<
    _$AuthorOsDatabase,
    $RecordLinkRowsTable,
    RecordLinkRow,
    $$RecordLinkRowsTableFilterComposer,
    $$RecordLinkRowsTableOrderingComposer,
    $$RecordLinkRowsTableAnnotationComposer,
    $$RecordLinkRowsTableCreateCompanionBuilder,
    $$RecordLinkRowsTableUpdateCompanionBuilder,
    (RecordLinkRow, $$RecordLinkRowsTableReferences),
    RecordLinkRow,
    PrefetchHooks Function({bool sourceId, bool targetId})>;
typedef $$RecordTypeDefinitionRowsTableCreateCompanionBuilder
    = RecordTypeDefinitionRowsCompanion Function({
  required String id,
  required String name,
  required String categoryId,
  Value<String?> baseTypeId,
  required String scopeType,
  required String scopeId,
  required int templateVersion,
  required bool builtIn,
  required String definitionJson,
  Value<int> rowid,
});
typedef $$RecordTypeDefinitionRowsTableUpdateCompanionBuilder
    = RecordTypeDefinitionRowsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> categoryId,
  Value<String?> baseTypeId,
  Value<String> scopeType,
  Value<String> scopeId,
  Value<int> templateVersion,
  Value<bool> builtIn,
  Value<String> definitionJson,
  Value<int> rowid,
});

class $$RecordTypeDefinitionRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $RecordTypeDefinitionRowsTable> {
  $$RecordTypeDefinitionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get baseTypeId => $composableBuilder(
      column: $table.baseTypeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeType => $composableBuilder(
      column: $table.scopeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get templateVersion => $composableBuilder(
      column: $table.templateVersion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get builtIn => $composableBuilder(
      column: $table.builtIn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get definitionJson => $composableBuilder(
      column: $table.definitionJson,
      builder: (column) => ColumnFilters(column));
}

class $$RecordTypeDefinitionRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $RecordTypeDefinitionRowsTable> {
  $$RecordTypeDefinitionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get baseTypeId => $composableBuilder(
      column: $table.baseTypeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeType => $composableBuilder(
      column: $table.scopeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get templateVersion => $composableBuilder(
      column: $table.templateVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get builtIn => $composableBuilder(
      column: $table.builtIn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get definitionJson => $composableBuilder(
      column: $table.definitionJson,
      builder: (column) => ColumnOrderings(column));
}

class $$RecordTypeDefinitionRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $RecordTypeDefinitionRowsTable> {
  $$RecordTypeDefinitionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get baseTypeId => $composableBuilder(
      column: $table.baseTypeId, builder: (column) => column);

  GeneratedColumn<String> get scopeType =>
      $composableBuilder(column: $table.scopeType, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<int> get templateVersion => $composableBuilder(
      column: $table.templateVersion, builder: (column) => column);

  GeneratedColumn<bool> get builtIn =>
      $composableBuilder(column: $table.builtIn, builder: (column) => column);

  GeneratedColumn<String> get definitionJson => $composableBuilder(
      column: $table.definitionJson, builder: (column) => column);
}

class $$RecordTypeDefinitionRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $RecordTypeDefinitionRowsTable,
    RecordTypeDefinitionRow,
    $$RecordTypeDefinitionRowsTableFilterComposer,
    $$RecordTypeDefinitionRowsTableOrderingComposer,
    $$RecordTypeDefinitionRowsTableAnnotationComposer,
    $$RecordTypeDefinitionRowsTableCreateCompanionBuilder,
    $$RecordTypeDefinitionRowsTableUpdateCompanionBuilder,
    (
      RecordTypeDefinitionRow,
      BaseReferences<_$AuthorOsDatabase, $RecordTypeDefinitionRowsTable,
          RecordTypeDefinitionRow>
    ),
    RecordTypeDefinitionRow,
    PrefetchHooks Function()> {
  $$RecordTypeDefinitionRowsTableTableManager(
      _$AuthorOsDatabase db, $RecordTypeDefinitionRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordTypeDefinitionRowsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordTypeDefinitionRowsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordTypeDefinitionRowsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> categoryId = const Value.absent(),
            Value<String?> baseTypeId = const Value.absent(),
            Value<String> scopeType = const Value.absent(),
            Value<String> scopeId = const Value.absent(),
            Value<int> templateVersion = const Value.absent(),
            Value<bool> builtIn = const Value.absent(),
            Value<String> definitionJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordTypeDefinitionRowsCompanion(
            id: id,
            name: name,
            categoryId: categoryId,
            baseTypeId: baseTypeId,
            scopeType: scopeType,
            scopeId: scopeId,
            templateVersion: templateVersion,
            builtIn: builtIn,
            definitionJson: definitionJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String categoryId,
            Value<String?> baseTypeId = const Value.absent(),
            required String scopeType,
            required String scopeId,
            required int templateVersion,
            required bool builtIn,
            required String definitionJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordTypeDefinitionRowsCompanion.insert(
            id: id,
            name: name,
            categoryId: categoryId,
            baseTypeId: baseTypeId,
            scopeType: scopeType,
            scopeId: scopeId,
            templateVersion: templateVersion,
            builtIn: builtIn,
            definitionJson: definitionJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecordTypeDefinitionRowsTableProcessedTableManager
    = ProcessedTableManager<
        _$AuthorOsDatabase,
        $RecordTypeDefinitionRowsTable,
        RecordTypeDefinitionRow,
        $$RecordTypeDefinitionRowsTableFilterComposer,
        $$RecordTypeDefinitionRowsTableOrderingComposer,
        $$RecordTypeDefinitionRowsTableAnnotationComposer,
        $$RecordTypeDefinitionRowsTableCreateCompanionBuilder,
        $$RecordTypeDefinitionRowsTableUpdateCompanionBuilder,
        (
          RecordTypeDefinitionRow,
          BaseReferences<_$AuthorOsDatabase, $RecordTypeDefinitionRowsTable,
              RecordTypeDefinitionRow>
        ),
        RecordTypeDefinitionRow,
        PrefetchHooks Function()>;
typedef $$ConnectionTypeDefinitionRowsTableCreateCompanionBuilder
    = ConnectionTypeDefinitionRowsCompanion Function({
  required String id,
  required String displayName,
  required String scopeId,
  required bool builtIn,
  required String definitionJson,
  Value<int> rowid,
});
typedef $$ConnectionTypeDefinitionRowsTableUpdateCompanionBuilder
    = ConnectionTypeDefinitionRowsCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<String> scopeId,
  Value<bool> builtIn,
  Value<String> definitionJson,
  Value<int> rowid,
});

class $$ConnectionTypeDefinitionRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $ConnectionTypeDefinitionRowsTable> {
  $$ConnectionTypeDefinitionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get builtIn => $composableBuilder(
      column: $table.builtIn, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get definitionJson => $composableBuilder(
      column: $table.definitionJson,
      builder: (column) => ColumnFilters(column));
}

class $$ConnectionTypeDefinitionRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $ConnectionTypeDefinitionRowsTable> {
  $$ConnectionTypeDefinitionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scopeId => $composableBuilder(
      column: $table.scopeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get builtIn => $composableBuilder(
      column: $table.builtIn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get definitionJson => $composableBuilder(
      column: $table.definitionJson,
      builder: (column) => ColumnOrderings(column));
}

class $$ConnectionTypeDefinitionRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $ConnectionTypeDefinitionRowsTable> {
  $$ConnectionTypeDefinitionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
      column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<bool> get builtIn =>
      $composableBuilder(column: $table.builtIn, builder: (column) => column);

  GeneratedColumn<String> get definitionJson => $composableBuilder(
      column: $table.definitionJson, builder: (column) => column);
}

class $$ConnectionTypeDefinitionRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $ConnectionTypeDefinitionRowsTable,
    ConnectionTypeDefinitionRow,
    $$ConnectionTypeDefinitionRowsTableFilterComposer,
    $$ConnectionTypeDefinitionRowsTableOrderingComposer,
    $$ConnectionTypeDefinitionRowsTableAnnotationComposer,
    $$ConnectionTypeDefinitionRowsTableCreateCompanionBuilder,
    $$ConnectionTypeDefinitionRowsTableUpdateCompanionBuilder,
    (
      ConnectionTypeDefinitionRow,
      BaseReferences<_$AuthorOsDatabase, $ConnectionTypeDefinitionRowsTable,
          ConnectionTypeDefinitionRow>
    ),
    ConnectionTypeDefinitionRow,
    PrefetchHooks Function()> {
  $$ConnectionTypeDefinitionRowsTableTableManager(
      _$AuthorOsDatabase db, $ConnectionTypeDefinitionRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectionTypeDefinitionRowsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectionTypeDefinitionRowsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectionTypeDefinitionRowsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> displayName = const Value.absent(),
            Value<String> scopeId = const Value.absent(),
            Value<bool> builtIn = const Value.absent(),
            Value<String> definitionJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ConnectionTypeDefinitionRowsCompanion(
            id: id,
            displayName: displayName,
            scopeId: scopeId,
            builtIn: builtIn,
            definitionJson: definitionJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String displayName,
            required String scopeId,
            required bool builtIn,
            required String definitionJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              ConnectionTypeDefinitionRowsCompanion.insert(
            id: id,
            displayName: displayName,
            scopeId: scopeId,
            builtIn: builtIn,
            definitionJson: definitionJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ConnectionTypeDefinitionRowsTableProcessedTableManager
    = ProcessedTableManager<
        _$AuthorOsDatabase,
        $ConnectionTypeDefinitionRowsTable,
        ConnectionTypeDefinitionRow,
        $$ConnectionTypeDefinitionRowsTableFilterComposer,
        $$ConnectionTypeDefinitionRowsTableOrderingComposer,
        $$ConnectionTypeDefinitionRowsTableAnnotationComposer,
        $$ConnectionTypeDefinitionRowsTableCreateCompanionBuilder,
        $$ConnectionTypeDefinitionRowsTableUpdateCompanionBuilder,
        (
          ConnectionTypeDefinitionRow,
          BaseReferences<_$AuthorOsDatabase, $ConnectionTypeDefinitionRowsTable,
              ConnectionTypeDefinitionRow>
        ),
        ConnectionTypeDefinitionRow,
        PrefetchHooks Function()>;
typedef $$StoryBranchRowsTableCreateCompanionBuilder = StoryBranchRowsCompanion
    Function({
  required String id,
  required String projectId,
  Value<String?> parentBranchId,
  required String name,
  required String kind,
  required String status,
  required String branchJson,
  Value<int> rowid,
});
typedef $$StoryBranchRowsTableUpdateCompanionBuilder = StoryBranchRowsCompanion
    Function({
  Value<String> id,
  Value<String> projectId,
  Value<String?> parentBranchId,
  Value<String> name,
  Value<String> kind,
  Value<String> status,
  Value<String> branchJson,
  Value<int> rowid,
});

final class $$StoryBranchRowsTableReferences extends BaseReferences<
    _$AuthorOsDatabase, $StoryBranchRowsTable, StoryBranchRow> {
  $$StoryBranchRowsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BranchRecordOverlayRowsTable,
      List<BranchRecordOverlayRow>> _branchRecordOverlayRowsRefsTable(
          _$AuthorOsDatabase db) =>
      MultiTypedResultKey.fromTable(db.branchRecordOverlayRows,
          aliasName:
              'story_branch_rows__id__branch_record_overlay_rows__branch_id');

  $$BranchRecordOverlayRowsTableProcessedTableManager
      get branchRecordOverlayRowsRefs {
    final manager = $$BranchRecordOverlayRowsTableTableManager(
            $_db, $_db.branchRecordOverlayRows)
        .filter((f) => f.branchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_branchRecordOverlayRowsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$BranchLinkOverlayRowsTable,
      List<BranchLinkOverlayRow>> _branchLinkOverlayRowsRefsTable(
          _$AuthorOsDatabase db) =>
      MultiTypedResultKey.fromTable(db.branchLinkOverlayRows,
          aliasName:
              'story_branch_rows__id__branch_link_overlay_rows__branch_id');

  $$BranchLinkOverlayRowsTableProcessedTableManager
      get branchLinkOverlayRowsRefs {
    final manager = $$BranchLinkOverlayRowsTableTableManager(
            $_db, $_db.branchLinkOverlayRows)
        .filter((f) => f.branchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_branchLinkOverlayRowsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$StoryBranchRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $StoryBranchRowsTable> {
  $$StoryBranchRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parentBranchId => $composableBuilder(
      column: $table.parentBranchId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchJson => $composableBuilder(
      column: $table.branchJson, builder: (column) => ColumnFilters(column));

  Expression<bool> branchRecordOverlayRowsRefs(
      Expression<bool> Function($$BranchRecordOverlayRowsTableFilterComposer f)
          f) {
    final $$BranchRecordOverlayRowsTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.branchRecordOverlayRows,
            getReferencedColumn: (t) => t.branchId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BranchRecordOverlayRowsTableFilterComposer(
                  $db: $db,
                  $table: $db.branchRecordOverlayRows,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<bool> branchLinkOverlayRowsRefs(
      Expression<bool> Function($$BranchLinkOverlayRowsTableFilterComposer f)
          f) {
    final $$BranchLinkOverlayRowsTableFilterComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.branchLinkOverlayRows,
            getReferencedColumn: (t) => t.branchId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BranchLinkOverlayRowsTableFilterComposer(
                  $db: $db,
                  $table: $db.branchLinkOverlayRows,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$StoryBranchRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $StoryBranchRowsTable> {
  $$StoryBranchRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parentBranchId => $composableBuilder(
      column: $table.parentBranchId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchJson => $composableBuilder(
      column: $table.branchJson, builder: (column) => ColumnOrderings(column));
}

class $$StoryBranchRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $StoryBranchRowsTable> {
  $$StoryBranchRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get parentBranchId => $composableBuilder(
      column: $table.parentBranchId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get branchJson => $composableBuilder(
      column: $table.branchJson, builder: (column) => column);

  Expression<T> branchRecordOverlayRowsRefs<T extends Object>(
      Expression<T> Function($$BranchRecordOverlayRowsTableAnnotationComposer a)
          f) {
    final $$BranchRecordOverlayRowsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.branchRecordOverlayRows,
            getReferencedColumn: (t) => t.branchId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BranchRecordOverlayRowsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.branchRecordOverlayRows,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }

  Expression<T> branchLinkOverlayRowsRefs<T extends Object>(
      Expression<T> Function($$BranchLinkOverlayRowsTableAnnotationComposer a)
          f) {
    final $$BranchLinkOverlayRowsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.branchLinkOverlayRows,
            getReferencedColumn: (t) => t.branchId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$BranchLinkOverlayRowsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.branchLinkOverlayRows,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$StoryBranchRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $StoryBranchRowsTable,
    StoryBranchRow,
    $$StoryBranchRowsTableFilterComposer,
    $$StoryBranchRowsTableOrderingComposer,
    $$StoryBranchRowsTableAnnotationComposer,
    $$StoryBranchRowsTableCreateCompanionBuilder,
    $$StoryBranchRowsTableUpdateCompanionBuilder,
    (StoryBranchRow, $$StoryBranchRowsTableReferences),
    StoryBranchRow,
    PrefetchHooks Function(
        {bool branchRecordOverlayRowsRefs, bool branchLinkOverlayRowsRefs})> {
  $$StoryBranchRowsTableTableManager(
      _$AuthorOsDatabase db, $StoryBranchRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoryBranchRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoryBranchRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoryBranchRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String?> parentBranchId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> branchJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StoryBranchRowsCompanion(
            id: id,
            projectId: projectId,
            parentBranchId: parentBranchId,
            name: name,
            kind: kind,
            status: status,
            branchJson: branchJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String projectId,
            Value<String?> parentBranchId = const Value.absent(),
            required String name,
            required String kind,
            required String status,
            required String branchJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              StoryBranchRowsCompanion.insert(
            id: id,
            projectId: projectId,
            parentBranchId: parentBranchId,
            name: name,
            kind: kind,
            status: status,
            branchJson: branchJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$StoryBranchRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {branchRecordOverlayRowsRefs = false,
              branchLinkOverlayRowsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (branchRecordOverlayRowsRefs) db.branchRecordOverlayRows,
                if (branchLinkOverlayRowsRefs) db.branchLinkOverlayRows
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (branchRecordOverlayRowsRefs)
                    await $_getPrefetchedData<StoryBranchRow,
                            $StoryBranchRowsTable, BranchRecordOverlayRow>(
                        currentTable: table,
                        referencedTable: $$StoryBranchRowsTableReferences
                            ._branchRecordOverlayRowsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StoryBranchRowsTableReferences(db, table, p0)
                                .branchRecordOverlayRowsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.branchId == item.id),
                        typedResults: items),
                  if (branchLinkOverlayRowsRefs)
                    await $_getPrefetchedData<StoryBranchRow,
                            $StoryBranchRowsTable, BranchLinkOverlayRow>(
                        currentTable: table,
                        referencedTable: $$StoryBranchRowsTableReferences
                            ._branchLinkOverlayRowsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$StoryBranchRowsTableReferences(db, table, p0)
                                .branchLinkOverlayRowsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.branchId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$StoryBranchRowsTableProcessedTableManager = ProcessedTableManager<
    _$AuthorOsDatabase,
    $StoryBranchRowsTable,
    StoryBranchRow,
    $$StoryBranchRowsTableFilterComposer,
    $$StoryBranchRowsTableOrderingComposer,
    $$StoryBranchRowsTableAnnotationComposer,
    $$StoryBranchRowsTableCreateCompanionBuilder,
    $$StoryBranchRowsTableUpdateCompanionBuilder,
    (StoryBranchRow, $$StoryBranchRowsTableReferences),
    StoryBranchRow,
    PrefetchHooks Function(
        {bool branchRecordOverlayRowsRefs, bool branchLinkOverlayRowsRefs})>;
typedef $$BranchRecordOverlayRowsTableCreateCompanionBuilder
    = BranchRecordOverlayRowsCompanion Function({
  required String branchId,
  required String recordId,
  required String state,
  required String overlayJson,
  Value<int> rowid,
});
typedef $$BranchRecordOverlayRowsTableUpdateCompanionBuilder
    = BranchRecordOverlayRowsCompanion Function({
  Value<String> branchId,
  Value<String> recordId,
  Value<String> state,
  Value<String> overlayJson,
  Value<int> rowid,
});

final class $$BranchRecordOverlayRowsTableReferences extends BaseReferences<
    _$AuthorOsDatabase, $BranchRecordOverlayRowsTable, BranchRecordOverlayRow> {
  $$BranchRecordOverlayRowsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $StoryBranchRowsTable _branchIdTable(_$AuthorOsDatabase db) =>
      db.storyBranchRows.createAlias(
          'branch_record_overlay_rows__branch_id__story_branch_rows__id');

  $$StoryBranchRowsTableProcessedTableManager get branchId {
    final $_column = $_itemColumn<String>('branch_id')!;

    final manager =
        $$StoryBranchRowsTableTableManager($_db, $_db.storyBranchRows)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_branchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BranchRecordOverlayRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $BranchRecordOverlayRowsTable> {
  $$BranchRecordOverlayRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => ColumnFilters(column));

  $$StoryBranchRowsTableFilterComposer get branchId {
    final $$StoryBranchRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.branchId,
        referencedTable: $db.storyBranchRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StoryBranchRowsTableFilterComposer(
              $db: $db,
              $table: $db.storyBranchRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BranchRecordOverlayRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $BranchRecordOverlayRowsTable> {
  $$BranchRecordOverlayRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => ColumnOrderings(column));

  $$StoryBranchRowsTableOrderingComposer get branchId {
    final $$StoryBranchRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.branchId,
        referencedTable: $db.storyBranchRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StoryBranchRowsTableOrderingComposer(
              $db: $db,
              $table: $db.storyBranchRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BranchRecordOverlayRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $BranchRecordOverlayRowsTable> {
  $$BranchRecordOverlayRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => column);

  $$StoryBranchRowsTableAnnotationComposer get branchId {
    final $$StoryBranchRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.branchId,
        referencedTable: $db.storyBranchRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StoryBranchRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.storyBranchRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BranchRecordOverlayRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $BranchRecordOverlayRowsTable,
    BranchRecordOverlayRow,
    $$BranchRecordOverlayRowsTableFilterComposer,
    $$BranchRecordOverlayRowsTableOrderingComposer,
    $$BranchRecordOverlayRowsTableAnnotationComposer,
    $$BranchRecordOverlayRowsTableCreateCompanionBuilder,
    $$BranchRecordOverlayRowsTableUpdateCompanionBuilder,
    (BranchRecordOverlayRow, $$BranchRecordOverlayRowsTableReferences),
    BranchRecordOverlayRow,
    PrefetchHooks Function({bool branchId})> {
  $$BranchRecordOverlayRowsTableTableManager(
      _$AuthorOsDatabase db, $BranchRecordOverlayRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BranchRecordOverlayRowsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$BranchRecordOverlayRowsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BranchRecordOverlayRowsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> branchId = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<String> overlayJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BranchRecordOverlayRowsCompanion(
            branchId: branchId,
            recordId: recordId,
            state: state,
            overlayJson: overlayJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String branchId,
            required String recordId,
            required String state,
            required String overlayJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              BranchRecordOverlayRowsCompanion.insert(
            branchId: branchId,
            recordId: recordId,
            state: state,
            overlayJson: overlayJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BranchRecordOverlayRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({branchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (branchId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.branchId,
                    referencedTable: $$BranchRecordOverlayRowsTableReferences
                        ._branchIdTable(db),
                    referencedColumn: $$BranchRecordOverlayRowsTableReferences
                        ._branchIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BranchRecordOverlayRowsTableProcessedTableManager
    = ProcessedTableManager<
        _$AuthorOsDatabase,
        $BranchRecordOverlayRowsTable,
        BranchRecordOverlayRow,
        $$BranchRecordOverlayRowsTableFilterComposer,
        $$BranchRecordOverlayRowsTableOrderingComposer,
        $$BranchRecordOverlayRowsTableAnnotationComposer,
        $$BranchRecordOverlayRowsTableCreateCompanionBuilder,
        $$BranchRecordOverlayRowsTableUpdateCompanionBuilder,
        (BranchRecordOverlayRow, $$BranchRecordOverlayRowsTableReferences),
        BranchRecordOverlayRow,
        PrefetchHooks Function({bool branchId})>;
typedef $$BranchLinkOverlayRowsTableCreateCompanionBuilder
    = BranchLinkOverlayRowsCompanion Function({
  required String branchId,
  required String linkId,
  required String state,
  required String overlayJson,
  Value<int> rowid,
});
typedef $$BranchLinkOverlayRowsTableUpdateCompanionBuilder
    = BranchLinkOverlayRowsCompanion Function({
  Value<String> branchId,
  Value<String> linkId,
  Value<String> state,
  Value<String> overlayJson,
  Value<int> rowid,
});

final class $$BranchLinkOverlayRowsTableReferences extends BaseReferences<
    _$AuthorOsDatabase, $BranchLinkOverlayRowsTable, BranchLinkOverlayRow> {
  $$BranchLinkOverlayRowsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $StoryBranchRowsTable _branchIdTable(_$AuthorOsDatabase db) =>
      db.storyBranchRows.createAlias(
          'branch_link_overlay_rows__branch_id__story_branch_rows__id');

  $$StoryBranchRowsTableProcessedTableManager get branchId {
    final $_column = $_itemColumn<String>('branch_id')!;

    final manager =
        $$StoryBranchRowsTableTableManager($_db, $_db.storyBranchRows)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_branchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$BranchLinkOverlayRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $BranchLinkOverlayRowsTable> {
  $$BranchLinkOverlayRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get linkId => $composableBuilder(
      column: $table.linkId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => ColumnFilters(column));

  $$StoryBranchRowsTableFilterComposer get branchId {
    final $$StoryBranchRowsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.branchId,
        referencedTable: $db.storyBranchRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StoryBranchRowsTableFilterComposer(
              $db: $db,
              $table: $db.storyBranchRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BranchLinkOverlayRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $BranchLinkOverlayRowsTable> {
  $$BranchLinkOverlayRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get linkId => $composableBuilder(
      column: $table.linkId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => ColumnOrderings(column));

  $$StoryBranchRowsTableOrderingComposer get branchId {
    final $$StoryBranchRowsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.branchId,
        referencedTable: $db.storyBranchRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StoryBranchRowsTableOrderingComposer(
              $db: $db,
              $table: $db.storyBranchRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BranchLinkOverlayRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $BranchLinkOverlayRowsTable> {
  $$BranchLinkOverlayRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get linkId =>
      $composableBuilder(column: $table.linkId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get overlayJson => $composableBuilder(
      column: $table.overlayJson, builder: (column) => column);

  $$StoryBranchRowsTableAnnotationComposer get branchId {
    final $$StoryBranchRowsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.branchId,
        referencedTable: $db.storyBranchRows,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$StoryBranchRowsTableAnnotationComposer(
              $db: $db,
              $table: $db.storyBranchRows,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$BranchLinkOverlayRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $BranchLinkOverlayRowsTable,
    BranchLinkOverlayRow,
    $$BranchLinkOverlayRowsTableFilterComposer,
    $$BranchLinkOverlayRowsTableOrderingComposer,
    $$BranchLinkOverlayRowsTableAnnotationComposer,
    $$BranchLinkOverlayRowsTableCreateCompanionBuilder,
    $$BranchLinkOverlayRowsTableUpdateCompanionBuilder,
    (BranchLinkOverlayRow, $$BranchLinkOverlayRowsTableReferences),
    BranchLinkOverlayRow,
    PrefetchHooks Function({bool branchId})> {
  $$BranchLinkOverlayRowsTableTableManager(
      _$AuthorOsDatabase db, $BranchLinkOverlayRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BranchLinkOverlayRowsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$BranchLinkOverlayRowsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BranchLinkOverlayRowsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> branchId = const Value.absent(),
            Value<String> linkId = const Value.absent(),
            Value<String> state = const Value.absent(),
            Value<String> overlayJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BranchLinkOverlayRowsCompanion(
            branchId: branchId,
            linkId: linkId,
            state: state,
            overlayJson: overlayJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String branchId,
            required String linkId,
            required String state,
            required String overlayJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              BranchLinkOverlayRowsCompanion.insert(
            branchId: branchId,
            linkId: linkId,
            state: state,
            overlayJson: overlayJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$BranchLinkOverlayRowsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({branchId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (branchId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.branchId,
                    referencedTable: $$BranchLinkOverlayRowsTableReferences
                        ._branchIdTable(db),
                    referencedColumn: $$BranchLinkOverlayRowsTableReferences
                        ._branchIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$BranchLinkOverlayRowsTableProcessedTableManager
    = ProcessedTableManager<
        _$AuthorOsDatabase,
        $BranchLinkOverlayRowsTable,
        BranchLinkOverlayRow,
        $$BranchLinkOverlayRowsTableFilterComposer,
        $$BranchLinkOverlayRowsTableOrderingComposer,
        $$BranchLinkOverlayRowsTableAnnotationComposer,
        $$BranchLinkOverlayRowsTableCreateCompanionBuilder,
        $$BranchLinkOverlayRowsTableUpdateCompanionBuilder,
        (BranchLinkOverlayRow, $$BranchLinkOverlayRowsTableReferences),
        BranchLinkOverlayRow,
        PrefetchHooks Function({bool branchId})>;
typedef $$RecordVersionRowsTableCreateCompanionBuilder
    = RecordVersionRowsCompanion Function({
  required String id,
  required String entityId,
  required String entityKind,
  required String recordId,
  required String recordType,
  required String projectId,
  Value<String?> seriesId,
  Value<String?> bookId,
  Value<String?> branchId,
  required String changeType,
  required DateTime createdAt,
  Value<String?> previousVersionId,
  required String versionJson,
  Value<int> rowid,
});
typedef $$RecordVersionRowsTableUpdateCompanionBuilder
    = RecordVersionRowsCompanion Function({
  Value<String> id,
  Value<String> entityId,
  Value<String> entityKind,
  Value<String> recordId,
  Value<String> recordType,
  Value<String> projectId,
  Value<String?> seriesId,
  Value<String?> bookId,
  Value<String?> branchId,
  Value<String> changeType,
  Value<DateTime> createdAt,
  Value<String?> previousVersionId,
  Value<String> versionJson,
  Value<int> rowid,
});

class $$RecordVersionRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $RecordVersionRowsTable> {
  $$RecordVersionRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityKind => $composableBuilder(
      column: $table.entityKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordType => $composableBuilder(
      column: $table.recordType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seriesId => $composableBuilder(
      column: $table.seriesId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changeType => $composableBuilder(
      column: $table.changeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get previousVersionId => $composableBuilder(
      column: $table.previousVersionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionJson => $composableBuilder(
      column: $table.versionJson, builder: (column) => ColumnFilters(column));
}

class $$RecordVersionRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $RecordVersionRowsTable> {
  $$RecordVersionRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityKind => $composableBuilder(
      column: $table.entityKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordType => $composableBuilder(
      column: $table.recordType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seriesId => $composableBuilder(
      column: $table.seriesId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changeType => $composableBuilder(
      column: $table.changeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get previousVersionId => $composableBuilder(
      column: $table.previousVersionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionJson => $composableBuilder(
      column: $table.versionJson, builder: (column) => ColumnOrderings(column));
}

class $$RecordVersionRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $RecordVersionRowsTable> {
  $$RecordVersionRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityKind => $composableBuilder(
      column: $table.entityKind, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
      column: $table.recordType, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get changeType => $composableBuilder(
      column: $table.changeType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get previousVersionId => $composableBuilder(
      column: $table.previousVersionId, builder: (column) => column);

  GeneratedColumn<String> get versionJson => $composableBuilder(
      column: $table.versionJson, builder: (column) => column);
}

class $$RecordVersionRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $RecordVersionRowsTable,
    RecordVersionRow,
    $$RecordVersionRowsTableFilterComposer,
    $$RecordVersionRowsTableOrderingComposer,
    $$RecordVersionRowsTableAnnotationComposer,
    $$RecordVersionRowsTableCreateCompanionBuilder,
    $$RecordVersionRowsTableUpdateCompanionBuilder,
    (
      RecordVersionRow,
      BaseReferences<_$AuthorOsDatabase, $RecordVersionRowsTable,
          RecordVersionRow>
    ),
    RecordVersionRow,
    PrefetchHooks Function()> {
  $$RecordVersionRowsTableTableManager(
      _$AuthorOsDatabase db, $RecordVersionRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordVersionRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordVersionRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordVersionRowsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> entityKind = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> recordType = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String?> seriesId = const Value.absent(),
            Value<String?> bookId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<String> changeType = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String?> previousVersionId = const Value.absent(),
            Value<String> versionJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordVersionRowsCompanion(
            id: id,
            entityId: entityId,
            entityKind: entityKind,
            recordId: recordId,
            recordType: recordType,
            projectId: projectId,
            seriesId: seriesId,
            bookId: bookId,
            branchId: branchId,
            changeType: changeType,
            createdAt: createdAt,
            previousVersionId: previousVersionId,
            versionJson: versionJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String entityId,
            required String entityKind,
            required String recordId,
            required String recordType,
            required String projectId,
            Value<String?> seriesId = const Value.absent(),
            Value<String?> bookId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            required String changeType,
            required DateTime createdAt,
            Value<String?> previousVersionId = const Value.absent(),
            required String versionJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordVersionRowsCompanion.insert(
            id: id,
            entityId: entityId,
            entityKind: entityKind,
            recordId: recordId,
            recordType: recordType,
            projectId: projectId,
            seriesId: seriesId,
            bookId: bookId,
            branchId: branchId,
            changeType: changeType,
            createdAt: createdAt,
            previousVersionId: previousVersionId,
            versionJson: versionJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecordVersionRowsTableProcessedTableManager = ProcessedTableManager<
    _$AuthorOsDatabase,
    $RecordVersionRowsTable,
    RecordVersionRow,
    $$RecordVersionRowsTableFilterComposer,
    $$RecordVersionRowsTableOrderingComposer,
    $$RecordVersionRowsTableAnnotationComposer,
    $$RecordVersionRowsTableCreateCompanionBuilder,
    $$RecordVersionRowsTableUpdateCompanionBuilder,
    (
      RecordVersionRow,
      BaseReferences<_$AuthorOsDatabase, $RecordVersionRowsTable,
          RecordVersionRow>
    ),
    RecordVersionRow,
    PrefetchHooks Function()>;
typedef $$AuditEventRowsTableCreateCompanionBuilder = AuditEventRowsCompanion
    Function({
  required String id,
  required String versionId,
  required String entityId,
  required String entityKind,
  required String recordId,
  required String recordType,
  required String projectId,
  Value<String?> seriesId,
  Value<String?> bookId,
  Value<String?> branchId,
  required String changeType,
  required DateTime createdAt,
  required String eventJson,
  Value<int> rowid,
});
typedef $$AuditEventRowsTableUpdateCompanionBuilder = AuditEventRowsCompanion
    Function({
  Value<String> id,
  Value<String> versionId,
  Value<String> entityId,
  Value<String> entityKind,
  Value<String> recordId,
  Value<String> recordType,
  Value<String> projectId,
  Value<String?> seriesId,
  Value<String?> bookId,
  Value<String?> branchId,
  Value<String> changeType,
  Value<DateTime> createdAt,
  Value<String> eventJson,
  Value<int> rowid,
});

class $$AuditEventRowsTableFilterComposer
    extends Composer<_$AuthorOsDatabase, $AuditEventRowsTable> {
  $$AuditEventRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get versionId => $composableBuilder(
      column: $table.versionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityKind => $composableBuilder(
      column: $table.entityKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordType => $composableBuilder(
      column: $table.recordType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seriesId => $composableBuilder(
      column: $table.seriesId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changeType => $composableBuilder(
      column: $table.changeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get eventJson => $composableBuilder(
      column: $table.eventJson, builder: (column) => ColumnFilters(column));
}

class $$AuditEventRowsTableOrderingComposer
    extends Composer<_$AuthorOsDatabase, $AuditEventRowsTable> {
  $$AuditEventRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get versionId => $composableBuilder(
      column: $table.versionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityKind => $composableBuilder(
      column: $table.entityKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId => $composableBuilder(
      column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordType => $composableBuilder(
      column: $table.recordType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get projectId => $composableBuilder(
      column: $table.projectId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seriesId => $composableBuilder(
      column: $table.seriesId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bookId => $composableBuilder(
      column: $table.bookId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get branchId => $composableBuilder(
      column: $table.branchId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changeType => $composableBuilder(
      column: $table.changeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get eventJson => $composableBuilder(
      column: $table.eventJson, builder: (column) => ColumnOrderings(column));
}

class $$AuditEventRowsTableAnnotationComposer
    extends Composer<_$AuthorOsDatabase, $AuditEventRowsTable> {
  $$AuditEventRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get versionId =>
      $composableBuilder(column: $table.versionId, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityKind => $composableBuilder(
      column: $table.entityKind, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get recordType => $composableBuilder(
      column: $table.recordType, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get seriesId =>
      $composableBuilder(column: $table.seriesId, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get branchId =>
      $composableBuilder(column: $table.branchId, builder: (column) => column);

  GeneratedColumn<String> get changeType => $composableBuilder(
      column: $table.changeType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get eventJson =>
      $composableBuilder(column: $table.eventJson, builder: (column) => column);
}

class $$AuditEventRowsTableTableManager extends RootTableManager<
    _$AuthorOsDatabase,
    $AuditEventRowsTable,
    AuditEventRow,
    $$AuditEventRowsTableFilterComposer,
    $$AuditEventRowsTableOrderingComposer,
    $$AuditEventRowsTableAnnotationComposer,
    $$AuditEventRowsTableCreateCompanionBuilder,
    $$AuditEventRowsTableUpdateCompanionBuilder,
    (
      AuditEventRow,
      BaseReferences<_$AuthorOsDatabase, $AuditEventRowsTable, AuditEventRow>
    ),
    AuditEventRow,
    PrefetchHooks Function()> {
  $$AuditEventRowsTableTableManager(
      _$AuthorOsDatabase db, $AuditEventRowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditEventRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditEventRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditEventRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> versionId = const Value.absent(),
            Value<String> entityId = const Value.absent(),
            Value<String> entityKind = const Value.absent(),
            Value<String> recordId = const Value.absent(),
            Value<String> recordType = const Value.absent(),
            Value<String> projectId = const Value.absent(),
            Value<String?> seriesId = const Value.absent(),
            Value<String?> bookId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            Value<String> changeType = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> eventJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AuditEventRowsCompanion(
            id: id,
            versionId: versionId,
            entityId: entityId,
            entityKind: entityKind,
            recordId: recordId,
            recordType: recordType,
            projectId: projectId,
            seriesId: seriesId,
            bookId: bookId,
            branchId: branchId,
            changeType: changeType,
            createdAt: createdAt,
            eventJson: eventJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String versionId,
            required String entityId,
            required String entityKind,
            required String recordId,
            required String recordType,
            required String projectId,
            Value<String?> seriesId = const Value.absent(),
            Value<String?> bookId = const Value.absent(),
            Value<String?> branchId = const Value.absent(),
            required String changeType,
            required DateTime createdAt,
            required String eventJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              AuditEventRowsCompanion.insert(
            id: id,
            versionId: versionId,
            entityId: entityId,
            entityKind: entityKind,
            recordId: recordId,
            recordType: recordType,
            projectId: projectId,
            seriesId: seriesId,
            bookId: bookId,
            branchId: branchId,
            changeType: changeType,
            createdAt: createdAt,
            eventJson: eventJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AuditEventRowsTableProcessedTableManager = ProcessedTableManager<
    _$AuthorOsDatabase,
    $AuditEventRowsTable,
    AuditEventRow,
    $$AuditEventRowsTableFilterComposer,
    $$AuditEventRowsTableOrderingComposer,
    $$AuditEventRowsTableAnnotationComposer,
    $$AuditEventRowsTableCreateCompanionBuilder,
    $$AuditEventRowsTableUpdateCompanionBuilder,
    (
      AuditEventRow,
      BaseReferences<_$AuthorOsDatabase, $AuditEventRowsTable, AuditEventRow>
    ),
    AuditEventRow,
    PrefetchHooks Function()>;

class $AuthorOsDatabaseManager {
  final _$AuthorOsDatabase _db;
  $AuthorOsDatabaseManager(this._db);
  $$ConnectedEntitiesTableTableManager get connectedEntities =>
      $$ConnectedEntitiesTableTableManager(_db, _db.connectedEntities);
  $$AuthorRecordRowsTableTableManager get authorRecordRows =>
      $$AuthorRecordRowsTableTableManager(_db, _db.authorRecordRows);
  $$ManuscriptNodeRowsTableTableManager get manuscriptNodeRows =>
      $$ManuscriptNodeRowsTableTableManager(_db, _db.manuscriptNodeRows);
  $$RecordLinkRowsTableTableManager get recordLinkRows =>
      $$RecordLinkRowsTableTableManager(_db, _db.recordLinkRows);
  $$RecordTypeDefinitionRowsTableTableManager get recordTypeDefinitionRows =>
      $$RecordTypeDefinitionRowsTableTableManager(
          _db, _db.recordTypeDefinitionRows);
  $$ConnectionTypeDefinitionRowsTableTableManager
      get connectionTypeDefinitionRows =>
          $$ConnectionTypeDefinitionRowsTableTableManager(
              _db, _db.connectionTypeDefinitionRows);
  $$StoryBranchRowsTableTableManager get storyBranchRows =>
      $$StoryBranchRowsTableTableManager(_db, _db.storyBranchRows);
  $$BranchRecordOverlayRowsTableTableManager get branchRecordOverlayRows =>
      $$BranchRecordOverlayRowsTableTableManager(
          _db, _db.branchRecordOverlayRows);
  $$BranchLinkOverlayRowsTableTableManager get branchLinkOverlayRows =>
      $$BranchLinkOverlayRowsTableTableManager(_db, _db.branchLinkOverlayRows);
  $$RecordVersionRowsTableTableManager get recordVersionRows =>
      $$RecordVersionRowsTableTableManager(_db, _db.recordVersionRows);
  $$AuditEventRowsTableTableManager get auditEventRows =>
      $$AuditEventRowsTableTableManager(_db, _db.auditEventRows);
}
