import 'record_types.dart';

/// The canonical Universal Record shape behind Research Studio.
///
/// Research has always been a Universal Record: `research-entry` (with its
/// selectable `research` alias) existed as a bare child of `general-lore`
/// before Research Studio had a workspace. This file gives that same type its
/// research fields instead of introducing a second research model — the ids,
/// the `research` category, and the `general-lore` base are unchanged, so
/// records written by the Story Codex, Analytics, and the importers keep
/// resolving exactly as they did.
///
/// Everything the Studio needs is a field on the canonical record:
///
/// * kind (Source / Note / Reference) -> [kindFieldId]
/// * author-facing category           -> [categoryFieldId]
/// * research lifecycle               -> [statusFieldId] + [AuthorRecordStatus]
/// * important / favourite            -> [importantFieldId]
///
/// The record's own `title`, `tags`, `createdAt`, and `updatedAt` carry the
/// rest, and `general-lore` already supplies `summary` and `notes`.
class ResearchRecordTypes {
  const ResearchRecordTypes._();

  /// The canonical research record type.
  static const baseTypeId = 'research-entry';

  /// The selectable alias the Codex offers when creating a record by hand.
  static const aliasTypeId = 'research';

  /// Every type id Research Studio treats as research.
  static const List<String> recordTypeIds = [baseTypeId, aliasTypeId];

  static const kindFieldId = 'researchKind';
  static const categoryFieldId = 'researchCategory';
  static const statusFieldId = 'researchStatus';
  static const importantFieldId = 'researchImportant';
  static const sourceUrlFieldId = 'sourceUrl';
  static const citationFieldId = 'citation';

  /// What sort of research entry this is. Drives the library's Sources /
  /// Notes / References shelves.
  static const List<String> kinds = ['Source', 'Note', 'Reference'];

  /// The kind a record carries when it does not name one — including every
  /// research-entry written before this Studio existed.
  static const defaultKind = 'Note';

  /// Author-facing subject categories.
  static const List<String> categories = [
    'World',
    'History',
    'Geography',
    'Culture',
    'Science',
    'Politics',
    'Religion',
    'Technology',
    'Character',
    'Setting',
    'Inspiration',
    'Other',
  ];

  /// The category a record carries when it does not name one.
  static const defaultCategory = 'Other';

  /// Research lifecycle states stored on the record.
  ///
  /// `Archived` is deliberately absent: archiving is a Universal Record
  /// lifecycle transition ([AuthorRecordStatus.archived]) that the shared
  /// [RecordService] already owns, so duplicating it here would give one
  /// concept two sources of truth. Read the combined state through
  /// `ResearchService.statusOf`.
  static const List<String> statuses = [
    'New',
    'In Progress',
    'Reviewed',
    'Verified',
  ];

  /// The status a record carries when it does not name one.
  static const defaultStatus = 'New';

  /// The state shown for records archived through the canonical lifecycle.
  static const archivedStatus = 'Archived';

  /// Every status an author can see, including the derived archived state.
  static const List<String> displayStatuses = [...statuses, archivedStatus];

  static const List<String> suggestedLinkTypeIds = [
    'documents',
    'relatedTo',
    'partOf',
  ];

  static final List<RecordTypeDefinition> definitions = [_entry, _alias];
}

const _entry = RecordTypeDefinition(
  id: ResearchRecordTypes.baseTypeId,
  name: 'Research Entry',
  description: 'A source, note, or reference in the author research library.',
  icon: 'menu_book',
  categoryId: 'research',
  baseTypeId: 'general-lore',
  fields: [
    RecordFieldDefinition(
      id: ResearchRecordTypes.kindFieldId,
      label: 'Kind',
      type: RecordFieldType.singleChoice,
      order: 100,
      defaultValue: ResearchRecordTypes.defaultKind,
      options: ResearchRecordTypes.kinds,
      description: 'Whether this entry is a source, a note, or a reference.',
    ),
    RecordFieldDefinition(
      id: ResearchRecordTypes.categoryFieldId,
      label: 'Category',
      type: RecordFieldType.singleChoice,
      order: 101,
      defaultValue: ResearchRecordTypes.defaultCategory,
      options: ResearchRecordTypes.categories,
      description: 'The subject area this research belongs to.',
    ),
    RecordFieldDefinition(
      id: ResearchRecordTypes.statusFieldId,
      label: 'Research status',
      type: RecordFieldType.singleChoice,
      order: 102,
      defaultValue: ResearchRecordTypes.defaultStatus,
      options: ResearchRecordTypes.statuses,
    ),
    RecordFieldDefinition(
      id: ResearchRecordTypes.importantFieldId,
      label: 'Important',
      type: RecordFieldType.boolean,
      order: 103,
      defaultValue: false,
      description: 'Marks the entry so it surfaces in the Important shelf.',
    ),
    RecordFieldDefinition(
      id: ResearchRecordTypes.sourceUrlFieldId,
      label: 'Source link',
      type: RecordFieldType.url,
      order: 104,
    ),
    RecordFieldDefinition(
      id: ResearchRecordTypes.citationFieldId,
      label: 'Citation',
      type: RecordFieldType.shortText,
      order: 105,
    ),
  ],
  sections: [
    RecordTemplateSection(
      id: 'research',
      title: 'Research',
      order: 10,
      fieldIds: [
        ResearchRecordTypes.kindFieldId,
        ResearchRecordTypes.categoryFieldId,
        ResearchRecordTypes.statusFieldId,
        ResearchRecordTypes.importantFieldId,
      ],
    ),
    RecordTemplateSection(
      id: 'researchSource',
      title: 'Source',
      order: 11,
      fieldIds: [
        ResearchRecordTypes.sourceUrlFieldId,
        ResearchRecordTypes.citationFieldId,
      ],
    ),
  ],
  suggestedLinkTypeIds: ResearchRecordTypes.suggestedLinkTypeIds,
  builtIn: true,
  sourcePackId: 'authoros-core',
  permissions: {'editableDefinition': false},
  extensionData: {'researchStudio': true},
);

/// The `research` alias stays exactly what it was — a selectable name for
/// [ResearchRecordTypes.baseTypeId] — and now inherits the research fields.
const _alias = RecordTypeDefinition(
  id: ResearchRecordTypes.aliasTypeId,
  name: 'Research',
  categoryId: 'research',
  baseTypeId: ResearchRecordTypes.baseTypeId,
  fields: [],
  sections: [],
  builtIn: true,
  sourcePackId: 'authoros-core',
  permissions: {'editableDefinition': false},
  extensionData: {'researchStudio': true},
);
