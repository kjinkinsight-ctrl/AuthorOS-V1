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
