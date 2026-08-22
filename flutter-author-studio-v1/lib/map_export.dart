/// Map Studio Phase 6 — export.
///
/// One drawing, three renderers. [MapDrawingBuilder] turns the canonical
/// projections into a list of primitives in export space, and PNG, SVG and PDF
/// each paint that same list. They therefore cannot disagree about where a city
/// is or which labels fitted — the failure mode where a preview and an export
/// show different maps is impossible by construction rather than by testing.
///
/// ```
/// MapCanvasData ┐
/// MapOverlayData├─▶ MapDrawingBuilder ─▶ MapDrawing ─┬─▶ MapSvgRenderer
/// MapWorldState ┘         ▲                          ├─▶ MapPdfRenderer
/// MapPresentation ────────┘                          └─▶ (PNG, painted by the
///                                                        view from the same
///                                                        drawing)
/// ```
///
/// Nothing here reads a database, writes a record or holds world data of its
/// own. Colour arrives as plain ARGB integers resolved by the view from the
/// Theme Engine, so this file stays free of Flutter and free of literal colour
/// exactly like the rest of the Map Studio domain.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'map_domain.dart';
import 'map_overlays.dart';
import 'map_presentation.dart';
import 'map_terrain.dart';
import 'map_world.dart';

/// What an export produces.
enum MapExportFormat { png, svg, pdf, json }

extension MapExportFormatDetail on MapExportFormat {
  String get label => switch (this) {
        MapExportFormat.png => 'PNG image',
        MapExportFormat.svg => 'SVG vector',
        MapExportFormat.pdf => 'PDF document',
        MapExportFormat.json => 'JSON data',
      };

  String get extension => switch (this) {
        MapExportFormat.png => 'png',
        MapExportFormat.svg => 'svg',
        MapExportFormat.pdf => 'pdf',
        MapExportFormat.json => 'json',
      };

  String get mimeType => switch (this) {
        MapExportFormat.png => 'image/png',
        MapExportFormat.svg => 'image/svg+xml',
        MapExportFormat.pdf => 'application/pdf',
        MapExportFormat.json => 'application/json',
      };

  bool get isVector => this == MapExportFormat.svg || this == MapExportFormat.pdf;
}

/// A page an export may be laid out on.
///
/// Sizes are in points (1/72 inch), the unit `package:pdf` works in, so a print
/// export is the size it says it is.
enum MapPageSize { a4, a3, a2, letter, square, wide }

extension MapPageSizeDetail on MapPageSize {
  String get label => switch (this) {
        MapPageSize.a4 => 'A4',
        MapPageSize.a3 => 'A3',
        MapPageSize.a2 => 'A2',
        MapPageSize.letter => 'Letter',
        MapPageSize.square => 'Square',
        MapPageSize.wide => 'Widescreen',
      };

  /// Width and height in points, portrait.
  (double width, double height) get points => switch (this) {
        MapPageSize.a4 => (595.28, 841.89),
        MapPageSize.a3 => (841.89, 1190.55),
        MapPageSize.a2 => (1190.55, 1683.78),
        MapPageSize.letter => (612, 792),
        MapPageSize.square => (720, 720),
        MapPageSize.wide => (1280, 720),
      };
}

/// A named set of output settings (§25).
///
/// Note on colour: every preset produces **sRGB**. AuthorOS performs no
/// colour-space conversion, so no preset claims CMYK — a print shop converts,
/// and saying otherwise here would be a claim the code cannot honour.
enum MapExportPreset { screen, web, print, book, poster, presentation }

extension MapExportPresetDetail on MapExportPreset {
  String get label => switch (this) {
        MapExportPreset.screen => 'Screen',
        MapExportPreset.web => 'Web',
        MapExportPreset.print => 'Print',
        MapExportPreset.book => 'Book',
        MapExportPreset.poster => 'Poster',
        MapExportPreset.presentation => 'Presentation',
      };

  /// Dots per inch for raster output.
  double get dpi => switch (this) {
        MapExportPreset.screen => 96,
        MapExportPreset.web => 96,
        MapExportPreset.print => 300,
        MapExportPreset.book => 300,
        MapExportPreset.poster => 200,
        MapExportPreset.presentation => 144,
      };

  /// The pixel ratio a raster capture should use, relative to logical pixels.
  double get pixelRatio => dpi / 96;

  MapPageSize get page => switch (this) {
        MapExportPreset.screen => MapPageSize.wide,
        MapExportPreset.web => MapPageSize.wide,
        MapExportPreset.print => MapPageSize.a3,
        MapExportPreset.book => MapPageSize.a4,
        MapExportPreset.poster => MapPageSize.a2,
        MapExportPreset.presentation => MapPageSize.wide,
      };

