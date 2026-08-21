/// World Board Phase 1 — the view.
///
/// The board is the author's command centre: one screen that answers "what is
/// in my world, and how does it fit together?" It reads; it does not own. Every
/// figure on it comes back from [WorldBoardService], which in turn asks the
/// Studios that already own each domain.
///
/// It also sizes itself. The shell renders Studio sections inside a scroll
/// view, so the board composes as a self-measuring column rather than claiming
/// unbounded height.
library;

import 'package:flutter/material.dart';

import '../manuscript_store.dart';
import '../onboarding.dart';
import '../persistence/authoros_database.dart';
import '../theme/flutter/authoros_theme.dart';
import '../theme/theme_tokens.dart';
import 'world_board_models.dart';
import 'world_board_sections.dart';
import 'world_board_service.dart';

class WorldBoardView extends StatefulWidget {
  const WorldBoardView({
    super.key,
    required this.project,
    this.repository,
    this.service,
    this.manuscriptStore = const ManuscriptStore(),
    this.onNavigate,
    this.now,
  });

  final StarterProject project;

  /// Injected by tests; production uses the shared repository.
  final DriftConnectedDomainRepository? repository;

  /// Injected by tests that want to control the aggregation directly.
  final WorldBoardService? service;

  final ManuscriptStore manuscriptStore;

  /// Hands a section's destination back to the shell, which owns routing.
  final ValueChanged<WorldBoardDestination>? onNavigate;

  /// Fixed "now" for deterministic relative timestamps in tests.
  final DateTime? now;

  @override
  State<WorldBoardView> createState() => _WorldBoardViewState();
}

class _WorldBoardViewState extends State<WorldBoardView> {
  bool _loading = true;
  String? _error;
  WorldBoardSnapshot? _snapshot;

  late final WorldBoardService _service = widget.service ??
      WorldBoardService(
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
      final snapshot = await _service.load(now: widget.now);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
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

  @override
  Widget build(BuildContext context) {
    // The board carries its own Studio identity so a theme can accent it
    // without any widget below reaching for a colour of its own.
    return StudioThemeScope(
      theme: StudioThemeScope.of(context).theme,
      studio: StudioId.worldBoard,
      child: Builder(builder: _buildBoard),
    );
  }

  Widget _buildBoard(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    if (_loading) {
      return Padding(
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
      return _WorldBoardError(message: error, onRetry: _reload);
    }

    final snapshot = _snapshot!;
    final gap = scope.space('md');

    return Column(
      key: const ValueKey('world-board'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        WorldBoardHeader(
          projectTitle: snapshot.project.title,
          onRefresh: _reload,
        ),
        SizedBox(height: gap),
        _WorldBoardGrid(snapshot: snapshot, onOpen: widget.onNavigate),
        SizedBox(height: gap),
        WorldBoardProjectPanel(snapshot: snapshot, onOpen: widget.onNavigate),
        SizedBox(height: gap),
        WorldBoardRelationshipMap(
          snapshot: snapshot,
          onOpen: widget.onNavigate,
        ),
        SizedBox(height: gap),
        WorldBoardActivityPanel(
          activity: snapshot.activity,
          now: widget.now,
        ),
      ],
    );
  }
}

/// The ecosystem grid, reflowing from three columns to two to one.
class _WorldBoardGrid extends StatelessWidget {
  const _WorldBoardGrid({required this.snapshot, this.onOpen});

  final WorldBoardSnapshot snapshot;
  final ValueChanged<WorldBoardDestination>? onOpen;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    final gap = scope.space('sm');

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560
            ? 1
            : constraints.maxWidth < 900
                ? 2
                : 3;
        const sections = WorldBoardSection.values;
        final rows = <Widget>[];

        for (var start = 0; start < sections.length; start += columns) {
          final end = start + columns > sections.length
              ? sections.length
              : start + columns;
          rows.add(
            // Equal-height tiles inside a column that measures itself: the
            // shell scrolls the board, so the row must not demand a height.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < columns; index += 1) ...[
                    if (index > 0) SizedBox(width: gap),
                    Expanded(
                      child: start + index < end
                          ? WorldBoardMetricTile(
                              metric: snapshot.metric(sections[start + index]),
                              onOpen: onOpen,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (end < sections.length) rows.add(SizedBox(height: gap));
        }

        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}

class _WorldBoardError extends StatelessWidget {
  const _WorldBoardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.of(context);

    return Container(
      key: const ValueKey('world-board-error'),
      width: double.infinity,
      padding: EdgeInsets.all(scope.space('lg')),
      decoration: BoxDecoration(
        color: scope.color(ThemeColorRef.surfaceContainer),
        borderRadius: BorderRadius.circular(scope.radius('card')),
        border: Border.all(color: scope.color(ThemeColorRef.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'World Board unavailable',
            style: scope.text(
              ThemeTextRole.heading,
              colorRef: ThemeColorRef.onSurface,
            ),
          ),
          SizedBox(height: scope.space('sm')),
          Text(
            message,
            style: scope.text(
              ThemeTextRole.body,
              colorRef: ThemeColorRef.onSurfaceVariant,
            ),
          ),
          SizedBox(height: scope.space('md')),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
