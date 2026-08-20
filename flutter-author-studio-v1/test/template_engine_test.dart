import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/core/template_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('template upgrade is reported and planned without mutating the record',
      () {
    const character = RecordTypeDefinition(
      id: 'character',
      name: 'Character',
      categoryId: 'characters',
      templateVersion: 2,
      fields: [
        RecordFieldDefinition(
          id: 'name',
          label: 'Name',
          type: RecordFieldType.shortText,
          order: 0,
          required: true,
        ),
      ],
      sections: [],
    );
    const protagonist = RecordTypeDefinition(
      id: 'protagonist',
      name: 'Protagonist',
      categoryId: 'characters',
      baseTypeId: 'character',
      templateVersion: 3,
      fields: [
        RecordFieldDefinition(
          id: 'centralGoal',
          label: 'Central goal',
          type: RecordFieldType.longText,
          order: 1,
          required: true,
        ),
      ],
      sections: [],
    );
    final engine = TemplateEngine(
      RecordTypeRegistry([character, protagonist]),
    );
    final timestamp = DateTime.utc(2026, 8, 19);
    final record = AuthorRecord(
      id: 'kali',
      typeId: 'character',
      templateId: 'protagonist',
      templateVersion: 1,
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      title: 'Kali Vale',
      fields: const {'name': 'Kali Vale', 'legacyField': 'preserved'},
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    final report = engine.inspect(record);
    final plan = engine.planMigration(record);

    expect(report.status, TemplateCompatibilityStatus.upgradeAvailable);
    expect(report.availableVersion, 3);
    expect(report.missingRequiredFieldIds, ['centralGoal']);
    expect(plan.fieldsToAdd.map((field) => field.id), ['centralGoal']);
    expect(plan.requiresAuthorInput, isTrue);
    expect(record.fields, {
      'name': 'Kali Vale',
      'legacyField': 'preserved',
    });
    expect(record.templateVersion, 1);
  });

  test('missing and incompatible templates remain explicit', () {
    const location = RecordTypeDefinition(
      id: 'location',
      name: 'Location',
      categoryId: 'locations',
      fields: [],
      sections: [],
    );
    final engine = TemplateEngine(RecordTypeRegistry([location]));
    final timestamp = DateTime.utc(2026, 8, 19);

    expect(
      engine
          .inspect(AuthorRecord(
            id: 'missing',
            typeId: 'location',
            templateId: 'unknown-template',
            scopeType: RecordScopeType.project,
            scopeId: 'project-a',
            title: 'Missing',
            createdAt: timestamp,
            updatedAt: timestamp,
          ))
          .status,
      TemplateCompatibilityStatus.missingDefinition,
    );
    expect(
      engine
          .inspect(AuthorRecord(
            id: 'wrong-type',
            typeId: 'character',
            templateId: 'location',
            scopeType: RecordScopeType.project,
            scopeId: 'project-a',
            title: 'Wrong Type',
            createdAt: timestamp,
            updatedAt: timestamp,
          ))
          .status,
      TemplateCompatibilityStatus.incompatibleRecordType,
    );
  });
}
