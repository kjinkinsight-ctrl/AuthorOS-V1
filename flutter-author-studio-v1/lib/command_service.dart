/// The Command System's executor.
///
/// [CommandService] answers a parsed [CommandQuery] by composing the read
/// surfaces AuthorOS already has: [StoryGraphService] for the graph,
/// [UniversalSearchService] for text, [PlotQueryService] for the story-status
/// questions Plot Studio already knows how to ask. It owns no storage, builds
/// no index, and defines no second notion of a node or an edge.
///
/// It lives at the service layer rather than in `core/` because it reaches
/// Studio services, and `core/` may not.
///
/// **Every read here is a read.** The manuscript is reached through the graph's
/// projection of `manuscript_node_rows`, never through
/// `ManuscriptStore.loadStudio`, because loading the manuscript *writes* — it
/// seeds and reconciles the projection as a side effect. A navigation query
/// that quietly changed the project would be a bad bargain.
library;

import 'core/command_grammar.dart';
import 'core/command_query.dart';
import 'core/connected_domain.dart';
import 'core/connection_types.dart';
import 'core/record_service.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/search_models.dart';
import 'core/story_graph.dart';
import 'core/story_graph_service.dart';
import 'core/universal_search.dart';
import 'map_domain.dart';
import 'persistence/authoros_database.dart';
import 'plot_service.dart';

/// How many rows one command may show.
///
/// Mirrors [UniversalSearchFilter.limit]'s intent: a navigation layer answers
/// questions, it does not page an entire project into a dialog.
const commandResultLimit = 200;

/// How many nodes one command may *examine*.
///
/// Deliberately far above [commandResultLimit] and above
/// [kStoryGraphDefaultMaxNodes]. A negative question — "characters not yet
/// assigned to a plot" — is only correct if every character was looked at, so
/// the scan cap and the display cap are different numbers for different
/// reasons. When the scan is truncated the result says so rather than quietly
/// answering from a sample.
const commandScanLimit = 5000;

class CommandService {
  CommandService({required this.projectId, required this.repository});

  final String projectId;
  final DriftConnectedDomainRepository repository;

