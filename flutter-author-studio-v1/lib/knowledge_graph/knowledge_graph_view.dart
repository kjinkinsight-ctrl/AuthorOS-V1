/// Knowledge Graph — the Story Graph made visible.
///
/// The Studio owns no store, no theme and no business rules. Every read goes
/// through [StoryGraphService], every relationship write through
/// [StoryGraphMutations] (which itself only delegates to `ConnectionEngine`),
/// and every colour and type style resolves through the Theme Engine under
/// [StudioId.knowledgeGraph]. There are no literal colours here.
///
/// Camera and layout are presentation state and never reach a record. The one
/// exception is Canvas mode, where the author's own arrangement *is* content —
/// and that is stored as an ordinary `knowledge-canvas` record, not as a new
/// table and not as an edge.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/connected_domain.dart';
import '../core/search_models.dart';
import '../core/story_graph.dart';
import '../core/story_graph_modes.dart';
import '../core/story_graph_service.dart';
import '../core/universal_search.dart';
import '../persistence/authoros_database.dart';
import '../theme/flutter/authoros_theme.dart';
import '../theme/theme_tokens.dart';
import 'canvas_service.dart';
import 'graph_canvas.dart';
import 'graph_layout.dart';
import 'graph_side_panels.dart';

class KnowledgeGraphView extends StatefulWidget {
  const KnowledgeGraphView({
    super.key,
    required this.projectId,
    this.repository,
    this.service,
    this.onNavigate,
    this.initialNodeId,
  });

  final String projectId;

  /// Injected by tests; production uses the shared repository.
  final DriftConnectedDomainRepository? repository;

  /// Injected by tests that want to control the read model directly.
  final StoryGraphService? service;

  /// Studios never route themselves. This hands the shell a destination and
  /// the shell decides where it goes.
  final ValueChanged<SearchNavigationTarget>? onNavigate;

  /// Opens straight onto a node, for "show this in the graph" from elsewhere.
  final String? initialNodeId;

  @override
  State<KnowledgeGraphView> createState() => _KnowledgeGraphViewState();
}

class _KnowledgeGraphViewState extends State<KnowledgeGraphView> {
  late StoryGraphService _service =
      widget.service ?? StoryGraphService(
        projectId: widget.projectId,
        repository: widget.repository ?? authorOsRepository,
      );

  late KnowledgeCanvasService _canvases = KnowledgeCanvasService(
    projectId: widget.projectId,
    repository: widget.repository ?? authorOsRepository,
  );

  bool _loading = true;
  String? _error;

  StoryGraphMode _mode = StoryGraphModes.character;
  StoryGraphFilter _filter = StoryGraphModes.character.filterFrom(
    StoryGraphFilter.unfiltered,
  );

  String? _rootId;
  String? _selectedId;
  StorySubgraph _subgraph = StorySubgraph.empty;
  StoryGraphNeighbourhood? _neighbourhood;
  ConnectionSummary? _summary;
  List<StoryGraphNode> _trail = [];
  List<StoryGraphNode> _roots = [];
  List<(String, String)> _books = [];
  int _hiddenCount = 0;

  Map<String, Offset> _positions = const {};
  final Map<String, Offset> _canvasOverrides = {};
  GraphProjection _projection = const GraphProjection(size: Size.zero);
  bool _canvasMode = false;
  bool _searchOpen = false;
  bool _fitPending = true;

  @override
  void initState() {
    super.initState();
    _rootId = widget.initialNodeId;
    _reload();
  }

