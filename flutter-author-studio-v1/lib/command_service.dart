/// The Command System's executor.
///
/// [CommandService] answers a parsed [CommandQuery] by composing the query
/// surfaces AuthorOS already has — [UniversalSearchService] for text,
/// [RecordGraph] and the link table for connections, [PlotQueryService] for the
/// story-status questions Plot Studio already knows how to ask. It owns no
/// storage, builds no index and defines no second notion of a relationship.
///
/// It lives at the service layer rather than in `core/` because it reaches
/// Studio services, and `core/` may not.
///
/// **Every read here is a read.** Manuscript scenes and chapters are taken from
/// [DriftConnectedDomainRepository.manuscriptNodesByProject], never through
/// `ManuscriptStore.loadStudio`, because loading the manuscript *writes* — it
/// seeds manuscript nodes as a side effect. A navigation query that quietly
/// changed the project would be a bad bargain.
library;

import 'core/command_grammar.dart';
import 'core/command_query.dart';
import 'core/connected_domain.dart';
import 'core/connection_types.dart';
import 'core/record_graph.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/search_models.dart';
import 'core/universal_search.dart';
import 'map_domain.dart';
import 'persistence/authoros_database.dart';
import 'plot_service.dart';

/// How many rows one command may return.
///
/// Mirrors [UniversalSearchFilter.limit]'s intent: a navigation layer answers
/// questions, it does not page an entire project into a dialog.
const commandResultLimit = 200;

class CommandService {
  CommandService({required this.projectId, required this.repository});

  final String projectId;
  final DriftConnectedDomainRepository repository;

