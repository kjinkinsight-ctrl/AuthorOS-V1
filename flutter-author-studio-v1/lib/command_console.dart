/// The Command System's surface.
///
/// One text field that answers questions about the whole project, and shows its
/// working. The "Understood as" row is not decoration: a rule-based parser is
/// only trustworthy if the author can see how their words were read and correct
/// it, so every chip names a decision the parser made.
///
/// The console renders results; it does not decide where they go. Tapping a row
/// hands its [SearchNavigationTarget] to the shell, which already knows how to
/// turn one into a Studio.
library;

import 'package:flutter/material.dart';

import 'command_actions.dart';
import 'command_service.dart';
import 'core/command_query.dart';
import 'core/search_models.dart';
import 'persistence/authoros_database.dart';

/// The command palette, opened from anywhere with Cmd/Ctrl+K.
class CommandPalette extends StatelessWidget {
  const CommandPalette({
    super.key,
    required this.projectId,
    required this.onNavigate,
    this.repository,
  });

  final String projectId;
  final ValueChanged<SearchNavigationTarget> onNavigate;
  final DriftConnectedDomainRepository? repository;

  /// Opens the palette over the current screen.
  static Future<void> show(
    BuildContext context, {
    required String projectId,
    required ValueChanged<SearchNavigationTarget> onNavigate,
    DriftConnectedDomainRepository? repository,
  }) =>
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => CommandPalette(
          projectId: projectId,
          onNavigate: onNavigate,
          repository: repository,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      key: const Key('command-palette'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: CommandConsole(
            projectId: projectId,
            repository: repository,
            onNavigate: onNavigate,
            autofocus: true,
          ),
        ),
      ),
    );
  }
}

/// The console itself, used both inside the palette and as a full page.
class CommandConsole extends StatefulWidget {
  const CommandConsole({
    super.key,
    required this.projectId,
    required this.onNavigate,
    this.repository,
    this.autofocus = false,
  });

  final String projectId;
  final ValueChanged<SearchNavigationTarget> onNavigate;
  final DriftConnectedDomainRepository? repository;
  final bool autofocus;

  @override
  State<CommandConsole> createState() => _CommandConsoleState();
}

class _CommandConsoleState extends State<CommandConsole> {
  final _controller = TextEditingController();

  late CommandService _commands;
  late CommandActionService _actions;

  CommandQuery? _reading;
  CommandResult? _result;
  CommandActionPreview? _proposal;
  String _status = '';
  bool _running = false;

  /// Guards against an older parse landing after a newer one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    final repository = widget.repository ?? authorOsRepository;
    _commands =
        CommandService(projectId: widget.projectId, repository: repository);
    _actions = CommandActionService(commands: _commands);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Re-reads the phrase on every keystroke so the chips keep up.
  ///
  /// Parsing is a pure function over a memoised vocabulary, so this costs
  /// nothing worth measuring — and it is what makes the grammar feel like a
  /// conversation rather than a guessing game.
  Future<void> _reparse(String text) async {
    final generation = ++_generation;
    if (text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _reading = null;
          _result = null;
          _proposal = null;
          _status = '';
        });
      }
      return;
    }
    final query = await _commands.parse(text);
    if (!mounted || generation != _generation) return;
    setState(() => _reading = query);
  }

  Future<void> _run({String? anchorId, String? connectionTypeId}) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _running = true;
      _status = '';
      _proposal = null;
    });

    final query = await _commands.parse(text);
    if (!mounted || generation != _generation) return;

    if (query.isAction) {
      final proposal = await _actions.prepare(
        query,
        sourceId: anchorId,
        connectionTypeId: connectionTypeId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _reading = query;
        _result = null;
        _proposal = proposal;
        _running = false;
      });
      return;
    }

    final result = await _commands.execute(query, anchorId: anchorId);
    if (!mounted || generation != _generation) return;
    setState(() {
      _reading = query;
      _result = result;
      _running = false;
    });
  }

  Future<void> _confirm() async {
    final proposal = _proposal;
    if (proposal == null) return;
    setState(() => _running = true);
    final result = await _actions.apply(proposal, confirmed: true);
    if (!mounted) return;
    setState(() {
      _running = false;
      _proposal = null;
      _status = result.message;
    });
  }

  void _cancel() => setState(() {
        _proposal = null;
        _status = 'Nothing was changed.';
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const Key('universal-search-field'),
                controller: _controller,
                autofocus: widget.autofocus,
                textInputAction: TextInputAction.search,
                onChanged: _reparse,
                onSubmitted: (_) => _run(),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Show everything connected to…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  prefixIcon: Icon(
                    Icons.bolt_outlined,
                    color: theme.colorScheme.onSurface,
                  ),
                  suffixIcon: _running
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded),
                          tooltip: 'Run',
                          onPressed: _run,
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_reading != null) ...[
                const SizedBox(height: 12),
                _UnderstoodAs(query: _reading!),
              ],
            ],
          ),
        ),
        Flexible(child: _body(theme)),
      ],
    );
  }

  Widget _body(ThemeData theme) {
    if (_status.isNotEmpty) return _Notice(message: _status);
    final proposal = _proposal;
    if (proposal != null) {
      return _ProposalCard(
        proposal: proposal,
        onConfirm: _confirm,
        onCancel: _cancel,
        onChooseConnection: (typeId) => _run(connectionTypeId: typeId),
      );
    }
    final result = _result;
    if (result == null) return const _Hint();
    if (result.needsDisambiguation) {
      return _Disambiguation(
        prompt: result.candidatePrompt,
        candidates: result.candidates,
        onPick: (id) => _run(anchorId: id),
      );
    }
    if (result.isEmpty) return _Notice(message: result.message);
    return _Results(
      result: result,
      onNavigate: widget.onNavigate,
    );
  }
}

