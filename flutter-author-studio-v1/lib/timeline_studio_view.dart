import 'package:flutter/material.dart';

import 'core/connected_domain.dart';
import 'core/record_types.dart';
import 'core/safe_delete.dart';
import 'core/search_models.dart';
import 'core/timeline_record_types.dart';
import 'core/universal_search.dart';
import 'knowledge_graph/open_in_graph.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';
import 'timeline_domain.dart';
import 'timeline_service.dart';

/// Where a connected record lives, so the shell can switch Studios.
class TimelineNavigationRequest {
  const TimelineNavigationRequest({
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

/// The writer-facing Timeline Studio workspace.
///
/// Every read and write goes through [TimelineService], the existing domain
/// facade over `RecordService`, `ConnectionEngine`, `BranchService`,
/// `UniversalSearchService`, `VersionAuditService`, `UniversalRecordInspector`
/// and `SafeDeleteService`. The Studio owns no store, index or history of its
/// own; every event stays a project-scoped Universal Record.
class TimelineStudioView extends StatefulWidget {
  const TimelineStudioView({
    super.key,
    required this.project,
    this.repository,
    this.service,
    this.onNavigate,
  });

  final StarterProject project;
  final DriftConnectedDomainRepository? repository;

  /// An explicit service, for tests that drive the Studio against a fixture
  /// database. When absent the Studio builds one for [project].
  final TimelineService? service;
  final ValueChanged<TimelineNavigationRequest>? onNavigate;

  @override
  State<TimelineStudioView> createState() => _TimelineStudioViewState();
}

/// One row of the chronological rail, already labelled for display.
class _TimelineEntry {
  const _TimelineEntry({
    required this.record,
    required this.dateLabel,
    required this.endLabel,
    required this.dated,
  });

  final AuthorRecord record;
  final String dateLabel;
  final String endLabel;
  final bool dated;
}

class _TimelineStudioViewState extends State<TimelineStudioView> {
  static const _undatedFilter = '__undated__';

  late final TimelineService service;
  final searchController = TextEditingController();

  bool loading = true;
  bool busy = false;
  String? loadError;
  List<_TimelineEntry> entries = const [];
  List<TimelineCalendar> calendars = const [];
  Map<String, String> typeNames = const {};
  String? selectedId;
  String typeFilter = 'all';
  bool sortDescending = false;
  bool showArchived = false;
  List<RecordLink> selectedLinks = const [];
  Map<String, AuthorRecord> linkedRecords = const {};

  @override
  void initState() {
    super.initState();
    service = widget.service ??
        TimelineService(
          projectId: widget.project.id,
          repository: widget.repository ?? authorOsRepository,
        );
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  _TimelineEntry? get selected =>
      entries.where((entry) => entry.record.id == selectedId).firstOrNull;

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final registry = await service.records.registry();
      final names = <String, String>{};
      for (final id in TimelineRecordTypes.recordTypeIds) {
        names[id] = registry.resolve(id).name;
      }
      final loadedCalendars = await service.calendars();
      final byId = {
        for (final calendar in loadedCalendars) calendar.id: calendar,
      };
      final records = await service.query.chronological(
        status: showArchived ? null : AuthorRecordStatus.active,
        descending: sortDescending,
      );
      final loaded = <_TimelineEntry>[
        for (final record in records)
          _entryFor(record, byId, registry: registry, names: names),
      ];
      if (!mounted) return;
      setState(() {
        typeNames = names;
        calendars = loadedCalendars;
        entries = loaded;
        loading = false;
        if (selectedId != null &&
            !loaded.any((entry) => entry.record.id == selectedId)) {
          selectedId = null;
          selectedLinks = const [];
          linkedRecords = const {};
        }
      });
      if (selectedId != null) {
        await _loadConnections(selectedId!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = '$error';
      });
    }
  }

  _TimelineEntry _entryFor(
    AuthorRecord record,
    Map<String, TimelineCalendar> byId, {
    required RecordTypeRegistry registry,
    required Map<String, String> names,
  }) {
    names.putIfAbsent(record.typeId, () {
      try {
        return registry.resolve(record.typeId).name;
      } on StateError {
        return record.typeId;
      }
    });
    final start = _startDate(record);
    final end = _endDate(record);
    final calendar = start == null ? null : byId[start.calendarId];
    final endCalendar = end == null ? null : byId[end.calendarId];
    return _TimelineEntry(
      record: record,
      dateLabel: start == null || calendar == null || !start.isDated
          ? 'Undated'
          : calendar.format(start),
      endLabel: end == null || endCalendar == null || !end.isDated
          ? ''
          : endCalendar.format(end),
      dated: start != null && calendar != null && start.isDated,
    );
  }

  Future<void> _loadConnections(String id) async {
    try {
      final links = await service.connectionsFor(id);
      final records = <String, AuthorRecord>{};
      for (final link in links) {
        final otherId = link.sourceId == id ? link.targetId : link.sourceId;
        final record = await service.repository.recordById(otherId);
        if (record != null) records[otherId] = record;
      }
      if (!mounted || selectedId != id) return;
      setState(() {
        selectedLinks = links;
        linkedRecords = records;
      });
    } catch (_) {
      // Connections are supplementary; the detail pane simply shows none.
      if (!mounted || selectedId != id) return;
      setState(() {
        selectedLinks = const [];
        linkedRecords = const {};
      });
    }
  }

  List<_TimelineEntry> get visibleEntries {
    final query = searchController.text.trim().toLowerCase();
    return [
      for (final entry in entries)
        if (_matchesType(entry) && _matchesQuery(entry, query)) entry,
    ];
  }

  bool _matchesType(_TimelineEntry entry) => switch (typeFilter) {
        'all' => true,
        _undatedFilter => !entry.dated,
        _ => entry.record.typeId == typeFilter,
      };

  bool _matchesQuery(_TimelineEntry entry, String query) {
    if (query.isEmpty) return true;
    final record = entry.record;
    return record.title.toLowerCase().contains(query) ||
        '${record.fields['summary'] ?? ''}'.toLowerCase().contains(query) ||
        '${record.fields['description'] ?? ''}'
            .toLowerCase()
            .contains(query) ||
        record.tags.any((tag) => tag.toLowerCase().contains(query)) ||
        entry.dateLabel.toLowerCase().contains(query);
  }

  void _select(String id) {
    setState(() => selectedId = id);
    _loadConnections(id);
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } on TimelineValidationException catch (error) {
      _showError(error.issues.map((issue) => issue.message).join('\n'));
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const Key('timeline-action-error'),
      content: Text(message),
    ));
  }

