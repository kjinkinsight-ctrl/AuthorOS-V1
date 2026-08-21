import 'package:flutter/material.dart';

import 'core/connected_domain.dart';
import 'core/connection_types.dart';
import 'core/record_validation.dart';
import 'core/search_models.dart';
import 'core/story_codex_domain.dart';
import 'core/universal_search.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'research_service.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/resolved_theme.dart';
import 'theme/theme_tokens.dart';

/// Where a record connected to a research item lives, so the shell can switch
/// Studios instead of opening a second copy of it here.
class ResearchNavigationRequest {
  const ResearchNavigationRequest({
    required this.destination,
    required this.recordId,
    required this.recordType,
    required this.title,
  });

  final SearchDestination destination;
  final String recordId;
  final String recordType;
  final String title;
}

/// The writer-facing Research Studio.
///
/// Every read and write goes through [ResearchService], which narrows
/// `StoryCodexService` to the Research record types. The Studio owns no store,
/// index, or history of its own: research is a Universal Record, its search is
/// the database FTS index, and its colours come from the Theme Engine through
/// [StudioThemeScope] under [StudioId.research].
class ResearchStudioView extends StatefulWidget {
  const ResearchStudioView({
    super.key,
    required this.project,
    this.repository,
    this.service,
    this.onNavigate,
  });

  final StarterProject project;
  final DriftConnectedDomainRepository? repository;
  final ResearchService? service;
  final ValueChanged<ResearchNavigationRequest>? onNavigate;

  @override
  State<ResearchStudioView> createState() => _ResearchStudioViewState();
}

class _ResearchStudioViewState extends State<ResearchStudioView> {
  late final ResearchService _service = widget.service ??
      ResearchService(
        projectId: widget.project.id,
        repository: widget.repository ?? authorOsRepository,
      );

  final TextEditingController _searchController = TextEditingController();

  ResearchFilter _filter = ResearchFilter.empty;
  ResearchDashboard _dashboard = ResearchDashboard.empty;
  List<CodexEntry> _items = const [];
  List<CodexCategory> _categories = const [];
  List<CodexTag> _tags = const [];
  List<ResearchConnectionView> _connections = const [];
  RecordValidationResult? _validation;

