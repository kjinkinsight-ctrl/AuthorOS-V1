/// Analytics Studio — the presentation layer.
///
/// Renders the [AnalyticsSummary] the service derives from canonical data.
/// The view performs no calculations of its own: the service produces the
/// summary once per load, and `build` only lays the values out. All colours
/// and text styles come from the Theme Engine through [StudioThemeScope] and
/// `Theme.of(context)` — this Studio owns no palette.
library;

import 'package:flutter/material.dart';

import 'analytics_service.dart';
import 'core/writing_goals.dart';
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';
import 'writing_goals_store.dart';
import 'world_board/world_board_models.dart' show formatWorldBoardCount;

/// Writing time in the compact form the history tiles use: `4h 12m`, `42m`,
/// `0m`. Seconds are never shown — a writing session is not a stopwatch.
String formatWritingDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  if (totalMinutes <= 0) return '0m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// A projected completion day in the author's own calendar: `6 October 2026`.
///
/// Read from the local date fields rather than through `toUtc()`: the
/// projection is a local midnight, and converting it would slide the date to
/// the previous day for every author west of Greenwich.
String formatProjectionDate(DateTime day) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  final local = day.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// A words-per-period rate as a whole number, or an em dash when the rate is
/// absent. A rate AuthorOS could not measure is never shown as zero.
String formatVelocity(double? rate) =>
    rate == null ? '—' : formatWorldBoardCount(rate.round());

class AnalyticsStudioView extends StatefulWidget {
  const AnalyticsStudioView({
    super.key,
    required this.project,
    this.repository,
    this.service,
    this.manuscriptStore = const ManuscriptStore(),
    this.goalsStore,
  });

  final StarterProject project;
  final DriftConnectedDomainRepository? repository;
  final AnalyticsService? service;
  final ManuscriptStore manuscriptStore;

  /// Where edited goals are saved. Defaults to the service's own store, so
  /// the Studio writes goals back to whichever repository it reads them from.
  final WritingGoalsStore? goalsStore;

  @override
  State<AnalyticsStudioView> createState() => _AnalyticsStudioViewState();
}

class _AnalyticsStudioViewState extends State<AnalyticsStudioView> {
  late final AnalyticsService service;
  late final WritingGoalsStore goalsStore;

  bool loading = true;
  String? loadError;
  AnalyticsSummary? summary;

