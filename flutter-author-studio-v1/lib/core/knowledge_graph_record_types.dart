/// The record behind Canvas mode.
///
/// A canvas is the author's own arrangement of entities, so it is content, not
/// camera state — and content belongs in a record. Making it an ordinary
/// [AuthorRecord] means it is versioned, audited, archived, exported and synced
/// for free, and it means the graph still adds **no table**: the
/// `exactly one persistence system` guardrail passes unchanged, which is what
/// proves invariant I-15 held through this milestone.
///
/// This is the same precedent map markers already set (invariant I-11):
/// author-authored coordinates are *record fields owned by the feature*, never
/// edge data and never a second store.
///
/// The rule that keeps a canvas honest: **it stores positions and entity ids
/// only, never edges.** Relationships are always read live from
/// `record_link_rows`, so a canvas cannot drift out of step with the truth, and
/// invariant I-13 — one edge table, ever — is not at risk.
library;

import 'record_types.dart';

class KnowledgeGraphRecordTypes {
  const KnowledgeGraphRecordTypes._();

  /// The canonical canvas record type.
  static const canvasTypeId = 'knowledge-canvas';

  /// Which mode the canvas was arranged in, so it reopens as it was left.
  static const modeFieldId = 'canvasMode';

  /// The arranged nodes: a list of `{entityId, x, y}` maps.
  static const nodesFieldId = 'canvasNodes';

  /// The filter that was active, serialised.
  static const filterFieldId = 'canvasFilter';

  /// The node the canvas was centred on.
  static const rootFieldId = 'canvasRoot';

  static const List<String> recordTypeIds = [canvasTypeId];

  /// The deterministic id for a project's canvas in a given mode.
  ///
  /// One canvas per (project, mode) keeps the feature predictable: switching
  /// mode and back returns the arrangement you left, and nothing accumulates
  /// untitled canvases behind the author's back.
  static String canvasId(String projectId, String modeId) =>
      'knowledge-canvas-$projectId-$modeId';

  static final List<RecordTypeDefinition> definitions = [_canvas];
}

const _canvas = RecordTypeDefinition(
  id: KnowledgeGraphRecordTypes.canvasTypeId,
  name: 'Knowledge Canvas',
  description: 'A hand-arranged board of records from the Knowledge Graph.',
  icon: 'dashboard_customize',
  // `custom` rather than a category of its own: a canvas is a workspace
  // artefact, not a new kind of story entity, and it should not appear as a
  // filterable node category in the graph it describes.
  categoryId: 'custom',
  baseTypeId: 'general-lore',
  fields: [
    RecordFieldDefinition(
      id: KnowledgeGraphRecordTypes.modeFieldId,
      label: 'Mode',
      type: RecordFieldType.shortText,
      order: 100,
      description: 'The graph mode this arrangement belongs to.',
    ),
    RecordFieldDefinition(
      id: KnowledgeGraphRecordTypes.rootFieldId,
      label: 'Centred on',
      type: RecordFieldType.recordReference,
      order: 101,
    ),
    RecordFieldDefinition(
      id: KnowledgeGraphRecordTypes.nodesFieldId,
      label: 'Arranged nodes',
      type: RecordFieldType.list,
      order: 102,
      description: 'Entity ids and their positions. Never relationships — '
          'those are read live from the edge table.',
    ),
    RecordFieldDefinition(
      id: KnowledgeGraphRecordTypes.filterFieldId,
      label: 'Filter',
      type: RecordFieldType.longText,
      order: 103,
    ),
  ],
  sections: [
    RecordTemplateSection(
      id: 'canvas',
      title: 'Canvas',
      order: 10,
      fieldIds: [
        KnowledgeGraphRecordTypes.modeFieldId,
        KnowledgeGraphRecordTypes.rootFieldId,
        KnowledgeGraphRecordTypes.nodesFieldId,
      ],
    ),
  ],
  builtIn: true,
  sourcePackId: 'authoros-core',
  permissions: {'editableDefinition': false},
  extensionData: {'knowledgeGraph': true},
);
