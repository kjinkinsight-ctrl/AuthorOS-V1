/// AuthorOS Intelligence Layer — presentation components.
///
/// Every colour, space and type style resolves through [StudioThemeScope].
/// There is no `ThemeData`, no `Color(0x...)` literal and no `Colors.*`
/// reference here, so a palette swap, a brightness change and high contrast all
/// reach this screen through the one engine.
///
/// The components are public because the World Board embeds
/// [IntelligenceHealthTile]. Keeping them public rather than private to the
/// view is what stops the second screen re-implementing the first.
library;

import 'package:flutter/material.dart';

import '../continuity.dart';
import '../theme/flutter/authoros_theme.dart';
import '../theme/theme_tokens.dart';
import 'intelligence_models.dart';

/// Each condition borrows the iconography of the Studio that owns it, so a
/// finding reads the same here as the section it sends you to.
extension StructuralConditionIcon on StructuralCondition {
  IconData get icon => switch (this) {
        StructuralCondition.orphanEntity => Icons.person_off_outlined,
        StructuralCondition.unlinkedMention => Icons.link_off_outlined,
        StructuralCondition.orphanPlot => Icons.route_outlined,
        StructuralCondition.unresolvedRelationship => Icons.favorite_border,
        StructuralCondition.timelineConflict => Icons.timeline_outlined,
        StructuralCondition.locationGap => Icons.wrong_location_outlined,
        StructuralCondition.castGap => Icons.person_search_outlined,
        StructuralCondition.researchGap => Icons.menu_book_outlined,
        StructuralCondition.unusedWorldbuilding => Icons.public_off_outlined,
      };
}

extension ContinuitySeverityLabel on ContinuitySeverity {
  String get label => switch (this) {
        ContinuitySeverity.critical => 'Critical',
        ContinuitySeverity.warning => 'Warning',
        ContinuitySeverity.notice => 'Notice',
      };
}

/// The screen's masthead.
class IntelligenceHeader extends StatelessWidget {
  const IntelligenceHeader({
    super.key,
    required this.report,
    required this.onRefresh,
  });

