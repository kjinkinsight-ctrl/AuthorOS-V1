// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_benchmark.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarBenchmarkRecordCollection on Isar {
  IsarCollection<IsarBenchmarkRecord> get isarBenchmarkRecords =>
      this.collection();
}

const IsarBenchmarkRecordSchema = CollectionSchema(
  name: r'IsarBenchmarkRecord',
  id: -8704294517023669270,
  properties: {
    r'canonicalId': PropertySchema(
      id: 0,
      name: r'canonicalId',
      type: IsarType.string,
    ),
    r'payload': PropertySchema(
      id: 1,
      name: r'payload',
      type: IsarType.string,
    ),
    r'revision': PropertySchema(
      id: 2,
      name: r'revision',
      type: IsarType.long,
    ),
    r'scopeId': PropertySchema(
      id: 3,
      name: r'scopeId',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 4,
      name: r'title',
      type: IsarType.string,
    ),
    r'typeId': PropertySchema(
      id: 5,
      name: r'typeId',
      type: IsarType.string,
    )
  },
  estimateSize: _isarBenchmarkRecordEstimateSize,
  serialize: _isarBenchmarkRecordSerialize,
  deserialize: _isarBenchmarkRecordDeserialize,
  deserializeProp: _isarBenchmarkRecordDeserializeProp,
  idName: r'id',
  indexes: {
    r'canonicalId': IndexSchema(
      id: 4719907467128787314,
      name: r'canonicalId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'canonicalId',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'typeId': IndexSchema(
      id: 5741258893451994948,
      name: r'typeId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'typeId',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarBenchmarkRecordGetId,
  getLinks: _isarBenchmarkRecordGetLinks,
  attach: _isarBenchmarkRecordAttach,
  version: '3.3.2',
);

int _isarBenchmarkRecordEstimateSize(
  IsarBenchmarkRecord object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.canonicalId.length * 3;
  bytesCount += 3 + object.payload.length * 3;
  bytesCount += 3 + object.scopeId.length * 3;
  bytesCount += 3 + object.title.length * 3;
  bytesCount += 3 + object.typeId.length * 3;
  return bytesCount;
}

void _isarBenchmarkRecordSerialize(
  IsarBenchmarkRecord object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.canonicalId);
  writer.writeString(offsets[1], object.payload);
  writer.writeLong(offsets[2], object.revision);
  writer.writeString(offsets[3], object.scopeId);
  writer.writeString(offsets[4], object.title);
  writer.writeString(offsets[5], object.typeId);
}

IsarBenchmarkRecord _isarBenchmarkRecordDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarBenchmarkRecord();
  object.canonicalId = reader.readString(offsets[0]);
  object.id = id;
  object.payload = reader.readString(offsets[1]);
  object.revision = reader.readLong(offsets[2]);
  object.scopeId = reader.readString(offsets[3]);
  object.title = reader.readString(offsets[4]);
  object.typeId = reader.readString(offsets[5]);
  return object;
}

P _isarBenchmarkRecordDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarBenchmarkRecordGetId(IsarBenchmarkRecord object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarBenchmarkRecordGetLinks(
    IsarBenchmarkRecord object) {
  return [];
}

void _isarBenchmarkRecordAttach(
    IsarCollection<dynamic> col, Id id, IsarBenchmarkRecord object) {
  object.id = id;
}

extension IsarBenchmarkRecordByIndex on IsarCollection<IsarBenchmarkRecord> {
  Future<IsarBenchmarkRecord?> getByCanonicalId(String canonicalId) {
    return getByIndex(r'canonicalId', [canonicalId]);
  }

  IsarBenchmarkRecord? getByCanonicalIdSync(String canonicalId) {
    return getByIndexSync(r'canonicalId', [canonicalId]);
  }

  Future<bool> deleteByCanonicalId(String canonicalId) {
    return deleteByIndex(r'canonicalId', [canonicalId]);
  }

  bool deleteByCanonicalIdSync(String canonicalId) {
    return deleteByIndexSync(r'canonicalId', [canonicalId]);
  }

  Future<List<IsarBenchmarkRecord?>> getAllByCanonicalId(
      List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'canonicalId', values);
  }

  List<IsarBenchmarkRecord?> getAllByCanonicalIdSync(
      List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'canonicalId', values);
  }

  Future<int> deleteAllByCanonicalId(List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'canonicalId', values);
  }

  int deleteAllByCanonicalIdSync(List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'canonicalId', values);
  }

  Future<Id> putByCanonicalId(IsarBenchmarkRecord object) {
    return putByIndex(r'canonicalId', object);
  }

  Id putByCanonicalIdSync(IsarBenchmarkRecord object, {bool saveLinks = true}) {
    return putByIndexSync(r'canonicalId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCanonicalId(List<IsarBenchmarkRecord> objects) {
    return putAllByIndex(r'canonicalId', objects);
  }

  List<Id> putAllByCanonicalIdSync(List<IsarBenchmarkRecord> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'canonicalId', objects, saveLinks: saveLinks);
  }
}