  @override
  void initState() {
    super.initState();
    service = widget.service ??
        AnalyticsService(
          project: widget.project,
          repository: widget.repository,
          manuscriptStore: widget.manuscriptStore,
        );
    // Falls back to the service's own store, so goals are written back to
    // whichever repository the summary was read from.
    goalsStore = widget.goalsStore ?? service.goalsStore;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final loaded = await service.getSummary();
      if (!mounted) return;
      setState(() {
        summary = loaded;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = 'Analytics could not be calculated: $error';
        loading = false;
      });
    }
  }

  /// Opens the goals editor and, when the author saves, stores the new
  /// targets and reloads.
  ///
  /// Saving goes through the store rather than the analytics service: the
  /// service derives and must never write. The reload is the ordinary
  /// [_load], so every number on the page re-derives together and the goal
  /// bars can never show a target the rest of the page has not caught up to.
  Future<void> _editGoals() async {
    final current = summary?.writingGoals;
    if (current == null) return;
    final result = await showDialog<_GoalsEdit>(
      context: context,
      builder: (context) => _GoalsDialog(goals: current),
    );
    if (result == null || !mounted) return;
    try {
      if (result.restoreDefaults) {
        await goalsStore.restoreDefaults(widget.project.id);
      } else {
        await goalsStore.save(result.goals);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = 'Writing goals could not be saved: $error';
        loading = false;
      });
      return;
    }
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    final content = _buildStudio(context);
    if (scope == null) return content;
    // Layer this Studio's theme overrides on top of the shell theme; the
    // engine and its tokens stay the single source of truth.
    return StudioThemeScope(
      theme: scope.theme,
      studio: StudioId.analytics,
      child: Builder(builder: _buildStudio),
    );
  }

  Widget _buildStudio(BuildContext context) {
    if (loading) {
      return Column(
        key: const Key('analytics-loading'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsHeader(onRefresh: _load),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 96),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    final error = loadError;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalyticsHeader(onRefresh: _load),
          const SizedBox(height: 16),
          _AnalyticsMessageCard(
            key: const Key('analytics-error'),
            icon: Icons.error_outline,
            title: 'Analytics unavailable',
            message: error,
            action: TextButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }
    final data = summary!;
    return Column(
      key: const Key('analytics-studio'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnalyticsHeader(onRefresh: _load),
        const SizedBox(height: 16),
        _OverviewTiles(summary: data),
        const SizedBox(height: 18),
        _BasicMetricsCard(summary: data),
        const SizedBox(height: 18),
        _WritingProgressCard(summary: data),
        const SizedBox(height: 18),
        _GoalsCard(summary: data, onEdit: _editGoals),
        const SizedBox(height: 18),
        _ProjectionCard(summary: data),
        const SizedBox(height: 18),
        _VelocityCard(summary: data),
        const SizedBox(height: 18),
        _WritingHistoryCard(summary: data),
        const SizedBox(height: 18),
        _ManuscriptCard(summary: data),
        const SizedBox(height: 18),
        _StoryEcosystemCard(summary: data),
        const SizedBox(height: 18),
        _ProgressCard(summary: data),
      ],
    );
  }
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analytics',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Project performance and writing progress',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const Key('analytics-refresh'),
          tooltip: 'Recalculate analytics',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _OverviewTiles extends StatelessWidget {
  const _OverviewTiles({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = formatWorldBoardCount(summary.totalWordCount);
    final percent = summary.percentTowardTarget;
    return Container(
      key: const Key('analytics-word-count-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatTile(
            label: 'Word Count',
            value: summary.hasWritingTarget
                ? '$words / ${formatWorldBoardCount(summary.targetWordCount)}'
                : words,
            caption: percent == null
                ? 'No writing target set'
                : '${percent.toStringAsFixed(1)}%',
          ),
          _StatTile(
            label: 'Chapters',
            value: formatWorldBoardCount(summary.chapterCount),
          ),
          _StatTile(
            label: 'Characters',
            value: formatWorldBoardCount(summary.characterCount),
          ),
          _StatTile(
            label: 'Research',
            value: formatWorldBoardCount(summary.researchItemCount),
          ),
        ],
      ),
    );
  }
}

class _WritingProgressCard extends StatelessWidget {
  const _WritingProgressCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = summary.progressTowardTarget;
    final remaining = summary.wordsRemaining;
    return _AnalyticsSectionCard(
      key: const Key('analytics-progress-section'),
      title: 'Writing Progress',
      badge: 'Read-only calculations',
      child: progress == null
          ? Text(
              'No writing target set. Set a word goal for this project to '
              'track progress.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _LabeledValue(
                        label: 'Current Words',
                        value: formatWorldBoardCount(summary.totalWordCount),
                      ),
                    ),
                    Expanded(
                      child: _LabeledValue(
                        label: 'Target',
                        value: formatWorldBoardCount(summary.targetWordCount),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledValue(
                  label: 'Words Remaining',
                  value: formatWorldBoardCount(remaining ?? 0),
                ),
              ],
            ),
    );
  }
}