  @override
  void didUpdateWidget(covariant KnowledgeGraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _service = widget.service ??
          StoryGraphService(
            projectId: widget.projectId,
            repository: widget.repository ?? authorOsRepository,
          );
      _canvases = KnowledgeCanvasService(
        projectId: widget.projectId,
        repository: widget.repository ?? authorOsRepository,
      );
      _rootId = null;
      _trail = [];
      _canvasOverrides.clear();
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roots = await _candidateRoots();
      final rootId = _rootId ?? (roots.isNotEmpty ? roots.first.id : null);

      // A saved arrangement is the author's own, so it is loaded before the
      // generated layout is applied and wins for the nodes they moved.
      if (_canvasOverrides.isEmpty) {
        final saved = await _canvases.load(_mode.id);
        if (saved != null) _canvasOverrides.addAll(saved.positions);
      }

      final subgraph = _mode.rooted && rootId != null
          ? await _service.getSubgraph(
              rootId,
              depth: _mode.defaultDepth,
              filter: _filter,
            )
          : await _service.getProjectGraph(filter: _filter);

      final focusId = _selectedId ?? rootId;
      final neighbourhood = focusId == null
          ? null
          : await _service.getNeighbours(focusId, filter: _filter);
      final summary = focusId == null
          ? null
          : await _service.connectionSummary(focusId, filter: _filter);

      // What the filters are costing, measured rather than guessed.
      final unfilteredCount = focusId == null
          ? 0
          : (await _service.connectionSummary(
                focusId,
                filter: const StoryGraphFilter(
                  includeArchived: true,
                  includeDeleted: true,
                  includeRelatedTo: true,
                  includeWildcardEdges: true,
                ),
              ))
                  ?.total ??
              0;

      if (!mounted) return;
      setState(() {
        _roots = roots;
        _rootId = rootId;
        _selectedId = focusId;
        _subgraph = subgraph;
        _neighbourhood = neighbourhood;
        _summary = summary;
        _hiddenCount =
            (unfilteredCount - (summary?.total ?? 0)).clamp(0, 1 << 30).toInt();
        _positions = _layout(subgraph);
        _loading = false;
        _fitPending = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Map<String, Offset> _layout(StorySubgraph subgraph) {
    final computed = layoutSubgraph(subgraph, layout: _mode.layout);
    if (_canvasOverrides.isEmpty) return computed;
    // An author's own arrangement wins over the generated one, for the nodes
    // they actually moved.
    return {
      for (final entry in computed.entries)
        entry.key: _canvasOverrides[entry.key] ?? entry.value,
    };
  }

  /// Records that could anchor the current mode, plus the project's books.
  Future<List<StoryGraphNode>> _candidateRoots() async {
    final repository = widget.repository ?? authorOsRepository;
    final records = await repository.recordsByProject(widget.projectId);
    final books = <(String, String)>[];
    final active = <String>[];

    for (final record in records) {
      if (record.status != AuthorRecordStatus.active) continue;
      // A canvas is an arrangement of the graph, not a part of it, so it must
      // never be offered as something to centre the graph on.
      if (kNonGraphRecordTypeIds.contains(record.typeId)) continue;
      if (record.typeId == 'book') books.add((record.id, record.title));
      active.add(record.id);
    }

    // One batched hydration rather than a query per record — a project with a
    // few hundred records would otherwise pay for every one of them on every
    // reload.
    final nodes = await _service.getNodes(active);
    final roots = [
      for (final node in nodes.values)
        if (_mode.acceptsRoot(node)) node,
    ]..sort((left, right) => left.title.compareTo(right.title));

    _books = books..sort((left, right) => left.$2.compareTo(right.$2));
    return roots;
  }

  void _changeMode(StoryGraphMode mode) {
    setState(() {
      _mode = mode;
      _filter = mode.filterFrom(_filter);
      _rootId = null;
      _selectedId = null;
      _trail = [];
      _canvasOverrides.clear();
    });
    _reload();
  }

  Future<void> _saveCanvas() async {
    if (_canvasOverrides.isEmpty) return;
    try {
      await _canvases.save(
        _mode.id,
        positions: Map.of(_canvasOverrides),
        rootId: _rootId,
        filter: _filter,
      );
    } catch (error) {
      if (!mounted) return;
      // A failed save must not take the board down with it — the author can
      // keep arranging, and the message says the arrangement is not kept.
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('The canvas could not be saved: $error')),
      );
    }
  }

  void _changeFilter(StoryGraphFilter filter) {
    setState(() => _filter = filter);
    _reload();
  }

  /// Refocus: the clicked node becomes the centre, and the old centre joins
  /// the trail. This is what turns the graph into a way of moving around.
  void _focusNode(StoryGraphNode node) {
    final previous = _neighbourhood?.centre;
    setState(() {
      if (previous != null && previous.id != node.id) {
        _trail = [..._trail, previous];
      }
      _selectedId = node.id;
      if (_mode.rooted && _mode.acceptsRoot(node)) _rootId = node.id;
    });
    _reload();
  }

  void _jumpToTrail(int index) {
    if (index < 0 || index >= _trail.length) return;
    final node = _trail[index];
    setState(() {
      _trail = _trail.sublist(0, index);
      _selectedId = node.id;
      if (_mode.rooted && _mode.acceptsRoot(node)) _rootId = node.id;
    });
    _reload();
  }

  void _openInStudio(StoryGraphNode node) {
    final navigate = widget.onNavigate;
    if (navigate == null || !node.inspectable) return;
    navigate(
      SearchNavigationTarget(
        destination: searchDestinationForType(node.typeId),
        recordId: node.id,
        projectId: widget.projectId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    if (scope == null) return Builder(builder: _buildStudio);
    return StudioThemeScope(
      theme: scope.theme,
      studio: StudioId.knowledgeGraph,
      child: Builder(builder: _buildStudio),
    );
  }

  Widget _buildStudio(BuildContext context) {
    final palette = GraphPalette.of(context);

    // Studio-scoped only. A global palette would mean wrapping the whole shell
    // in Shortcuts/Actions, which is a much larger change than this milestone
    // needs — see the implementation map.
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const _GraphSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const _GraphSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _GraphSearchIntent: CallbackAction<_GraphSearchIntent>(
            onInvoke: (_) {
              setState(() => _searchOpen = !_searchOpen);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(palette),
              if (_searchOpen) _searchBar(palette),
              const SizedBox(height: 12),
              Expanded(child: _body(palette)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(GraphPalette palette) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Knowledge Graph',
                    key: const Key('knowledge-graph-title'),
                    style: palette.title),
                const SizedBox(height: 2),
                Text(_mode.description, style: palette.label),
              ],
            ),
          ),
          // Flexible so the chips wrap onto a second line on a narrow window
          // instead of overflowing the row.
          Flexible(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              children: [
                for (final mode in StoryGraphModes.all)
                  ChoiceChip(
                    key: Key('graph-mode-${mode.id}'),
                    label: Text(mode.label),
                    selected: mode.id == _mode.id,
                    onSelected: (_) => _changeMode(mode),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const Key('graph-search-toggle'),
            // Ctrl-K is the accelerator, but a shortcut with no affordance is
            // a feature nobody finds.
            tooltip: 'Show me everything connected to… (Ctrl-K)',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searchOpen = !_searchOpen),
          ),
          IconButton(
            key: const Key('graph-canvas-toggle'),
            tooltip: _canvasMode
                ? 'Back to the generated layout'
                : 'Arrange nodes by hand',
            icon: Icon(
              _canvasMode
                  ? Icons.auto_awesome_mosaic
                  : Icons.dashboard_customize_outlined,
            ),
            onPressed: () {
              final leaving = _canvasMode;
              setState(() {
                _canvasMode = !_canvasMode;
                if (leaving) {
                  _canvasOverrides.clear();
                  _positions = _layout(_subgraph);
                }
              });
              // Leaving canvas mode returns to the generated layout, so the
              // saved arrangement goes too — soft-deleted, so an author who
              // spent time on it can get it back out of history.
              if (leaving) _canvases.clear(_mode.id);
            },
          ),
          IconButton(
            key: const Key('graph-fit-button'),
            tooltip: 'Fit to view',
            icon: const Icon(Icons.center_focus_strong_outlined),
            onPressed: () => setState(() => _fitPending = true),
          ),
        ],
      );

  Widget _searchBar(GraphPalette palette) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _GraphNodeSearch(
          key: const Key('graph-node-search'),
          roots: _roots,
          palette: palette,
          onSelected: (node) {
            setState(() => _searchOpen = false);
            _focusNode(node);
          },
        ),
      );

  Widget _body(GraphPalette palette) {
    if (_loading) {
      return const Center(
        key: Key('graph-loading'),
        child: CircularProgressIndicator(),
      );
    }
    if (_error != null) {
      return Center(
        key: const Key('graph-error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('The graph could not be read.', style: palette.title),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center, style: palette.label),
              const SizedBox(height: 12),
              FilledButton(onPressed: _reload, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final canvas = _canvasArea(palette);
        if (!wide) {
          // Narrow: the canvas keeps a workable height and the explorer sits
          // beneath it rather than being squeezed beside it.
          return Column(
            children: [
              SizedBox(height: constraints.maxHeight * 0.55, child: canvas),
              const SizedBox(height: 8),
              Expanded(child: _explorer(palette)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 240, child: _rail(palette)),
            const SizedBox(width: 12),
            Expanded(child: canvas),
            const SizedBox(width: 12),
            SizedBox(width: 300, child: _explorer(palette)),
          ],
        );
      },
    );
  }

  /// A panel surface.
  ///
  /// The background comes from a [Material], not a decorated box, because both
  /// panels contain `ListTile`s: a tile paints its background and ink on the
  /// nearest Material ancestor, so a coloured box in between would swallow
  /// them — and Flutter asserts rather than letting it look broken. The outer
  /// container carries the border only.
  Widget _panel(GraphPalette palette, Widget child) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.outlineVariant),
        ),
        child: Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );

  Widget _rail(GraphPalette palette) => _panel(
        palette,
        GraphFilterRail(
          mode: _mode,
          filter: _filter,
          palette: palette,
          books: _books,
          hiddenCount: _hiddenCount,
          onFilterChanged: _changeFilter,
        ),
      );

  Widget _explorer(GraphPalette palette) => _panel(
        palette,
        ConnectionExplorer(
          palette: palette,
          neighbourhood: _neighbourhood,
          summary: _summary,
          trail: _trail,
          onNodeSelected: _focusNode,
          onTrailTapped: _jumpToTrail,
          onOpenInStudio:
              widget.onNavigate == null ? null : _openInStudio,
        ),
      );

  Widget _canvasArea(GraphPalette palette) {
    return LayoutBuilder(
      builder: (context, canvasConstraints) {
        final size = Size(
          canvasConstraints.maxWidth,
          canvasConstraints.maxHeight,
        );
        var projection = _projection.copyWith(size: size);
        if (_fitPending && _positions.isNotEmpty) {
          projection = projection.fitted(_positions.values);
          // Applied after this frame so `fitted` does not setState during
          // build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _projection = projection;
              _fitPending = false;
            });
          });
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.outlineVariant),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GraphCanvas(
                    subgraph: _subgraph,
                    positions: _positions,
                    projection: projection,
                    palette: palette,
                    rootId: _rootId,
                    selectedId: _selectedId,
                    draggable: _canvasMode,
                    onNodeTap: _focusNode,
                    onNodeOpen: _openInStudio,
                    onNodeDragged: (nodeId, position) => setState(() {
                      _canvasOverrides[nodeId] = position;
                      _positions = {..._positions, nodeId: position};
                    }),
                    // Persisted on release rather than on every pointer delta:
                    // a drag is one edit, not forty.
                    onNodeDragEnd: _saveCanvas,
                    onPanUpdate: (delta) => setState(() {
                      _projection =
                          projection.copyWith(pan: projection.pan + delta);
                    }),
                    onBackgroundTap: () => setState(() => _selectedId = null),
                  ),
                ),
                if (_subgraph.truncated)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _notice(
                      palette,
                      key: const Key('graph-truncation-notice'),
                      // Never silently truncate: a partial graph that looks
                      // complete is worse than no graph.
                      text: 'Showing the first ${_subgraph.nodes.length} '
                          'nodes. Filter down to see the rest.',
                    ),
                  ),
                if (_canvasMode)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _notice(
                      palette,
                      key: const Key('graph-canvas-mode-notice'),
                      text: 'Canvas mode — drag nodes to arrange them.',
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _zoomControls(palette, projection),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _notice(
    GraphPalette palette, {
    required Key key,
    required String text,
  }) =>
      Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.outlineVariant),
        ),
        child: Text(text, style: palette.label),
      );

  Widget _zoomControls(GraphPalette palette, GraphProjection projection) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('graph-zoom-in'),
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add),
            onPressed: () => setState(
              () => _projection = projection.copyWith(
                zoom: projection.zoom * 1.25,
              ),
            ),
          ),
          IconButton(
            key: const Key('graph-zoom-out'),
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove),
            onPressed: () => setState(
              () => _projection = projection.copyWith(
                zoom: projection.zoom / 1.25,
              ),
            ),
          ),
        ],
      );
}

class _GraphSearchIntent extends Intent {
  const _GraphSearchIntent();
}

/// "Show me everything connected to Kali" — pick a node, get its summary.
class _GraphNodeSearch extends StatefulWidget {
  const _GraphNodeSearch({
    super.key,
    required this.roots,
    required this.palette,
    required this.onSelected,
  });

  final List<StoryGraphNode> roots;
  final GraphPalette palette;
  final ValueChanged<StoryGraphNode> onSelected;

  @override
  State<_GraphNodeSearch> createState() => _GraphNodeSearchState();
}

class _GraphNodeSearchState extends State<_GraphNodeSearch> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = _query.trim().isEmpty
        ? widget.roots.take(6).toList()
        : widget.roots
            .where((node) =>
                node.title.toLowerCase().contains(_query.toLowerCase()))
            .take(6)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('graph-search-field'),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Show me everything connected to…',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        for (final node in matches)
          ListTile(
            key: Key('graph-search-result-${node.id}'),
            dense: true,
            leading: Icon(iconForBucket(node.bucket), size: 18),
            title: Text(node.title, style: widget.palette.title),
            subtitle: Text(node.typeId, style: widget.palette.label),
            onTap: () => widget.onSelected(node),
          ),
      ],
    );
  }
}
