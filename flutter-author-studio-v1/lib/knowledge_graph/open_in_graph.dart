/// "Open in graph", shared by every Studio that shows a record.
///
/// Cross-Studio integration is the whole point of this phase, and five bespoke
/// buttons would be five places to drift. This is one widget: a Studio supplies
/// the record and the callback it already uses for navigation, and the shell
/// does the routing — Studios never navigate themselves.
library;

import 'package:flutter/material.dart';

import '../theme/flutter/authoros_theme.dart';
import '../theme/theme_tokens.dart';

/// A button that asks the shell to open [recordId] in the Knowledge Graph.
///
/// Renders nothing when [onOpen] is null, so a Studio embedded somewhere
/// without routing does not show an action that cannot work.
class OpenInGraphButton extends StatelessWidget {
  const OpenInGraphButton({
    super.key,
    required this.recordId,
    required this.onOpen,
    this.label = 'Open in graph',
    this.compact = false,
  });

  final String recordId;

  /// Emits the Studio's own navigation request.
  ///
  /// Each Studio has its own request type, so the callback is a plain closure
  /// rather than one shared payload: this widget owns the affordance, and the
  /// Studio owns saying where it wants to go.
  final VoidCallback? onOpen;

  final String label;

  /// Icon-only, for a dense toolbar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (onOpen == null || recordId.isEmpty) {
      return const SizedBox.shrink();
    }

    final scope = StudioThemeScope.maybeOf(context);
    final labelStyle = scope?.text(
      ThemeTextRole.ui,
      colorRef: ThemeColorRef.primary,
    );

    if (compact) {
      return IconButton(
        key: Key('open-in-graph-$recordId'),
        tooltip: label,
        icon: const Icon(Icons.share_outlined, size: 18),
        onPressed: onOpen,
      );
    }

    return TextButton.icon(
      key: Key('open-in-graph-$recordId'),
      onPressed: onOpen,
      icon: const Icon(Icons.share_outlined, size: 16),
      label: Text(label, style: labelStyle),
    );
  }
}