extension IsarBenchmarkRecordQueryWhereSort
    on QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QWhere> {
  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhere>
      anyCanonicalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'canonicalId'),
      );
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhere>
      anyTypeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'typeId'),
      );
    });
  }
}

extension IsarBenchmarkRecordQueryWhere
    on QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QWhereClause> {
  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdEqualTo(String canonicalId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'canonicalId',
        value: [canonicalId],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdNotEqualTo(String canonicalId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [],
              upper: [canonicalId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [canonicalId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [canonicalId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [],
              upper: [canonicalId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdGreaterThan(
    String canonicalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [canonicalId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdLessThan(
    String canonicalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [],
        upper: [canonicalId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdBetween(
    String lowerCanonicalId,
    String upperCanonicalId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [lowerCanonicalId],
        includeLower: includeLower,
        upper: [upperCanonicalId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdStartsWith(String CanonicalIdPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [CanonicalIdPrefix],
        upper: ['$CanonicalIdPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'canonicalId',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      canonicalIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'canonicalId',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'canonicalId',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'canonicalId',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'canonicalId',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdEqualTo(String typeId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'typeId',
        value: [typeId],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdNotEqualTo(String typeId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'typeId',
              lower: [],
              upper: [typeId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'typeId',
              lower: [typeId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'typeId',
              lower: [typeId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'typeId',
              lower: [],
              upper: [typeId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdGreaterThan(
    String typeId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'typeId',
        lower: [typeId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdLessThan(
    String typeId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'typeId',
        lower: [],
        upper: [typeId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdBetween(
    String lowerTypeId,
    String upperTypeId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'typeId',
        lower: [lowerTypeId],
        includeLower: includeLower,
        upper: [upperTypeId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdStartsWith(String TypeIdPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'typeId',
        lower: [TypeIdPrefix],
        upper: ['$TypeIdPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'typeId',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterWhereClause>
      typeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'typeId',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'typeId',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'typeId',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'typeId',
              upper: [''],
            ));
      }
    });
  }
}

extension IsarBenchmarkRecordQueryFilter on QueryBuilder<IsarBenchmarkRecord,
    IsarBenchmarkRecord, QFilterCondition> {
  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'canonicalId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'canonicalId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'canonicalId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      canonicalIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'canonicalId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payload',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'payload',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'payload',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'payload',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'payload',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'payload',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'payload',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'payload',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'payload',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      payloadIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'payload',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      revisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'revision',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      revisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'revision',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      revisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'revision',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      revisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'revision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scopeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'scopeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      scopeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'scopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'typeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'typeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'typeId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterFilterCondition>
      typeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'typeId',
        value: '',
      ));
    });
  }
}

extension IsarBenchmarkRecordQueryObject on QueryBuilder<IsarBenchmarkRecord,
    IsarBenchmarkRecord, QFilterCondition> {}

extension IsarBenchmarkRecordQueryLinks on QueryBuilder<IsarBenchmarkRecord,
    IsarBenchmarkRecord, QFilterCondition> {}

extension IsarBenchmarkRecordQuerySortBy
    on QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QSortBy> {
  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByCanonicalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByCanonicalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByPayload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByPayloadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByScopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByScopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByTypeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      sortByTypeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.desc);
    });
  }
}

extension IsarBenchmarkRecordQuerySortThenBy
    on QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QSortThenBy> {
  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByCanonicalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByCanonicalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByPayload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByPayloadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'payload', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByScopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByScopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByTypeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QAfterSortBy>
      thenByTypeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.desc);
    });
  }
}

extension IsarBenchmarkRecordQueryWhereDistinct
    on QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QDistinct> {
  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QDistinct>
      distinctByCanonicalId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'canonicalId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QDistinct>
      distinctByPayload({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'payload', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QDistinct>
      distinctByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revision');
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QDistinct>
      distinctByScopeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scopeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QDistinct>
      distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QDistinct>
      distinctByTypeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'typeId', caseSensitive: caseSensitive);
    });
  }
}

extension IsarBenchmarkRecordQueryProperty
    on QueryBuilder<IsarBenchmarkRecord, IsarBenchmarkRecord, QQueryProperty> {
  QueryBuilder<IsarBenchmarkRecord, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarBenchmarkRecord, String, QQueryOperations>
      canonicalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'canonicalId');
    });
  }

  QueryBuilder<IsarBenchmarkRecord, String, QQueryOperations>
      payloadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'payload');
    });
  }

  QueryBuilder<IsarBenchmarkRecord, int, QQueryOperations> revisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revision');
    });
  }

  QueryBuilder<IsarBenchmarkRecord, String, QQueryOperations>
      scopeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scopeId');
    });
  }

  QueryBuilder<IsarBenchmarkRecord, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<IsarBenchmarkRecord, String, QQueryOperations> typeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'typeId');
    });
  }
}

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetIsarBenchmarkLinkCollection on Isar {
  IsarCollection<IsarBenchmarkLink> get isarBenchmarkLinks => this.collection();
}

