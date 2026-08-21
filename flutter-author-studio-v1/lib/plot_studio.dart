import 'package:flutter/material.dart';

import 'core/connected_domain.dart';
import 'core/plot_record_types.dart';
import 'core/record_types.dart';
import 'core/safe_delete.dart';
import 'persistence/authoros_database.dart';
import 'plot_service.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

/// The writer-facing Plot Studio.
///
/// Every read and write goes through [PlotService], which composes
/// `RecordService`, `RecordTypeRegistry`, `TemplateEngine`, `ConnectionEngine`,
/// `BranchService`, `UniversalSearchService`, `UniversalRecordInspector`,
/// `VersionAuditService` and `SafeDeleteService`. The view owns no store,
/// index, history or type list of its own: Plot data stays a Universal Record
/// and the Plot catalogue stays data-driven.
///
/// Colour and type come from the Theme Engine. The view re-scopes the
/// inherited [StudioThemeScope] to [StudioId.plot] so Plot token overrides
/// apply to this subtree, and reads Material roles through `Theme.of`. It
/// builds no `ThemeData` and hard-codes no palette.
class PlotStudioView extends StatefulWidget {
  const PlotStudioView({
    super.key,
    required this.projectId,
    this.repository,
  });

  final String projectId;

  /// Injected by tests. The app uses the shared [authorOsRepository] so Plot
  /// records live in the same database as every other Universal Record.
  final DriftConnectedDomainRepository? repository;

  @override
  State<PlotStudioView> createState() => _PlotStudioViewState();
}

/// The "every type" sentinel for the type filter.
const _allTypes = '__all__';

class _PlotStudioViewState extends State<PlotStudioView> {
  final searchController = TextEditingController();
  late final PlotService plot;

  List<AuthorRecord> records = const [];
  List<RecordTypeDefinition> templates = const [];
  List<PlotValidationIssue> issues = const [];

  bool loading = true;
  bool busy = false;
  String? loadError;
  String typeFilter = _allTypes;
  bool showArchived = false;

