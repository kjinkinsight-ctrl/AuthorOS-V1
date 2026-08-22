import 'package:flutter/material.dart';

import 'continuity.dart';
import 'continuity_actions.dart';
import 'core/branch_domain.dart';
import 'core/connected_domain.dart';
import 'core/connection_types.dart';
import 'core/record_inspection.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/safe_delete.dart';
import 'core/search_models.dart';
import 'core/template_engine.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/world_record_types.dart';
import 'knowledge_graph/open_in_graph.dart';
import 'persistence/authoros_database.dart';
import 'world_continuity.dart';
import 'world_service.dart';

/// Where a connected record lives, so the shell can switch Studios.
class WorldNavigationRequest {
  const WorldNavigationRequest({
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

enum WorldSaveState { idle, saving, saved, failed }

enum _WorldTab {
  overview,
  fields,
  hierarchy,
  connections,
  maps,
  markers,
  routes,
  continuity,
  inspector,
  history,
}

String _tabLabel(_WorldTab tab) => switch (tab) {
      _WorldTab.overview => 'Overview',
      _WorldTab.fields => 'Fields',
      _WorldTab.hierarchy => 'Hierarchy',
      _WorldTab.connections => 'Connections',
      _WorldTab.maps => 'Maps',
      _WorldTab.markers => 'Markers',
      _WorldTab.routes => 'Routes',
      _WorldTab.continuity => 'Continuity',
      _WorldTab.inspector => 'Inspector',
      _WorldTab.history => 'History',
    };

/// The writer-facing World Studio workspace.
///
/// Every read and write goes through [WorldService], which composes
/// `RecordService`, `RecordTypeRegistry`, `TemplateEngine`, `ConnectionEngine`,
/// `BranchService`, `UniversalSearchService`, `UniversalRecordInspector`,
/// `VersionAuditService` and `SafeDeleteService`. The workspace owns no store,
/// index or history of its own and all World data stays a Universal Record.
class WorldWorkspace extends StatefulWidget {
  const WorldWorkspace({
    super.key,
    required this.projectId,
    this.repository,
    this.onNavigate,
    this.continuity = const WorldContinuityIntelligence(),
  });

  final String projectId;
  final DriftConnectedDomainRepository? repository;
  final ValueChanged<WorldNavigationRequest>? onNavigate;
  final WorldContinuityIntelligence continuity;

  @override
  State<WorldWorkspace> createState() => _WorldWorkspaceState();
}

class _WorldWorkspaceState extends State<WorldWorkspace> {
  final searchController = TextEditingController();
  late final WorldService service;

  WorldFilter filter = WorldFilter.empty;
  WorldEditorMode editorMode = WorldEditorMode.simple;
  String? activeBranchId;
  String? selectedId;
  Set<String> expanded = <String>{};

  List<AuthorRecord> allRecords = const [];
  List<AuthorRecord> visible = const [];
  List<WorldTreeNode> tree = const [];
  List<RecordTypeDefinition> templates = const [];
  List<StoryBranch> branches = const [];
  Map<String, RecordValidationResult> validation = const {};
  Map<String, TemplateCompatibilityReport> templateReports = const {};

  bool loading = true;
  bool busy = false;
  String? loadError;
  WorldSaveState saveState = WorldSaveState.idle;
  String saveMessage = '';

  @override
  void initState() {
    super.initState();
    service = WorldService(
      projectId: widget.projectId,
      repository: widget.repository ?? authorOsRepository,
    );
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  AuthorRecord? get selected =>
      allRecords.where((record) => record.id == selectedId).firstOrNull;

  bool get onBranch => activeBranchId != null;

  String get branchName =>
      branches.where((branch) => branch.id == activeBranchId).firstOrNull?.name ??
      activeBranchId ??
      '';

  Future<void> _load() async {
    try {
      final records = await service.worldRecords(branchId: activeBranchId);
      final filtered = await service.filterWorldRecords(
        filter,
        branchId: activeBranchId,
      );
      final results = await Future.wait<Object>([
        service.validateRecords(records),
        service.templateReports(records),
        service.worldTemplates(),
        service.getBranches(),
        service.hierarchyTree(
          branchId: activeBranchId,
          visibleIds: filter.isEmpty
              ? null
              : filtered.map((record) => record.id).toSet(),
          includeArchived: filter.includeArchived,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        allRecords = records;
        visible = filtered;
        validation = results[0] as Map<String, RecordValidationResult>;
        templateReports =
            results[1] as Map<String, TemplateCompatibilityReport>;
        templates = results[2] as List<RecordTypeDefinition>;
        branches = results[3] as List<StoryBranch>;
        tree = results[4] as List<WorldTreeNode>;
        loading = false;
        loadError = null;
        // First load opens the whole hierarchy: a collapsed tree hides the
        // world instead of introducing it.
        if (expanded.isEmpty) {
          expanded = {for (final node in tree) ...node.allIds};
        }
        if (!filter.isEmpty) {
          expanded = {
            ...expanded,
            for (final node in tree) ...node.allIds,
          };
        }
        if (selectedId != null &&
            !records.any((record) => record.id == selectedId)) {
          selectedId = null;
        }
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = caught.toString();
      });
    }
  }

  Future<void> _applyFilter(WorldFilter next) async {
    setState(() {
      filter = next;
      busy = true;
    });
    final filtered = await service.filterWorldRecords(
      next,
      branchId: activeBranchId,
    );
    final nextTree = await service.hierarchyTree(
      branchId: activeBranchId,
      visibleIds:
          next.isEmpty ? null : filtered.map((record) => record.id).toSet(),
      includeArchived: next.includeArchived,
    );
    if (!mounted) return;
    setState(() {
      visible = filtered;
      tree = nextTree;
      busy = false;
      if (!next.isEmpty) {
        expanded = {
          ...expanded,
          for (final node in nextTree) ...node.allIds,
        };
      }
    });
  }

  Future<void> _switchBranch(String? branchId) async {
    setState(() {
      activeBranchId = branchId;
      selectedId = null;
      expanded = <String>{};
      loading = true;
    });
    await _load();
  }

  /// Runs a mutation and reports it through the shared save indicator.
  Future<bool> _mutate(
    Future<void> Function() action, {
    required String success,
  }) async {
    setState(() {
      saveState = WorldSaveState.saving;
      saveMessage = 'Saving…';
    });
    try {
      await action();
      if (!mounted) return true;
      await _load();
      if (!mounted) return true;
      setState(() {
        saveState = WorldSaveState.saved;
        saveMessage = success;
      });
      return true;
    } catch (caught) {
      if (!mounted) return false;
      setState(() {
        saveState = WorldSaveState.failed;
        saveMessage = _readableError(caught);
      });
      return false;
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('world-confirm-dialog'),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('world-confirm-button'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _navigate(AuthorRecord record) {
    widget.onNavigate?.call(WorldNavigationRequest(
      destination: searchDestinationForType(record.typeId),
      recordId: record.id,
      recordType: record.typeId,
      title: record.title,
    ));
  }

  /// Asks the shell for the Knowledge Graph, focused on [record].
  ///
  /// Separate from [_navigate], which always routes a record to the Studio
  /// that owns it — the graph is a different destination, not a different
  /// owner.
  void _openInGraph(AuthorRecord record) {
    widget.onNavigate?.call(WorldNavigationRequest(
      destination: SearchDestination.knowledgeGraph,
      recordId: record.id,
      recordType: record.typeId,
      title: record.title,
    ));
  }

  void _openRecord(AuthorRecord record) {
    final destination = searchDestinationForType(record.typeId);
    final ownedHere = destination == SearchDestination.worldStudio ||
        destination == SearchDestination.record;
    if (ownedHere && allRecords.any((item) => item.id == record.id)) {
      setState(() => selectedId = record.id);
      return;
    }
    _navigate(record);
  }

  // --- Commands -----------------------------------------------------------

  Future<void> _createRecord() async {
    if (templates.isEmpty) return;
    final spatialTemplates = templates
        .where((template) =>
            WorldRecordTypes.spatialTypeIds.contains(template.id) ||
            WorldRecordTypes.mapTypeIds.contains(template.id) ||
            !WorldRecordTypes.isBuiltInWorldType(template.id))
        .toList();
    if (spatialTemplates.isEmpty) return;
    final draft = await showDialog<_WorldCreateResult>(
      context: context,
      builder: (context) => _WorldCreateDialog(
        templates: spatialTemplates,
        places: allRecords
            .where((record) =>
                WorldRecordTypes.spatialTypeIds.contains(record.typeId))
            .toList(),
        onBranch: onBranch,
        branchId: activeBranchId,
      ),
    );
    if (draft == null) return;
    String? createdId;
    final saved = await _mutate(
      () async {
        final record = await service.createWorldRecord(
          id: draft.id,
          title: draft.title,
          typeId: draft.typeId,
          templateId: draft.templateId,
          fields: draft.fields,
          scopeType: activeBranchId == null
              ? RecordScopeType.project
              : RecordScopeType.branch,
          scopeId: activeBranchId,
          branchId: activeBranchId,
          canonState: draft.canonState,
        );
        createdId = record.id;
        if (draft.parentId != null && draft.parentId!.isNotEmpty) {
          await service.setParent(
            childId: record.id,
            parentId: draft.parentId!,
            branchId: activeBranchId,
          );
        }
        if (draft.mappedRecordId != null && draft.mappedRecordId!.isNotEmpty) {
          await service.connectRecord(
            sourceId: record.id,
            targetId: draft.mappedRecordId!,
            typeId: 'maps',
            activeBranchId: activeBranchId,
          );
        }
      },
      success: 'Created ${draft.title}',
    );
    if (saved && createdId != null && mounted) {
      setState(() => selectedId = createdId);
    }
  }

  Future<void> _archive(AuthorRecord record) async {
    if (onBranch) {
      _notify('Archiving changes Canon. Leave the $branchName branch first.');
      return;
    }
    final analysis = await service.analyzeDelete(record.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('world-archive-dialog'),
        title: Text('Archive ${record.title}?'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Archiving hides the record from the workspace. Nothing is '
                'deleted: children, connections, markers, routes, history and '
                'branch overlays are kept and the record can be restored at '
                'any time.',
              ),
              if (analysis != null) ...[
                const SizedBox(height: 12),
                _SafeDeleteSummary(
                  key: const Key('world-safe-delete-summary'),
                  analysis: analysis,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('world-archive-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _mutate(
      () => service.archiveWorldRecord(record.id),
      success: 'Archived ${record.title}',
    );
  }

  Future<void> _restore(AuthorRecord record) async {
    if (onBranch) {
      _notify('Restoring changes Canon. Leave the $branchName branch first.');
      return;
    }
    await _mutate(
      () => service.restoreWorldRecord(record.id),
      success: 'Restored ${record.title}',
    );
  }

  Future<void> _duplicate(AuthorRecord record) async {
    if (onBranch) {
      _notify('Duplicating writes a new Canon record. Leave the $branchName '
          'branch first.');
      return;
    }
    await _mutate(
      () => service.duplicateWorldRecord(
        record.id,
        newId: '${record.id}-copy-${record.revision + 1}',
      ),
      success: 'Duplicated ${record.title}',
    );
  }

  Future<void> _showSafeDelete(AuthorRecord record) async {
    final analysis = await service.analyzeDelete(record.id);
    if (!mounted || analysis == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('world-safe-delete-dialog'),
        title: Text('Safe delete: ${record.title}'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: _SafeDeleteSummary(analysis: analysis, detailed: true),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        key: Key('world-loading-state'),
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (loadError != null) {
      return _WorldMessage(
        key: const Key('world-error-state'),
        icon: Icons.error_outline,
        title: 'World Studio could not be opened.',
        message: loadError!,
        actionLabel: 'Try again',
        onAction: () {
          setState(() => loading = true);
          _load();
        },
      );
    }

    return Material(
      key: const Key('world-workspace'),
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final rail = _WorldFilterRail(
              filter: filter,
              records: allRecords,
              templates: templates,
              searchController: searchController,
              onFilterChanged: _applyFilter,
            );
            final browser = _WorldBrowser(
              filter: filter,
              tree: tree,
              records: visible,
              expanded: expanded,
              selectedId: selectedId,
              validation: validation,
              templateReports: templateReports,
              busy: busy,
              hasAnyRecords: allRecords.isNotEmpty,
              onSelect: (id) => setState(() => selectedId = id),
              onToggle: (id) => setState(() {
                expanded.contains(id) ? expanded.remove(id) : expanded.add(id);
              }),
              onCreate: _createRecord,
              onClearFilters: () {
                searchController.clear();
                _applyFilter(WorldFilter.empty);
              },
            );
            final record = selected;
            final detail = record == null
                ? const _WorldMessage(
                    key: Key('world-detail-empty-state'),
                    icon: Icons.public_outlined,
                    title: 'Select a place',
                    message:
                        'Choose a record to read it, edit its fields, manage '
                        'its hierarchy, maps, markers, routes and connections.',
                  )
                : _WorldRecordPane(
                    key: ValueKey('world-pane-${record.id}'),
                    service: service,
                    record: record,
                    records: allRecords,
                    templates: templates,
                    editorMode: editorMode,
                    activeBranchId: activeBranchId,
                    validation: validation[record.id],
                    templateReport: templateReports[record.id],
                    continuity: widget.continuity,
                    saveState: saveState,
                    saveMessage: saveMessage,
                    onEditorModeChanged: (mode) =>
                        setState(() => editorMode = mode),
                    onMutate: _mutate,
                    onConfirm: _confirm,
                    onNotify: _notify,
                    onArchive: () => _archive(record),
                    onRestore: () => _restore(record),
                    onDuplicate: () => _duplicate(record),
                    onSafeDelete: () => _showSafeDelete(record),
                    onOpenRecord: _openRecord,
                    onNavigate: _navigate,
                    onOpenInGraph: _openInGraph,
                  );

            if (constraints.maxWidth >= 1180) {
              return SizedBox(
                height: _paneHeight(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 262,
                      child: SingleChildScrollView(child: rail),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 348,
                      child: SingleChildScrollView(child: browser),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(child: detail)),
                  ],
                ),
              );
            }
            if (constraints.maxWidth >= 860) {
              return SizedBox(
                height: _paneHeight(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 330,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            rail,
                            const SizedBox(height: 16),
                            browser,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(child: detail)),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rail,
                const SizedBox(height: 16),
                browser,
                const SizedBox(height: 16),
                detail,
              ],
            );
          }),
        ],
      ),
    );
  }

  double _paneHeight(BuildContext context) =>
      (MediaQuery.sizeOf(context).height - 230).clamp(520.0, 1200.0);

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
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
                  'World Studio',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${allRecords.length} world record'
                  '${allRecords.length == 1 ? '' : 's'} in this project.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _WorldSaveIndicator(state: saveState, message: saveMessage),
                if (branches.isNotEmpty)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      key: const Key('world-branch-selector'),
                      initialValue: activeBranchId ?? _canonBranchValue,
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Reading',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _canonBranchValue,
                          child: Text('Canon'),
                        ),
                        for (final branch in branches)
                          DropdownMenuItem(
                            key: Key('world-branch-option-${branch.id}'),
                            value: branch.id,
                            child: Text(branch.name),
                          ),
                      ],
                      onChanged: (value) => _switchBranch(
                        value == _canonBranchValue ? null : value,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  key: const Key('world-new-record-button'),
                  onPressed: templates.isEmpty ? null : _createRecord,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('New record'),
                ),
              ],
            ),
          ],
        ),
        if (onBranch) ...[
          const SizedBox(height: 12),
          _WorldBanner(
            key: const Key('world-branch-banner'),
            icon: Icons.alt_route_rounded,
            message: 'You are reading the "$branchName" branch. Edits are '
                'saved as branch overrides and Canon is left untouched.',
          ),
        ],
      ],
    );
  }
}

