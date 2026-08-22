/// Node placement for the Knowledge Graph.
///
/// Both layouts are **deterministic pure functions** — the same subgraph always
/// produces the same coordinates. That is a deliberate choice over a
/// force-directed simulation: a physics layout settles somewhere slightly
/// different every run, which makes the view restless to read, impossible to
/// assert on in a widget test, and expensive to hand-roll without a library.
///
/// Coordinates are in an abstract model space centred on the origin. Turning
/// them into canvas pixels is `GraphProjection`'s job, not this file's.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart' show Offset, Size;

import '../core/story_graph.dart';
import '../core/story_graph_modes.dart';

/// Distance between depth rings, and between layers.
const double kGraphRingSpacing = 190;
const double kGraphLayerSpacing = 170;
const double kGraphNodeSpacing = 150;

/// Places every node in [subgraph], keyed by node id.
Map<String, Offset> layoutSubgraph(
  StorySubgraph subgraph, {
  required StoryGraphLayout layout,
}) =>
    switch (layout) {
      StoryGraphLayout.radial => radialLayout(subgraph),
      StoryGraphLayout.layered => layeredLayout(subgraph),
    };

/// Concentric rings around a root.
///
/// Neighbours are grouped by bucket before being placed, so characters sit
/// beside characters and locations beside locations rather than interleaving.
/// A reader can then find a kind of thing by where it is, not only by reading
/// every label.
Map<String, Offset> radialLayout(StorySubgraph subgraph) {
  if (subgraph.isEmpty) return const {};

  final rootId = subgraph.rootId ?? subgraph.nodes.first.id;
  final depths = _depthsFrom(subgraph, rootId);
  final positions = <String, Offset>{rootId: Offset.zero};

  final byDepth = <int, List<StoryGraphNode>>{};
  for (final node in subgraph.nodes) {
    if (node.id == rootId) continue;
    // A node no edge reaches still has to go somewhere; park it on the
    // outermost ring rather than dropping it from its own graph.
    final depth = depths[node.id] ?? _maxDepth(depths) + 1;
    byDepth.putIfAbsent(depth, () => []).add(node);
  }

  for (final entry in byDepth.entries) {
    final ring = entry.key;
    final nodes = entry.value
      ..sort((left, right) {
        final byBucket = left.bucket.index.compareTo(right.bucket.index);
        return byBucket != 0 ? byBucket : left.title.compareTo(right.title);
      });

    final radius = kGraphRingSpacing * ring;
    // Rings are offset by half a step so a node on ring 2 does not sit exactly
    // behind the ring-1 node in front of it.
    final phase = ring.isEven ? 0.0 : math.pi / nodes.length;
    for (var index = 0; index < nodes.length; index++) {
      final angle = (2 * math.pi * index / nodes.length) + phase - math.pi / 2;
      positions[nodes[index].id] = Offset(
        radius * math.cos(angle),
        radius * math.sin(angle),
      );
    }
  }

  return positions;
}

/// Left-to-right layers along the direction of travel.
///
/// This is what makes a plot spine read as
/// `Inciting Incident -> Investigation -> Discovery` and a manuscript as
/// `Book -> Chapter -> Scene`, instead of as a blob with arrows in it.
Map<String, Offset> layeredLayout(StorySubgraph subgraph) {
  if (subgraph.isEmpty) return const {};

  final layers = _longestPathLayers(subgraph);
  final byLayer = <int, List<StoryGraphNode>>{};
  for (final node in subgraph.nodes) {
    byLayer.putIfAbsent(layers[node.id] ?? 0, () => []).add(node);
  }

  final positions = <String, Offset>{};
  final ordered = byLayer.keys.toList()..sort();
  for (final layer in ordered) {
    final nodes = byLayer[layer]!
      ..sort((left, right) {
        final byBucket = left.bucket.index.compareTo(right.bucket.index);
        return byBucket != 0 ? byBucket : left.title.compareTo(right.title);
      });
    // Centre each column vertically so the shape stays balanced whichever
    // layer happens to be widest.
    final offset = (nodes.length - 1) / 2;
    for (var index = 0; index < nodes.length; index++) {
      positions[nodes[index].id] = Offset(
        kGraphLayerSpacing * layer,
        kGraphNodeSpacing * (index - offset),
      );
    }
  }

  return positions;
}

