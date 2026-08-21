import 'package:flutter/material.dart';

import 'core/connected_domain.dart';
import 'core/plot_record_types.dart';
import 'core/record_types.dart';
import 'core/record_validation.dart';
import 'onboarding.dart';
import 'plot_service.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

class PlotStudioView extends StatefulWidget {
  const PlotStudioView({
    super.key,
    required this.project,
    required this.service,
  });

  final StarterProject project;
  final PlotService service;

  @override
  State<PlotStudioView> createState() => _PlotStudioViewState();
}

class _PlotStudioViewState extends State<PlotStudioView> {
  final TextEditingController _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<AuthorRecord> _records = const [];
  Map<String, PlotViewItem> _viewItems = const {};
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  static const _laneOrder = <String>[
    'planned',
    'active',
    'resolved',
    'abandoned',
  ];

  List<RecordTypeDefinition> get _typeOptions =>
      PlotRecordTypes.definitions.where((definition) {
        return definition.id != PlotRecordTypes.baseTypeId;
      }).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.query.all(),
        widget.service.query.viewItems(),
      ]);
      final records = results[0] as List<AuthorRecord>;
      final items = results[1] as List<PlotViewItem>;
      if (!mounted) return;
      setState(() {
        _records = records.where((record) => record.status != AuthorRecordStatus.deleted).toList();
        _viewItems = {for (final item in items) item.recordId: item};
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _readableError(error);
        _loading = false;
      });
    }
  }

  Future<void> _createRecord() async {
    final draft = await _showRecordDialog(context);
    if (draft == null) return;
    try {
      await widget.service.createPlotRecord(draft.toPlotRecordDraft());
      await _reload();
    } on RecordValidationException catch (error) {
      _showMessage(_readableError(error));
    } on ArgumentError catch (error) {
      _showMessage(_readableError(error));
    } on StateError catch (error) {
      _showMessage(_readableError(error));
    }
  }

  Future<void> _editRecord(AuthorRecord record) async {
    final draft = await _showRecordDialog(context, record: record);
    if (draft == null) return;
    try {
      await widget.service.updatePlotRecord(
        record.copyWith(
          title: draft.title.trim(),
          fields: draft.fields,
          canonStatus: draft.canonStatus,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await _reload();
    } on RecordValidationException catch (error) {
      _showMessage(_readableError(error));
    } on ArgumentError catch (error) {
      _showMessage(_readableError(error));
    } on StateError catch (error) {
      _showMessage(_readableError(error));
    }
  }

  Future<void> _archiveRecord(AuthorRecord record) async {
    await widget.service.archivePlotRecord(record.id);
    await _reload();
  }

  Future<void> _restoreRecord(AuthorRecord record) async {
    await widget.service.restorePlotRecord(record.id);
    await _reload();
  }

  Future<void> _deleteRecord(AuthorRecord record) async {
    await widget.service.records.deleteRecord(record.id);
    await _reload();
  }

  Future<void> _moveRecord(AuthorRecord record, int delta) async {
    final lane = _records
        .where((candidate) => _plotStatus(candidate) == _plotStatus(record))
        .toList()
      ..sort(_compareRecords);
    final index = lane.indexWhere((candidate) => candidate.id == record.id);
    if (index == -1) return;
    final targetIndex = (index + delta).clamp(0, lane.length - 1);
    if (targetIndex == index) return;
    final target = lane[targetIndex];
    final updated = record.copyWith(
      fields: {
        ...record.fields,
        'planningOrder': _nextOrderValue(target, delta),
      },
      updatedAt: DateTime.now().toUtc(),
    );
    await widget.service.updatePlotRecord(updated);
    await _reload();
  }

  int _compareRecords(AuthorRecord a, AuthorRecord b) {
    final statusCompare = _laneOrder.indexOf(_plotStatus(a)).compareTo(
          _laneOrder.indexOf(_plotStatus(b)),
        );
    if (statusCompare != 0) return statusCompare;
    final orderCompare = _orderOf(a).compareTo(_orderOf(b));
    if (orderCompare != 0) return orderCompare;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  List<AuthorRecord> _filteredRecords([String? status]) {
    final search = _searchController.text.trim().toLowerCase();
    return _records.where((record) {
      if (_statusFilter != 'all' && _plotStatus(record) != _statusFilter) {
        return false;
      }
      if (status != null && _plotStatus(record) != status) return false;
      if (_typeFilter != 'all' && record.typeId != _typeFilter) return false;
      if (search.isEmpty) return true;
      return record.title.toLowerCase().contains(search) ||
          record.typeId.toLowerCase().contains(search);
    }).toList()
      ..sort(_compareRecords);
  }

  List<AuthorRecord> get _visibleRecords => _filteredRecords();

  String _plotStatus(AuthorRecord record) =>
      (record.fields['plotStatus'] as String?)?.trim().toLowerCase() ?? 'planned';

  int _orderOf(AuthorRecord record) {
    final value = record.fields['planningOrder'] ??
        record.fields['narrativeOrder'] ??
        record.fields['chronologicalOrder'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _nextOrderValue(AuthorRecord record, int delta) => _orderOf(record) + delta;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final surface = scope.color(ThemeColorRef.surface);
    final container = scope.color(ThemeColorRef.surfaceContainer);
    final outline = scope.color(ThemeColorRef.outlineVariant);
    final onSurface = scope.color(ThemeColorRef.onSurface);
    final onSurfaceVariant = scope.color(ThemeColorRef.onSurfaceVariant);
    final primary = scope.color(ThemeColorRef.primary);

    return Container(
      color: surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.project.title} Plot Studio',
                        style: scope.text(ThemeTextRole.heading, colorRef: ThemeColorRef.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Project-scoped plot records, ordering, and lifecycle.',
                        style: scope.text(ThemeTextRole.label, colorRef: ThemeColorRef.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  key: const ValueKey('plot-refresh-button'),
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('plot-create-button'),
                  onPressed: _loading ? null : _createRecord,
                  icon: const Icon(Icons.add),
                  label: const Text('Add record'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    key: const ValueKey('plot-search-field'),
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search records',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                DropdownButton<String>(
                  value: _statusFilter,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    for (final status in _laneOrder)
                      DropdownMenuItem(value: status, child: Text(_title(status))),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _statusFilter = value);
                  },
                ),
                DropdownButton<String>(
                  value: _typeFilter,
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All types')),
                    for (final definition in _typeOptions)
                      DropdownMenuItem(value: definition.id, child: Text(definition.name)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _typeFilter = value);
                  },
                ),
                Text(
                  '${_visibleRecords.length} records',
                  style: scope.text(ThemeTextRole.label, colorRef: ThemeColorRef.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: scope.text(ThemeTextRole.body, colorRef: ThemeColorRef.onSurface),
                        ),
                      )
                    : _visibleRecords.isEmpty
                        ? Center(
                            child: Text(
                              'No plot records found.',
                              style: scope.text(ThemeTextRole.body, colorRef: ThemeColorRef.onSurfaceVariant),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final lane in _laneOrder)
                                    SizedBox(
                                      width: 340,
                                      child: _StatusLane(
                                        key: ValueKey('plot-lane-$lane'),
                                        laneId: lane,
                                        label: _title(lane),
                                        color: container,
                                        outline: outline,
                                        onSurface: onSurface,
                                        onSurfaceVariant: onSurfaceVariant,
                                        records: _filteredRecords(lane),
                                        viewItems: _viewItems,
                                        onEdit: _editRecord,
                                        onArchive: _archiveRecord,
                                        onRestore: _restoreRecord,
                                        onDelete: _deleteRecord,
                                        onMoveUp: (record) => _moveRecord(record, -1),
                                        onMoveDown: (record) => _moveRecord(record, 1),
                                        primary: primary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatusLane extends StatelessWidget {
  const _StatusLane({
    super.key,
    required this.laneId,
    required this.label,
    required this.color,
    required this.outline,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.records,
    required this.viewItems,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.primary,
  });

  final String laneId;
  final String label;
  final Color color;
  final Color outline;
  final Color onSurface;
  final Color onSurfaceVariant;
  final List<AuthorRecord> records;
  final Map<String, PlotViewItem> viewItems;
  final Future<void> Function(AuthorRecord record) onEdit;
  final Future<void> Function(AuthorRecord record) onArchive;
  final Future<void> Function(AuthorRecord record) onRestore;
  final Future<void> Function(AuthorRecord record) onDelete;
  final Future<void> Function(AuthorRecord record) onMoveUp;
  final Future<void> Function(AuthorRecord record) onMoveDown;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('plot-lane-container-$laneId'),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: outline),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: onSurface),
              ),
              const Spacer(),
              Text(
                '${records.length}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Create a record to populate this lane.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onSurfaceVariant),
              ),
            )
          else
            for (final record in records) ...[
              _PlotRecordCard(
                key: ValueKey('plot-record-${record.id}'),
                record: record,
                connectionCount: viewItems[record.id]?.connectionIds.length ?? 0,
                onEdit: onEdit,
                onArchive: onArchive,
                onRestore: onRestore,
                onDelete: onDelete,
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onSurface: onSurface,
                onSurfaceVariant: onSurfaceVariant,
                primary: primary,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PlotRecordCard extends StatelessWidget {
  const _PlotRecordCard({
    super.key,
    required this.record,
    required this.connectionCount,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.primary,
  });

  final AuthorRecord record;
  final int connectionCount;
  final Future<void> Function(AuthorRecord record) onEdit;
  final Future<void> Function(AuthorRecord record) onArchive;
  final Future<void> Function(AuthorRecord record) onRestore;
  final Future<void> Function(AuthorRecord record) onDelete;
  final Future<void> Function(AuthorRecord record) onMoveUp;
  final Future<void> Function(AuthorRecord record) onMoveDown;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final status = (record.fields['plotStatus'] as String?)?.trim() ?? 'planned';
    final order = [
      record.fields['planningOrder'],
      record.fields['narrativeOrder'],
      record.fields['chronologicalOrder'],
    ].firstWhere((value) => value is num || value is String, orElse: () => null);

    return LongPressDraggable<AuthorRecord>(
      data: record,
      feedback: Material(
        color: Colors.transparent,
        child: _cardBody(
          context,
          status: status,
          order: order,
          connectionCount: connectionCount,
          dragging: true,
        ),
      ),
      child: _cardBody(
        context,
        status: status,
        order: order,
        connectionCount: connectionCount,
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(
              tooltip: 'Move earlier',
              onPressed: () => onMoveUp(record),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move later',
              onPressed: () => onMoveDown(record),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: () => onEdit(record),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: record.status == AuthorRecordStatus.archived ? 'Restore' : 'Archive',
              onPressed: () => record.status == AuthorRecordStatus.archived
                  ? onRestore(record)
                  : onArchive(record),
              icon: Icon(
                record.status == AuthorRecordStatus.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => onDelete(record),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardBody(
    BuildContext context, {
    required String status,
    required Object? order,
    required int connectionCount,
    Widget? trailing,
    bool dragging = false,
  }) {
    final scope = StudioThemeScope.of(context);
    final surface = scope.color(ThemeColorRef.surface);
    final border = scope.color(ThemeColorRef.outlineVariant);
    final highlight = scope.color(ThemeColorRef.highlight);
    final label = scope.text(ThemeTextRole.label, colorRef: ThemeColorRef.onSurfaceVariant);
    return Opacity(
      opacity: dragging ? 0.8 : 1,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: scope.text(ThemeTextRole.heading, colorRef: ThemeColorRef.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${record.typeId} • ${_title(status)}${order == null ? '' : ' • #$order'}',
                        style: label,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('$connectionCount links'),
                  side: BorderSide(color: highlight),
                ),
                Chip(
                  label: Text(record.canonStatus.name),
                  side: BorderSide(color: border),
                ),
                Chip(
                  label: Text(record.status.name),
                  side: BorderSide(color: border),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlotRecordDraftView {
  const _PlotRecordDraftView({
    required this.id,
    required this.typeId,
    required this.title,
    required this.fields,
    required this.canonStatus,
  });

  final String id;
  final String typeId;
  final String title;
  final Map<String, Object?> fields;
  final CanonStatus canonStatus;

  PlotRecordDraft toPlotRecordDraft() => PlotRecordDraft(
        id: id,
        typeId: typeId,
        name: title,
        fields: fields,
        canonStatus: canonStatus,
      );
}

Future<_PlotRecordDraftView?> _showRecordDialog(
  BuildContext context, {
  AuthorRecord? record,
}) async {
  final idController = TextEditingController(text: record?.id ?? '');
  final titleController = TextEditingController(text: record?.title ?? '');
  final typeController = TextEditingController(text: record?.typeId ?? PlotRecordTypes.recordTypeIds.first);
  final statusController = TextEditingController(
    text: record?.fields['plotStatus'] as String? ?? 'planned',
  );
  final planningController = TextEditingController(
    text: record?.fields['planningOrder']?.toString() ?? '',
  );
  final narrativeController = TextEditingController(
    text: record?.fields['narrativeOrder']?.toString() ?? '',
  );
  final chronologicalController = TextEditingController(
    text: record?.fields['chronologicalOrder']?.toString() ?? '',
  );
  final dependenciesController = TextEditingController(
    text: (record?.fields['dependencies'] as List?)?.join(', ') ?? '',
  );
  CanonStatus canonStatus = record?.canonStatus ?? CanonStatus.draft;

  return showDialog<_PlotRecordDraftView>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(record == null ? 'Create plot record' : 'Edit plot record'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('plot-record-id-field'),
                  controller: idController,
                  decoration: const InputDecoration(labelText: 'Record id'),
                ),
                TextField(
                  key: const ValueKey('plot-record-title-field'),
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('plot-record-type-field'),
                  value: typeController.text,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final definition in PlotRecordTypes.definitions
                        .where((definition) => definition.id != PlotRecordTypes.baseTypeId))
                      DropdownMenuItem(value: definition.id, child: Text(definition.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) typeController.text = value;
                  },
                ),
                DropdownButtonFormField<String>(
                  key: const ValueKey('plot-record-status-field'),
                  value: statusController.text,
                  decoration: const InputDecoration(labelText: 'Plot status'),
                  items: const [
                    DropdownMenuItem(value: 'planned', child: Text('Planned')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'abandoned', child: Text('Abandoned')),
                  ],
                  onChanged: (value) {
                    if (value != null) statusController.text = value;
                  },
                ),
                TextField(
                  key: const ValueKey('plot-record-planning-order-field'),
                  controller: planningController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Planning order'),
                ),
                TextField(
                  key: const ValueKey('plot-record-narrative-order-field'),
                  controller: narrativeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Narrative order'),
                ),
                TextField(
                  key: const ValueKey('plot-record-chronological-order-field'),
                  controller: chronologicalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Chronological order'),
                ),
                TextField(
                  key: const ValueKey('plot-record-dependencies-field'),
                  controller: dependenciesController,
                  decoration: const InputDecoration(
                    labelText: 'Dependencies',
                    helperText: 'Comma-separated record ids',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CanonStatus>(
                  key: const ValueKey('plot-record-canon-status-field'),
                  value: canonStatus,
                  decoration: const InputDecoration(labelText: 'Canon status'),
                  items: CanonStatus.values
                      .map((value) => DropdownMenuItem(value: value, child: Text(value.name)))
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) canonStatus = value;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final fields = <String, Object?>{
                'plotStatus': statusController.text.trim().toLowerCase(),
              };
              final planning = int.tryParse(planningController.text.trim());
              final narrative = int.tryParse(narrativeController.text.trim());
              final chronological = int.tryParse(chronologicalController.text.trim());
              if (planning != null) fields['planningOrder'] = planning;
              if (narrative != null) fields['narrativeOrder'] = narrative;
              if (chronological != null) fields['chronologicalOrder'] = chronological;
              final dependencies = dependenciesController.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false);
              if (dependencies.isNotEmpty) fields['dependencies'] = dependencies;
              Navigator.of(dialogContext).pop(
                _PlotRecordDraftView(
                  id: idController.text.trim(),
                  typeId: typeController.text.trim(),
                  title: titleController.text.trim(),
                  fields: record == null ? fields : {...record.fields, ...fields},
                  canonStatus: canonStatus,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
}

String _title(String value) =>
    value.replaceAll('-', ' ').replaceAllMapped(RegExp(r'\b\w'), (m) => m.group(0)!.toUpperCase());

String _readableError(Object error) {
  if (error is RecordValidationException) {
    return error.result.errors.map((issue) => issue.message).join(' ');
  }
  if (error is ArgumentError) return '${error.message}';
  if (error is StateError) return error.message;
  return error.toString();
}