  CommandVocabulary? _vocabulary;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);

  RecordGraph get graph =>
      RecordGraph(projectId: projectId, repository: repository);

  PlotService get plot =>
      PlotService(projectId: projectId, repository: repository);

  /// The phrase table, derived once from the project's live registries.
  ///
  /// Memoised per service instance: building it walks every record type pair,
  /// and the answer only changes when a custom type is registered.
  Future<CommandVocabulary> vocabulary() async => _vocabulary ??=
      CommandVocabulary.fromRegistries(
        records: await records.registry(),
        connections: await records.connectionRegistry(),
      );

  Future<CommandQuery> parse(String text) async =>
      CommandGrammar(await vocabulary()).parse(text);

  Future<CommandResult> run(String text) async => execute(await parse(text));

  /// Answers [query].
  ///
  /// [anchorId] is how the console resolves an ambiguity: the author picked one
  /// of the candidates a previous run offered, and the same query is re-run
  /// against that entity.
  Future<CommandResult> execute(CommandQuery query, {String? anchorId}) async {
    if (query.isFreeText) return _freeText(query);
    if (query.isAction) {
      return CommandResult(
        query: query,
        message: 'This command changes your project. '
            'Review it before it runs.',
      );
    }

    final workspace = await _load();
    if (query.subject.isReport) return _conflicts(query, workspace);

    if (query.hasAnchor) {
      final anchor = await _resolveAnchor(
        query.anchorPhrase!,
        workspace,
        anchorId: anchorId,
      );
      if (anchor == null) {
        return CommandResult(
          query: query,
          message: 'Nothing in this project is called '
              '"${query.anchorPhrase}".',
        );
      }
      if (anchor.candidates.isNotEmpty) {
        return CommandResult(
          query: query,
          candidates: anchor.candidates,
          candidatePrompt:
              'More than one thing is called "${query.anchorPhrase}". '
              'Which did you mean?',
        );
      }
      // "Show me Kali" names a thing without naming a relationship. The
      // author wants the thing itself, and — because this is a navigation
      // layer — what sits around it.
      if (query.relation == null && query.subject.everything) {
        return _show(query, anchor, workspace);
      }
      return _traverse(query, anchor, workspace);
    }

    return _list(query, workspace);
  }

  /// Resolves a name the way a query does.
  ///
  /// Shared with the action layer so that "link Kali to Endovier" and "show
  /// everything connected to Kali" can never disagree about who Kali is.
  Future<CommandEntity?> resolveEntity(
    String phrase, {
    String? entityId,
  }) async {
    final workspace = await _load();
    final anchor =
        await _resolveAnchor(phrase, workspace, anchorId: entityId);
    return anchor?.toEntity();
  }

  // ------------------------------------------------------------------ modes

  /// A phrase the grammar could not read. Not a failure — the author almost
  /// certainly wanted to search for it.
  Future<CommandResult> _freeText(CommandQuery query) async {
    final hits = await search.searchAll(query.text);
    if (hits.isEmpty) {
      return CommandResult(
        query: query,
        message: 'Nothing matches "${query.text}".',
      );
    }
    return CommandResult(
      query: query,
      groups: [
        CommandGroup(
          label: 'Matches',
          rows: hits
              .take(commandResultLimit)
              .map(
                (hit) => CommandRow(
                  id: hit.recordId,
                  title: hit.title,
                  kind: CommandRowKind.record,
                  typeLabel: hit.category ?? hit.recordType,
                  subtitle: hit.snippet,
                  navigationTarget: hit.navigationTarget,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// Everything of a kind, narrowed by the query's predicates.
  Future<CommandResult> _list(
    CommandQuery query,
    _Workspace workspace,
  ) async {
    final rows = <CommandRow>[];
    final context = await _context(query, workspace);

    for (final record in workspace.records) {
      if (!query.subject.matchesRecordType(record.typeId)) continue;
      if (!_visible(record, query)) continue;
      if (!await _keepRecord(record, query, workspace, context)) continue;
      rows.add(_recordRow(record, workspace));
    }
    for (final node in workspace.nodes) {
      if (!query.subject.includesNodes) continue;
      if (!query.subject.matchesNodeType(node.nodeType)) continue;
      if (!_keepNode(node, query, workspace, context)) continue;
      rows.add(_nodeRow(node, workspace));
    }

    return _result(query, rows, workspace, context);
  }

  /// Everything reachable from an anchor in one hop.
  ///
  /// This walks the link index directly rather than calling
  /// [RecordGraph.related], because that method resolves far endpoints with
  /// `recordById` and so silently drops scenes and chapters. The Command System
  /// is the first surface that has to show both node kinds, and an answer that
  /// quietly omitted half the story would be worse than no answer.
  Future<CommandResult> _traverse(
    CommandQuery query,
    _Anchor anchor,
    _Workspace workspace,
  ) async {
    final relation = query.relation ?? CommandRelation.any;
    final context = await _context(query, workspace);
    final rows = <CommandRow>[];
    final anchorIds = workspace.anchorScope(anchor.id);
    final seen = <String>{...anchorIds};

    for (final link in workspace.linksForAll(anchorIds)) {
      if (!relation.matches(link.typeId)) continue;
      final otherId =
          anchorIds.contains(link.sourceId) ? link.targetId : link.sourceId;
      if (!seen.add(otherId)) continue;
      final relationLabel = workspace.relationLabel(link.typeId);

      final record = workspace.recordById[otherId];
      if (record != null) {
        if (!query.subject.matchesRecordType(record.typeId)) continue;
        if (!_visible(record, query)) continue;
        if (!await _keepRecord(record, query, workspace, context)) continue;
        rows.add(_recordRow(record, workspace, subtitle: relationLabel));
        continue;
      }

      final node = workspace.nodeById[otherId];
      if (node == null) continue;
      if (!query.subject.matchesNodeType(node.nodeType)) continue;
      if (!_keepNode(node, query, workspace, context)) continue;
      rows.add(_nodeRow(node, workspace, subtitle: relationLabel));
    }

    if (rows.isEmpty) {
      return CommandResult(
        query: query,
        message: 'Nothing is connected to ${anchor.title} yet.',
      );
    }
    return _result(query, rows, workspace, context, anchor: anchor);
  }

  /// One named thing, and what surrounds it.
  Future<CommandResult> _show(
    CommandQuery query,
    _Anchor anchor,
    _Workspace workspace,
  ) async {
    final record = workspace.recordById[anchor.id];
    final node = workspace.nodeById[anchor.id];
    final subject = record != null
        ? _recordRow(record, workspace)
        : _nodeRow(node!, workspace);

    final connected = <CommandRow>[];
    final seen = <String>{anchor.id};
    for (final link in workspace.linksFor(anchor.id)) {
      final otherId = link.sourceId == anchor.id ? link.targetId : link.sourceId;
      if (!seen.add(otherId)) continue;
      final label = workspace.relationLabel(link.typeId);
      final other = workspace.recordById[otherId];
      if (other != null) {
        if (other.status == AuthorRecordStatus.deleted) continue;
        connected.add(_recordRow(other, workspace, subtitle: label));
        continue;
      }
      final otherNode = workspace.nodeById[otherId];
      if (otherNode != null) {
        connected.add(_nodeRow(otherNode, workspace, subtitle: label));
      }
    }

    return CommandResult(
      query: query,
      groups: [
        CommandGroup(label: subject.typeLabel, rows: [subject]),
        if (connected.isNotEmpty)
          CommandGroup(label: 'Connected', rows: connected),
      ],
    );
  }

  /// The canon-conflict report.
  ///
  /// Composed from checks that already exist rather than a new analyzer:
  /// shared record validation, Plot Studio's structural validation, and two
  /// pure reads over the link table. Each Studio's own continuity intelligence
  /// stays where it is — this is the cross-cutting view, not a replacement.
  Future<CommandResult> _conflicts(
    CommandQuery query,
    _Workspace workspace,
  ) async {
    final rows = <CommandRow>[];

    for (final record in workspace.records) {
      if (record.status == AuthorRecordStatus.deleted) continue;
      final result = await records.validateRecord(record);
      for (final issue in result.issues) {
        rows.add(
          CommandRow(
            id: '${record.id}:${issue.code}',
            title: record.title,
            kind: CommandRowKind.issue,
            typeLabel: issue.severity == RecordValidationSeverity.error
                ? 'Error'
                : 'Warning',
            subtitle: issue.code,
            detail: issue.message,
            navigationTarget: _targetForRecord(record),
          ),
        );
      }
    }

    // A canon record joined to a record its project has ruled out of canon is
    // the contradiction an author most wants surfaced, and it is a pure read.
    for (final link in workspace.links) {
      final source = workspace.recordById[link.sourceId];
      final target = workspace.recordById[link.targetId];
      if (source == null || target == null) continue;
      final conflicted = _isCanon(source) && _isOutOfCanon(target) ||
          _isCanon(target) && _isOutOfCanon(source);
      if (!conflicted) continue;
      rows.add(
        CommandRow(
          id: link.id,
          title: '${source.title} → ${target.title}',
          kind: CommandRowKind.issue,
          typeLabel: 'Canon',
          subtitle: workspace.relationLabel(link.typeId),
          detail: '${source.title} is ${source.canonStatus.name} and '
              '${target.title} is ${target.canonStatus.name}.',
          navigationTarget: _targetForRecord(source),
        ),
      );
    }

    // An edge pointing at something neither store can resolve.
    for (final link in workspace.links) {
      for (final endpointId in [link.sourceId, link.targetId]) {
        if (workspace.recordById.containsKey(endpointId) ||
            workspace.nodeById.containsKey(endpointId)) {
          continue;
        }
        rows.add(
          CommandRow(
            id: '${link.id}:$endpointId',
            title: 'Connection points at something that is gone',
            kind: CommandRowKind.issue,
            typeLabel: 'Reference',
            subtitle: workspace.relationLabel(link.typeId),
            detail: 'The ${workspace.relationLabel(link.typeId)} connection '
                '${link.id} references $endpointId, which no longer exists.',
          ),
        );
      }
    }

    for (final issue in await plot.validatePlot()) {
      final record =
          issue.recordId == null ? null : workspace.recordById[issue.recordId];
      rows.add(
        CommandRow(
          id: '${issue.recordId ?? 'plot'}:${issue.code}',
          title: record?.title ?? 'Plot structure',
          kind: CommandRowKind.issue,
          typeLabel: issue.isError ? 'Error' : 'Plot',
          subtitle: issue.code,
          detail: issue.message,
          navigationTarget: record == null ? null : _targetForRecord(record),
        ),
      );
    }

    if (rows.isEmpty) {
      return CommandResult(
        query: query,
        message: 'No canon conflicts. Everything agrees with everything else.',
      );
    }
    return CommandResult(
      query: query,
      groups: _group(rows, byTypeLabel: true),
    );
  }

  // ------------------------------------------------------------- predicates

  bool _visible(AuthorRecord record, CommandQuery query) {
    if (record.status == AuthorRecordStatus.deleted) return false;
    if (record.status == AuthorRecordStatus.archived) {
      return query.hasPredicate(CommandPredicateKind.archived);
    }
    return true;
  }

  Future<bool> _keepRecord(
    AuthorRecord record,
    CommandQuery query,
    _Workspace workspace,
    _Context context,
  ) async {
    for (final predicate in query.predicates) {
      switch (predicate.kind) {
        case CommandPredicateKind.unresolved:
          if (!context.unresolvedIds.contains(record.id)) return false;
        case CommandPredicateKind.resolved:
          if (!_isResolved(record)) return false;
        case CommandPredicateKind.active:
          if (!_isActive(record)) return false;
        case CommandPredicateKind.canon:
          if (!_isCanon(record)) return false;
        case CommandPredicateKind.draft:
          if (record.canonStatus != CanonStatus.draft &&
              record.canonStatus != CanonStatus.proposed) {
            return false;
          }
        case CommandPredicateKind.archived:
          if (record.status != AuthorRecordStatus.archived) return false;
        case CommandPredicateKind.onMap:
          if (!_isOnMap(record)) return false;
        case CommandPredicateKind.inBook:
          if (!context.inBook(record)) return false;
        case CommandPredicateKind.missingRelation:
          if (workspace.hasNeighbourIn(record.id, predicate.target)) {
            return false;
          }
        case CommandPredicateKind.before:
          final position = workspace.manuscriptPosition(record.id);
          if (position == null || position >= (context.orderCut ?? -1)) {
            return false;
          }
        case CommandPredicateKind.after:
          final position = workspace.manuscriptPosition(record.id);
          if (position == null || position <= (context.orderCut ?? 1 << 30)) {
            return false;
          }
      }
    }
    return true;
  }

  bool _keepNode(
    ManuscriptNodeReference node,
    CommandQuery query,
    _Workspace workspace,
    _Context context,
  ) {
    for (final predicate in query.predicates) {
      switch (predicate.kind) {
        case CommandPredicateKind.missingRelation:
          if (workspace.hasNeighbourIn(node.id, predicate.target)) return false;
          // A scene can name its location in prose without ever linking it.
          // Both have to be empty before the scene is "missing" one.
          if (_nodeMentions(node, predicate.target)) return false;
        case CommandPredicateKind.before:
          final position = workspace.nodeOrder(node);
          if (position == null || position >= (context.orderCut ?? -1)) {
            return false;
          }
        case CommandPredicateKind.after:
          final position = workspace.nodeOrder(node);
          if (position == null || position <= (context.orderCut ?? 1 << 30)) {
            return false;
          }
        case CommandPredicateKind.archived:
          return false;
        case CommandPredicateKind.unresolved:
        case CommandPredicateKind.resolved:
        case CommandPredicateKind.active:
        case CommandPredicateKind.canon:
        case CommandPredicateKind.draft:
        case CommandPredicateKind.onMap:
        case CommandPredicateKind.inBook:
          // Record-only facets. A node neither passes nor fails them; it is
          // simply not the kind of thing being asked about.
          return false;
      }
    }
    return true;
  }

  /// A scene's free-text `location` field is a second, older way of saying
  /// where it happens. "Scenes with no location" has to respect both.
  bool _nodeMentions(ManuscriptNodeReference node, CommandSubject? target) {
    if (target == null) return false;
    if (!target.recordTypeIds.contains('location') &&
        !target.recordTypeIds.contains('place')) {
      return false;
    }
    final value = node.extensionData['location'];
    return value is String && value.trim().isNotEmpty;
  }

  Future<_Context> _context(CommandQuery query, _Workspace workspace) async {
    var orderCut = <int?>[null].first;
    String? bookId;
    final unresolvedIds = <String>{};

    for (final predicate in query.predicates) {
      switch (predicate.kind) {
        case CommandPredicateKind.before:
        case CommandPredicateKind.after:
          orderCut = _orderOf(predicate.anchorPhrase, workspace);
        case CommandPredicateKind.inBook:
          bookId = _bookIdFor(predicate.anchorPhrase, workspace);
        case CommandPredicateKind.unresolved:
          unresolvedIds.addAll(await _unresolvedIds(query.subject, workspace));
        default:
          break;
      }
    }
    return _Context(
      orderCut: orderCut,
      bookId: bookId,
      mapIdsInBook: bookId == null
          ? const <String>{}
          : {
              for (final record in workspace.records)
                if (record.bookId == bookId) record.id,
            },
      unresolvedIds: unresolvedIds,
    );
  }

  /// "Unresolved" as Plot Studio already defines it.
  ///
  /// The field test mirrors `plot_service.dart`: a record is resolved when its
  /// `plotStatus` says so, and an unmarked thread is still open. Foreshadowing
  /// is different — whether a setup is unresolved is a question about links,
  /// not fields — so that case is left to the service that owns it.
  Future<Set<String>> _unresolvedIds(
    CommandSubject subject,
    _Workspace workspace,
  ) async {
    final ids = <String>{};
    for (final record in workspace.records) {
      if (!subject.matchesRecordType(record.typeId)) continue;
      if (!_isResolved(record)) ids.add(record.id);
    }
    if (subject.matchesRecordType('foreshadowing')) {
      for (final setup in await plot.query.unresolvedSetups()) {
        ids.add(setup.id);
      }
    }
    return ids;
  }

  int? _orderOf(String? phrase, _Workspace workspace) {
    if (phrase == null) return null;
    final ordinal = _ordinal(phrase);
    if (ordinal != null) {
      for (final node in workspace.nodes) {
        if (node.nodeType != ordinal.kind) continue;
        if (workspace.nodeOrder(node) == ordinal.number) return ordinal.number;
      }
      return ordinal.number;
    }
    final normalized = phrase.toLowerCase().trim();
    for (final node in workspace.nodes) {
      if (node.title.toLowerCase() == normalized) {
        return workspace.nodeOrder(node);
      }
    }
    return null;
  }

  String? _bookIdFor(String? phrase, _Workspace workspace) {
    if (phrase == null) return null;
    final normalized = phrase.toLowerCase().trim();
    final books = workspace.records
        .where((record) => record.typeId == 'book')
        .toList()
      ..sort((left, right) => left.title.compareTo(right.title));
    for (final book in books) {
      if (book.title.toLowerCase() == normalized) return book.id;
    }
    final ordinal = _ordinal(phrase);
    if (ordinal != null &&
        ordinal.number >= 1 &&
        ordinal.number <= books.length) {
      return books[ordinal.number - 1].id;
    }
    return null;
  }

  // ----------------------------------------------------------------- anchors

  Future<_Anchor?> _resolveAnchor(
    String phrase,
    _Workspace workspace, {
    String? anchorId,
  }) async {
    if (anchorId != null) {
      final record = workspace.recordById[anchorId];
      if (record != null) return _anchorForRecord(record, workspace);
      final node = workspace.nodeById[anchorId];
      if (node != null) return _anchorForNode(node);
    }

    // "Chapter 20" is an ordinal, not a title. Manuscript nodes carry their
    // position, so this is the reading to try first.
    final ordinal = _ordinal(phrase);
    if (ordinal != null && ordinal.kind != 'book') {
      for (final node in workspace.nodes) {
        if (node.nodeType != ordinal.kind) continue;
        if (workspace.nodeOrder(node) == ordinal.number) {
          return _anchorForNode(node);
        }
      }
    }

    final normalized = phrase.toLowerCase().trim();
    final exact = <_Anchor>[];
    for (final record in workspace.records) {
      if (record.status == AuthorRecordStatus.deleted) continue;
      if (record.title.toLowerCase() == normalized) {
        exact.add(_anchorForRecord(record, workspace));
      }
    }
    for (final node in workspace.nodes) {
      if (node.title.toLowerCase() == normalized) {
        exact.add(_anchorForNode(node));
      }
    }
    if (exact.length == 1) return exact.single;
    if (exact.length > 1) return _ambiguous(exact);

    final hits = await search.searchAll(phrase);
    final found = <_Anchor>[];
    for (final hit in hits) {
      final record = workspace.recordById[hit.recordId];
      if (record != null && record.status != AuthorRecordStatus.deleted) {
        found.add(_anchorForRecord(record, workspace));
        continue;
      }
      final node = workspace.nodeById[hit.recordId];
      if (node != null) found.add(_anchorForNode(node));
    }
    if (found.isEmpty) return null;
    if (found.length == 1) return found.single;
    return _ambiguous(found.take(8).toList());
  }

  _Anchor _anchorForRecord(AuthorRecord record, _Workspace workspace) =>
      _Anchor(
        id: record.id,
        title: record.title,
        typeId: record.typeId,
        typeLabel: workspace.typeLabel(record.typeId),
      );

  _Anchor _anchorForNode(ManuscriptNodeReference node) => _Anchor(
        id: node.id,
        title: node.title,
        typeId: node.nodeType,
        typeLabel: _titleCase(node.nodeType),
        isNode: true,
      );

  _Anchor _ambiguous(List<_Anchor> options) => _Anchor(
        id: options.first.id,
        title: options.first.title,
        typeId: options.first.typeId,
        typeLabel: options.first.typeLabel,
        isNode: options.first.isNode,
        candidates: options
            .map((option) => CommandCandidate(
                  id: option.id,
                  title: option.title,
                  typeLabel: option.typeLabel,
                ))
            .toList(),
      );

  // ------------------------------------------------------------------- rows

  CommandRow _recordRow(
    AuthorRecord record,
    _Workspace workspace, {
    String subtitle = '',
  }) =>
      CommandRow(
        id: record.id,
        title: record.title,
        kind: CommandRowKind.record,
        typeLabel: workspace.typeLabel(record.typeId),
        subtitle: subtitle.isNotEmpty ? subtitle : record.canonStatus.name,
        navigationTarget: _targetForRecord(record),
      );

  CommandRow _nodeRow(
    ManuscriptNodeReference node,
    _Workspace workspace, {
    String subtitle = '',
  }) {
    final order = workspace.nodeOrder(node);
    return CommandRow(
      id: node.id,
      title: node.title,
      kind: CommandRowKind.manuscriptNode,
      typeLabel: _titleCase(node.nodeType),
      subtitle: subtitle.isNotEmpty
          ? subtitle
          : (order == null ? '' : '${_titleCase(node.nodeType)} $order'),
      navigationTarget: SearchNavigationTarget(
        destination: SearchDestination.manuscriptStudio,
        recordId: node.id,
        projectId: node.projectId,
      ),
    );
  }

  SearchNavigationTarget _targetForRecord(AuthorRecord record) =>
      SearchNavigationTarget(
        destination: searchDestinationForType(record.typeId),
        recordId: record.id,
        projectId: record.projectId ?? record.scopeId,
        branchId: record.branchId,
      );

  CommandResult _result(
    CommandQuery query,
    List<CommandRow> rows,
    _Workspace workspace,
    _Context context, {
    _Anchor? anchor,
  }) {
    if (rows.isEmpty) {
      return CommandResult(
        query: query,
        message: 'Nothing matches that yet.',
      );
    }
    final capped = rows.length > commandResultLimit;
    final shown = capped ? rows.take(commandResultLimit).toList() : rows;
    return CommandResult(
      query: query,
      groups: _group(shown),
      message: capped
          ? 'Showing the first $commandResultLimit of ${rows.length}.'
          : '',
    );
  }

  List<CommandGroup> _group(List<CommandRow> rows, {bool byTypeLabel = true}) {
    final grouped = <String, List<CommandRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(byTypeLabel ? row.typeLabel : '', () => []).add(row);
    }
    final labels = grouped.keys.toList()..sort();
    return [
      for (final label in labels)
        CommandGroup(
          label: label,
          rows: grouped[label]!
            ..sort((left, right) =>
                left.title.toLowerCase().compareTo(right.title.toLowerCase())),
        ),
    ];
  }

  // ------------------------------------------------------------- workspace

  Future<_Workspace> _load() async {
    final registry = await records.registry();
    final connections = await records.connectionRegistry();
    return _Workspace(
      records: await repository.recordsByProject(projectId),
      nodes: await repository.manuscriptNodesByProject(projectId),
      links: await repository.linksByScope(projectId),
      registry: registry,
      connections: connections,
    );
  }
}

/// Everything one command needs, read once.
///
/// The links are loaded with a single [DriftConnectedDomainRepository.linksByScope]
/// call and indexed in memory rather than asking for one record's backlinks at a
/// time. A question like "characters not yet assigned to a plot" touches every
/// character; per-record queries would make it quadratic.
class _Workspace {
  _Workspace({
    required this.records,
    required this.nodes,
    required this.links,
    required this.registry,
    required this.connections,
  }) {
    for (final record in records) {
      recordById[record.id] = record;
    }
    for (final node in nodes) {
      nodeById[node.id] = node;
    }
    for (final link in links) {
      _byEntity.putIfAbsent(link.sourceId, () => []).add(link);
      _byEntity.putIfAbsent(link.targetId, () => []).add(link);
    }
  }

  final List<AuthorRecord> records;
  final List<ManuscriptNodeReference> nodes;
  final List<RecordLink> links;
  final RecordTypeRegistry registry;
  final ConnectionTypeRegistry connections;

  final Map<String, AuthorRecord> recordById = {};
  final Map<String, ManuscriptNodeReference> nodeById = {};
  final Map<String, List<RecordLink>> _byEntity = {};

  List<RecordLink> linksFor(String entityId) =>
      _byEntity[entityId] ?? const <RecordLink>[];

  /// Every entity a question about [entityId] should really reach.
  ///
  /// Characters do not appear in chapters; they appear in the scenes a chapter
  /// contains. "Characters appearing in Chapter 20" therefore has to ask the
  /// chapter *and its scenes*, or it answers nothing while looking correct.
  Set<String> anchorScope(String entityId) {
    final scope = <String>{entityId};
    final node = nodeById[entityId];
    if (node == null || node.nodeType != 'chapter') return scope;
    for (final candidate in nodes) {
      if (candidate.extensionData['chapterId'] == node.id) {
        scope.add(candidate.id);
      }
    }
    return scope;
  }

  Iterable<RecordLink> linksForAll(Set<String> entityIds) sync* {
    final seen = <String>{};
    for (final entityId in entityIds) {
      for (final link in linksFor(entityId)) {
        if (seen.add(link.id)) yield link;
      }
    }
  }

  Iterable<String> neighbourIds(String entityId) sync* {
    for (final link in linksFor(entityId)) {
      yield link.sourceId == entityId ? link.targetId : link.sourceId;
    }
  }

  /// Whether [entityId] is connected to anything in [target]'s family.
  ///
  /// Relationship type is deliberately not considered. Most connection types
  /// permit any endpoint pair, so "is there an edge of the right type" would
  /// answer a question nobody asked; "is this character attached to any plot at
  /// all" is what the author means.
  bool hasNeighbourIn(String entityId, CommandSubject? target) {
    if (target == null) return false;
    for (final otherId in neighbourIds(entityId)) {
      final record = recordById[otherId];
      if (record != null &&
          record.status != AuthorRecordStatus.deleted &&
          target.matchesRecordType(record.typeId)) {
        return true;
      }
      final node = nodeById[otherId];
      if (node != null && target.matchesNodeType(node.nodeType)) return true;
    }
    return false;
  }

  int? nodeOrder(ManuscriptNodeReference node) {
    final value = node.extensionData['order'];
    return value is int ? value : (value is num ? value.toInt() : null);
  }

  /// Where a record sits in the manuscript, taken from the earliest scene or
  /// chapter it is attached to.
  ///
  /// A record with no manuscript connection has no position. It is excluded
  /// from "before"/"after" rather than guessed at — inventing an order would be
  /// the one thing worse than leaving it out.
  int? manuscriptPosition(String entityId) {
    int? earliest;
    for (final otherId in neighbourIds(entityId)) {
      final node = nodeById[otherId];
      if (node == null) continue;
      final order = node.nodeType == 'scene'
          ? _chapterOrderForScene(node)
          : nodeOrder(node);
      if (order == null) continue;
      if (earliest == null || order < earliest) earliest = order;
    }
    return earliest;
  }

  int? _chapterOrderForScene(ManuscriptNodeReference scene) {
    final chapterId = scene.extensionData['chapterId'];
    if (chapterId is! String) return null;
    final chapter = nodeById[chapterId];
    return chapter == null ? null : nodeOrder(chapter);
  }

  String typeLabel(String typeId) {
    try {
      return registry.resolve(typeId).name;
    } on StateError {
      return _titleCase(typeId.replaceAll('-', ' '));
    }
  }

  String relationLabel(String typeId) {
    try {
      return connections.resolve(typeId).displayName;
    } on StateError {
      return _titleCase(typeId.replaceAll('-', ' '));
    }
  }
}

class _Context {
  const _Context({
    this.orderCut,
    this.bookId,
    this.mapIdsInBook = const {},
    this.unresolvedIds = const {},
  });

  /// The manuscript position "before"/"after" is measured against.
  final int? orderCut;

  final String? bookId;

  /// Maps that belong to the scoped book, so a location placed on one counts as
  /// used by that book even when the location itself is series-scoped.
  final Set<String> mapIdsInBook;

  final Set<String> unresolvedIds;

  bool inBook(AuthorRecord record) {
    if (bookId == null) return true;
    if (record.bookId == bookId) return true;
    final mapId = record.fields[MapFields.mapId];
    return mapId is String && mapIdsInBook.contains(mapId);
  }
}

class _Anchor {
  const _Anchor({
    required this.id,
    required this.title,
    this.typeId = '',
    this.typeLabel = '',
    this.isNode = false,
    this.candidates = const [],
  });

  final String id;
  final String title;
  final String typeId;
  final String typeLabel;
  final bool isNode;
  final List<CommandCandidate> candidates;

  CommandEntity toEntity() => CommandEntity(
        id: id,
        title: title,
        typeId: typeId,
        typeLabel: typeLabel,
        isManuscriptNode: isNode,
        candidates: candidates,
      );
}

class _Ordinal {
  const _Ordinal(this.kind, this.number);
  final String kind;
  final int number;
}

_Ordinal? _ordinal(String phrase) {
  final match = RegExp(r'^(chapter|scene|book)\s+(\d+)$', caseSensitive: false)
      .firstMatch(phrase.trim());
  if (match == null) return null;
  return _Ordinal(match.group(1)!.toLowerCase(), int.parse(match.group(2)!));
}

bool _isResolved(AuthorRecord record) {
  final status = '${record.fields['plotStatus'] ?? ''}'.toLowerCase();
  return status == 'resolved' || status == 'completed';
}

bool _isActive(AuthorRecord record) {
  final status = '${record.fields['plotStatus'] ?? ''}'.toLowerCase();
  return record.status == AuthorRecordStatus.active &&
      status != 'resolved' &&
      status != 'completed' &&
      status != 'abandoned';
}

bool _isCanon(AuthorRecord record) => record.canonStatus == CanonStatus.canon;

bool _isOutOfCanon(AuthorRecord record) =>
    record.canonStatus == CanonStatus.nonCanon ||
    record.canonStatus == CanonStatus.deprecated ||
    record.canonStatus == CanonStatus.alternate;

bool _isOnMap(AuthorRecord record) {
  final value = record.fields[MapFields.mapId];
  return value is String && value.trim().isNotEmpty;
}

String _titleCase(String value) => value
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