  String? _selectedId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CodexEntry? get _selected =>
      _items.where((entry) => entry.id == _selectedId).firstOrNull;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await _service.dashboard();
      final items = await _service.filterResearch(_filter);
      final categories = await _service.categories();
      final tags = await _service.tags();
      if (!mounted) return;
      final nextSelected = items.any((entry) => entry.id == _selectedId)
          ? _selectedId
          : items.isEmpty
              ? null
              : items.first.id;
      setState(() {
        _dashboard = dashboard;
        _items = items;
        _categories = categories;
        _tags = tags;
        _selectedId = nextSelected;
        _loading = false;
      });
      await _loadSelection();
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _readable(caught);
      });
    }
  }

  Future<void> _loadSelection() async {
    final id = _selectedId;
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _connections = const [];
        _validation = null;
      });
      return;
    }
    try {
      final connections = await _service.connectionsFor(id);
      final validation = await _service.validateResearch(id);
      if (!mounted) return;
      setState(() {
        _connections = connections;
        _validation = validation;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connections = const [];
        _validation = null;
      });
    }
  }

  Future<void> _applyFilter(ResearchFilter next) async {
    setState(() {
      _filter = next;
      _busy = true;
    });
    try {
      final items = await _service.filterResearch(next);
      if (!mounted) return;
      setState(() {
        _items = items;
        _selectedId = items.any((entry) => entry.id == _selectedId)
            ? _selectedId
            : items.isEmpty
                ? null
                : items.first.id;
        _busy = false;
      });
      await _loadSelection();
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _readable(caught);
      });
    }
  }

  Future<void> _select(String id) async {
    setState(() => _selectedId = id);
    await _loadSelection();
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (caught) {
      if (!mounted) return;
      setState(() => _busy = false);
      _message(_readable(caught));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createResearch() async {
    final result = await _showEditor();
    if (result == null) return;
    await _guard(() async {
      final created = await _service.createResearch(
        ResearchDraft(
          title: result.title,
          typeId: result.typeId,
          categoryId: result.categoryId,
          summary: result.summary,
          details: result.details,
          notes: result.notes,
          tagIds: result.tagIds,
          canonStatus: result.canonStatus,
          knowledgeStatus: result.knowledgeStatus,
        ),
      );
      _selectedId = created.id;
    });
  }

  Future<void> _editResearch(CodexEntry entry) async {
    final result = await _showEditor(entry: entry);
    if (result == null) return;
    await _guard(() => _service.updateResearch(
          entry.id,
          title: result.title,
          summary: result.summary,
          details: result.details,
          notes: result.notes,
          categoryId: result.categoryId,
          tagIds: result.tagIds,
          canonStatus: result.canonStatus,
          knowledgeStatus: result.knowledgeStatus,
        ));
  }

  Future<void> _archive(CodexEntry entry) =>
      _guard(() => _service.archiveResearch(entry.id));

  Future<void> _restore(CodexEntry entry) =>
      _guard(() => _service.restoreResearch(entry.id));

  Future<void> _delete(CodexEntry entry) async {
    final theme = _resolvedTheme();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _scoped(
        theme,
        AlertDialog(
          key: const ValueKey('research-delete-confirm'),
          title: const Text('Delete research?'),
          content: Text(
            '"${entry.title}" is moved to the deleted state. Its record and '
            'version history are kept, and it stops appearing in the library.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('research-delete-confirm-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _guard(() async {
      await _service.deleteResearch(entry.id);
      _selectedId = null;
    });
  }

  Future<void> _addSource(CodexEntry entry) async {
    final source = await _showSourceEditor();
    if (source == null) return;
    await _guard(() => _service.addSource(entry.id, source));
  }

  Future<void> _removeSource(CodexEntry entry, String sourceId) =>
      _guard(() => _service.removeSource(entry.id, sourceId));

  Future<void> _connect(CodexEntry entry) async {
    final targets = await _service.connectionTargets(excludeId: entry.id);
    if (!mounted) return;
    if (targets.isEmpty) {
      _message('This project has no other records to connect research to yet.');
      return;
    }
    final request = await _showConnectionEditor(entry, targets);
    if (request == null) return;
    await _guard(() => _service.connectResearch(
          researchId: entry.id,
          targetId: request.targetId,
          typeId: request.typeId,
        ));
  }

  Future<void> _disconnect(String linkId) =>
      _guard(() => _service.disconnectResearch(linkId));

  void _openConnected(ResearchConnectionView connection) {
    widget.onNavigate?.call(ResearchNavigationRequest(
      destination: searchDestinationForType(connection.otherTypeId),
      recordId: connection.otherId,
      recordType: connection.otherTypeId,
      title: connection.otherTitle,
    ));
  }

  void _message(String text) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(text)));
  }

  ResolvedTheme _resolvedTheme() => StudioThemeScope.of(context).theme;

  Widget _scoped(ResolvedTheme theme, Widget child) => StudioThemeScope(
        theme: theme,
        studio: StudioId.research,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final outer = StudioThemeScope.of(context);
    return StudioThemeScope(
      theme: outer.theme,
      studio: StudioId.research,
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return Container(
      key: const ValueKey('research-studio'),
      color: scope.color(ThemeColorRef.surface),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, scope),
          const SizedBox(height: 16),
          if (_error != null) ...[
            _ResearchBanner(
              key: const ValueKey('research-error'),
              message: _error!,
            ),
            const SizedBox(height: 16),
          ],
          _ResearchDashboardStrip(
            dashboard: _dashboard,
            categories: _categories,
            onOpen: _select,
            onFilterUnresolved: () =>
                _applyFilter(_filter.copyWith(onlyUnresolved: true)),
          ),
          const SizedBox(height: 16),
          _filterBar(context, scope),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              key: ValueKey('research-loading'),
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final library = _ResearchLibraryList(
                  items: _items,
                  selectedId: _selectedId,
                  connectedIds: _dashboard.connectedItemIds,
                  onSelect: _select,
                );
                final detail = _detailPane(context);
                if (constraints.maxWidth >= 940) {
                  return SizedBox(
                    height: _paneHeight(context),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 340, child: library),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SingleChildScrollView(child: detail),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: _paneHeight(context) / 2, child: library),
                    const SizedBox(height: 16),
                    detail,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  double _paneHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).height - 230).clamp(520.0, 1200.0);

  Widget _header(BuildContext context, StudioThemeScope scope) => Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Research Studio',
                style: scope.text(
                  ThemeTextRole.heading,
                  colorRef: ThemeColorRef.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.project.title} · sources, references, and open '
                'questions kept beside the story.',
                style: scope.text(
                  ThemeTextRole.label,
                  colorRef: ThemeColorRef.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('research-refresh-button'),
                onPressed: _loading || _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                key: const ValueKey('research-new-button'),
                onPressed: _loading || _busy ? null : _createResearch,
                icon: const Icon(Icons.add),
                label: const Text('New research'),
              ),
            ],
          ),
        ],
      );

  Widget _filterBar(BuildContext context, StudioThemeScope scope) {
    final categoryIds = <String>{
      ..._categories.map((category) => category.id),
      ..._dashboard.categoryCounts.keys,
    }.toList()
      ..sort();
    final tagIds = <String>{
      ..._tags.map((tag) => tag.id),
      ..._dashboard.tagCounts.keys,
    }.toList()
      ..sort();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: TextField(
            key: const ValueKey('research-search-field'),
            controller: _searchController,
            onSubmitted: (value) =>
                _applyFilter(_filter.copyWith(query: value)),
            onChanged: (value) => _applyFilter(_filter.copyWith(query: value)),
            decoration: const InputDecoration(
              labelText: 'Search research',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        _ResearchDropdown<String>(
          fieldKey: const ValueKey('research-type-filter'),
          label: 'Type',
          value: _filter.typeIds.length == 1 ? _filter.typeIds.first : '',
          options: [
            const ('', 'All types'),
            for (final id in ResearchRecordTypes.templateIds)
              (id, ResearchRecordTypes.label(id)),
          ],
          onChanged: (value) => _applyFilter(
            _filter.copyWith(typeIds: value.isEmpty ? const {} : {value}),
          ),
        ),
        _ResearchDropdown<String>(
          fieldKey: const ValueKey('research-category-filter'),
          label: 'Category',
          value:
              _filter.categoryIds.length == 1 ? _filter.categoryIds.first : '',
          options: [
            const ('', 'All categories'),
            for (final id in categoryIds) (id, _categoryLabel(id)),
          ],
          onChanged: (value) => _applyFilter(
            _filter.copyWith(categoryIds: value.isEmpty ? const {} : {value}),
          ),
        ),
        _ResearchDropdown<String>(
          fieldKey: const ValueKey('research-tag-filter'),
          label: 'Tag',
          value: _filter.tagIds.length == 1 ? _filter.tagIds.first : '',
          options: [
            const ('', 'All tags'),
            for (final id in tagIds) (id, id),
          ],
          onChanged: (value) => _applyFilter(
            _filter.copyWith(tagIds: value.isEmpty ? const {} : {value}),
          ),
        ),
        _ResearchDropdown<String>(
          fieldKey: const ValueKey('research-canon-filter'),
          label: 'Canon',
          value: _filter.canonStatuses.length == 1
              ? _filter.canonStatuses.first.name
              : '',
          options: [
            const ('', 'Any canon state'),
            for (final status in CodexCanonStatus.values)
              (status.name, codexCanonStatusLabel(status)),
          ],
          onChanged: (value) => _applyFilter(
            _filter.copyWith(
              canonStatuses: value.isEmpty
                  ? const {}
                  : {CodexCanonStatus.values.byName(value)},
            ),
          ),
        ),
        _ResearchDropdown<String>(
          fieldKey: const ValueKey('research-sort-field'),
          label: 'Sort',
          value: _filter.sort.name,
          options: [
            for (final sort in ResearchSort.values)
              (sort.name, researchSortLabel(sort)),
          ],
          onChanged: (value) => _applyFilter(
            _filter.copyWith(sort: ResearchSort.values.byName(value)),
          ),
        ),
        FilterChip(
          key: const ValueKey('research-unresolved-toggle'),
          label: const Text('Unresolved only'),
          selected: _filter.onlyUnresolved,
          onSelected: (selected) =>
              _applyFilter(_filter.copyWith(onlyUnresolved: selected)),
        ),
        FilterChip(
          key: const ValueKey('research-connected-toggle'),
          label: const Text('Connected only'),
          selected: _filter.onlyConnected,
          onSelected: (selected) =>
              _applyFilter(_filter.copyWith(onlyConnected: selected)),
        ),
        FilterChip(
          key: const ValueKey('research-archived-toggle'),
          label: const Text('Show archived'),
          selected: _filter.includeArchived,
          onSelected: (selected) =>
              _applyFilter(_filter.copyWith(includeArchived: selected)),
        ),
        Text(
          '${_items.length} shown',
          key: const ValueKey('research-result-count'),
          style: scope.text(
            ThemeTextRole.label,
            colorRef: ThemeColorRef.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _categoryLabel(String id) =>
      _categories.where((category) => category.id == id).firstOrNull?.name ??
      id;

  Widget _detailPane(BuildContext context) {
    final entry = _selected;
    if (entry == null) {
      return const _ResearchMessage(
        key: ValueKey('research-detail-empty-state'),
        icon: Icons.travel_explore_outlined,
        title: 'Nothing selected',
        body: 'Pick a research item, or create one to start a source trail.',
      );
    }
    return _ResearchDetailPane(
      key: const ValueKey('research-detail-pane'),
      entry: entry,
      categoryLabel: _categoryLabel(entry.categoryId),
      projectId: widget.project.id,
      connections: _connections,
      validation: _validation,
      busy: _busy,
      onEdit: () => _editResearch(entry),
      onArchive: () => _archive(entry),
      onRestore: () => _restore(entry),
      onDelete: () => _delete(entry),
      onAddSource: () => _addSource(entry),
      onRemoveSource: (sourceId) => _removeSource(entry, sourceId),
      onConnect: () => _connect(entry),
      onDisconnect: _disconnect,
      onOpenConnected: _openConnected,
    );
  }

  Future<_ResearchEditorResult?> _showEditor({CodexEntry? entry}) {
    final theme = _resolvedTheme();
    return showDialog<_ResearchEditorResult>(
      context: context,
      builder: (dialogContext) => _scoped(
        theme,
        _ResearchEditorDialog(
          entry: entry,
          categories: _categories,
          knownTags: _tags.map((tag) => tag.id).toList(),
        ),
      ),
    );
  }

  Future<CodexSourceReference?> _showSourceEditor() {
    final theme = _resolvedTheme();
    return showDialog<CodexSourceReference>(
      context: context,
      builder: (dialogContext) => _scoped(theme, const _ResearchSourceDialog()),
    );
  }

  Future<_ResearchConnectionRequest?> _showConnectionEditor(
    CodexEntry entry,
    List<ResearchConnectionTarget> targets,
  ) {
    final theme = _resolvedTheme();
    return showDialog<_ResearchConnectionRequest>(
      context: context,
      builder: (dialogContext) => _scoped(
        theme,
        _ResearchConnectionDialog(
          sourceTypeId: entry.record.typeId,
          targets: targets,
          typesFor: (targetTypeId) => _service.connectionTypesFor(
            sourceTypeId: entry.record.typeId,
            targetTypeId: targetTypeId,
          ),
        ),
      ),
    );
  }
}

String _readable(Object error) {
  if (error is RecordValidationException) {
    final messages = error.result.errors.map((issue) => issue.message);
    return messages.isEmpty ? 'This record is not valid.' : messages.join(' ');
  }
  if (error is ArgumentError) return error.message?.toString() ?? '$error';
  if (error is StateError) return error.message;
  return error.toString();
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class _ResearchDashboardStrip extends StatelessWidget {
  const _ResearchDashboardStrip({
    required this.dashboard,
    required this.categories,
    required this.onOpen,
    required this.onFilterUnresolved,
  });

  final ResearchDashboard dashboard;
  final List<CodexCategory> categories;
  final ValueChanged<String> onOpen;
  final VoidCallback onFilterUnresolved;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return Column(
      key: const ValueKey('research-dashboard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ResearchMetric(
              metricKey: const ValueKey('research-metric-items'),
              label: 'Research items',
              value: '${dashboard.itemCount}',
            ),
            _ResearchMetric(
              metricKey: const ValueKey('research-metric-sources'),
              label: 'Sources',
              value: '${dashboard.sourceCount}',
            ),
            _ResearchMetric(
              metricKey: const ValueKey('research-metric-categories'),
              label: 'Categories',
              value: '${dashboard.categoryCount}',
            ),
            _ResearchMetric(
              metricKey: const ValueKey('research-metric-tags'),
              label: 'Tags',
              value: '${dashboard.tagCount}',
            ),
            _ResearchMetric(
              metricKey: const ValueKey('research-metric-unresolved'),
              label: 'Unresolved',
              value: '${dashboard.unresolvedCount}',
              onTap: dashboard.unresolvedCount == 0 ? null : onFilterUnresolved,
            ),
            _ResearchMetric(
              metricKey: const ValueKey('research-metric-connected'),
              label: 'Connected to project',
              value: '${dashboard.connectedCount}',
            ),
            _ResearchMetric(
              metricKey: const ValueKey('research-metric-archived'),
              label: 'Archived',
              value: '${dashboard.archivedCount}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 320,
              child: _ResearchPanel(
                panelKey: const ValueKey('research-recent-panel'),
                title: 'Recent research',
                emptyMessage: 'Nothing captured yet.',
                children: [
                  for (final entry in dashboard.recent)
                    _ResearchPanelRow(
                      rowKey: ValueKey('research-recent-${entry.id}'),
                      title: entry.title,
                      detail: ResearchRecordTypes.label(entry.recordType),
                      onTap: () => onOpen(entry.id),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 320,
              child: _ResearchPanel(
                panelKey: const ValueKey('research-unresolved-panel'),
                title: 'Unresolved research',
                emptyMessage: 'Everything is verified and sourced.',
                children: [
                  for (final entry in dashboard.unresolved.take(5))
                    _ResearchPanelRow(
                      rowKey: ValueKey('research-unresolved-${entry.id}'),
                      title: entry.title,
                      detail: researchUnresolvedReason(entry),
                      onTap: () => onOpen(entry.id),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 320,
              child: _ResearchPanel(
                panelKey: const ValueKey('research-sources-panel'),
                title: 'Sources',
                emptyMessage: 'No sources cited yet.',
                children: [
                  for (final source in dashboard.sources.take(5))
                    _ResearchPanelRow(
                      rowKey: ValueKey('research-source-${source.id}'),
                      title: source.label,
                      detail: '${source.kind} · cited '
                          '${source.usageCount} '
                          '${source.usageCount == 1 ? 'time' : 'times'}',
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 320,
              child: _ResearchPanel(
                panelKey: const ValueKey('research-categories-panel'),
                title: 'Categories and tags',
                emptyMessage: 'Categorise research to group it here.',
                children: [
                  for (final entry in dashboard.categoryCounts.entries)
                    _ResearchPanelRow(
                      rowKey: ValueKey('research-category-${entry.key}'),
                      title: categories
                              .where(
                                  (category) => category.id == entry.key)
                              .firstOrNull
                              ?.name ??
                          entry.key,
                      detail: '${entry.value} items',
                    ),
                  for (final entry in dashboard.tagCounts.entries)
                    _ResearchPanelRow(
                      rowKey: ValueKey('research-tag-${entry.key}'),
                      title: '#${entry.key}',
                      detail: '${entry.value} items',
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Research connected to the current project: '
          '${dashboard.connectedCount} of ${dashboard.itemCount}',
          key: const ValueKey('research-project-connection-summary'),
          style: scope.text(
            ThemeTextRole.label,
            colorRef: ThemeColorRef.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ResearchMetric extends StatelessWidget {
  const _ResearchMetric({
    required this.metricKey,
    required this.label,
    required this.value,
    this.onTap,
  });

  final Key metricKey;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(scope.radius('card')),
      child: Container(
        key: metricKey,
        width: 168,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scope.color(ThemeColorRef.surfaceContainer),
          border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
          borderRadius: BorderRadius.circular(scope.radius('card')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: scope.text(
                ThemeTextRole.label,
                colorRef: ThemeColorRef.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: scope.text(
                ThemeTextRole.heading,
                colorRef: ThemeColorRef.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchPanel extends StatelessWidget {
  const _ResearchPanel({
    required this.panelKey,
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final Key panelKey;
  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return Container(
      key: panelKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
        borderRadius: BorderRadius.circular(scope.radius('card')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: scope.text(
              ThemeTextRole.ui,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(
              emptyMessage,
              style: scope.text(
                ThemeTextRole.label,
                colorRef: ThemeColorRef.onSurfaceVariant,
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _ResearchPanelRow extends StatelessWidget {
  const _ResearchPanelRow({
    required this.rowKey,
    required this.title,
    required this.detail,
    this.onTap,
  });

  final Key rowKey;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: scope.text(
                ThemeTextRole.body,
                colorRef: ThemeColorRef.onSurface,
              ),
            ),
            if (detail.isNotEmpty)
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: scope.text(
                  ThemeTextRole.label,
                  colorRef: ThemeColorRef.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Library
// ---------------------------------------------------------------------------

class _ResearchLibraryList extends StatelessWidget {
  const _ResearchLibraryList({
    required this.items,
    required this.selectedId,
    required this.connectedIds,
    required this.onSelect,
  });

  final List<CodexEntry> items;
  final String? selectedId;
  final Set<String> connectedIds;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    if (items.isEmpty) {
      return const _ResearchMessage(
        key: ValueKey('research-empty-state'),
        icon: Icons.library_books_outlined,
        title: 'No research yet',
        body: 'Create research, or relax the filters to see archived items.',
      );
    }
    return Container(
      key: const ValueKey('research-library'),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
        borderRadius: BorderRadius.circular(scope.radius('card')),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final entry = items[index];
          return _ResearchTile(
            key: ValueKey('research-item-tile-${entry.id}'),
            entry: entry,
            selected: entry.id == selectedId,
            connected: connectedIds.contains(entry.id),
            onTap: () => onSelect(entry.id),
          );
        },
      ),
    );
  }
}

class _ResearchTile extends StatelessWidget {
  const _ResearchTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.connected,
    required this.onTap,
  });

  final CodexEntry entry;
  final bool selected;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final resolved = researchIsResolved(entry);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(scope.radius('chip')),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? scope.color(ThemeColorRef.selection)
              : scope.color(ThemeColorRef.surface),
          border: Border.all(
            color: selected
                ? scope.color(ThemeColorRef.primary)
                : scope.color(ThemeColorRef.outlineVariant),
          ),
          borderRadius: BorderRadius.circular(scope.radius('chip')),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: scope.text(
                      ThemeTextRole.ui,
                      colorRef: ThemeColorRef.onSurface,
                    ),
                  ),
                ),
                if (entry.isArchived)
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: scope.color(ThemeColorRef.onSurfaceVariant),
                  ),
                if (connected)
                  Icon(
                    Icons.link,
                    size: 16,
                    color: scope.color(ThemeColorRef.primary),
                  ),
                Icon(
                  resolved
                      ? Icons.verified_outlined
                      : Icons.help_outline_rounded,
                  size: 16,
                  color: resolved
                      ? scope.color(ThemeColorRef.primary)
                      : scope.color(ThemeColorRef.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                ResearchRecordTypes.label(entry.recordType),
                codexKnowledgeStatusLabel(entry.knowledgeStatus),
                if (entry.tagIds.isNotEmpty) entry.tagIds.join(', '),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: scope.text(
                ThemeTextRole.label,
                colorRef: ThemeColorRef.onSurfaceVariant,
              ),
            ),
            if (entry.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: scope.text(
                  ThemeTextRole.body,
                  colorRef: ThemeColorRef.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

class _ResearchDetailPane extends StatelessWidget {
  const _ResearchDetailPane({
    super.key,
    required this.entry,
    required this.categoryLabel,
    required this.projectId,
    required this.connections,
    required this.validation,
    required this.busy,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
    required this.onAddSource,
    required this.onRemoveSource,
    required this.onConnect,
    required this.onDisconnect,
    required this.onOpenConnected,
  });

  final CodexEntry entry;
  final String categoryLabel;
  final String projectId;
  final List<ResearchConnectionView> connections;
  final RecordValidationResult? validation;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onAddSource;
  final ValueChanged<String> onRemoveSource;
  final VoidCallback onConnect;
  final ValueChanged<String> onDisconnect;
  final ValueChanged<ResearchConnectionView> onOpenConnected;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final notes = entry.structuredFields['notes'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
        borderRadius: BorderRadius.circular(scope.radius('card')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry.title,
            key: const ValueKey('research-detail-title'),
            style: scope.text(
              ThemeTextRole.heading,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ResearchChip(
                chipKey: const ValueKey('research-detail-type'),
                label: ResearchRecordTypes.label(entry.recordType),
              ),
              _ResearchChip(
                chipKey: const ValueKey('research-detail-category'),
                label: categoryLabel,
              ),
              _ResearchChip(
                chipKey: const ValueKey('research-detail-canon'),
                label: codexCanonStatusLabel(entry.canonStatus),
              ),
              _ResearchChip(
                chipKey: const ValueKey('research-detail-knowledge'),
                label: 'Reliability: '
                    '${codexKnowledgeStatusLabel(entry.knowledgeStatus)}',
              ),
              _ResearchChip(
                chipKey: const ValueKey('research-detail-lifecycle'),
                label: switch (entry.status) {
                  AuthorRecordStatus.active => 'Active',
                  AuthorRecordStatus.archived => 'Archived',
                  AuthorRecordStatus.deleted => 'Deleted',
                },
              ),
              _ResearchChip(
                chipKey: const ValueKey('research-detail-project'),
                label: 'Project: $projectId',
              ),
              for (final tag in entry.tagIds)
                _ResearchChip(
                  chipKey: ValueKey('research-detail-tag-$tag'),
                  label: '#$tag',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('research-edit-button'),
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              if (entry.isArchived)
                OutlinedButton.icon(
                  key: const ValueKey('research-restore-button'),
                  onPressed: busy ? null : onRestore,
                  icon: const Icon(Icons.unarchive_outlined),
                  label: const Text('Restore'),
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey('research-archive-button'),
                  onPressed: busy ? null : onArchive,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Archive'),
                ),
              OutlinedButton.icon(
                key: const ValueKey('research-delete-button'),
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _section(scope, 'Summary'),
          Text(
            entry.summary.isEmpty ? 'No summary yet.' : entry.summary,
            key: const ValueKey('research-detail-summary'),
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          _section(scope, 'Details'),
          Text(
            entry.content.isEmpty ? 'No details recorded.' : entry.content,
            key: const ValueKey('research-detail-details'),
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          _section(scope, 'Notes'),
          Text(
            notes is String && notes.trim().isNotEmpty
                ? notes.trim()
                : 'No research notes.',
            key: const ValueKey('research-detail-notes'),
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _section(scope, 'Sources and links')),
              OutlinedButton.icon(
                key: const ValueKey('research-add-source-button'),
                onPressed: busy ? null : onAddSource,
                icon: const Icon(Icons.add_link),
                label: const Text('Add source'),
              ),
            ],
          ),
          if (entry.sources.isEmpty)
            Text(
              'No sources cited yet.',
              key: const ValueKey('research-sources-empty'),
              style: scope.text(
                ThemeTextRole.label,
                colorRef: ThemeColorRef.onSurfaceVariant,
              ),
            )
          else
            for (final source in entry.sources)
              Padding(
                key: ValueKey('research-source-row-${source.stableId}'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.displayLabel,
                            style: scope.text(
                              ThemeTextRole.body,
                              colorRef: ThemeColorRef.onSurface,
                            ),
                          ),
                          Text(
                            [
                              source.kind,
                              if (source.location.isNotEmpty) source.location,
                              if (source.notes.isNotEmpty) source.notes,
                            ].join(' · '),
                            style: scope.text(
                              ThemeTextRole.label,
                              colorRef: ThemeColorRef.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey(
                          'research-remove-source-${source.stableId}'),
                      tooltip: 'Remove source',
                      onPressed:
                          busy ? null : () => onRemoveSource(source.stableId),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _section(scope, 'Connections')),
              OutlinedButton.icon(
                key: const ValueKey('research-connect-button'),
                onPressed: busy ? null : onConnect,
                icon: const Icon(Icons.hub_outlined),
                label: const Text('Connect'),
              ),
            ],
          ),
          if (connections.isEmpty)
            Text(
              'Not connected to any manuscript, character, world, plot, '
              'timeline or note record yet.',
              key: const ValueKey('research-connections-empty'),
              style: scope.text(
                ThemeTextRole.label,
                colorRef: ThemeColorRef.onSurfaceVariant,
              ),
            )
          else
            for (final connection in connections)
              Padding(
                key: ValueKey('research-connection-${connection.linkId}'),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => onOpenConnected(connection),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              connection.otherTitle,
                              style: scope.text(
                                ThemeTextRole.body,
                                colorRef: ThemeColorRef.onSurface,
                              ),
                            ),
                            Text(
                              '${connection.label} · '
                              '${connection.otherTypeId}',
                              style: scope.text(
                                ThemeTextRole.label,
                                colorRef: ThemeColorRef.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey(
                          'research-disconnect-${connection.linkId}'),
                      tooltip: 'Remove connection',
                      onPressed:
                          busy ? null : () => onDisconnect(connection.linkId),
                      icon: const Icon(Icons.link_off, size: 18),
                    ),
                  ],
                ),
              ),
          if (validation != null && !validation!.isValid) ...[
            const SizedBox(height: 14),
            _ResearchBanner(
              key: const ValueKey('research-validation-banner'),
              message: validation!.errors
                  .map((issue) => issue.message)
                  .join(' '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(StudioThemeScope scope, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title,
          style: scope.text(
            ThemeTextRole.ui,
            colorRef: ThemeColorRef.onSurface,
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Shared chrome
// ---------------------------------------------------------------------------

class _ResearchChip extends StatelessWidget {
  const _ResearchChip({required this.chipKey, required this.label});

  final Key chipKey;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return Container(
      key: chipKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surface),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
        borderRadius: BorderRadius.circular(scope.radius('chip')),
      ),
      child: Text(
        label,
        style: scope.text(
          ThemeTextRole.label,
          colorRef: ThemeColorRef.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ResearchBanner extends StatelessWidget {
  const _ResearchBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.highlight),
        border: Border.all(color: scope.color(ThemeColorRef.outline)),
        borderRadius: BorderRadius.circular(scope.radius('card')),
      ),
      child: Text(
        message,
        style: scope.text(
          ThemeTextRole.body,
          colorRef: ThemeColorRef.onSurface,
        ),
      ),
    );
  }
}

class _ResearchMessage extends StatelessWidget {
  const _ResearchMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
        borderRadius: BorderRadius.circular(scope.radius('card')),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: scope.color(ThemeColorRef.outline)),
          const SizedBox(height: 10),
          Text(
            title,
            style: scope.text(
              ThemeTextRole.ui,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: scope.text(
              ThemeTextRole.label,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResearchDropdown<T> extends StatelessWidget {
  const _ResearchDropdown({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    // A facet can outlive its option — filtering by a tag and then archiving
    // the last item carrying it, for instance. Fall back to the first option
    // rather than letting the dropdown assert on a value it cannot show.
    final selected = options.any((option) => option.$1 == value)
        ? value
        : options.first.$1;
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: scope.text(
            ThemeTextRole.label,
            colorRef: ThemeColorRef.onSurfaceVariant,
          ),
        ),
        DropdownButton<T>(
          value: selected,
          underline: const SizedBox.shrink(),
          items: [
            for (final option in options)
              DropdownMenuItem<T>(
                value: option.$1,
                child: Text(option.$2),
              ),
          ],
          onChanged: (next) {
            if (next == null) return;
            onChanged(next);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class _ResearchEditorResult {
  const _ResearchEditorResult({
    required this.title,
    required this.typeId,
    required this.categoryId,
    required this.summary,
    required this.details,
    required this.notes,
    required this.tagIds,
    required this.canonStatus,
    required this.knowledgeStatus,
  });

  final String title;
  final String typeId;
  final String categoryId;
  final String summary;
  final String details;
  final String notes;
  final List<String> tagIds;
  final CodexCanonStatus canonStatus;
  final CodexKnowledgeStatus knowledgeStatus;
}

class _ResearchEditorDialog extends StatefulWidget {
  const _ResearchEditorDialog({
    required this.entry,
    required this.categories,
    required this.knownTags,
  });

  final CodexEntry? entry;
  final List<CodexCategory> categories;
  final List<String> knownTags;

  @override
  State<_ResearchEditorDialog> createState() => _ResearchEditorDialogState();
}

class _ResearchEditorDialogState extends State<_ResearchEditorDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.entry?.title ?? '');
  late final TextEditingController _summary =
      TextEditingController(text: widget.entry?.summary ?? '');
  late final TextEditingController _details =
      TextEditingController(text: widget.entry?.content ?? '');
  late final TextEditingController _notes = TextEditingController(
    text: widget.entry?.structuredFields['notes'] is String
        ? widget.entry!.structuredFields['notes'] as String
        : '',
  );
  late final TextEditingController _tags = TextEditingController(
    text: widget.entry?.tagIds.join(', ') ?? '',
  );

  late String _typeId = _initialType();
  late String _categoryId = widget.entry?.categoryId ?? 'research';
  late CodexCanonStatus _canonStatus =
      widget.entry?.canonStatus ?? CodexCanonStatus.draft;
  late CodexKnowledgeStatus _knowledgeStatus =
      widget.entry?.knowledgeStatus ?? CodexKnowledgeStatus.unknown;
  String? _error;

  String _initialType() {
    final entry = widget.entry;
    if (entry == null) return ResearchRecordTypes.entryTypeId;
    final resolved = ResearchRecordTypes.resolveTemplate(entry.recordType);
    return ResearchRecordTypes.templateIds.contains(resolved)
        ? resolved
        : ResearchRecordTypes.entryTypeId;
  }

  List<String> get _categoryIds {
    final ids = <String>{
      ...ResearchRecordTypes.categoryIds,
      ...widget.categories.map((category) => category.id),
      _categoryId,
    }.toList()
      ..sort();
    return ids;
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _details.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'A research title is required.');
      return;
    }
    Navigator.of(context).pop(_ResearchEditorResult(
      title: title,
      typeId: _typeId,
      categoryId: _categoryId,
      summary: _summary.text.trim(),
      details: _details.text.trim(),
      notes: _notes.text.trim(),
      tagIds: _tags.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList(),
      canonStatus: _canonStatus,
      knowledgeStatus: _knowledgeStatus,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final editing = widget.entry != null;
    return AlertDialog(
      key: const ValueKey('research-editor-dialog'),
      title: Text(editing ? 'Edit research' : 'New research'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('research-editor-title'),
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const ValueKey('research-editor-type'),
                isExpanded: true,
                initialValue: _typeId,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final id in ResearchRecordTypes.templateIds)
                    DropdownMenuItem(
                      value: id,
                      child: Text(ResearchRecordTypes.label(id)),
                    ),
                ],
                onChanged: editing
                    ? null
                    : (value) => setState(
                          () => _typeId = value ?? _typeId,
                        ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: const ValueKey('research-editor-category'),
                isExpanded: true,
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final id in _categoryIds)
                    DropdownMenuItem(
                      value: id,
                      child: Text(
                        widget.categories
                                .where((category) => category.id == id)
                                .firstOrNull
                                ?.name ??
                            id,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _categoryId = value ?? _categoryId),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('research-editor-summary'),
                controller: _summary,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Summary'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('research-editor-details'),
                controller: _details,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Details'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('research-editor-notes'),
                controller: _notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('research-editor-tags'),
                controller: _tags,
                decoration: InputDecoration(
                  labelText: 'Tags (comma separated)',
                  helperText: widget.knownTags.isEmpty
                      ? null
                      : 'In use: ${widget.knownTags.take(6).join(', ')}',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<CodexCanonStatus>(
                key: const ValueKey('research-editor-canon'),
                isExpanded: true,
                initialValue: _canonStatus,
                decoration: const InputDecoration(labelText: 'Canon status'),
                items: [
                  for (final status in CodexCanonStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(codexCanonStatusLabel(status)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _canonStatus = value ?? _canonStatus),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<CodexKnowledgeStatus>(
                key: const ValueKey('research-editor-knowledge'),
                isExpanded: true,
                initialValue: _knowledgeStatus,
                decoration: const InputDecoration(
                  labelText: 'Reliability (knowledge status)',
                ),
                items: [
                  for (final status in CodexKnowledgeStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(codexKnowledgeStatusLabel(status)),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _knowledgeStatus = value ?? _knowledgeStatus,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  key: const ValueKey('research-editor-error'),
                  style: scope.text(
                    ThemeTextRole.label,
                    colorRef: ThemeColorRef.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('research-editor-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('research-editor-save'),
          onPressed: _submit,
          child: Text(editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _ResearchSourceDialog extends StatefulWidget {
  const _ResearchSourceDialog();

  @override
  State<_ResearchSourceDialog> createState() => _ResearchSourceDialogState();
}

class _ResearchSourceDialogState extends State<_ResearchSourceDialog> {
  final TextEditingController _label = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  String _kind = 'external';
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = 'A source label is required.');
      return;
    }
    Navigator.of(context).pop(CodexSourceReference(
      recordId: '',
      kind: _kind,
      label: label,
      location: _location.text.trim(),
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return AlertDialog(
      key: const ValueKey('research-source-dialog'),
      title: const Text('Add source'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('research-source-label'),
              controller: _label,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Source'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: const ValueKey('research-source-kind'),
              isExpanded: true,
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: [
                for (final kind in codexSourceKinds)
                  DropdownMenuItem(value: kind, child: Text(kind)),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('research-source-location'),
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Link or location',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('research-source-notes'),
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                key: const ValueKey('research-source-error'),
                style: scope.text(
                  ThemeTextRole.label,
                  colorRef: ThemeColorRef.primary,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('research-source-save'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _ResearchConnectionRequest {
  const _ResearchConnectionRequest({
    required this.targetId,
    required this.typeId,
  });

  final String targetId;
  final String typeId;
}

class _ResearchConnectionDialog extends StatefulWidget {
  const _ResearchConnectionDialog({
    required this.sourceTypeId,
    required this.targets,
    required this.typesFor,
  });

  final String sourceTypeId;
  final List<ResearchConnectionTarget> targets;
  final Future<List<ConnectionTypeDefinition>> Function(String targetTypeId)
      typesFor;

  @override
  State<_ResearchConnectionDialog> createState() =>
      _ResearchConnectionDialogState();
}

class _ResearchConnectionDialogState extends State<_ResearchConnectionDialog> {
  late String _targetId = widget.targets.first.id;
  List<ConnectionTypeDefinition> _types = const [];
  String? _typeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    setState(() => _loading = true);
    final target =
        widget.targets.firstWhere((entity) => entity.id == _targetId);
    final types = await widget.typesFor(target.typeId);
    if (!mounted) return;
    setState(() {
      _types = types;
      _typeId = types.isEmpty ? null : types.first.id;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return AlertDialog(
      key: const ValueKey('research-connection-dialog'),
      title: const Text('Connect research'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('research-connection-target'),
              isExpanded: true,
              initialValue: _targetId,
              decoration: const InputDecoration(labelText: 'Record'),
              items: [
                for (final target in widget.targets)
                  DropdownMenuItem(
                    value: target.id,
                    child: Text(
                      '${target.title} (${target.typeId})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _targetId = value);
                _loadTypes();
              },
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_types.isEmpty)
              Text(
                'No connection type joins ${widget.sourceTypeId} to this '
                'record. Pick another record.',
                key: const ValueKey('research-connection-unavailable'),
                style: scope.text(
                  ThemeTextRole.label,
                  colorRef: ThemeColorRef.onSurfaceVariant,
                ),
              )
            else
              DropdownButtonFormField<String>(
                key: const ValueKey('research-connection-type'),
                isExpanded: true,
                initialValue: _typeId,
                decoration: const InputDecoration(labelText: 'Relationship'),
                items: [
                  for (final type in _types)
                    DropdownMenuItem(
                      value: type.id,
                      child: Text(type.displayName),
                    ),
                ],
                onChanged: (value) => setState(() => _typeId = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('research-connection-save'),
          onPressed: _typeId == null
              ? null
              : () => Navigator.of(context).pop(
                    _ResearchConnectionRequest(
                      targetId: _targetId,
                      typeId: _typeId!,
                    ),
                  ),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
