import 'package:flutter/material.dart';

import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

enum ContinuityWarningType {
  unknownCharacter,
  unknownLocation,
  missingPovPresence,
  characterOverlap,
  impossibleTravel,
  invalidRange,
  impossibleSequence,
  missingRelationship,
}

enum ContinuitySeverity { notice, warning, critical }

enum ContinuityActionKind { create, link, review }

class ContinuityEventSnapshot {
  const ContinuityEventSnapshot({
    required this.id,
    required this.title,
    required this.startDay,
    required this.endDay,
    required this.order,
    required this.pov,
    required this.plotline,
    required this.presentCharacters,
    this.dateLabel = '',
    this.type = 'Plot',
    this.location = '',
    this.travelDaysFromPrevious = 0,
  });

  final String id;
  final String title;
  final int startDay;
  final int endDay;
  final int order;
  final String pov;
  final String plotline;
  final List<String> presentCharacters;
  final String dateLabel;
  final String type;
  final String location;
  final int travelDaysFromPrevious;
}

class ContinuityWarning {
  const ContinuityWarning({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.eventIds,
  });

  final ContinuityWarningType type;
  final ContinuitySeverity severity;
  final String title;
  final String message;
  final List<String> eventIds;
}

class ContinuityIntegrityIssue {
  const ContinuityIntegrityIssue({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.recommendation,
    required this.eventIds,
  });

  final ContinuityWarningType type;
  final ContinuitySeverity severity;
  final String title;
  final String message;
  final String recommendation;
  final List<String> eventIds;

  ContinuityActionKind get actionKind => switch (type) {
        ContinuityWarningType.unknownCharacter ||
        ContinuityWarningType.unknownLocation =>
          ContinuityActionKind.create,
        ContinuityWarningType.missingRelationship => ContinuityActionKind.link,
        _ => ContinuityActionKind.review,
      };
}

class ContinuityIntegritySummary {
  const ContinuityIntegritySummary({
    required this.score,
    required this.criticalCount,
    required this.warningCount,
    required this.noticeCount,
    required this.issues,
  });

  final int score;
  final int criticalCount;
  final int warningCount;
  final int noticeCount;
  final List<ContinuityIntegrityIssue> issues;
}

class ContinuityAnalyzer {
  const ContinuityAnalyzer();

  static String _recommendationFor(ContinuityWarning warning) {
    switch (warning.type) {
      case ContinuityWarningType.unknownCharacter:
        return 'Add the character to your project roster or remove them from the scene to keep the cast accurate.';
      case ContinuityWarningType.unknownLocation:
        return 'Add this location to the Story Codex or update the scene reference so the world map stays consistent.';
      case ContinuityWarningType.missingPovPresence:
        return 'Assign the POV to a present character or change the scene POV so the narrative perspective remains consistent.';
      case ContinuityWarningType.characterOverlap:
        return 'Adjust one scene timeline or remove the duplicate character from the conflicting event to preserve story logic.';
      case ContinuityWarningType.impossibleTravel:
        return 'Increase travel time between locations or correct the route so the character can plausibly reach the next event.';
      case ContinuityWarningType.invalidRange:
        return 'Fix the start and end day values so the scene timeline never ends before it begins.';
      case ContinuityWarningType.impossibleSequence:
        return 'Reorder the event chronology so the sequence follows the actual story timeline.';
      case ContinuityWarningType.missingRelationship:
        return 'Link the existing records so their relationship is represented with stable IDs.';
    }
  }

