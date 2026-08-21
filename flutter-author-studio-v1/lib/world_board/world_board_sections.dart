/// World Board Phase 1 — presentation components.
///
/// Every colour and type style here resolves through [StudioThemeScope]. The
/// board owns no `ThemeData`, no `Color(0x...)` literal, and no `Colors.*`
/// reference, so a palette swap, a brightness change, high contrast, and
/// reduced intensity all reach it through the one engine.
library;

import 'package:flutter/material.dart';

import '../theme/flutter/authoros_theme.dart';
import '../theme/theme_tokens.dart';
import 'world_board_models.dart';

/// The board reuses the shell's own iconography so a section reads the same
/// on the board as it does in the navigation rail.
extension WorldBoardSectionIcon on WorldBoardSection {
  IconData get icon => switch (this) {
        WorldBoardSection.projects => Icons.folder_copy_outlined,
        WorldBoardSection.manuscript => Icons.menu_book_outlined,
        WorldBoardSection.characters => Icons.groups_outlined,
        WorldBoardSection.worlds => Icons.public_outlined,
        WorldBoardSection.timelines => Icons.timeline_outlined,
        WorldBoardSection.plot => Icons.route_outlined,
      };
}

/// The board's masthead: what this screen is, and whose world it shows.
class WorldBoardHeader extends StatelessWidget {
  const WorldBoardHeader({
    super.key,
    required this.projectTitle,
    required this.onRefresh,
  });