  /// Margin in points. A book map keeps a wider inner margin for the gutter.
  double get margin => switch (this) {
        MapExportPreset.screen || MapExportPreset.web => 24,
        MapExportPreset.presentation => 32,
        MapExportPreset.print => 48,
        MapExportPreset.book => 54,
        MapExportPreset.poster => 64,
      };

  String get description => switch (this) {
        MapExportPreset.screen => 'For looking at on a screen.',
        MapExportPreset.web => 'For a web page or a reader portal.',
        MapExportPreset.print => 'A3 at 300 DPI, sRGB.',
        MapExportPreset.book => 'A4 at 300 DPI with a gutter margin, sRGB.',
        MapExportPreset.poster => 'A2 at 200 DPI, sRGB.',
        MapExportPreset.presentation => 'Widescreen, for slides.',
      };
}

/// The colours a drawing uses, as plain ARGB integers.
///
/// Resolved by the view from the Theme Engine and handed in. Keeping them as
/// integers is what lets the renderers live outside Flutter without any Map
/// Studio file ever naming a colour.
class MapDrawPalette {
  const MapDrawPalette({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.outline,
    required this.accent,
    required this.regionFill,
    this.terrain = const {},
  });

  final int background;
  final int surface;
  final int ink;
  final int muted;
  final int outline;
  final int accent;
  final int regionFill;

  /// One colour per painted terrain kind, derived by the view exactly as the
  /// on-screen map derives it.
  final Map<MapTerrainKind, int> terrain;
}

/// One thing to paint.
sealed class MapDrawPrimitive {
  const MapDrawPrimitive({required this.layer});

  /// Which [MapLayer] this belongs to. Painting walks the declared order, so an
  /// export stacks exactly as the screen does.
  final MapLayer layer;
}

