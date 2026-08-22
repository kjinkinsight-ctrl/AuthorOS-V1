import 'package:flutter/material.dart';

import 'continuity.dart';
import 'core/connected_domain.dart';
import 'core/record_validation.dart';
import 'core/scene_prose.dart';
import 'core/search_models.dart';
import 'core/version_audit.dart';
import 'manuscript_continuity.dart';
import 'manuscript_service.dart';
import 'manuscript_store.dart';

/// A request to open a connected record in the Studio that owns it.
class ManuscriptNavigationRequest {
  const ManuscriptNavigationRequest({
    required this.destination,
    required this.recordId,
    required this.projectId,
  });

  final SearchDestination destination;
  final String recordId;
  final String projectId;
}

/// The Phase 2 panes of Manuscript Studio for one chapter or scene.
///
/// Every pane reads through [ManuscriptService], which in turn uses the
/// project's existing shared services. The panel owns no state of its own
/// beyond the selected tab and the futures it is currently showing.
class ManuscriptConnectedPanel extends StatefulWidget {
  const ManuscriptConnectedPanel({
    super.key,
    required this.service,
    required this.manuscript,
    required this.nodeId,
    required this.nodeKind,
    required this.onChanged,
    this.onNavigate,
    this.continuity = const ManuscriptContinuityIntelligence(),
  });

  final ManuscriptService service;
  final ManuscriptProjectSummary manuscript;
  final String nodeId;
  final ManuscriptNodeKind nodeKind;

  /// Called with the manuscript a mutation produced, so the host view can
  /// adopt it without reloading from storage.
  final Future<void> Function(ManuscriptProjectSummary manuscript) onChanged;

  final ValueChanged<ManuscriptNavigationRequest>? onNavigate;
  final ManuscriptContinuityIntelligence continuity;

  @override
  State<ManuscriptConnectedPanel> createState() =>
      _ManuscriptConnectedPanelState();
}

enum ManuscriptPanelTab { connections, continuity, inspector, history }

String manuscriptPanelTabLabel(ManuscriptPanelTab tab) => switch (tab) {
      ManuscriptPanelTab.connections => 'Connections',
      ManuscriptPanelTab.continuity => 'Continuity',
      ManuscriptPanelTab.inspector => 'Inspector',
      ManuscriptPanelTab.history => 'History',
    };

class _ManuscriptConnectedPanelState extends State<ManuscriptConnectedPanel> {
  ManuscriptPanelTab _tab = ManuscriptPanelTab.connections;

  Future<List<ManuscriptConnection>>? _connections;
  Future<ManuscriptContinuityReport>? _continuity;
  Future<ManuscriptNodeInspection?>? _inspection;
  Future<List<RecordVersion>>? _history;
  Future<List<SceneProseSnapshot>>? _proseHistory;