/// Hop count from [rootId], breadth-first over undirected adjacency.
Map<String, int> _depthsFrom(StorySubgraph subgraph, String rootId) {
  final adjacency = _adjacency(subgraph, directed: false);
  final depths = <String, int>{rootId: 0};
  var frontier = <String>[rootId];
  var depth = 0;

  while (frontier.isNotEmpty) {
    depth++;
    final next = <String>[];
    for (final id in frontier) {
      for (final neighbour in adjacency[id] ?? const <String>[]) {
        if (depths.containsKey(neighbour)) continue;
        depths[neighbour] = depth;
        next.add(neighbour);
      }
    }
    frontier = next;
  }
  return depths;
}

/// Assigns each node a layer one past its deepest predecessor.
///
/// Cycles are real in story data — two plot threads can each depend on the
/// other — so this is bounded by node count rather than assuming a DAG, and
/// simply stops improving once it stops changing.
Map<String, int> _longestPathLayers(StorySubgraph subgraph) {
  final incoming = <String, List<String>>{};
  for (final node in subgraph.nodes) {
    incoming[node.id] = [];
  }
  for (final edge in subgraph.edges) {
    // An undirected edge implies no ordering, so it must not push a node into
    // a later layer; only directed edges describe travel.
    if (edge.undirected) continue;
    if (!incoming.containsKey(edge.targetId)) continue;
    if (!incoming.containsKey(edge.sourceId)) continue;
    incoming[edge.targetId]!.add(edge.sourceId);
  }

  final layers = {for (final node in subgraph.nodes) node.id: 0};
  for (var pass = 0; pass < subgraph.nodes.length; pass++) {
    var changed = false;
    for (final entry in incoming.entries) {
      for (final predecessor in entry.value) {
        final candidate = layers[predecessor]! + 1;
        if (candidate > layers[entry.key]!) {
          layers[entry.key] = candidate;
          changed = true;
        }
      }
    }
    if (!changed) break;
  }
  return layers;
}

Map<String, List<String>> _adjacency(
  StorySubgraph subgraph, {
  required bool directed,
}) {
  final adjacency = <String, List<String>>{};
  for (final edge in subgraph.edges) {
    adjacency.putIfAbsent(edge.sourceId, () => []).add(edge.targetId);
    if (!directed) {
      adjacency.putIfAbsent(edge.targetId, () => []).add(edge.sourceId);
    }
  }
  return adjacency;
}

int _maxDepth(Map<String, int> depths) =>
    depths.values.fold(0, (highest, depth) => depth > highest ? depth : highest);

/// Model space to canvas pixels, and back.
///
/// Mirrors Map Studio's `MapProjection` so the two canvases behave the same
/// way under pan and zoom rather than each inventing its own feel.
class GraphProjection {
  const GraphProjection({
    required this.size,
    this.pan = Offset.zero,
    this.zoom = 1,
  });

  final Size size;
  final Offset pan;
  final double zoom;

  static const double minZoom = 0.25;
  static const double maxZoom = 3;

  Offset get _centre => Offset(size.width / 2, size.height / 2);

  Offset toCanvas(Offset model) => _centre + (model * zoom) + pan;

  Offset toModel(Offset canvas) => (canvas - pan - _centre) / zoom;

  GraphProjection copyWith({Size? size, Offset? pan, double? zoom}) =>
      GraphProjection(
        size: size ?? this.size,
        pan: pan ?? this.pan,
        zoom: (zoom ?? this.zoom).clamp(minZoom, maxZoom).toDouble(),
      );

  /// Pan and zoom so every position in [positions] is on screen.
  ///
  /// Returns the projection unchanged when there is nothing to frame, so a
  /// caller can apply it without checking for an empty graph first.
  GraphProjection fitted(
    Iterable<Offset> positions, {
    double padding = 90,
  }) {
    final points = positions.toList();
    if (points.isEmpty || size.isEmpty) return this;

    var left = points.first.dx;
    var right = points.first.dx;
    var top = points.first.dy;
    var bottom = points.first.dy;
    for (final point in points) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }

    final spanX = math.max(right - left, 1.0);
    final spanY = math.max(bottom - top, 1.0);
    final available = Size(
      math.max(size.width - padding * 2, 1),
      math.max(size.height - padding * 2, 1),
    );
    final scale = math
        .min(available.width / spanX, available.height / spanY)
        .clamp(minZoom, maxZoom)
        .toDouble();

    // Centre the content's midpoint, so a lopsided graph is not pinned to one
    // side of the canvas.
    final midpoint = Offset((left + right) / 2, (top + bottom) / 2);
    return GraphProjection(
      size: size,
      zoom: scale,
      pan: -midpoint * scale,
    );
  }
}