class MapDrawRect extends MapDrawPrimitive {
  const MapDrawRect({
    required super.layer,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.fill,
    this.stroke,
    this.strokeWidth = 1,
    this.opacity = 1,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final int? fill;
  final int? stroke;
  final double strokeWidth;
  final double opacity;
}

class MapDrawPolygon extends MapDrawPrimitive {
  const MapDrawPolygon({
    required super.layer,
    required this.points,
    this.fill,
    this.stroke,
    this.strokeWidth = 1.5,
    this.opacity = 1,
    this.closed = true,
    this.dashed = false,
  });

  /// Alternating x, y in export space.
  final List<double> points;
  final int? fill;
  final int? stroke;
  final double strokeWidth;
  final double opacity;
  final bool closed;
  final bool dashed;
}

class MapDrawCircle extends MapDrawPrimitive {
  const MapDrawCircle({
    required super.layer,
    required this.x,
    required this.y,
    required this.radius,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
  });

  final double x;
  final double y;
  final double radius;
  final int? fill;
  final int? stroke;
  final double strokeWidth;
}

class MapDrawText extends MapDrawPrimitive {
  const MapDrawText({
    required super.layer,
    required this.text,
    required this.x,
    required this.y,
    required this.size,
    required this.colour,
    this.align = MapTextAlign.centre,
    this.bold = false,
    this.opacity = 1,
  });

  final String text;
  final double x;
  final double y;
  final double size;
  final int colour;
  final MapTextAlign align;
  final bool bold;
  final double opacity;
}

enum MapTextAlign { start, centre, end }

/// A finished map, ready to be painted in any format.
class MapDrawing {
  const MapDrawing({
    required this.width,
    required this.height,
    required this.primitives,
    required this.palette,
    this.gaps = const [],
  });

  final double width;
  final double height;
  final List<MapDrawPrimitive> primitives;
  final MapDrawPalette palette;

  /// What the canonical model could not supply, carried through to the export
  /// so a caller can report it rather than discovering a blank corner.
  final List<MapPresentationGap> gaps;

  int get primitiveCount => primitives.length;

  /// Primitives in draw order: the declared [MapLayer] order, then insertion
  /// order within a layer. Deterministic, and identical for every renderer.
  List<MapDrawPrimitive> get ordered {
    final byLayer = <MapLayer, List<MapDrawPrimitive>>{};
    for (final primitive in primitives) {
      byLayer.putIfAbsent(primitive.layer, () => []).add(primitive);
    }
    return [
      for (final layer in MapLayer.values) ...?byLayer[layer],
    ];
  }
}

/// What to draw, and how big.
class MapExportRequest {
  const MapExportRequest({
    required this.presentation,
    required this.canvas,
    required this.palette,
    this.overlays,
    this.world,
    this.preset = MapExportPreset.screen,
    this.format = MapExportFormat.png,
    this.landscape = true,
    this.labelDetail,
  });

  /// A printed map shows everything that fits; a small screen export shows the
  /// places that matter. Both are the author's to override.
  static MapLabelDetail _detailFor(MapExportPreset preset) => switch (preset) {
        MapExportPreset.print ||
        MapExportPreset.book ||
        MapExportPreset.poster =>
          MapLabelDetail.full,
        MapExportPreset.presentation => MapLabelDetail.standard,
        MapExportPreset.screen || MapExportPreset.web => MapLabelDetail.standard,
      };

  final MapPresentation presentation;

  /// The canonical projections. A reader export passes the filtered ones.
  final MapCanvasData canvas;
  final MapOverlayData? overlays;
  final MapWorldState? world;

  final MapDrawPalette palette;
  final MapExportPreset preset;
  final MapExportFormat format;
  final bool landscape;

  /// Set to override the preset's own choice.
  final MapLabelDetail? labelDetail;

  /// How much labelling this export asks for.
  MapLabelDetail get labelling => labelDetail ?? _detailFor(preset);

  /// Page size in points, oriented.
  (double width, double height) get pageSize {
    final (width, height) = preset.page.points;
    return landscape && width < height ? (height, width) : (width, height);
  }

  String get suggestedFileName {
    final title = presentation.title.trim().isEmpty
        ? 'map'
        : presentation.title.trim();
    final slug = title
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-+|-+\$'), '');
    return '${slug.isEmpty ? 'map' : slug}.${format.extension}';
  }
}

/// Turns the canonical projections into primitives.
///
/// The only place in Phase 6 that decides where anything goes. Everything it
/// reads is a projection it was handed; it never queries, never writes and
/// never invents a position.
class MapDrawingBuilder {
  const MapDrawingBuilder({this.planner = const MapLabelPlanner()});

  final MapLabelPlanner planner;

  MapDrawing build(MapExportRequest request) {
    final (pageWidth, pageHeight) = request.pageSize;
    final margin = request.preset.margin;
    final presentation = request.presentation;
    final palette = request.palette;

    // Room for the title block and the footer, when they are drawn.
    final headerHeight = presentation.shows(MapDecoration.titleBlock) ? 64.0 : 0;
    final footerHeight = presentation.shows(MapDecoration.scaleBar) ||
            presentation.shows(MapDecoration.legend)
        ? 54.0
        : 0;

    final frame = _Frame(
      left: margin,
      top: margin + headerHeight,
      width: pageWidth - margin * 2,
      height: pageHeight - margin * 2 - headerHeight - footerHeight,
    );

    final extent = MapExtent.fromRecord(request.canvas.map.record);
    final projection = MapProjection(
      extent: extent,
      canvasWidth: frame.width,
      canvasHeight: frame.height,
      camera: MapCamera.identity,
    );
    double px(MapPosition position) =>
        frame.left + projection.toCanvas(position).x;
    double py(MapPosition position) =>
        frame.top + projection.toCanvas(position).y;

    final primitives = <MapDrawPrimitive>[];
    final style = presentation.theme.styleFor(request.canvas.map.visualStyle);

    // --- ground ----------------------------------------------------------
    primitives.add(
      MapDrawRect(
        layer: MapLayer.base,
        left: 0,
        top: 0,
        width: pageWidth,
        height: pageHeight,
        fill: palette.background,
      ),
    );
    primitives.add(
      MapDrawRect(
        layer: MapLayer.base,
        left: frame.left,
        top: frame.top,
        width: frame.width,
        height: frame.height,
        fill: palette.surface,
        stroke: presentation.shows(MapDecoration.frame) ? palette.ink : null,
        strokeWidth: presentation.shows(MapDecoration.frame) ? 2.5 : 1,
      ),
    );

    if (presentation.shows(MapDecoration.grid)) {
      const divisions = 8;
      for (var index = 1; index < divisions; index++) {
        final x = frame.left + frame.width * index / divisions;
        final y = frame.top + frame.height * index / divisions;
        primitives.add(
          MapDrawPolygon(
            layer: MapLayer.base,
            points: [x, frame.top, x, frame.top + frame.height],
            stroke: palette.outline,
            strokeWidth: 0.5,
            opacity: 0.4,
            closed: false,
          ),
        );
        primitives.add(
          MapDrawPolygon(
            layer: MapLayer.base,
            points: [frame.left, y, frame.left + frame.width, y],
            stroke: palette.outline,
            strokeWidth: 0.5,
            opacity: 0.4,
            closed: false,
          ),
        );
      }
    }

    // --- terrain ---------------------------------------------------------
    //
    // Painted as merged rectangles rather than one per cell. Two reasons, and
    // the first is visual: translucent cells that merely abut are blended twice
    // along their shared edge, which prints as a lattice of darker seams across
    // the whole map — a 48x48 grid of them. Merging removes the edges instead
    // of hiding them. The second is size: a uniform map becomes a handful of
    // rectangles rather than 2,304, which is the difference between a 220 KB
    // SVG and a 12 KB one.
    final terrain = request.canvas.map.terrain;
    if (!terrain.isEmpty) {
      for (final block in _mergeTerrain(terrain)) {
        final colour = palette.terrain[block.kind];
        if (colour == null) continue;
        final topLeft = terrain.rectFor(block.column, block.row, extent);
        final bottomRight = terrain.rectFor(
          block.column + block.width - 1,
          block.row + block.height - 1,
          extent,
        );
        final left = px(topLeft.topLeft);
        final top = py(topLeft.topLeft);
        primitives.add(
          MapDrawRect(
            layer: MapLayer.terrain,
            left: left,
            top: top,
            width: px(bottomRight.bottomRight) - left,
            height: py(bottomRight.bottomRight) - top,
            fill: colour,
            opacity: style.terrainOpacity,
          ),
        );
      }
    }

    // --- regions ---------------------------------------------------------
    for (final region in request.canvas.regions) {
      // A bounds geometry stores two corners; drawn as a polygon that is a
      // diagonal line, not a territory. asPolygon() is what Phase 2 already
      // provides for exactly this.
      final points = region.geometry.asPolygon().points;
      if (points.length < 3) continue;
      primitives.add(
        MapDrawPolygon(
          layer: MapLayer.regions,
          points: [
            for (final point in points) ...[px(point), py(point)],
          ],
          fill: palette.regionFill,
          stroke: palette.outline,
          opacity: 0.55,
        ),
      );
    }

    // --- borders and routes, from the world projection --------------------
    final world = request.world;
    if (world != null) {
      for (final border in world.borders) {
        final shape = border.geometry.kind == MapGeometryKind.bounds
            ? border.geometry.asPolygon()
            : border.geometry;
        final points = shape.points;
        if (points.length < 2) continue;
        primitives.add(
          MapDrawPolygon(
            layer: MapLayer.borders,
            points: [
              for (final point in points) ...[px(point), py(point)],
            ],
            stroke: palette.ink,
            strokeWidth: 1.8,
            closed: shape.kind == MapGeometryKind.polygon,
            dashed: border.kind == MapBorderKind.disputed ||
                border.kind == MapBorderKind.temporary,
            opacity: border.kind == MapBorderKind.historical ? 0.45 : 0.85,
          ),
        );
      }
      for (final route in world.routes) {
        primitives.add(
          MapDrawPolygon(
            layer: MapLayer.worldRoutes,
            points: [
              px(route.fromPosition),
              py(route.fromPosition),
              px(route.toPosition),
              py(route.toPosition),
            ],
            stroke: palette.muted,
            strokeWidth: 1.6,
            closed: false,
            dashed: route.kind == MapRouteKind.hidden ||
                route.kind == MapRouteKind.path ||
                route.kind == MapRouteKind.magical ||
                route.kind == MapRouteKind.mountainPass,
          ),
        );
      }
    }

    // --- places and markers ----------------------------------------------
    final labels = <MapLabel>[];
    for (final location in request.canvas.locations) {
      final x = px(location.position);
      final y = py(location.position);
      final rank = world?.settlementById(location.record.id)?.kind.rank ?? 3;
      primitives.add(
        MapDrawCircle(
          layer: MapLayer.locations,
          x: x,
          y: y,
          radius: 2.5 + rank * 0.6,
          fill: palette.ink,
          stroke: palette.surface,
          strokeWidth: 1,
        ),
      );
      // Below the pin, because the story overlay badge for this place sits
      // above it. Two things competing for the same spot is how "Aurel" ends
      // up printed underneath a character marker.
      labels.add(
        MapLabel(
          id: location.record.id,
          text: location.name,
          tier: MapLabelTierDetail.forRank(rank),
          x: x,
          y: y + (14 + rank * 0.7),
        ),
      );
    }
    for (final marker in request.canvas.markers) {
      final x = px(marker.position);
      final y = py(marker.position);
      primitives.add(
        MapDrawCircle(
          layer: MapLayer.markers,
          x: x,
          y: y,
          radius: 3,
          fill: palette.accent,
          stroke: palette.surface,
        ),
      );
      if (marker.label.trim().isNotEmpty) {
        labels.add(
          MapLabel(
            id: marker.record.id,
            text: marker.label,
            tier: MapLabelTier.minor,
            x: x,
            y: y + 11,
          ),
        );
      }
    }

    // --- story overlays ---------------------------------------------------
    //
    // Every badge drawn here is also registered as an obstacle, so a place name
    // is never printed underneath one.
    final obstacles = <(double, double, double, double)>[];
    final overlays = request.overlays;
    if (overlays != null) {
      for (final journey in overlays.journeys) {
        if (!journey.isDrawable) continue;
        primitives.add(
          MapDrawPolygon(
            layer: MapLayer.storyPaths,
            points: [
              for (final stop in journey.stops) ...[
                px(stop.position),
                py(stop.position),
              ],
            ],
            stroke: palette.accent,
            strokeWidth: 1.6,
            closed: false,
            opacity: 0.8,
          ),
        );
      }
      for (final cluster in MapOverlayCluster.clusterAll([
        for (final item in overlays.items)
          if (item.kind != MapOverlayKind.location) item,
      ])) {
        final x = px(cluster.position);
        final y = py(cluster.position) - 16;
        obstacles.add((x - 8, y - 8, x + 8, y + 8));
        primitives.add(
          MapDrawCircle(
            layer: MapLayer.storyOverlays,
            x: x,
            y: y,
            radius: 6,
            fill: palette.surface,
            stroke: palette.accent,
            strokeWidth: 1.2,
          ),
        );
        primitives.add(
          MapDrawText(
            layer: MapLayer.storyOverlays,
            text: cluster.isSingle
                ? cluster.primary.kind.label.substring(0, 1)
                : '${cluster.count}',
            x: x,
            y: y + 3,
            size: 8,
            colour: palette.ink,
          ),
        );
      }
    }

    // --- labels, placed without collisions --------------------------------
    if (presentation.shows(MapDecoration.compass)) {
      final cx = frame.left + frame.width - 30;
      final cy = frame.top + 30;
      obstacles.add((cx - 20, cy - 22, cx + 20, cy + 20));
    }
    for (final label in planner.plan(
      labels,
      scale: request.labelling.scale,
      canvasWidth: pageWidth,
      canvasHeight: pageHeight,
      obstacles: obstacles,
    )) {
      primitives.add(
        MapDrawText(
          layer: MapLayer.markers,
          text: label.text,
          x: label.x,
          y: label.y,
          size: 9 * label.tier.sizeFactor,
          colour: palette.ink,
          bold: label.tier == MapLabelTier.primary,
        ),
      );
    }

    // --- decorations ------------------------------------------------------
    if (presentation.shows(MapDecoration.titleBlock)) {
      primitives.add(
        MapDrawText(
          layer: MapLayer.interaction,
          text: presentation.title,
          x: pageWidth / 2,
          y: margin + 22,
          size: 20,
          colour: palette.ink,
          bold: true,
        ),
      );
      final subtitle = presentation.subtitle.trim().isEmpty
          ? presentation.metadata.lines.skip(1).join(' · ')
          : presentation.subtitle;
      if (subtitle.isNotEmpty) {
        primitives.add(
          MapDrawText(
            layer: MapLayer.interaction,
            text: subtitle,
            x: pageWidth / 2,
            y: margin + 42,
            size: 10,
            colour: palette.muted,
          ),
        );
      }
    }

    if (presentation.shows(MapDecoration.compass)) {
      final cx = frame.left + frame.width - 30;
      final cy = frame.top + 30;
      primitives.add(
        MapDrawCircle(
          layer: MapLayer.interaction,
          x: cx,
          y: cy,
          radius: 14,
          stroke: palette.ink,
          strokeWidth: 1.2,
        ),
      );
      primitives.add(
        MapDrawPolygon(
          layer: MapLayer.interaction,
          points: [cx, cy - 11, cx - 4, cy + 6, cx + 4, cy + 6],
          fill: palette.ink,
        ),
      );
      primitives.add(
        MapDrawText(
          layer: MapLayer.interaction,
          text: 'N',
          x: cx,
          y: cy - 16,
          size: 8,
          colour: palette.ink,
          bold: true,
        ),
      );
    }

    final scaleBar = presentation.scaleBar;
    if (presentation.shows(MapDecoration.scaleBar) && scaleBar != null) {
      final barWidth = projection.scaleX * scaleBar.mapUnits;
      final y = frame.top + frame.height + 22;
      primitives.add(
        MapDrawPolygon(
          layer: MapLayer.interaction,
          points: [frame.left, y, frame.left + barWidth, y],
          stroke: palette.ink,
          strokeWidth: 2,
          closed: false,
        ),
      );
      primitives.add(
        MapDrawText(
          layer: MapLayer.interaction,
          text: scaleBar.text,
          x: frame.left + barWidth / 2,
          y: y + 12,
          size: 8,
          colour: palette.muted,
        ),
      );
    }

    if (presentation.shows(MapDecoration.legend)) {
      final entries = <String>[
        for (final entry in request.canvas.map.legend.take(4))
          '${entry.label} ${(entry.coverage * 100).round()}%',
        if (world != null && world.factions.isNotEmpty)
          '${world.factions.length} '
              "${world.factions.length == 1 ? 'faction' : 'factions'}",
      ];
      final overlayKinds = <MapOverlayKind>{
        if (overlays != null)
          for (final item in overlays.items)
            if (item.kind != MapOverlayKind.location) item.kind,
      };
      for (final kind in overlayKinds) {
        entries.add('${kind.label.substring(0, 1)} ${kind.label.toLowerCase()}');
      }
      if (entries.isNotEmpty) {
        primitives.add(
          MapDrawText(
            layer: MapLayer.interaction,
            text: entries.join('   ·   '),
            x: frame.left + frame.width,
            y: frame.top + frame.height + 22,
            size: 8,
            colour: palette.muted,
            align: MapTextAlign.end,
          ),
        );
      }
    }

    if (presentation.shows(MapDecoration.watermark) &&
        presentation.watermark.trim().isNotEmpty) {
      primitives.add(
        MapDrawText(
          layer: MapLayer.interaction,
          text: presentation.watermark.trim(),
          x: pageWidth / 2,
          y: pageHeight / 2,
          size: 42,
          colour: palette.muted,
          opacity: 0.12,
        ),
      );
    }

    if (presentation.credit.trim().isNotEmpty) {
      primitives.add(
        MapDrawText(
          layer: MapLayer.interaction,
          text: presentation.credit.trim(),
          x: pageWidth / 2,
          y: pageHeight - margin / 2,
          size: 8,
          colour: palette.muted,
        ),
      );
    }

    return MapDrawing(
      width: pageWidth,
      height: pageHeight,
      primitives: primitives,
      palette: palette,
      gaps: presentation.gaps,
    );
  }
}

/// One rectangle of a single terrain kind.
class _TerrainBlock {
  const _TerrainBlock({
    required this.kind,
    required this.column,
    required this.row,
    required this.width,
    required this.height,
  });

  final MapTerrainKind kind;
  final int column;
  final int row;
  final int width;
  final int height;
}

/// Greedily merges same-kind cells into the largest rectangles it can.
///
/// Scans in reading order; from each unclaimed cell it extends right while the
/// kind holds, then down while the whole run still matches. Deterministic, and
/// exact — every painted cell ends up in exactly one rectangle, so the merged
/// picture is the same picture.
List<_TerrainBlock> _mergeTerrain(MapTerrainGrid terrain) {
  final claimed = List<bool>.filled(terrain.columns * terrain.rows, false);
  bool taken(int column, int row) => claimed[row * terrain.columns + column];
  void claim(int column, int row) => claimed[row * terrain.columns + column] = true;

  final blocks = <_TerrainBlock>[];
  for (var row = 0; row < terrain.rows; row++) {
    for (var column = 0; column < terrain.columns; column++) {
      if (taken(column, row)) continue;
      final kind = terrain.kindAt(column, row);
      if (kind == null) {
        claim(column, row);
        continue;
      }

      var width = 1;
      while (column + width < terrain.columns &&
          !taken(column + width, row) &&
          terrain.kindAt(column + width, row) == kind) {
        width++;
      }

      var height = 1;
      var extending = true;
      while (extending && row + height < terrain.rows) {
        for (var offset = 0; offset < width; offset++) {
          if (taken(column + offset, row + height) ||
              terrain.kindAt(column + offset, row + height) != kind) {
            extending = false;
            break;
          }
        }
        if (extending) height++;
      }

      for (var y = row; y < row + height; y++) {
        for (var x = column; x < column + width; x++) {
          claim(x, y);
        }
      }
      blocks.add(
        _TerrainBlock(
          kind: kind,
          column: column,
          row: row,
          width: width,
          height: height,
        ),
      );
    }
  }
  return blocks;
}

class _Frame {
  const _Frame({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

/// Writes a drawing as SVG.
///
/// Hand-written rather than reached for from a package: the drawing is already
/// a list of vector primitives, SVG is a vector format, and a dependency for
/// string concatenation would be a poor trade. Deterministic — the same drawing
/// always produces byte-identical output.
class MapSvgRenderer {
  const MapSvgRenderer();

  String render(MapDrawing drawing) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'width="${_number(drawing.width)}" height="${_number(drawing.height)}" '
        'viewBox="0 0 ${_number(drawing.width)} ${_number(drawing.height)}">',
      );
    for (final primitive in drawing.ordered) {
      buffer.writeln('  ${_primitive(primitive)}');
    }
    buffer.writeln('</svg>');
    return buffer.toString();
  }

  String _primitive(MapDrawPrimitive primitive) => switch (primitive) {
        MapDrawRect() => '<rect x="${_number(primitive.left)}" '
            'y="${_number(primitive.top)}" width="${_number(primitive.width)}" '
            'height="${_number(primitive.height)}" '
            '${_paint(primitive.fill, primitive.stroke, primitive.strokeWidth, primitive.opacity)}/>',
        MapDrawCircle() => '<circle cx="${_number(primitive.x)}" '
            'cy="${_number(primitive.y)}" r="${_number(primitive.radius)}" '
            '${_paint(primitive.fill, primitive.stroke, primitive.strokeWidth, 1)}/>',
        MapDrawPolygon() => _polygon(primitive),
        MapDrawText() => '<text x="${_number(primitive.x)}" '
            'y="${_number(primitive.y)}" font-size="${_number(primitive.size)}" '
            'font-family="Helvetica, Arial, sans-serif" '
            'text-anchor="${_anchor(primitive.align)}" '
            '${primitive.bold ? 'font-weight="700" ' : ''}'
            'fill="${_colour(primitive.colour)}" '
            'fill-opacity="${_number(primitive.opacity)}">'
            '${_escape(primitive.text)}</text>',
      };

  String _polygon(MapDrawPolygon polygon) {
    final points = <String>[];
    for (var index = 0; index + 1 < polygon.points.length; index += 2) {
      points.add(
        '${_number(polygon.points[index])},${_number(polygon.points[index + 1])}',
      );
    }
    final dash = polygon.dashed ? ' stroke-dasharray="6 4"' : '';
    final tag = polygon.closed ? 'polygon' : 'polyline';
    return '<$tag points="${points.join(' ')}" '
        '${_paint(polygon.fill, polygon.stroke, polygon.strokeWidth, polygon.opacity)}$dash/>';
  }

  String _paint(int? fill, int? stroke, double strokeWidth, double opacity) {
    final parts = <String>[
      'fill="${fill == null ? 'none' : _colour(fill)}"',
      if (fill != null) 'fill-opacity="${_number(opacity)}"',
      if (stroke != null) ...[
        'stroke="${_colour(stroke)}"',
        'stroke-width="${_number(strokeWidth)}"',
        'stroke-opacity="${_number(opacity)}"',
        'stroke-linejoin="round"',
        'stroke-linecap="round"',
      ],
    ];
    return parts.join(' ');
  }

  static String _anchor(MapTextAlign align) => switch (align) {
        MapTextAlign.start => 'start',
        MapTextAlign.centre => 'middle',
        MapTextAlign.end => 'end',
      };

  static String _colour(int argb) {
    final value = argb & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }

  static String _number(double value) {
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  static String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

/// Writes a drawing as a PDF page.
///
/// Uses `package:pdf`, already in the tree for manuscript export — no new
/// dependency. The page is the size the preset says, in points, and the drawing
/// is painted one-to-one because both are measured in points.
class MapPdfRenderer {
  const MapPdfRenderer();

  Future<Uint8List> render(MapDrawing drawing, {String title = 'Map'}) async {
    final document = pw.Document(title: title);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(drawing.width, drawing.height),
        build: (context) {
          // The fonts are built here, where the document exists, and handed to
          // the painter. Text measured with the same font it is drawn with is
          // the only way an alignment can be trusted.
          final regular = PdfFont.helvetica(context.document);
          final bold = PdfFont.helveticaBold(context.document);
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.CustomPaint(
              size: PdfPoint(drawing.width, drawing.height),
              painter: (canvas, size) => _paint(
                canvas,
                drawing,
                regular: regular,
                bold: bold,
              ),
            ),
          );
        },
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  void _paint(
    PdfGraphics canvas,
    MapDrawing drawing, {
    required PdfFont regular,
    required PdfFont bold,
  }) {
    // PDF's origin is bottom-left and the drawing's is top-left, so the whole
    // page is flipped once here rather than every primitive being converted.
    final height = drawing.height;
    double flip(double y) => height - y;

    // `setFillColor` carries an alpha channel that PDF simply ignores: real
    // transparency is a graphics state. Without this, a translucent region
    // wash prints as a solid block covering the terrain underneath it — which
    // is exactly how the PDF and the SVG came to disagree the first time these
    // were laid side by side.
    var appliedOpacity = 1.0;
    void useOpacity(double opacity) {
      final wanted = opacity.clamp(0.0, 1.0).toDouble();
      if (wanted == appliedOpacity) return;
      canvas.setGraphicState(PdfGraphicState(opacity: wanted));
      appliedOpacity = wanted;
    }

    for (final primitive in drawing.ordered) {
      switch (primitive) {
        case MapDrawRect():
          useOpacity(primitive.opacity);
          canvas
            ..setFillColor(_colour(primitive.fill ?? 0, primitive.opacity))
            ..drawRect(
              primitive.left,
              flip(primitive.top + primitive.height),
              primitive.width,
              primitive.height,
            );
          if (primitive.fill != null) canvas.fillPath();
          if (primitive.stroke != null) {
            canvas
              ..setStrokeColor(_colour(primitive.stroke!, primitive.opacity))
              ..setLineWidth(primitive.strokeWidth)
              ..drawRect(
                primitive.left,
                flip(primitive.top + primitive.height),
                primitive.width,
                primitive.height,
              )
              ..strokePath();
          }
        case MapDrawCircle():
          useOpacity(1);
          if (primitive.fill != null) {
            canvas
              ..setFillColor(_colour(primitive.fill!, 1))
              ..drawEllipse(
                primitive.x,
                flip(primitive.y),
                primitive.radius,
                primitive.radius,
              )
              ..fillPath();
          }
          if (primitive.stroke != null) {
            canvas
              ..setStrokeColor(_colour(primitive.stroke!, 1))
              ..setLineWidth(primitive.strokeWidth)
              ..drawEllipse(
                primitive.x,
                flip(primitive.y),
                primitive.radius,
                primitive.radius,
              )
              ..strokePath();
          }
        case MapDrawPolygon():
          if (primitive.points.length < 4) continue;
          useOpacity(primitive.opacity);
          void trace() {
            canvas.moveTo(primitive.points[0], flip(primitive.points[1]));
            for (var index = 2; index + 1 < primitive.points.length; index += 2) {
              canvas.lineTo(
                primitive.points[index],
                flip(primitive.points[index + 1]),
              );
            }
            if (primitive.closed) canvas.closePath();
          }

          if (primitive.fill != null) {
            canvas.setFillColor(_colour(primitive.fill!, primitive.opacity));
            trace();
            canvas.fillPath();
          }
          if (primitive.stroke != null) {
            canvas
              ..setStrokeColor(_colour(primitive.stroke!, primitive.opacity))
              ..setLineWidth(primitive.strokeWidth)
              ..setLineJoin(PdfLineJoin.round)
              ..setLineCap(PdfLineCap.round);
            trace();
            canvas.strokePath();
          }
        case MapDrawText():
          useOpacity(primitive.opacity);
          final font = primitive.bold ? bold : regular;
          final width =
              font.stringMetrics(primitive.text).width * primitive.size;
          final x = switch (primitive.align) {
            MapTextAlign.start => primitive.x,
            MapTextAlign.centre => primitive.x - width / 2,
            MapTextAlign.end => primitive.x - width,
          };
          canvas
            ..setFillColor(_colour(primitive.colour, primitive.opacity))
            ..drawString(font, primitive.size, primitive.text, x,
                flip(primitive.y));
      }
    }
  }

  /// Opacity is applied through the graphics state, not here: a PdfColor's
  /// alpha is ignored by `setFillColor`, so carrying it would only look right.
  static PdfColor _colour(int argb, double opacity) => PdfColor(
        ((argb >> 16) & 0xFF) / 255,
        ((argb >> 8) & 0xFF) / 255,
        (argb & 0xFF) / 255,
      );
}

/// Writes the projections as JSON.
///
/// A data export, not a second model: every value is read straight off the
/// canonical projections, and the shape mirrors them rather than inventing a
/// schema of its own.
class MapJsonExporter {
  const MapJsonExporter();

  String render(MapExportRequest request) {
    final map = request.canvas.map;
    final world = request.world;
    final overlays = request.overlays;
    final payload = <String, Object?>{
      'map': {
        'id': map.id,
        'title': map.title,
        'revision': map.record.revision,
        'extent': {
          'width': MapExtent.fromRecord(map.record).width,
          'height': MapExtent.fromRecord(map.record).height,
        },
      },
      'metadata': {
        'project': request.presentation.metadata.projectTitle,
        if (request.presentation.metadata.bookTitle.isNotEmpty)
          'book': request.presentation.metadata.bookTitle,
        if (request.presentation.metadata.seriesTitle.isNotEmpty)
          'series': request.presentation.metadata.seriesTitle,
        if (request.presentation.metadata.authorName.isNotEmpty)
          'author': request.presentation.metadata.authorName,
        if (request.presentation.metadata.eraLabel.isNotEmpty)
          'era': request.presentation.metadata.eraLabel,
        'version': request.presentation.metadata.versionLabel,
      },
      'places': [
        for (final location in request.canvas.locations)
          {
            'id': location.record.id,
            'name': location.name,
            'type': location.locationType,
            'x': location.position.x,
            'y': location.position.y,
          },
      ],
      'regions': [
        for (final region in request.canvas.regions)
          {
            'id': region.record.id,
            'name': region.name,
            'points': [
              for (final point in region.geometry.points)
                {'x': point.x, 'y': point.y},
            ],
          },
      ],
      if (world != null) ...{
        'territories': [
          for (final territory in world.territories)
            {
              'id': territory.id,
              'name': territory.name,
              'kind': territory.kind.label,
              if (territory.holderName.isNotEmpty) 'heldBy': territory.holderName,
            },
        ],
        'routes': [
          for (final route in world.routes)
            {
              'id': route.id,
              'name': route.name,
              'kind': route.kind.label,
              'from': route.fromId,
              'to': route.toId,
              if (route.distance != null) 'distance': route.distance,
            },
        ],
      },
      if (overlays != null)
        'story': [
          for (final item in overlays.items)
            {
              'id': item.sourceId,
              'kind': item.kind.label,
              'label': item.label,
              if (item.locationId.isNotEmpty) 'at': item.locationId,
              if (item.moment != null) 'when': item.moment!.label,
            },
        ],
      if (request.presentation.gaps.isNotEmpty)
        'omitted': [
          for (final gap in request.presentation.gaps) gap.message,
        ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}