const IsarBenchmarkLinkSchema = CollectionSchema(
  name: r'IsarBenchmarkLink',
  id: 3657667909311790607,
  properties: {
    r'canonicalId': PropertySchema(
      id: 0,
      name: r'canonicalId',
      type: IsarType.string,
    ),
    r'metadata': PropertySchema(
      id: 1,
      name: r'metadata',
      type: IsarType.string,
    ),
    r'revision': PropertySchema(
      id: 2,
      name: r'revision',
      type: IsarType.long,
    ),
    r'scopeId': PropertySchema(
      id: 3,
      name: r'scopeId',
      type: IsarType.string,
    ),
    r'sourceId': PropertySchema(
      id: 4,
      name: r'sourceId',
      type: IsarType.string,
    ),
    r'targetId': PropertySchema(
      id: 5,
      name: r'targetId',
      type: IsarType.string,
    ),
    r'typeId': PropertySchema(
      id: 6,
      name: r'typeId',
      type: IsarType.string,
    )
  },
  estimateSize: _isarBenchmarkLinkEstimateSize,
  serialize: _isarBenchmarkLinkSerialize,
  deserialize: _isarBenchmarkLinkDeserialize,
  deserializeProp: _isarBenchmarkLinkDeserializeProp,
  idName: r'id',
  indexes: {
    r'canonicalId': IndexSchema(
      id: 4719907467128787314,
      name: r'canonicalId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'canonicalId',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'sourceId': IndexSchema(
      id: 2155220942429093580,
      name: r'sourceId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sourceId',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    ),
    r'targetId': IndexSchema(
      id: -7400732725972739031,
      name: r'targetId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'targetId',
          type: IndexType.value,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _isarBenchmarkLinkGetId,
  getLinks: _isarBenchmarkLinkGetLinks,
  attach: _isarBenchmarkLinkAttach,
  version: '3.3.2',
);

int _isarBenchmarkLinkEstimateSize(
  IsarBenchmarkLink object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.canonicalId.length * 3;
  bytesCount += 3 + object.metadata.length * 3;
  bytesCount += 3 + object.scopeId.length * 3;
  bytesCount += 3 + object.sourceId.length * 3;
  bytesCount += 3 + object.targetId.length * 3;
  bytesCount += 3 + object.typeId.length * 3;
  return bytesCount;
}

void _isarBenchmarkLinkSerialize(
  IsarBenchmarkLink object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.canonicalId);
  writer.writeString(offsets[1], object.metadata);
  writer.writeLong(offsets[2], object.revision);
  writer.writeString(offsets[3], object.scopeId);
  writer.writeString(offsets[4], object.sourceId);
  writer.writeString(offsets[5], object.targetId);
  writer.writeString(offsets[6], object.typeId);
}

IsarBenchmarkLink _isarBenchmarkLinkDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = IsarBenchmarkLink();
  object.canonicalId = reader.readString(offsets[0]);
  object.id = id;
  object.metadata = reader.readString(offsets[1]);
  object.revision = reader.readLong(offsets[2]);
  object.scopeId = reader.readString(offsets[3]);
  object.sourceId = reader.readString(offsets[4]);
  object.targetId = reader.readString(offsets[5]);
  object.typeId = reader.readString(offsets[6]);
  return object;
}

