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
        title,
        status,
        schemaVersion,
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
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      schemaVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}schema_version'])!,
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
  final String title;
  final String status;
  final int schemaVersion;
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
      required this.title,
      required this.status,
      required this.schemaVersion,
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
    map['title'] = Variable<String>(title);
    map['status'] = Variable<String>(status);
    map['schema_version'] = Variable<int>(schemaVersion);
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
      title: Value(title),
      status: Value(status),
      schemaVersion: Value(schemaVersion),
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
      title: serializer.fromJson<String>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
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
      'title': serializer.toJson<String>(title),
      'status': serializer.toJson<String>(status),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
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
          String? title,
          String? status,
          int? schemaVersion,
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
        title: title ?? this.title,
        status: status ?? this.status,
        schemaVersion: schemaVersion ?? this.schemaVersion,
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
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
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
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('schemaVersion: $schemaVersion, ')
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
      title,
      status,
      schemaVersion,
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
          other.title == this.title &&
          other.status == this.status &&
          other.schemaVersion == this.schemaVersion &&
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
  final Value<String> title;
  final Value<String> status;
  final Value<int> schemaVersion;
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
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.schemaVersion = const Value.absent(),
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
    required String title,
    required String status,
    required int schemaVersion,
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
    Expression<String>? title,
    Expression<String>? status,
    Expression<int>? schemaVersion,
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
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (schemaVersion != null) 'schema_version': schemaVersion,
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
      Value<String>? title,
      Value<String>? status,
      Value<int>? schemaVersion,
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
      title: title ?? this.title,
      status: status ?? this.status,
      schemaVersion: schemaVersion ?? this.schemaVersion,
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
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
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
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('schemaVersion: $schemaVersion, ')
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
  late final Index authorRecordsType = Index('author_records_type',
      'CREATE INDEX author_records_type ON author_record_rows (type_id)');
  late final Index authorRecordsScope = Index('author_records_scope',
      'CREATE INDEX author_records_scope ON author_record_rows (scope_id)');
  late final Index manuscriptNodesProject = Index('manuscript_nodes_project',
      'CREATE INDEX manuscript_nodes_project ON manuscript_node_rows (project_id)');
  late final Index recordLinksSource = Index('record_links_source',
      'CREATE INDEX record_links_source ON record_link_rows (source_id)');
  late final Index recordLinksTarget = Index('record_links_target',
      'CREATE INDEX record_links_target ON record_link_rows (target_id)');
  late final Index recordLinksScope = Index('record_links_scope',
      'CREATE INDEX record_links_scope ON record_link_rows (scope_id)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        connectedEntities,
        authorRecordRows,
        manuscriptNodeRows,
        recordLinkRows,
        authorRecordsType,
        authorRecordsScope,
        manuscriptNodesProject,
        recordLinksSource,
        recordLinksTarget,
        recordLinksScope
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
  required String title,
  required String status,
  required int schemaVersion,
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
  Value<String> title,
  Value<String> status,
  Value<int> schemaVersion,
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

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion,
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

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
      column: $table.schemaVersion, builder: (column) => column);

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
            Value<String> title = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> schemaVersion = const Value.absent(),
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
            title: title,
            status: status,
            schemaVersion: schemaVersion,
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
            required String title,
            required String status,
            required int schemaVersion,
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
            title: title,
            status: status,
            schemaVersion: schemaVersion,
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
}
