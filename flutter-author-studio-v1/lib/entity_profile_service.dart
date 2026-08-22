import 'canon_conflict_service.dart';
import 'core/book_scope.dart';
import 'core/canon_facts.dart';
import 'core/connected_domain.dart';
import 'core/entity_recognition.dart';
import 'core/record_inspection.dart';
import 'core/record_inspector.dart';
import 'core/record_types.dart';
import 'core/record_service.dart';
import 'entity_profile.dart';
import 'entity_suggestions.dart';
import 'persistence/authoros_database.dart';
import 'series_service.dart';

/// Assembles one entity's profile and its usage across the whole series.
///
/// A read composition. Every part already has an owner — the inspector owns
/// connections and references, [SeriesService] owns books, the analyzer owns
/// contradictions — and this puts them on one page without owning any of them.
/// Nothing here writes.
class EntityProfileService {
  const EntityProfileService({
    required this.projectId,
    required this.repository,
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);

  SeriesService get series =>
      SeriesService(projectId: projectId, repository: repository);

  CanonConflictAnalyzer get conflicts =>
      CanonConflictAnalyzer(projectId: projectId, repository: repository);

  EntitySuggestionService get suggestions =>
      EntitySuggestionService(projectId: projectId, repository: repository);

  /// Everywhere [recordId] is used, grouped by book.
  ///
  /// The manuscript structure is read from `manuscript_node_rows`, never
  /// through `ManuscriptStore.loadStudio` — that seeds a starter manuscript on
  /// a project nobody has opened, and a usage report must not be able to invent
  /// a chapter just by looking.
  Future<EntityUsageReport?> usageFor(String recordId) async {
    final inspection = await inspector.inspectRecord(recordId);
    if (inspection == null) return null;

    final nodes = await repository.manuscriptNodesByProject(projectId);
    final nodesById = {for (final node in nodes) node.id: node};
    final books = await series.books(includeArchived: true);
    final states = await series.entityStatesFor(recordId);
    final appearances = {
      for (final link in await repository.outgoingLinks(recordId))
        if (link.typeId == BookScope.appearsInTypeId) link.targetId: link,
    };

    // Bucket the manuscript references by the chapter they sit under, and each
    // chapter by the book that claims it.
    final scenesByChapter = <String, List<ReferenceInspection>>{};
    final chapterRefs = <String, ReferenceInspection>{};
    final ghosts = <String>[];
    final other = <ReferenceKind, List<ReferenceInspection>>{};

    for (final reference in inspection.references) {
      switch (reference.kind) {
        case ReferenceKind.scene:
          final node = nodesById[reference.entity.id];
          if (node == null) {
            ghosts.add(reference.entity.id);
            continue;
          }
          final chapterId = node.extensionData['chapterId']?.toString();
          if (chapterId == null || chapterId.isEmpty) {
            ghosts.add(reference.entity.id);
            continue;
          }
          (scenesByChapter[chapterId] ??= []).add(reference);
        case ReferenceKind.chapter:
          if (!nodesById.containsKey(reference.entity.id)) {
            ghosts.add(reference.entity.id);
            continue;
          }
          chapterRefs[reference.entity.id] = reference;
        default:
          (other[reference.kind] ??= []).add(reference);
      }
    }

    final touchedChapters = <String>{
      ...scenesByChapter.keys,
      ...chapterRefs.keys,
    };
    final chaptersByBook = <String?, List<ChapterUsage>>{};
    for (final chapterId in touchedChapters) {
      final node = nodesById[chapterId];
      final bookId = node == null
          ? null
          : node.extensionData[BookScope.chapterBookKey]?.toString();
      (chaptersByBook[bookId == null || bookId.isEmpty ? null : bookId] ??= [])
          .add(ChapterUsage(
        chapterId: chapterId,
        chapterTitle: node?.title ?? chapterId,
        scenes: scenesByChapter[chapterId] ?? const [],
        reference: chapterRefs[chapterId],
      ));
    }

    final bookUsages = <BookUsage>[];
    for (final book in books) {
      final chapters = chaptersByBook[book.id] ?? const <ChapterUsage>[];
      final state = states.where((each) => each.bookId == book.id).firstOrNull;
      final usage = BookUsage(
        bookId: book.id,
        bookTitle: book.title,
        order: (book.fields['order'] as num?)?.toInt() ?? 0,
        chapters: chapters,
        appearance: appearances[book.id],
        stateRecordId: state?.id,
      );
      if (usage.isEmpty && state == null) continue;
      bookUsages.add(usage);
    }

    return EntityUsageReport(
      recordId: recordId,
      books: bookUsages,
      unfiledChapters: chaptersByBook[null] ?? const [],
      groups: [
        for (final entry in other.entries)
          UsageGroup(kind: entry.key, references: entry.value),
      ],
      derived: await _derivedUsage(recordId, nodesById),
      ghostNodeIds: ghosts,
    );
  }

  /// Names in the prose that point at [recordId] but that nothing links.
  ///
  /// Returned separately from the recorded usage above, never merged with it.
  /// A derived relationship is a suggestion; presenting it beside a recorded
  /// one would blur what the author has actually decided.
  Future<List<DerivedUsage>> _derivedUsage(
    String recordId,
    Map<String, ManuscriptNodeReference> nodesById,
  ) async {
    final record = await records.getRecord(recordId);
    if (record == null) return const [];
    final index = EntityNameIndex.fromRecords([record]);
    if (index.names.isEmpty) return const [];

    final connected = <String>{
      for (final link in await repository.backlinks(recordId))
        link.sourceId == recordId ? link.targetId : link.sourceId,
    };
    final dismissed = await suggestions.dismissedKeys();

    final derived = <DerivedUsage>[];
    for (final node in nodesById.values) {
      if (node.nodeType != 'scene') continue;
      if (connected.contains(node.id)) continue;
      final prose = [
        node.title,
        node.extensionData['notes']?.toString() ?? '',
      ].where((part) => part.trim().isNotEmpty).join('\n');
      // Scene prose lives outside the graph, so only what the node itself
      // carries is visible here. The manuscript-side scan sees the full text.
      final mentions = index.scan(prose, limit: 1);
      if (mentions.isEmpty) continue;
      final mention = mentions.single;
      if (dismissed.contains('${node.id}|${mention.matchedName.toLowerCase()}')) {
        continue;
      }
      derived.add(DerivedUsage(
        nodeId: node.id,
        nodeTitle: node.title,
        matchedName: mention.matchedName,
        snippet: prose,
        bookId: BookScope.bookOfNode(node, nodesById),
      ));
    }
    return derived;
  }

  /// Everything [recordId] is, on one page.
  Future<EntityProfile?> profileFor(String recordId) async {
    final record = await records.getRecord(recordId);
    if (record == null) return null;
    final inspection = await inspector.inspectRecord(recordId);
    if (inspection == null) return null;

    final usage = await usageFor(recordId) ??
        EntityUsageReport(
          recordId: recordId,
          books: const [],
          unfiledChapters: const [],
          groups: const [],
          derived: const [],
        );
    final report = await conflicts.analyze(recordId);
    final registry = await records.registry();
    final seriesRecord = await series.series();
    final booksFor = await series.booksFor(recordId);

    final titles = <String, String>{};
    for (final connection in [
      ...inspection.outgoingConnections,
      ...inspection.incomingConnections,
    ]) {
      titles[connection.source.id] = connection.source.title;
      titles[connection.target.id] = connection.target.title;
    }

    List<ProfileEntry> connectionsMatching(Set<String> typeIds) => [
          for (final connection in inspection.outgoingConnections)
            if (typeIds.contains(connection.typeId))
              ProfileEntry(
                label: connection.displayName,
                detail: connection.target.title,
                recordId: connection.target.id,
              ),
          for (final connection in inspection.incomingConnections)
            if (typeIds.contains(connection.typeId))
              ProfileEntry(
                label: connection.inverseLabel.isEmpty
                    ? connection.displayName
                    : connection.inverseLabel,
                detail: connection.source.title,
                recordId: connection.source.id,
              ),
        ];

    const relationshipTypes = {
      'friendOf', 'enemyOf', 'alliedWith', 'rivalOf', 'partnerOf', 'parentOf',
      'guardianOf', 'mentors', 'protects', 'employs', 'trusts', 'distrusts',
      'memberOf', 'knows',
    };
    const locationTypes = {
      'livesIn', 'bornIn', 'worksIn', 'visits', 'currentlyAt', 'previouslyAt',
      'homeAt', 'safehouseAt', 'locatedIn', 'occursAt',
    };
    const timelineTypes = {
      'involves', 'presentAt', 'occursDuring', 'witnessed', 'participatedIn',
    };
    const researchTypes = {'documents', 'explainedIn', 'confirmedIn'};

    final sections = <ProfileSection>[
      ProfileSection(
        id: 'relationships',
        title: 'Relationships',
        entries: connectionsMatching(relationshipTypes),
      ),
      ProfileSection(
        id: 'locations',
        title: 'Locations',
        entries: connectionsMatching(locationTypes),
      ),
      ProfileSection(
        id: 'timeline',
        title: 'Timeline',
        entries: connectionsMatching(timelineTypes),
      ),
      ProfileSection(
        id: 'appearances',
        title: 'Appearances',
        entries: [
          for (final book in usage.books)
            ProfileEntry(
              label: book.bookTitle,
              detail: book.sceneCount == 0
                  ? 'listed'
                  : '${book.sceneCount} '
                      '${book.sceneCount == 1 ? 'scene' : 'scenes'}',
              recordId: book.bookId,
            ),
        ],
      ),
      ProfileSection(
        id: 'research',
        title: 'Research',
        entries: connectionsMatching(researchTypes),
      ),
      ProfileSection(
        id: 'notes',
        title: 'Notes',
        entries: [
          if ((record.fields['notes']?.toString() ?? '').trim().isNotEmpty)
            ProfileEntry(label: record.fields['notes'].toString()),
        ],
      ),
    ];

    final status = report.isClean
        ? CanonFields.fromRecordStatus(record.canonStatus)
        : CanonFactStatus.contradicted;

    return EntityProfile(
      record: record,
      typeName: _typeName(registry, record.typeId),
      aliases: EntityNames.aliasesOf(record),
      sections: sections,
      usage: usage,
      canonStatus: status,
      confidence: canonConfidence(
        CanonFact(
          recordId: recordId,
          fieldId: '',
          value: record.title,
          status: CanonFields.fromRecordStatus(record.canonStatus),
          sourceCount: EntityNames.split(record.fields['sourceReferences'])
              .length,
          agreeingStateCount: 0,
          contradictionCount: report.findings.length,
        ),
      ),
      conflictCount: report.findings.length,
      seriesTitle: seriesRecord?.title,
      bookTitles: booksFor.map((book) => book.title).toList(),
    );
  }

  String _typeName(RecordTypeRegistry registry, String typeId) {
    try {
      return registry.resolve(typeId).name;
    } on StateError {
      return typeId;
    }
  }
}