/// The Writing History section.
///
/// Reads only [AnalyticsSummary.writingHistory] — the service has already
/// folded the recorded sessions into it, so nothing here counts, queries, or
/// reaches for a clock. Colours and text styles come from the Theme Engine
/// through `Theme.of(context)`; the bars below are laid out with the same
/// tokens rather than a charting dependency.
class _WritingHistoryCard extends StatelessWidget {
  const _WritingHistoryCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = summary.writingHistory;
    return _AnalyticsSectionCard(
      key: const Key('analytics-writing-history-section'),
      title: 'Writing History',
      badge: 'Recorded sessions',
      child: history.hasSessions
          ? _WritingHistoryBody(history: history)
          : Column(
              key: const Key('analytics-writing-history-empty'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No writing sessions recorded yet.',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Writing history appears here once you write in Manuscript '
                  'Studio. Daily totals, streaks, and session averages are '
                  'built from sessions recorded from now on — AuthorOS does '
                  'not invent history it did not observe.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

class _WritingHistoryBody extends StatelessWidget {
  const _WritingHistoryBody({required this.history});

  final AnalyticsWritingHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perHour = history.averageWordsPerHour;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HistoryTile(
              tileKey: const Key('analytics-history-today'),
              label: 'Today',
              value: '${formatWorldBoardCount(history.wordsToday)} words',
              lines: [
                formatWritingDuration(history.writingTimeToday),
                '${formatWorldBoardCount(history.sessionsToday)} '
                    '${history.sessionsToday == 1 ? 'session' : 'sessions'}',
              ],
            ),
            _HistoryTile(
              tileKey: const Key('analytics-history-streak'),
              label: 'Current streak',
              value: '🔥 ${formatWorldBoardCount(history.currentStreakDays)} '
                  '${history.currentStreakDays == 1 ? 'day' : 'days'}',
              lines: [
                'Longest '
                    '${formatWorldBoardCount(history.longestStreakDays)} '
                    '${history.longestStreakDays == 1 ? 'day' : 'days'}',
                if (history.currentStreakDays == 0)
                  'Write today to start a new streak',
              ],
            ),
            _HistoryTile(
              tileKey: const Key('analytics-history-week'),
              label: 'This week',
              value: '${formatWorldBoardCount(history.wordsThisWeek)} words',
              lines: [
                formatWritingDuration(history.writingTimeThisWeek),
                '${formatWorldBoardCount(history.sessionsThisWeek)} '
                    '${history.sessionsThisWeek == 1 ? 'session' : 'sessions'}',
              ],
            ),
            _HistoryTile(
              tileKey: const Key('analytics-history-average'),
              label: 'Average session',
              value: formatWritingDuration(history.averageSessionDuration),
              lines: [
                '${formatWorldBoardCount(history.averageWordsPerSession)} '
                    'words',
                if (perHour != null)
                  '${formatWorldBoardCount(perHour.round())} words/hour',
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        _WeeklyWritingBars(days: history.dailyTotals),
        const SizedBox(height: 18),
        Text(
          'All time',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          key: const Key('analytics-history-totals'),
          spacing: 24,
          runSpacing: 12,
          children: [
            _LabeledValue(
              label: 'Sessions',
              value: formatWorldBoardCount(history.totalSessions),
            ),
            _LabeledValue(
              label: 'Words Written',
              value: formatWorldBoardCount(history.totalWordsWritten),
            ),
            _LabeledValue(
              label: 'Writing Time',
              value: formatWritingDuration(history.totalWritingTime),
            ),
            _LabeledValue(
              label: 'Longest Session',
              value: formatWritingDuration(history.longestSessionDuration),
            ),
            _LabeledValue(
              label: 'Best Session',
              value:
                  '${formatWorldBoardCount(history.mostProductiveSessionWords)}'
                  ' words',
            ),
            _LabeledValue(
              label: 'This Month',
              value: '${formatWorldBoardCount(history.wordsThisMonth)} words',
            ),
            _LabeledValue(
              label: 'Sessions This Month',
              value: formatWorldBoardCount(history.sessionsThisMonth),
            ),
          ],
        ),
      ],
    );
  }
}

/// The daily totals for the current week, drawn as proportional bars.
///
/// Deliberately hand-laid-out: seven sized boxes need no charting package,
/// and staying in plain widgets keeps every colour on the Theme Engine.
class _WeeklyWritingBars extends StatelessWidget {
  const _WeeklyWritingBars({required this.days});

  final List<AnalyticsWritingDay> days;

  static const _initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _barHeight = 78.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (days.isEmpty) return const SizedBox.shrink();
    var peak = 0;
    for (final day in days) {
      if (day.wordsWritten > peak) peak = day.wordsWritten;
    }
    return Column(
      key: const Key('analytics-history-week-chart'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Words this week',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = 0; index < days.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatWorldBoardCount(days[index].wordsWritten),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: _barHeight,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: peak == 0
                                ? 3
                                : (days[index].wordsWritten / peak * _barHeight)
                                    .clamp(3.0, _barHeight),
                            decoration: BoxDecoration(
                              color: days[index].hasWriting
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _initials[index % _initials.length],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A stat tile with one headline value and a short stack of captions.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.tileKey,
    required this.label,
    required this.value,
    this.lines = const [],
  });

  final Key tileKey;
  final String label;
  final String value;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: tileKey,
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final line in lines) ...[
            const SizedBox(height: 4),
            Text(
              line,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManuscriptCard extends StatelessWidget {
  const _ManuscriptCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final longest = summary.longestChapter;
    final shortest = summary.shortestChapter;
    return _AnalyticsSectionCard(
      key: const Key('analytics-manuscript-section'),
      title: 'Manuscript',
      child: summary.chapterCount == 0
          ? Text(
              'No chapters yet. Chapter analytics appear once the manuscript '
              'has chapters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _LabeledValue(
                      label: 'Chapters',
                      value: formatWorldBoardCount(summary.chapterCount),
                    ),
                    _LabeledValue(
                      label: 'Scenes',
                      value: formatWorldBoardCount(summary.sceneCount),
                    ),
                    _LabeledValue(
                      label: 'Avg Chapter',
                      value:
                          '${formatWorldBoardCount(summary.averageChapterLength)} words',
                    ),
                    _LabeledValue(
                      label: 'Complete',
                      value:
                          formatWorldBoardCount(summary.completedChapterCount),
                    ),
                    _LabeledValue(
                      label: 'Draft',
                      value: formatWorldBoardCount(summary.draftChapterCount),
                    ),
                  ],
                ),
                if (longest != null) ...[
                  const SizedBox(height: 14),
                  _LabeledValue(
                    label: 'Longest Chapter',
                    value:
                        '${longest.title} · ${formatWorldBoardCount(longest.wordCount)} words',
                  ),
                ],
                if (shortest != null) ...[
                  const SizedBox(height: 10),
                  _LabeledValue(
                    label: 'Shortest Chapter',
                    value:
                        '${shortest.title} · ${formatWorldBoardCount(shortest.wordCount)} words',
                  ),
                ],
              ],
            ),
    );
  }
}

class _StoryEcosystemCard extends StatelessWidget {
  const _StoryEcosystemCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = summary.characterCount == 0 &&
        summary.plotRecordCount == 0 &&
        summary.timelineEventCount == 0 &&
        summary.researchItemCount == 0;
    return _AnalyticsSectionCard(
      key: const Key('analytics-ecosystem-section'),
      title: 'Story Ecosystem',
      child: isEmpty
          ? Text(
              'No story records yet. Characters, plot threads, timeline '
              'events, and research appear here as you create them.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _LabeledValue(
                  label: 'Characters',
                  value: formatWorldBoardCount(summary.characterCount),
                ),
                _LabeledValue(
                  label: 'With Profiles',
                  value:
                      formatWorldBoardCount(summary.charactersWithProfiles),
                ),
                _LabeledValue(
                  label: 'With Relationships',
                  value: formatWorldBoardCount(
                    summary.charactersWithRelationships,
                  ),
                ),
                _LabeledValue(
                  label: 'In Manuscript',
                  value: formatWorldBoardCount(
                    summary.charactersReferencedInManuscript,
                  ),
                ),
                _LabeledValue(
                  label: 'Plot Records',
                  value: formatWorldBoardCount(summary.plotRecordCount),
                ),
                _LabeledValue(
                  label: 'Active Threads',
                  value:
                      formatWorldBoardCount(summary.activePlotThreadCount),
                ),
                _LabeledValue(
                  label: 'Completed Threads',
                  value:
                      formatWorldBoardCount(summary.completedPlotThreadCount),
                ),
                _LabeledValue(
                  label: 'Timeline Events',
                  value: formatWorldBoardCount(summary.timelineEventCount),
                ),
                _LabeledValue(
                  label: 'Research Items',
                  value: formatWorldBoardCount(summary.researchItemCount),
                ),
              ],
            ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final percent = summary.completionPercent;
    return _AnalyticsSectionCard(
      key: const Key('analytics-progress-panel'),
      title: 'Progress',
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _LabeledValue(
            label: 'Completion',
            value: percent == null
                ? 'No writing target set'
                : '${percent.toStringAsFixed(1)}%',
          ),
          _LabeledValue(
            label: 'Status',
            value: summary.manuscriptStatus,
          ),
        ],
      ),
    );
  }
}