  final IntelligenceReport report;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      key: const ValueKey('intelligence-header'),
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
          Icon(
            Icons.troubleshoot_outlined,
            color: scope.color(ThemeColorRef.primary),
          ),
          SizedBox(width: scope.space('md')),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Story Intelligence',
                  style: scope.text(
                    ThemeTextRole.heading,
                    colorRef: ThemeColorRef.onSurface,
                  ),
                ),
                SizedBox(height: scope.space('xs')),
                Text(
                  'What your story is missing, not how much of it there is.',
                  style: scope.text(
                    ThemeTextRole.body,
                    colorRef: ThemeColorRef.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: scope.space('sm')),
                Wrap(
                  spacing: scope.space('sm'),
                  runSpacing: scope.space('xs'),
                  children: [
                    IntelligenceChip(
                      label: '${report.criticalCount} critical',
                      icon: Icons.error_outline,
                      emphasised: report.criticalCount > 0,
                    ),
                    IntelligenceChip(
                      label: '${report.warningCount} warnings',
                      icon: Icons.warning_amber_outlined,
                      emphasised: report.warningCount > 0,
                    ),
                    IntelligenceChip(
                      label: '${report.noticeCount} notices',
                      icon: Icons.info_outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('intelligence-refresh'),
            tooltip: 'Re-check the story',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            color: scope.color(ThemeColorRef.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The world-coverage line: how much of what the author built reaches the page.
///
/// This is the report's headline number, and deliberately not a score. See
/// [IntelligenceReport] for why a 0-100 integrity score does not survive being
/// applied to a whole project.
class IntelligenceCoveragePanel extends StatelessWidget {
  const IntelligenceCoveragePanel({super.key, required this.report});

  final IntelligenceReport report;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final total = report.totalWorldEntities;
    final connected = report.connectedWorldEntities;
    final fraction = total == 0 ? 0.0 : connected / total;

    return Container(
      key: const ValueKey('intelligence-coverage'),
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
          Text(
            'World coverage',
            style: scope.text(
              ThemeTextRole.heading,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          SizedBox(height: scope.space('xs')),
          Text(
            total == 0
                ? 'No world entities yet.'
                : '$connected of $total world entities reach the manuscript.',
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
          SizedBox(height: scope.space('md')),
          ClipRRect(
            borderRadius: BorderRadius.circular(scope.radius('chip')),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: scope.color(ThemeColorRef.surfaceContainer),
              valueColor: AlwaysStoppedAnimation<Color>(
                scope.color(ThemeColorRef.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One condition, with every finding it produced.
class IntelligenceConditionCard extends StatelessWidget {
  const IntelligenceConditionCard({
    super.key,
    required this.condition,
    required this.findings,
    this.onOpen,
    this.onResolve,
  });

  final StructuralCondition condition;
  final List<StructuralFinding> findings;
  final ValueChanged<IntelligenceDestination>? onOpen;
  final ValueChanged<StructuralFinding>? onResolve;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      key: ValueKey('intelligence-condition-${condition.name}'),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                condition.icon,
                size: 20,
                color: scope.color(ThemeColorRef.primary),
              ),
              SizedBox(width: scope.space('sm')),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.label,
                      style: scope.text(
                        ThemeTextRole.heading,
                        colorRef: ThemeColorRef.onSurface,
                      ),
                    ),
                    SizedBox(height: scope.space('xs')),
                    Text(
                      condition.description,
                      style: scope.text(
                        ThemeTextRole.label,
                        colorRef: ThemeColorRef.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IntelligenceChip(
                label: '${findings.length}',
                emphasised: true,
              ),
            ],
          ),
          SizedBox(height: scope.space('md')),
          for (final finding in findings) ...[
            IntelligenceFindingRow(
              finding: finding,
              onOpen: onOpen,
              onResolve: onResolve,
            ),
            if (finding != findings.last) SizedBox(height: scope.space('sm')),
          ],
        ],
      ),
    );
  }
}

/// One finding: what was found, why, and what to do about it.
class IntelligenceFindingRow extends StatelessWidget {
  const IntelligenceFindingRow({
    super.key,
    required this.finding,
    this.onOpen,
    this.onResolve,
  });

  final StructuralFinding finding;
  final ValueChanged<IntelligenceDestination>? onOpen;
  final ValueChanged<StructuralFinding>? onResolve;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final action = finding.action;
    final open = onOpen;
    final resolve = onResolve;

    return Container(
      padding: EdgeInsets.all(scope.space('md')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        borderRadius: BorderRadius.circular(scope.radius('chip')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  finding.title,
                  style: scope.text(
                    ThemeTextRole.body,
                    colorRef: ThemeColorRef.onSurface,
                  ),
                ),
              ),
              SizedBox(width: scope.space('sm')),
              IntelligenceChip(
                label: finding.severity.label,
                emphasised: finding.severity != ContinuitySeverity.notice,
              ),
            ],
          ),
          SizedBox(height: scope.space('xs')),
          Text(
            finding.detail,
            style: scope.text(
              ThemeTextRole.label,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
          SizedBox(height: scope.space('xs')),
          Text(
            finding.recommendation,
            style: scope.text(
              ThemeTextRole.label,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
          SizedBox(height: scope.space('sm')),
          Wrap(
            spacing: scope.space('sm'),
            runSpacing: scope.space('xs'),
            children: [
              if (open != null)
                TextButton.icon(
                  onPressed: () => open(finding.destination),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open Studio'),
                ),
              if (action != null && resolve != null)
                FilledButton.tonalIcon(
                  key: ValueKey(
                    'intelligence-resolve-${finding.entityIds.join('-')}',
                  ),
                  onPressed: () => resolve(finding),
                  icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
                  label: Text(action.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The state the author most wants to see.
class IntelligenceCleanState extends StatelessWidget {
  const IntelligenceCleanState({super.key, required this.hasManuscript});

  final bool hasManuscript;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      key: const ValueKey('intelligence-clean'),
      width: double.infinity,
      padding: EdgeInsets.all(scope.space('xl')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surface),
        borderRadius: BorderRadius.circular(scope.radius('card')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Column(
        children: [
          Icon(
            hasManuscript ? Icons.verified_outlined : Icons.edit_outlined,
            size: 32,
            color: scope.color(ThemeColorRef.primary),
          ),
          SizedBox(height: scope.space('md')),
          Text(
            hasManuscript
                ? 'Nothing structurally wrong'
                : 'Nothing to check yet',
            style: scope.text(
              ThemeTextRole.heading,
              colorRef: ThemeColorRef.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: scope.space('xs')),
          Text(
            hasManuscript
                ? 'Every character reaches the page, every storyline holds '
                    'scenes, and nothing contradicts itself.'
                : 'Start writing, and this screen will tell you what your '
                    'story is missing.',
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The Intelligence Layer's presence on the World Board.
///
/// One tile, one number, one route in. The board is where the author lands, so
/// this is where a structural problem has to be visible — a finding nobody sees
/// is a finding that does not exist.
class IntelligenceHealthTile extends StatelessWidget {
  const IntelligenceHealthTile({
    super.key,
    required this.report,
    this.onOpen,
  });

  final IntelligenceReport report;

  /// Opens the Intelligence Studio. The tile never names the shell's section
  /// enum — routing belongs to the shell.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final count = report.findings.length;
    final clean = count == 0;
    final accent = clean
        ? scope.color(ThemeColorRef.onSurfaceVariant)
        : scope.color(ThemeColorRef.primary);

    return Material(
      key: const ValueKey('intelligence-health-tile'),
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(scope.radius('card')),
        onTap: onOpen,
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
                  Icon(Icons.troubleshoot_outlined, size: 18, color: accent),
                  SizedBox(width: scope.space('sm')),
                  Expanded(
                    child: Text(
                      'Story Intelligence',
                      style: scope.text(
                        ThemeTextRole.label,
                        colorRef: ThemeColorRef.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: scope.space('sm')),
              Text(
                clean ? 'All clear' : '$count',
                style: scope.text(
                  ThemeTextRole.heading,
                  colorRef: ThemeColorRef.onSurface,
                ),
              ),
              SizedBox(height: scope.space('xs')),
              Text(
                clean
                    ? 'Nothing structurally wrong.'
                    : count == 1
                        ? 'structural condition to look at'
                        : 'structural conditions to look at',
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

/// A small pill, used for counts and severities.
class IntelligenceChip extends StatelessWidget {
  const IntelligenceChip({
    super.key,
    required this.label,
    this.icon,
    this.emphasised = false,
  });

  final String label;
  final IconData? icon;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final foreground = emphasised
        ? scope.color(ThemeColorRef.primary)
        : scope.color(ThemeColorRef.onSurfaceVariant);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: scope.space('sm'),
        vertical: scope.space('xs'),
      ),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        borderRadius: BorderRadius.circular(scope.radius('chip')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            SizedBox(width: scope.space('xs')),
          ],
          Text(
            label,
            style: scope.text(ThemeTextRole.label).copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
