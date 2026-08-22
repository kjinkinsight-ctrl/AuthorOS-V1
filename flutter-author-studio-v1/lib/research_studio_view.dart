import 'package:flutter/material.dart';

import 'core/connected_domain.dart';
import 'core/record_validation.dart';
import 'core/research_record_types.dart';
import 'core/story_codex_domain.dart';
import 'onboarding.dart';
import 'research_service.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

/// The author's research library.
///
/// Every entry the Studio shows is a canonical Universal Record read through
/// [ResearchService]; the Studio holds no store, no cache, and no index of its
/// own. Filtering and sorting are derived from the loaded records, and search
/// is delegated to the shared full-text index.
class ResearchStudioView extends StatefulWidget {
  const ResearchStudioView({
    super.key,
    required this.project,
    required this.service,
  });

  final StarterProject project;
  final ResearchService service;

  @override
  State<ResearchStudioView> createState() => _ResearchStudioViewState();
}

class _ResearchStudioViewState extends State<ResearchStudioView> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _loadError;
  List<AuthorRecord> _records = const [];
  ResearchShelf _shelf = ResearchShelf.all;
  String _categoryFilter = _anyCategory;
  String _statusFilter = _anyStatus;
  String _tagFilter = _anyTag;
  ResearchSort _sort = ResearchSort.recentlyUpdated;
  String? _selectedId;
  List<ResearchConnection> _selectedConnections = const [];
  ResearchDashboard? _dashboard;
  List<ResearchSavedView> _savedViews = const [];

  static const _anyCategory = '__all_categories__';
  static const _anyStatus = '__all_statuses__';
  static const _anyTag = '__all_tags__';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ResearchStudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching projects must never leave the previous project's research on
    // screen, so a new scope reloads from the canonical repository.
    if (oldWidget.service.projectId != widget.service.projectId) {
      _selectedId = null;
      _selectedConnections = const [];
      _records = const [];
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _searchTerm => _searchController.text.trim();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final records = _searchTerm.isEmpty
          ? await widget.service.query.all()
          : await widget.service.searchResearch(_searchTerm);
      // The dashboard is a read-model over the same canonical records, so it
      // is recomputed with every load rather than cached and invalidated.
      final dashboard = await widget.service.dashboard();
      final savedViews = await widget.service.savedViews();
      if (!mounted) return;
      setState(() {
        _records = records;
        _dashboard = dashboard;
        _savedViews = savedViews;
        _loading = false;
        if (_selectedId != null &&
            !records.any((record) => record.id == _selectedId)) {
          _selectedId = null;
          _selectedConnections = const [];
        }
      });
      await _loadConnections();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _readableError(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadConnections() async {
    final id = _selectedId;
    if (id == null) {
      if (mounted) setState(() => _selectedConnections = const []);
      return;
    }
    try {
      final connections = await widget.service.connectedRecords(id);
      if (!mounted) return;
      setState(() => _selectedConnections = connections);
    } on StateError {
      if (!mounted) return;
      setState(() => _selectedConnections = const []);
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on RecordValidationException catch (error) {
      _showMessage(_readableError(error));
    } on ArgumentError catch (error) {
      _showMessage(_readableError(error));
    } on StateError catch (error) {
      _showMessage(_readableError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEditor({AuthorRecord? existing}) async {
    final draft = await showDialog<ResearchDraft>(
      context: context,
      builder: (context) => _ResearchEditorDialog(
        existing: existing,
        newId: existing?.id ?? _nextId(),
      ),
    );
    if (draft == null) return;
    await _runBusy(() async {
      if (existing == null) {
        final created = await widget.service.createResearch(draft);
        _selectedId = created.id;
      } else {
        await widget.service.updateResearch(draft);
      }
      await _load();
    });
  }

  Future<void> _toggleImportant(AuthorRecord record) => _runBusy(() async {
        await widget.service.setImportant(
          record.id,
          !ResearchService.isImportant(record),
        );
        await _load();
      });

  Future<void> _toggleArchived(AuthorRecord record) => _runBusy(() async {
        if (record.status == AuthorRecordStatus.archived) {
          await widget.service.restoreResearch(record.id);
        } else {
          await widget.service.archiveResearch(record.id);
        }
        await _load();
      });

  Future<void> _delete(AuthorRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete research entry?'),
        content: Text(
          '"${record.title}" will be removed from the research library. '
          'Its history stays in the record archive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('research-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBusy(() async {
      await widget.service.deleteResearch(record.id);
      if (_selectedId == record.id) _selectedId = null;
      await _load();
    });
  }

  void _select(AuthorRecord record) {
    setState(() => _selectedId = record.id);
    _loadConnections();
  }

  String _nextId() {
    final existing = _records.map((record) => record.id).toSet();
    var index = existing.length + 1;
    var candidate = 'research-$index';
    while (existing.contains(candidate)) {
      index += 1;
      candidate = 'research-$index';
    }
    return candidate;
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  /// The records currently on screen: shelf, then filters, then sort. All of
  /// it derived from [_records], which came from the canonical repository.
  List<AuthorRecord> get _visible {
    var records = ResearchQueryService.onShelf(_records, _shelf);
    if (_categoryFilter != _anyCategory) {
      records = records
          .where(
            (record) => ResearchService.categoryOf(record) == _categoryFilter,
          )
          .toList();
    }
    if (_statusFilter != _anyStatus) {
      records = records
          .where((record) => ResearchService.statusOf(record) == _statusFilter)
          .toList();
    }
    final tagFilter = _effectiveTagFilter;
    if (tagFilter != _anyTag) {
      records = records
          .where(
            (record) => record.tags.any(
              (tag) => tag.toLowerCase() == tagFilter.toLowerCase(),
            ),
          )
          .toList();
    }
    return ResearchQueryService.sorted(records, _sort);
  }

  /// The tag filter, ignored once the last record carrying that tag is gone,
  /// so the list never silently disagrees with the dropdown.
  String get _effectiveTagFilter =>
      _tagOptions.contains(_tagFilter) ? _tagFilter : _anyTag;

  AuthorRecord? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  Map<String, int> get _categoryCounts {
    final counts = <String, int>{};
    for (final record in _records) {
      final category = ResearchService.categoryOf(record);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    return counts;
  }

  List<String> get _tagOptions {
    final tags = <String>{};
    for (final record in _records) {
      tags.addAll(record.tags.where((tag) => tag.trim().isNotEmpty));
    }
    final ordered = tags.toList()
      ..sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    if (scope == null) return Builder(builder: _buildStudio);
    // Layer this Studio's overrides on the shell theme. The engine and its
    // tokens stay the single source of truth for every colour below.
    return StudioThemeScope(
      theme: scope.theme,
      studio: StudioId.research,
      child: Builder(builder: _buildStudio),
    );
  }

  Widget _buildStudio(BuildContext context) {
    final palette = _ResearchPalette.of(context);
    if (_loading) {
      return Column(
        key: const Key('research-loading'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(palette),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 96),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (_loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(palette),
          const SizedBox(height: 16),
          _ErrorState(palette: palette, message: _loadError!, onRetry: _load),
        ],
      );
    }
    return FocusTraversalGroup(
      child: Column(
        key: const Key('research-studio'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(palette),
          const SizedBox(height: 16),
          if (_dashboard != null)
            _ResearchDashboardBand(
              palette: palette,
              dashboard: _dashboard!,
              onShowUnresolved: () =>
                  setState(() => _shelf = ResearchShelf.unresolved),
            ),
          if (_dashboard != null) const SizedBox(height: 16),
          _buildSearchBar(palette),
          const SizedBox(height: 12),
          _buildSavedViewBar(palette),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              final library = _ResearchLibraryRail(
                palette: palette,
                shelf: _shelf,
                counts: _shelfCounts,
                categoryCounts: _categoryCounts,
                categoryFilter: _categoryFilter,
                anyCategory: _anyCategory,
                onShelfChanged: (shelf) => setState(() => _shelf = shelf),
                onCategoryChanged: (category) =>
                    setState(() => _categoryFilter = category),
              );
              final list = _buildListPane(palette);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 240, child: library),
                    const SizedBox(width: 16),
                    Expanded(child: list),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [library, const SizedBox(height: 16), list],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Saved views -------------------------------------------------------

  ResearchViewFilter get _currentFilter => ResearchViewFilter(
        query: _searchTerm,
        shelf: _shelf,
        category: _categoryFilter == _anyCategory ? '' : _categoryFilter,
        status: _statusFilter == _anyStatus ? '' : _statusFilter,
        tag: _tagFilter == _anyTag ? '' : _tagFilter,
        sort: _sort,
      );

  void _applySavedView(ResearchSavedView view) {
    setState(() {
      _shelf = view.filter.shelf;
      _categoryFilter =
          view.filter.category.isEmpty ? _anyCategory : view.filter.category;
      _statusFilter =
          view.filter.status.isEmpty ? _anyStatus : view.filter.status;
      _tagFilter = view.filter.tag.isEmpty ? _anyTag : view.filter.tag;
      _sort = view.filter.sort;
      _searchController.text = view.filter.query;
    });
    _load();
  }

  Future<void> _saveCurrentView() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this view'),
        content: TextField(
          key: const Key('research-save-view-name'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'View name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('research-save-view-confirm'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await _runBusy(() async {
      await widget.service.saveView(
        id: 'research-view-${_slug(name)}',
        name: name,
        filter: _currentFilter,
      );
      await _load();
    });
  }

  Future<void> _deleteSavedView(ResearchSavedView view) => _runBusy(() async {
        await widget.service.deleteSavedView(view.id);
        await _load();
      });

  Widget _buildSavedViewBar(_ResearchPalette palette) => Wrap(
        key: const Key('research-saved-views'),
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Saved views',
            style: palette.label.copyWith(
              color: palette.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_savedViews.isEmpty)
            Text(
              'None yet',
              style: palette.body.copyWith(color: palette.onSurfaceVariant),
            ),
          for (final view in _savedViews)
            InputChip(
              key: Key('research-saved-view-${view.id}'),
              label: Text(view.name),
              onPressed: _busy ? null : () => _applySavedView(view),
              onDeleted: _busy ? null : () => _deleteSavedView(view),
              deleteIcon: const Icon(Icons.close, size: 16),
            ),
          TextButton.icon(
            key: const Key('research-save-view'),
            onPressed: _busy || _loading ? null : _saveCurrentView,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Save view'),
          ),
        ],
      );

  // --- Sources -----------------------------------------------------------

  Future<void> _addSource(AuthorRecord record) async {
    final labelController = TextEditingController();
    final locationController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('research-source-label'),
              controller: labelController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Source',
                hintText: 'Book, article, interview...',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('research-source-location'),
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'Page, chapter, timestamp...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('research-source-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (saved != true || labelController.text.trim().isEmpty) return;
    await _runBusy(() async {
      await widget.service.addSource(
        record.id,
        CodexSourceReference(
          recordId: '',
          kind: 'external',
          label: labelController.text.trim(),
          location: locationController.text.trim(),
        ),
      );
      await _load();
    });
  }

  Future<void> _removeSource(AuthorRecord record, String stableId) =>
      _runBusy(() async {
        await widget.service.removeSource(record.id, stableId);
        await _load();
      });

  // --- Connections -------------------------------------------------------

  Future<void> _connect(AuthorRecord record) async {
    final candidates =
        await widget.service.connectableRecords(excludeId: record.id);
    if (!mounted) return;
    if (candidates.isEmpty) {
      _showMessage('There is nothing else in this project to connect to yet.');
      return;
    }
    var targetId = candidates.first.id;
    var types = await widget.service.connectionTypesBetween(
      sourceTypeId: record.typeId,
      targetTypeId: candidates.first.typeId,
    );
    if (!mounted) return;
    if (types.isEmpty) {
      _showMessage('No connection type accepts these two records.');
      return;
    }
    var typeId = types.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Connect research'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('research-connect-target'),
                initialValue: targetId,
                decoration: const InputDecoration(labelText: 'Connect to'),
                items: [
                  for (final candidate in candidates)
                    DropdownMenuItem(
                      value: candidate.id,
                      child: Text(candidate.title),
                    ),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  final target = candidates.firstWhere(
                    (candidate) => candidate.id == value,
                  );
                  final allowed =
                      await widget.service.connectionTypesBetween(
                    sourceTypeId: record.typeId,
                    targetTypeId: target.typeId,
                  );
                  setDialogState(() {
                    targetId = value;
                    types = allowed;
                    typeId = allowed.isEmpty ? '' : allowed.first.id;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('research-connect-type'),
                initialValue: typeId.isEmpty ? null : typeId,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: [
                  for (final type in types)
                    DropdownMenuItem(
                      value: type.id,
                      child: Text(type.displayName),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => typeId = value ?? ''),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('research-connect-confirm'),
              onPressed: typeId.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || typeId.isEmpty) return;
    await _runBusy(() async {
      await widget.service.connect(
        sourceId: record.id,
        targetId: targetId,
        typeId: typeId,
      );
      await _load();
    });
  }

  Future<void> _disconnect(String linkId) => _runBusy(() async {
        await widget.service.disconnect(linkId);
        await _load();
      });

  Map<ResearchShelf, int> get _shelfCounts => {
        for (final shelf in ResearchShelf.values)
          shelf: ResearchQueryService.onShelf(_records, shelf).length,
      };

  Widget _buildHeader(_ResearchPalette palette) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Research Studio',
                  style: palette.heading.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Collect, organise, and connect the research behind '
                  '${widget.project.title}.',
                  style: palette.body.copyWith(color: palette.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Create research entry',
            child: FilledButton.icon(
              key: const Key('research-create-button'),
              onPressed: _busy || _loading ? null : () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('New'),
            ),
          ),
        ],
      );

  Widget _buildSearchBar(_ResearchPalette palette) => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              key: const Key('research-search-field'),
              controller: _searchController,
              onChanged: (_) => _load(),
              decoration: const InputDecoration(
                hintText: 'Search research...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          DropdownButton<String>(
            key: const Key('research-status-filter'),
            value: _statusFilter,
            items: [
              const DropdownMenuItem(
                value: _anyStatus,
                child: Text('All statuses'),
              ),
              for (final status in ResearchRecordTypes.displayStatuses)
                DropdownMenuItem(value: status, child: Text(status)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _statusFilter = value);
            },
          ),
          DropdownButton<String>(
            key: const Key('research-tag-filter'),
            value: _effectiveTagFilter,
            items: [
              const DropdownMenuItem(value: _anyTag, child: Text('All tags')),
              for (final tag in _tagOptions)
                DropdownMenuItem(value: tag, child: Text(tag)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _tagFilter = value);
            },
          ),
          DropdownButton<ResearchSort>(
            key: const Key('research-sort'),
            value: _sort,
            items: const [
              DropdownMenuItem(
                value: ResearchSort.recentlyUpdated,
                child: Text('Recently updated'),
              ),
              DropdownMenuItem(
                value: ResearchSort.recentlyCreated,
                child: Text('Recently created'),
              ),
              DropdownMenuItem(
                value: ResearchSort.alphabetical,
                child: Text('Alphabetical'),
              ),
              DropdownMenuItem(
                value: ResearchSort.category,
                child: Text('Category'),
              ),
              DropdownMenuItem(
                value: ResearchSort.importance,
                child: Text('Importance'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _sort = value);
            },
          ),
          Text(
            '${_visible.length} of ${_records.length}',
            style: palette.label.copyWith(color: palette.onSurfaceVariant),
          ),
        ],
      );

  Widget _buildListPane(_ResearchPalette palette) {
    final visible = _visible;
    if (visible.isEmpty) {
      return _EmptyState(
        palette: palette,
        kind: _emptyStateKind,
        onCreate: _busy ? null : () => _openEditor(),
      );
    }
    final selected = _selected;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720 && selected != null;
        final list = Column(
          key: const Key('research-list'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final record in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ResearchTile(
                  key: Key('research-entry-${record.id}'),
                  record: record,
                  palette: palette,
                  selected: record.id == _selectedId,
                  onTap: () => _select(record),
                  onToggleImportant:
                      _busy ? null : () => _toggleImportant(record),
                ),
              ),
          ],
        );
        if (selected == null) return list;
        final detail = _ResearchDetailPane(
          record: selected,
          palette: palette,
          connections: _selectedConnections,
          busy: _busy,
          onEdit: () => _openEditor(existing: selected),
          onToggleImportant: () => _toggleImportant(selected),
          onToggleArchived: () => _toggleArchived(selected),
          onDelete: () => _delete(selected),
          onAddSource: () => _addSource(selected),
          onRemoveSource: (stableId) => _removeSource(selected, stableId),
          onConnect: () => _connect(selected),
          onDisconnect: _disconnect,
          onClose: () => setState(() {
            _selectedId = null;
            _selectedConnections = const [];
          }),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: list),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: detail),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [list, const SizedBox(height: 16), detail],
        );
      },
    );
  }

  _EmptyStateKind get _emptyStateKind {
    if (_records.isEmpty && _searchTerm.isNotEmpty) {
      return _EmptyStateKind.noSearchResults;
    }
    if (_records.isEmpty) return _EmptyStateKind.noResearch;
    if (_searchTerm.isNotEmpty) return _EmptyStateKind.noSearchResults;
    if (_categoryFilter != _anyCategory) return _EmptyStateKind.noCategory;
    return _EmptyStateKind.noFilterResults;
  }
}

enum _EmptyStateKind {
  noResearch,
  noSearchResults,
  noCategory,
  noFilterResults,
}

/// The Research Library rail: shelves on top, categories below.
class _ResearchLibraryRail extends StatelessWidget {
  const _ResearchLibraryRail({
    required this.palette,
    required this.shelf,
    required this.counts,
    required this.categoryCounts,
    required this.categoryFilter,
    required this.anyCategory,
    required this.onShelfChanged,
    required this.onCategoryChanged,
  });

  final _ResearchPalette palette;
  final ResearchShelf shelf;
  final Map<ResearchShelf, int> counts;
  final Map<String, int> categoryCounts;
  final String categoryFilter;
  final String anyCategory;
  final ValueChanged<ResearchShelf> onShelfChanged;
  final ValueChanged<String> onCategoryChanged;

  static const _shelves = <(ResearchShelf, String, IconData)>[
    (ResearchShelf.all, 'All research', Icons.inventory_2_outlined),
    (ResearchShelf.sources, 'Sources', Icons.menu_book_outlined),
    (ResearchShelf.notes, 'Notes', Icons.sticky_note_2_outlined),
    (ResearchShelf.references, 'References', Icons.link_outlined),
    (ResearchShelf.important, 'Important', Icons.star_outline),
    (ResearchShelf.unresolved, 'Unresolved', Icons.error_outline),
    (ResearchShelf.recent, 'Recently updated', Icons.history_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final activeCategories = categoryCounts.keys.toList()
      ..sort(
        (left, right) => ResearchRecordTypes.categories
            .indexOf(left)
            .compareTo(ResearchRecordTypes.categories.indexOf(right)),
      );
    return Container(
      key: const Key('research-library-rail'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Research Library',
            style: palette.ui.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (final entry in _shelves)
            _RailTile(
              key: Key('research-shelf-${entry.$1.name}'),
              palette: palette,
              icon: entry.$3,
              label: entry.$2,
              trailing: '${counts[entry.$1] ?? 0}',
              selected: shelf == entry.$1,
              onTap: () => onShelfChanged(entry.$1),
            ),
          const SizedBox(height: 14),
          Text(
            'Categories',
            style: palette.label.copyWith(
              color: palette.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _RailTile(
            key: const Key('research-category-all'),
            palette: palette,
            icon: Icons.label_outline,
            label: 'All categories',
            trailing: '',
            selected: categoryFilter == anyCategory,
            onTap: () => onCategoryChanged(anyCategory),
          ),
          if (activeCategories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Categories appear as you file research.',
                style: palette.label.copyWith(color: palette.onSurfaceVariant),
              ),
            )
          else
            for (final category in activeCategories)
              _RailTile(
                key: Key('research-category-$category'),
                palette: palette,
                icon: Icons.folder_outlined,
                label: category,
                trailing: '${categoryCounts[category]}',
                selected: categoryFilter == category,
                onTap: () => onCategoryChanged(category),
              ),
        ],
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.trailing,
    required this.selected,
    required this.onTap,
  });

  final _ResearchPalette palette;
  final IconData icon;
  final String label;
  final String trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(palette.chipRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? palette.selection : palette.surface,
              borderRadius: BorderRadius.circular(palette.chipRadius),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: palette.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: palette.ui.copyWith(
                      color: palette.onSurface,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (trailing.isNotEmpty)
                  Text(
                    trailing,
                    style: palette.label.copyWith(
                      color: palette.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile({
    super.key,
    required this.record,
    required this.palette,
    required this.selected,
    required this.onTap,
    required this.onToggleImportant,
  });

  final AuthorRecord record;
  final _ResearchPalette palette;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onToggleImportant;

  @override
  Widget build(BuildContext context) {
    final important = ResearchService.isImportant(record);
    final summary = ResearchService.summaryOf(record);
    return Semantics(
      button: true,
      selected: selected,
      label: record.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? palette.selection : palette.surfaceContainer,
            borderRadius: BorderRadius.circular(palette.cardRadius),
            border: Border.all(
              color: selected ? palette.primary : palette.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      record.title,
                      style: palette.ui.copyWith(
                        color: palette.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('research-important-${record.id}'),
                    tooltip:
                        important ? 'Remove from Important' : 'Mark important',
                    onPressed: onToggleImportant,
                    icon: Icon(
                      important ? Icons.star : Icons.star_outline,
                      color:
                          important ? palette.primary : palette.onSurfaceVariant,
                      size: 18,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Chip(
                    palette: palette,
                    label: ResearchService.kindOf(record),
                  ),
                  _Chip(
                    palette: palette,
                    label: ResearchService.categoryOf(record),
                  ),
                  _Chip(
                    palette: palette,
                    label: ResearchService.statusOf(record),
                  ),
                  for (final tag in record.tags)
                    _Chip(palette: palette, label: '#$tag'),
                ],
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: palette.body.copyWith(
                    color: palette.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.palette, required this.label});

  final _ResearchPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(palette.chipRadius),
          border: Border.all(color: palette.outline),
        ),
        child: Text(
          label,
          style: palette.label.copyWith(color: palette.onSurfaceVariant),
        ),
      );
}

/// Inspects one entry. It renders the canonical record and hands editing back
/// to the shared editor, so it never becomes a second editing system.
class _ResearchDetailPane extends StatelessWidget {
  const _ResearchDetailPane({
    required this.record,
    required this.palette,
    required this.connections,
    required this.busy,
    required this.onEdit,
    required this.onToggleImportant,
    required this.onToggleArchived,
    required this.onDelete,
    required this.onAddSource,
    required this.onRemoveSource,
    required this.onConnect,
    required this.onDisconnect,
    required this.onClose,
  });

  final AuthorRecord record;
  final _ResearchPalette palette;
  final List<ResearchConnection> connections;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleImportant;
  final VoidCallback onToggleArchived;
  final VoidCallback onDelete;
  final VoidCallback onAddSource;
  final ValueChanged<String> onRemoveSource;
  final VoidCallback onConnect;
  final ValueChanged<String> onDisconnect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final notes = ResearchService.notesOf(record);
    final summary = ResearchService.summaryOf(record);
    final sourceUrl =
        '${record.fields[ResearchRecordTypes.sourceUrlFieldId] ?? ''}';
    final citation =
        '${record.fields[ResearchRecordTypes.citationFieldId] ?? ''}';
    final archived = record.status == AuthorRecordStatus.archived;
    final sources = ResearchService.sourcesOf(record);
    return Container(
      key: const Key('research-detail-pane'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  record.title,
                  style: palette.heading.copyWith(
                    color: palette.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const Key('research-detail-close'),
                tooltip: 'Close',
                onPressed: onClose,
                icon: Icon(Icons.close, color: palette.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Chip(palette: palette, label: ResearchService.kindOf(record)),
              _Chip(
                palette: palette,
                label: ResearchService.categoryOf(record),
              ),
              _Chip(palette: palette, label: ResearchService.statusOf(record)),
              if (ResearchService.isImportant(record))
                _Chip(palette: palette, label: 'Important'),
              for (final tag in record.tags)
                _Chip(palette: palette, label: '#$tag'),
            ],
          ),
          if (summary.isNotEmpty)
            _DetailSection(palette: palette, title: 'Summary', body: summary),
          if (notes.isNotEmpty)
            _DetailSection(palette: palette, title: 'Notes', body: notes),
          if (sourceUrl.isNotEmpty)
            _DetailSection(
              palette: palette,
              title: 'Source link',
              body: sourceUrl,
            ),
          if (citation.isNotEmpty)
            _DetailSection(
              palette: palette,
              title: 'Citation',
              body: citation,
            ),
          _DetailSection(
            palette: palette,
            title: 'Record',
            body: 'Type ${record.typeId} · revision ${record.revision}\n'
                'Created ${_formatDate(record.createdAt)}\n'
                'Updated ${_formatDate(record.updatedAt)}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sources',
                  style: palette.label.copyWith(
                    color: palette.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('research-add-source'),
                onPressed: busy ? null : onAddSource,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (sources.isEmpty)
            Text(
              'No sources recorded yet.',
              key: const Key('research-detail-no-sources'),
              style: palette.body.copyWith(color: palette.onSurfaceVariant),
            )
          else
            for (final source in sources)
              Padding(
                key: Key('research-source-${source.stableId}'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        source.location.isEmpty
                            ? source.displayLabel
                            : '${source.displayLabel} · ${source.location}',
                        style:
                            palette.body.copyWith(color: palette.onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove source',
                      onPressed:
                          busy ? null : () => onRemoveSource(source.stableId),
                      icon: Icon(
                        Icons.close,
                        size: 16,
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Connections',
                  style: palette.label.copyWith(
                    color: palette.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('research-add-connection'),
                onPressed: busy ? null : onConnect,
                icon: const Icon(Icons.add_link, size: 18),
                label: const Text('Connect'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (connections.isEmpty)
            Text(
              'Not connected to any records yet.',
              key: const Key('research-detail-no-connections'),
              style: palette.body.copyWith(color: palette.onSurfaceVariant),
            )
          else
            for (final connection in connections)
              Padding(
                key: Key('research-connection-${connection.link.id}'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${connection.link.typeId} → '
                        '${connection.record.title}',
                        style:
                            palette.body.copyWith(color: palette.onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove connection',
                      onPressed: busy
                          ? null
                          : () => onDisconnect(connection.link.id),
                      icon: Icon(
                        Icons.link_off,
                        size: 16,
                        color: palette.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('research-detail-edit'),
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                key: const Key('research-detail-important'),
                onPressed: busy ? null : onToggleImportant,
                icon: Icon(
                  ResearchService.isImportant(record)
                      ? Icons.star
                      : Icons.star_outline,
                ),
                label: Text(
                  ResearchService.isImportant(record)
                      ? 'Unmark important'
                      : 'Mark important',
                ),
              ),
              OutlinedButton.icon(
                key: const Key('research-detail-archive'),
                onPressed: busy ? null : onToggleArchived,
                icon: Icon(
                  archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                ),
                label: Text(archived ? 'Restore' : 'Archive'),
              ),
              TextButton.icon(
                key: const Key('research-detail-delete'),
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.palette,
    required this.title,
    required this.body,
  });

  final _ResearchPalette palette;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: palette.label.copyWith(
                color: palette.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: palette.body.copyWith(color: palette.onSurface),
            ),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.palette,
    required this.kind,
    required this.onCreate,
  });

  final _ResearchPalette palette;
  final _EmptyStateKind kind;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final (title, detail) = switch (kind) {
      _EmptyStateKind.noResearch => (
          'Your research library is empty.',
          'Create your first research entry to start building your '
              'knowledge base.',
        ),
      _EmptyStateKind.noSearchResults => (
          'No research matches your search.',
          'Try a different word, or clear the search to see everything.',
        ),
      _EmptyStateKind.noCategory => (
          'No research in this category yet.',
          'File an entry under this category, or pick another shelf.',
        ),
      _EmptyStateKind.noFilterResults => (
          'No research matches these filters.',
          'Clear a filter to widen the shelf.',
        ),
    };
    return Container(
      key: const Key('research-empty-state'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          Icon(Icons.library_books_outlined,
              size: 36, color: palette.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: palette.ui.copyWith(
              color: palette.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: palette.body.copyWith(color: palette.onSurfaceVariant),
          ),
          if (kind == _EmptyStateKind.noResearch) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('research-empty-create-button'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create research entry'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.palette,
    required this.message,
    required this.onRetry,
  });

  final _ResearchPalette palette;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('research-error-state'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surfaceContainer,
          borderRadius: BorderRadius.circular(palette.cardRadius),
          border: Border.all(color: palette.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Research could not be loaded.',
              style: palette.ui.copyWith(
                color: palette.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: palette.body.copyWith(color: palette.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('research-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}

/// Creates and edits a research entry.
///
/// It builds a [ResearchDraft]; [ResearchService] is what turns that into a
/// canonical record, so this dialog is a form and nothing more.
class _ResearchEditorDialog extends StatefulWidget {
  const _ResearchEditorDialog({required this.existing, required this.newId});

  final AuthorRecord? existing;
  final String newId;

  @override
  State<_ResearchEditorDialog> createState() => _ResearchEditorDialogState();
}

class _ResearchEditorDialogState extends State<_ResearchEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _notes;
  late final TextEditingController _sourceUrl;
  late final TextEditingController _citation;
  late final TextEditingController _tags;
  late String _kind;
  late String _category;
  late String _status;
  late bool _important;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final draft = existing == null
        ? ResearchDraft(id: widget.newId, title: '')
        : ResearchDraft.fromRecord(existing);
    _title = TextEditingController(text: draft.title);
    _summary = TextEditingController(text: draft.summary);
    _notes = TextEditingController(text: draft.notes);
    _sourceUrl = TextEditingController(text: draft.sourceUrl);
    _citation = TextEditingController(text: draft.citation);
    _tags = TextEditingController(text: draft.tags.join(', '));
    _kind = draft.kind;
    _category = draft.category;
    _status = draft.status;
    _important = draft.important;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _notes.dispose();
    _sourceUrl.dispose();
    _citation.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('research-editor-dialog'),
        title: Text(
          widget.existing == null ? 'New research entry' : 'Edit research',
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('research-editor-title'),
                  controller: _title,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const Key('research-editor-kind'),
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Kind'),
                  items: [
                    for (final kind in ResearchRecordTypes.kinds)
                      DropdownMenuItem(value: kind, child: Text(kind)),
                  ],
                  onChanged: (value) =>
                      setState(() => _kind = value ?? _kind),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const Key('research-editor-category'),
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in ResearchRecordTypes.categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const Key('research-editor-status'),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    for (final status in ResearchRecordTypes.statuses)
                      DropdownMenuItem(value: status, child: Text(status)),
                  ],
                  onChanged: (value) =>
                      setState(() => _status = value ?? _status),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('research-editor-summary'),
                  controller: _summary,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Summary'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('research-editor-notes'),
                  controller: _notes,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('research-editor-source-url'),
                  controller: _sourceUrl,
                  decoration: const InputDecoration(labelText: 'Source link'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('research-editor-citation'),
                  controller: _citation,
                  decoration: const InputDecoration(labelText: 'Citation'),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('research-editor-tags'),
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    helperText: 'Comma separated',
                  ),
                ),
                const SizedBox(height: 6),
                CheckboxListTile(
                  key: const Key('research-editor-important'),
                  value: _important,
                  onChanged: (value) =>
                      setState(() => _important = value ?? false),
                  title: const Text('Important'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const Key('research-editor-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('research-editor-save'),
            onPressed: _title.text.trim().isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ],
      );

  void _save() {
    Navigator.of(context).pop(
      ResearchDraft(
        id: widget.existing?.id ?? widget.newId,
        title: _title.text,
        typeId: widget.existing?.typeId ?? ResearchRecordTypes.baseTypeId,
        kind: _kind,
        category: _category,
        status: _status,
        important: _important,
        summary: _summary.text,
        notes: _notes.text,
        sourceUrl: _sourceUrl.text,
        citation: _citation.text,
        tags: _tags.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
      ),
    );
  }
}

/// Resolves every colour and text style this Studio paints.
///
/// Tokens come from the Theme Engine through [StudioThemeScope]; when the
/// Studio is pumped without a scope, Material's [Theme] supplies the fallback.
/// Nothing here names a colour literally.
/// The dashboard strip above the library.
///
/// Every number here comes from [ResearchDashboard], which is derived from the
/// canonical records on each load. The band stores nothing and decides
/// nothing — it renders what the read-model computed.
class _ResearchDashboardBand extends StatelessWidget {
  const _ResearchDashboardBand({
    required this.palette,
    required this.dashboard,
    required this.onShowUnresolved,
  });

  final _ResearchPalette palette;
  final ResearchDashboard dashboard;
  final VoidCallback onShowUnresolved;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String, VoidCallback?)>[
      ('Items', '${dashboard.total}', null),
      ('Sources', '${dashboard.sources}', null),
      ('Notes', '${dashboard.notes}', null),
      ('References', '${dashboard.references}', null),
      ('Categories', '${dashboard.categories.length}', null),
      ('Tags', '${dashboard.tags.length}', null),
      ('Cited', '${dashboard.sourceReferences}', null),
      (
        'Unresolved',
        '${dashboard.unresolved.length}',
        dashboard.unresolved.isEmpty ? null : onShowUnresolved,
      ),
      ('Archived', '${dashboard.archived}', null),
    ];
    return Container(
      key: const Key('research-dashboard'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(palette.cardRadius),
        border: Border.all(color: palette.outline),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final metric in metrics)
            _MetricTile(
              palette: palette,
              label: metric.$1,
              value: metric.$2,
              onTap: metric.$3,
            ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.palette,
    required this.label,
    required this.value,
    this.onTap,
  });

  final _ResearchPalette palette;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      key: Key('research-metric-${label.toLowerCase()}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(palette.chipRadius),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: palette.label.copyWith(color: palette.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: palette.ui.copyWith(
              color: palette.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      label: 'Show $label research',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(palette.chipRadius),
        child: tile,
      ),
    );
  }
}

/// A stable, filename-safe id fragment for a saved view name.
String _slug(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'view' : normalized;
}

class _ResearchPalette {
  const _ResearchPalette({
    required this.surface,
    required this.surfaceContainer,
    required this.primary,
    required this.onPrimary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.selection,
    required this.cardRadius,
    required this.chipRadius,
    required this.heading,
    required this.ui,
    required this.body,
    required this.label,
  });

  final Color surface;
  final Color surfaceContainer;
  final Color primary;
  final Color onPrimary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color selection;

  /// Named radii from the engine's metrics; the Studio never invents one.
  final double cardRadius;
  final double chipRadius;

  final TextStyle heading;
  final TextStyle ui;
  final TextStyle body;
  final TextStyle label;

  static _ResearchPalette of(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    TextStyle text(
      ThemeTextRole role,
      ThemeColorRef ref,
      TextStyle? fallback,
    ) =>
        scope?.text(role, colorRef: ref) ??
        (fallback ?? const TextStyle()).copyWith(
          color: ref == ThemeColorRef.onSurfaceVariant
              ? scheme.onSurfaceVariant
              : scheme.onSurface,
        );
    return _ResearchPalette(
      surface: scope?.color(ThemeColorRef.surface) ?? scheme.surface,
      surfaceContainer: scope?.color(ThemeColorRef.surfaceContainer) ??
          scheme.surfaceContainerHighest,
      primary: scope?.color(ThemeColorRef.primary) ?? scheme.primary,
      onPrimary: scope?.color(ThemeColorRef.onPrimary) ?? scheme.onPrimary,
      onSurface: scope?.color(ThemeColorRef.onSurface) ?? scheme.onSurface,
      onSurfaceVariant: scope?.color(ThemeColorRef.onSurfaceVariant) ??
          scheme.onSurfaceVariant,
      outline:
          scope?.color(ThemeColorRef.outlineVariant) ?? scheme.outlineVariant,
      selection:
          scope?.color(ThemeColorRef.selection) ?? scheme.primaryContainer,
      cardRadius: scope?.radius('card') ?? 20,
      chipRadius: scope?.radius('chip') ?? 12,
      heading: text(
        ThemeTextRole.heading,
        ThemeColorRef.onSurface,
        theme.textTheme.titleLarge,
      ),
      ui: text(
        ThemeTextRole.ui,
        ThemeColorRef.onSurface,
        theme.textTheme.titleSmall,
      ),
      body: text(
        ThemeTextRole.body,
        ThemeColorRef.onSurface,
        theme.textTheme.bodyMedium,
      ),
      label: text(
        ThemeTextRole.label,
        ThemeColorRef.onSurfaceVariant,
        theme.textTheme.labelMedium,
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final utc = value.toUtc();
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}

String _readableError(Object error) {
  if (error is RecordValidationException) {
    final messages = error.result.errors.map((issue) => issue.message);
    return messages.isEmpty ? 'The record is not valid.' : messages.join(' ');
  }
  if (error is ArgumentError) return '${error.message ?? error}';
  if (error is StateError) return error.message;
  return '$error';
}