/// The Basic Metrics section — spec 7.1.
///
/// Six counts the author checks at a glance. Every one is read straight off
/// the summary; nothing here adds, divides, or reaches for a clock.
class _BasicMetricsCard extends StatelessWidget {
  const _BasicMetricsCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final history = summary.writingHistory;
    final remaining = summary.wordsRemaining;
    return _AnalyticsSectionCard(
      key: const Key('analytics-basic-metrics-section'),
      title: 'Writing Metrics',
      badge: 'Read-only calculations',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatTile(
            key: const Key('analytics-metric-words-written'),
            label: 'Words Written',
            value: formatWorldBoardCount(summary.totalWordCount),
            caption: 'Manuscript total',
          ),
          _StatTile(
            key: const Key('analytics-metric-words-remaining'),
            label: 'Words Remaining',
            value: remaining == null ? '—' : formatWorldBoardCount(remaining),
            caption: remaining == null ? 'No writing target set' : null,
          ),
          _StatTile(
            key: const Key('analytics-metric-chapters-complete'),
            label: 'Chapters Complete',
            value: '${formatWorldBoardCount(summary.completedChapterCount)}'
                ' / ${formatWorldBoardCount(summary.chapterCount)}',
          ),
          _StatTile(
            key: const Key('analytics-metric-scenes-complete'),
            label: 'Scenes Complete',
            value: '${formatWorldBoardCount(summary.completedSceneCount)}'
                ' / ${formatWorldBoardCount(summary.sceneCount)}',
          ),
          _StatTile(
            key: const Key('analytics-metric-writing-sessions'),
            label: 'Writing Sessions',
            value: formatWorldBoardCount(history.totalSessions),
            caption:
                history.hasSessions ? null : 'No sessions recorded yet',
          ),
          _StatTile(
            key: const Key('analytics-metric-session-time'),
            label: 'Session Time',
            value: formatWritingDuration(history.totalWritingTime),
          ),
        ],
      ),
    );
  }
}