P _isarBenchmarkLinkDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _isarBenchmarkLinkGetId(IsarBenchmarkLink object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _isarBenchmarkLinkGetLinks(
    IsarBenchmarkLink object) {
  return [];
}

void _isarBenchmarkLinkAttach(
    IsarCollection<dynamic> col, Id id, IsarBenchmarkLink object) {
  object.id = id;
}

extension IsarBenchmarkLinkByIndex on IsarCollection<IsarBenchmarkLink> {
  Future<IsarBenchmarkLink?> getByCanonicalId(String canonicalId) {
    return getByIndex(r'canonicalId', [canonicalId]);
  }

  IsarBenchmarkLink? getByCanonicalIdSync(String canonicalId) {
    return getByIndexSync(r'canonicalId', [canonicalId]);
  }

  Future<bool> deleteByCanonicalId(String canonicalId) {
    return deleteByIndex(r'canonicalId', [canonicalId]);
  }

  bool deleteByCanonicalIdSync(String canonicalId) {
    return deleteByIndexSync(r'canonicalId', [canonicalId]);
  }

  Future<List<IsarBenchmarkLink?>> getAllByCanonicalId(
      List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'canonicalId', values);
  }

  List<IsarBenchmarkLink?> getAllByCanonicalIdSync(
      List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'canonicalId', values);
  }

  Future<int> deleteAllByCanonicalId(List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'canonicalId', values);
  }

  int deleteAllByCanonicalIdSync(List<String> canonicalIdValues) {
    final values = canonicalIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'canonicalId', values);
  }

  Future<Id> putByCanonicalId(IsarBenchmarkLink object) {
    return putByIndex(r'canonicalId', object);
  }

  Id putByCanonicalIdSync(IsarBenchmarkLink object, {bool saveLinks = true}) {
    return putByIndexSync(r'canonicalId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCanonicalId(List<IsarBenchmarkLink> objects) {
    return putAllByIndex(r'canonicalId', objects);
  }

  List<Id> putAllByCanonicalIdSync(List<IsarBenchmarkLink> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'canonicalId', objects, saveLinks: saveLinks);
  }
}

extension IsarBenchmarkLinkQueryWhereSort
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QWhere> {
  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhere>
      anyCanonicalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'canonicalId'),
      );
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhere>
      anySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'sourceId'),
      );
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhere>
      anyTargetId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'targetId'),
      );
    });
  }
}

