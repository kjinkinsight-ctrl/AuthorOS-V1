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
import 'manuscript_store.dart';
import 'onboarding.dart';
import 'persistence/authoros_database.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';
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

class AnalyticsStudioView extends StatefulWidget {
  const AnalyticsStudioView({
    super.key,
    required this.project,
    this.repository,
    this.service,
    this.manuscriptStore = const ManuscriptStore(),
  });

  final StarterProject project;
  final DriftConnectedDomainRepository? repository;
  final AnalyticsService? service;
  final ManuscriptStore manuscriptStore;

  @override
  State<AnalyticsStudioView> createState() => _AnalyticsStudioViewState();
}

class _AnalyticsStudioViewState extends State<AnalyticsStudioView> {
  late final AnalyticsService service;

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
        _WritingProgressCard(summary: data),
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
  const _StatTile({required this.label, required this.value, this.caption});

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
  const _LabeledValue({required this.label, required this.value});

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
