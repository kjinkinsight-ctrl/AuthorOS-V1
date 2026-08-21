import 'package:flutter/material.dart';

import 'core/connected_domain.dart';
import 'core/timeline_record_types.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';
import 'timeline_domain.dart';
import 'timeline_service.dart';

class TimelineStudioView extends StatefulWidget {
  const TimelineStudioView({
    super.key,
    required this.project,
    this.repository,
    this.service,
  });

  final StarterProject project;
  final DriftConnectedDomainRepository? repository;
  final TimelineService? service;

  @override
  State<TimelineStudioView> createState() => _TimelineStudioViewState();
}

class _TimelineStudioViewState extends State<TimelineStudioView> {
  bool _loading = true;
  String? _error;
  List<AuthorRecord> _events = const [];

  late final TimelineService _service = widget.service ??
      TimelineService(
        projectId: widget.project.id,
        repository: widget.repository ?? authorOsRepository,
      );

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final records = await _service.query.all();
      if (!mounted) return;
      setState(() {
        _events = records
            .where((record) => record.status != AuthorRecordStatus.deleted)
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<AuthorRecord> get _chronologicalEvents {
    final ordered = [..._events];
    ordered.sort((left, right) {
      final leftDate = _startDate(left);
      final rightDate = _startDate(right);
      final leftOrdinal = _dateOrdinal(leftDate);
      final rightOrdinal = _dateOrdinal(rightDate);

      final byDate = leftOrdinal.compareTo(rightOrdinal);
      if (byDate != 0) return byDate;
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });
    return ordered;
  }

  TimelineDate? _startDate(AuthorRecord record) {
    final raw = record.fields['start'];
    if (raw is! List || raw.isEmpty) {
      return null;
    }
    final first = raw.first;
    if (first is! Map) {
      return null;
    }
    final map = Map<String, Object?>.from(first);
    final calendarId = map['calendarId'] as String? ?? '';
    if (calendarId.isEmpty) {
      return null;
    }
    return TimelineDate.fromJson(map);
  }

  int _dateOrdinal(TimelineDate? date) {
    if (date == null) return 0;
    final year = date.year ?? 0;
    final month = date.month ?? 1;
    final day = date.day ?? 1;
    return year * 10000 + month * 100 + day;
  }

  Future<void> _createEvent() async {
    final titleController = TextEditingController();
    final summaryController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Event'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Event title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summaryController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                ),
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
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'summary': summaryController.text.trim(),
            }),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    final title = result?['title'] ?? '';
    final summary = result?['summary'] ?? '';
    if (title.isEmpty || !mounted) return;

    final eventId = 'timeline-event-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _service.createEvent(
        TimelineEventDraft(
          id: eventId,
          name: title,
          summary: summary,
          typeId: TimelineRecordTypes.eventTypeId,
          status: 'planned',
        ),
      );
      await _reload();
    } on ArgumentError catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    }
  }

  Future<void> _editEvent(AuthorRecord record) async {
    final titleController = TextEditingController(text: record.title);
    final summaryController = TextEditingController(
      text: (record.fields['summary'] as String?) ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Event'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Event title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summaryController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                ),
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
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'summary': summaryController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final title = result?['title'] ?? '';
    if (title.isEmpty || !mounted) return;

    final updated = record.copyWith(
      title: title,
      fields: {
        ...record.fields,
        'summary': result?['summary'] ?? '',
        'description': result?['summary'] ?? '',
        'temporalStatus': 'planned',
      },
      updatedAt: DateTime.now().toUtc(),
    );

    try {
      await _service.updateTimelineRecord(updated);
      await _reload();
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    }
  }

  Future<void> _deleteEvent(AuthorRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Delete "${record.title}" from the current project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.records.deleteRecord(record.id);
      await _reload();
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final surface = scope.color(ThemeColorRef.surface);
    final surfaceContainer = scope.color(ThemeColorRef.surfaceContainer);
    final outlineVariant = scope.color(ThemeColorRef.outlineVariant);
    final onSurface = scope.color(ThemeColorRef.onSurface);
    final onSurfaceVariant = scope.color(ThemeColorRef.onSurfaceVariant);
    final primary = scope.color(ThemeColorRef.primary);
    final heading = scope.text(ThemeTextRole.heading, colorRef: ThemeColorRef.onSurface);
    final body = scope.text(ThemeTextRole.body, colorRef: ThemeColorRef.onSurfaceVariant);
    final label = scope.text(ThemeTextRole.label, colorRef: ThemeColorRef.onSurface);

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Timeline unavailable', style: heading),
                  const SizedBox(height: 8),
                  Text(_error!, style: body),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final events = _chronologicalEvents;

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Card(
            color: surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timeline_outlined,
                    size: 44,
                    color: primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your story has no events yet.',
                    style: heading,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create the first milestone, turning point, or historical beat for this project.',
                    textAlign: TextAlign.center,
                    style: body,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _createEvent,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Event'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Timeline Studio',
                    style: scope.text(ThemeTextRole.heading, colorRef: ThemeColorRef.onSurface),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _createEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Event'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final event = events[index];
                final date = _humanDate(event);
                final type = event.typeId
                    .split('-')
                    .map((part) => part.isEmpty
                        ? ''
                        : part[0].toUpperCase() + part.substring(1))
                    .join(' ');
                final summary = (event.fields['summary'] as String?) ??
                    (event.fields['description'] as String?) ??
                    'No summary yet.';

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: surface,
                                width: 2,
                              ),
                            ),
                          ),
                          if (index < events.length - 1)
                            Container(
                              width: 2,
                              height: 60,
                              margin: const EdgeInsets.only(top: 8),
                              color: outlineVariant,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        color: surfaceContainer,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: scope.text(
                                        ThemeTextRole.ui,
                                        colorRef: ThemeColorRef.onSurface,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Event actions',
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'edit':
                                          _editEvent(event);
                                          break;
                                        case 'delete':
                                          _deleteEvent(event);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                date,
                                style: scope.text(
                                  ThemeTextRole.label,
                                  colorRef: ThemeColorRef.primary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(type,
                                        style: label.copyWith(fontWeight: FontWeight.w600)),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: surface,
                                    side: BorderSide(color: outlineVariant),
                                  ),
                                  Chip(
                                    label: Text(
                                      (event.fields['temporalStatus'] as String?) ??
                                          'planned',
                                      style: label.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: surface,
                                    side: BorderSide(color: outlineVariant),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                summary,
                                style: scope.text(
                                  ThemeTextRole.body,
                                  colorRef: ThemeColorRef.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _humanDate(AuthorRecord record) {
    final date = _startDate(record);
    if (date == null) {
      return 'Date pending';
    }

    final parts = <String>[];
    if (date.year != null) parts.add('Y${date.year}');
    if (date.month != null) parts.add('M${date.month}');
    if (date.day != null) parts.add('D${date.day}');
    if (parts.isEmpty) {
      return 'Date pending';
    }
    return parts.join(' · ');
  }
}