  static ContinuityIntegritySummary summaryFor(
      List<ContinuityWarning> warnings) {
    final issues = warnings
        .map((warning) => ContinuityIntegrityIssue(
              type: warning.type,
              severity: warning.severity,
              title: warning.title,
              message: warning.message,
              recommendation: _recommendationFor(warning),
              eventIds: warning.eventIds,
            ))
        .toList();

    final criticalCount = warnings
        .where((warning) => warning.severity == ContinuitySeverity.critical)
        .length;
    final warningCount = warnings
        .where((warning) => warning.severity == ContinuitySeverity.warning)
        .length;
    final noticeCount = warnings
        .where((warning) => warning.severity == ContinuitySeverity.notice)
        .length;

    final score =
        (100 - (criticalCount * 25) - (warningCount * 10) - (noticeCount * 4))
            .clamp(0, 100);

    return ContinuityIntegritySummary(
      score: score,
      criticalCount: criticalCount,
      warningCount: warningCount,
      noticeCount: noticeCount,
      issues: issues,
    );
  }

  List<ContinuityWarning> analyze(
    List<ContinuityEventSnapshot> events, {
    Iterable<String>? knownCharacters,
    Iterable<String>? knownLocations,
  }) {
    final warnings = <ContinuityWarning>[];
    final knownCharacterSet = knownCharacters?.toSet();
    final knownLocationSet = knownLocations?.toSet();
    final byOrder = [...events]
      ..sort((left, right) => left.order.compareTo(right.order));

    for (final event in byOrder) {
      final unknownCharacters = knownCharacterSet == null
          ? <String>[]
          : event.presentCharacters
              .where((character) => !knownCharacterSet.contains(character))
              .toSet()
              .toList()
        ..sort();
      if (unknownCharacters.isNotEmpty) {
        warnings.add(ContinuityWarning(
          type: ContinuityWarningType.unknownCharacter,
          severity: ContinuitySeverity.warning,
          title: 'Unknown character presence',
          message:
              '${unknownCharacters.join(', ')} is marked present in ${event.title} but is not in the project roster.',
          eventIds: [event.id],
        ));
      }

      if (event.location.isNotEmpty && knownLocationSet != null) {
        final normalizedLocation = event.location.trim();
        final normalizedMatches = {
          normalizedLocation,
          normalizedLocation.toLowerCase(),
          normalizedLocation.toUpperCase(),
          normalizedLocation.split(RegExp(r'\s+')).map((part) {
            if (part.isEmpty) {
              return part;
            }
            return part[0].toUpperCase() + part.substring(1).toLowerCase();
          }).join(' '),
        };
        if (!normalizedMatches.any(knownLocationSet.contains)) {
          warnings.add(ContinuityWarning(
            type: ContinuityWarningType.unknownLocation,
            severity: ContinuitySeverity.warning,
            title: 'Unknown world location',
            message:
                '${event.location} is referenced by ${event.title} but is not in the Story Codex or project world database.',
            eventIds: [event.id],
          ));
        }
      }

      if (event.endDay < event.startDay) {
        warnings.add(ContinuityWarning(
          type: ContinuityWarningType.invalidRange,
          severity: ContinuitySeverity.critical,
          title: 'Impossible date range',
          message:
              '${event.title} ends on Day ${event.endDay} before it starts on Day ${event.startDay}.',
          eventIds: [event.id],
        ));
      }

      if (event.pov.isNotEmpty &&
          !event.presentCharacters.contains(event.pov)) {
        warnings.add(ContinuityWarning(
          type: ContinuityWarningType.missingPovPresence,
          severity: ContinuitySeverity.warning,
          title: 'POV character is absent',
          message:
              '${event.pov} is the POV for ${event.title} but is not marked present.',
          eventIds: [event.id],
        ));
      }
    }

    for (var index = 1; index < byOrder.length; index++) {
      final previous = byOrder[index - 1];
      final current = byOrder[index];
      if (current.startDay < previous.startDay) {
        warnings.add(ContinuityWarning(
          type: ContinuityWarningType.impossibleSequence,
          severity: ContinuitySeverity.warning,
          title: 'Timeline order moves backward',
          message:
              '${current.title} is ordered after ${previous.title}, but starts earlier.',
          eventIds: [previous.id, current.id],
        ));
      }
    }

    for (var leftIndex = 0; leftIndex < events.length; leftIndex++) {
      final left = events[leftIndex];
      if (left.endDay < left.startDay) {
        continue;
      }

      for (var rightIndex = leftIndex + 1;
          rightIndex < events.length;
          rightIndex++) {
        final right = events[rightIndex];
        if (right.endDay < right.startDay || left.plotline == right.plotline) {
          continue;
        }

        final overlaps =
            left.startDay <= right.endDay && right.startDay <= left.endDay;
        if (!overlaps) {
          continue;
        }

        final sharedCharacters = left.presentCharacters
            .where(right.presentCharacters.contains)
            .toSet()
            .toList()
          ..sort();
        if (sharedCharacters.isEmpty) {
          continue;
        }

        warnings.add(ContinuityWarning(
          type: ContinuityWarningType.characterOverlap,
          severity: ContinuitySeverity.critical,
          title: 'Character appears in overlapping events',
          message:
              '${sharedCharacters.join(', ')} cannot be in ${left.title} and ${right.title} during the same time range.',
          eventIds: [left.id, right.id],
        ));
      }
    }

    final characters =
        events.expand((event) => event.presentCharacters).toSet();
    for (final character in characters) {
      final appearances = events
          .where((event) =>
              event.presentCharacters.contains(character) &&
              event.endDay >= event.startDay)
          .toList()
        ..sort((left, right) {
          final byDay = left.startDay.compareTo(right.startDay);
          return byDay != 0 ? byDay : left.order.compareTo(right.order);
        });

      for (var index = 1; index < appearances.length; index++) {
        final previous = appearances[index - 1];
        final current = appearances[index];
        if (previous.location.isEmpty ||
            current.location.isEmpty ||
            previous.location == current.location ||
            current.travelDaysFromPrevious <= 0) {
          continue;
        }

        final availableDays = current.startDay - previous.endDay;
        if (availableDays >= current.travelDaysFromPrevious) {
          continue;
        }

        warnings.add(ContinuityWarning(
          type: ContinuityWarningType.impossibleTravel,
          severity: ContinuitySeverity.critical,
          title: 'Impossible character travel',
          message:
              '$character has $availableDays day${availableDays == 1 ? '' : 's'} to travel from ${previous.location} to ${current.location}, but ${current.travelDaysFromPrevious} are required.',
          eventIds: [previous.id, current.id],
        ));
      }
    }

    return warnings;
  }
}

