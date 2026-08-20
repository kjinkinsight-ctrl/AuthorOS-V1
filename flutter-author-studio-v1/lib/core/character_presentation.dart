import 'connected_domain.dart';
import 'record_types.dart';

class CharacterPresentationField {
  const CharacterPresentationField({
    required this.definition,
    required this.value,
  });

  final RecordFieldDefinition definition;
  final Object? value;

  bool get hasValue =>
      value != null &&
      (!(value is String) || (value as String).trim().isNotEmpty) &&
      (!(value is Iterable) || (value as Iterable).isNotEmpty) &&
      (!(value is Map) || (value as Map).isNotEmpty);
}

class CharacterPresentationSection {
  const CharacterPresentationSection({
    required this.id,
    required this.title,
    required this.order,
    required this.collapsedByDefault,
    required this.connectionBacked,
    required this.fields,
  });

  final String id;
  final String title;
  final int order;
  final bool collapsedByDefault;
  final bool connectionBacked;
  final List<CharacterPresentationField> fields;

  bool get hasData => fields.any((field) => field.hasValue);
}

class CharacterPresentationModel {
  const CharacterPresentationModel({
    required this.recordId,
    required this.title,
    required this.templateId,
    required this.templateVersion,
    required this.sections,
  });

  final String recordId;
  final String title;
  final String templateId;
  final int templateVersion;
  final List<CharacterPresentationSection> sections;

  factory CharacterPresentationModel.fromRecord(
    AuthorRecord character,
    RecordTypeRegistry registry,
  ) {
    if (character.typeId != 'character') {
      throw StateError('${character.id} is not a character.');
    }
    final templateId = character.templateId ?? 'character';
    final template = registry.resolve(templateId);
    final visible = template.extensionData['visibleSections'];
    final visibleSectionIds = visible is List
        ? visible.map((value) => value.toString()).toSet()
        : null;
    final fields = {for (final field in template.fields) field.id: field};
    final sections = template.sections
        .where((section) =>
            visibleSectionIds == null || visibleSectionIds.contains(section.id))
        .map(
          (section) => CharacterPresentationSection(
            id: section.id,
            title: section.title,
            order: section.order,
            collapsedByDefault: section.collapsedByDefault,
            connectionBacked: section.extensionData['connectionBacked'] == true,
            fields: section.fieldIds
                .where(fields.containsKey)
                .map(
                  (fieldId) => CharacterPresentationField(
                    definition: fields[fieldId]!,
                    value: character.fields[fieldId],
                  ),
                )
                .toList(),
          ),
        )
        .toList()
      ..sort((left, right) => left.order.compareTo(right.order));
    return CharacterPresentationModel(
      recordId: character.id,
      title: character.title,
      templateId: templateId,
      templateVersion: character.templateVersion ?? template.templateVersion,
      sections: List.unmodifiable(sections),
    );
  }
}