  final String projectTitle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      key: const ValueKey('world-board-header'),
      width: double.infinity,
      padding: EdgeInsets.all(scope.space('lg')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        borderRadius: BorderRadius.circular(scope.radius('card')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hub_outlined, color: scope.color(ThemeColorRef.primary)),
          SizedBox(width: scope.space('md')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My AuthorOS World',
                  style: scope.text(
                    ThemeTextRole.heading,
                    colorRef: ThemeColorRef.onSurface,
                  ),
                ),
                SizedBox(height: scope.space('xs')),
                Text(
                  'Your entire creative ecosystem in one place.',
                  style: scope.text(
                    ThemeTextRole.body,
                    colorRef: ThemeColorRef.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: scope.space('sm')),
                _WorldBoardChip(label: projectTitle, icon: Icons.bookmark_border),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('world-board-refresh'),
            tooltip: 'Refresh world',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            color: scope.color(ThemeColorRef.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// One cell of the ecosystem grid.
///
/// A populated tile shows its count; an empty one shows the section's empty
/// state instead of a confident zero, and both open the owning Studio.
class WorldBoardMetricTile extends StatelessWidget {
  const WorldBoardMetricTile({
    super.key,
    required this.metric,
    this.onOpen,
  });

  final WorldBoardMetric metric;
  final ValueChanged<WorldBoardDestination>? onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final section = metric.section;
    final accent = metric.isEmpty
        ? scope.color(ThemeColorRef.onSurfaceVariant)
        : scope.color(ThemeColorRef.primary);
    final onOpenTile = onOpen;

    return Material(
      key: ValueKey('world-board-metric-${section.name}'),
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(scope.radius('card')),
        onTap: onOpenTile == null ? null : () => onOpenTile(section.destination),
        child: Container(
          padding: EdgeInsets.all(scope.space('md')),
          decoration: BoxDecoration(
            color: scope.color(ThemeColorRef.surface),
            borderRadius: BorderRadius.circular(scope.radius('card')),
            border:
                Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(section.icon, size: 18, color: accent),
                  SizedBox(width: scope.space('sm')),
                  Expanded(
                    child: Text(
                      section.label.toUpperCase(),
                      style: scope
                          .text(
                            ThemeTextRole.label,
                            colorRef: ThemeColorRef.onSurfaceVariant,
                          )
                          .copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: scope.space('sm')),
              if (metric.isEmpty)
                Text(
                  section.emptyTitle,
                  key: ValueKey('world-board-empty-${section.name}'),
                  style: scope.text(
                    ThemeTextRole.ui,
                    colorRef: ThemeColorRef.onSurfaceVariant,
                  ),
                )
              else
                Text(
                  metric.value,
                  key: ValueKey('world-board-value-${section.name}'),
                  style: scope
                      .text(
                        ThemeTextRole.heading,
                        colorRef: ThemeColorRef.onSurface,
                      )
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              SizedBox(height: scope.space('xs')),
              Text(
                metric.isEmpty ? section.emptyBody : metric.caption,
                style: scope.text(
                  ThemeTextRole.label,
                  colorRef: ThemeColorRef.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The current project, its draft progress, and the four counts that describe
/// the story around it.
class WorldBoardProjectPanel extends StatelessWidget {
  const WorldBoardProjectPanel({
    super.key,
    required this.snapshot,
    this.onOpen,
  });

  final WorldBoardSnapshot snapshot;
  final ValueChanged<WorldBoardDestination>? onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final project = snapshot.project;
    final onOpenPanel = onOpen;

    return Container(
      key: const ValueKey('world-board-project-panel'),
      width: double.infinity,
      padding: EdgeInsets.all(scope.space('lg')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        borderRadius: BorderRadius.circular(scope.radius('card')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WorldBoardSectionLabel(label: 'Current project'),
          SizedBox(height: scope.space('sm')),
          Text(
            project.title,
            key: const ValueKey('world-board-project-title'),
            style: scope
                .text(ThemeTextRole.heading, colorRef: ThemeColorRef.onSurface)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: scope.space('sm')),
          Wrap(
            spacing: scope.space('sm'),
            runSpacing: scope.space('sm'),
            children: [
              _WorldBoardChip(label: project.projectType),
              _WorldBoardChip(label: project.genre),
            ],
          ),
          SizedBox(height: scope.space('lg')),
          if (project.hasManuscript) ...[
            _WorldBoardProgressBar(project: project),
            SizedBox(height: scope.space('lg')),
          ] else ...[
            WorldBoardEmptyState(
              section: WorldBoardSection.manuscript,
              onOpen: onOpenPanel,
            ),
            SizedBox(height: scope.space('lg')),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final stats = <Widget>[
                for (final section in const [
                  WorldBoardSection.manuscript,
                  WorldBoardSection.characters,
                  WorldBoardSection.timelines,
                  WorldBoardSection.plot,
                ])
                  _WorldBoardMiniStat(metric: snapshot.metric(section)),
              ];
              final columns = constraints.maxWidth < 420 ? 2 : 4;
              return _WorldBoardStatRow(columns: columns, children: stats);
            },
          ),
        ],
      ),
    );
  }
}

/// The Phase 1 relationship view: the project, then one level of what hangs
/// off it. Deliberately a tree of cards and connector rules rather than an
/// interactive graph, which is World Board Phase 2 work.
class WorldBoardRelationshipMap extends StatelessWidget {
  const WorldBoardRelationshipMap({
    super.key,
    required this.snapshot,
    this.onOpen,
  });

  final WorldBoardSnapshot snapshot;
  final ValueChanged<WorldBoardDestination>? onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final branches = snapshot.branches;

    return Container(
      key: const ValueKey('world-board-relationship-map'),
      width: double.infinity,
      padding: EdgeInsets.all(scope.space('lg')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surface),
        borderRadius: BorderRadius.circular(scope.radius('card')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WorldBoardSectionLabel(label: 'How your world connects'),
          SizedBox(height: scope.space('md')),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scope.color(ThemeColorRef.primary),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: scope.space('sm')),
              Expanded(
                child: Text(
                  snapshot.project.title,
                  style: scope
                      .text(
                        ThemeTextRole.ui,
                        colorRef: ThemeColorRef.onSurface,
                      )
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          for (var index = 0; index < branches.length; index += 1)
            _WorldBoardBranchRow(
              branch: branches[index],
              isLast: index == branches.length - 1,
              onOpen: onOpen,
            ),
        ],
      ),
    );
  }
}

/// The audit trail, phrased for an author rather than a changelog reader.
class WorldBoardActivityPanel extends StatelessWidget {
  const WorldBoardActivityPanel({
    super.key,
    required this.activity,
    this.now,
  });

  final List<WorldBoardActivity> activity;

  /// Injected by tests so relative timestamps are deterministic.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      key: const ValueKey('world-board-activity'),
      width: double.infinity,
      padding: EdgeInsets.all(scope.space('lg')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surface),
        borderRadius: BorderRadius.circular(scope.radius('card')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WorldBoardSectionLabel(label: 'Recent activity'),
          SizedBox(height: scope.space('md')),
          if (activity.isEmpty)
            Text(
              'No activity yet. Anything you change in a Studio shows up here.',
              key: const ValueKey('world-board-activity-empty'),
              style: scope.text(
                ThemeTextRole.body,
                colorRef: ThemeColorRef.onSurfaceVariant,
              ),
            )
          else
            for (final entry in activity)
              Padding(
                padding: EdgeInsets.only(bottom: scope.space('sm')),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: scope.space('xs')),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scope.color(ThemeColorRef.primary),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: scope.space('sm')),
                    Expanded(
                      child: Text(
                        entry.summary,
                        style: scope.text(
                          ThemeTextRole.body,
                          colorRef: ThemeColorRef.onSurface,
                        ),
                      ),
                    ),
                    SizedBox(width: scope.space('sm')),
                    Text(
                      formatWorldBoardMoment(entry.occurredAt, now: now),
                      style: scope.text(
                        ThemeTextRole.label,
                        colorRef: ThemeColorRef.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// A category with nothing in it yet, and the way into the Studio that fills
/// it. Shown wherever the board would otherwise render a hollow zero.
class WorldBoardEmptyState extends StatelessWidget {
  const WorldBoardEmptyState({
    super.key,
    required this.section,
    this.onOpen,
  });

  final WorldBoardSection section;
  final ValueChanged<WorldBoardDestination>? onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final onOpenState = onOpen;

    return Container(
      key: ValueKey('world-board-empty-state-${section.name}'),
      width: double.infinity,
      padding: EdgeInsets.all(scope.space('md')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surface),
        borderRadius: BorderRadius.circular(scope.radius('chip')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            section.emptyTitle,
            style: scope
                .text(ThemeTextRole.ui, colorRef: ThemeColorRef.onSurface)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: scope.space('xs')),
          Text(
            section.emptyBody,
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
          if (onOpenState != null) ...[
            SizedBox(height: scope.space('sm')),
            TextButton(
              key: ValueKey('world-board-open-${section.name}'),
              onPressed: () => onOpenState(section.destination),
              child: Text(section.openLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorldBoardBranchRow extends StatelessWidget {
  const _WorldBoardBranchRow({
    required this.branch,
    required this.isLast,
    this.onOpen,
  });

  final WorldBoardBranch branch;
  final bool isLast;
  final ValueChanged<WorldBoardDestination>? onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final outline = scope.color(ThemeColorRef.outlineVariant);
    final onOpenRow = onOpen;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                // Drops past the horizontal tick below, then keeps running to
                // the next branch — and stops on the last one, so the tree
                // reads as closed rather than trailing off.
                Container(width: 1, height: 22, color: outline),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: outline)),
              ],
            ),
          ),
          Padding(
            // Meets the vertical rule level with the branch icon beside it.
            padding: EdgeInsets.only(top: scope.space('lg')),
            child: Container(width: 12, height: 1, color: outline),
          ),
          SizedBox(width: scope.space('sm')),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: scope.space('sm')),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: scope.space('sm')),
                  Row(
                    children: [
                      Icon(
                        branch.section.icon,
                        size: 16,
                        color: branch.isEmpty
                            ? scope.color(ThemeColorRef.onSurfaceVariant)
                            : scope.color(ThemeColorRef.primary),
                      ),
                      SizedBox(width: scope.space('sm')),
                      Flexible(
                        child: Text(
                          branch.section.label,
                          overflow: TextOverflow.ellipsis,
                          style: scope
                              .text(
                                ThemeTextRole.ui,
                                colorRef: ThemeColorRef.onSurface,
                              )
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: scope.space('sm')),
                      if (!branch.isEmpty)
                        Text(
                          formatWorldBoardCount(branch.count),
                          key: ValueKey(
                            'world-board-branch-count-${branch.section.name}',
                          ),
                          style: scope.text(
                            ThemeTextRole.label,
                            colorRef: ThemeColorRef.primary,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: scope.space('xs')),
                  if (branch.isEmpty)
                    Text(
                      branch.section.emptyTitle,
                      key: ValueKey(
                        'world-board-branch-empty-${branch.section.name}',
                      ),
                      style: scope.text(
                        ThemeTextRole.label,
                        colorRef: ThemeColorRef.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: scope.space('sm'),
                      runSpacing: scope.space('xs'),
                      children: [
                        for (final leaf in branch.leaves)
                          _WorldBoardChip(label: leaf),
                        if (branch.hiddenCount > 0)
                          _WorldBoardChip(
                            label: '+${branch.hiddenCount} more',
                          ),
                      ],
                    ),
                  if (branch.isEmpty && onOpenRow != null) ...[
                    SizedBox(height: scope.space('xs')),
                    TextButton(
                      key: ValueKey(
                        'world-board-branch-open-${branch.section.name}',
                      ),
                      onPressed: () => onOpenRow(branch.section.destination),
                      child: Text(branch.section.openLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldBoardProgressBar extends StatelessWidget {
  const _WorldBoardProgressBar({required this.project});

  final WorldBoardProjectContext project;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final hasGoal = project.wordGoal > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasGoal
                    ? '${formatWorldBoardCount(project.wordCount)} of '
                        '${formatWorldBoardCount(project.wordGoal)} words'
                    : '${formatWorldBoardCount(project.wordCount)} words',
                style: scope.text(
                  ThemeTextRole.body,
                  colorRef: ThemeColorRef.onSurface,
                ),
              ),
            ),
            if (hasGoal)
              Text(
                '${project.progressPercent}%',
                key: const ValueKey('world-board-progress-percent'),
                style: scope
                    .text(
                      ThemeTextRole.label,
                      colorRef: ThemeColorRef.primary,
                    )
                    .copyWith(fontWeight: FontWeight.w700),
              ),
          ],
        ),
        SizedBox(height: scope.space('sm')),
        ClipRRect(
          borderRadius: BorderRadius.circular(scope.radius('chip')),
          child: LinearProgressIndicator(
            key: const ValueKey('world-board-progress'),
            value: project.progress,
            minHeight: 10,
            backgroundColor: scope.color(ThemeColorRef.surface),
            valueColor: AlwaysStoppedAnimation<Color>(
              scope.color(ThemeColorRef.primary),
            ),
          ),
        ),
        if (hasGoal) ...[
          SizedBox(height: scope.space('sm')),
          Text(
            '${formatWorldBoardCount(project.wordsRemaining)} words remaining',
            style: scope.text(
              ThemeTextRole.label,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _WorldBoardMiniStat extends StatelessWidget {
  const _WorldBoardMiniStat({required this.metric});

  final WorldBoardMetric metric;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      padding: EdgeInsets.all(scope.space('md')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surface),
        borderRadius: BorderRadius.circular(scope.radius('chip')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metric.section.label,
            style: scope.text(
              ThemeTextRole.label,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
          SizedBox(height: scope.space('xs')),
          Text(
            metric.isEmpty ? '—' : metric.value,
            key: ValueKey('world-board-mini-${metric.section.name}'),
            style: scope
                .text(ThemeTextRole.ui, colorRef: ThemeColorRef.onSurface)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// A fixed-column grid that keeps its own height, so the board composes inside
/// the shell's scroll view without fighting it for constraints.
class _WorldBoardStatRow extends StatelessWidget {
  const _WorldBoardStatRow({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final rows = <Widget>[];

    for (var start = 0; start < children.length; start += columns) {
      final slice = children.sublist(
        start,
        start + columns > children.length ? children.length : start + columns,
      );
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < columns; index += 1) ...[
                if (index > 0) SizedBox(width: scope.space('sm')),
                Expanded(
                  child: index < slice.length
                      ? slice[index]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
      if (start + columns < children.length) {
        rows.add(SizedBox(height: scope.space('sm')));
      }
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _WorldBoardSectionLabel extends StatelessWidget {
  const _WorldBoardSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Text(
      label.toUpperCase(),
      style: scope
          .text(ThemeTextRole.label, colorRef: ThemeColorRef.primary)
          .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
    );
  }
}

class _WorldBoardChip extends StatelessWidget {
  const _WorldBoardChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final chipIcon = icon;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scope.space('md'),
        vertical: scope.space('xs'),
      ),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surface),
        borderRadius: BorderRadius.circular(scope.radius('chip')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chipIcon != null) ...[
            Icon(
              chipIcon,
              size: 14,
              color: scope.color(ThemeColorRef.onSurfaceVariant),
            ),
            SizedBox(width: scope.space('xs')),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: scope.text(
                ThemeTextRole.label,
                colorRef: ThemeColorRef.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
