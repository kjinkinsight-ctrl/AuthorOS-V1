/// The drawn graph: edges painted beneath, nodes as real widgets above.
///
/// The split is deliberate and mirrors Map Studio. Nodes are `Positioned`
/// widgets so they get real hit-testing, semantics, tooltips and test keys;
/// edges are painted because 250 edge widgets would cost a great deal for
/// something nobody needs to focus or tap.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/story_graph.dart';
import '../theme/flutter/authoros_theme.dart';
import '../theme/theme_tokens.dart';
import 'graph_layout.dart';

/// Tokens resolved once per build, so the painter is not reaching into an
/// InheritedWidget for every line it draws.
class GraphPalette {
  const GraphPalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.selection,
    required this.label,
    required this.title,
  });

  factory GraphPalette.of(BuildContext context) {
    final scope = StudioThemeScope.of(context);
    return GraphPalette(
      background: scope.color(ThemeColorRef.background),
      surface: scope.color(ThemeColorRef.surface),
      primary: scope.color(ThemeColorRef.primary),
      onSurface: scope.color(ThemeColorRef.onSurface),
      onSurfaceVariant: scope.color(ThemeColorRef.onSurfaceVariant),
      outline: scope.color(ThemeColorRef.outline),
      outlineVariant: scope.color(ThemeColorRef.outlineVariant),
      selection: scope.color(ThemeColorRef.selection),
      label: scope.text(ThemeTextRole.label,
          colorRef: ThemeColorRef.onSurfaceVariant),
      title: scope.text(ThemeTextRole.ui, colorRef: ThemeColorRef.onSurface),
    );
  }

  final Color background;
  final Color surface;
  final Color primary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color selection;
  final TextStyle label;
  final TextStyle title;
}

/// The icon a bucket is drawn with, so a reader can tell a location from a
/// character without reading either label.
IconData iconForBucket(StoryGraphBucket bucket) => switch (bucket) {
      StoryGraphBucket.characters => Icons.person_outline,
      StoryGraphBucket.locations => Icons.place_outlined,
      StoryGraphBucket.events => Icons.event_outlined,
      StoryGraphBucket.plotlines => Icons.timeline_outlined,
      StoryGraphBucket.chapters => Icons.menu_book_outlined,
      StoryGraphBucket.research => Icons.science_outlined,
      StoryGraphBucket.maps => Icons.map_outlined,
      StoryGraphBucket.notes => Icons.sticky_note_2_outlined,
      StoryGraphBucket.worldbuilding => Icons.public_outlined,
      StoryGraphBucket.other => Icons.category_outlined,
    };

class GraphCanvas extends StatelessWidget {
  const GraphCanvas({
    super.key,
    required this.subgraph,
    required this.positions,
    required this.projection,
    required this.palette,
    this.rootId,
    this.selectedId,
    this.onNodeTap,
    this.onNodeOpen,
    this.onNodeDragged,
    this.onPanUpdate,
    this.onBackgroundTap,
    this.draggable = false,
  });

  final StorySubgraph subgraph;
  final Map<String, Offset> positions;
  final GraphProjection projection;
  final GraphPalette palette;
  final String? rootId;
  final String? selectedId;

  /// Selects a node and refocuses the explorer on it.
  final ValueChanged<StoryGraphNode>? onNodeTap;

  /// Opens the node in its owning Studio.
  final ValueChanged<StoryGraphNode>? onNodeOpen;

  /// Canvas mode only: reports a new **model-space** position for a node.
  final void Function(String nodeId, Offset position)? onNodeDragged;

  final ValueChanged<Offset>? onPanUpdate;
  final VoidCallback? onBackgroundTap;

  /// Whether nodes can be rearranged by hand.
  final bool draggable;

