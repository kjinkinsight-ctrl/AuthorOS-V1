/// AuthorOS Intelligence Layer — the Studio.
///
/// One screen that answers "what is structurally wrong with my book?" It
/// performs no analysis of its own: [IntelligenceService] produces the report
/// once per load, and `build` lays the findings out.
///
/// It also sizes itself. The shell renders Studio sections inside a scroll
/// view, so this composes as a self-measuring column rather than claiming
/// unbounded height.
library;

import 'package:flutter/material.dart';

import '../continuity.dart';
import '../continuity_actions.dart';
import '../manuscript_store.dart';
import '../onboarding.dart';
import '../persistence/authoros_database.dart';
import '../theme/flutter/authoros_theme.dart';
import '../theme/theme_tokens.dart';
import 'intelligence_models.dart';
import 'intelligence_sections.dart';
import 'intelligence_service.dart';

class IntelligenceStudioView extends StatefulWidget {
  const IntelligenceStudioView({
    super.key,
    required this.project,
    this.repository,
    this.service,
    this.manuscriptStore = const ManuscriptStore(),
    this.onNavigate,
  });

  final StarterProject project;

  /// Injected by tests; production uses the shared repository.
  final DriftConnectedDomainRepository? repository;

  /// Injected by tests that want to drive the analysis directly.
  final IntelligenceService? service;

  final ManuscriptStore manuscriptStore;

  /// Hands a finding's destination back to the shell, which owns routing.
  final ValueChanged<IntelligenceDestination>? onNavigate;

  @override
  State<IntelligenceStudioView> createState() => _IntelligenceStudioViewState();
}

class _IntelligenceStudioViewState extends State<IntelligenceStudioView> {
  bool _loading = true;
  String? _error;
  IntelligenceReport? _report;

  late final IntelligenceService _service = widget.service ??
      IntelligenceService(
        project: widget.project,
        repository: widget.repository,
        manuscriptStore: widget.manuscriptStore,
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
      final report = await _service.analyze();
      if (!mounted) return;
      setState(() {
        _report = report;
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

  /// Applies a finding's recommendation through the existing
  /// `ContinuityActionService`.
  ///
  /// No new write path: the same service that resolves a continuity
  /// recommendation inside a character panel resolves it here. Only findings
  /// whose condition maps onto a recommendation it already understands carry
  /// an action at all.
  Future<void> _resolve(StructuralFinding finding) async {
    final action = finding.action;
    if (action == null) return;

    final actions = ContinuityActionService(
      projectId: widget.project.id,
      repository: _service.repository,
    );

    ContinuityActionResult result;
    switch (action.kind) {
      case ContinuityActionKind.create:
        result = await actions.createForRecommendation(
          action.issue,
          name: action.name,
          confirmed: true,
        );
      case ContinuityActionKind.link:
        result = await actions.linkForRecommendation(
          action.issue,
          sourceId: action.sourceId!,
          targetId: action.targetId!,
          typeId: action.connectionTypeId!,
          confirmed: true,
        );
      case ContinuityActionKind.review:
        return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          result.message.isNotEmpty
              ? result.message
              : result.mutationApplied
                  ? 'Applied.'
                  : 'Nothing was changed.',
        ),
      ),
    );
    if (result.mutationApplied) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    // The Studio carries its own identity so a theme can accent it without any
    // widget below reaching for a colour of its own.
    return StudioThemeScope(
      theme: StudioThemeScope.of(context).theme,
      studio: StudioId.intelligence,
      child: Builder(builder: _buildStudio),
    );
  }

  Widget _buildStudio(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    if (_loading) {
      return Padding(
        key: const ValueKey('intelligence-loading'),
        padding: EdgeInsets.all(scope.space('xl')),
        child: Center(
          child: CircularProgressIndicator(
            color: scope.color(ThemeColorRef.primary),
          ),
        ),
      );
    }

    final error = _error;
    if (error != null) {
      return _IntelligenceError(message: error, onRetry: _reload);
    }

    final report = _report!;
    final gap = scope.space('md');

    return Column(
      key: const ValueKey('intelligence-studio'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        IntelligenceHeader(report: report, onRefresh: _reload),
        SizedBox(height: gap),
        IntelligenceCoveragePanel(report: report),
        SizedBox(height: gap),
        if (report.isClean)
          IntelligenceCleanState(hasManuscript: report.hasManuscript)
        else
          for (final condition in report.activeConditions) ...[
            IntelligenceConditionCard(
              condition: condition,
              findings: report.forCondition(condition),
              onOpen: widget.onNavigate,
              onResolve: _resolve,
            ),
            SizedBox(height: gap),
          ],
      ],
    );
  }
}

class _IntelligenceError extends StatelessWidget {
  const _IntelligenceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      key: const ValueKey('intelligence-error'),
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
            children: [
              Icon(
                Icons.error_outline,
                color: scope.color(ThemeColorRef.primary),
              ),
              SizedBox(width: scope.space('sm')),
              Expanded(
                child: Text(
                  'Story Intelligence unavailable',
                  style: scope.text(
                    ThemeTextRole.heading,
                    colorRef: ThemeColorRef.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: scope.space('sm')),
          Text(
            message,
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
          SizedBox(height: scope.space('sm')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