  CommandVocabulary? _vocabulary;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);

  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);

  StoryGraphService get graph =>
      StoryGraphService(projectId: projectId, repository: repository);

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

    final workspace = await _load(query);
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
      // "Show me Kali" names a thing without naming a relationship. The author
      // wants the thing itself, and — because this is a navigation layer —
      // what sits around it.
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
    final workspace = await _load(CommandQuery(text: phrase));
    final node = await _resolveAnchor(phrase, workspace, anchorId: entityId);
    if (node == null) return null;
    return CommandEntity(
      id: node.id,
      title: node.title,
      typeId: node.typeId,
      typeLabel: workspace.typeLabel(node),
      isManuscriptNode: node.kind == StoryGraphNodeKind.manuscriptNode,
      candidates: node.candidates,
    );
  }

  // ----------------------------------------------------------------- filters

  /// The graph filter a command implies.
  ///
  /// Wildcard edges and `relatedTo` are opt-in for a graph *view*, where 73 of
  /// ~130 types would swamp the picture. A command is the opposite case: an
  /// author who types "everything connected to Kali" means everything, and
  /// silently dropping more than half the edge vocabulary would make the answer
  /// wrong. Naming a relationship narrows it back down, and
  /// [StoryGraphFilter.allowsEdgeType] lets an explicit type win over both
  /// switches.
  StoryGraphFilter _filterFor(
    CommandQuery query, {
    Set<String> edgeTypeIds = const {},
  }) =>
      StoryGraphFilter(
        edgeTypeIds: edgeTypeIds,
        includeArchived: query.hasPredicate(CommandPredicateKind.archived),
        includeRelatedTo: true,
        includeWildcardEdges: true,
      );

  Set<String> _edgeTypesFor(CommandQuery query) {
    final relation = query.relation;
    return relation == null || relation.isAny
        ? const <String>{}
        : <String>{relation.typeId!};
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
    final context = await _context(query, workspace);
    final rows = <CommandRow>[];
    for (final node in workspace.nodes) {
      if (!_matchesSubject(node, query.subject)) continue;
      if (!await _keep(node, query, workspace, context)) continue;
      rows.add(_row(node, workspace));
    }
    return _result(query, rows, workspace);
  }

  /// Everything reachable from an anchor in one hop.
  ///
  /// A chapter is asked about together with its scenes, so the traversal runs
  /// once per id in [_Workspace.anchorScope] and the results are merged.
  Future<CommandResult> _traverse(
    CommandQuery query,
    StoryGraphNode anchor,
    _Workspace workspace,
  ) async {
    final context = await _context(query, workspace);
    final filter = _filterFor(query, edgeTypeIds: _edgeTypesFor(query));
    final anchorIds = workspace.anchorScope(anchor.id);
    final seen = <String>{...anchorIds};
    final rows = <CommandRow>[];

    for (final anchorId in anchorIds) {
      final hood = await graph.getNeighbours(
        anchorId,
        filter: filter,
        maxNodes: commandScanLimit,
      );
      if (hood == null) continue;
      final labelByNeighbour = <String, String>{
        for (final edge in hood.edges)
          edge.otherEnd(anchorId): workspace.relationLabel(edge.typeId),
      };
      for (final neighbour in hood.neighbours) {
        if (!seen.add(neighbour.id)) continue;
        if (!_matchesSubject(neighbour, query.subject)) continue;
        if (!await _keep(neighbour, query, workspace, context)) continue;
        rows.add(_row(
          neighbour,
          workspace,
          subtitle: labelByNeighbour[neighbour.id] ?? '',
        ));
      }
    }

    if (rows.isEmpty) {
      return CommandResult(
        query: query,
        message: 'Nothing is connected to ${anchor.title} yet.',
      );
    }
    return _result(query, rows, workspace);
  }

  /// One named thing, and what surrounds it.
  Future<CommandResult> _show(
    CommandQuery query,
    StoryGraphNode anchor,
    _Workspace workspace,
  ) async {
    final hood = await graph.getNeighbours(
      anchor.id,
      filter: _filterFor(query),
      maxNodes: commandScanLimit,
    );
    final subject = _row(anchor, workspace);
    final connected = <CommandRow>[];
    if (hood != null) {
      final labels = <String, String>{
        for (final edge in hood.edges)
          edge.otherEnd(anchor.id): workspace.relationLabel(edge.typeId),
      };
      for (final neighbour in hood.neighbours) {
        connected.add(
          _row(neighbour, workspace, subtitle: labels[neighbour.id] ?? ''),
        );
      }
    }

    return CommandResult(
      query: query,
      groups: [
        CommandGroup(label: subject.typeLabel, rows: [subject]),
        if (connected.isNotEmpty)
          CommandGroup(label: 'Connected', rows: connected),
      ],
      message: hood?.truncated ?? false
          ? 'Showing the first ${hood!.neighbours.length} connections.'
          : '',
    );
  }

  /// The canon-conflict report.
  ///
  /// Composed from checks that already exist rather than a new analyzer:
  /// shared record validation, Plot Studio's structural validation, and two
  /// reads over the raw link table. Each Studio's own continuity intelligence
  /// stays where it is — this is the cross-cutting view, not a replacement.
  Future<CommandResult> _conflicts(
    CommandQuery query,
    _Workspace workspace,
  ) async {
    final rows = <CommandRow>[];

    for (final node in workspace.nodes) {
      final record = node.record;
      if (record == null) continue;
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

    // Read raw rather than through the graph. Every other command wants the
    // graph's view — nodes that exist, edges worth drawing. A conflict report
    // wants exactly what that view excludes: the edge whose endpoint is gone.
    final links = await repository.linksByScope(projectId);

    // A canon record joined to a record its project has ruled out of canon is
    // the contradiction an author most wants surfaced.
    for (final link in links) {
      final source = workspace.recordFor(link.sourceId);
      final target = workspace.recordFor(link.targetId);
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
    for (final link in links) {
      for (final endpointId in [link.sourceId, link.targetId]) {
        if (await graph.getNode(endpointId) != null) continue;
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
          issue.recordId == null ? null : workspace.recordFor(issue.recordId!);
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
    return CommandResult(query: query, groups: _group(rows));
  }

  // ------------------------------------------------------------- predicates

  /// Whether [node] is the kind of thing the query asked about.
  ///
  /// Both node kinds answer here: a subject may name record types, manuscript
  /// node types, or both, and [StoryGraphNode.typeId] is the record type or the
  /// manuscript node type accordingly.
  bool _matchesSubject(StoryGraphNode node, CommandSubject subject) =>
      switch (node.kind) {
        StoryGraphNodeKind.record => subject.matchesRecordType(node.typeId),
        StoryGraphNodeKind.manuscriptNode =>
          subject.includesNodes && subject.matchesNodeType(node.typeId),
      };

  Future<bool> _keep(
    StoryGraphNode node,
    CommandQuery query,
    _Workspace workspace,
    _Context context,
  ) async {
    final record = node.record;
    for (final predicate in query.predicates) {
      switch (predicate.kind) {
        case CommandPredicateKind.unresolved:
          if (!context.unresolvedIds.contains(node.id)) return false;
        case CommandPredicateKind.resolved:
          if (record == null || !_isResolved(record)) return false;
        case CommandPredicateKind.active:
          if (record == null || !_isActive(record)) return false;
        case CommandPredicateKind.canon:
          if (node.canonStatus != CanonStatus.canon) return false;
        case CommandPredicateKind.draft:
          if (node.canonStatus != CanonStatus.draft &&
              node.canonStatus != CanonStatus.proposed) {
            return false;
          }
        case CommandPredicateKind.archived:
          if (node.lifecycleStatus != AuthorRecordStatus.archived) return false;
        case CommandPredicateKind.onMap:
          if (record == null || !_isOnMap(record)) return false;
        case CommandPredicateKind.inBook:
          if (record == null || !context.inBook(record)) return false;
        case CommandPredicateKind.missingRelation:
          if (workspace.hasNeighbourIn(node.id, predicate.target)) return false;
          // A scene can name its location in prose without ever linking it.
          // Both have to be empty before the scene is "missing" one.
          if (_mentionsInProse(node, predicate.target)) return false;
        case CommandPredicateKind.before:
          final position = workspace.positionOf(node);
          if (position == null || position >= (context.orderCut ?? -1)) {
            return false;
          }
        case CommandPredicateKind.after:
          final position = workspace.positionOf(node);
          if (position == null || position <= (context.orderCut ?? 1 << 30)) {
            return false;
          }
      }
    }
    return true;
  }

  /// A scene's free-text `location` field is a second, older way of saying
  /// where it happens. "Scenes with no location" has to respect both.
  bool _mentionsInProse(StoryGraphNode node, CommandSubject? target) {
    final reference = node.manuscriptNode;
    if (target == null || reference == null) return false;
    if (!target.recordTypeIds.contains('location') &&
        !target.recordTypeIds.contains('place')) {
      return false;
    }
    final value = reference.extensionData['location'];
    return value is String && value.trim().isNotEmpty;
  }

  Future<_Context> _context(CommandQuery query, _Workspace workspace) async {
    int? orderCut;
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
              for (final node in workspace.nodes)
                if (node.record?.bookId == bookId) node.id,
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
    for (final node in workspace.nodes) {
      final record = node.record;
      if (record == null) continue;
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
    if (ordinal != null) return ordinal.number;
    final normalized = phrase.toLowerCase().trim();
    for (final node in workspace.nodes) {
      if (node.title.toLowerCase() == normalized) {
        return workspace.orderOf(node);
      }
    }
    return null;
  }

  String? _bookIdFor(String? phrase, _Workspace workspace) {
    if (phrase == null) return null;
    final normalized = phrase.toLowerCase().trim();
    final books = <AuthorRecord>[
      for (final node in workspace.nodes)
        if (node.record?.typeId == 'book') node.record!,
    ]..sort((left, right) => left.title.compareTo(right.title));
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

  Future<StoryGraphNode?> _resolveAnchor(
    String phrase,
    _Workspace workspace, {
    String? anchorId,
  }) async {
    if (anchorId != null) return graph.getNode(anchorId);

    // "Chapter 20" is an ordinal, not a title. Manuscript nodes carry their
    // position, so this is the reading to try first.
    final ordinal = _ordinal(phrase);
    if (ordinal != null && ordinal.kind != 'book') {
      for (final node in workspace.nodes) {
        if (node.kind != StoryGraphNodeKind.manuscriptNode) continue;
        if (node.typeId != ordinal.kind) continue;
        if (workspace.orderOf(node) == ordinal.number) return node;
      }
    }

    final normalized = phrase.toLowerCase().trim();
    final exact = [
      for (final node in workspace.nodes)
        if (node.title.toLowerCase() == normalized) node,
    ];
    if (exact.length == 1) return exact.single;
    if (exact.length > 1) return _ambiguous(exact, workspace);

    final hits = await search.searchAll(phrase);
    final found = <StoryGraphNode>[
      for (final hit in hits)
        if (workspace.nodeById[hit.recordId] != null)
          workspace.nodeById[hit.recordId]!,
    ];
    if (found.isEmpty) return null;
    if (found.length == 1) return found.single;
    return _ambiguous(found.take(8).toList(), workspace);
  }

  /// A stand-in node carrying the candidates the author must choose between.
  StoryGraphNode _ambiguous(
    List<StoryGraphNode> options,
    _Workspace workspace,
  ) =>
      _AmbiguousAnchor(
        options.first,
        [
          for (final option in options)
            CommandCandidate(
              id: option.id,
              title: option.title,
              typeLabel: workspace.typeLabel(option),
            ),
        ],
      );

  // ------------------------------------------------------------------- rows

  CommandRow _row(
    StoryGraphNode node,
    _Workspace workspace, {
    String subtitle = '',
  }) {
    final record = node.record;
    final order = workspace.orderOf(node);
    return CommandRow(
      id: node.id,
      title: node.title,
      kind: node.kind == StoryGraphNodeKind.record
          ? CommandRowKind.record
          : CommandRowKind.manuscriptNode,
      typeLabel: workspace.typeLabel(node),
      subtitle: subtitle.isNotEmpty
          ? subtitle
          : record != null
              ? record.canonStatus.name
              : (order == null ? '' : '${workspace.typeLabel(node)} $order'),
      navigationTarget: record != null
          ? _targetForRecord(record)
          : SearchNavigationTarget(
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
  ) {
    if (rows.isEmpty) {
      return CommandResult(query: query, message: 'Nothing matches that yet.');
    }
    final capped = rows.length > commandResultLimit;
    final shown = capped ? rows.take(commandResultLimit).toList() : rows;
    final notices = <String>[
      if (capped) 'Showing the first $commandResultLimit of ${rows.length}.',
      if (workspace.truncated)
        'This project is larger than one command can scan, so some entries '
            'were not examined.',
    ];
    return CommandResult(
      query: query,
      groups: _group(shown),
      message: notices.join(' '),
    );
  }

  /// Groups by the same buckets the Connection Explorer uses, so the console
  /// and the graph name the parts of a story the same way.
  List<CommandGroup> _group(List<CommandRow> rows) {
    final grouped = <String, List<CommandRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.typeLabel, () => []).add(row);
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

  Future<_Workspace> _load(CommandQuery query) async {
    final subgraph = await graph.getProjectGraph(
      filter: _filterFor(query),
      maxNodes: commandScanLimit,
    );
    return _Workspace(
      subgraph: subgraph,
      registry: await records.registry(),
      connections: await records.connectionRegistry(),
    );
  }
}

/// Everything one command needs, read once.
///
/// Nodes arrive already unified across the two kinds and already stripped of
/// the record types that describe the graph rather than take part in it, so
/// nothing here re-derives what [StoryGraphService] settled.
class _Workspace {
  _Workspace({
    required this.subgraph,
    required this.registry,
    required this.connections,
  }) {
    for (final node in subgraph.nodes) {
      nodeById[node.id] = node;
    }
    for (final edge in subgraph.edges) {
      _byEntity.putIfAbsent(edge.sourceId, () => []).add(edge);
      _byEntity.putIfAbsent(edge.targetId, () => []).add(edge);
    }
  }

  final StorySubgraph subgraph;
  final RecordTypeRegistry registry;
  final ConnectionTypeRegistry connections;

  final Map<String, StoryGraphNode> nodeById = {};
  final Map<String, List<StoryGraphEdge>> _byEntity = {};

  List<StoryGraphNode> get nodes => subgraph.nodes;

  bool get truncated => subgraph.truncated;

  AuthorRecord? recordFor(String id) => nodeById[id]?.record;

  Iterable<String> neighbourIds(String entityId) sync* {
    for (final edge in _byEntity[entityId] ?? const <StoryGraphEdge>[]) {
      yield edge.otherEnd(entityId);
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
      final node = nodeById[otherId];
      if (node == null) continue;
      final matches = switch (node.kind) {
        StoryGraphNodeKind.record => target.matchesRecordType(node.typeId),
        StoryGraphNodeKind.manuscriptNode => target.matchesNodeType(node.typeId),
      };
      if (matches) return true;
    }
    return false;
  }

  /// Every entity a question about [entityId] should really reach.
  ///
  /// Characters do not appear in chapters; they appear in the scenes a chapter
  /// contains. "Characters appearing in Chapter 20" therefore has to ask the
  /// chapter *and its scenes*, or it answers nothing while looking correct.
  Set<String> anchorScope(String entityId) {
    final scope = <String>{entityId};
    final anchor = nodeById[entityId];
    if (anchor?.typeId != 'chapter') return scope;
    for (final node in nodes) {
      if (node.manuscriptNode?.extensionData['chapterId'] == entityId) {
        scope.add(node.id);
      }
    }
    return scope;
  }

  int? orderOf(StoryGraphNode node) {
    final value = node.manuscriptNode?.extensionData['order'];
    return value is int ? value : (value is num ? value.toInt() : null);
  }

  /// Where a node sits in the manuscript.
  ///
  /// A chapter or scene answers from its own position. Anything else answers
  /// from the earliest scene or chapter it is attached to, and a record with no
  /// manuscript connection has no position at all — it is excluded from
  /// "before"/"after" rather than guessed at, because inventing an order would
  /// be the one thing worse than leaving it out.
  int? positionOf(StoryGraphNode node) {
    if (node.kind == StoryGraphNodeKind.manuscriptNode) {
      return node.typeId == 'scene' ? _chapterOrderForScene(node) : orderOf(node);
    }
    int? earliest;
    for (final otherId in neighbourIds(node.id)) {
      final other = nodeById[otherId];
      if (other == null || other.kind != StoryGraphNodeKind.manuscriptNode) {
        continue;
      }
      final order = other.typeId == 'scene'
          ? _chapterOrderForScene(other)
          : orderOf(other);
      if (order == null) continue;
      if (earliest == null || order < earliest) earliest = order;
    }
    return earliest;
  }

  int? _chapterOrderForScene(StoryGraphNode scene) {
    final chapterId = scene.manuscriptNode?.extensionData['chapterId'];
    if (chapterId is! String) return null;
    final chapter = nodeById[chapterId];
    return chapter == null ? null : orderOf(chapter);
  }

  String typeLabel(StoryGraphNode node) {
    if (node.kind == StoryGraphNodeKind.manuscriptNode) {
      return _titleCase(node.typeId);
    }
    try {
      return registry.resolve(node.typeId).name;
    } on StateError {
      return _titleCase(node.typeId.replaceAll('-', ' '));
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

/// A resolved anchor that turned out to name more than one thing.
///
/// Modelled as a [StoryGraphNode] so the resolution path has one return type,
/// with the candidates carried alongside for the console to offer.
class _AmbiguousAnchor extends StoryGraphNode {
  _AmbiguousAnchor(StoryGraphNode first, this.candidates)
      : super(
          id: first.id,
          kind: first.kind,
          typeId: first.typeId,
          categoryId: first.categoryId,
          title: first.title,
          projectId: first.projectId,
          versioned: first.versioned,
          deletable: first.deletable,
          canonStatus: first.canonStatus,
          lifecycleStatus: first.lifecycleStatus,
          record: first.record,
          manuscriptNode: first.manuscriptNode,
        );

  final List<CommandCandidate> candidates;
}

extension _AnchorCandidates on StoryGraphNode {
  List<CommandCandidate> get candidates =>
      this is _AmbiguousAnchor ? (this as _AmbiguousAnchor).candidates : const [];
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