/// The parser, showing its working.
class _UnderstoodAs extends StatelessWidget {
  const _UnderstoodAs({required this.query});

  final CommandQuery query;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('command-understanding'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          query.isFreeText ? 'No command found, so:' : 'Understood as',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final term in query.terms)
              _Chip(
                label: term.label,
                muted: term.kind == CommandTermKind.ignored,
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted
            ? Colors.transparent
            : theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: muted
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSecondaryContainer,
          fontStyle: muted ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result, required this.onNavigate});

  final CommandResult result;
  final ValueChanged<SearchNavigationTarget> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('command-results'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      shrinkWrap: true,
      children: [
        if (result.message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              result.message,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final group in result.groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
            child: Text(
              '${group.label}  ·  ${group.rows.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
          ),
          for (final row in group.rows)
            _ResultTile(row: row, onNavigate: onNavigate),
        ],
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.row, required this.onNavigate});

  final CommandRow row;
  final ValueChanged<SearchNavigationTarget> onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = row.navigationTarget;
    final detail = row.detail.isNotEmpty ? row.detail : row.subtitle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: target == null ? null : () => onNavigate(target),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  switch (row.kind) {
                    CommandRowKind.manuscriptNode =>
                      Icons.menu_book_outlined,
                    CommandRowKind.issue => Icons.warning_amber_rounded,
                    CommandRowKind.record => Icons.circle_outlined,
                  },
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (detail.isNotEmpty)
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (target != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when a name matched more than one thing.
class _Disambiguation extends StatelessWidget {
  const _Disambiguation({
    required this.prompt,
    required this.candidates,
    required this.onPick,
  });

  final String prompt;
  final List<CommandCandidate> candidates;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('command-disambiguation'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      shrinkWrap: true,
      children: [
        Text(prompt, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        for (final candidate in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton(
              onPressed: () => onPick(candidate.id),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('${candidate.title}  ·  ${candidate.typeLabel}'),
              ),
            ),
          ),
      ],
    );
  }
}

/// A change, described before it happens.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.onConfirm,
    required this.onCancel,
    required this.onChooseConnection,
  });

  final CommandActionPreview proposal;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final ValueChanged<String> onChooseConnection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('command-proposal'),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      shrinkWrap: true,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    proposal.isRefused
                        ? Icons.block_outlined
                        : Icons.edit_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    proposal.isRefused ? 'Not run' : 'This will change your '
                        'project',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(proposal.summary, style: theme.textTheme.bodyMedium),
              if (proposal.needsConnectionChoice) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final choice in proposal.connectionChoices)
                      ActionChip(
                        label: Text(choice.label),
                        onPressed: () => onChooseConnection(choice.typeId),
                      ),
                  ],
                ),
              ],
              if (proposal.canApply) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: onCancel, child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('command-confirm'),
                      onPressed: onConfirm,
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  static const _examples = <String>[
    'Show everything connected to Kali',
    'Show all unresolved plot threads',
    'Show characters appearing in Chapter 20',
    'Show scenes with no location',
    'Show canon conflicts',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask about anything in this project.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (final example in _examples)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                example,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