/// The Goals section — spec 7.2.
///
/// Renders the author's own daily, weekly, and monthly targets and how far
/// through each one this project has got. Unlike the history chart, this card
/// renders with no sessions recorded: `0 / 2,000 words` is a true statement
/// about a target that genuinely exists, not an observation AuthorOS invented.
class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.summary, required this.onEdit});

  final AnalyticsSummary summary;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = summary.goalProgress;
    final goals = progress.goals;
    return _AnalyticsSectionCard(
      key: const Key('analytics-goals-section'),
      title: 'Writing Goals',
      badge: goals.isCustomized ? 'Your targets' : 'Default targets',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Daily, weekly, and monthly word targets for this project.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('analytics-goals-edit'),
                onPressed: onEdit,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Edit goals'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GoalRow(
            key: const Key('analytics-goal-daily'),
            label: 'Daily',
            period: 'daily',
            written: progress.wordsToday,
            goal: goals.dailyWords,
            progress: progress.dailyProgress,
            remaining: progress.dailyWordsRemaining,
            met: progress.dailyGoalMet,
          ),
          const SizedBox(height: 14),
          _GoalRow(
            key: const Key('analytics-goal-weekly'),
            label: 'Weekly',
            period: 'weekly',
            written: progress.wordsThisWeek,
            goal: goals.weeklyWords,
            progress: progress.weeklyProgress,
            remaining: progress.weeklyWordsRemaining,
            met: progress.weeklyGoalMet,
          ),
          const SizedBox(height: 14),
          _GoalRow(
            key: const Key('analytics-goal-monthly'),
            label: 'Monthly',
            period: 'monthly',
            written: progress.wordsThisMonth,
            goal: goals.monthlyWords,
            progress: progress.monthlyProgress,
            remaining: progress.monthlyWordsRemaining,
            met: progress.monthlyGoalMet,
          ),
        ],
      ),
    );
  }
}

