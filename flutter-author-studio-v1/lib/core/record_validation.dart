import 'connected_domain.dart';
import 'record_types.dart';

enum RecordValidationSeverity { warning, error }

class RecordValidationIssue {
  const RecordValidationIssue({
    required this.code,
    required this.message,
    this.fieldId,
    this.severity = RecordValidationSeverity.error,
  });

  final String code;
  final String message;
  final String? fieldId;
  final RecordValidationSeverity severity;
}

class RecordValidationResult {
  const RecordValidationResult(this.issues);

  final List<RecordValidationIssue> issues;

  bool get isValid =>
      !issues.any((issue) => issue.severity == RecordValidationSeverity.error);
  List<RecordValidationIssue> get errors => issues
      .where((issue) => issue.severity == RecordValidationSeverity.error)
      .toList();
  List<RecordValidationIssue> get warnings => issues
      .where((issue) => issue.severity == RecordValidationSeverity.warning)
      .toList();
}

class RecordValidationException implements Exception {
  const RecordValidationException(this.result);

  final RecordValidationResult result;

  @override
  String toString() =>
      'Record validation failed: ${result.errors.map((issue) => issue.message).join(' ')}';
}

class RecordValidator {
  const RecordValidator(this.registry);

  final RecordTypeRegistry registry;

  RecordValidationResult validate(
    AuthorRecord record, {
    required String projectId,
  }) {
    final issues = <RecordValidationIssue>[];
    if (record.id.trim().isEmpty) {
      issues.add(const RecordValidationIssue(
        code: 'missing-id',
        message: 'Record id is required.',
      ));
    }
    if (record.title.trim().isEmpty) {
      issues.add(const RecordValidationIssue(
        code: 'missing-title',
        message: 'Record title is required.',
        fieldId: 'title',
      ));
    }
    if (record.scopeId.trim().isEmpty) {
      issues.add(const RecordValidationIssue(
        code: 'missing-scope',
        message: 'Record scope id is required.',
      ));
    }
    final owningProjectId = record.projectId ??
        record.fields['projectId'] ??
        record.fields['_codex.projectId'];
    if (record.scopeId != projectId && owningProjectId != projectId) {
      issues.add(RecordValidationIssue(
        code: 'project-mismatch',
        message: 'Record ${record.id} does not belong to project $projectId.',
      ));
    }
    try {
      RecordScope(
        type: record.scopeType,
        id: record.scopeId,
        projectId: owningProjectId is String ? owningProjectId : projectId,
        seriesId:
            record.seriesId ?? (record.fields['_codex.seriesId'] as String?),
        bookId: record.bookId ?? (record.fields['_codex.bookId'] as String?),
        branchId:
            record.branchId ?? (record.fields['_codex.branchId'] as String?),
      ).validate();
    } on FormatException catch (error) {
      issues.add(RecordValidationIssue(
        code: 'invalid-scope-hierarchy',
        message: error.message,
      ));
    }

    RecordTypeDefinition? definition;
    try {
      registry.resolve(record.typeId);
    } on StateError {
      issues.add(RecordValidationIssue(
        code: 'unknown-record-type',
        message: 'Unknown record type: ${record.typeId}.',
      ));
    }
    final templateId = record.templateId ?? record.typeId;
    try {
      definition = registry.resolve(templateId);
    } on StateError {
      issues.add(RecordValidationIssue(
        code: 'unknown-template',
        message: 'Unknown record template: $templateId.',
      ));
    }
    if (definition == null) {
      return RecordValidationResult(issues);
    }
    if (!registry.isTemplateCompatible(templateId, record.typeId)) {
      issues.add(RecordValidationIssue(
        code: 'incompatible-template',
        message:
            'Template $templateId is not compatible with ${record.typeId}.',
      ));
    }
    if (!definition.allowedScopeTypes.contains(record.scopeType)) {
      issues.add(RecordValidationIssue(
        code: 'invalid-scope',
        message:
            '${definition.name} records cannot use ${record.scopeType.name} scope.',
      ));
    }
    final recordTemplateVersion =
        record.templateVersion ?? record.schemaVersion;
    if (recordTemplateVersion > definition.templateVersion) {
      issues.add(RecordValidationIssue(
        code: 'schema-mismatch',
        message: 'Record template version $recordTemplateVersion is newer than '
            '${definition.name} template version ${definition.templateVersion}.',
      ));
    }
    for (final field in definition.fields) {
      final value = field.extensionData['recordProperty'] == 'title'
          ? record.title
          : record.fields[field.id];
      if (field.required && _isEmpty(value)) {
        issues.add(RecordValidationIssue(
          code: 'missing-required-field',
          message: '${field.label} is required.',
          fieldId: field.id,
        ));
      } else if (!_isEmpty(value) && !_matchesType(field, value)) {
        issues.add(RecordValidationIssue(
          code: 'invalid-field-type',
          message: '${field.label} has an invalid value.',
          fieldId: field.id,
        ));
      }
    }
    return RecordValidationResult(issues);
  }
}

bool _isEmpty(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is Iterable && value.isEmpty) ||
    (value is Map && value.isEmpty);

bool _matchesType(RecordFieldDefinition field, Object? value) =>
    switch (field.type) {
      RecordFieldType.number || RecordFieldType.rating => value is num,
      RecordFieldType.boolean => value is bool,
      RecordFieldType.multipleChoice ||
      RecordFieldType.tags ||
      RecordFieldType.list ||
      RecordFieldType.table ||
      RecordFieldType.checklist =>
        value is List,
      RecordFieldType.singleChoice =>
        value is String && field.options.contains(value),
      _ => value is String,
    };