const _canonBranchValue = '__canon__';

// ---------------------------------------------------------------------------
// Filter rail
// ---------------------------------------------------------------------------

class _WorldFilterRail extends StatelessWidget {
  const _WorldFilterRail({
    required this.filter,
    required this.records,
    required this.templates,
    required this.searchController,
    required this.onFilterChanged,
  });

  final WorldFilter filter;
  final List<AuthorRecord> records;
  final List<RecordTypeDefinition> templates;
  final TextEditingController searchController;
  final ValueChanged<WorldFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = <String>{for (final record in records) ...record.tags}.toList()
      ..sort();
    final groupTypes = filter.group.typeIds;
    final presentTypes = <String>{
      for (final record in records)
        if (groupTypes.contains(record.typeId)) record.typeId,
    }.toList()
      ..sort();
    return _WorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('world-search-field'),
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Find a place',
              hintText: 'Name, description, tag',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (value) =>
                onFilterChanged(filter.copyWith(query: value)),
            onChanged: (value) => onFilterChanged(filter.copyWith(query: value)),
          ),
          const SizedBox(height: 16),
          _railHeader(context, 'Show'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in WorldRecordGroup.values)
                ChoiceChip(
                  key: Key('world-group-filter-${group.name}'),
                  label: Text(group.label),
                  selected: filter.group == group,
                  onSelected: (_) => onFilterChanged(
                    filter.copyWith(group: group, typeIds: const {}),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _railHeader(context, 'Record type'),
          const SizedBox(height: 8),
          if (presentTypes.isEmpty)
            Text('No records of this kind yet.',
                style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final typeId in presentTypes)
                  FilterChip(
                    key: Key('world-type-filter-$typeId'),
                    label: Text(_templateName(typeId)),
                    selected: filter.typeIds.contains(typeId),
                    onSelected: (_) =>
                        onFilterChanged(filter.toggleType(typeId)),
                  ),
              ],
            ),
          const SizedBox(height: 18),
          _railHeader(context, 'Canon state'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final state in worldCanonStateOrder)
                FilterChip(
                  key: Key('world-canon-filter-${_slug(state)}'),
                  label: Text(state),
                  selected: filter.canonStates.contains(state),
                  onSelected: (_) =>
                      onFilterChanged(filter.toggleCanonState(state)),
                ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 18),
            _railHeader(context, 'Tags'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tags)
                  FilterChip(
                    key: Key('world-tag-filter-$tag'),
                    label: Text(tag),
                    selected: filter.tagIds.contains(tag),
                    onSelected: (_) => onFilterChanged(filter.toggleTag(tag)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _railHeader(context, 'Sort'),
          const SizedBox(height: 8),
          DropdownButtonFormField<WorldSort>(
            key: const Key('world-sort-field'),
            initialValue: filter.sort,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: WorldSort.hierarchy,
                child: Text('Hierarchy'),
              ),
              DropdownMenuItem(
                value: WorldSort.title,
                child: Text('Name (A–Z)'),
              ),
              DropdownMenuItem(
                value: WorldSort.recentlyUpdated,
                child: Text('Recently updated'),
              ),
            ],
            onChanged: (value) => onFilterChanged(filter.copyWith(sort: value)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('world-include-archived-toggle'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include archived'),
            value: filter.includeArchived,
            onChanged: (value) =>
                onFilterChanged(filter.copyWith(includeArchived: value)),
          ),
          SwitchListTile(
            key: const Key('world-needs-attention-toggle'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Needs attention'),
            subtitle: const Text('Validation errors or warnings'),
            value: filter.onlyInvalid,
            onChanged: (value) =>
                onFilterChanged(filter.copyWith(onlyInvalid: value)),
          ),
          if (!filter.isEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('world-clear-filters-button'),
                onPressed: () {
                  searchController.clear();
                  onFilterChanged(WorldFilter.empty);
                },
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text('Clear ${filter.activeFacetCount} filter'
                    '${filter.activeFacetCount == 1 ? '' : 's'}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _templateName(String typeId) =>
      templates.where((item) => item.id == typeId).firstOrNull?.name ?? typeId;

  Widget _railHeader(BuildContext context, String title) => Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
      );
}

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'(^-+|-+$)'), '');

// ---------------------------------------------------------------------------
// Hierarchy tree and record list
// ---------------------------------------------------------------------------

class _WorldBrowser extends StatelessWidget {
  const _WorldBrowser({
    required this.filter,
    required this.tree,
    required this.records,
    required this.expanded,
    required this.selectedId,
    required this.validation,
    required this.templateReports,
    required this.busy,
    required this.hasAnyRecords,
    required this.onSelect,
    required this.onToggle,
    required this.onCreate,
    required this.onClearFilters,
  });

  final WorldFilter filter;
  final List<WorldTreeNode> tree;
  final List<AuthorRecord> records;
  final Set<String> expanded;
  final String? selectedId;
  final Map<String, RecordValidationResult> validation;
  final Map<String, TemplateCompatibilityReport> templateReports;
  final bool busy;
  final bool hasAnyRecords;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onToggle;
  final VoidCallback onCreate;
  final VoidCallback onClearFilters;

  bool get _isTree =>
      filter.group == WorldRecordGroup.spatial &&
      filter.sort == WorldSort.hierarchy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _isTree
        ? [for (final node in tree) ...node.flatten(expanded)]
        : const <WorldTreeNode>[];
    final count = _isTree ? rows.length : records.length;
    return _WorldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isTree ? 'World hierarchy' : filter.group.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  '$count',
                  key: const Key('world-result-count'),
                  style: theme.textTheme.labelMedium,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (count == 0)
            hasAnyRecords
                ? _WorldMessage(
                    key: const Key('world-no-results-state'),
                    icon: Icons.search_off_rounded,
                    title: 'Nothing matches this view',
                    message:
                        'No world record matches the current filters.',
                    actionLabel: filter.isEmpty ? null : 'Clear filters',
                    onAction: filter.isEmpty ? null : onClearFilters,
                  )
                : _WorldMessage(
                    key: const Key('world-empty-state'),
                    icon: Icons.public_outlined,
                    title: 'The world is empty',
                    message:
                        'Create your first place from a template to start '
                        'building the world hierarchy.',
                    actionLabel: 'New record',
                    onAction: onCreate,
                  )
          else if (_isTree)
            for (final node in rows)
              _WorldTreeRow(
                key: Key('world-tree-node-${node.id}'),
                node: node,
                selected: node.id == selectedId,
                expanded: expanded.contains(node.id),
                badge: worldValidationBadge(
                  validation[node.id],
                  templateReports[node.id],
                ),
                onSelect: () => onSelect(node.id),
                onToggle: () => onToggle(node.id),
              )
          else
            for (final record in records)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WorldRecordRow(
                  key: Key('world-record-tile-${record.id}'),
                  record: record,
                  selected: record.id == selectedId,
                  badge: worldValidationBadge(
                    validation[record.id],
                    templateReports[record.id],
                  ),
                  onTap: () => onSelect(record.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _WorldTreeRow extends StatelessWidget {
  const _WorldTreeRow({
    super.key,
    required this.node,
    required this.selected,
    required this.expanded,
    required this.badge,
    required this.onSelect,
    required this.onToggle,
  });

  final WorldTreeNode node;
  final bool selected;
  final bool expanded;
  final WorldValidationBadge? badge;
  final VoidCallback onSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final record = node.record;
    final archived = record.status == AuthorRecordStatus.archived;
    return Padding(
      padding: EdgeInsets.only(left: node.depth * 14.0, bottom: 4),
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('world-tree-select-${node.id}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: node.hasChildren
                      ? IconButton(
                          key: Key('world-tree-toggle-${node.id}'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          tooltip: expanded ? 'Collapse' : 'Expand',
                          onPressed: onToggle,
                          icon: Icon(
                            expanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.chevron_right_rounded,
                            size: 18,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Icon(worldTypeIcon(record.typeId), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.title,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: node.matchesFilter
                              ? null
                              : scheme.onSurfaceVariant,
                        ),
                  ),
                ),
                if (archived)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.archive_outlined, size: 14),
                  ),
                if (badge != null)
                  Tooltip(
                    message: badge!.message,
                    child: Icon(
                      badge!.icon,
                      key: Key('world-validation-badge-${node.id}'),
                      size: 14,
                      color: badge!.isError ? scheme.error : scheme.tertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldRecordRow extends StatelessWidget {
  const _WorldRecordRow({
    super.key,
    required this.record,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final AuthorRecord record;
  final bool selected;
  final WorldValidationBadge? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(worldTypeIcon(record.typeId), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${record.typeId} · ${worldCanonState(record)}'
                      '${record.status == AuthorRecordStatus.archived ? ' · Archived' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Tooltip(
                  message: badge!.message,
                  child: Icon(
                    badge!.icon,
                    key: Key('world-validation-badge-${record.id}'),
                    size: 16,
                    color: badge!.isError ? scheme.error : scheme.tertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Validation summary shown next to a World record.
class WorldValidationBadge {
  const WorldValidationBadge({
    required this.icon,
    required this.message,
    required this.isError,
  });

  final IconData icon;
  final String message;
  final bool isError;
}

WorldValidationBadge? worldValidationBadge(
  RecordValidationResult? validation,
  TemplateCompatibilityReport? templateReport,
) {
  if (validation != null && validation.errors.isNotEmpty) {
    return WorldValidationBadge(
      icon: Icons.error_outline,
      message: validation.errors.map((issue) => issue.message).join('\n'),
      isError: true,
    );
  }
  if (templateReport != null && !templateReport.isReadable) {
    return WorldValidationBadge(
      icon: Icons.error_outline,
      message: 'Template ${templateReport.templateId} cannot be resolved.',
      isError: true,
    );
  }
  final warnings = <String>[
    if (validation != null) ...validation.warnings.map((issue) => issue.message),
    if (templateReport != null &&
        templateReport.status == TemplateCompatibilityStatus.upgradeAvailable)
      'A newer version of the ${templateReport.templateId} template is '
          'available.',
    if (templateReport != null &&
        templateReport.status == TemplateCompatibilityStatus.newerThanDefinition)
      'This record was written with a newer template than this install has.',
  ];
  if (warnings.isEmpty) return null;
  return WorldValidationBadge(
    icon: Icons.warning_amber_rounded,
    message: warnings.join('\n'),
    isError: false,
  );
}

IconData worldTypeIcon(String typeId) {
  if (WorldRecordTypes.mapTypeIds.contains(typeId)) return Icons.map_outlined;
  if (WorldRecordTypes.routeTypeIds.contains(typeId)) {
    return Icons.alt_route_outlined;
  }
  if (typeId == 'map-marker') return Icons.place_outlined;
  if (WorldRecordTypes.cosmicTypeIds.contains(typeId)) {
    return Icons.public_outlined;
  }
  return switch (typeId) {
    'continent' || 'region' || 'territory' => Icons.terrain_outlined,
    'country' || 'nation' || 'province' || 'state' => Icons.flag_outlined,
    'city' || 'town' || 'village' || 'settlement' =>
      Icons.location_city_outlined,
    'building' || 'structure' || 'room' || 'interior-location' =>
      Icons.home_work_outlined,
    'mountain' || 'forest' || 'desert' || 'island' || 'natural-feature' =>
      Icons.landscape_outlined,
    'river' || 'lake' || 'ocean' || 'sea' => Icons.water_outlined,
    _ => Icons.location_on_outlined,
  };
}

// ---------------------------------------------------------------------------
// Record detail pane
// ---------------------------------------------------------------------------

/// Field ids the World editor handles through dedicated controls rather than
/// the generic template field editor.
const _worldCoreFieldIds = <String>{
  'name',
  'primaryName',
  'summary',
  'description',
  'aliases',
};

bool _isCoreFieldId(String id) =>
    _worldCoreFieldIds.contains(id) || id.startsWith('_world.');

const _factionTypeIds = <String>{
  'faction',
  'organisation',
  'government',
  'house',
  'clan',
  'institution',
  'political-system',
};

class _WorldRecordPane extends StatefulWidget {
  const _WorldRecordPane({
    super.key,
    required this.service,
    required this.record,
    required this.records,
    required this.templates,
    required this.editorMode,
    required this.activeBranchId,
    required this.validation,
    required this.templateReport,
    required this.continuity,
    required this.saveState,
    required this.saveMessage,
    required this.onEditorModeChanged,
    required this.onMutate,
    required this.onConfirm,
    required this.onNotify,
    required this.onArchive,
    required this.onRestore,
    required this.onDuplicate,
    required this.onSafeDelete,
    required this.onOpenRecord,
    required this.onNavigate,
    required this.onOpenInGraph,
  });

  final WorldService service;
  final AuthorRecord record;
  final List<AuthorRecord> records;
  final List<RecordTypeDefinition> templates;
  final WorldEditorMode editorMode;
  final String? activeBranchId;
  final RecordValidationResult? validation;
  final TemplateCompatibilityReport? templateReport;
  final WorldContinuityIntelligence continuity;
  final WorldSaveState saveState;
  final String saveMessage;
  final ValueChanged<WorldEditorMode> onEditorModeChanged;
  final Future<bool> Function(Future<void> Function(), {required String success})
      onMutate;
  final Future<bool> Function({
    required String title,
    required String message,
    required String confirmLabel,
  }) onConfirm;
  final ValueChanged<String> onNotify;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDuplicate;
  final VoidCallback onSafeDelete;
  final ValueChanged<AuthorRecord> onOpenRecord;
  final ValueChanged<AuthorRecord> onNavigate;
  final ValueChanged<AuthorRecord> onOpenInGraph;

  @override
  State<_WorldRecordPane> createState() => _WorldRecordPaneState();
}

class _WorldRecordPaneState extends State<_WorldRecordPane> {
  static const _titleKey = '__title';
  static const _summaryKey = '__summary';
  static const _descriptionKey = '__description';
  static const _aliasesKey = '__aliases';
  static const _tagsKey = '__tags';

  final Map<String, TextEditingController> controllers = {};
  final Map<String, Object?> pendingValues = {};

  _WorldTab tab = _WorldTab.overview;
  late String canonState;
  bool dirty = false;
  List<RecordValidationIssue> saveIssues = const [];
  String? saveError;

  RecordTypeDefinition? template;
  Future<List<_WorldConnectionEntry>>? links;
  Future<UniversalRecordInspection?>? inspection;
  Future<List<RecordVersion>>? history;
  Future<WorldContinuityReport>? continuityReport;
  Future<_WorldHierarchyView>? hierarchyView;
  Future<List<AuthorRecord>>? maps;
  Future<List<WorldMapMarkerView>>? markers;
  Future<List<WorldRouteView>>? routes;

  bool get onBranch => widget.activeBranchId != null;
  bool get isMap => WorldRecordTypes.mapTypeIds.contains(widget.record.typeId);
  bool get isRoute =>
      WorldRecordTypes.routeTypeIds.contains(widget.record.typeId);
  bool get isSpatial =>
      WorldRecordTypes.spatialTypeIds.contains(widget.record.typeId);

  @override
  void initState() {
    super.initState();
    _resetBuffers();
    _reloadPanels();
  }

  @override
  void didUpdateWidget(_WorldRecordPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.record.id != widget.record.id ||
        oldWidget.record.revision != widget.record.revision ||
        oldWidget.record.updatedAt != widget.record.updatedAt ||
        oldWidget.activeBranchId != widget.activeBranchId;
    if (changed) {
      _resetBuffers();
      _reloadPanels();
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _resetBuffers() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    controllers.clear();
    pendingValues.clear();
    final record = widget.record;
    canonState = worldCanonState(record);
    dirty = false;
    saveIssues = const [];
    saveError = null;
    template = _resolveTemplate();
    controllers[_titleKey] = _watched(record.title);
    controllers[_summaryKey] = _watched(_display(record.fields['summary']));
    controllers[_descriptionKey] =
        _watched(_display(record.fields['description']));
    controllers[_aliasesKey] = _watched(_display(record.fields['aliases']));
    controllers[_tagsKey] = _watched(record.tags.join(', '));
    for (final field in _editableFields()) {
      final value = record.fields[field.id] ?? field.defaultValue;
      if (field.type == RecordFieldType.boolean) {
        pendingValues[field.id] = value is bool ? value : false;
      } else if (field.type == RecordFieldType.singleChoice) {
        pendingValues[field.id] =
            value is String && field.options.contains(value) ? value : null;
      } else {
        controllers[field.id] = _watched(_display(value));
      }
    }
    for (final key in _unknownFieldKeys()) {
      controllers[key] = _watched(_display(record.fields[key]));
    }
  }

  TextEditingController _watched(String text) {
    final controller = TextEditingController(text: text);
    controller.addListener(() {
      if (!dirty && mounted) setState(() => dirty = true);
    });
    return controller;
  }

  RecordTypeDefinition? _resolveTemplate() {
    final wanted = widget.record.templateId ?? widget.record.typeId;
    for (final definition in widget.templates) {
      if (definition.id == wanted) return definition;
    }
    return null;
  }

  List<RecordFieldDefinition> _editableFields() {
    final definition = template;
    if (definition == null) return const [];
    return definition.fields
        .where((field) => !field.hidden)
        .where((field) => !_isCoreFieldId(field.id))
        .toList()
      ..sort((left, right) => left.order.compareTo(right.order));
  }

  /// Field ids present on the record that no template declares.
  List<String> _unknownFieldKeys() {
    final known = <String>{
      ...?template?.fields.map((field) => field.id),
      ..._worldCoreFieldIds,
    };
    return widget.record.fields.keys
        .where((key) => !known.contains(key))
        .where((key) => !key.startsWith('_world.'))
        .where((key) => widget.record.fields[key] is! Map)
        .toList()
      ..sort();
  }

  void _reloadPanels() {
    final service = widget.service;
    final id = widget.record.id;
    final branchId = widget.activeBranchId;
    links = _loadConnections();
    inspection = service.inspectWorldRecord(id, branchId: branchId);
    history = service.getWorldHistory(id, branchId: branchId);
    continuityReport = _analyzeContinuity();
    hierarchyView = _loadHierarchy();
    maps = service.mapsFor(id, branchId: branchId);
    routes = service.routesFor(id, branchId: branchId);
    markers = _loadMarkers();
  }

  /// Reads this record's connections and resolves the record at the far end of
  /// each one against the whole project, so a connection to another Studio is
  /// grouped and labelled correctly.
  Future<List<_WorldConnectionEntry>> _loadConnections() async {
    final service = widget.service;
    final branchId = widget.activeBranchId;
    final values =
        await service.connectionsFor(widget.record.id, branchId: branchId);
    if (values.isEmpty) return const [];
    final byId = {
      for (final record in await service.connectableRecords(branchId: branchId))
        record.id: record,
    };
    return [
      for (final link in values)
        _WorldConnectionEntry(
          link: link,
          other: byId[link.sourceId == widget.record.id
              ? link.targetId
              : link.sourceId],
        ),
    ];
  }

  Future<_WorldHierarchyView> _loadHierarchy() async {
    final model =
        await widget.service.hierarchy(branchId: widget.activeBranchId);
    return _WorldHierarchyView(
      parent: model.parentOf(widget.record.id),
      children: model.childrenOf(widget.record.id),
      ancestors: model.ancestorsOf(widget.record.id).reversed.toList(),
    );
  }

  Future<List<WorldMapMarkerView>> _loadMarkers() async {
    final mapId = await _resolveContextMapId();
    if (mapId == null) return const [];
    return widget.service.markersForMap(mapId, branchId: widget.activeBranchId);
  }

  Future<String?> _resolveContextMapId() async {
    if (isMap) return widget.record.id;
    final attached = await widget.service
        .mapsFor(widget.record.id, branchId: widget.activeBranchId);
    return attached.firstOrNull?.id;
  }

  Future<WorldContinuityReport> _analyzeContinuity() async {
    final service = widget.service;
    final connections =
        await service.connectionsFor(widget.record.id, branchId: widget.activeBranchId);
    final connectable =
        await service.connectableRecords(branchId: widget.activeBranchId);
    final locationFields =
        await service.locationReferenceFieldIds(widget.record);
    return widget.continuity.analyze(
      record: widget.record,
      records: widget.records,
      links: connections,
      knownNames: WorldContinuityIntelligence.knownNames(connectable),
      hierarchy: await service.hierarchy(branchId: widget.activeBranchId),
      locationFieldIds: locationFields,
    );
  }

  // --- Saving -----------------------------------------------------------

  Future<void> _save() async {
    final title = controllers[_titleKey]!.text.trim();
    if (title.isEmpty) {
      setState(() {
        saveError = 'A name is required.';
        saveIssues = const [
          RecordValidationIssue(
            code: 'missing-title',
            message: 'World record title is required.',
            fieldId: 'title',
          ),
        ];
      });
      return;
    }
    final fields = <String, Object?>{
      'summary': controllers[_summaryKey]!.text,
      'description': controllers[_descriptionKey]!.text,
      'aliases': _splitList(controllers[_aliasesKey]!.text),
      for (final field in _editableFields()) field.id: _collectValue(field),
      for (final key in _unknownFieldKeys())
        key: _coerceLike(widget.record.fields[key], controllers[key]!.text),
    };
    setState(() {
      saveError = null;
      saveIssues = const [];
    });
    final saved = await widget.onMutate(
      () => widget.service.saveWorldRecord(
        widget.record.id,
        title: title,
        fields: fields,
        tags: _splitList(controllers[_tagsKey]!.text),
        // Canon state is edited by its own control and is read-only on a
        // branch, so an overlay save never carries one.
        canonState: onBranch ? null : canonState,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Saved $title',
    );
    if (!mounted) return;
    if (saved) {
      setState(() => dirty = false);
    } else {
      final result = await widget.service.validateWorldRecord(widget.record);
      if (!mounted) return;
      setState(() => saveIssues = result.issues);
    }
  }

  void _discard() => setState(_resetBuffers);

  Object? _collectValue(RecordFieldDefinition field) {
    switch (field.type) {
      case RecordFieldType.boolean:
        return pendingValues[field.id] as bool? ?? false;
      case RecordFieldType.singleChoice:
        return pendingValues[field.id];
      case RecordFieldType.number:
      case RecordFieldType.rating:
        final text = controllers[field.id]!.text.trim();
        if (text.isEmpty) return null;
        return num.tryParse(text) ?? text;
      case RecordFieldType.multipleChoice:
      case RecordFieldType.tags:
      case RecordFieldType.list:
      case RecordFieldType.checklist:
        return _splitList(controllers[field.id]!.text);
      case RecordFieldType.table:
        // Tables are preserved untouched; they are edited elsewhere.
        return widget.record.fields[field.id];
      default:
        final text = controllers[field.id]!.text;
        return text.trim().isEmpty ? '' : text;
    }
  }

  // --- Actions ----------------------------------------------------------

  Future<void> _setCanonState(String value) async {
    if (onBranch) {
      widget.onNotify(
        'Canon state is read-only on a branch. Override the record instead.',
      );
      return;
    }
    setState(() => canonState = value);
    await widget.onMutate(
      () => widget.service.setCanonState(
        widget.record.id,
        value,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Canon state set to $value',
    );
  }

  Future<void> _changeTemplate() async {
    if (onBranch) {
      widget.onNotify(
        'Changing a template changes Canon. Leave the branch first.',
      );
      return;
    }
    final registry = await widget.service.records.registry();
    final compatible = [
      for (final definition in widget.templates)
        if (registry.isTemplateCompatible(definition.id, widget.record.typeId))
          definition,
    ];
    if (!mounted || compatible.isEmpty) return;
    final templateId = await showDialog<String>(
      context: context,
      builder: (context) => _WorldChoiceDialog(
        title: 'Change template',
        label: 'Template',
        dialogKey: const Key('world-template-dialog'),
        fieldKey: const Key('world-template-field'),
        confirmKey: const Key('world-template-confirm'),
        confirmLabel: 'Apply template',
        initialValue: widget.record.templateId ?? widget.record.typeId,
        options: [
          for (final definition in compatible) (definition.id, definition.name),
        ],
      ),
    );
    if (templateId == null || templateId == widget.record.templateId) return;
    await widget.onMutate(
      () => widget.service
          .changeTemplate(widget.record.id, templateId: templateId),
      success: 'Template changed to $templateId',
    );
  }

  Future<void> _setParent() async {
    final candidates = widget.records
        .where((record) =>
            record.id != widget.record.id &&
            WorldRecordTypes.spatialTypeIds.contains(record.typeId))
        .toList();
    if (candidates.isEmpty) {
      widget.onNotify('There is no other place to nest this record under yet.');
      return;
    }
    final parentId = await showDialog<String>(
      context: context,
      builder: (context) => _WorldChoiceDialog(
        title: 'Move ${widget.record.title}',
        label: 'Parent place',
        dialogKey: const Key('world-parent-dialog'),
        fieldKey: const Key('world-parent-field'),
        confirmKey: const Key('world-parent-confirm'),
        confirmLabel: 'Move here',
        options: [
          for (final record in candidates)
            (record.id, '${record.title} · ${record.typeId}'),
        ],
      ),
    );
    if (parentId == null) return;
    await widget.onMutate(
      () => widget.service.setParent(
        childId: widget.record.id,
        parentId: parentId,
        branchId: widget.activeBranchId,
      ),
      success: 'Moved ${widget.record.title}',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _clearParent() async {
    final confirmed = await widget.onConfirm(
      title: 'Detach ${widget.record.title}?',
      message: 'The record becomes a root of the hierarchy. Nothing is '
          'deleted and its children stay attached to it.',
      confirmLabel: 'Detach',
    );
    if (!confirmed) return;
    await widget.onMutate(
      () => widget.service
          .clearParent(widget.record.id, branchId: widget.activeBranchId),
      success: 'Detached ${widget.record.title}',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _addConnection() async {
    final candidates = await widget.service
        .connectableRecords(branchId: widget.activeBranchId);
    if (!mounted) return;
    final targets =
        candidates.where((record) => record.id != widget.record.id).toList();
    if (targets.isEmpty) {
      widget.onNotify('There is no other record to connect to yet.');
      return;
    }
    final result = await showDialog<_WorldConnectionChoice>(
      context: context,
      builder: (context) => _WorldConnectionDialog(
        service: widget.service,
        sourceTypeId: widget.record.typeId,
        targets: targets,
      ),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service.connectRecord(
        sourceId: widget.record.id,
        targetId: result.targetId,
        typeId: result.typeId,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Connection added',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _editConnection(RecordLink link) async {
    if (onBranch) {
      widget.onNotify(
        'Existing connections belong to Canon. Leave the branch to change '
        'their type.',
      );
      return;
    }
    final registry = await widget.service.connectionRegistry();
    final available = await widget.service.connectionTypesBetween(
      sourceTypeId:
          await widget.service.repository.entityTypeId(link.sourceId) ?? '',
      targetTypeId:
          await widget.service.repository.entityTypeId(link.targetId) ?? '',
    );
    // Only types with the same direction can replace this link: the
    // ConnectionEngine refuses a directed type on an undirected link.
    final expected = registry.resolve(link.typeId).direction;
    final compatible =
        available.where((item) => item.direction == expected).toList();
    final definitions = compatible.isEmpty
        ? <ConnectionTypeDefinition>[registry.resolve(link.typeId)]
        : compatible;
    if (!mounted) return;
    final typeId = await showDialog<String>(
      context: context,
      builder: (context) => _WorldChoiceDialog(
        title: 'Change connection type',
        label: 'Connection type',
        dialogKey: const Key('world-connection-type-dialog'),
        fieldKey: const Key('world-connection-edit-type-field'),
        confirmKey: const Key('world-connection-type-confirm'),
        confirmLabel: 'Update',
        initialValue: link.typeId,
        options: [
          for (final definition in definitions)
            (definition.id, definition.displayName),
        ],
      ),
    );
    if (typeId == null || typeId == link.typeId) return;
    await widget.onMutate(
      () => widget.service.updateRecordConnection(link.id, typeId: typeId),
      success: 'Connection updated',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _removeConnection(RecordLink link) async {
    final confirmed = await widget.onConfirm(
      title: 'Remove this connection?',
      message: widget.activeBranchId == null
          ? 'The connection is removed. Both records are kept.'
          : 'The connection is hidden inside this branch. Canon keeps it.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await widget.onMutate(
      () => widget.service.disconnectRecord(
        link.id,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Connection removed',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _addCustomField() async {
    if (onBranch) {
      widget.onNotify('Custom fields are declared on the Canon record.');
      return;
    }
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _WorldCustomFieldDialog(),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service
          .setCustomField(widget.record.id, result.$1, result.$2, ''),
      success: 'Custom field added',
    );
  }

  Future<void> _restoreVersion(RecordVersion version) async {
    final confirmed = await widget.onConfirm(
      title: 'Restore this version?',
      message: 'The record is rewritten to the state saved on '
          '${_formatDate(version.createdAt)}. The current state stays in '
          'history, so this can be undone.',
      confirmLabel: 'Restore version',
    );
    if (!confirmed) return;
    await widget.onMutate(
      () => widget.service.records.restoreVersion(version.id),
      success: 'Version restored',
    );
  }

  // --- Maps, markers and routes -----------------------------------------

  Future<void> _saveMapMetadata(WorldMapMetadata metadata) => widget.onMutate(
        () => widget.service.updateMapMetadata(
          widget.record.id,
          metadata,
          activeBranchId: widget.activeBranchId,
        ),
        success: 'Map metadata saved',
      );

  Future<void> _addMap() async {
    if (onBranch) {
      widget.onNotify(
        'Creating a map writes a Canon record. Leave the branch first.',
      );
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _WorldNameDialog(
        title: 'Add a map',
        label: 'Map name',
        confirmLabel: 'Create map',
        fieldKey: Key('world-map-name-field'),
        confirmKey: Key('world-map-name-confirm'),
      ),
    );
    if (name == null || name.isEmpty) return;
    await widget.onMutate(
      () => widget.service.createMap(
        id: _newId('map', name),
        title: name,
        mappedRecordId: widget.record.id,
      ),
      success: 'Created $name',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _addMarker() async {
    final mapId = await _resolveContextMapId();
    if (!mounted) return;
    if (mapId == null) {
      widget.onNotify('Add a map before placing markers on it.');
      return;
    }
    if (onBranch) {
      widget.onNotify('Markers are Canon records. Leave the branch first.');
      return;
    }
    final result = await showDialog<_WorldMarkerDraft>(
      context: context,
      builder: (context) => _WorldMarkerDialog(
        targets: widget.records
            .where((record) => record.typeId != 'map-marker')
            .toList(),
        initialTargetId: isMap ? null : widget.record.id,
      ),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service.createMapMarker(
        markerId: _newId('marker', result.label),
        mapId: mapId,
        recordId: result.targetId,
        x: result.x,
        y: result.y,
        label: result.label,
        icon: result.icon,
        category: result.category,
        notes: result.notes,
      ),
      success: 'Marker added',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _editMarker(WorldMapMarkerView marker) async {
    if (onBranch) {
      widget.onNotify('Markers are Canon records. Leave the branch first.');
      return;
    }
    final result = await showDialog<_WorldMarkerDraft>(
      context: context,
      builder: (context) => _WorldMarkerDialog(
        targets: widget.records
            .where((record) => record.typeId != 'map-marker')
            .toList(),
        initialTargetId: marker.targetId,
        existing: marker,
      ),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service.updateMapMarker(
        marker.id,
        x: result.x,
        y: result.y,
        label: result.label,
        icon: result.icon,
        category: result.category,
        notes: result.notes,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Marker updated',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _archiveMarker(WorldMapMarkerView marker) async {
    final confirmed = await widget.onConfirm(
      title: 'Archive ${marker.displayLabel}?',
      message: 'The marker is archived, not deleted. Its links to the map and '
          'the record it represents are preserved.',
      confirmLabel: 'Archive marker',
    );
    if (!confirmed) return;
    await widget.onMutate(
      () => widget.service.archiveWorldRecord(marker.id),
      success: 'Marker archived',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _addRoute() async {
    if (onBranch) {
      widget.onNotify('Routes are Canon records. Leave the branch first.');
      return;
    }
    final places = widget.records
        .where(
            (record) => WorldRecordTypes.spatialTypeIds.contains(record.typeId))
        .toList();
    if (places.length < 2) {
      widget.onNotify('Two places are needed before a route can be drawn.');
      return;
    }
    final result = await showDialog<_WorldRouteDraft>(
      context: context,
      builder: (context) => _WorldRouteDialog(
        places: places,
        initialStartId: isSpatial ? widget.record.id : null,
      ),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service.createRoute(
        id: _newId('route', result.title),
        title: result.title,
        startId: result.startId,
        endId: result.endId,
        metadata: {
          'routeType': result.routeType,
          'distance': result.distance,
          'travelTime': result.travelTime,
          'difficulty': result.difficulty,
        },
      ),
      success: 'Route created',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _editRoute(WorldRouteView route) async {
    if (onBranch) {
      widget.onNotify('Routes are Canon records. Leave the branch first.');
      return;
    }
    final result = await showDialog<_WorldRouteDraft>(
      context: context,
      builder: (context) => _WorldRouteDialog(
        places: widget.records
            .where((record) =>
                WorldRecordTypes.spatialTypeIds.contains(record.typeId))
            .toList(),
        existing: route,
      ),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service.updateRoute(
        route.id,
        title: result.title,
        startId: result.startId,
        endId: result.endId,
        routeType: result.routeType,
        distance: result.distance,
        travelTime: result.travelTime,
        difficulty: result.difficulty,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Route updated',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _resolveContinuity(
    ContinuityIntegrityIssue issue,
    WorldContinuityFinding finding,
  ) async {
    final actions = ContinuityActionService(
      projectId: widget.service.projectId,
      repository: widget.service.repository,
      activeBranchId: widget.activeBranchId,
    );
    ContinuityActionResult result;
    if (finding.actionKind == ContinuityActionKind.create) {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => _WorldNameDialog(
          title: 'Create the missing record',
          label: 'Name',
          confirmLabel: 'Create record',
          initialValue: finding.missingName,
          message: issue.recommendation,
          fieldKey: const Key('world-continuity-name-field'),
          confirmKey: const Key('world-continuity-name-confirm'),
        ),
      );
      if (name == null || name.isEmpty) return;
      result = await actions.createForRecommendation(
        issue,
        name: name,
        confirmed: true,
        recheck: () => _continuityWarningRemains(finding),
      );
    } else if (finding.actionKind == ContinuityActionKind.link) {
      final confirmed = await widget.onConfirm(
        title: 'Link these records?',
        message: issue.recommendation,
        confirmLabel: 'Create link',
      );
      if (!confirmed) return;
      final definition = await widget.service
          .connectionRegistry()
          .then((registry) => registry.resolve(finding.connectionTypeId));
      result = await actions.linkForRecommendation(
        issue,
        sourceId: finding.recordId,
        targetId: finding.targetId!,
        typeId: finding.connectionTypeId,
        direction: definition.direction == ConnectionDirection.directed
            ? RecordLinkDirection.directed
            : RecordLinkDirection.undirected,
        confirmed: true,
        recheck: () => _continuityWarningRemains(finding),
      );
    } else {
      setState(() => tab = isRoute ? _WorldTab.routes : _WorldTab.fields);
      widget.onNotify(
        'Review the highlighted values, then save to resolve this warning.',
      );
      return;
    }

    if (!mounted) return;
    widget.onNotify(result.message);
    if (result.mutationApplied) {
      await widget.onMutate(() async {}, success: result.message);
      if (mounted) setState(_reloadPanels);
    }
  }

  Future<bool> _continuityWarningRemains(WorldContinuityFinding finding) async {
    final service = widget.service;
    final record = await service.getWorldRecord(widget.record.id);
    if (record == null) return false;
    final connections =
        await service.connectionsFor(record.id, branchId: widget.activeBranchId);
    final connectable =
        await service.connectableRecords(branchId: widget.activeBranchId);
    final report = widget.continuity.analyze(
      record: record,
      records: await service.worldRecords(branchId: widget.activeBranchId),
      links: connections,
      knownNames: WorldContinuityIntelligence.knownNames(connectable),
      hierarchy: await service.hierarchy(branchId: widget.activeBranchId),
      locationFieldIds: await service.locationReferenceFieldIds(record),
    );
    return report.findings.any((item) =>
        item.warning.type == finding.warning.type &&
        item.missingName == finding.missingName &&
        item.targetId == finding.targetId);
  }

  // --- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final theme = Theme.of(context);
    final archived = record.status == AuthorRecordStatus.archived;
    return _WorldCard(
      key: const Key('world-record-pane'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(worldTypeIcon(record.typeId), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template?.name ?? record.typeId} · ${record.typeId}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: const Key('world-record-actions'),
                tooltip: 'Record actions',
                onSelected: (value) {
                  switch (value) {
                    case 'archive':
                      widget.onArchive();
                    case 'restore':
                      widget.onRestore();
                    case 'duplicate':
                      widget.onDuplicate();
                    case 'template':
                      _changeTemplate();
                    case 'safe-delete':
                      widget.onSafeDelete();
                  }
                },
                itemBuilder: (context) => [
                  if (archived)
                    const PopupMenuItem(
                      key: Key('world-action-restore'),
                      value: 'restore',
                      child: Text('Restore record'),
                    )
                  else
                    const PopupMenuItem(
                      key: Key('world-action-archive'),
                      value: 'archive',
                      child: Text('Archive record'),
                    ),
                  const PopupMenuItem(
                    key: Key('world-action-duplicate'),
                    value: 'duplicate',
                    child: Text('Duplicate'),
                  ),
                  const PopupMenuItem(
                    key: Key('world-action-template'),
                    value: 'template',
                    child: Text('Change template'),
                  ),
                  const PopupMenuItem(
                    key: Key('world-action-safe-delete'),
                    value: 'safe-delete',
                    child: Text('Safe delete analysis'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                key: const Key('world-canon-chip'),
                label: Text(canonState),
                avatar: const Icon(Icons.verified_outlined, size: 16),
              ),
              if (archived)
                const Chip(
                  key: Key('world-archived-chip'),
                  label: Text('Archived'),
                  avatar: Icon(Icons.archive_outlined, size: 16),
                ),
              for (final tag in record.tags) Chip(label: Text(tag)),
            ],
          ),
          const SizedBox(height: 12),
          _WorldSaveIndicator(
            key: const Key('world-detail-save-state'),
            state: dirty && widget.saveState != WorldSaveState.saving
                ? WorldSaveState.idle
                : widget.saveState,
            message: dirty && widget.saveState != WorldSaveState.saving
                ? 'Unsaved changes'
                : widget.saveMessage,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _WorldTab.values)
                ChoiceChip(
                  key: Key('world-tab-${value.name}'),
                  label: Text(_tabLabel(value)),
                  selected: tab == value,
                  onSelected: (_) => setState(() => tab = value),
                ),
            ],
          ),
          const Divider(height: 28),
          switch (tab) {
            _WorldTab.overview => _overviewTab(context),
            _WorldTab.fields => _fieldsTab(context),
            _WorldTab.hierarchy => _hierarchyTab(context),
            _WorldTab.connections => _connectionsTab(context),
            _WorldTab.maps => _mapsTab(context),
            _WorldTab.markers => _markersTab(context),
            _WorldTab.routes => _routesTab(context),
            _WorldTab.continuity => _continuityTab(context),
            _WorldTab.inspector => _inspectorTab(context),
            _WorldTab.history => _historyTab(context),
          },
        ],
      ),
    );
  }

  Widget _saveBar(BuildContext context) => Row(
        children: [
          if (saveError != null)
            Expanded(
              child: Text(
                saveError!,
                key: const Key('world-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else
            const Spacer(),
          TextButton(
            key: const Key('world-discard-button'),
            onPressed: dirty ? _discard : null,
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('world-save-record-button'),
            onPressed: dirty ? _save : null,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
        ],
      );

  Widget _overviewTab(BuildContext context) {
    final issues = [...?widget.validation?.issues, ...saveIssues];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (issues.isNotEmpty) ...[
          _WorldValidationPanel(
            key: const Key('world-validation-panel'),
            issues: issues,
            templateReport: widget.templateReport,
          ),
          const SizedBox(height: 16),
        ],
        _sectionTitle(context, 'Identity'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('world-title-input'),
          controller: controllers[_titleKey],
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('world-summary-input'),
          controller: controllers[_summaryKey],
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Summary',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('world-description-input'),
          controller: controllers[_descriptionKey],
          minLines: 4,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('world-aliases-input'),
          controller: controllers[_aliasesKey],
          decoration: const InputDecoration(
            labelText: 'Aliases',
            helperText: 'Comma separated. Aliases stay searchable.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('world-tags-input'),
          controller: controllers[_tagsKey],
          decoration: const InputDecoration(
            labelText: 'Tags',
            helperText: 'Comma separated.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(context, 'Canon'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('world-canon-state-field'),
          initialValue: canonState,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Canon state',
            border: const OutlineInputBorder(),
            helperText: onBranch
                ? 'Canon cannot be changed from a branch.'
                : 'Saved immediately and recorded in history.',
          ),
          items: [
            for (final state in worldCanonStateOrder)
              DropdownMenuItem(value: state, child: Text(state)),
          ],
          onChanged: onBranch
              ? null
              : (value) {
                  if (value != null) _setCanonState(value);
                },
        ),
        const SizedBox(height: 16),
        _saveBar(context),
      ],
    );
  }

  Widget _fieldsTab(BuildContext context) {
    final definition = template;
    final deep = widget.editorMode == WorldEditorMode.deep;
    final fields = _editableFields();
    final unknown = _unknownFieldKeys();
    final labels = WorldService.customFieldLabels(widget.record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<WorldEditorMode>(
                key: const Key('world-editor-mode-selector'),
                segments: const [
                  ButtonSegment(
                    value: WorldEditorMode.simple,
                    icon: Icon(Icons.short_text_rounded),
                    label: Text('Simple'),
                  ),
                  ButtonSegment(
                    value: WorldEditorMode.deep,
                    icon: Icon(Icons.tune_rounded),
                    label: Text('Deep'),
                  ),
                ],
                selected: {widget.editorMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    widget.onEditorModeChanged(selection.first),
              ),
            ),
            if (deep)
              IconButton(
                key: const Key('world-add-custom-field-button'),
                tooltip: 'Add a custom field',
                onPressed: _addCustomField,
                icon: const Icon(Icons.playlist_add_rounded),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          deep
              ? 'Every template field, custom field, and field written by '
                  'another Studio.'
              : 'The fields most places need. Switch to Deep for everything.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (definition == null)
          _WorldBanner(
            key: const Key('world-missing-template-banner'),
            icon: Icons.help_outline,
            message: 'The ${widget.record.templateId ?? widget.record.typeId} '
                'template is not installed. Stored values are shown below and '
                'are preserved on save.',
          )
        else
          for (final section in _sectionsFor(definition, fields, deep))
            _WorldFieldSection(
              key: Key('world-section-${section.id}'),
              title: section.title,
              children: [
                for (final field in section.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _fieldEditor(context, field),
                  ),
              ],
            ),
        if (deep && unknown.isNotEmpty)
          _WorldFieldSection(
            key: const Key('world-section-additional'),
            title: 'Additional fields',
            children: [
              for (final key in unknown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    key: Key('world-field-$key'),
                    controller: controllers[key],
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: labels[key] ?? key,
                      helperText: labels.containsKey(key)
                          ? 'Custom field'
                          : 'Stored on this record but not declared by the '
                              'template. It is preserved on save.',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        _saveBar(context),
      ],
    );
  }

  List<_WorldSection> _sectionsFor(
    RecordTypeDefinition definition,
    List<RecordFieldDefinition> fields,
    bool deep,
  ) {
    final byId = {for (final field in fields) field.id: field};
    final sections = <_WorldSection>[];
    final used = <String>{};
    for (final section in definition.sections.toList()
      ..sort((left, right) => left.order.compareTo(right.order))) {
      if (!deep && section.collapsedByDefault) continue;
      final sectionFields = <RecordFieldDefinition>[];
      for (final id in section.fieldIds) {
        final field = byId[id];
        if (field == null) continue;
        if (!deep && !_isSimpleField(field)) continue;
        sectionFields.add(field);
        used.add(id);
      }
      if (sectionFields.isEmpty) continue;
      sections.add(_WorldSection(section.id, section.title, sectionFields));
    }
    final loose = fields
        .where((field) => !used.contains(field.id))
        .where((field) => deep || _isSimpleField(field))
        .toList();
    if (loose.isNotEmpty) {
      sections.add(_WorldSection('other', 'Other details', loose));
    }
    return sections;
  }

  bool _isSimpleField(RecordFieldDefinition field) =>
      field.required ||
      const {
        RecordFieldType.shortText,
        RecordFieldType.singleChoice,
        RecordFieldType.boolean,
        RecordFieldType.number,
        RecordFieldType.rating,
        RecordFieldType.date,
      }.contains(field.type);

  Widget _fieldEditor(BuildContext context, RecordFieldDefinition field) {
    final label = field.required ? '${field.label} *' : field.label;
    switch (field.type) {
      case RecordFieldType.boolean:
        return SwitchListTile(
          key: Key('world-field-${field.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: field.description.isEmpty ? null : Text(field.description),
          value: pendingValues[field.id] as bool? ?? false,
          onChanged: (value) => setState(() {
            pendingValues[field.id] = value;
            dirty = true;
          }),
        );
      case RecordFieldType.singleChoice:
        return DropdownButtonFormField<String>(
          key: Key('world-field-${field.id}'),
          initialValue: pendingValues[field.id] as String?,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description.isEmpty ? null : field.description,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final option in field.options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) => setState(() {
            pendingValues[field.id] = value;
            dirty = true;
          }),
        );
      case RecordFieldType.number:
      case RecordFieldType.rating:
        return TextField(
          key: Key('world-field-${field.id}'),
          controller: controllers[field.id],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description.isEmpty ? null : field.description,
            border: const OutlineInputBorder(),
          ),
        );
      case RecordFieldType.multipleChoice:
      case RecordFieldType.tags:
      case RecordFieldType.list:
      case RecordFieldType.checklist:
        return TextField(
          key: Key('world-field-${field.id}'),
          controller: controllers[field.id],
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description.isEmpty
                ? 'Comma separated'
                : '${field.description} · Comma separated',
            border: const OutlineInputBorder(),
          ),
        );
      case RecordFieldType.table:
        return InputDecorator(
          key: Key('world-field-${field.id}'),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            helperText: 'Table values are preserved and edited elsewhere.',
          ),
          child: Text(
            _display(widget.record.fields[field.id]),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      default:
        final multiline = field.type == RecordFieldType.longText ||
            field.type == RecordFieldType.richText;
        return TextField(
          key: Key('world-field-${field.id}'),
          controller: controllers[field.id],
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 10 : 1,
          decoration: InputDecoration(
            labelText: label,
            helperText: field.description.isEmpty ? null : field.description,
            border: const OutlineInputBorder(),
          ),
        );
    }
  }

  Widget _hierarchyTab(BuildContext context) =>
      FutureBuilder<_WorldHierarchyView>(
        future: hierarchyView,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _WorldInlineLoader();
          }
          final view = snapshot.data ?? const _WorldHierarchyView();
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(context, 'Position in the world'),
              const SizedBox(height: 8),
              Wrap(
                key: const Key('world-breadcrumb'),
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final ancestor in view.ancestors) ...[
                    ActionChip(
                      key: Key('world-breadcrumb-${ancestor.id}'),
                      avatar: Icon(worldTypeIcon(ancestor.typeId), size: 14),
                      label: Text(ancestor.title),
                      onPressed: () => widget.onOpenRecord(ancestor),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                  Chip(label: Text(widget.record.title)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      view.parent == null
                          ? 'This record is a root of the hierarchy.'
                          : 'Parent: ${view.parent!.title}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  if (!isSpatial)
                    Text('Only places can be nested.',
                        style: theme.textTheme.bodySmall)
                  else ...[
                    TextButton.icon(
                      key: const Key('world-set-parent-button'),
                      onPressed: _setParent,
                      icon: const Icon(Icons.drive_file_move_outline, size: 18),
                      label: Text(view.parent == null ? 'Set parent' : 'Move'),
                    ),
                    if (view.parent != null)
                      TextButton(
                        key: const Key('world-clear-parent-button'),
                        onPressed: _clearParent,
                        child: const Text('Detach'),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle(context, 'Contains (${view.children.length})'),
              const SizedBox(height: 8),
              if (view.children.isEmpty)
                const _WorldMessage(
                  key: Key('world-hierarchy-empty-state'),
                  icon: Icons.account_tree_outlined,
                  title: 'Nothing nested here yet',
                  message:
                      'Create a place and choose this record as its parent, or '
                      'move an existing place into it.',
                )
              else
                for (final child in view.children)
                  Card(
                    key: Key('world-child-${child.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(worldTypeIcon(child.typeId)),
                      title: Text(child.title),
                      subtitle:
                          Text('${child.typeId} · ${worldCanonState(child)}'),
                      trailing: IconButton(
                        key: Key('world-open-child-${child.id}'),
                        tooltip: 'Open',
                        onPressed: () => widget.onOpenRecord(child),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
                    ),
                  ),
            ],
          );
        },
      );

  Widget _connectionsTab(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle(context, 'Connections')),
              FilledButton.tonalIcon(
                key: const Key('world-add-connection-button'),
                onPressed: _addConnection,
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Connect'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_WorldConnectionEntry>>(
            future: links,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _WorldInlineLoader();
              }
              final values = snapshot.data ?? const <_WorldConnectionEntry>[];
              if (values.isEmpty) {
                return const _WorldMessage(
                  key: Key('world-connections-empty-state'),
                  icon: Icons.hub_outlined,
                  title: 'No connections yet',
                  message:
                      'Connect this record to characters, factions, Codex '
                      'entries, timeline events, plot threads or manuscript '
                      'records to build the story graph.',
                );
              }
              final grouped = <String, List<_WorldConnectionEntry>>{};
              for (final entry in values) {
                grouped
                    .putIfAbsent(
                      _connectionGroup(entry.other?.typeId ?? ''),
                      () => <_WorldConnectionEntry>[],
                    )
                    .add(entry);
              }
              final order = grouped.keys.toList()..sort();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in order) ...[
                    Padding(
                      key: Key('world-connection-group-${_slug(group)}'),
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Text(
                        '$group (${grouped[group]!.length})',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final entry in grouped[group]!)
                      _WorldConnectionTile(
                        key: Key('world-connection-${entry.link.id}'),
                        entry: entry,
                        onOpen: widget.onOpenRecord,
                        onEdit: () => _editConnection(entry.link),
                        onRemove: () => _removeConnection(entry.link),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      );

  Widget _mapsTab(BuildContext context) {
    if (isMap) {
      return _WorldMapMetadataPanel(
        key: ValueKey('world-map-metadata-${widget.record.id}'),
        record: widget.record,
        readOnly: onBranch,
        onSave: _saveMapMetadata,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'Maps of this place')),
            FilledButton.tonalIcon(
              key: const Key('world-add-map-button'),
              onPressed: _addMap,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add map'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<AuthorRecord>>(
          future: maps,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _WorldInlineLoader();
            }
            final values = snapshot.data ?? const <AuthorRecord>[];
            if (values.isEmpty) {
              return const _WorldMessage(
                key: Key('world-maps-empty-state'),
                icon: Icons.map_outlined,
                title: 'No maps yet',
                message:
                    'Add a map to place markers and plan routes across this '
                    'part of the world.',
              );
            }
            return Column(
              children: [
                for (final map in values)
                  Card(
                    key: Key('world-map-${map.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: Text(map.title),
                      subtitle: Text(_mapSubtitle(map)),
                      trailing: IconButton(
                        key: Key('world-open-map-${map.id}'),
                        tooltip: 'Open map',
                        onPressed: () => widget.onOpenRecord(map),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _mapSubtitle(AuthorRecord map) {
    final metadata = WorldMapMetadata.fromRecord(map);
    final parts = <String>[
      if (metadata.mapType.isNotEmpty) metadata.mapType,
      if (metadata.hasBounds) '${metadata.width} × ${metadata.height}',
      if (metadata.scale.isNotEmpty) metadata.scale,
    ];
    return parts.isEmpty ? map.typeId : parts.join(' · ');
  }

  Widget _markersTab(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle(context, 'Map markers')),
              FilledButton.tonalIcon(
                key: const Key('world-add-marker-button'),
                onPressed: _addMarker,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('Add marker'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<WorldMapMarkerView>>(
            future: markers,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _WorldInlineLoader();
              }
              final values = snapshot.data ?? const <WorldMapMarkerView>[];
              if (values.isEmpty) {
                return const _WorldMessage(
                  key: Key('world-markers-empty-state'),
                  icon: Icons.place_outlined,
                  title: 'No markers yet',
                  message:
                      'Markers pin a record to a coordinate on a map. Add a '
                      'map first, then place markers on it.',
                );
              }
              return Column(
                children: [
                  for (final marker in values)
                    Card(
                      key: Key('world-marker-${marker.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          marker.withinBounds
                              ? Icons.place_outlined
                              : Icons.wrong_location_outlined,
                        ),
                        title: Text(marker.displayLabel),
                        subtitle: Text(
                          '${marker.targetTitle} · (${marker.x}, ${marker.y})'
                          '${marker.category.isEmpty ? '' : ' · ${marker.category}'}'
                          '${marker.withinBounds ? '' : ' · outside the map bounds'}',
                          key: marker.withinBounds
                              ? null
                              : Key('world-marker-out-of-bounds-${marker.id}'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('world-edit-marker-${marker.id}'),
                              tooltip: 'Edit marker',
                              onPressed: () => _editMarker(marker),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              key: Key('world-remove-marker-${marker.id}'),
                              tooltip: 'Archive marker',
                              onPressed: () => _archiveMarker(marker),
                              icon: const Icon(Icons.archive_outlined),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );

  Widget _routesTab(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle(context, 'Travel routes')),
              FilledButton.tonalIcon(
                key: const Key('world-add-route-button'),
                onPressed: _addRoute,
                icon: const Icon(Icons.alt_route_rounded, size: 18),
                label: const Text('Add route'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<WorldRouteView>>(
            future: routes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _WorldInlineLoader();
              }
              final values = snapshot.data ?? const <WorldRouteView>[];
              if (values.isEmpty) {
                return const _WorldMessage(
                  key: Key('world-routes-empty-state'),
                  icon: Icons.alt_route_outlined,
                  title: 'No routes yet',
                  message:
                      'Routes record how travellers move between two places, '
                      'with distance, travel time and difficulty.',
                );
              }
              return Column(
                children: [
                  for (final route in values)
                    Card(
                      key: Key('world-route-${route.id}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          route.endpointsResolved
                              ? Icons.alt_route_outlined
                              : Icons.report_gmailerrorred_outlined,
                        ),
                        title: Text(route.record.title),
                        subtitle: Text(
                          '${route.startTitle} → ${route.endTitle}'
                          '${route.travelTime.isEmpty ? '' : ' · ${route.travelTime}'}'
                          '${route.distance.isEmpty ? '' : ' · ${route.distance}'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: Key('world-edit-route-${route.id}'),
                              tooltip: 'Edit route',
                              onPressed: () => _editRoute(route),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              key: Key('world-open-route-${route.id}'),
                              tooltip: 'Open route record',
                              onPressed: () =>
                                  widget.onOpenRecord(route.record),
                              icon: const Icon(Icons.open_in_new_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );

  Widget _continuityTab(BuildContext context) =>
      FutureBuilder<WorldContinuityReport>(
        future: continuityReport,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _WorldInlineLoader();
          }
          final report = snapshot.data ?? WorldContinuityReport.empty;
          if (report.isClean) {
            return const _WorldMessage(
              key: Key('world-continuity-clean-state'),
              icon: Icons.verified_outlined,
              title: 'No continuity recommendations',
              message:
                  'Every name this record mentions has a record, every mention '
                  'is connected, and its routes can be travelled.',
            );
          }
          return Column(
            key: const Key('world-continuity-panel'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _sectionTitle(context, 'Continuity Intelligence'),
                  ),
                  Chip(
                    label: Text('Integrity ${report.summary.score}'),
                    avatar: const Icon(Icons.insights_outlined, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var index = 0;
                  index < report.summary.issues.length;
                  index += 1)
                _WorldContinuityTile(
                  key: Key('world-continuity-issue-$index'),
                  issue: report.summary.issues[index],
                  actionLabel: switch (report.findings[index].actionKind) {
                    ContinuityActionKind.create => 'Create record',
                    ContinuityActionKind.link => 'Create link',
                    ContinuityActionKind.review => 'Review record',
                  },
                  actionKey: Key('world-continuity-resolve-$index'),
                  onResolve: () => _resolveContinuity(
                    report.summary.issues[index],
                    report.findings[index],
                  ),
                ),
            ],
          );
        },
      );

  Widget _inspectorTab(BuildContext context) =>
      FutureBuilder<UniversalRecordInspection?>(
        future: inspection,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _WorldInlineLoader();
          }
          final data = snapshot.data;
          if (data == null) {
            return const _WorldMessage(
              key: Key('world-inspector-empty-state'),
              icon: Icons.travel_explore_outlined,
              title: 'Inspection unavailable',
              message: 'This record is not visible in the current scope.',
            );
          }
          return Column(
            key: const Key('world-inspector-panel'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _sectionTitle(
                      context,
                      'Universal Record Inspector',
                    ),
                  ),
                  OpenInGraphButton(
                    recordId: data.recordId,
                    onOpen: () => widget.onOpenInGraph(widget.record),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _kv(context, 'Record id', data.recordId),
              _kv(context, 'Record type', data.recordType),
              _kv(context, 'Template',
                  '${data.template.id} v${data.template.recordVersion}'),
              _kv(context, 'Template state',
                  data.template.compatibility.status.name),
              _kv(context, 'Canon status', data.canonStatus.name),
              _kv(context, 'Canon state', canonState),
              _kv(context, 'Lifecycle', data.lifecycleStatus.name),
              _kv(context, 'Branch state', data.scope.branchState.name),
              _kv(context, 'Visible in scope',
                  data.scope.visible ? 'Yes' : 'No'),
              _kv(context, 'Validation', data.validation.state.name),
              _kv(
                context,
                'Connections',
                '${data.outgoingConnections.length} out · '
                    '${data.incomingConnections.length} in',
              ),
              _kv(context, 'References', '${data.references.length}'),
              _kv(context, 'Versions', '${data.history.versionCount}'),
              _kv(context, 'Audit events', '${data.history.auditEventCount}'),
              _kv(
                context,
                'Safe delete',
                data.safeDelete.hasDependencies
                    ? '${data.safeDelete.dependentEntityIds.length} dependent '
                        'record(s)'
                    : 'No dependencies',
              ),
              if (data.capabilities.limitations.isNotEmpty) ...[
                const SizedBox(height: 12),
                _sectionTitle(context, 'Known limitations'),
                const SizedBox(height: 6),
                for (final limitation in data.capabilities.limitations)
                  Text('• $limitation',
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          );
        },
      );

  Widget _historyTab(BuildContext context) =>
      FutureBuilder<List<RecordVersion>>(
        future: history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _WorldInlineLoader();
          }
          final versions = snapshot.data ?? const <RecordVersion>[];
          if (versions.isEmpty) {
            return const _WorldMessage(
              key: Key('world-history-empty-state'),
              icon: Icons.history_toggle_off_outlined,
              title: 'No history yet',
              message: 'Saved changes appear here as versions you can restore.',
            );
          }
          return Column(
            key: const Key('world-history-panel'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(context, 'Version history'),
              const SizedBox(height: 12),
              for (final version in versions)
                Card(
                  key: Key('world-history-${version.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(version.summary),
                    subtitle: Text(
                      '${version.changeType.name} · '
                      '${_formatDate(version.createdAt)}',
                    ),
                    trailing: widget.activeBranchId == null &&
                            version.branchId == null
                        ? IconButton(
                            key: Key('world-restore-version-${version.id}'),
                            tooltip: 'Restore this version',
                            onPressed: () => _restoreVersion(version),
                            icon: const Icon(Icons.restore_rounded),
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      );

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      );

  Widget _kv(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(value, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}

class _WorldSection {
  const _WorldSection(this.id, this.title, this.fields);

  final String id;
  final String title;
  final List<RecordFieldDefinition> fields;
}

class _WorldHierarchyView {
  const _WorldHierarchyView({
    this.parent,
    this.children = const [],
    this.ancestors = const [],
  });

  final AuthorRecord? parent;
  final List<AuthorRecord> children;
  final List<AuthorRecord> ancestors;
}

String _connectionGroup(String typeId) {
  if (typeId == 'character') return 'Characters';
  if (_factionTypeIds.contains(typeId)) return 'Factions';
  if (WorldRecordTypes.worldDomainTypeIds.contains(typeId)) return 'World';
  return switch (searchDestinationForType(typeId)) {
    SearchDestination.timelineStudio => 'Timeline',
    SearchDestination.plotStudio => 'Plot',
    SearchDestination.manuscriptStudio => 'Manuscript',
    SearchDestination.storyCodex => 'Story Codex',
    SearchDestination.characterStudio => 'Characters',
    SearchDestination.worldStudio => 'World',
    _ => 'Other records',
  };
}

/// A connection plus the record at its other end, resolved once for the whole
/// panel instead of once per row.
class _WorldConnectionEntry {
  const _WorldConnectionEntry({required this.link, required this.other});

  final RecordLink link;
  final AuthorRecord? other;
}

class _WorldConnectionTile extends StatelessWidget {
  const _WorldConnectionTile({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
  });

  final _WorldConnectionEntry entry;
  final ValueChanged<AuthorRecord> onOpen;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final link = entry.link;
    final record = entry.other;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(worldTypeIcon(record?.typeId ?? '')),
        title: Text(record?.title ?? link.targetId),
        subtitle: Text(
          '${link.label.isEmpty ? link.typeId : link.label}'
          '${record == null ? '' : ' · ${record.typeId}'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (record != null)
              IconButton(
                key: Key('world-open-connection-${link.id}'),
                tooltip: 'Open connected record',
                onPressed: () => onOpen(record),
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            IconButton(
              key: Key('world-edit-connection-${link.id}'),
              tooltip: 'Change connection type',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: Key('world-remove-connection-${link.id}'),
              tooltip: 'Remove connection',
              onPressed: onRemove,
              icon: const Icon(Icons.link_off_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map metadata panel
// ---------------------------------------------------------------------------

class _WorldMapMetadataPanel extends StatefulWidget {
  const _WorldMapMetadataPanel({
    super.key,
    required this.record,
    required this.readOnly,
    required this.onSave,
  });

  final AuthorRecord record;
  final bool readOnly;
  final Future<void> Function(WorldMapMetadata metadata) onSave;

  @override
  State<_WorldMapMetadataPanel> createState() => _WorldMapMetadataPanelState();
}

class _WorldMapMetadataPanelState extends State<_WorldMapMetadataPanel> {
  late WorldMapMetadata original;
  late final TextEditingController mapType;
  late final TextEditingController coordinateSystem;
  late final TextEditingController width;
  late final TextEditingController height;
  late final TextEditingController scale;
  late final TextEditingController projection;
  late final TextEditingController background;
  bool dirty = false;

  @override
  void initState() {
    super.initState();
    original = WorldMapMetadata.fromRecord(widget.record);
    mapType = _watched(original.mapType);
    coordinateSystem = _watched(original.coordinateSystem);
    width = _watched(original.width == null ? '' : '${original.width}');
    height = _watched(original.height == null ? '' : '${original.height}');
    scale = _watched(original.scale);
    projection = _watched(original.projection);
    background = _watched(original.backgroundReference);
  }

  TextEditingController _watched(String text) {
    final controller = TextEditingController(text: text);
    controller.addListener(() {
      if (!dirty && mounted) setState(() => dirty = true);
    });
    return controller;
  }

  @override
  void dispose() {
    mapType.dispose();
    coordinateSystem.dispose();
    width.dispose();
    height.dispose();
    scale.dispose();
    projection.dispose();
    background.dispose();
    super.dispose();
  }

  WorldMapMetadata get _current => WorldMapMetadata(
        mapType: mapType.text.trim(),
        coordinateSystem: coordinateSystem.text.trim(),
        width: num.tryParse(width.text.trim()),
        height: num.tryParse(height.text.trim()),
        scale: scale.text.trim(),
        projection: projection.text.trim(),
        backgroundReference: background.text.trim(),
      );

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('world-map-metadata-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Map metadata',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.readOnly
                ? 'Map metadata belongs to Canon and is read-only on a branch.'
                : 'Bounds are used to flag markers placed outside the map.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('world-map-type-field'),
            controller: mapType,
            readOnly: widget.readOnly,
            decoration: const InputDecoration(
              labelText: 'Map type',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('world-map-width-field'),
                  controller: width,
                  readOnly: widget.readOnly,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Width',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('world-map-height-field'),
                  controller: height,
                  readOnly: widget.readOnly,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('world-map-scale-field'),
            controller: scale,
            readOnly: widget.readOnly,
            decoration: const InputDecoration(
              labelText: 'Scale',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('world-map-coordinate-field'),
            controller: coordinateSystem,
            readOnly: widget.readOnly,
            decoration: const InputDecoration(
              labelText: 'Coordinate system',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('world-map-projection-field'),
            controller: projection,
            readOnly: widget.readOnly,
            decoration: const InputDecoration(
              labelText: 'Projection',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('world-map-background-field'),
            controller: background,
            readOnly: widget.readOnly,
            decoration: const InputDecoration(
              labelText: 'Background reference',
              helperText: 'Path or asset id of the map image.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: const Key('world-save-map-metadata-button'),
              onPressed: widget.readOnly || !dirty
                  ? null
                  : () async {
                      await widget.onSave(_current);
                      if (mounted) setState(() => dirty = false);
                    },
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save map metadata'),
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class _WorldCreateResult {
  const _WorldCreateResult({
    required this.id,
    required this.title,
    required this.typeId,
    required this.templateId,
    required this.canonState,
    required this.fields,
    this.parentId,
    this.mappedRecordId,
  });

  final String id;
  final String title;
  final String typeId;
  final String templateId;
  final String canonState;
  final Map<String, Object?> fields;
  final String? parentId;
  final String? mappedRecordId;
}

class _WorldCreateDialog extends StatefulWidget {
  const _WorldCreateDialog({
    required this.templates,
    required this.places,
    required this.onBranch,
    required this.branchId,
  });

  final List<RecordTypeDefinition> templates;
  final List<AuthorRecord> places;
  final bool onBranch;
  final String? branchId;

  @override
  State<_WorldCreateDialog> createState() => _WorldCreateDialogState();
}

class _WorldCreateDialogState extends State<_WorldCreateDialog> {
  final titleController = TextEditingController();
  final summaryController = TextEditingController();
  final fieldControllers = <String, TextEditingController>{};

  late String templateId;
  String? parentId;
  String? mappedRecordId;
  String canonState = 'Draft';
  WorldEditorMode mode = WorldEditorMode.simple;
  String? error;

  RecordTypeDefinition get template =>
      widget.templates.firstWhere((item) => item.id == templateId);

  bool get isMapTemplate => WorldRecordTypes.mapTypeIds.contains(templateId);

  bool get isSpatialTemplate =>
      WorldRecordTypes.spatialTypeIds.contains(templateId);

  @override
  void initState() {
    super.initState();
    templateId = widget.templates.first.id;
    if (widget.onBranch) canonState = 'Alternate';
    _syncControllers();
  }

  void _syncControllers() {
    for (final field in template.fields) {
      if (_isCoreFieldId(field.id)) continue;
      fieldControllers.putIfAbsent(
        field.id,
        () => TextEditingController(text: _display(field.defaultValue)),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => error = 'A name is required.');
      return;
    }
    final missing = template.fields
        .where((field) => field.required && !_isCoreFieldId(field.id))
        .where(
            (field) => (fieldControllers[field.id]?.text ?? '').trim().isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      setState(() {
        mode = WorldEditorMode.deep;
        error = '${missing.map((field) => field.label).join(', ')} '
            '${missing.length == 1 ? 'is' : 'are'} required.';
      });
      return;
    }
    if (isMapTemplate && (mappedRecordId == null || mappedRecordId!.isEmpty)) {
      setState(() => error = 'Choose which place this map depicts.');
      return;
    }
    Navigator.pop(
      context,
      _WorldCreateResult(
        id: _newId('world', title),
        title: title,
        typeId: templateId,
        templateId: templateId,
        canonState: canonState,
        parentId: parentId,
        mappedRecordId: mappedRecordId,
        fields: {
          if (summaryController.text.trim().isNotEmpty)
            'summary': summaryController.text.trim(),
          for (final field in template.fields)
            if (!_isCoreFieldId(field.id) &&
                (fieldControllers[field.id]?.text ?? '').trim().isNotEmpty)
              field.id: _coerceForField(field, fieldControllers[field.id]!.text),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deep = mode == WorldEditorMode.deep;
    return AlertDialog(
      key: const Key('world-create-dialog'),
      title: const Text('New world record'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<WorldEditorMode>(
                key: const Key('world-create-mode-selector'),
                segments: const [
                  ButtonSegment(
                    value: WorldEditorMode.simple,
                    label: Text('Simple'),
                  ),
                  ButtonSegment(
                    value: WorldEditorMode.deep,
                    label: Text('Deep'),
                  ),
                ],
                selected: {mode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) =>
                    setState(() => mode = selection.first),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('world-create-template-field'),
                initialValue: templateId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in widget.templates)
                    DropdownMenuItem(
                      key: Key('world-create-template-option-${item.id}'),
                      value: item.id,
                      child: Text(item.name),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    templateId = value;
                    if (!isMapTemplate) mappedRecordId = null;
                    if (!isSpatialTemplate) parentId = null;
                    _syncControllers();
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('world-create-title-field'),
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('world-create-summary-field'),
                controller: summaryController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isSpatialTemplate && widget.places.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('world-create-parent-field'),
                  initialValue: parentId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Nest inside (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final place in widget.places)
                      DropdownMenuItem(
                        key: Key('world-create-parent-option-${place.id}'),
                        value: place.id,
                        child: Text('${place.title} · ${place.typeId}'),
                      ),
                  ],
                  onChanged: (value) => setState(() => parentId = value),
                ),
              ],
              if (isMapTemplate) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('world-create-mapped-field'),
                  initialValue: mappedRecordId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Maps which place',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final place in widget.places)
                      DropdownMenuItem(
                        key: Key('world-create-mapped-option-${place.id}'),
                        value: place.id,
                        child: Text(place.title),
                      ),
                  ],
                  onChanged: (value) => setState(() => mappedRecordId = value),
                ),
              ],
              if (deep) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('world-create-canon-field'),
                  initialValue: canonState,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Canon state',
                    border: const OutlineInputBorder(),
                    helperText: widget.onBranch
                        ? 'Branch records can never be Canon.'
                        : null,
                  ),
                  items: [
                    for (final state in worldCanonStateOrder)
                      if (!widget.onBranch || state != 'Canon')
                        DropdownMenuItem(value: state, child: Text(state)),
                  ],
                  onChanged: (value) =>
                      setState(() => canonState = value ?? canonState),
                ),
                for (final section in template.sections.toList()
                  ..sort((left, right) => left.order.compareTo(right.order)))
                  ..._sectionFields(context, section),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  key: const Key('world-create-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('world-create-confirm'),
          onPressed: _submit,
          child: const Text('Create record'),
        ),
      ],
    );
  }

  List<Widget> _sectionFields(
    BuildContext context,
    RecordTemplateSection section,
  ) {
    final fields = template.fields
        .where((field) => section.fieldIds.contains(field.id))
        .where((field) => !_isCoreFieldId(field.id) && !field.hidden)
        .toList();
    if (fields.isEmpty) return const [];
    return [
      const SizedBox(height: 18),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          section.title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      const SizedBox(height: 8),
      for (final field in fields) ...[
        TextField(
          key: Key('world-create-field-${field.id}'),
          controller: fieldControllers[field.id],
          minLines: field.type == RecordFieldType.longText ||
                  field.type == RecordFieldType.richText
              ? 2
              : 1,
          maxLines: field.type == RecordFieldType.longText ||
                  field.type == RecordFieldType.richText
              ? 5
              : 1,
          decoration: InputDecoration(
            labelText: field.required ? '${field.label} *' : field.label,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _WorldConnectionChoice {
  const _WorldConnectionChoice(this.targetId, this.typeId);

  final String targetId;
  final String typeId;
}

class _WorldConnectionDialog extends StatefulWidget {
  const _WorldConnectionDialog({
    required this.service,
    required this.sourceTypeId,
    required this.targets,
  });

  final WorldService service;
  final String sourceTypeId;
  final List<AuthorRecord> targets;

  @override
  State<_WorldConnectionDialog> createState() => _WorldConnectionDialogState();
}

class _WorldConnectionDialogState extends State<_WorldConnectionDialog> {
  late String targetId = widget.targets.first.id;
  String? typeId;
  List<ConnectionTypeDefinition> definitions = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    final target = widget.targets.firstWhere((item) => item.id == targetId);
    final available = await widget.service.connectionTypesBetween(
      sourceTypeId: widget.sourceTypeId,
      targetTypeId: target.typeId,
    );
    if (!mounted) return;
    setState(() {
      definitions = available;
      typeId = available.any((item) => item.id == typeId)
          ? typeId
          : available
                  .where((item) => item.id == 'relatedTo')
                  .firstOrNull
                  ?.id ??
              available.firstOrNull?.id;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('world-connection-dialog'),
        title: const Text('Connect this record'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('world-connection-target-field'),
                initialValue: targetId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Record',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final record in widget.targets)
                    DropdownMenuItem(
                      key: Key('world-connection-target-${record.id}'),
                      value: record.id,
                      child: Text(
                        '${record.title} · ${record.typeId}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    targetId = value;
                    loading = true;
                  });
                  _loadTypes();
                },
              ),
              const SizedBox(height: 12),
              if (loading)
                const _WorldInlineLoader()
              else if (definitions.isEmpty)
                const Text(
                  'No connection type allows these two record types. Pick a '
                  'different record.',
                )
              else
                DropdownButtonFormField<String>(
                  key: const Key('world-connection-type-field'),
                  initialValue: typeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Connection type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final definition in definitions)
                      DropdownMenuItem(
                        key: Key('world-connection-type-${definition.id}'),
                        value: definition.id,
                        child: Text(definition.displayName),
                      ),
                  ],
                  onChanged: (value) => setState(() => typeId = value),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('world-connection-confirm'),
            onPressed: typeId == null
                ? null
                : () => Navigator.pop(
                      context,
                      _WorldConnectionChoice(targetId, typeId!),
                    ),
            child: const Text('Connect'),
          ),
        ],
      );
}

class _WorldMarkerDraft {
  const _WorldMarkerDraft({
    required this.targetId,
    required this.x,
    required this.y,
    required this.label,
    required this.icon,
    required this.category,
    required this.notes,
  });

  final String targetId;
  final num x;
  final num y;
  final String label;
  final String icon;
  final String category;
  final String notes;
}

class _WorldMarkerDialog extends StatefulWidget {
  const _WorldMarkerDialog({
    required this.targets,
    this.initialTargetId,
    this.existing,
  });

  final List<AuthorRecord> targets;
  final String? initialTargetId;
  final WorldMapMarkerView? existing;

  @override
  State<_WorldMarkerDialog> createState() => _WorldMarkerDialogState();
}

class _WorldMarkerDialogState extends State<_WorldMarkerDialog> {
  late final TextEditingController label;
  late final TextEditingController x;
  late final TextEditingController y;
  late final TextEditingController icon;
  late final TextEditingController category;
  late final TextEditingController notes;
  String? targetId;
  String? error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    label = TextEditingController(text: existing?.label ?? '');
    x = TextEditingController(text: existing == null ? '0' : '${existing.x}');
    y = TextEditingController(text: existing == null ? '0' : '${existing.y}');
    icon = TextEditingController(text: existing?.icon ?? '');
    category = TextEditingController(text: existing?.category ?? '');
    notes = TextEditingController(text: existing?.notes ?? '');
    final wanted = existing?.targetId ?? widget.initialTargetId;
    targetId = widget.targets.any((record) => record.id == wanted)
        ? wanted
        : widget.targets.firstOrNull?.id;
  }

  @override
  void dispose() {
    label.dispose();
    x.dispose();
    y.dispose();
    icon.dispose();
    category.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('world-marker-dialog'),
        title:
            Text(widget.existing == null ? 'Place a marker' : 'Edit marker'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('world-marker-target-field'),
                  initialValue: targetId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Marks which record',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final record in widget.targets)
                      DropdownMenuItem(
                        key: Key('world-marker-target-${record.id}'),
                        value: record.id,
                        child: Text(
                          '${record.title} · ${record.typeId}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: widget.existing == null
                      ? (value) => setState(() => targetId = value)
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-marker-label-field'),
                  controller: label,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('world-marker-x-field'),
                        controller: x,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'X',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('world-marker-y-field'),
                        controller: y,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Y',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-marker-category-field'),
                  controller: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-marker-icon-field'),
                  controller: icon,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-marker-notes-field'),
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    key: const Key('world-marker-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('world-marker-confirm'),
            onPressed: () {
              final target = targetId;
              if (target == null || target.isEmpty) {
                setState(() => error = 'Choose the record this marker points '
                    'at.');
                return;
              }
              final parsedX = num.tryParse(x.text.trim());
              final parsedY = num.tryParse(y.text.trim());
              if (parsedX == null || parsedY == null) {
                setState(() => error = 'X and Y must be numbers.');
                return;
              }
              Navigator.pop(
                context,
                _WorldMarkerDraft(
                  targetId: target,
                  x: parsedX,
                  y: parsedY,
                  label: label.text.trim(),
                  icon: icon.text.trim(),
                  category: category.text.trim(),
                  notes: notes.text.trim(),
                ),
              );
            },
            child: Text(widget.existing == null ? 'Place marker' : 'Save'),
          ),
        ],
      );
}

class _WorldRouteDraft {
  const _WorldRouteDraft({
    required this.title,
    required this.startId,
    required this.endId,
    required this.routeType,
    required this.distance,
    required this.travelTime,
    required this.difficulty,
  });

  final String title;
  final String startId;
  final String endId;
  final String routeType;
  final String distance;
  final String travelTime;
  final String difficulty;
}

class _WorldRouteDialog extends StatefulWidget {
  const _WorldRouteDialog({
    required this.places,
    this.initialStartId,
    this.existing,
  });

  final List<AuthorRecord> places;
  final String? initialStartId;
  final WorldRouteView? existing;

  @override
  State<_WorldRouteDialog> createState() => _WorldRouteDialogState();
}

class _WorldRouteDialogState extends State<_WorldRouteDialog> {
  late final TextEditingController title;
  late final TextEditingController routeType;
  late final TextEditingController distance;
  late final TextEditingController travelTime;
  late final TextEditingController difficulty;
  String? startId;
  String? endId;
  String? error;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    title = TextEditingController(text: existing?.record.title ?? '');
    routeType = TextEditingController(text: existing?.routeType ?? '');
    distance = TextEditingController(text: existing?.distance ?? '');
    travelTime = TextEditingController(text: existing?.travelTime ?? '');
    difficulty = TextEditingController(text: existing?.difficulty ?? '');
    final wantedStart = existing?.startId ?? widget.initialStartId;
    startId = widget.places.any((place) => place.id == wantedStart)
        ? wantedStart
        : widget.places.firstOrNull?.id;
    final wantedEnd = existing?.endId;
    endId = widget.places.any((place) => place.id == wantedEnd)
        ? wantedEnd
        : widget.places
            .where((place) => place.id != startId)
            .firstOrNull
            ?.id;
  }

  @override
  void dispose() {
    title.dispose();
    routeType.dispose();
    distance.dispose();
    travelTime.dispose();
    difficulty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('world-route-dialog'),
        title: Text(widget.existing == null ? 'Add a route' : 'Edit route'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('world-route-title-field'),
                  controller: title,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Route name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('world-route-start-field'),
                  initialValue: startId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'From',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final place in widget.places)
                      DropdownMenuItem(
                        key: Key('world-route-start-${place.id}'),
                        value: place.id,
                        child: Text(place.title,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => startId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('world-route-end-field'),
                  initialValue: endId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'To',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final place in widget.places)
                      DropdownMenuItem(
                        key: Key('world-route-end-${place.id}'),
                        value: place.id,
                        child: Text(place.title,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) => setState(() => endId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-route-type-field'),
                  controller: routeType,
                  decoration: const InputDecoration(
                    labelText: 'Route type',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-route-distance-field'),
                  controller: distance,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-route-time-field'),
                  controller: travelTime,
                  decoration: const InputDecoration(
                    labelText: 'Travel time',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('world-route-difficulty-field'),
                  controller: difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    key: const Key('world-route-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('world-route-confirm'),
            onPressed: () {
              final name = title.text.trim();
              if (name.isEmpty) {
                setState(() => error = 'A route name is required.');
                return;
              }
              if (startId == null || endId == null) {
                setState(() => error = 'Both endpoints are required.');
                return;
              }
              if (startId == endId) {
                setState(() => error = 'Route endpoints must differ.');
                return;
              }
              Navigator.pop(
                context,
                _WorldRouteDraft(
                  title: name,
                  startId: startId!,
                  endId: endId!,
                  routeType: routeType.text.trim(),
                  distance: distance.text.trim(),
                  travelTime: travelTime.text.trim(),
                  difficulty: difficulty.text.trim(),
                ),
              );
            },
            child: Text(widget.existing == null ? 'Create route' : 'Save'),
          ),
        ],
      );
}

class _WorldCustomFieldDialog extends StatefulWidget {
  const _WorldCustomFieldDialog();

  @override
  State<_WorldCustomFieldDialog> createState() =>
      _WorldCustomFieldDialogState();
}

class _WorldCustomFieldDialogState extends State<_WorldCustomFieldDialog> {
  final labelController = TextEditingController();
  String? error;

  @override
  void dispose() {
    labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('world-custom-field-dialog'),
        title: const Text('Add a custom field'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('world-custom-field-label'),
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Field name',
                  helperText: 'Stored on this record alongside template fields.',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('world-custom-field-confirm'),
            onPressed: () {
              final label = labelController.text.trim();
              if (label.isEmpty) {
                setState(() => error = 'A field name is required.');
                return;
              }
              Navigator.pop(context, (_fieldKey(label), label));
            },
            child: const Text('Add field'),
          ),
        ],
      );
}

class _WorldChoiceDialog extends StatefulWidget {
  const _WorldChoiceDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.dialogKey,
    required this.fieldKey,
    required this.confirmKey,
    required this.options,
    this.initialValue,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final Key dialogKey;
  final Key fieldKey;
  final Key confirmKey;
  final List<(String, String)> options;
  final String? initialValue;

  @override
  State<_WorldChoiceDialog> createState() => _WorldChoiceDialogState();
}

class _WorldChoiceDialogState extends State<_WorldChoiceDialog> {
  late String? value = widget.options
          .where((option) => option.$1 == widget.initialValue)
          .firstOrNull
          ?.$1 ??
      widget.options.firstOrNull?.$1;

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: widget.dialogKey,
        title: Text(widget.title),
        content: SizedBox(
          width: 460,
          child: DropdownButtonFormField<String>(
            key: widget.fieldKey,
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final option in widget.options)
                DropdownMenuItem(
                  key: Key('world-choice-option-${option.$1}'),
                  value: option.$1,
                  child: Text(option.$2, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (next) => setState(() => value = next),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: widget.confirmKey,
            onPressed:
                value == null ? null : () => Navigator.pop(context, value),
            child: Text(widget.confirmLabel),
          ),
        ],
      );
}

class _WorldNameDialog extends StatefulWidget {
  const _WorldNameDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.fieldKey,
    required this.confirmKey,
    this.initialValue = '',
    this.message,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final Key fieldKey;
  final Key confirmKey;
  final String initialValue;
  final String? message;

  @override
  State<_WorldNameDialog> createState() => _WorldNameDialogState();
}

class _WorldNameDialogState extends State<_WorldNameDialog> {
  late final controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!),
              const SizedBox(height: 12),
            ],
            TextField(
              key: widget.fieldKey,
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.label,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: widget.confirmKey,
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(widget.confirmLabel),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------

class _WorldCard extends StatelessWidget {
  const _WorldCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A Material, not a decorated Container: list tiles and ink effects inside
    // the card need a Material ancestor to paint against.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _WorldMessage extends StatelessWidget {
  const _WorldMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _WorldBanner extends StatelessWidget {
  const _WorldBanner({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldFieldSection extends StatelessWidget {
  const _WorldFieldSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _WorldValidationPanel extends StatelessWidget {
  const _WorldValidationPanel({
    super.key,
    required this.issues,
    this.templateReport,
  });

  final List<RecordValidationIssue> issues;
  final TemplateCompatibilityReport? templateReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final errors =
        issues.where((issue) => issue.severity == RecordValidationSeverity.error);
    final warnings = issues
        .where((issue) => issue.severity == RecordValidationSeverity.warning);
    final drift = templateReport == null ||
            templateReport!.status == TemplateCompatibilityStatus.current
        ? null
        : 'Template state: ${templateReport!.status.name}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errors.isEmpty ? scheme.surfaceContainer : scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                errors.isEmpty
                    ? Icons.warning_amber_rounded
                    : Icons.error_outline,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                errors.isEmpty ? 'Needs attention' : 'Validation errors',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in [...errors, ...warnings])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${issue.message}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (drift != null)
            Text('• $drift',
                style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WorldContinuityTile extends StatelessWidget {
  const _WorldContinuityTile({
    super.key,
    required this.issue,
    required this.actionLabel,
    required this.actionKey,
    required this.onResolve,
  });

  final ContinuityIntegrityIssue issue;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (issue.severity) {
                    ContinuitySeverity.critical => Icons.error_outline_rounded,
                    ContinuitySeverity.warning => Icons.warning_amber_rounded,
                    ContinuitySeverity.notice => Icons.info_outline_rounded,
                  },
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(issue.title, style: theme.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(issue.message),
            const SizedBox(height: 6),
            Text(issue.recommendation, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: actionKey,
                onPressed: onResolve,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafeDeleteSummary extends StatelessWidget {
  const _SafeDeleteSummary({
    super.key,
    required this.analysis,
    this.detailed = false,
  });

  final SafeDeleteAnalysis analysis;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connections = analysis.incomingConnections.length +
        analysis.outgoingConnections.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Disposition: ${analysis.disposition.name}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$connections connection(s), ${analysis.references.length} '
          'reference(s), ${analysis.affectedBranches.length} branch(es) and '
          '${analysis.versionCount} version(s) are preserved.',
          style: theme.textTheme.bodySmall,
        ),
        if (detailed) ...[
          if (analysis.blockingReasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Blocking', style: theme.textTheme.titleSmall),
            for (final reason in analysis.blockingReasons)
              Text('• $reason', style: theme.textTheme.bodySmall),
          ],
          if (analysis.warnings.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Warnings', style: theme.textTheme.titleSmall),
            for (final warning in analysis.warnings)
              Text('• $warning', style: theme.textTheme.bodySmall),
          ],
          if (analysis.affectedRecords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Dependent records', style: theme.textTheme.titleSmall),
            for (final id in analysis.affectedRecords)
              Text('• $id', style: theme.textTheme.bodySmall),
          ],
        ],
      ],
    );
  }
}

class _WorldSaveIndicator extends StatelessWidget {
  const _WorldSaveIndicator({
    super.key,
    required this.state,
    required this.message,
  });

  final WorldSaveState state;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, fallback) = switch (state) {
      WorldSaveState.saving => (Icons.sync_rounded, scheme.primary, 'Saving…'),
      WorldSaveState.saved => (
          Icons.cloud_done_outlined,
          scheme.primary,
          'All changes saved',
        ),
      WorldSaveState.failed => (
          Icons.error_outline,
          scheme.error,
          'Could not save',
        ),
      WorldSaveState.idle => (
          Icons.edit_note_outlined,
          scheme.outline,
          'No pending changes',
        ),
    };
    return Row(
      key: const Key('world-save-state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            message.isEmpty ? fallback : message,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _WorldInlineLoader extends StatelessWidget {
  const _WorldInlineLoader();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _display(Object? value) {
  if (value == null) return '';
  if (value is Iterable) {
    return value.map((item) => '$item').join(', ');
  }
  return '$value';
}

List<String> _splitList(String value) => value
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

/// Keeps an unknown field's stored shape when the author edits it as text.
Object? _coerceLike(Object? original, String text) {
  if (original is List) return _splitList(text);
  if (original is num) return num.tryParse(text.trim()) ?? text.trim();
  if (original is bool) return text.trim().toLowerCase() == 'true';
  return text;
}

Object? _coerceForField(RecordFieldDefinition field, String text) {
  final trimmed = text.trim();
  switch (field.type) {
    case RecordFieldType.number:
    case RecordFieldType.rating:
      return num.tryParse(trimmed) ?? trimmed;
    case RecordFieldType.boolean:
      return trimmed.toLowerCase() == 'true';
    case RecordFieldType.multipleChoice:
    case RecordFieldType.tags:
    case RecordFieldType.list:
    case RecordFieldType.checklist:
      return _splitList(trimmed);
    default:
      return trimmed;
  }
}

String _fieldKey(String label) {
  final slug = label
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'(^_+|_+$)'), '');
  return slug.isEmpty ? 'custom_field' : slug;
}

String _newId(String prefix, String label) {
  final slug = _slug(label);
  return '$prefix-${slug.isEmpty ? 'record' : slug}-'
      '${DateTime.now().microsecondsSinceEpoch}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int input) => input.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _readableError(Object error) {
  if (error is StateError) return error.message;
  if (error is ArgumentError) return '${error.message}';
  if (error is RecordValidationException) {
    return error.result.errors.map((issue) => issue.message).join(' ');
  }
  if (error is WorldHierarchyException) return error.message;
  return error.toString();
}