/// One cadence's progress bar.
///
/// A target of zero draws no bar at all. A goal the author has not set has no
/// progress to show, and a full-width empty track would read as "0% of a goal"
/// — the same misreading the manuscript target's empty state exists to avoid.
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    super.key,
    required this.label,
    required this.period,
    required this.written,
    required this.goal,
    required this.progress,
    required this.remaining,
    required this.met,
  });

  final String label;
  final String period;
  final int written;
  final int goal;
  final double? progress;
  final int? remaining;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (progress == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No $period goal set',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${formatWorldBoardCount(written)}'
              ' / ${formatWorldBoardCount(goal)} words',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          met
              ? 'Goal met'
              : '${formatWorldBoardCount(remaining ?? 0)} to go',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The Velocity section — spec 7.3.
///
/// Two daily figures sit side by side on purpose. "Average Daily Words"
/// counts every day since the author started, rest days included, because
/// that is the pace the projection below rests on. "On Writing Days" counts
/// only the days they wrote. Both are true; neither is allowed to stand in
/// for the other.
class _VelocityCard extends StatelessWidget {
  const _VelocityCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final velocity = summary.velocity;
    return _AnalyticsSectionCard(
      key: const Key('analytics-velocity-section'),
      title: 'Velocity',
      badge: 'Recorded sessions',
      child: !velocity.hasVelocity
          ? Column(
              key: const Key('analytics-velocity-empty'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No pace to measure yet.',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Velocity is measured from recorded writing sessions. Write '
                  'in Manuscript Studio and your pace appears here — AuthorOS '
                  'does not estimate a speed it has not observed.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _HistoryTile(
                  tileKey: const Key('analytics-velocity-daily'),
                  label: 'Average Daily Words',
                  value: formatVelocity(velocity.averageDailyWords),
                  lines: [
                    'Over ${formatWorldBoardCount(velocity.daysElapsed)} days '
                        'since your first session',
                  ],
                ),
                _HistoryTile(
                  tileKey: const Key('analytics-velocity-writing-day'),
                  label: 'On Writing Days',
                  value: formatVelocity(velocity.averageWordsPerWritingDay),
                  lines: [
                    '${formatWorldBoardCount(velocity.daysWritten)} days '
                        'written on',
                  ],
                ),
                _HistoryTile(
                  tileKey: const Key('analytics-velocity-session'),
                  label: 'Average Session Words',
                  value: formatWorldBoardCount(velocity.averageSessionWords),
                  lines: [
                    '${formatWorldBoardCount(summary.writingHistory.totalSessions)}'
                        ' sessions recorded',
                  ],
                ),
                _HistoryTile(
                  tileKey: const Key('analytics-velocity-hourly'),
                  label: 'Average Words/Hour',
                  value: formatVelocity(velocity.averageWordsPerHour),
                  lines: [
                    if (velocity.averageWordsPerHour == null)
                      'No measurable writing time yet',
                  ],
                ),
                _HistoryTile(
                  tileKey: const Key('analytics-velocity-weekly'),
                  label: 'Weekly Velocity',
                  value: formatVelocity(velocity.weeklyVelocity),
                  lines: const ['At your current daily pace'],
                ),
                _HistoryTile(
                  tileKey: const Key('analytics-velocity-monthly'),
                  label: 'Monthly Velocity',
                  value: formatVelocity(velocity.monthlyVelocity),
                  lines: const ['At your current daily pace'],
                ),
              ],
            ),
    );
  }
}