enum TimelineLaneMode { pov, plotline }

class ContinuityTimelinePanel extends StatefulWidget {
  const ContinuityTimelinePanel({
    super.key,
    required this.events,
    required this.warnings,
    this.selectedEventId,
    this.onEventSelected,
    this.onRecommendationSelected,
  });

  final List<ContinuityEventSnapshot> events;
  final List<ContinuityWarning> warnings;
  final String? selectedEventId;
  final ValueChanged<String>? onEventSelected;
  final ValueChanged<ContinuityIntegrityIssue>? onRecommendationSelected;

  @override
  State<ContinuityTimelinePanel> createState() =>
      _ContinuityTimelinePanelState();
}

class _ContinuityTimelinePanelState extends State<ContinuityTimelinePanel> {
  static const pageSize = 20;
  static const zoomLevels = [32.0, 52.0, 76.0];
  TimelineLaneMode laneMode = TimelineLaneMode.pov;
  String? povFilter;
  String? plotlineFilter;
  int visibleEventCount = pageSize;
  int zoomIndex = 1;

  List<ContinuityEventSnapshot> get filteredEvents {
    final filtered = widget.events.where((event) {
      return (povFilter == null || event.pov == povFilter) &&
          (plotlineFilter == null || event.plotline == plotlineFilter);
    }).toList()
      ..sort((left, right) {
        final byDay = left.startDay.compareTo(right.startDay);
        return byDay != 0 ? byDay : left.order.compareTo(right.order);
      });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final semantic = AuthorOsSemanticColors.of(context);
    final integrity = ContinuityAnalyzer.summaryFor(widget.warnings);
    final povs = widget.events
        .map((event) => event.pov)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final plotlines = widget.events
        .map((event) => event.plotline)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final currentEvents = filteredEvents;
    final laneNames = currentEvents
        .map((event) => laneMode == TimelineLaneMode.pov
            ? (event.pov.isEmpty ? 'Unassigned POV' : event.pov)
            : (event.plotline.isEmpty ? 'Unassigned Plotline' : event.plotline))
        .toSet()
        .toList()
      ..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_outlined,
                      color: semantic.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Continuity intelligence',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: integrity.score >= 80
                          ? semantic.success.withValues(alpha: 0.18)
                          : integrity.score >= 50
                              ? semantic.warning.withValues(alpha: 0.18)
                              : semantic.error.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: integrity.score >= 80
                            ? semantic.success
                            : integrity.score >= 50
                                ? semantic.warning
                                : semantic.error,
                      ),
                    ),
                    child: Text(
                      '${integrity.score}/100 story integrity',
                      key: const Key('continuity-integrity-score'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.warnings.isEmpty)
                Text(
                  'No character presence, overlap, or sequence conflicts detected.',
                  style: TextStyle(color: semantic.success),
                )
              else ...[
                Text(
                  '${widget.warnings.length} warning${widget.warnings.length == 1 ? '' : 's'} · ${integrity.criticalCount} critical · ${integrity.warningCount} warnings',
                  key: const Key('continuity-warning-count'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                for (final issue in integrity.issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      key: Key('continuity-warning-${issue.type.name}'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: issue.severity == ContinuitySeverity.critical
                            ? semantic.error.withValues(alpha: 0.12)
                            : semantic.warning.withValues(alpha: 0.12),
                        border: Border.all(
                          color: issue.severity == ContinuitySeverity.critical
                              ? semantic.error
                              : semantic.warning,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                            issue.message,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  'Next step: ${issue.recommendation}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (widget.onRecommendationSelected != null) ...[
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  key: Key(
                                    'continuity-action-${issue.actionKind.name}-${issue.type.name}-${issue.eventIds.join('-')}',
                                  ),
                                  onPressed: () =>
                                      widget.onRecommendationSelected!(issue),
                                  icon: Icon(switch (issue.actionKind) {
                                    ContinuityActionKind.create =>
                                      Icons.add_circle_outline,
                                    ContinuityActionKind.link => Icons.link,
                                    ContinuityActionKind.review =>
                                      Icons.rate_review_outlined,
                                  }),
                                  label: Text(switch (issue.actionKind) {
                                    ContinuityActionKind.create => 'Create',
                                    ContinuityActionKind.link => 'Link',
                                    ContinuityActionKind.review => 'Review',
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Timeline lanes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<TimelineLaneMode>(
                    key: const Key('timeline-lane-mode'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: TimelineLaneMode.pov,
                        label: Text('By POV'),
                      ),
                      ButtonSegment(
                        value: TimelineLaneMode.plotline,
                        label: Text('By plotline'),
                      ),
                    ],
                    selected: {laneMode},
                    onSelectionChanged: (selection) => setState(() {
                      laneMode = selection.first;
                      visibleEventCount = pageSize;
                    }),
                  ),
                  _LaneFilter(
                    fieldKey: ValueKey('continuity-pov-${povFilter ?? 'all'}'),
                    label: 'POV',
                    value: povFilter,
                    values: povs,
                    onChanged: (value) => setState(() {
                      povFilter = value;
                      visibleEventCount = pageSize;
                    }),
                  ),
                  _LaneFilter(
                    fieldKey: ValueKey(
                        'continuity-plotline-${plotlineFilter ?? 'all'}'),
                    label: 'Plotline',
                    value: plotlineFilter,
                    values: plotlines,
                    onChanged: (value) => setState(() {
                      plotlineFilter = value;
                      visibleEventCount = pageSize;
                    }),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      povFilter = null;
                      plotlineFilter = null;
                      visibleEventCount = pageSize;
                    }),
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('Clear lane filters'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${currentEvents.length} of ${widget.events.length} timeline events',
                key: const Key('continuity-lane-count'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    key: const Key('timeline-zoom-out'),
                    tooltip: 'Zoom out',
                    onPressed: zoomIndex == 0
                        ? null
                        : () => setState(() => zoomIndex--),
                    icon: const Icon(Icons.zoom_out),
                  ),
                  IconButton(
                    key: const Key('timeline-zoom-in'),
                    tooltip: 'Zoom in',
                    onPressed: zoomIndex == zoomLevels.length - 1
                        ? null
                        : () => setState(() => zoomIndex++),
                    icon: const Icon(Icons.zoom_in),
                  ),
                  TextButton.icon(
                    key: const Key('timeline-fit-events'),
                    onPressed: () => setState(() => zoomIndex = 0),
                    icon: const Icon(Icons.fit_screen_outlined),
                    label: const Text('Fit events'),
                  ),
                  Text(
                    '${zoomLevels[zoomIndex].round()} px/day',
                    key: const Key('timeline-zoom-label'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _LayeredTimeline(
                laneNames: laneNames,
                events: currentEvents.take(visibleEventCount).toList(),
                laneMode: laneMode,
                dayWidth: zoomLevels[zoomIndex],
                warnings: widget.warnings,
                selectedEventId: widget.selectedEventId,
                onEventSelected: widget.onEventSelected,
              ),
              if (currentEvents.length > visibleEventCount) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('load-more-timeline-events'),
                  onPressed: () =>
                      setState(() => visibleEventCount += pageSize),
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                    'Load ${currentEvents.length - visibleEventCount > pageSize ? pageSize : currentEvents.length - visibleEventCount} more events',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LaneFilter extends StatelessWidget {
  const _LaneFilter({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        key: fieldKey,
        initialValue: value,
        isExpanded: true,
        hint: const Text('All'),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All')),
          ...values.map((value) => DropdownMenuItem(
                value: value,
                child: Text(value, overflow: TextOverflow.ellipsis),
              )),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _LayeredTimeline extends StatelessWidget {
  const _LayeredTimeline({
    required this.laneNames,
    required this.events,
    required this.laneMode,
    required this.dayWidth,
    required this.warnings,
    required this.selectedEventId,
    required this.onEventSelected,
  });

  static const laneHeight = 64.0;
  static const labelWidth = 150.0;
  static const axisHeight = 38.0;

  final List<String> laneNames;
  final List<ContinuityEventSnapshot> events;
  final TimelineLaneMode laneMode;
  final double dayWidth;
  final List<ContinuityWarning> warnings;
  final String? selectedEventId;
  final ValueChanged<String>? onEventSelected;

  String laneFor(ContinuityEventSnapshot event) =>
      laneMode == TimelineLaneMode.pov
          ? (event.pov.isEmpty ? 'Unassigned POV' : event.pov)
          : (event.plotline.isEmpty ? 'Unassigned Plotline' : event.plotline);

  /// Link categories resolve through the theme's categorical ramp.
  ///
  /// `Political`/`War` deliberately uses a ramp slot rather than the `error`
  /// status role: a political link is a kind of thing, not a failure, and the
  /// two must stay free to diverge even though they share a value today.
  Color colorFor(BuildContext context, String type) {
    final ramp = AuthorOsSemanticColors.of(context);
    return switch (type) {
      'Character' ||
      'Relationship' =>
        ramp.category(ThemeCategoryRef.category2),
      'World' || 'Discovery' => ramp.category(ThemeCategoryRef.category6),
      'Political' || 'War' => ramp.category(ThemeCategoryRef.category7),
      'Historical' => ramp.category(ThemeCategoryRef.category8),
      _ => ramp.category(ThemeCategoryRef.category3),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (laneNames.isEmpty || events.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('No timeline events match the lane filters.'),
        ),
      );
    }

    final minimumDay = events
            .map((event) => event.startDay)
            .reduce((left, right) => left < right ? left : right) -
        1;
    final maximumDay = events
            .map((event) =>
                event.endDay < event.startDay ? event.startDay : event.endDay)
            .reduce((left, right) => left > right ? left : right) +
        1;
    final dayCount = maximumDay - minimumDay + 1;
    final canvasWidth = dayCount * dayWidth;
    final warningIds = warnings.expand((warning) => warning.eventIds).toSet();

    return Container(
      key: const Key('layered-timeline-canvas'),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Column(
              children: [
                Container(
                  height: axisHeight,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    'Day $minimumDay to $maximumDay',
                    key: const Key('timeline-visible-range'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final laneName in laneNames)
                  Container(
                    key: Key('timeline-lane-$laneName'),
                    height: laneHeight,
                    width: labelWidth,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Text(
                      laneName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('timeline-horizontal-scroll'),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: canvasWidth,
                child: Column(
                  children: [
                    SizedBox(
                      height: axisHeight,
                      child: Stack(
                        children: [
                          for (var day = minimumDay; day <= maximumDay; day++)
                            Positioned(
                              left: (day - minimumDay) * dayWidth,
                              width: dayWidth,
                              height: axisHeight,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  border: Border(
                                    left: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final laneName in laneNames)
                      SizedBox(
                        height: laneHeight,
                        child: Stack(
                          key: Key('timeline-track-$laneName'),
                          children: [
                            for (var day = minimumDay; day <= maximumDay; day++)
                              Positioned(
                                left: (day - minimumDay) * dayWidth,
                                width: dayWidth,
                                height: laneHeight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    border: Border(
                                      top: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                      left: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            for (final event in events
                                .where((item) => laneFor(item) == laneName))
                              _TimelineEventBar(
                                event: event,
                                minimumDay: minimumDay,
                                dayWidth: dayWidth,
                                color: colorFor(context, event.type),
                                hasWarning: warningIds.contains(event.id),
                                isSelected: selectedEventId == event.id,
                                onTap: onEventSelected == null
                                    ? null
                                    : () => onEventSelected!(event.id),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineEventBar extends StatelessWidget {
  const _TimelineEventBar({
    required this.event,
    required this.minimumDay,
    required this.dayWidth,
    required this.color,
    required this.hasWarning,
    required this.isSelected,
    required this.onTap,
  });

  final ContinuityEventSnapshot event;
  final int minimumDay;
  final double dayWidth;
  final Color color;
  final bool hasWarning;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final endDay =
        event.endDay < event.startDay ? event.startDay : event.endDay;
    final width = (endDay - event.startDay + 1) * dayWidth - 6;
    final dayText = event.startDay == event.endDay
        ? 'Day ${event.startDay}'
        : 'Day ${event.startDay}-${event.endDay}';

    return Positioned(
      left: (event.startDay - minimumDay) * dayWidth + 3,
      top: 9,
      width: width < 26 ? 26 : width,
      height: 46,
      child: Tooltip(
        message:
            '${event.title}\n${event.dateLabel.isEmpty ? dayText : event.dateLabel}\n${event.pov.isEmpty ? 'No POV' : event.pov} | ${event.plotline}',
        child: Material(
          color: color.withValues(alpha: isSelected ? 0.42 : 0.24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: hasWarning
                  ? AuthorOsSemanticColors.of(context).error
                  : color,
              width: isSelected || hasWarning ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: Key('timeline-lane-event-${event.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Row(
                children: [
                  if (hasWarning) ...[
                    Icon(
                      Icons.warning_amber_rounded,
                      key: const Key('timeline-event-warning'),
                      size: 14,
                      color: AuthorOsSemanticColors.of(context).error,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