  String _message = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(ManuscriptConnectedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodeId != widget.nodeId ||
        _nodeStamp(oldWidget) != _nodeStamp(widget) ||
        oldWidget.service.activeBranchId != widget.service.activeBranchId) {
      _reload();
    }
  }

  /// When the inspected node itself last changed.
  ///
  /// Autosaving prose in another scene must not re-run continuity analysis or
  /// re-read the Inspector for this one.
  DateTime? _nodeStamp(ManuscriptConnectedPanel panel) =>
      panel.manuscript.chapterById(panel.nodeId)?.updatedAt ??
      panel.manuscript.sceneById(panel.nodeId)?.updatedAt;

  void _reload() {
    final service = widget.service;
    setState(() {
      _connections = service.connectionsFor(widget.nodeId);
      _continuity = service.analyzeContinuity(
        widget.manuscript,
        widget.nodeId,
        intelligence: widget.continuity,
      );
      _inspection = service.inspectNode(widget.manuscript, widget.nodeId);
      _history = service.historyFor(widget.nodeId);
      // Chapters hold no prose of their own, so there is nothing to ask for.
      _proseHistory = widget.nodeKind == ManuscriptNodeKind.scene
          ? service.proseHistoryFor(widget.nodeId)
          : Future<List<SceneProseSnapshot>>.value(const []);
    });
  }

  void _report(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  Future<void> _adopt(ManuscriptProjectSummary manuscript) async {
    await widget.onChanged(manuscript);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('manuscript-connected-panel'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.service.canEditCanon)
            _ManuscriptBanner(
              key: const Key('manuscript-canon-banner'),
              icon: Icons.lock_outline,
              message:
                  'Canon is read-only while the ${widget.service.activeBranchId} '
                  'branch is active. Leave the branch to edit the manuscript.',
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tab in ManuscriptPanelTab.values)
                ChoiceChip(
                  key: Key('manuscript-tab-${tab.name}'),
                  label: Text(manuscriptPanelTabLabel(tab)),
                  selected: _tab == tab,
                  onSelected: (_) => setState(() => _tab = tab),
                ),
            ],
          ),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ManuscriptBanner(
              key: const Key('manuscript-panel-message'),
              icon: Icons.info_outline,
              message: _message,
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: switch (_tab) {
              ManuscriptPanelTab.connections => _buildConnections(),
              ManuscriptPanelTab.continuity => _buildContinuity(),
              ManuscriptPanelTab.inspector => _buildInspector(),
              ManuscriptPanelTab.history => _buildHistory(),
            },
          ),
        ],
      ),
    );
  }

  // --- Connections -------------------------------------------------------

  Widget _buildConnections() => FutureBuilder<List<ManuscriptConnection>>(
        future: _connections,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final connections = snapshot.data ?? const <ManuscriptConnection>[];
          return ListView(
            key: const Key('manuscript-connections-list'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Connected records (${connections.length})',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('manuscript-add-connection'),
                    onPressed:
                        widget.service.canEditCanon ? _addConnection : null,
                    icon: const Icon(Icons.add_link),
                    label: const Text('Connect'),
                  ),
                ],
              ),
              if (connections.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Nothing is connected yet. Connect the characters, places, '
                    'plot threads and events this part of the manuscript uses.',
                  ),
                ),
              for (final connection in connections)
                _ManuscriptConnectionTile(
                  key: Key('manuscript-connection-${connection.linkId}'),
                  connection: connection,
                  canEdit: widget.service.canEditCanon,
                  onOpen: widget.onNavigate == null
                      ? null
                      : () => widget.onNavigate!(ManuscriptNavigationRequest(
                            destination: connection.destination,
                            recordId: connection.recordId,
                            projectId: widget.service.projectId,
                          )),
                  onRemove: () => _removeConnection(connection),
                ),
            ],
          );
        },
      );

  Future<void> _addConnection() async {
    final records = await widget.service.connectableRecords();
    if (!mounted) return;
    if (records.isEmpty) {
      _report('This project has no records to connect yet.');
      return;
    }
    final choice = await showDialog<_ConnectionChoice>(
      context: context,
      builder: (context) => _ConnectRecordDialog(
        service: widget.service,
        nodeKind: widget.nodeKind,
        records: records,
      ),
    );
    if (choice == null) return;
    try {
      await widget.service.connectNode(
        nodeId: widget.nodeId,
        recordId: choice.recordId,
        typeId: choice.typeId,
      );
      _report('Connected ${choice.title}.');
      _reload();
    } on Object catch (error) {
      _report(error.toString());
    }
  }

  Future<void> _removeConnection(ManuscriptConnection connection) async {
    final confirmed = await _confirm(
      title: 'Remove connection?',
      message:
          'This removes the ${connection.displayName} connection to '
          '${connection.title}. The record itself is not deleted.',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    try {
      await widget.service.disconnectNode(connection.linkId);
      _report('Removed the connection to ${connection.title}.');
      _reload();
    } on Object catch (error) {
      _report(error.toString());
    }
  }

  // --- Continuity --------------------------------------------------------

  Widget _buildContinuity() => FutureBuilder<ManuscriptContinuityReport>(
        future: _continuity,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final report = snapshot.data ?? ManuscriptContinuityReport.empty;
          return ListView(
            key: const Key('manuscript-continuity-list'),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Continuity Intelligence',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Text(
                    'Score ${report.summary.score}',
                    key: const Key('manuscript-continuity-score'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (report.isClean)
                const Text(
                  'No continuity problems found in this part of the '
                  'manuscript.',
                  key: Key('manuscript-continuity-clean'),
                ),
              for (final issue in report.summary.issues)
                _ManuscriptContinuityTile(
                  key: Key('manuscript-continuity-${issue.title}'),
                  issue: issue,
                  canResolve: widget.service.canEditCanon,
                  onResolve: () => _resolveContinuity(report, issue),
                ),
            ],
          );
        },
      );

  Future<void> _resolveContinuity(
    ManuscriptContinuityReport report,
    ContinuityIntegrityIssue issue,
  ) async {
    final finding = report.findingFor(issue);
    if (finding == null) return;
    final label = switch (finding.actionKind) {
      ContinuityActionKind.create => 'Create record',
      ContinuityActionKind.link => 'Link record',
      ContinuityActionKind.review => 'Apply fix',
    };
    final confirmed = await _confirm(
      title: label,
      message: '${issue.message}\n\n${issue.recommendation}',
      confirmLabel: label,
    );
    if (!confirmed) return;
    final result = await widget.service.resolveContinuity(
      widget.manuscript,
      issue,
      finding,
      confirmed: true,
    );
    if (!mounted) return;
    _report(result.message);
    if (result.mutationApplied) {
      await _adopt(await widget.service.load(
        manuscriptTitle: widget.manuscript.manuscriptTitle,
      ));
    }
  }

  // --- Inspector ---------------------------------------------------------

  Widget _buildInspector() => FutureBuilder<ManuscriptNodeInspection?>(
        future: _inspection,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final inspection = snapshot.data;
          if (inspection == null) {
            return const Text('This node is no longer part of the manuscript.');
          }
          return ListView(
            key: const Key('manuscript-inspector-list'),
            children: [
              _line('Type', inspection.nodeKind.label),
              _line('Status', inspection.status.label),
              _line('Words', '${inspection.wordCount}'),
              _line('Canon', inspection.scope.canonStatus.name),
              _line('Branch', inspection.branchId ?? 'Canon'),
              _line('Project', inspection.projectId),
              _line('Created', _date(inspection.createdAt)),
              _line('Updated', _date(inspection.updatedAt)),
              _line(
                'Connections',
                '${inspection.outgoingConnections.length} out / '
                    '${inspection.incomingConnections.length} in',
              ),
              _line('Versions', '${inspection.history.versionCount}'),
              _line('Audit events', '${inspection.history.auditEventCount}'),
              const SizedBox(height: 12),
              Text(
                'Validation',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              if (inspection.validation.issues.isEmpty)
                const Text(
                  'No validation problems.',
                  key: Key('manuscript-validation-clean'),
                )
              else
                for (final issue in inspection.validation.issues)
                  Padding(
                    key: Key('manuscript-validation-${issue.code}'),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          issue.severity == RecordValidationSeverity.error
                              ? Icons.error_outline
                              : Icons.warning_amber_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(issue.message)),
                      ],
                    ),
                  ),
              const SizedBox(height: 12),
              Text(
                'References (${inspection.references.length})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              for (final reference in inspection.references)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${reference.entity.title} — ${reference.connectionType}'
                    '${reference.entity.exists ? '' : ' (missing)'}',
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Limitations',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              for (final limitation in inspection.capabilities.limitations)
                Text(limitation),
            ],
          );
        },
      );

  // --- History -----------------------------------------------------------

  /// The History tab: what the scene *said*, then what it *was*.
  ///
  /// Prose comes first because it is what an author reaches for. Structure
  /// history — renames, reorders, status changes — has always been here;
  /// prose history is only possible now that the words live in the database
  /// with a bounded history of their own.
  Widget _buildHistory() => ListView(
        key: const Key('manuscript-history-list'),
        children: [
          if (widget.nodeKind == ManuscriptNodeKind.scene) ...[
            _historySectionHeading('Prose'),
            _buildProseHistory(),
            const SizedBox(height: 16),
          ],
          _historySectionHeading('Structure'),
          _buildStructureHistory(),
        ],
      );

  Widget _historySectionHeading(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Widget _buildProseHistory() =>
      FutureBuilder<List<SceneProseSnapshot>>(
        future: _proseHistory,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? const <SceneProseSnapshot>[];
          if (entries.isEmpty) {
            return const Text(
              'No earlier drafts of this scene yet. AuthorOS keeps a copy of '
              'the prose as you write, so a bad rewrite is always recoverable.',
              key: Key('manuscript-prose-history-empty'),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in entries)
                _ManuscriptProseHistoryTile(
                  key: Key('manuscript-prose-snapshot-${entry.id}'),
                  snapshot: entry,
                  canRestore: widget.service.canEditCanon,
                  onRestore: () => _restoreProse(entry),
                ),
            ],
          );
        },
      );

  Widget _buildStructureHistory() => FutureBuilder<List<RecordVersion>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final versions = (snapshot.data ?? const <RecordVersion>[]).reversed
              .toList(growable: false);
          if (versions.isEmpty) {
            return const Text(
              'No history yet. Renaming, reordering, status changes and '
              'connections are all recorded here.',
              key: Key('manuscript-history-empty'),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final version in versions)
                _ManuscriptHistoryTile(
                  key: Key('manuscript-version-${version.id}'),
                  version: version,
                  canRestore: widget.service.canEditCanon,
                  onRestore: () => _restore(version),
                ),
            ],
          );
        },
      );

  Future<void> _restoreProse(SceneProseSnapshot snapshot) async {
    final confirmed = await _confirm(
      title: 'Restore this draft?',
      message: 'This replaces the scene with the ${snapshot.wordCount} words '
          'it held at ${_date(snapshot.capturedAt)}. The prose being replaced '
          'is kept, so you can come straight back.',
      confirmLabel: 'Restore',
    );
    if (!confirmed) return;
    try {
      final restored = await widget.service.restoreSceneProse(
        widget.manuscript,
        sceneId: widget.nodeId,
        snapshotId: snapshot.id,
      );
      _report('Restored the prose from ${_date(snapshot.capturedAt)}.');
      await _adopt(restored);
    } on Object catch (error) {
      _report(error.toString());
    }
  }

  Future<void> _restore(RecordVersion version) async {
    final confirmed = await _confirm(
      title: 'Restore this version?',
      message:
          'This restores the title, status and scene details recorded at '
          '${_date(version.createdAt)}. The prose itself is not rolled back; '
          'use the Prose section above for that.',
      confirmLabel: 'Restore',
    );
    if (!confirmed) return;
    try {
      final restored = await widget.service.restoreVersion(
        widget.manuscript,
        version.id,
      );
      _report('Restored ${version.summary}.');
      await _adopt(restored);
    } on Object catch (error) {
      _report(error.toString());
    }
  }

  // --- Shared ------------------------------------------------------------

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('manuscript-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _ManuscriptConnectionTile extends StatelessWidget {
  const _ManuscriptConnectionTile({
    super.key,
    required this.connection,
    required this.canEdit,
    required this.onRemove,
    this.onOpen,
  });

  final ManuscriptConnection connection;
  final bool canEdit;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.title,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${connection.displayName} • ${connection.recordType}'
                        '${connection.exists ? '' : ' • missing'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onOpen != null)
                  IconButton(
                    key: Key('manuscript-open-${connection.recordId}'),
                    tooltip: 'Open in its Studio',
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                IconButton(
                  key: Key('manuscript-remove-${connection.linkId}'),
                  tooltip: 'Remove connection',
                  onPressed: canEdit ? onRemove : null,
                  icon: const Icon(Icons.link_off, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManuscriptContinuityTile extends StatelessWidget {
  const _ManuscriptContinuityTile({
    super.key,
    required this.issue,
    required this.canResolve,
    required this.onResolve,
  });

  final ContinuityIntegrityIssue issue;
  final bool canResolve;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionLabel = switch (issue.actionKind) {
      ContinuityActionKind.create => 'Create',
      ContinuityActionKind.link => 'Link',
      ContinuityActionKind.review => 'Review',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    switch (issue.severity) {
                      ContinuitySeverity.critical => Icons.error_outline,
                      ContinuitySeverity.warning =>
                        Icons.warning_amber_outlined,
                      ContinuitySeverity.notice => Icons.info_outline,
                    },
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      issue.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(issue.message, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(issue.recommendation, style: theme.textTheme.bodySmall),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  key: Key('manuscript-resolve-${issue.title}'),
                  onPressed: canResolve ? onResolve : null,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One earlier draft of a scene, with the way back to it.
class _ManuscriptProseHistoryTile extends StatelessWidget {
  const _ManuscriptProseHistoryTile({
    super.key,
    required this.snapshot,
    required this.canRestore,
    required this.onRestore,
  });

  final SceneProseSnapshot snapshot;
  final bool canRestore;
  final VoidCallback onRestore;

  /// What this copy of the prose was taken for, in the author's terms.
  String get _reasonLabel => switch (snapshot.reason) {
        SceneProseSnapshotReason.autosave => 'While writing',
        SceneProseSnapshotReason.manual => 'Saved by you',
        SceneProseSnapshotReason.beforeRestore => 'Before a restore',
        SceneProseSnapshotReason.imported => 'First draft on record',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The first line of the scene is what tells one draft from another; a
    // timestamp on its own tells the author nothing about what they would be
    // getting back.
    final preview = snapshot.plainText
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snapshot.wordCount} words • '
                      '${_date(snapshot.capturedAt)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(_reasonLabel, style: theme.textTheme.bodySmall),
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                key: Key('manuscript-restore-prose-${snapshot.id}'),
                onPressed: canRestore ? onRestore : null,
                child: const Text('Restore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManuscriptHistoryTile extends StatelessWidget {
  const _ManuscriptHistoryTile({
    super.key,
    required this.version,
    required this.canRestore,
    required this.onRestore,
  });

  final RecordVersion version;
  final bool canRestore;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      version.summary,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${version.changeType.name} • ${_date(version.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                key: Key('manuscript-restore-${version.id}'),
                onPressed: canRestore ? onRestore : null,
                child: const Text('Restore'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManuscriptBanner extends StatelessWidget {
  const _ManuscriptBanner({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionChoice {
  const _ConnectionChoice({
    required this.recordId,
    required this.typeId,
    required this.title,
  });

  final String recordId;
  final String typeId;
  final String title;
}

class _ConnectRecordDialog extends StatefulWidget {
  const _ConnectRecordDialog({
    required this.service,
    required this.nodeKind,
    required this.records,
  });

  final ManuscriptService service;
  final ManuscriptNodeKind nodeKind;
  final List<AuthorRecord> records;

  @override
  State<_ConnectRecordDialog> createState() => _ConnectRecordDialogState();
}

class _ConnectRecordDialogState extends State<_ConnectRecordDialog> {
  final TextEditingController _search = TextEditingController();

  AuthorRecord? _record;
  String? _typeId;
  List<String> _types = const [];
  bool _loadingTypes = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AuthorRecord> get _visible {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.records;
    return widget.records
        .where((record) =>
            record.title.toLowerCase().contains(query) ||
            record.typeId.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _select(AuthorRecord record) async {
    setState(() {
      _record = record;
      _loadingTypes = true;
      _types = const [];
      _typeId = null;
    });
    final definitions = await widget.service.connectionTypesFor(
      nodeKind: widget.nodeKind,
      recordTypeId: record.typeId,
    );
    if (!mounted) return;
    setState(() {
      _types = definitions.map((definition) => definition.id).toList();
      _typeId = _types.contains('appearsIn') ? 'appearsIn' : _types.firstOrNull;
      _loadingTypes = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return AlertDialog(
      title: const Text('Connect a record'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('manuscript-connect-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Search records',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: ListView(
                key: const Key('manuscript-connect-records'),
                children: [
                  for (final candidate in _visible.take(50))
                    Material(
                      color: candidate.id == record?.id
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: ListTile(
                        key: Key('manuscript-candidate-${candidate.id}'),
                        dense: true,
                        title: Text(candidate.title),
                        subtitle: Text(candidate.typeId),
                        onTap: () => _select(candidate),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingTypes)
              const LinearProgressIndicator()
            else if (record != null)
              DropdownButtonFormField<String>(
                key: const Key('manuscript-connection-type'),
                initialValue: _typeId,
                decoration: const InputDecoration(labelText: 'Connection'),
                items: [
                  for (final type in _types)
                    DropdownMenuItem<String>(value: type, child: Text(type)),
                ],
                onChanged: (value) => setState(() => _typeId = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('manuscript-connect-confirm'),
          onPressed: record == null || _typeId == null
              ? null
              : () => Navigator.of(context).pop(_ConnectionChoice(
                    recordId: record.id,
                    typeId: _typeId!,
                    title: record.title,
                  )),
          child: const Text('Connect'),
        ),
      ],
    );
  }
}

/// Search and filter controls for the manuscript navigator.
class ManuscriptFilterRail extends StatelessWidget {
  const ManuscriptFilterRail({
    super.key,
    required this.manuscript,
    required this.filter,
    required this.controller,
    required this.onChanged,
    required this.matchCount,
  });

  final ManuscriptProjectSummary manuscript;
  final ManuscriptFilter filter;
  final TextEditingController controller;
  final ValueChanged<ManuscriptFilter> onChanged;
  final int matchCount;

  @override
  Widget build(BuildContext context) {
    final povs = <String>{
      for (final chapter in manuscript.chapters)
        for (final scene in chapter.scenes)
          if (scene.pov.trim().isNotEmpty) scene.pov.trim(),
    }.toList()
      ..sort();

    return Column(
      key: const Key('manuscript-filter-rail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('manuscript-filter-query'),
          controller: controller,
          onChanged: (value) => onChanged(filter.copyWith(query: value)),
          decoration: const InputDecoration(
            labelText: 'Search scenes',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final status in ManuscriptNodeStatus.values)
              FilterChip(
                key: Key('manuscript-filter-status-${status.id}'),
                label: Text(status.label),
                selected: filter.statuses.contains(status),
                onSelected: (selected) => onChanged(filter.copyWith(
                  statuses: {
                    ...filter.statuses,
                    if (selected) status,
                  }..removeWhere((item) => !selected && item == status),
                )),
              ),
            FilterChip(
              key: const Key('manuscript-filter-unconnected'),
              label: const Text('Unconnected'),
              selected: filter.onlyUnconnected,
              onSelected: (selected) =>
                  onChanged(filter.copyWith(onlyUnconnected: selected)),
            ),
            FilterChip(
              key: const Key('manuscript-filter-empty'),
              label: const Text('Empty'),
              selected: filter.onlyEmpty,
              onSelected: (selected) =>
                  onChanged(filter.copyWith(onlyEmpty: selected)),
            ),
            for (final pov in povs)
              FilterChip(
                key: Key('manuscript-filter-pov-$pov'),
                label: Text(pov),
                selected: filter.pov == pov,
                onSelected: (selected) =>
                    onChanged(filter.copyWith(pov: selected ? pov : '')),
              ),
          ],
        ),
        if (!filter.isEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$matchCount scene(s) match',
                  key: const Key('manuscript-filter-count'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                key: const Key('manuscript-filter-clear'),
                onPressed: () {
                  controller.clear();
                  onChanged(const ManuscriptFilter());
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Word counts and writing progress for the current selection.
class ManuscriptProgressBar extends StatelessWidget {
  const ManuscriptProgressBar({
    super.key,
    required this.progress,
    required this.label,
  });

  final ManuscriptProgress progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('manuscript-progress'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            Text(
              progress.goalWords > 0
                  ? '${progress.wordCount} / ${progress.goalWords} words'
                  : '${progress.wordCount} words',
              key: const Key('manuscript-progress-words'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.goalWords > 0
                ? progress.goalProgress
                : progress.completionRatio,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${progress.completedScenes}/${progress.sceneCount} scenes complete'
          '${progress.wordsWrittenToday > 0 ? ' • ${progress.wordsWrittenToday} words today' : ''}',
          key: const Key('manuscript-progress-detail'),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
  String two(int input) => input.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