/// The Manuscript Projection section — spec 7.4.
///
/// The one forward-looking claim AuthorOS makes, and deliberately the most
/// reluctant card on the page: without a target, without a measured pace, or
/// past the target, it says so rather than naming a day it cannot stand behind.
class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projection = summary.projection;
    return _AnalyticsSectionCard(
      key: const Key('analytics-projection-section'),
      title: 'Manuscript Projection',
      badge: 'Estimate',
      child: !projection.hasTarget
          ? Text(
              'No writing target set. Set a word goal for this project to '
              'project a completion date.',
              key: const Key('analytics-projection-empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 28,
                  runSpacing: 14,
                  children: [
                    _LabeledValue(
                      key: const Key('analytics-projection-current'),
                      label: 'Current Words',
                      value: formatWorldBoardCount(projection.currentWords),
                    ),
                    _LabeledValue(
                      key: const Key('analytics-projection-target'),
                      label: 'Target',
                      value:
                          formatWorldBoardCount(projection.targetWords ?? 0),
                    ),
                    _LabeledValue(
                      key: const Key('analytics-projection-remaining'),
                      label: 'Remaining',
                      value:
                          formatWorldBoardCount(projection.wordsRemaining ?? 0),
                    ),
                    _LabeledValue(
                      key: const Key('analytics-projection-velocity'),
                      label: 'Average Velocity',
                      value: projection.averageDailyWords == null
                          ? '—'
                          : '${formatVelocity(projection.averageDailyWords)}'
                              ' words/day',
                    ),
                    _LabeledValue(
                      key: const Key('analytics-projection-date'),
                      label: 'Estimated Completion',
                      value: projection.projectedCompletionDate == null
                          ? '—'
                          : formatProjectionDate(
                              projection.projectedCompletionDate!,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _projectionMessage(context, theme),
              ],
            ),
    );
  }

  Widget _projectionMessage(BuildContext context, ThemeData theme) {
    final projection = summary.projection;
    if (projection.isComplete) {
      return Text(
        'You have reached this manuscript\'s word target. There is nothing '
        'left to project.',
        key: const Key('analytics-projection-complete'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final days = projection.estimatedDaysToCompletion;
    if (days == null) {
      return Text(
        'Not enough writing history to project a completion date yet.',
        key: const Key('analytics-projection-unavailable'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Text(
      'At your current pace, you\'ll complete this manuscript in '
      'approximately ${formatWorldBoardCount(days)} '
      '${days == 1 ? 'day' : 'days'}.',
      key: const Key('analytics-projection-sentence'),
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// What the goals editor hands back: either new targets, or a request to drop
/// the stored ones and return to the seeded defaults.
class _GoalsEdit {
  const _GoalsEdit.save(this.goals) : restoreDefaults = false;
  const _GoalsEdit.restore(this.goals) : restoreDefaults = true;

  final WritingGoals goals;
  final bool restoreDefaults;
}

/// The goals editor.
///
/// Zero is a legal target and means "no goal for this period", so the
/// validators reject only what cannot be a target at all: blanks, non-numbers,
/// negatives, and figures past [WritingGoals.maximumWords].
class _GoalsDialog extends StatefulWidget {
  const _GoalsDialog({required this.goals});

  final WritingGoals goals;

  @override
  State<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends State<_GoalsDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController daily;
  late final TextEditingController weekly;
  late final TextEditingController monthly;

  @override
  void initState() {
    super.initState();
    daily = TextEditingController(text: '${widget.goals.dailyWords}');
    weekly = TextEditingController(text: '${widget.goals.weeklyWords}');
    monthly = TextEditingController(text: '${widget.goals.monthlyWords}');
  }

  @override
  void dispose() {
    daily.dispose();
    weekly.dispose();
    monthly.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return 'Enter a whole number of words.';
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'Enter a whole number of words.';
    if (parsed < 0) return 'A goal cannot be negative.';
    if (parsed > WritingGoals.maximumWords) {
      return 'That is more words than a goal can hold.';
    }
    return null;
  }

  int _read(TextEditingController controller) =>
      int.parse(controller.text.trim());

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _GoalsEdit.save(
        widget.goals.copyWith(
          dailyWords: _read(daily),
          weeklyWords: _read(weekly),
          monthlyWords: _read(monthly),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('analytics-goals-dialog'),
      title: const Text('Writing goals'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How many words you mean to write in this project. Set a target '
              'to 0 to turn that goal off.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            _GoalField(
              fieldKey: const Key('analytics-goal-daily-field'),
              controller: daily,
              label: 'Daily words',
              validator: _validate,
            ),
            const SizedBox(height: 12),
            _GoalField(
              fieldKey: const Key('analytics-goal-weekly-field'),
              controller: weekly,
              label: 'Weekly words',
              validator: _validate,
            ),
            const SizedBox(height: 12),
            _GoalField(
              fieldKey: const Key('analytics-goal-monthly-field'),
              controller: monthly,
              label: 'Monthly words',
              validator: _validate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('analytics-goals-restore'),
          onPressed: () => Navigator.of(context).pop(
            _GoalsEdit.restore(
              WritingGoals.defaultsFor(widget.goals.projectId),
            ),
          ),
          child: const Text('Restore defaults'),
        ),
        TextButton(
          key: const Key('analytics-goals-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('analytics-goals-save'),
          onPressed: _save,
          child: const Text('Save goals'),
        ),
      ],
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.validator,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}

class _AnalyticsSectionCard extends StatelessWidget {
  const _AnalyticsSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.badge,
  });

  final String title;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AnalyticsMessageCard extends StatelessWidget {
  const _AnalyticsMessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: theme.colorScheme.onSurface),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