extension IsarBenchmarkLinkQueryWhere
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QWhereClause> {
  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdEqualTo(String canonicalId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'canonicalId',
        value: [canonicalId],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdNotEqualTo(String canonicalId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [],
              upper: [canonicalId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [canonicalId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [canonicalId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'canonicalId',
              lower: [],
              upper: [canonicalId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdGreaterThan(
    String canonicalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [canonicalId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdLessThan(
    String canonicalId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [],
        upper: [canonicalId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdBetween(
    String lowerCanonicalId,
    String upperCanonicalId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [lowerCanonicalId],
        includeLower: includeLower,
        upper: [upperCanonicalId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdStartsWith(String CanonicalIdPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'canonicalId',
        lower: [CanonicalIdPrefix],
        upper: ['$CanonicalIdPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'canonicalId',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      canonicalIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'canonicalId',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'canonicalId',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'canonicalId',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'canonicalId',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdEqualTo(String sourceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sourceId',
        value: [sourceId],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdNotEqualTo(String sourceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceId',
              lower: [],
              upper: [sourceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceId',
              lower: [sourceId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceId',
              lower: [sourceId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sourceId',
              lower: [],
              upper: [sourceId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdGreaterThan(
    String sourceId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceId',
        lower: [sourceId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdLessThan(
    String sourceId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceId',
        lower: [],
        upper: [sourceId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdBetween(
    String lowerSourceId,
    String upperSourceId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceId',
        lower: [lowerSourceId],
        includeLower: includeLower,
        upper: [upperSourceId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdStartsWith(String SourceIdPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'sourceId',
        lower: [SourceIdPrefix],
        upper: ['$SourceIdPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sourceId',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      sourceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'sourceId',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'sourceId',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'sourceId',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'sourceId',
              upper: [''],
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdEqualTo(String targetId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'targetId',
        value: [targetId],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdNotEqualTo(String targetId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetId',
              lower: [],
              upper: [targetId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetId',
              lower: [targetId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetId',
              lower: [targetId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'targetId',
              lower: [],
              upper: [targetId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdGreaterThan(
    String targetId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'targetId',
        lower: [targetId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdLessThan(
    String targetId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'targetId',
        lower: [],
        upper: [targetId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdBetween(
    String lowerTargetId,
    String upperTargetId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'targetId',
        lower: [lowerTargetId],
        includeLower: includeLower,
        upper: [upperTargetId],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdStartsWith(String TargetIdPrefix) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'targetId',
        lower: [TargetIdPrefix],
        upper: ['$TargetIdPrefix\u{FFFFF}'],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'targetId',
        value: [''],
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterWhereClause>
      targetIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'targetId',
              upper: [''],
            ))
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'targetId',
              lower: [''],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.greaterThan(
              indexName: r'targetId',
              lower: [''],
            ))
            .addWhereClause(IndexWhereClause.lessThan(
              indexName: r'targetId',
              upper: [''],
            ));
      }
    });
  }
}

extension IsarBenchmarkLinkQueryFilter
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QFilterCondition> {
  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'canonicalId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'canonicalId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'canonicalId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'canonicalId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      canonicalIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'canonicalId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadata',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'metadata',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'metadata',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'metadata',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'metadata',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'metadata',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'metadata',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'metadata',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'metadata',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      metadataIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'metadata',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      revisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'revision',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      revisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'revision',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      revisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'revision',
        value: value,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      revisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'revision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scopeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'scopeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'scopeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      scopeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'scopeId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sourceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sourceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sourceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sourceId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      sourceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sourceId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'targetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'targetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'targetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'targetId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      targetIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'targetId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'typeId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'typeId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'typeId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'typeId',
        value: '',
      ));
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterFilterCondition>
      typeIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'typeId',
        value: '',
      ));
    });
  }
}

extension IsarBenchmarkLinkQueryObject
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QFilterCondition> {}

extension IsarBenchmarkLinkQueryLinks
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QFilterCondition> {}

extension IsarBenchmarkLinkQuerySortBy
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QSortBy> {
  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByCanonicalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByCanonicalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByMetadata() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByMetadataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByScopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByScopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByTargetId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByTargetIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByTypeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      sortByTypeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.desc);
    });
  }
}

extension IsarBenchmarkLinkQuerySortThenBy
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QSortThenBy> {
  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByCanonicalId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByCanonicalIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'canonicalId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByMetadata() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByMetadataDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadata', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'revision', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByScopeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByScopeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'scopeId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenBySourceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenBySourceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sourceId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByTargetId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByTargetIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetId', Sort.desc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByTypeId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.asc);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QAfterSortBy>
      thenByTypeIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'typeId', Sort.desc);
    });
  }
}

extension IsarBenchmarkLinkQueryWhereDistinct
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct> {
  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct>
      distinctByCanonicalId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'canonicalId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct>
      distinctByMetadata({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadata', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct>
      distinctByRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'revision');
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct>
      distinctByScopeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'scopeId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct>
      distinctBySourceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sourceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct>
      distinctByTargetId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QDistinct>
      distinctByTypeId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'typeId', caseSensitive: caseSensitive);
    });
  }
}

extension IsarBenchmarkLinkQueryProperty
    on QueryBuilder<IsarBenchmarkLink, IsarBenchmarkLink, QQueryProperty> {
  QueryBuilder<IsarBenchmarkLink, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<IsarBenchmarkLink, String, QQueryOperations>
      canonicalIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'canonicalId');
    });
  }

  QueryBuilder<IsarBenchmarkLink, String, QQueryOperations> metadataProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadata');
    });
  }

  QueryBuilder<IsarBenchmarkLink, int, QQueryOperations> revisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'revision');
    });
  }

  QueryBuilder<IsarBenchmarkLink, String, QQueryOperations> scopeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'scopeId');
    });
  }

  QueryBuilder<IsarBenchmarkLink, String, QQueryOperations> sourceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sourceId');
    });
  }

  QueryBuilder<IsarBenchmarkLink, String, QQueryOperations> targetIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetId');
    });
  }

  QueryBuilder<IsarBenchmarkLink, String, QQueryOperations> typeIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'typeId');
    });
  }
}