  static const double nodeWidth = 132;
  static const double nodeHeight = 52;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          // Background and the pointer surface for anything that starts on
          // empty ground. It sits at the bottom so nodes above answer for
          // themselves first.
          Positioned.fill(
            child: CustomPaint(
              painter: _GraphBackgroundPainter(
                color: palette.outlineVariant,
                background: palette.background,
                projection: projection,
              ),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('graph-canvas-surface'),
              behavior: HitTestBehavior.translucent,
              // The pointer's own travel is the pan, so the drag starts where
              // the finger went down rather than where the slop was crossed.
              dragStartBehavior: DragStartBehavior.down,
              onTap: onBackgroundTap,
              onPanUpdate: onPanUpdate == null
                  ? null
                  : (details) => onPanUpdate!(details.delta),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _GraphEdgePainter(
                subgraph: subgraph,
                positions: positions,
                projection: projection,
                palette: palette,
                selectedId: selectedId,
              ),
            ),
          ),
          for (final node in subgraph.nodes)
            if (positions[node.id] != null)
              _positionedNode(context, node, positions[node.id]!),
          if (subgraph.isEmpty)
            Center(
              child: Padding(
                key: const Key('graph-canvas-empty'),
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nothing to draw yet. Connect some records, or widen the '
                  'filters.',
                  textAlign: TextAlign.center,
                  style: palette.label,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _positionedNode(
    BuildContext context,
    StoryGraphNode node,
    Offset model,
  ) {
    final canvas = projection.toCanvas(model);
    return Positioned(
      left: canvas.dx - nodeWidth / 2,
      top: canvas.dy - nodeHeight / 2,
      width: nodeWidth,
      height: nodeHeight,
      child: _GraphNodeChip(
        node: node,
        palette: palette,
        isRoot: node.id == rootId,
        isSelected: node.id == selectedId,
        onTap: onNodeTap == null ? null : () => onNodeTap!(node),
        onOpen: onNodeOpen == null ? null : () => onNodeOpen!(node),
        onDrag: !draggable || onNodeDragged == null
            ? null
            : (delta) => onNodeDragged!(
                  node.id,
                  model + (delta / projection.zoom),
                ),
      ),
    );
  }
}

class _GraphNodeChip extends StatelessWidget {
  const _GraphNodeChip({
    required this.node,
    required this.palette,
    required this.isRoot,
    required this.isSelected,
    this.onTap,
    this.onOpen,
    this.onDrag,
  });

  final StoryGraphNode node;
  final GraphPalette palette;
  final bool isRoot;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;
  final ValueChanged<Offset>? onDrag;

  @override
  Widget build(BuildContext context) {
    final border = isSelected || isRoot ? palette.primary : palette.outline;
    final chip = Material(
      color: isRoot ? palette.primary.withValues(alpha: 0.12) : palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onDoubleTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: border,
              width: isSelected || isRoot ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconForBucket(node.bucket),
                size: 16,
                color: palette.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      node.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: palette.title,
                    ),
                    Text(
                      node.typeId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: palette.label,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final labelled = Semantics(
      button: true,
      selected: isSelected,
      label: '${node.title}, ${node.typeId}',
      child: Tooltip(
        message: '${node.title} · ${node.bucket.label}',
        waitDuration: const Duration(milliseconds: 600),
        child: chip,
      ),
    );

    final keyed = KeyedSubtree(
      key: Key('graph-node-${node.id}'),
      child: labelled,
    );

    if (onDrag == null) return keyed;
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      dragStartBehavior: DragStartBehavior.down,
      onPanUpdate: (details) => onDrag!(details.delta),
      child: keyed,
    );
  }
}

/// A faint grid, so pan and zoom are legible as movement.
class _GraphBackgroundPainter extends CustomPainter {
  const _GraphBackgroundPainter({
    required this.color,
    required this.background,
    required this.projection,
  });

  final Color color;
  final Color background;
  final GraphProjection projection;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    final step = 48 * projection.zoom;
    if (step < 12) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    final origin = projection.toCanvas(Offset.zero);
    for (var x = origin.dx % step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = origin.dy % step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GraphBackgroundPainter old) =>
      old.projection.pan != projection.pan ||
      old.projection.zoom != projection.zoom ||
      old.color != color ||
      old.background != background;
}

class _GraphEdgePainter extends CustomPainter {
  const _GraphEdgePainter({
    required this.subgraph,
    required this.positions,
    required this.projection,
    required this.palette,
    this.selectedId,
  });

  final StorySubgraph subgraph;
  final Map<String, Offset> positions;
  final GraphProjection projection;
  final GraphPalette palette;
  final String? selectedId;

  /// Labels are unreadable and overlapping when zoomed out, so they only
  /// appear once there is room for them.
  static const double labelZoomThreshold = 0.75;

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in subgraph.edges) {
      final from = positions[edge.sourceId];
      final to = positions[edge.targetId];
      if (from == null || to == null) continue;

      final touchesSelection = selectedId != null &&
          (edge.sourceId == selectedId || edge.targetId == selectedId);
      // A wildcard edge is a real relationship with no type discipline behind
      // it, so it is drawn present but quieter than a typed one.
      final alpha = touchesSelection
          ? 0.95
          : edge.wildcard
              ? 0.28
              : 0.55;
      final paint = Paint()
        ..color = (touchesSelection ? palette.primary : palette.outline)
            .withValues(alpha: alpha)
        ..strokeWidth = touchesSelection ? 2 : 1.4
        ..style = PaintingStyle.stroke;

      final start = projection.toCanvas(from);
      final end = projection.toCanvas(to);
      canvas.drawLine(start, end, paint);

      if (!edge.undirected) {
        _drawArrowHead(canvas, start, end, paint);
      }
      if (projection.zoom >= labelZoomThreshold) {
        _drawLabel(canvas, start, end, edge);
      }
    }

    // Derived edges are dashed and never solid, so no reader can mistake an
    // inference for something the author actually recorded.
    for (final derived in subgraph.derivedEdges) {
      final from = positions[derived.sourceId];
      final to = positions[derived.targetId];
      if (from == null || to == null) continue;
      _drawDashed(
        canvas,
        projection.toCanvas(from),
        projection.toCanvas(to),
        Paint()
          ..color = palette.onSurfaceVariant.withValues(alpha: 0.45)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final direction = end - start;
    final distance = direction.distance;
    if (distance < 1) return;
    final unit = direction / distance;
    // Stop short of the node so the head is not hidden under the chip.
    final tip = end - unit * (GraphCanvas.nodeHeight / 2 + 4);
    const headLength = 10.0;
    const spread = 0.42;
    final angle = math.atan2(unit.dy, unit.dx);
    for (final offset in [spread, -spread]) {
      canvas.drawLine(
        tip,
        tip -
            Offset(
              math.cos(angle + offset) * headLength,
              math.sin(angle + offset) * headLength,
            ),
        paint,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset start,
    Offset end,
    StoryGraphEdge edge,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: edge.typeId, style: palette.label),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 96);

    final midpoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );
    final origin = midpoint - Offset(painter.width / 2, painter.height / 2);

    // A plate behind the text, or the line runs straight through it.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          origin.dx - 4,
          origin.dy - 2,
          painter.width + 8,
          painter.height + 4,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = palette.background.withValues(alpha: 0.85),
    );
    painter.paint(canvas, origin);
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
    final total = (end - start).distance;
    if (total < 1) return;
    final unit = (end - start) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final next = math.min(travelled + dash, total);
      canvas.drawLine(start + unit * travelled, start + unit * next, paint);
      travelled = next + gap;
    }
  }

  @override
  bool shouldRepaint(_GraphEdgePainter old) =>
      old.subgraph != subgraph ||
      old.positions != positions ||
      old.projection.pan != projection.pan ||
      old.projection.zoom != projection.zoom ||
      old.selectedId != selectedId;
}
