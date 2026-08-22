import 'package:flutter/material.dart';

import 'codex_continuity.dart';
import 'continuity.dart';
import 'continuity_actions.dart';
import 'core/branch_domain.dart';
import 'core/connected_domain.dart';
import 'core/connection_types.dart';
import 'core/record_inspection.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'core/story_graph.dart';
import 'core/story_graph_service.dart';
import 'core/search_models.dart';
import 'core/story_codex_domain.dart';
import 'core/template_engine.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'knowledge_graph/open_in_graph.dart';
import 'persistence/authoros_database.dart';
import 'story_codex_service.dart';

/// Where a connected record lives, so the shell can switch Studios.
class CodexNavigationRequest {
  const CodexNavigationRequest({
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

enum CodexSaveState { idle, saving, saved, failed }

/// The writer-facing Story Codex workspace.
///
/// Every read and write goes through [StoryCodexService], which composes
/// `RecordService`, `RecordTypeRegistry`, `TemplateEngine`, `ConnectionEngine`,
/// `BranchService`, `UniversalSearchService`, `UniversalRecordInspector`,
/// `VersionAuditService` and `SafeDeleteService`. All Codex data stays a
/// Universal Record.
class StoryCodexWorkspace extends StatefulWidget {
  const StoryCodexWorkspace({
    super.key,
    required this.projectId,
    this.repository,
    this.onNavigate,
    this.focusRecordId,
    this.continuity = const CodexContinuityIntelligence(),
  });

  final String projectId;
  final DriftConnectedDomainRepository? repository;
  final ValueChanged<CodexNavigationRequest>? onNavigate;
  /// A record to open on, when the author arrived by following a connection.
  ///
  /// A request, not a guarantee: an id this Studio does not hold leaves the
  /// existing selection alone.
  final String? focusRecordId;
  final CodexContinuityIntelligence continuity;

  @override
  State<StoryCodexWorkspace> createState() => _StoryCodexWorkspaceState();
}

class _StoryCodexWorkspaceState extends State<StoryCodexWorkspace> {
  final searchController = TextEditingController();
  late final StoryCodexService service;

  CodexEntryFilter filter = CodexEntryFilter.empty;
  CodexEditorMode editorMode = CodexEditorMode.simple;
  String? activeBranchId;
  String? selectedId;
  String? activeSavedViewId;

  List<CodexEntry> visible = const [];
  List<CodexEntry> allEntries = const [];
  List<CodexCategory> categories = const [];
  List<CodexTag> tags = const [];
  List<RecordTypeDefinition> templates = const [];
  List<CodexSavedView> savedViews = const [];
  List<StoryBranch> branches = const [];
  Set<String> pinnedIds = const {};
  Map<String, RecordValidationResult> validation = const {};
  Map<String, TemplateCompatibilityReport> templateReports = const {};

  bool loading = true;
  bool busy = false;
  String? loadError;
  CodexSaveState saveState = CodexSaveState.idle;
  String saveMessage = '';

  @override
  void initState() {
    super.initState();
    service = StoryCodexService(
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

  CodexEntry? get selected =>
      visible.where((entry) => entry.id == selectedId).firstOrNull ??
      allEntries.where((entry) => entry.id == selectedId).firstOrNull;

  bool get onBranch => activeBranchId != null;

  Future<void> _load() async {
    try {
      await service.ensureFoundation();
      final entries = onBranch
          ? await service.listByBranch(activeBranchId!)
          : await service.getEntries(includeArchived: true);
      final results = await Future.wait<Object>([
        service.filterEntries(filter, branchId: activeBranchId),
        service.getCategories(),
        service.getTags(),
        service.templateRegistry(),
        service.getSavedViews(),
        service.getBranches(),
        service.getPinnedEntries(),
        service.validateEntries(entries),
        service.templateReports(entries),
      ]);
      if (!mounted) return;
      final registry = results[3] as RecordTypeRegistry;
      setState(() {
        allEntries = entries;
        visible = results[0] as List<CodexEntry>;
        categories = results[1] as List<CodexCategory>;
        tags = results[2] as List<CodexTag>;
        templates = registry.definitions
            .where((definition) =>
                definition.extensionData['selectableForNewRecords'] != false &&
                definition.extensionData['archived'] != true)
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
        savedViews = results[4] as List<CodexSavedView>;
        branches = results[5] as List<StoryBranch>;
        pinnedIds =
            (results[6] as List<CodexEntry>).map((entry) => entry.id).toSet();
        validation = results[7] as Map<String, RecordValidationResult>;
        templateReports =
            results[8] as Map<String, TemplateCompatibilityReport>;
        loading = false;
        loadError = null;
        if (selectedId != null &&
            !allEntries.any((entry) => entry.id == selectedId)) {
          selectedId = null;
        }
        final focus = widget.focusRecordId;
        if (focus != null && allEntries.any((entry) => entry.id == focus)) {
          selectedId = focus;
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

  Future<void> _applyFilter(CodexEntryFilter next, {String? savedViewId}) async {
    setState(() {
      filter = next;
      activeSavedViewId = savedViewId;
      busy = true;
    });
    final results = await service.filterEntries(next, branchId: activeBranchId);
    if (!mounted) return;
    setState(() {
      visible = results;
      busy = false;
    });
  }

  Future<void> _switchBranch(String? branchId) async {
    setState(() {
      activeBranchId = branchId;
      selectedId = null;
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
      saveState = CodexSaveState.saving;
      saveMessage = 'Saving…';
    });
    try {
      await action();
      if (!mounted) return true;
      await _load();
      if (!mounted) return true;
      setState(() {
        saveState = CodexSaveState.saved;
        saveMessage = success;
      });
      return true;
    } catch (caught) {
      if (!mounted) return false;
      setState(() {
        saveState = CodexSaveState.failed;
        saveMessage = _readableError(caught);
      });
      return false;
    }
  }

  Future<void> _createEntry() async {
    if (templates.isEmpty || categories.isEmpty) return;
    final draft = await showDialog<CodexEntryDraft>(
      context: context,
      builder: (context) => _CodexCreateDialog(
        templates: templates,
        categories: categories,
        onBranch: onBranch,
        registry: null,
        service: service,
      ),
    );
    if (draft == null) return;
    String? createdId;
    final saved = await _mutate(
      () async {
        final entry = onBranch
            ? await service.createCodexEntryInBranch(activeBranchId!, draft)
            : await service.createCodexEntry(draft);
        createdId = entry.id;
      },
      success: 'Entry created',
    );
    if (saved && createdId != null && mounted) {
      setState(() => selectedId = createdId);
    }
  }

  Future<void> _togglePin(CodexEntry entry) => _mutate(
        () => service.setPinned(entry.id, !pinnedIds.contains(entry.id)),
        success: pinnedIds.contains(entry.id) ? 'Unpinned' : 'Pinned',
      );

  Future<void> _archive(CodexEntry entry) async {
    final analysis = await service.analyzeDelete(entry.id);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('codex-archive-dialog'),
        title: Text('Archive ${entry.title}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Archiving hides the entry from the workspace. Nothing is '
              'deleted: connections, history, branches and sources are kept '
              'and the entry can be restored at any time.',
            ),
            if (analysis != null) ...[
              const SizedBox(height: 12),
              Text(
                '${analysis.incomingConnections.length + analysis.outgoingConnections.length} '
                'connection(s) and ${analysis.versionCount} version(s) will be '
                'preserved.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('codex-archive-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _mutate(
      () => service.archiveCodexEntry(entry.id),
      success: 'Archived ${entry.title}',
    );
  }

  Future<void> _restore(CodexEntry entry) => _mutate(
        () => service.restoreCodexEntry(entry.id),
        success: 'Restored ${entry.title}',
      );

  Future<void> _saveCurrentView() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _CodexNameDialog(
        title: 'Save this view',
        label: 'View name',
        confirmLabel: 'Save view',
        fieldKey: Key('codex-save-view-name-field'),
        confirmKey: Key('codex-save-view-confirm'),
      ),
    );
    if (name == null || name.isEmpty) return;
    await _mutate(
      () async {
        final view = await service.saveView(name: name, filter: filter);
        activeSavedViewId = view.id;
      },
      success: 'Saved view "$name"',
    );
  }

  Future<void> _deleteView(CodexSavedView view) async {
    final confirmed = await _confirm(
      title: 'Delete "${view.name}"?',
      message: 'The saved view is removed. No Codex entries are affected.',
      confirmLabel: 'Delete view',
    );
    if (!confirmed) return;
    await _mutate(
      () async {
        await service.deleteSavedView(view.id);
        if (activeSavedViewId == view.id) activeSavedViewId = null;
      },
      success: 'View deleted',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('codex-confirm-dialog'),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('codex-confirm-button'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Asks the shell for the Knowledge Graph, focused on [record].
  ///
  /// Separate from [_navigate], which routes a record to the Studio that owns
  /// it — the graph is a different destination, not a different owner.
  void _openInGraph(AuthorRecord record) {
    widget.onNavigate?.call(CodexNavigationRequest(
      destination: SearchDestination.knowledgeGraph,
      recordId: record.id,
      recordType: record.typeId,
      title: record.title,
    ));
  }

  /// Hands a graph node off to the Studio that owns it.
  ///
  /// [_navigate] takes an [AuthorRecord], which a scene or chapter is not.
  void _navigateNode(StoryGraphNode node) {
    widget.onNavigate?.call(CodexNavigationRequest(
      destination: searchDestinationForType(node.typeId),
      recordId: node.id,
      recordType: node.typeId,
      title: node.title,
    ));
  }

  void _navigate(AuthorRecord record) {
    widget.onNavigate?.call(CodexNavigationRequest(
      destination: searchDestinationForType(record.typeId),
      recordId: record.id,
      recordType: record.typeId,
      title: record.title,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        key: Key('codex-loading-state'),
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (loadError != null) {
      return _CodexMessage(
        key: const Key('codex-error-state'),
        icon: Icons.error_outline,
        title: 'The Story Codex could not be opened.',
        message: loadError!,
        actionLabel: 'Try again',
        onAction: () {
          setState(() => loading = true);
          _load();
        },
      );
    }

    return Material(
      key: const Key('story-codex-workspace'),
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final rail = _CodexFilterRail(
              filter: filter,
              categories: categories,
              tags: tags,
              templates: templates,
              savedViews: savedViews,
              activeSavedViewId: activeSavedViewId,
              searchController: searchController,
              onFilterChanged: _applyFilter,
              onApplySavedView: (view) =>
                  _applyFilter(view.filter, savedViewId: view.id),
              onSaveView: _saveCurrentView,
              onDeleteView: _deleteView,
            );
            final list = _CodexEntryList(
              entries: visible,
              selectedId: selectedId,
              pinnedIds: pinnedIds,
              validation: validation,
              templateReports: templateReports,
              categories: categories,
              busy: busy,
              hasAnyEntries: allEntries.isNotEmpty,
              filter: filter,
              onSelect: (id) => setState(() => selectedId = id),
              onCreate: _createEntry,
              onClearFilters: () => _applyFilter(CodexEntryFilter.empty),
            );
            final entry = selected;
            final detail = entry == null
                ? const _CodexMessage(
                    key: Key('codex-detail-empty-state'),
                    icon: Icons.auto_stories_outlined,
                    title: 'Select an entry',
                    message:
                        'Choose a Codex entry to read it, edit its fields, '
                        'manage relationships and sources, or inspect its '
                        'history.',
                  )
                : _CodexEntryPane(
                    key: ValueKey('codex-pane-${entry.id}'),
                    service: service,
                    entry: entry,
                    entries: allEntries,
                    categories: categories,
                    tags: tags,
                    templates: templates,
                    pinned: pinnedIds.contains(entry.id),
                    editorMode: editorMode,
                    activeBranchId: activeBranchId,
                    validation: validation[entry.id],
                    templateReport: templateReports[entry.id],
                    continuity: widget.continuity,
                    saveState: saveState,
                    saveMessage: saveMessage,
                    onEditorModeChanged: (mode) =>
                        setState(() => editorMode = mode),
                    onMutate: _mutate,
                    onTogglePin: () => _togglePin(entry),
                    onArchive: () => _archive(entry),
                    onRestore: () => _restore(entry),
                    onConfirm: _confirm,
                    onNavigate: _navigate,
                    onNavigateNode: _navigateNode,
                    onOpenInGraph: _openInGraph,
                    onOpenEntry: (id) => setState(() => selectedId = id),
                  );

            if (constraints.maxWidth >= 1180) {
              return SizedBox(
                height: _paneHeight(context),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 268,
                      child: SingleChildScrollView(child: rail),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 352,
                      child: SingleChildScrollView(child: list),
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
                            list,
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
                list,
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
                  'Story Codex',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${allEntries.length} connected knowledge record'
                  '${allEntries.length == 1 ? '' : 's'} in this project.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CodexSaveIndicator(state: saveState, message: saveMessage),
                if (branches.isNotEmpty)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      key: const Key('codex-branch-selector'),
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
                            key: Key('codex-branch-option-${branch.id}'),
                            value: branch.id,
                            child: Text(
                              branch.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => _switchBranch(
                        value == _canonBranchValue ? null : value,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  key: const Key('codex-new-entry-button'),
                  onPressed: templates.isEmpty ? null : _createEntry,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New entry'),
                ),
              ],
            ),
          ],
        ),
        if (onBranch) ...[
          const SizedBox(height: 12),
          _CodexBanner(
            key: const Key('codex-branch-banner'),
            icon: Icons.alt_route_rounded,
            message:
                'You are reading the "${_branchName(activeBranchId!)}" branch. '
                'Edits are saved as branch overrides and Canon is left '
                'untouched.',
          ),
        ],
      ],
    );
  }

  String _branchName(String id) =>
      branches.where((branch) => branch.id == id).firstOrNull?.name ?? id;
}

const _canonBranchValue = '__canon__';

// ---------------------------------------------------------------------------
// Filter rail and saved views
// ---------------------------------------------------------------------------

class _CodexFilterRail extends StatelessWidget {
  const _CodexFilterRail({
    required this.filter,
    required this.categories,
    required this.tags,
    required this.templates,
    required this.savedViews,
    required this.activeSavedViewId,
    required this.searchController,
    required this.onFilterChanged,
    required this.onApplySavedView,
    required this.onSaveView,
    required this.onDeleteView,
  });

  final CodexEntryFilter filter;
  final List<CodexCategory> categories;
  final List<CodexTag> tags;
  final List<RecordTypeDefinition> templates;
  final List<CodexSavedView> savedViews;
  final String? activeSavedViewId;
  final TextEditingController searchController;
  final ValueChanged<CodexEntryFilter> onFilterChanged;
  final ValueChanged<CodexSavedView> onApplySavedView;
  final VoidCallback onSaveView;
  final ValueChanged<CodexSavedView> onDeleteView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _CodexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('codex-search-field'),
            controller: searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Find an entry',
              hintText: 'Title, summary, content, tag',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (value) =>
                onFilterChanged(filter.copyWith(query: value)),
            onChanged: (value) => onFilterChanged(filter.copyWith(query: value)),
          ),
          const SizedBox(height: 16),
          _railHeader(context, 'Saved views', action: 'Save current view',
              onAction: onSaveView, actionKey: const Key('codex-save-view-button')),
          const SizedBox(height: 8),
          if (savedViews.isEmpty)
            Text(
              'Filter the list, then save it as a view you can return to.',
              style: theme.textTheme.bodySmall,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final view in savedViews)
                  InputChip(
                    key: Key('codex-saved-view-${view.id}'),
                    avatar: const Icon(Icons.bookmark_outline, size: 16),
                    label: Text(view.name),
                    selected: activeSavedViewId == view.id,
                    onPressed: () => onApplySavedView(view),
                    onDeleted: () => onDeleteView(view),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    deleteButtonTooltipMessage: 'Delete view',
                  ),
              ],
            ),
          const SizedBox(height: 18),
          _railHeader(context, 'Categories'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category
                  in categories.where((category) => !category.archived))
                FilterChip(
                  key: Key('codex-category-filter-${category.id}'),
                  label: Text(category.name),
                  selected: filter.categoryIds.contains(category.id),
                  onSelected: (_) =>
                      onFilterChanged(filter.toggleCategory(category.id)),
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
              for (final status in CodexCanonStatus.values)
                FilterChip(
                  key: Key('codex-canon-filter-${status.name}'),
                  label: Text(codexCanonStatusLabel(status)),
                  selected: filter.canonStatuses.contains(status),
                  onSelected: (_) =>
                      onFilterChanged(filter.toggleCanonStatus(status)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _railHeader(context, 'Knowledge'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final status in CodexKnowledgeStatus.values)
                FilterChip(
                  key: Key('codex-knowledge-filter-${status.name}'),
                  label: Text(codexKnowledgeStatusLabel(status)),
                  selected: filter.knowledgeStatuses.contains(status),
                  onSelected: (_) =>
                      onFilterChanged(filter.toggleKnowledgeStatus(status)),
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
                    key: Key('codex-tag-filter-${tag.id}'),
                    label: Text(tag.name),
                    selected: filter.tagIds.contains(tag.id),
                    onSelected: (_) => onFilterChanged(filter.toggleTag(tag.id)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _railHeader(context, 'Template'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('codex-template-filter'),
            initialValue: filter.templateIds.isEmpty
                ? _anyTemplateValue
                : filter.templateIds.first,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: _anyTemplateValue,
                child: Text('Any template'),
              ),
              for (final template in templates)
                DropdownMenuItem(
                  value: template.id,
                  child: Text(template.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => onFilterChanged(
              filter.copyWith(
                templateIds:
                    value == null || value == _anyTemplateValue ? {} : {value},
              ),
            ),
          ),
          const SizedBox(height: 18),
          _railHeader(context, 'Sort'),
          const SizedBox(height: 8),
          DropdownButtonFormField<CodexEntrySort>(
            key: const Key('codex-sort-field'),
            initialValue: filter.sort,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: CodexEntrySort.recentlyUpdated,
                child: Text('Recently updated'),
              ),
              DropdownMenuItem(
                value: CodexEntrySort.title,
                child: Text('Title (A–Z)'),
              ),
              DropdownMenuItem(
                value: CodexEntrySort.canonStatus,
                child: Text('Canon state'),
              ),
            ],
            onChanged: (value) => onFilterChanged(filter.copyWith(sort: value)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('codex-include-archived-toggle'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Include archived'),
            value: filter.includeArchived,
            onChanged: (value) =>
                onFilterChanged(filter.copyWith(includeArchived: value)),
          ),
          SwitchListTile(
            key: const Key('codex-pinned-toggle'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Pinned only'),
            value: filter.onlyPinned,
            onChanged: (value) =>
                onFilterChanged(filter.copyWith(onlyPinned: value)),
          ),
          SwitchListTile(
            key: const Key('codex-needs-attention-toggle'),
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
                key: const Key('codex-clear-filters-button'),
                onPressed: () {
                  searchController.clear();
                  onFilterChanged(CodexEntryFilter.empty);
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

  Widget _railHeader(
    BuildContext context,
    String title, {
    String? action,
    VoidCallback? onAction,
    Key? actionKey,
  }) =>
      Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (action != null)
            IconButton(
              key: actionKey,
              tooltip: action,
              visualDensity: VisualDensity.compact,
              onPressed: onAction,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            ),
        ],
      );
}

const _anyTemplateValue = '__any__';

// ---------------------------------------------------------------------------
// Entry list
// ---------------------------------------------------------------------------

class _CodexEntryList extends StatelessWidget {
  const _CodexEntryList({
    required this.entries,
    required this.selectedId,
    required this.pinnedIds,
    required this.validation,
    required this.templateReports,
    required this.categories,
    required this.busy,
    required this.hasAnyEntries,
    required this.filter,
    required this.onSelect,
    required this.onCreate,
    required this.onClearFilters,
  });

  final List<CodexEntry> entries;
  final String? selectedId;
  final Set<String> pinnedIds;
  final Map<String, RecordValidationResult> validation;
  final Map<String, TemplateCompatibilityReport> templateReports;
  final List<CodexCategory> categories;
  final bool busy;
  final bool hasAnyEntries;
  final CodexEntryFilter filter;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _CodexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Entries',
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
                  '${entries.length}',
                  key: const Key('codex-result-count'),
                  style: theme.textTheme.labelMedium,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            hasAnyEntries
                ? _CodexMessage(
                    key: const Key('codex-no-results-state'),
                    icon: Icons.search_off_rounded,
                    title: 'No entries match this view',
                    message:
                        'Nothing in the Codex matches the current filters.',
                    actionLabel: filter.isEmpty ? null : 'Clear filters',
                    onAction: filter.isEmpty ? null : onClearFilters,
                  )
                : _CodexMessage(
                    key: const Key('codex-empty-state'),
                    icon: Icons.auto_stories_outlined,
                    title: 'The Codex is empty',
                    message:
                        'Create your first entry from a template to start '
                        'building connected story knowledge.',
                    actionLabel: 'New entry',
                    onAction: onCreate,
                  )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CodexEntryTile(
                  entry: entry,
                  selected: entry.id == selectedId,
                  pinned: pinnedIds.contains(entry.id),
                  validation: validation[entry.id],
                  templateReport: templateReports[entry.id],
                  categoryName: categories
                      .where((category) => category.id == entry.categoryId)
                      .firstOrNull
                      ?.name,
                  onTap: () => onSelect(entry.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _CodexEntryTile extends StatelessWidget {
  const _CodexEntryTile({
    required this.entry,
    required this.selected,
    required this.pinned,
    required this.validation,
    required this.templateReport,
    required this.categoryName,
    required this.onTap,
  });

  final CodexEntry entry;
  final bool selected;
  final bool pinned;
  final RecordValidationResult? validation;
  final TemplateCompatibilityReport? templateReport;
  final String? categoryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = codexValidationBadge(validation, templateReport);
    return Material(
      color: selected ? scheme.secondaryContainer : scheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: Key('codex-entry-tile-${entry.id}'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (pinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin, size: 14),
                    ),
                  Expanded(
                    child: Text(
                      entry.title,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (badge != null)
                    Tooltip(
                      message: badge.message,
                      child: Icon(
                        badge.icon,
                        key: Key('codex-validation-badge-${entry.id}'),
                        size: 16,
                        color: badge.isError ? scheme.error : scheme.tertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${categoryName ?? entry.categoryId} · '
                '${codexCanonStatusLabel(entry.canonStatus)}'
                '${entry.isArchived ? ' · Archived' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (entry.summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Validation summary shown next to an entry.
class CodexValidationBadge {
  const CodexValidationBadge({
    required this.icon,
    required this.message,
    required this.isError,
  });

  final IconData icon;
  final String message;
  final bool isError;
}

CodexValidationBadge? codexValidationBadge(
  RecordValidationResult? validation,
  TemplateCompatibilityReport? templateReport,
) {
  if (validation != null && validation.errors.isNotEmpty) {
    return CodexValidationBadge(
      icon: Icons.error_outline,
      message: validation.errors.map((issue) => issue.message).join('\n'),
      isError: true,
    );
  }
  if (templateReport != null && !templateReport.isReadable) {
    return CodexValidationBadge(
      icon: Icons.error_outline,
      message: 'Template ${templateReport.templateId} cannot be resolved.',
      isError: true,
    );
  }
  final warnings = <String>[
    if (validation != null)
      ...validation.warnings.map((issue) => issue.message),
    if (templateReport != null &&
        templateReport.status == TemplateCompatibilityStatus.upgradeAvailable)
      'A newer version of the ${templateReport.templateId} template is '
          'available.',
    if (templateReport != null &&
        templateReport.status ==
            TemplateCompatibilityStatus.newerThanDefinition)
      'This entry was written with a newer template than this install has.',
  ];
  if (warnings.isEmpty) return null;
  return CodexValidationBadge(
    icon: Icons.warning_amber_rounded,
    message: warnings.join('\n'),
    isError: false,
  );
}

// ---------------------------------------------------------------------------
// Entry detail pane
// ---------------------------------------------------------------------------

enum _CodexTab {
  overview,
  fields,
  relationships,
  sources,
  continuity,
  inspector,
  history,
}

String _tabLabel(_CodexTab tab) => switch (tab) {
      _CodexTab.overview => 'Overview',
      _CodexTab.fields => 'Fields',
      _CodexTab.relationships => 'Relationships',
      _CodexTab.sources => 'Sources',
      _CodexTab.continuity => 'Continuity',
      _CodexTab.inspector => 'Inspector',
      _CodexTab.history => 'History',
    };

class _CodexEntryPane extends StatefulWidget {
  const _CodexEntryPane({
    super.key,
    required this.service,
    required this.entry,
    required this.entries,
    required this.categories,
    required this.tags,
    required this.templates,
    required this.pinned,
    required this.editorMode,
    required this.activeBranchId,
    required this.validation,
    required this.templateReport,
    required this.continuity,
    required this.saveState,
    required this.saveMessage,
    required this.onEditorModeChanged,
    required this.onMutate,
    required this.onTogglePin,
    required this.onArchive,
    required this.onRestore,
    required this.onConfirm,
    required this.onNavigate,
    required this.onNavigateNode,
    required this.onOpenInGraph,
    required this.onOpenEntry,
  });

  final StoryCodexService service;
  final CodexEntry entry;
  final List<CodexEntry> entries;
  final List<CodexCategory> categories;
  final List<CodexTag> tags;
  final List<RecordTypeDefinition> templates;
  final bool pinned;
  final CodexEditorMode editorMode;
  final String? activeBranchId;
  final RecordValidationResult? validation;
  final TemplateCompatibilityReport? templateReport;
  final CodexContinuityIntelligence continuity;
  final CodexSaveState saveState;
  final String saveMessage;
  final ValueChanged<CodexEditorMode> onEditorModeChanged;
  final Future<bool> Function(Future<void> Function(), {required String success})
      onMutate;
  final VoidCallback onTogglePin;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final Future<bool> Function({
    required String title,
    required String message,
    required String confirmLabel,
  }) onConfirm;
  final ValueChanged<AuthorRecord> onNavigate;

  /// The same hand-off for a graph node, which may be a scene or a chapter —
  /// [onNavigate] cannot express those, because they are manuscript nodes
  /// rather than records.
  final ValueChanged<StoryGraphNode> onNavigateNode;
  final ValueChanged<AuthorRecord> onOpenInGraph;
  final ValueChanged<String> onOpenEntry;

  @override
  State<_CodexEntryPane> createState() => _CodexEntryPaneState();
}

class _CodexEntryPaneState extends State<_CodexEntryPane> {
  static const _titleKey = '__title';
  static const _summaryKey = '__summary';
  static const _contentKey = '__content';
  static const _aliasesKey = '__aliases';
  static const _tagsKey = '__tags';

  final Map<String, TextEditingController> controllers = {};
  final Map<String, Object?> pendingValues = {};

  _CodexTab tab = _CodexTab.overview;
  late String categoryId;
  late CodexCanonStatus canonStatus;
  late CodexKnowledgeStatus knowledgeStatus;
  bool dirty = false;
  List<RecordValidationIssue> saveIssues = const [];
  String? saveError;

  RecordTypeDefinition? template;
  Future<List<_CodexRelationshipView>>? relationships;
  Future<UniversalRecordInspection?>? inspection;
  Future<List<RecordVersion>>? history;
  Future<CodexContinuityReport>? continuityReport;

  @override
  void initState() {
    super.initState();
    _resetBuffers();
    _reloadPanels();
  }

  @override
  void didUpdateWidget(_CodexEntryPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.entry.id != widget.entry.id ||
        oldWidget.entry.record.revision != widget.entry.record.revision ||
        oldWidget.entry.updatedAt != widget.entry.updatedAt;
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
    final entry = widget.entry;
    categoryId = entry.categoryId;
    canonStatus = entry.canonStatus;
    knowledgeStatus = entry.knowledgeStatus;
    dirty = false;
    saveIssues = const [];
    saveError = null;
    template = _resolveTemplate();
    controllers[_titleKey] = _watched(entry.title);
    controllers[_summaryKey] = _watched(entry.summary);
    controllers[_contentKey] = _watched(entry.content);
    controllers[_aliasesKey] = _watched(entry.aliases.join(', '));
    controllers[_tagsKey] = _watched(
      widget.tags
          .where((tag) => entry.tagIds.contains(tag.id))
          .map((tag) => tag.name)
          .join(', '),
    );
    for (final field in _editableFields()) {
      final value = entry.structuredFields[field.id] ?? field.defaultValue;
      if (field.type == RecordFieldType.boolean) {
        pendingValues[field.id] = value is bool ? value : false;
      } else if (field.type == RecordFieldType.singleChoice) {
        pendingValues[field.id] =
            value is String && field.options.contains(value) ? value : null;
      } else {
        controllers[field.id] = _watched(_displayValue(value));
      }
    }
    for (final key in _unknownFieldKeys()) {
      controllers[key] =
          _watched(_displayValue(widget.entry.structuredFields[key]));
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
    for (final definition in widget.templates) {
      if (definition.id == widget.entry.templateId) return definition;
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
      ..._codexCoreFieldIds,
    };
    return widget.entry.structuredFields.keys
        .where((key) => !known.contains(key))
        .where((key) => widget.entry.structuredFields[key] is! Map)
        .toList()
      ..sort();
  }

  Map<String, String> get _customFieldLabels {
    final raw = widget.entry.metadata[CodexFields.customFieldsKey];
    if (raw is! Map) return const {};
    return {
      for (final item in raw.entries) item.key.toString(): '${item.value}',
    };
  }

  void _reloadPanels() {
    final service = widget.service;
    final id = widget.entry.id;
    relationships = _loadRelationships();
    inspection = service.inspectEntry(id, branchId: widget.activeBranchId);
    history = service.getHistory(id, branchId: widget.activeBranchId);
    continuityReport = _analyzeContinuity();
  }

  /// Loads every connection together with the record on its far end, so the
  /// relationship list renders from one settled future.
  Future<List<_CodexRelationshipView>> _loadRelationships() async {
    final links = await widget.service.getCodexConnections(widget.entry.id);
    // Resolved through the Story Graph rather than recordById: a link to a
    // scene came back null and the tile rendered the raw id followed by
    // "record unavailable" — while the empty state above promises the author
    // they can connect entries to manuscript records.
    final neighbourhood = await StoryGraphService(
      projectId: widget.service.projectId,
      repository: widget.service.repository,
    ).getNeighbours(widget.entry.id,
      filter: StoryGraphFilter.everyRelationship,
    );
    final byId = {
      for (final node in neighbourhood?.neighbours ?? const <StoryGraphNode>[])
        node.id: node,
    };
    final views = <_CodexRelationshipView>[];
    for (final link in links) {
      final otherId =
          link.sourceId == widget.entry.id ? link.targetId : link.sourceId;
      views.add(_CodexRelationshipView(
        link: link,
        other: byId[otherId],
        otherId: otherId,
      ));
    }
    return views;
  }

  Future<CodexContinuityReport> _analyzeContinuity() async {
    final connections = await widget.service.getCodexConnections(widget.entry.id);
    final records = await widget.service
        .connectableRecords(branchId: widget.activeBranchId);
    return widget.continuity.analyze(
      entry: widget.entry,
      entries: widget.entries,
      links: connections,
      knownNames: CodexContinuityIntelligence.knownNames(records),
    );
  }

  // --- Saving -----------------------------------------------------------

  Future<void> _save() async {
    final title = controllers[_titleKey]!.text.trim();
    if (title.isEmpty) {
      setState(() {
        saveError = 'A title is required.';
        saveIssues = const [
          RecordValidationIssue(
            code: 'missing-title',
            message: 'Codex entry title is required.',
            fieldId: 'title',
          ),
        ];
      });
      return;
    }
    final structured = <String, Object?>{
      CodexFields.aliases: _splitList(controllers[_aliasesKey]!.text),
      CodexFields.knowledgeStatus: codexKnowledgeStatusValue(knowledgeStatus),
      for (final field in _editableFields()) field.id: _collectValue(field),
      for (final key in _unknownFieldKeys())
        key: _coerceLike(
          widget.entry.structuredFields[key],
          controllers[key]!.text,
        ),
    };
    setState(() {
      saveError = null;
      saveIssues = const [];
    });

    final tagIds = <String>[];
    for (final name in _splitList(controllers[_tagsKey]!.text)) {
      final existing = widget.tags
          .where((tag) => tag.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      tagIds.add(
        existing?.id ?? (await widget.service.createTag(name: name)).id,
      );
    }

    final saved = await widget.onMutate(
      () async {
        if (widget.activeBranchId != null) {
          await widget.service.updateEntryInBranch(
            widget.activeBranchId!,
            widget.entry.id,
            title: title,
            summary: controllers[_summaryKey]!.text,
            content: controllers[_contentKey]!.text,
            structuredFields: structured,
            tagIds: tagIds,
          );
          return;
        }
        await widget.service.updateCodexEntry(
          widget.entry.id,
          title: title,
          summary: controllers[_summaryKey]!.text,
          content: controllers[_contentKey]!.text,
          categoryId: categoryId,
          tagIds: tagIds,
          canonStatus: canonStatus,
          structuredFields: structured,
        );
      },
      success: 'Saved ${title.isEmpty ? 'entry' : title}',
    );
    if (!mounted) return;
    if (saved) {
      setState(() => dirty = false);
    } else {
      final result = await widget.service.validateEntry(widget.entry.id);
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
        // Tables are edited elsewhere; keep the stored value untouched.
        return widget.entry.structuredFields[field.id];
      default:
        final text = controllers[field.id]!.text;
        return text.trim().isEmpty ? '' : text;
    }
  }

  // --- Actions ----------------------------------------------------------

  Future<void> _setCanonStatus(CodexCanonStatus status) async {
    await widget.onMutate(
      () => widget.service.setCanonStatus(
        widget.entry.id,
        status,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Canon state set to ${codexCanonStatusLabel(status)}',
    );
  }

  Future<void> _addRelationship() async {
    final candidates =
        await widget.service.connectableRecords(branchId: widget.activeBranchId);
    if (!mounted) return;
    final targets =
        candidates.where((record) => record.id != widget.entry.id).toList();
    if (targets.isEmpty) {
      _notify('There is no other record to connect to yet.');
      return;
    }
    final result = await showDialog<_RelationshipChoice>(
      context: context,
      builder: (context) => _CodexRelationshipDialog(
        service: widget.service,
        sourceTypeId: widget.entry.record.typeId,
        targets: targets,
      ),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service.connectEntry(
        sourceId: widget.entry.id,
        targetId: result.targetId,
        typeId: result.typeId,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Relationship added',
    );
    // Connections live beside the record, so the entry revision does not
    // change and the panel futures must be refreshed explicitly.
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _editRelationship(RecordLink link) async {
    final registry = await widget.service.connectionRegistry();
    final available = await widget.service.connectionTypesBetween(
      sourceTypeId:
          await widget.service.repository.entityTypeId(link.sourceId) ?? '',
      targetTypeId:
          await widget.service.repository.entityTypeId(link.targetId) ?? '',
    );
    // Retyping cannot flip a link between directed and undirected, so only
    // offer types that match the stored direction. The current type is always
    // offered, even when the endpoints have changed shape.
    final current = registry.resolve(link.typeId);
    final definitions = <ConnectionTypeDefinition>{
      current,
      ...available.where(
        (definition) => definition.direction == current.direction,
      ),
    }.toList()
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
    if (!mounted) return;
    final typeId = await showDialog<String>(
      context: context,
      builder: (context) => _CodexRelationshipTypeDialog(
        definitions: definitions,
        initialTypeId: link.typeId,
      ),
    );
    if (typeId == null || typeId == link.typeId) return;
    await widget.onMutate(
      () => widget.service.updateEntryConnection(link.id, typeId: typeId),
      success: 'Relationship updated',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _removeRelationship(RecordLink link) async {
    final confirmed = await widget.onConfirm(
      title: 'Remove this relationship?',
      message: widget.activeBranchId == null
          ? 'The connection is removed. Both records are kept.'
          : 'The connection is hidden inside this branch. Canon keeps it.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await widget.onMutate(
      () => widget.service.disconnectEntry(
        link.id,
        activeBranchId: widget.activeBranchId,
      ),
      success: 'Relationship removed',
    );
    if (mounted) setState(_reloadPanels);
  }

  Future<void> _addSource() async {
    final source = await showDialog<CodexSourceReference>(
      context: context,
      builder: (context) => const _CodexSourceDialog(),
    );
    if (source == null) return;
    await widget.onMutate(
      () => widget.service.addSource(widget.entry.id, source),
      success: 'Source added',
    );
  }

  Future<void> _editSource(CodexSourceReference source) async {
    final updated = await showDialog<CodexSourceReference>(
      context: context,
      builder: (context) => _CodexSourceDialog(existing: source),
    );
    if (updated == null) return;
    await widget.onMutate(
      () => widget.service.updateSource(
        widget.entry.id,
        updated.copyWith(id: source.stableId),
      ),
      success: 'Source updated',
    );
  }

  Future<void> _removeSource(CodexSourceReference source) async {
    final confirmed = await widget.onConfirm(
      title: 'Remove this source?',
      message: 'The reference is removed from this entry only.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    await widget.onMutate(
      () => widget.service.removeSource(widget.entry.id, source.stableId),
      success: 'Source removed',
    );
  }

  Future<void> _addCustomField() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => const _CodexCustomFieldDialog(),
    );
    if (result == null) return;
    await widget.onMutate(
      () => widget.service.setCustomField(
        widget.entry.id,
        result.$1,
        result.$2,
        '',
      ),
      success: 'Custom field added',
    );
  }

  Future<void> _setVisibility(
    String fieldId,
    CodexFieldVisibility visibility,
  ) =>
      widget.onMutate(
        () => widget.service
            .setFieldVisibility(widget.entry.id, fieldId, visibility),
        success: 'Visibility updated',
      );

  Future<void> _restoreVersion(RecordVersion version) async {
    final confirmed = await widget.onConfirm(
      title: 'Restore this version?',
      message: 'The entry is rewritten to the state saved on '
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

  Future<void> _resolveContinuity(
    ContinuityIntegrityIssue issue,
    CodexContinuityFinding finding,
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
        builder: (context) => _CodexNameDialog(
          title: 'Create the missing record',
          label: 'Name',
          confirmLabel: 'Create record',
          initialValue: finding.missingName,
          message: issue.recommendation,
          fieldKey: const Key('codex-continuity-name-field'),
          confirmKey: const Key('codex-continuity-name-confirm'),
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
        sourceId: finding.entryId,
        targetId: finding.targetId!,
        typeId: finding.connectionTypeId,
        direction: definition.direction == ConnectionDirection.directed
            ? RecordLinkDirection.directed
            : RecordLinkDirection.undirected,
        confirmed: true,
        recheck: () => _continuityWarningRemains(finding),
      );
    } else {
      setState(() => tab = _CodexTab.fields);
      _notify('Review the entry fields, then save to resolve this warning.');
      return;
    }

    if (!mounted) return;
    _notify(result.message);
    if (result.mutationApplied) {
      await widget.onMutate(() async {}, success: result.message);
      if (mounted) setState(_reloadPanels);
    }
  }

  Future<bool> _continuityWarningRemains(CodexContinuityFinding finding) async {
    final entry = await widget.service.getCodexEntry(widget.entry.id);
    if (entry == null) return false;
    final connections = await widget.service.getCodexConnections(entry.id);
    final records =
        await widget.service.connectableRecords(branchId: widget.activeBranchId);
    final report = widget.continuity.analyze(
      entry: entry,
      entries: widget.entries,
      links: connections,
      knownNames: CodexContinuityIntelligence.knownNames(records),
    );
    return report.findings.any((item) =>
        item.warning.type == finding.warning.type &&
        item.missingName == finding.missingName &&
        item.targetId == finding.targetId);
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  // --- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    return _CodexCard(
      key: const Key('codex-entry-pane'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template?.name ?? entry.templateId} · '
                      '${_categoryName(entry.categoryId)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('codex-pin-button'),
                tooltip: widget.pinned ? 'Unpin entry' : 'Pin entry',
                onPressed: widget.onTogglePin,
                icon: Icon(
                  widget.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
              ),
              PopupMenuButton<String>(
                key: const Key('codex-entry-actions'),
                tooltip: 'Entry actions',
                onSelected: (value) {
                  if (value == 'archive') widget.onArchive();
                  if (value == 'restore') widget.onRestore();
                },
                itemBuilder: (context) => [
                  if (entry.isArchived)
                    const PopupMenuItem(
                      value: 'restore',
                      child: Text('Restore entry'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'archive',
                      child: Text('Archive entry'),
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
                key: const Key('codex-canon-chip'),
                label: Text(codexCanonStatusLabel(entry.canonStatus)),
                avatar: const Icon(Icons.verified_outlined, size: 16),
              ),
              Chip(
                key: const Key('codex-knowledge-chip'),
                label: Text(codexKnowledgeStatusLabel(entry.knowledgeStatus)),
                avatar: const Icon(Icons.visibility_outlined, size: 16),
              ),
              if (entry.isArchived)
                const Chip(
                  key: Key('codex-archived-chip'),
                  label: Text('Archived'),
                  avatar: Icon(Icons.archive_outlined, size: 16),
                ),
              for (final tag in widget.tags
                  .where((tag) => entry.tagIds.contains(tag.id)))
                Chip(label: Text(tag.name)),
            ],
          ),
          const SizedBox(height: 12),
          _CodexSaveIndicator(
            key: const Key('codex-detail-save-state'),
            state: dirty && widget.saveState != CodexSaveState.saving
                ? CodexSaveState.idle
                : widget.saveState,
            message: dirty && widget.saveState != CodexSaveState.saving
                ? 'Unsaved changes'
                : widget.saveMessage,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in _CodexTab.values)
                ChoiceChip(
                  key: Key('codex-tab-${value.name}'),
                  label: Text(_tabLabel(value)),
                  selected: tab == value,
                  onSelected: (_) => setState(() => tab = value),
                ),
            ],
          ),
          const Divider(height: 28),
          switch (tab) {
            _CodexTab.overview => _overviewTab(context),
            _CodexTab.fields => _fieldsTab(context),
            _CodexTab.relationships => _relationshipsTab(context),
            _CodexTab.sources => _sourcesTab(context),
            _CodexTab.continuity => _continuityTab(context),
            _CodexTab.inspector => _inspectorTab(context),
            _CodexTab.history => _historyTab(context),
          },
        ],
      ),
    );
  }

  String _categoryName(String id) =>
      widget.categories.where((category) => category.id == id).firstOrNull?.name ??
      id;

  Widget _saveBar(BuildContext context) => Row(
        children: [
          if (saveError != null)
            Expanded(
              child: Text(
                saveError!,
                key: const Key('codex-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          else
            const Spacer(),
          TextButton(
            key: const Key('codex-discard-button'),
            onPressed: dirty ? _discard : null,
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const Key('codex-save-entry-button'),
            onPressed: dirty ? _save : null,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save'),
          ),
        ],
      );

  Widget _overviewTab(BuildContext context) {
    final issues = [
      ...?widget.validation?.issues,
      ...saveIssues,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (issues.isNotEmpty) ...[
          _CodexValidationPanel(
            key: const Key('codex-validation-panel'),
            issues: issues,
            templateReport: widget.templateReport,
          ),
          const SizedBox(height: 16),
        ],
        _sectionTitle(context, 'Identity'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('codex-title-input'),
          controller: controllers[_titleKey],
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('codex-summary-input'),
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
          key: const Key('codex-content-input'),
          controller: controllers[_contentKey],
          minLines: 4,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Content',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('codex-aliases-input'),
          controller: controllers[_aliasesKey],
          decoration: const InputDecoration(
            labelText: 'Aliases',
            helperText: 'Comma separated. Aliases stay searchable.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('codex-tags-input'),
          controller: controllers[_tagsKey],
          decoration: const InputDecoration(
            labelText: 'Tags',
            helperText: 'Comma separated.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(context, 'Canon and knowledge'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('codex-category-input'),
          initialValue: categoryId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final category
                in widget.categories.where((category) => !category.archived))
              DropdownMenuItem(value: category.id, child: Text(category.name)),
          ],
          onChanged: widget.activeBranchId != null
              ? null
              : (value) => setState(() {
                    categoryId = value ?? categoryId;
                    dirty = true;
                  }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CodexCanonStatus>(
          key: const Key('codex-canon-status-field'),
          initialValue: canonStatus,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Canon state',
            border: const OutlineInputBorder(),
            helperText: widget.activeBranchId == null
                ? 'Canon state is saved with the entry.'
                : 'Canon cannot be changed from a branch.',
          ),
          items: [
            for (final status in CodexCanonStatus.values)
              DropdownMenuItem(
                value: status,
                child: Text(codexCanonStatusLabel(status)),
              ),
          ],
          onChanged: widget.activeBranchId != null
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => canonStatus = value);
                  _setCanonStatus(value);
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CodexKnowledgeStatus>(
          key: const Key('codex-knowledge-status-field'),
          initialValue: knowledgeStatus,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Knowledge status',
            border: OutlineInputBorder(),
            helperText: 'How certain this knowledge is inside the story.',
          ),
          items: [
            for (final status in CodexKnowledgeStatus.values)
              DropdownMenuItem(
                value: status,
                child: Text(codexKnowledgeStatusLabel(status)),
              ),
          ],
          onChanged: (value) => setState(() {
            knowledgeStatus = value ?? knowledgeStatus;
            dirty = true;
          }),
        ),
        const SizedBox(height: 16),
        _saveBar(context),
      ],
    );
  }

  Widget _fieldsTab(BuildContext context) {
    final definition = template;
    final deep = widget.editorMode == CodexEditorMode.deep;
    final fields = _editableFields();
    final unknown = _unknownFieldKeys();
    final labels = _customFieldLabels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<CodexEditorMode>(
                key: const Key('codex-editor-mode-selector'),
                segments: const [
                  ButtonSegment(
                    value: CodexEditorMode.simple,
                    icon: Icon(Icons.short_text_rounded),
                    label: Text('Simple'),
                  ),
                  ButtonSegment(
                    value: CodexEditorMode.deep,
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
                key: const Key('codex-add-custom-field-button'),
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
              : 'The fields most entries need. Switch to Deep for everything.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        if (definition == null)
          _CodexBanner(
            key: const Key('codex-missing-template-banner'),
            icon: Icons.help_outline,
            message:
                'The ${widget.entry.templateId} template is not installed. '
                'Stored values are shown below and are preserved on save.',
          )
        else
          for (final section in _sectionsFor(definition, fields, deep))
            _CodexFieldSection(
              key: Key('codex-section-${section.id}'),
              title: section.title,
              children: [
                for (final field in section.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _fieldEditor(context, field, deep),
                  ),
              ],
            ),
        if (deep && unknown.isNotEmpty)
          _CodexFieldSection(
            key: const Key('codex-section-additional'),
            title: 'Additional fields',
            children: [
              for (final key in unknown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    key: Key('codex-field-$key'),
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

  List<_ResolvedSection> _sectionsFor(
    RecordTypeDefinition definition,
    List<RecordFieldDefinition> fields,
    bool deep,
  ) {
    final byId = {for (final field in fields) field.id: field};
    final sections = <_ResolvedSection>[];
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
      sections.add(_ResolvedSection(section.id, section.title, sectionFields));
    }
    final loose = fields
        .where((field) => !used.contains(field.id))
        .where((field) => deep || _isSimpleField(field))
        .toList();
    if (loose.isNotEmpty) {
      sections.add(_ResolvedSection('other', 'Other details', loose));
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

  Widget _fieldEditor(
    BuildContext context,
    RecordFieldDefinition field,
    bool deep,
  ) {
    final label = field.required ? '${field.label} *' : field.label;
    final visibility = widget.entry.visibilityFor(field.id);
    Widget editor;
    switch (field.type) {
      case RecordFieldType.boolean:
        editor = SwitchListTile(
          key: Key('codex-field-${field.id}'),
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
        editor = DropdownButtonFormField<String>(
          key: Key('codex-field-${field.id}'),
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
        editor = TextField(
          key: Key('codex-field-${field.id}'),
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
        editor = TextField(
          key: Key('codex-field-${field.id}'),
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
        editor = InputDecorator(
          key: Key('codex-field-${field.id}'),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            helperText: 'Table values are preserved and edited elsewhere.',
          ),
          child: Text(
            _displayValue(widget.entry.structuredFields[field.id]),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      default:
        final multiline = field.type == RecordFieldType.longText ||
            field.type == RecordFieldType.richText;
        editor = TextField(
          key: Key('codex-field-${field.id}'),
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
    if (!deep) return editor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        editor,
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<CodexFieldVisibility>(
            key: Key('codex-visibility-${field.id}'),
            tooltip: 'Knowledge visibility',
            onSelected: (value) => _setVisibility(field.id, value),
            itemBuilder: (context) => [
              for (final value in CodexFieldVisibility.values)
                PopupMenuItem(
                  value: value,
                  child: Text(codexVisibilityLabel(value)),
                ),
            ],
            child: Chip(
              avatar: const Icon(Icons.shield_outlined, size: 14),
              label: Text(codexVisibilityLabel(visibility)),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _relationshipsTab(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _sectionTitle(context, 'Relationships')),
              FilledButton.tonalIcon(
                key: const Key('codex-add-relationship-button'),
                onPressed: _addRelationship,
                icon: const Icon(Icons.add_link_rounded, size: 18),
                label: const Text('Connect'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_CodexRelationshipView>>(
            future: relationships,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _CodexInlineLoader();
              }
              final values =
                  snapshot.data ?? const <_CodexRelationshipView>[];
              if (values.isEmpty) {
                return const _CodexMessage(
                  key: Key('codex-relationships-empty-state'),
                  icon: Icons.hub_outlined,
                  title: 'No relationships yet',
                  message:
                      'Connect this entry to characters, places, plot threads '
                      'or manuscript records to build the story graph.',
                );
              }
              return Column(
                children: [
                  for (final view in values)
                    _CodexRelationshipTile(
                      key: Key('codex-relationship-${view.link.id}'),
                      view: view,
                      onOpen: (record) {
                        // Knowledge records open in place; a record another
                        // Studio owns hands off to that Studio instead, so the
                        // Codex never becomes a second editor for it.
                        final destination =
                            searchDestinationForType(record.typeId);
                        final ownedHere =
                            destination == SearchDestination.storyCodex ||
                                destination == SearchDestination.record;
                        if (ownedHere &&
                            widget.entries
                                .any((entry) => entry.id == record.id)) {
                          widget.onOpenEntry(record.id);
                          return;
                        }
                        widget.onNavigateNode(record);
                      },
                      onEdit: () => _editRelationship(view.link),
                      onRemove: () => _removeRelationship(view.link),
                    ),
                ],
              );
            },
          ),
        ],
      );

  Widget _sourcesTab(BuildContext context) {
    final sources = widget.entry.sources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle(context, 'Sources and references')),
            FilledButton.tonalIcon(
              key: const Key('codex-add-source-button'),
              onPressed: _addSource,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('Add source'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sources.isEmpty)
          const _CodexMessage(
            key: Key('codex-sources-empty-state'),
            icon: Icons.menu_book_outlined,
            title: 'No sources recorded',
            message:
                'Record where this knowledge comes from: a scene, a chapter, '
                'research, or an external reference.',
          )
        else
          for (final source in sources)
            Card(
              key: Key('codex-source-${source.stableId}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(source.displayLabel),
                subtitle: Text([
                  source.kind,
                  if (source.location.isNotEmpty) source.location,
                  if (source.notes.isNotEmpty) source.notes,
                ].join(' · ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('codex-edit-source-${source.stableId}'),
                      tooltip: 'Edit source',
                      onPressed: () => _editSource(source),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      key: Key('codex-remove-source-${source.stableId}'),
                      tooltip: 'Remove source',
                      onPressed: () => _removeSource(source),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _continuityTab(BuildContext context) => FutureBuilder<
          CodexContinuityReport>(
        future: continuityReport,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CodexInlineLoader();
          }
          final report = snapshot.data ?? CodexContinuityReport.empty;
          if (report.isClean) {
            return const _CodexMessage(
              key: Key('codex-continuity-clean-state'),
              icon: Icons.verified_outlined,
              title: 'No continuity recommendations',
              message:
                  'Every name this entry mentions has a record, and every '
                  'mention is connected.',
            );
          }
          return Column(
            key: const Key('codex-continuity-panel'),
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
                _CodexContinuityTile(
                  key: Key('codex-continuity-issue-$index'),
                  issue: report.summary.issues[index],
                  actionLabel: switch (report.findings[index].actionKind) {
                    ContinuityActionKind.create => 'Create record',
                    ContinuityActionKind.link => 'Create link',
                    ContinuityActionKind.review => 'Review entry',
                  },
                  actionKey: Key('codex-continuity-resolve-$index'),
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
            return const _CodexInlineLoader();
          }
          final data = snapshot.data;
          if (data == null) {
            return const _CodexMessage(
              key: Key('codex-inspector-empty-state'),
              icon: Icons.travel_explore_outlined,
              title: 'Inspection unavailable',
              message: 'This record is not visible in the current scope.',
            );
          }
          return Column(
            key: const Key('codex-inspector-panel'),
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
                    onOpen: () => widget.onOpenInGraph(widget.entry.record),
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
              _kv(context, 'Canon state', data.canonStatus.name),
              _kv(context, 'Lifecycle', data.lifecycleStatus.name),
              _kv(context, 'Branch state', data.scope.branchState.name),
              _kv(context, 'Visible in scope', data.scope.visible ? 'Yes' : 'No'),
              _kv(context, 'Validation', data.validation.state.name),
              _kv(context, 'Connections',
                  '${data.outgoingConnections.length} out · '
                      '${data.incomingConnections.length} in'),
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

  Widget _historyTab(BuildContext context) => FutureBuilder<List<RecordVersion>>(
        future: history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _CodexInlineLoader();
          }
          final versions = snapshot.data ?? const <RecordVersion>[];
          if (versions.isEmpty) {
            return const _CodexMessage(
              key: Key('codex-history-empty-state'),
              icon: Icons.history_toggle_off_outlined,
              title: 'No history yet',
              message: 'Saved changes appear here as versions you can restore.',
            );
          }
          return Column(
            key: const Key('codex-history-panel'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(context, 'Version history'),
              const SizedBox(height: 12),
              for (final version in versions)
                Card(
                  key: Key('codex-history-${version.id}'),
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
                            key: Key('codex-restore-version-${version.id}'),
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
              child: Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
            ),
            Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      );
}

class _ResolvedSection {
  const _ResolvedSection(this.id, this.title, this.fields);

  final String id;
  final String title;
  final List<RecordFieldDefinition> fields;
}

// ---------------------------------------------------------------------------
// Relationship tile
// ---------------------------------------------------------------------------

/// One connection plus the record on its far end.
class _CodexRelationshipView {
  const _CodexRelationshipView({
    required this.link,
    required this.other,
    required this.otherId,
  });

  final RecordLink link;
  final StoryGraphNode? other;
  final String otherId;
}

class _CodexRelationshipTile extends StatelessWidget {
  const _CodexRelationshipTile({
    super.key,
    required this.view,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
  });

  final _CodexRelationshipView view;
  final ValueChanged<StoryGraphNode> onOpen;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final link = view.link;
    final record = view.other;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.hub_outlined),
        title: Text(record?.title ?? view.otherId),
        subtitle: Text(
          '${link.label.isEmpty ? link.typeId : link.label}'
          '${record == null ? ' · record unavailable' : ' · ${record.typeId}'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (record != null)
              IconButton(
                key: Key('codex-open-relationship-${link.id}'),
                tooltip: 'Open connected record',
                onPressed: () => onOpen(record),
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            IconButton(
              key: Key('codex-edit-relationship-${link.id}'),
              tooltip: 'Change connection type',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              key: Key('codex-remove-relationship-${link.id}'),
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
// Dialogs
// ---------------------------------------------------------------------------

class _CodexCreateDialog extends StatefulWidget {
  const _CodexCreateDialog({
    required this.templates,
    required this.categories,
    required this.onBranch,
    required this.registry,
    required this.service,
  });

  final List<RecordTypeDefinition> templates;
  final List<CodexCategory> categories;
  final bool onBranch;
  final RecordTypeRegistry? registry;
  final StoryCodexService service;

  @override
  State<_CodexCreateDialog> createState() => _CodexCreateDialogState();
}

class _CodexCreateDialogState extends State<_CodexCreateDialog> {
  final titleController = TextEditingController();
  final summaryController = TextEditingController();
  final contentController = TextEditingController();
  final fieldControllers = <String, TextEditingController>{};

  late String templateId;
  late String categoryId;
  CodexCanonStatus canonStatus = CodexCanonStatus.draft;
  CodexEditorMode mode = CodexEditorMode.simple;
  String? error;

  RecordTypeDefinition get template =>
      widget.templates.firstWhere((item) => item.id == templateId);

  @override
  void initState() {
    super.initState();
    templateId = widget.templates.first.id;
    categoryId = _categoryForTemplate(template);
    _syncControllers();
  }

  String _categoryForTemplate(RecordTypeDefinition definition) =>
      widget.categories.any((item) => item.id == definition.categoryId)
          ? definition.categoryId
          : widget.categories.first.id;

  void _syncControllers() {
    for (final field in template.fields) {
      if (_isCoreFieldId(field.id)) continue;
      fieldControllers.putIfAbsent(
        field.id,
        () => TextEditingController(text: _displayValue(field.defaultValue)),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    contentController.dispose();
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => error = 'A title is required.');
      return;
    }
    final missing = template.fields
        .where((field) => field.required && !_isCoreFieldId(field.id))
        .where((field) =>
            (fieldControllers[field.id]?.text ?? '').trim().isEmpty)
        .toList();
    if (missing.isNotEmpty) {
      setState(() {
        mode = CodexEditorMode.deep;
        error = '${missing.map((field) => field.label).join(', ')} '
            '${missing.length == 1 ? 'is' : 'are'} required.';
      });
      return;
    }
    Navigator.pop(
      context,
      CodexEntryDraft(
        title: title,
        templateId: templateId,
        categoryId: categoryId,
        summary: summaryController.text.trim(),
        content: contentController.text.trim(),
        canonStatus: canonStatus,
        structuredFields: {
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
    final deep = mode == CodexEditorMode.deep;
    return AlertDialog(
      key: const Key('codex-create-dialog'),
      title: const Text('New Codex entry'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<CodexEditorMode>(
                key: const Key('codex-create-mode-selector'),
                segments: const [
                  ButtonSegment(
                    value: CodexEditorMode.simple,
                    label: Text('Simple'),
                  ),
                  ButtonSegment(
                    value: CodexEditorMode.deep,
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
                key: const Key('codex-create-template-field'),
                initialValue: templateId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Template',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in widget.templates)
                    DropdownMenuItem(
                      key: Key('codex-create-template-option-${item.id}'),
                      value: item.id,
                      child: Text(item.name),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    templateId = value;
                    categoryId = _categoryForTemplate(template);
                    _syncControllers();
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('codex-create-category-field'),
                initialValue: categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item
                      in widget.categories.where((item) => !item.archived))
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) =>
                    setState(() => categoryId = value ?? categoryId),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('codex-create-title-field'),
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('codex-create-summary-field'),
                controller: summaryController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  border: OutlineInputBorder(),
                ),
              ),
              if (deep) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-create-content-field'),
                  controller: contentController,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CodexCanonStatus>(
                  key: const Key('codex-create-canon-field'),
                  initialValue: canonStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Canon state',
                    border: const OutlineInputBorder(),
                    helperText: widget.onBranch
                        ? 'Branch entries can never be Canon.'
                        : null,
                  ),
                  items: [
                    for (final status in CodexCanonStatus.values)
                      if (!widget.onBranch || status != CodexCanonStatus.canon)
                        DropdownMenuItem(
                          value: status,
                          child: Text(codexCanonStatusLabel(status)),
                        ),
                  ],
                  onChanged: (value) =>
                      setState(() => canonStatus = value ?? canonStatus),
                ),
                for (final section in template.sections.toList()
                  ..sort((left, right) => left.order.compareTo(right.order)))
                  ..._sectionFields(context, section),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  key: const Key('codex-create-error'),
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
          key: const Key('codex-create-confirm'),
          onPressed: _submit,
          child: const Text('Create entry'),
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
          key: Key('codex-create-field-${field.id}'),
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

class _RelationshipChoice {
  const _RelationshipChoice(this.targetId, this.typeId);

  final String targetId;
  final String typeId;
}

class _CodexRelationshipDialog extends StatefulWidget {
  const _CodexRelationshipDialog({
    required this.service,
    required this.sourceTypeId,
    required this.targets,
  });

  final StoryCodexService service;
  final String sourceTypeId;
  final List<AuthorRecord> targets;

  @override
  State<_CodexRelationshipDialog> createState() =>
      _CodexRelationshipDialogState();
}

class _CodexRelationshipDialogState extends State<_CodexRelationshipDialog> {
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
        key: const Key('codex-relationship-dialog'),
        title: const Text('Connect this entry'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('codex-relationship-target-field'),
                initialValue: targetId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Record',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final record in widget.targets)
                    DropdownMenuItem(
                      key: Key('codex-relationship-target-${record.id}'),
                      value: record.id,
                      child: Text('${record.title} · ${record.typeId}',
                          overflow: TextOverflow.ellipsis),
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
                const _CodexInlineLoader()
              else if (definitions.isEmpty)
                const Text(
                  'No connection type allows these two record types. Pick a '
                  'different record.',
                )
              else
                DropdownButtonFormField<String>(
                  key: const Key('codex-relationship-type-field'),
                  initialValue: typeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Connection type',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final definition in definitions)
                      DropdownMenuItem(
                        key: Key('codex-relationship-type-${definition.id}'),
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
            key: const Key('codex-relationship-confirm'),
            onPressed: typeId == null
                ? null
                : () => Navigator.pop(
                      context,
                      _RelationshipChoice(targetId, typeId!),
                    ),
            child: const Text('Connect'),
          ),
        ],
      );
}

class _CodexRelationshipTypeDialog extends StatefulWidget {
  const _CodexRelationshipTypeDialog({
    required this.definitions,
    required this.initialTypeId,
  });

  final List<ConnectionTypeDefinition> definitions;
  final String initialTypeId;

  @override
  State<_CodexRelationshipTypeDialog> createState() =>
      _CodexRelationshipTypeDialogState();
}

class _CodexRelationshipTypeDialogState
    extends State<_CodexRelationshipTypeDialog> {
  late String typeId = widget.definitions.any(
    (definition) => definition.id == widget.initialTypeId,
  )
      ? widget.initialTypeId
      : widget.definitions.first.id;

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('codex-relationship-type-dialog'),
        title: const Text('Change connection type'),
        content: SizedBox(
          width: 420,
          child: DropdownButtonFormField<String>(
            key: const Key('codex-relationship-edit-type-field'),
            initialValue: typeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Connection type',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final definition in widget.definitions)
                DropdownMenuItem(
                  value: definition.id,
                  child: Text(definition.displayName),
                ),
            ],
            onChanged: (value) => setState(() => typeId = value ?? typeId),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('codex-relationship-type-confirm'),
            onPressed: () => Navigator.pop(context, typeId),
            child: const Text('Update'),
          ),
        ],
      );
}

class _CodexSourceDialog extends StatefulWidget {
  const _CodexSourceDialog({this.existing});

  final CodexSourceReference? existing;

  @override
  State<_CodexSourceDialog> createState() => _CodexSourceDialogState();
}

class _CodexSourceDialogState extends State<_CodexSourceDialog> {
  late final labelController =
      TextEditingController(text: widget.existing?.label ?? '');
  late final locationController =
      TextEditingController(text: widget.existing?.location ?? '');
  late final notesController =
      TextEditingController(text: widget.existing?.notes ?? '');
  late final recordController =
      TextEditingController(text: widget.existing?.recordId ?? '');
  late String kind = widget.existing?.kind ?? codexSourceKinds.last;
  String? error;

  @override
  void dispose() {
    labelController.dispose();
    locationController.dispose();
    notesController.dispose();
    recordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('codex-source-dialog'),
        title: Text(widget.existing == null ? 'Add source' : 'Edit source'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('codex-source-kind-field'),
                  initialValue: kind,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Source kind',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final value in codexSourceKinds)
                      DropdownMenuItem(value: value, child: Text(value)),
                  ],
                  onChanged: (value) => setState(() => kind = value ?? kind),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-source-label-field'),
                  controller: labelController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-source-location-field'),
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    helperText: 'Chapter, page, URL, or timestamp.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-source-record-field'),
                  controller: recordController,
                  decoration: const InputDecoration(
                    labelText: 'Record id (optional)',
                    helperText: 'Link this source to a Universal Record.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('codex-source-notes-field'),
                  controller: notesController,
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
            key: const Key('codex-source-confirm'),
            onPressed: () {
              if (labelController.text.trim().isEmpty &&
                  recordController.text.trim().isEmpty) {
                setState(() => error = 'Add a label or a record id.');
                return;
              }
              Navigator.pop(
                context,
                CodexSourceReference(
                  id: widget.existing?.stableId ?? '',
                  recordId: recordController.text.trim(),
                  kind: kind,
                  label: labelController.text.trim(),
                  location: locationController.text.trim(),
                  notes: notesController.text.trim(),
                ),
              );
            },
            child: const Text('Save source'),
          ),
        ],
      );
}

class _CodexCustomFieldDialog extends StatefulWidget {
  const _CodexCustomFieldDialog();

  @override
  State<_CodexCustomFieldDialog> createState() =>
      _CodexCustomFieldDialogState();
}

class _CodexCustomFieldDialogState extends State<_CodexCustomFieldDialog> {
  final labelController = TextEditingController();
  String? error;

  @override
  void dispose() {
    labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('codex-custom-field-dialog'),
        title: const Text('Add a custom field'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('codex-custom-field-label'),
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Field name',
                  helperText: 'Stored on this entry alongside template fields.',
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
            key: const Key('codex-custom-field-confirm'),
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

class _CodexNameDialog extends StatefulWidget {
  const _CodexNameDialog({
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
  State<_CodexNameDialog> createState() => _CodexNameDialogState();
}

class _CodexNameDialogState extends State<_CodexNameDialog> {
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

class _CodexCard extends StatelessWidget {
  const _CodexCard({super.key, required this.child});

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

class _CodexMessage extends StatelessWidget {
  const _CodexMessage({
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 34, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonal(
                key: const Key('codex-message-action'),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
}

class _CodexBanner extends StatelessWidget {
  const _CodexBanner({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodexFieldSection extends StatelessWidget {
  const _CodexFieldSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      );
}

class _CodexValidationPanel extends StatelessWidget {
  const _CodexValidationPanel({
    super.key,
    required this.issues,
    required this.templateReport,
  });

  final List<RecordValidationIssue> issues;
  final TemplateCompatibilityReport? templateReport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError =
        issues.any((issue) => issue.severity == RecordValidationSeverity.error);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasError ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasError ? Icons.error_outline : Icons.warning_amber_rounded,
                size: 18,
                color: hasError ? scheme.onErrorContainer : scheme.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                hasError
                    ? 'This entry has validation errors'
                    : 'This entry has validation warnings',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          hasError ? scheme.onErrorContainer : scheme.onSurface,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${issue.message}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasError
                          ? scheme.onErrorContainer
                          : scheme.onSurface,
                    ),
              ),
            ),
          if (templateReport != null &&
              templateReport!.status ==
                  TemplateCompatibilityStatus.upgradeAvailable)
            Text(
              '• Template ${templateReport!.templateId} has version '
              '${templateReport!.availableVersion}; this entry is on '
              '${templateReport!.recordVersion}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _CodexContinuityTile extends StatelessWidget {
  const _CodexContinuityTile({
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
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    switch (issue.severity) {
                      ContinuitySeverity.critical => Icons.error_outline,
                      ContinuitySeverity.warning => Icons.warning_amber_rounded,
                      ContinuitySeverity.notice => Icons.info_outline,
                    },
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      issue.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(issue.message,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(
                issue.recommendation,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
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

class _CodexSaveIndicator extends StatelessWidget {
  const _CodexSaveIndicator({
    super.key,
    required this.state,
    required this.message,
  });

  final CodexSaveState state;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, fallback) = switch (state) {
      CodexSaveState.saving => (
          Icons.sync_rounded,
          scheme.primary,
          'Saving…',
        ),
      CodexSaveState.saved => (
          Icons.cloud_done_outlined,
          scheme.primary,
          'All changes saved',
        ),
      CodexSaveState.failed => (
          Icons.error_outline,
          scheme.error,
          'Could not save',
        ),
      CodexSaveState.idle => (
          Icons.edit_note_outlined,
          scheme.outline,
          'No pending changes',
        ),
    };
    return Row(
      key: const Key('codex-save-state'),
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

class _CodexInlineLoader extends StatelessWidget {
  const _CodexInlineLoader();

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

/// Fields the workspace edits through dedicated controls rather than as
/// generic template fields.
const _codexCoreFieldIds = <String>{
  'name',
  'summary',
  'description',
  CodexFields.aliases,
  CodexFields.knowledgeStatus,
  CodexFields.sources,
};

bool _isCoreFieldId(String id) => _codexCoreFieldIds.contains(id);

String _displayValue(Object? value) {
  if (value == null) return '';
  if (value is List) return value.map((item) => '$item').join(', ');
  return '$value';
}

List<String> _splitList(String raw) => raw
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();

/// Keeps an existing value's shape when a free-text editor writes it back.
Object? _coerceLike(Object? existing, String text) {
  if (existing is List) return _splitList(text);
  if (existing is num) return num.tryParse(text.trim()) ?? text;
  if (existing is bool) return text.trim().toLowerCase() == 'true';
  return text;
}

Object? _coerceForField(RecordFieldDefinition field, String text) =>
    switch (field.type) {
      RecordFieldType.number ||
      RecordFieldType.rating =>
        num.tryParse(text.trim()) ?? text.trim(),
      RecordFieldType.boolean => text.trim().toLowerCase() == 'true',
      RecordFieldType.multipleChoice ||
      RecordFieldType.tags ||
      RecordFieldType.list ||
      RecordFieldType.checklist =>
        _splitList(text),
      _ => text.trim(),
    };

String _fieldKey(String label) {
  final slug = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-+|-+$)'), '');
  return 'custom.${slug.isEmpty ? 'field' : slug}';
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _readableError(Object error) {
  if (error is RecordValidationException) {
    return error.result.errors.map((issue) => issue.message).join(' ');
  }
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  return error.toString();
}
