import 'connected_domain.dart';
import 'record_types.dart';

enum TemplateCompatibilityStatus {
  current,
  upgradeAvailable,
  newerThanDefinition,
  missingDefinition,
  incompatibleRecordType,
}

class TemplateCompatibilityReport {
  const TemplateCompatibilityReport({
    required this.status,
    required this.templateId,
    required this.recordVersion,
    this.availableVersion,
    this.missingRequiredFieldIds = const [],
  });

  final TemplateCompatibilityStatus status;
  final String templateId;
  final int recordVersion;
  final int? availableVersion;
  final List<String> missingRequiredFieldIds;

  bool get isReadable =>
      status != TemplateCompatibilityStatus.missingDefinition &&
      status != TemplateCompatibilityStatus.incompatibleRecordType;
}

class TemplateMigrationPlan {
  const TemplateMigrationPlan({
    required this.templateId,
    required this.fromVersion,
    required this.toVersion,
    required this.fieldsToAdd,
    required this.requiredFieldsNeedingValues,
  });

  final String templateId;
  final int fromVersion;
  final int toVersion;
  final List<RecordFieldDefinition> fieldsToAdd;
  final List<RecordFieldDefinition> requiredFieldsNeedingValues;

  bool get requiresAuthorInput => requiredFieldsNeedingValues.isNotEmpty;
}

class TemplateEngine {
  const TemplateEngine(this.registry);

  final RecordTypeRegistry registry;

  TemplateCompatibilityReport inspect(AuthorRecord record) {
    final templateId = record.templateId ?? record.typeId;
    final recordVersion = record.templateVersion ?? record.schemaVersion;
    RecordTypeDefinition definition;
    try {
      definition = registry.resolve(templateId);
    } on StateError {
      return TemplateCompatibilityReport(
        status: TemplateCompatibilityStatus.missingDefinition,
        templateId: templateId,
        recordVersion: recordVersion,
      );
    }
    if (!registry.isTemplateCompatible(templateId, record.typeId)) {
      return TemplateCompatibilityReport(
        status: TemplateCompatibilityStatus.incompatibleRecordType,
        templateId: templateId,
        recordVersion: recordVersion,
        availableVersion: definition.templateVersion,
      );
    }
    final missingRequired = definition.fields
        .where((field) => field.required && _isEmpty(record.fields[field.id]))
        .map((field) => field.id)
        .toList();
    final status = recordVersion < definition.templateVersion
        ? TemplateCompatibilityStatus.upgradeAvailable
        : recordVersion > definition.templateVersion
            ? TemplateCompatibilityStatus.newerThanDefinition
            : TemplateCompatibilityStatus.current;
    return TemplateCompatibilityReport(
      status: status,
      templateId: templateId,
      recordVersion: recordVersion,
      availableVersion: definition.templateVersion,
      missingRequiredFieldIds: missingRequired,
    );
  }

  TemplateMigrationPlan planMigration(AuthorRecord record) {
    final report = inspect(record);
    if (!report.isReadable || report.availableVersion == null) {
      throw StateError('Template ${report.templateId} is not compatible.');
    }
    final definition = registry.resolve(report.templateId);
    final missing = definition.fields
        .where((field) => !record.fields.containsKey(field.id))
        .toList();
    return TemplateMigrationPlan(
      templateId: report.templateId,
      fromVersion: report.recordVersion,
      toVersion: definition.templateVersion,
      fieldsToAdd: missing,
      requiredFieldsNeedingValues: missing
          .where((field) => field.required && field.defaultValue == null)
          .toList(),
    );
  }
}

bool _isEmpty(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is Iterable && value.isEmpty) ||
    (value is Map && value.isEmpty);