  /// The Studio never invents a calendar behind the author's back: a dated
  /// event needs one, so the editor provisions a neutral default the first
  /// time a date is saved into a project that has none.
  Future<TimelineCalendar> _ensureCalendar() async {
    if (calendars.isNotEmpty) return calendars.first;
    final calendar = TimelineCalendar(
      id: 'calendar-${service.projectId}',
      name: 'Story Calendar',
      months: [
        for (var month = 1; month <= 12; month++)
          TimelineCalendarMonth(name: 'Month $month', length: 30),
      ],
    );
    await service.createCalendar(calendar, primary: true);
    return calendar;
  }

  Future<String> _newEventId(String title) async {
    var slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'event';
    var candidate = 'timeline-$slug';
    var suffix = 2;
    while (await service.repository.recordById(candidate) != null) {
      candidate = 'timeline-$slug-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  Future<void> _openEventEditor({AuthorRecord? existing}) async {
    final draft = await showDialog<_TimelineEventFormResult>(
      context: context,
      builder: (context) => _TimelineEventDialog(
        existing: existing,
        typeNames: typeNames,
        calendars: calendars,
      ),
    );
    if (draft == null || !mounted) return;
    await _runBusy(() async {
      String? calendarId = draft.calendarId;
      if (draft.startYear != null && calendarId == null) {
        calendarId = (await _ensureCalendar()).id;
      }
      TimelineDate? date(int? year, int? month, int? day) =>
          year == null || calendarId == null
              ? null
              : TimelineDate(
                  calendarId: calendarId,
                  year: year,
                  month: month,
                  day: day,
                  precision: draft.approximate
                      ? TimelinePrecision.approximate
                      : TimelinePrecision.exact,
                  approximate: draft.approximate,
                );
      final eventDraft = TimelineEventDraft(
        id: existing?.id ?? await _newEventId(draft.title),
        name: draft.title,
        typeId: draft.typeId,
        summary: draft.summary,
        description: draft.description,
        start: date(draft.startYear, draft.startMonth, draft.startDay),
        end: date(draft.endYear, draft.endMonth, draft.endDay),
        status: draft.status,
        importance: draft.importance,
        notes: draft.notes,
        tags: draft.tags,
        canonStatus: draft.canonStatus,
        seriesId: existing?.seriesId,
        bookId: existing?.bookId,
        branchId: existing?.branchId,
      );
      final saved = existing == null
          ? await service.createEvent(eventDraft)
          : await service.updateEvent(eventDraft,
              summary: 'Edited in Timeline Studio');
      selectedId = saved.id;
      await _load();
    });
  }

  Future<void> _confirmDelete(AuthorRecord record) async {
    SafeDeleteAnalysis? analysis;
    try {
      analysis = await service.analyzeDelete(record.id);
    } catch (_) {
      analysis = null;
    }
    if (!mounted) return;
    final palette = _TimelinePalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('timeline-delete-dialog'),
        title: Text('Delete "${record.title}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The event is removed from the timeline. Its history and '
              'connections stay recorded, so this can be reviewed later.',
            ),
            if (analysis != null &&
                (analysis.incomingConnections.isNotEmpty ||
                    analysis.outgoingConnections.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Text(
                '${analysis.incomingConnections.length + analysis.outgoingConnections.length} '
                'connection(s) reference this event.',
                style: palette.label,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('timeline-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runBusy(() async {
      await service.deleteTimelineRecord(record.id);
      if (selectedId == record.id) selectedId = null;
      await _load();
    });
  }

  Future<void> _toggleArchived(AuthorRecord record) => _runBusy(() async {
        if (record.status == AuthorRecordStatus.archived) {
          await service.restoreTimelineRecord(record.id);
        } else {
          await service.archiveTimelineRecord(record.id);
        }
        await _load();
      });

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    final content = _buildStudio(context);
    if (scope == null) return content;
    // Layer this Studio's theme overrides on top of the shell theme; the
    // engine and its tokens stay the single source of truth.
    return StudioThemeScope(
      theme: scope.theme,
      studio: StudioId.timeline,
      child: Builder(builder: _buildStudio),
    );
  }

  Widget _buildStudio(BuildContext context) {
    final palette = _TimelinePalette.of(context);
    if (loading) {
      return Column(
        key: const Key('timeline-loading'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, palette),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 96),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (loadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, palette),
          const SizedBox(height: 16),
          _ErrorState(palette: palette, message: loadError!, onRetry: _load),
        ],
      );
    }
    final visible = visibleEntries;
    return FocusTraversalGroup(
      child: Column(
        key: const Key('timeline-studio'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, palette),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            _EmptyState(palette: palette, onCreate: () => _openEventEditor())
          else ...[
            _buildFilterBar(context, palette),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final rail = _buildRail(context, palette, visible);
                final detail = selected == null
                    ? null
                    : _TimelineDetailPane(
                        entry: selected!,
                        typeNames: typeNames,
                        links: selectedLinks,
                        linkedRecords: linkedRecords,
                        palette: palette,
                        busy: busy,
                        onEdit: () =>
                            _openEventEditor(existing: selected!.record),
                        onDelete: () => _confirmDelete(selected!.record),
                        onToggleArchived: () =>
                            _toggleArchived(selected!.record),
                        onClose: () => setState(() => selectedId = null),
                        onNavigate: widget.onNavigate,
                      );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: rail),
                      if (detail != null) ...[
                        const SizedBox(width: 16),
                        Expanded(flex: 3, child: detail),
                      ],
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    rail,
                    if (detail != null) ...[
                      const SizedBox(height: 16),
                      detail,
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _TimelinePalette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Timeline Studio',
                style: palette.heading.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Chart the chronology of your story world through shared '
                'Universal Records.',
                style: palette.body.copyWith(color: palette.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: 'Create timeline event',
          child: FilledButton.icon(
            key: const Key('timeline-create-button'),
            onPressed: busy || loading || loadError != null
                ? null
                : () => _openEventEditor(),
            icon: const Icon(Icons.add),
            label: const Text('Create Event'),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, _TimelinePalette palette) {
    final presentTypes = {
      for (final entry in entries) entry.record.typeId,
    }.toList()
      ..sort();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.outline),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              key: const Key('timeline-search-field'),
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search events',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              key: const Key('timeline-type-filter'),
              initialValue: typeFilter,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Type', isDense: true),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All types')),
                const DropdownMenuItem(
                  value: _undatedFilter,
                  child: Text('Undated only'),
                ),
                for (final typeId in presentTypes)
                  DropdownMenuItem(
                    value: typeId,
                    child: Text(typeNames[typeId] ?? typeId),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => typeFilter = value ?? 'all'),
            ),
          ),
          Semantics(
            button: true,
            label: sortDescending
                ? 'Sort earliest first'
                : 'Sort latest first',
            child: OutlinedButton.icon(
              key: const Key('timeline-sort-toggle'),
              onPressed: () {
                setState(() => sortDescending = !sortDescending);
                _load();
              },
              icon: Icon(sortDescending
                  ? Icons.arrow_upward
                  : Icons.arrow_downward),
              label: Text(sortDescending ? 'Latest first' : 'Earliest first'),
            ),
          ),
          FilterChip(
            key: const Key('timeline-show-archived'),
            label: const Text('Show archived'),
            selected: showArchived,
            onSelected: (value) {
              setState(() => showArchived = value);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRail(
    BuildContext context,
    _TimelinePalette palette,
    List<_TimelineEntry> visible,
  ) {
    if (visible.isEmpty) {
      return Container(
        key: const Key('timeline-no-matches'),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.outline),
        ),
        child: Text(
          'No timeline events match the current filters.',
          style: palette.body,
        ),
      );
    }
    final dated = [
      for (final entry in visible)
        if (entry.dated) entry,
    ];
    final undated = [
      for (final entry in visible)
        if (!entry.dated) entry,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < dated.length; index++)
          _TimelineRow(
            entry: dated[index],
            isFirst: index == 0,
            // The undated group carries its own spine below the header, so
            // the dated run ends cleanly on its last marker.
            isLast: index == dated.length - 1,
            selected: dated[index].record.id == selectedId,
            typeName: typeNames[dated[index].record.typeId] ??
                dated[index].record.typeId,
            palette: palette,
            onTap: () => _select(dated[index].record.id),
          ),
        if (undated.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
            child: Text(
              'Undated',
              key: const Key('timeline-undated-header'),
              style: palette.ui.copyWith(
                    color: palette.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          for (var index = 0; index < undated.length; index++)
            _TimelineRow(
              entry: undated[index],
              isFirst: index == 0,
              isLast: index == undated.length - 1,
              selected: undated[index].record.id == selectedId,
              typeName: typeNames[undated[index].record.typeId] ??
                  undated[index].record.typeId,
              palette: palette,
              onTap: () => _select(undated[index].record.id),
            ),
        ],
      ],
    );
  }
}

/// Colours resolved once per build from the Theme Engine scope, with the
/// Material theme as fallback so the Studio renders in bare-`MaterialApp`
/// tests too. No `ThemeData` is created here.
class _TimelinePalette {
  const _TimelinePalette({
    required this.surface,
    required this.surfaceContainer,
    required this.primary,
    required this.onPrimary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.selection,
    required this.focusRing,
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
  final Color focusRing;

  /// Typography comes from the Theme Engine's roles rather than the Material
  /// text theme, so the Studio's type scale is governed by the same tokens as
  /// its colours.
  final TextStyle heading;
  final TextStyle ui;
  final TextStyle body;
  final TextStyle label;

  /// The chronological rail and its markers use the Studio accent.
  Color get railLine => primary;

  static _TimelinePalette of(BuildContext context) {
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
    return _TimelinePalette(
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
      selection: scope?.color(ThemeColorRef.selection) ??
          scheme.primaryContainer,
      focusRing: scope?.color(ThemeColorRef.focusRing) ?? scheme.primary,
      heading: text(ThemeTextRole.heading, ThemeColorRef.onSurface,
          theme.textTheme.headlineSmall),
      ui: text(ThemeTextRole.ui, ThemeColorRef.onSurface,
          theme.textTheme.titleSmall),
      body: text(ThemeTextRole.body, ThemeColorRef.onSurfaceVariant,
          theme.textTheme.bodyMedium),
      label: text(ThemeTextRole.label, ThemeColorRef.onSurfaceVariant,
          theme.textTheme.labelMedium),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette, required this.onCreate});

  final _TimelinePalette palette;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('timeline-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          Icon(Icons.timeline_outlined, size: 56, color: palette.primary),
          const SizedBox(height: 16),
          Text(
            'Your story has no events yet.',
            style: palette.heading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Timeline events anchor eras, battles, births and turning points '
            'to the chronology of your world.',
            textAlign: TextAlign.center,
            style: palette.body.copyWith(color: palette.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: 'Create the first timeline event',
            child: FilledButton.icon(
              key: const Key('timeline-empty-create-button'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            ),
          ),
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

  final _TimelinePalette palette;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('timeline-error-state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline,
              size: 44, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(
            'The timeline could not be loaded.',
            style: palette.ui.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: palette.label.copyWith(color: palette.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('timeline-retry-button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// One event on the vertical chronology rail: date gutter, spine with a
/// marker, and the event card.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.selected,
    required this.typeName,
    required this.palette,
    required this.onTap,
  });

  final _TimelineEntry entry;
  final bool isFirst;
  final bool isLast;
  final bool selected;
  final String typeName;
  final _TimelinePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final archived = record.status == AuthorRecordStatus.archived;
    final importance = '${record.fields['importance'] ?? 'normal'}';
    final summary = '${record.fields['summary'] ?? ''}';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(top: 14, right: 8),
              child: Text(
                entry.dateLabel,
                textAlign: TextAlign.right,
                style: palette.label.copyWith(
                      color: palette.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: Column(
              children: [
                SizedBox(
                  height: 14,
                  child: isFirst
                      ? null
                      : Center(
                          child: Container(width: 2, color: palette.railLine),
                        ),
                ),
                Container(
                  key: Key('timeline-marker-${record.id}'),
                  width: selected ? 16 : 12,
                  height: selected ? 16 : 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? palette.railLine : palette.surface,
                    border: Border.all(color: palette.railLine, width: 2.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(width: 2, color: palette.railLine),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                button: true,
                selected: selected,
                label: 'Timeline event ${record.title}, ${entry.dateLabel}',
                child: Material(
                  color: selected ? palette.selection : palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: Key('timeline-event-${record.id}'),
                    borderRadius: BorderRadius.circular(14),
                    focusColor: palette.focusRing.withValues(alpha: 0.18),
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? palette.railLine : palette.outline,
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.title,
                                  style: palette.ui.copyWith(
                                        fontWeight: FontWeight.w700,
                                        decoration: archived
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                ),
                              ),
                              _TimelineTag(
                                label: typeName,
                                palette: palette,
                                emphasized: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (entry.endLabel.isNotEmpty &&
                                  entry.endLabel != entry.dateLabel)
                                _TimelineTag(
                                  label:
                                      '${entry.dateLabel} → ${entry.endLabel}',
                                  palette: palette,
                                ),
                              _TimelineTag(
                                label:
                                    '${record.fields['temporalStatus'] ?? 'draft'}',
                                palette: palette,
                              ),
                              _TimelineTag(
                                label: importance,
                                palette: palette,
                              ),
                              if (archived)
                                _TimelineTag(
                                    label: 'archived', palette: palette),
                              for (final tag in record.tags.take(3))
                                _TimelineTag(label: '#$tag', palette: palette),
                            ],
                          ),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: palette.label.copyWith(color: palette.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTag extends StatelessWidget {
  const _TimelineTag({
    required this.label,
    required this.palette,
    this.emphasized = false,
  });

  final String label;
  final _TimelinePalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasized
            ? palette.primary.withValues(alpha: 0.14)
            : palette.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: palette.label.copyWith(
              color: emphasized ? palette.primary : palette.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TimelineDetailPane extends StatelessWidget {
  const _TimelineDetailPane({
    required this.entry,
    required this.typeNames,
    required this.links,
    required this.linkedRecords,
    required this.palette,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleArchived,
    required this.onClose,
    required this.onNavigate,
  });

  final _TimelineEntry entry;
  final Map<String, String> typeNames;
  final List<RecordLink> links;
  final Map<String, AuthorRecord> linkedRecords;
  final _TimelinePalette palette;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleArchived;
  final VoidCallback onClose;
  final ValueChanged<TimelineNavigationRequest>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final archived = record.status == AuthorRecordStatus.archived;
    final description = '${record.fields['description'] ?? ''}';
    final summary = '${record.fields['summary'] ?? ''}';
    final notes = '${record.fields['notes'] ?? ''}';
    return Container(
      key: const Key('timeline-detail-pane'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
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
                  style: palette.heading.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              // The pane already holds both the record and the callback, so
              // it can ask for the graph itself without new plumbing.
              OpenInGraphButton(
                recordId: record.id,
                compact: true,
                onOpen: onNavigate == null
                    ? null
                    : () => onNavigate!(
                          TimelineNavigationRequest(
                            destination: SearchDestination.knowledgeGraph,
                            recordId: record.id,
                            recordType: record.typeId,
                            title: record.title,
                          ),
                        ),
              ),
              IconButton(
                key: const Key('timeline-detail-close'),
                tooltip: 'Close details',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _TimelineTag(
                label: typeNames[record.typeId] ?? record.typeId,
                palette: palette,
                emphasized: true,
              ),
              _TimelineTag(
                label: 'canon: ${record.canonStatus.name}',
                palette: palette,
              ),
              _TimelineTag(
                label: 'status: ${record.fields['temporalStatus'] ?? 'draft'}',
                palette: palette,
              ),
              _TimelineTag(
                label: 'importance: '
                    '${record.fields['importance'] ?? 'normal'}',
                palette: palette,
              ),
              if (archived) _TimelineTag(label: 'archived', palette: palette),
            ],
          ),
          const SizedBox(height: 14),
          _DetailLine(label: 'Start', value: entry.dateLabel, palette: palette),
          if (entry.endLabel.isNotEmpty)
            _DetailLine(label: 'End', value: entry.endLabel, palette: palette),
          if (summary.isNotEmpty)
            _DetailLine(label: 'Summary', value: summary, palette: palette),
          if (record.tags.isNotEmpty)
            _DetailLine(
              label: 'Tags',
              value: record.tags.join(', '),
              palette: palette,
            ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: palette.body,
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: palette.label.copyWith(color: palette.onSurfaceVariant),
            ),
          ],
          if (links.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Connections',
              style: palette.ui.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final link in links)
              _ConnectionRow(
                link: link,
                record: linkedRecords[link.sourceId == record.id
                    ? link.targetId
                    : link.sourceId],
                palette: palette,
                onNavigate: onNavigate,
              ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                button: true,
                label: 'Edit event ${record.title}',
                child: FilledButton.icon(
                  key: const Key('timeline-edit-button'),
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('timeline-archive-button'),
                onPressed: busy ? null : onToggleArchived,
                icon: Icon(
                  archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: 18,
                ),
                label: Text(archived ? 'Restore' : 'Archive'),
              ),
              Semantics(
                button: true,
                label: 'Delete event ${record.title}',
                child: OutlinedButton.icon(
                  key: const Key('timeline-delete-button'),
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final _TimelinePalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: palette.label.copyWith(color: palette.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: palette.body),
          ),
        ],
      ),
    );
  }
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.link,
    required this.record,
    required this.palette,
    required this.onNavigate,
  });

  final RecordLink link;
  final AuthorRecord? record;
  final _TimelinePalette palette;
  final ValueChanged<TimelineNavigationRequest>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final target = record;
    if (target == null) return const SizedBox.shrink();
    final request = TimelineNavigationRequest(
      destination: searchDestinationForType(target.typeId),
      recordId: target.id,
      recordType: target.typeId,
      title: target.title,
    );
    return InkWell(
      key: Key('timeline-connection-${link.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: onNavigate == null ? null : () => onNavigate!(request),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Icon(Icons.link, size: 14, color: palette.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${link.typeId} · ${target.title}',
                style: palette.label,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Values the event dialog hands back; the Studio turns them into a
/// [TimelineEventDraft] so all writes stay in [TimelineService].
class _TimelineEventFormResult {
  const _TimelineEventFormResult({
    required this.title,
    required this.typeId,
    required this.summary,
    required this.description,
    required this.notes,
    required this.status,
    required this.importance,
    required this.canonStatus,
    required this.tags,
    required this.approximate,
    this.calendarId,
    this.startYear,
    this.startMonth,
    this.startDay,
    this.endYear,
    this.endMonth,
    this.endDay,
  });

  final String title;
  final String typeId;
  final String summary;
  final String description;
  final String notes;
  final String status;
  final String importance;
  final CanonStatus canonStatus;
  final List<String> tags;
  final bool approximate;
  final String? calendarId;
  final int? startYear;
  final int? startMonth;
  final int? startDay;
  final int? endYear;
  final int? endMonth;
  final int? endDay;
}

class _TimelineEventDialog extends StatefulWidget {
  const _TimelineEventDialog({
    required this.existing,
    required this.typeNames,
    required this.calendars,
  });

  final AuthorRecord? existing;
  final Map<String, String> typeNames;
  final List<TimelineCalendar> calendars;

  @override
  State<_TimelineEventDialog> createState() => _TimelineEventDialogState();
}

class _TimelineEventDialogState extends State<_TimelineEventDialog> {
  static const importanceOptions = [
    'minor',
    'normal',
    'important',
    'major',
    'critical',
  ];
  static const statusOptions = [
    'draft',
    'planned',
    'established',
    'completed',
  ];

  late final TextEditingController titleController;
  late final TextEditingController summaryController;
  late final TextEditingController descriptionController;
  late final TextEditingController notesController;
  late final TextEditingController tagsController;
  late final TextEditingController startYearController;
  late final TextEditingController startMonthController;
  late final TextEditingController startDayController;
  late final TextEditingController endYearController;
  late final TextEditingController endMonthController;
  late final TextEditingController endDayController;

  late String typeId;
  late String status;
  late String importance;
  late CanonStatus canonStatus;
  bool approximate = false;
  String? validationMessage;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final fields = existing?.fields ?? const <String, Object?>{};
    final start = existing == null ? null : _startDate(existing);
    final end = existing == null ? null : _endDate(existing);
    titleController = TextEditingController(text: existing?.title ?? '');
    summaryController =
        TextEditingController(text: '${fields['summary'] ?? ''}');
    descriptionController =
        TextEditingController(text: '${fields['description'] ?? ''}');
    notesController = TextEditingController(text: '${fields['notes'] ?? ''}');
    tagsController =
        TextEditingController(text: existing?.tags.join(', ') ?? '');
    startYearController =
        TextEditingController(text: start?.year?.toString() ?? '');
    startMonthController =
        TextEditingController(text: start?.month?.toString() ?? '');
    startDayController =
        TextEditingController(text: start?.day?.toString() ?? '');
    endYearController =
        TextEditingController(text: end?.year?.toString() ?? '');
    endMonthController =
        TextEditingController(text: end?.month?.toString() ?? '');
    endDayController = TextEditingController(text: end?.day?.toString() ?? '');
    typeId = existing?.typeId ?? TimelineRecordTypes.eventTypeId;
    final storedStatus = '${fields['temporalStatus'] ?? 'draft'}';
    status =
        statusOptions.contains(storedStatus) ? storedStatus : statusOptions.first;
    final storedImportance = '${fields['importance'] ?? 'normal'}';
    importance = importanceOptions.contains(storedImportance)
        ? storedImportance
        : 'normal';
    canonStatus = existing?.canonStatus ?? CanonStatus.draft;
    approximate = start?.approximate ?? false;
  }

  @override
  void dispose() {
    titleController.dispose();
    summaryController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    tagsController.dispose();
    startYearController.dispose();
    startMonthController.dispose();
    startDayController.dispose();
    endYearController.dispose();
    endMonthController.dispose();
    endDayController.dispose();
    super.dispose();
  }

  int? _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  void _submit() {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      setState(() => validationMessage = 'The event needs a name.');
      return;
    }
    final startYear = _int(startYearController);
    if (startYearController.text.trim().isNotEmpty && startYear == null) {
      setState(() => validationMessage = 'Start year must be a whole number.');
      return;
    }
    final endYear = _int(endYearController);
    if (endYear != null && startYear == null) {
      setState(() =>
          validationMessage = 'An end date needs a start date to follow.');
      return;
    }
    final tags = [
      for (final tag in tagsController.text.split(','))
        if (tag.trim().isNotEmpty) tag.trim(),
    ];
    Navigator.of(context).pop(_TimelineEventFormResult(
      title: title,
      typeId: typeId,
      summary: summaryController.text.trim(),
      description: descriptionController.text.trim(),
      notes: notesController.text.trim(),
      status: status,
      importance: importance,
      canonStatus: canonStatus,
      tags: tags,
      approximate: approximate,
      calendarId:
          widget.calendars.isEmpty ? null : widget.calendars.first.id,
      startYear: startYear,
      startMonth: _int(startMonthController),
      startDay: _int(startDayController),
      endYear: endYear,
      endMonth: _int(endMonthController),
      endDay: _int(endDayController),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final sortedTypes = TimelineRecordTypes.recordTypeIds.toList()
      ..sort((left, right) => (widget.typeNames[left] ?? left)
          .compareTo(widget.typeNames[right] ?? right));
    if (editing && !sortedTypes.contains(typeId)) sortedTypes.insert(0, typeId);
    return AlertDialog(
      key: const Key('timeline-event-dialog'),
      title: Text(editing ? 'Edit Timeline Event' : 'Create Timeline Event'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('timeline-event-title-field'),
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('timeline-event-type-field'),
                initialValue: typeId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Type',
                  helperText: editing
                      ? 'A record keeps its type; duplicate it to change type.'
                      : null,
                ),
                items: [
                  for (final id in sortedTypes)
                    DropdownMenuItem(
                      value: id,
                      child: Text(widget.typeNames[id] ?? id),
                    ),
                ],
                // The shared record service forbids type changes on update.
                onChanged: editing
                    ? null
                    : (value) => setState(() =>
                        typeId = value ?? TimelineRecordTypes.eventTypeId),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('timeline-event-summary-field'),
                controller: summaryController,
                decoration: const InputDecoration(labelText: 'Summary'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('timeline-event-description-field'),
                controller: descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('timeline-event-start-year-field'),
                      controller: startYearController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Start year'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('timeline-event-start-month-field'),
                      controller: startMonthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Month'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('timeline-event-start-day-field'),
                      controller: startDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Day'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('timeline-event-end-year-field'),
                      controller: endYearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'End year'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: endMonthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Month'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: endDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Day'),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                key: const Key('timeline-event-approximate-field'),
                value: approximate,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Approximate date'),
                onChanged: (value) =>
                    setState(() => approximate = value ?? false),
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('timeline-event-status-field'),
                      initialValue: status,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final option in statusOptions)
                          DropdownMenuItem(
                              value: option, child: Text(option)),
                      ],
                      onChanged: (value) =>
                          setState(() => status = value ?? 'draft'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('timeline-event-importance-field'),
                      initialValue: importance,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Importance'),
                      items: [
                        for (final option in importanceOptions)
                          DropdownMenuItem(
                              value: option, child: Text(option)),
                      ],
                      onChanged: (value) =>
                          setState(() => importance = value ?? 'normal'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CanonStatus>(
                key: const Key('timeline-event-canon-field'),
                initialValue: canonStatus,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Canon'),
                items: [
                  for (final option in CanonStatus.values)
                    DropdownMenuItem(value: option, child: Text(option.name)),
                ],
                onChanged: (value) =>
                    setState(() => canonStatus = value ?? CanonStatus.draft),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('timeline-event-tags-field'),
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  helperText: 'Comma separated',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('timeline-event-notes-field'),
                controller: notesController,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              if (validationMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  validationMessage!,
                  key: const Key('timeline-event-dialog-error'),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('timeline-event-save-button'),
          onPressed: _submit,
          child: Text(editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

TimelineDate? _startDate(AuthorRecord record) =>
    _dateFrom(record.fields['start']);

TimelineDate? _endDate(AuthorRecord record) => _dateFrom(record.fields['end']);

TimelineDate? _dateFrom(Object? value) {
  final Object? json = value is List && value.isNotEmpty ? value.first : value;
  if (json is! Map) return null;
  final map = Map<String, Object?>.from(json);
  if ((map['calendarId'] as String? ?? '').isEmpty) return null;
  return TimelineDate.fromJson(map);
}