  @override
  void initState() {
    super.initState();
    plot = PlotService(
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

  Future<void> _load() async {
    try {
      final loaded = await plot.query.all();
      final catalogue = await plot.plotTemplates();
      final warnings = await plot.validatePlot();
      if (!mounted) return;
      setState(() {
        records = loaded;
        templates = catalogue;
        issues = warnings;
        loading = false;
        loadError = null;
        if (typeFilter != _allTypes &&
            !catalogue.any((template) => template.id == typeFilter)) {
          typeFilter = _allTypes;
        }
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = '$caught';
      });
    }
  }

  /// Resolved definition for [record], or `null` when its type was removed.
  RecordTypeDefinition? _templateFor(AuthorRecord record) =>
      templates.where((template) => template.id == record.typeId).firstOrNull;

  String _typeLabel(AuthorRecord record) =>
      _templateFor(record)?.name ?? record.typeId;

  List<AuthorRecord> get _visible {
    final query = searchController.text.trim().toLowerCase();
    return records.where((record) {
      if (!showArchived && record.status != AuthorRecordStatus.active) {
        return false;
      }
      if (typeFilter != _allTypes && record.typeId != typeFilter) return false;
      if (query.isEmpty) return true;
      return [
        record.title,
        _typeLabel(record),
        ...record.tags,
        ...record.fields.values.map((value) => value ?? ''),
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  /// Runs [action] with the busy latch held, reloads, and reports failures.
  ///
  /// Service errors surface as a message rather than an exception: creative
  /// validation in Plot Studio is warning-only and must never lose the writer's
  /// place in the board.
  Future<void> _mutate(Future<void> Function() action, String failure) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await _load();
    } catch (caught) {
      if (mounted) _report('$failure $caught');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _report(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _create() async {
    if (templates.isEmpty) return;
    final draft = await showDialog<_PlotDraft>(
      context: context,
      builder: (context) => _PlotRecordDialog(
        templates: templates,
        initialTypeId: typeFilter == _allTypes ? null : typeFilter,
      ),
    );
    if (draft == null) return;
    await _mutate(
      () => plot.createPlotRecord(
        PlotRecordDraft(
          id: _newPlotId(draft.typeId, draft.name),
          typeId: draft.typeId,
          name: draft.name,
          fields: draft.fields,
          tags: draft.tags,
        ),
      ),
      'Could not create this Plot record:',
    );
  }

  Future<void> _edit(AuthorRecord record) async {
    final template = _templateFor(record);
    if (template == null) return;
    final draft = await showDialog<_PlotDraft>(
      context: context,
      builder: (context) => _PlotRecordDialog(
        templates: templates,
        existing: record,
        initialTypeId: record.typeId,
      ),
    );
    if (draft == null) return;
    await _mutate(
      () => plot.updatePlotRecord(
        record.copyWith(
          title: draft.name,
          // The record keeps every field the template does not edit, so a
          // Phase 1 editor never truncates data written by the fixture, an
          // import, or a later Plot surface.
          fields: {
            ...record.fields,
            ...draft.fields,
            'name': draft.name,
          },
          tags: draft.tags,
          updatedAt: DateTime.now().toUtc(),
        ),
      ),
      'Could not save this Plot record:',
    );
  }

  Future<void> _duplicate(AuthorRecord record) => _mutate(
        () => plot.duplicatePlotRecord(
          record.id,
          newId: _newPlotId(record.typeId, record.title),
          title: '${record.title} copy',
        ),
        'Could not duplicate this Plot record:',
      );

  Future<void> _restore(AuthorRecord record) => _mutate(
        () => plot.restorePlotRecord(record.id),
        'Could not restore this Plot record:',
      );

  /// Archives [record] after showing what the shared safe-delete analysis found.
  ///
  /// Deletion stays non-physical and stays in the service layer: the view asks
  /// [PlotService.analyzeDelete] what depends on the record and then calls
  /// [PlotService.archivePlotRecord]. It never touches the database.
  Future<void> _delete(AuthorRecord record) async {
    SafeDeleteAnalysis? analysis;
    try {
      analysis = await plot.analyzeDelete(record.id);
    } catch (caught) {
      if (!mounted) return;
      _report('Could not analyse this Plot record: $caught');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _PlotDeleteDialog(
        record: record,
        typeLabel: _typeLabel(record),
        analysis: analysis,
      ),
    );
    if (confirmed != true) return;
    await _mutate(
      () => plot.archivePlotRecord(record.id),
      'Could not archive this Plot record:',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    final content = _buildContent(context);
    // Re-scope to the Plot Studio so its token overrides reach this subtree.
    // Outside the shell — a widget test, a preview — there is no scope to
    // inherit and Material's own theme is the whole story.
    if (scope == null) return content;
    return StudioThemeScope(
      theme: scope.theme,
      studio: StudioId.plot,
      child: content,
    );
  }

  Widget _buildContent(BuildContext context) {
    if (loading) {
      return const Padding(
        key: Key('plot-loading'),
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final error = loadError;
    if (error != null) {
      return Padding(
        key: const Key('plot-error-state'),
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 42, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('Plot Studio could not load.',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(error, style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('plot-retry-button'),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final visible = _visible;
    return Material(
      key: const Key('plot-studio-view'),
      type: MaterialType.transparency,
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
                      'Plot Studio',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Shape the acts, plotlines, arcs, and beats the story '
                      'turns on.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                key: const Key('plot-new-record-button'),
                onPressed: busy || templates.isEmpty ? null : _create,
                icon: const Icon(Icons.add_rounded),
                label: const Text('New plot record'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _PlotOverview(records: records, issues: issues),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 18),
            _PlotValidationPanel(issues: issues),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                key: const Key('plot-search-field'),
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  labelText: 'Search plot records',
                ),
              );
              final filter = DropdownButtonFormField<String>(
                key: const Key('plot-type-filter'),
                initialValue: typeFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  const DropdownMenuItem(
                    value: _allTypes,
                    child: Text('All types', overflow: TextOverflow.ellipsis),
                  ),
                  ...templates.map(
                    (template) => DropdownMenuItem(
                      value: template.id,
                      child: Text(
                        template.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => typeFilter = value ?? _allTypes),
              );
              if (constraints.maxWidth < 640) {
                return Column(
                  children: [search, const SizedBox(height: 10), filter],
                );
              }
              return Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  SizedBox(width: 230, child: filter),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              key: const Key('plot-archived-toggle'),
              selected: showArchived,
              onSelected: (value) => setState(() => showArchived = value),
              avatar: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text('Show archived'),
            ),
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            _PlotEmptyState(
              hasRecords: records.isNotEmpty,
              canCreate: templates.isNotEmpty,
              onCreate: _create,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1100
                    ? 3
                    : width >= 680
                        ? 2
                        : 1;
                final itemWidth = (width - ((columns - 1) * 12)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: visible
                      .map(
                        (record) => SizedBox(
                          width: itemWidth,
                          child: _PlotRecordTile(
                            record: record,
                            typeLabel: _typeLabel(record),
                            icon: _templateFor(record)?.icon ?? 'account_tree',
                            enabled: !busy,
                            onEdit: () => _edit(record),
                            onDuplicate: () => _duplicate(record),
                            onArchive: () => _delete(record),
                            onRestore: () => _restore(record),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A counts strip over the whole Plot, so the board reads at a glance.
class _PlotOverview extends StatelessWidget {
  const _PlotOverview({required this.records, required this.issues});

  final List<AuthorRecord> records;
  final List<PlotValidationIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = records
        .where((record) => record.status == AuthorRecordStatus.active)
        .length;
    final beats = records
        .where((record) => record.typeId == PlotRecordTypes.beatTypeId)
        .length;
    final entries = <(String, String)>[
      ('Plot records', '$active'),
      ('Beats', '$beats'),
      ('Warnings', '${issues.length}'),
    ];
    return Wrap(
      key: const Key('plot-overview'),
      spacing: 12,
      runSpacing: 12,
      children: entries
          .map(
            (entry) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.$2,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(entry.$1, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Warning-only creative validation, surfaced without blocking authoring.
class _PlotValidationPanel extends StatelessWidget {
  const _PlotValidationPanel({required this.issues});

  final List<PlotValidationIssue> issues;

  static const _shown = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errors = issues.where((issue) => issue.isError).length;
    return Container(
      key: const Key('plot-validation-panel'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                errors > 0 ? Icons.error_outline : Icons.info_outline,
                size: 20,
                color: errors > 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errors > 0
                      ? '${issues.length} plot notes, $errors need attention'
                      : '${issues.length} plot notes',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'These are creative prompts, not errors. Nothing here blocks '
            'writing or saving.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          ...issues.take(_shown).map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• ${issue.message}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
          if (issues.length > _shown)
            Text(
              'and ${issues.length - _shown} more.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _PlotRecordTile extends StatelessWidget {
  const _PlotRecordTile({
    required this.record,
    required this.typeLabel,
    required this.icon,
    required this.enabled,
    required this.onEdit,
    required this.onDuplicate,
    required this.onArchive,
    required this.onRestore,
  });

  final AuthorRecord record;
  final String typeLabel;
  final String icon;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final archived = record.status != AuthorRecordStatus.active;
    final purpose = record.fields['purpose']?.toString() ?? '';
    final status = record.fields['plotStatus']?.toString() ?? '';
    return Material(
      key: Key('plot-record-tile-${record.id}'),
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled && !archived ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_plotIcon(icon), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: Key('plot-record-menu-${record.id}'),
                    tooltip: 'Plot record actions',
                    enabled: enabled,
                    onSelected: (value) => switch (value) {
                      'edit' => onEdit(),
                      'duplicate' => onDuplicate(),
                      'restore' => onRestore(),
                      _ => onArchive(),
                    },
                    itemBuilder: (context) => [
                      if (!archived)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit record'),
                        ),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicate'),
                      ),
                      if (archived)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Restore'),
                        )
                      else
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Delete'),
                        ),
                    ],
                  ),
                ],
              ),
              Text(
                [
                  typeLabel,
                  record.canonStatus.name,
                  if (status.isNotEmpty) status,
                  if (archived) 'archived',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              if (purpose.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(purpose, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (record.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: record.tags
                      .take(4)
                      .map((tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlotEmptyState extends StatelessWidget {
  const _PlotEmptyState({
    required this.hasRecords,
    required this.canCreate,
    required this.onCreate,
  });

  final bool hasRecords;
  final bool canCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
        key: const Key('plot-empty-state'),
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(Icons.route_outlined, size: 42),
            const SizedBox(height: 12),
            Text(
              hasRecords
                  ? 'No plot records match these filters.'
                  : 'This story has no plot yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!hasRecords) ...[
              const SizedBox(height: 6),
              Text(
                'Start with an act, a plotline, or the beat you already know.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (!hasRecords && canCreate) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                key: const Key('plot-empty-create-button'),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create plot record'),
              ),
            ],
          ],
        ),
      );
}

/// What the editor collected. The service turns it into a Universal Record.
class _PlotDraft {
  const _PlotDraft({
    required this.typeId,
    required this.name,
    required this.fields,
    required this.tags,
  });

  final String typeId;
  final String name;
  final Map<String, Object?> fields;
  final List<String> tags;
}

/// Creates or edits one Plot record.
///
/// The field list is read from the resolved [RecordTypeDefinition], so a new
/// built-in or project custom type shows its own fields without a code change
/// here.
class _PlotRecordDialog extends StatefulWidget {
  const _PlotRecordDialog({
    required this.templates,
    this.existing,
    this.initialTypeId,
  });

  final List<RecordTypeDefinition> templates;
  final AuthorRecord? existing;
  final String? initialTypeId;

  @override
  State<_PlotRecordDialog> createState() => _PlotRecordDialogState();
}

class _PlotRecordDialogState extends State<_PlotRecordDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController tagsController;
  final Map<String, TextEditingController> fieldControllers = {};
  final Map<String, String?> choices = {};

  late String typeId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    typeId = existing?.typeId ??
        widget.initialTypeId ??
        widget.templates.first.id;
    if (!widget.templates.any((template) => template.id == typeId)) {
      typeId = widget.templates.first.id;
    }
    nameController = TextEditingController(text: existing?.title ?? '');
    tagsController =
        TextEditingController(text: (existing?.tags ?? const []).join(', '));
    _syncFieldControllers();
  }

  @override
  void dispose() {
    nameController.dispose();
    tagsController.dispose();
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  RecordTypeDefinition get template =>
      widget.templates.firstWhere((item) => item.id == typeId);

  /// Editable fields for the current type.
  ///
  /// Ordering, planning and reference fields stay out of the Phase 1 editor:
  /// they belong to boards and the connection graph, and a text box for them
  /// would invite a second, weaker way to express the same relationship.
  List<RecordFieldDefinition> get _editable => template.fields
      .where((field) => !field.hidden)
      .where((field) => const {
            RecordFieldType.shortText,
            RecordFieldType.longText,
            RecordFieldType.richText,
            RecordFieldType.singleChoice,
          }.contains(field.type))
      .where((field) => field.id != 'name')
      .toList()
    ..sort((left, right) => left.order.compareTo(right.order));

  void _syncFieldControllers() {
    final existing = widget.existing;
    for (final field in _editable) {
      final raw = existing?.fields[field.id] ?? field.defaultValue;
      if (field.type == RecordFieldType.singleChoice) {
        final value = raw?.toString();
        choices[field.id] =
            field.options.contains(value) ? value : null;
        continue;
      }
      fieldControllers.putIfAbsent(
        field.id,
        () => TextEditingController(text: raw?.toString() ?? ''),
      );
    }
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final fields = <String, Object?>{};
    for (final field in _editable) {
      if (field.type == RecordFieldType.singleChoice) {
        final value = choices[field.id];
        if (value != null && value.isNotEmpty) fields[field.id] = value;
        continue;
      }
      final text = fieldControllers[field.id]?.text.trim() ?? '';
      if (text.isNotEmpty) fields[field.id] = text;
    }
    Navigator.of(context).pop(
      _PlotDraft(
        typeId: typeId,
        name: nameController.text.trim(),
        fields: fields,
        tags: tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      key: const Key('plot-record-dialog'),
      title: Text(editing ? 'Edit plot record' : 'New plot record'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('plot-dialog-type-field'),
                  initialValue: typeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  // A Universal Record cannot change type after creation, so
                  // the editor offers the choice only while creating.
                  onChanged: editing
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            typeId = value;
                            _syncFieldControllers();
                          });
                        },
                  items: widget.templates
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('plot-dialog-name-field'),
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'A plot record needs a name.'
                      : null,
                ),
                for (final field in _editable) ...[
                  const SizedBox(height: 12),
                  if (field.type == RecordFieldType.singleChoice)
                    DropdownButtonFormField<String>(
                      key: Key('plot-dialog-field-${field.id}'),
                      initialValue: choices[field.id],
                      isExpanded: true,
                      decoration: InputDecoration(labelText: field.label),
                      onChanged: (value) =>
                          setState(() => choices[field.id] = value),
                      items: field.options
                          .map((option) => DropdownMenuItem(
                                value: option,
                                child: Text(
                                  option,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                    )
                  else
                    TextFormField(
                      key: Key('plot-dialog-field-${field.id}'),
                      controller: fieldControllers[field.id],
                      minLines: field.type == RecordFieldType.shortText ? 1 : 2,
                      maxLines: field.type == RecordFieldType.shortText ? 1 : 4,
                      decoration: InputDecoration(labelText: field.label),
                    ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('plot-dialog-tags-field'),
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    helperText: 'Comma separated',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('plot-dialog-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('plot-dialog-save-button'),
          onPressed: _submit,
          child: Text(editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

/// Confirms an archive, showing what the shared safe-delete analysis found.
class _PlotDeleteDialog extends StatelessWidget {
  const _PlotDeleteDialog({
    required this.record,
    required this.typeLabel,
    required this.analysis,
  });

  final AuthorRecord record;
  final String typeLabel;
  final SafeDeleteAnalysis? analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = analysis;
    final dependents = report == null
        ? 0
        : report.incomingConnections.length + report.references.length;
    return AlertDialog(
      key: const Key('plot-delete-dialog'),
      title: Text('Delete ${record.title}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This $typeLabel is archived, not erased. Its history, versions, '
            'and connections stay intact and it can be restored.',
            style: theme.textTheme.bodyMedium,
          ),
          if (dependents > 0) ...[
            const SizedBox(height: 12),
            Text(
              '$dependents other records point at it.',
              key: const Key('plot-delete-dependents'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('plot-delete-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('plot-delete-confirm-button'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// A stable Universal Record id for a new Plot record.
String _newPlotId(String typeId, String label) {
  final slug = label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final stem = slug.isEmpty ? typeId : '$typeId-$slug';
  return '$stem-${DateTime.now().microsecondsSinceEpoch}';
}

IconData _plotIcon(String name) => switch (name) {
      'auto_stories' => Icons.auto_stories_outlined,
      'view_agenda' => Icons.view_agenda_outlined,
      'reorder' => Icons.reorder_rounded,
      'route' => Icons.route_outlined,
      'music_note' => Icons.music_note_outlined,
      'turn_sharp_right' => Icons.turn_sharp_right_rounded,
      'visibility' => Icons.visibility_outlined,
      'lightbulb' => Icons.lightbulb_outline,
      'task_alt' => Icons.task_alt_rounded,
      'landscape' => Icons.landscape_outlined,
      'flag' => Icons.flag_outlined,
      _ => Icons.account_tree_outlined,
    };
