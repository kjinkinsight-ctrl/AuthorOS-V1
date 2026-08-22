/// Map Studio Phase 6 — the presentation model.
///
/// Phases 1–3 built the map, Phase 4 put the story on it and Phase 5 made the
/// world behave. Phase 6 turns all of that into something an author can show
/// somebody: a titled, themed, decorated map, exported as a file.
///
/// It is a **projection and nothing else**. Every value here is derived from
/// [MapCanvasData], [MapOverlayData], [MapWorldState] and the canonical record
/// and profile layers; none of it is stored, and none of it is a second
/// description of the world. Presentation changes how the map is drawn, never
/// what the map is.
///
/// Where the canonical model does not carry something a presentation would
/// like — a real-world scale, a series title — this file records the gap in
/// [MapPresentationGap] and the renderers omit the element. Nothing is invented
/// to fill a hole, because a map that states a scale nobody wrote is worse than
/// a map with no scale bar.
library;

import 'map_terrain.dart';

/// A named look for a finished map.
///
/// A theme is a **transform of the Theme Engine's own tokens**, expressed as
/// plain numbers so this file stays free of Flutter and free of colour. The
/// view resolves the numbers through `StudioThemeScope` exactly as Phase 3
/// does; nothing here knows what colour anything is.
enum MapPresentationTheme {
  /// The working map: the Studio's own styling, unchanged.
  studio,

  /// Warm, low-contrast, illustrated — parchment without a parchment image.
  classicFantasy,

  /// Restrained highlights on dark ground.
  darkFantasy,

  /// Old-world cartography: muted, high-contrast line work.
  historical,

  /// Clean contemporary geography.
  modern,

  /// A planning map: as little as possible.
  minimal,
}

extension MapPresentationThemeDetail on MapPresentationTheme {
  String get label => switch (this) {
        MapPresentationTheme.studio => 'Studio',
        MapPresentationTheme.classicFantasy => 'Classic fantasy',
        MapPresentationTheme.darkFantasy => 'Dark fantasy',
        MapPresentationTheme.historical => 'Historical',
        MapPresentationTheme.modern => 'Modern',
        MapPresentationTheme.minimal => 'Minimal',
      };

  String get description => switch (this) {
        MapPresentationTheme.studio => 'The map as you work on it.',
        MapPresentationTheme.classicFantasy =>
          'Warm and softly lit, for a map at the front of a novel.',
        MapPresentationTheme.darkFantasy =>
          'Dark ground, restrained highlights.',
        MapPresentationTheme.historical =>
          'Muted colour and strong line work, like an old survey.',
        MapPresentationTheme.modern => 'Clean, even, geographic.',
        MapPresentationTheme.minimal => 'Line and label only.',
      };

  /// The Phase 3 visual style this theme produces from the map's own style.
  ///
  /// Deliberately a transform of [base] rather than a replacement: the author's
  /// stored styling is the starting point, and a theme adjusts it. The map
  /// record is never written — the result lives as long as the export does.
  MapVisualStyle styleFor(MapVisualStyle base) => switch (this) {
        MapPresentationTheme.studio => base,
        MapPresentationTheme.classicFantasy => MapVisualStyle(
            treatment: MapBackgroundTreatment.parchment,
            saturation: (base.saturation * 0.85).clamp(0.0, 2.0).toDouble(),
            contrast: (base.contrast * 0.9).clamp(0.1, 2.0).toDouble(),
            terrainOpacity: (base.terrainOpacity * 0.95).clamp(0.0, 1.0),
            showLegend: base.showLegend,
          ),
        MapPresentationTheme.darkFantasy => MapVisualStyle(
            treatment: MapBackgroundTreatment.plain,
            saturation: (base.saturation * 0.6).clamp(0.0, 2.0).toDouble(),
            contrast: (base.contrast * 1.35).clamp(0.1, 2.0).toDouble(),
            terrainOpacity: (base.terrainOpacity * 0.85).clamp(0.0, 1.0),
            showLegend: base.showLegend,
          ),
        MapPresentationTheme.historical => MapVisualStyle(
            treatment: MapBackgroundTreatment.parchment,
            saturation: (base.saturation * 0.45).clamp(0.0, 2.0).toDouble(),
            contrast: (base.contrast * 1.2).clamp(0.1, 2.0).toDouble(),
            terrainOpacity: (base.terrainOpacity * 0.8).clamp(0.0, 1.0),
            showLegend: base.showLegend,
          ),
        MapPresentationTheme.modern => MapVisualStyle(
            treatment: MapBackgroundTreatment.plain,
            saturation: base.saturation,
            contrast: base.contrast,
            terrainOpacity: base.terrainOpacity,
            showLegend: base.showLegend,
          ),
        MapPresentationTheme.minimal => MapVisualStyle(
            treatment: MapBackgroundTreatment.plain,
            saturation: (base.saturation * 0.2).clamp(0.0, 2.0).toDouble(),
            contrast: (base.contrast * 1.1).clamp(0.1, 2.0).toDouble(),
            terrainOpacity: (base.terrainOpacity * 0.35).clamp(0.0, 1.0),
            showLegend: false,
          ),
      };

  /// What this theme turns on when it is chosen.
  ///
  /// A starting point the author can change, not a rule: every decoration is
  /// independently switchable afterwards.
  Set<MapDecoration> get decorations => switch (this) {
        MapPresentationTheme.studio => const {
            MapDecoration.legend,
            MapDecoration.scaleBar,
          },
        MapPresentationTheme.classicFantasy => const {
            MapDecoration.titleBlock,
            MapDecoration.compass,
            MapDecoration.frame,
            MapDecoration.legend,
            MapDecoration.scaleBar,
          },
        MapPresentationTheme.darkFantasy => const {
            MapDecoration.titleBlock,
            MapDecoration.compass,
            MapDecoration.legend,
          },
        MapPresentationTheme.historical => const {
            MapDecoration.titleBlock,
            MapDecoration.compass,
            MapDecoration.frame,
            MapDecoration.grid,
            MapDecoration.scaleBar,
            MapDecoration.legend,
          },
        MapPresentationTheme.modern => const {
            MapDecoration.titleBlock,
            MapDecoration.scaleBar,
            MapDecoration.legend,
          },
        MapPresentationTheme.minimal => const {MapDecoration.titleBlock},
      };
}

/// Something drawn around the map rather than on it.
enum MapDecoration {
  titleBlock,
  compass,
  scaleBar,
  legend,
  frame,
  grid,
  watermark,
  elevationKey,
}

extension MapDecorationLabel on MapDecoration {
  String get label => switch (this) {
        MapDecoration.titleBlock => 'Title block',
        MapDecoration.compass => 'Compass',
        MapDecoration.scaleBar => 'Scale bar',
        MapDecoration.legend => 'Legend',
        MapDecoration.frame => 'Frame',
        MapDecoration.grid => 'Coordinate grid',
        MapDecoration.watermark => 'Watermark',
        MapDecoration.elevationKey => 'Elevation key',
      };
}

/// Which decorations are on. Independently switchable, as §22 requires.
class MapDecorations {
  const MapDecorations(this.enabled);

  const MapDecorations.none() : enabled = const {};

  final Set<MapDecoration> enabled;

  bool has(MapDecoration decoration) => enabled.contains(decoration);

  MapDecorations toggling(MapDecoration decoration) {
    final next = {...enabled};
    if (!next.remove(decoration)) next.add(decoration);
    return MapDecorations(next);
  }

  MapDecorations withOnly(Set<MapDecoration> decorations) =>
      MapDecorations({...decorations});
}

/// How prominent a label is, and therefore when it appears.
///
/// A map that draws every label at every zoom is unreadable, and one that
/// drops labels arbitrarily is untrustworthy. Tier is derived from what the
/// canonical record already says a place is — a capital outranks a village
/// because [MapSettlementKind] says so, not because presentation decided it.
enum MapLabelTier { primary, secondary, tertiary, minor }

extension MapLabelTierDetail on MapLabelTier {
  /// The smallest camera scale at which this tier is drawn.
  double get minimumScale => switch (this) {
        MapLabelTier.primary => 0,
        MapLabelTier.secondary => 0.75,
        MapLabelTier.tertiary => 1.5,
        MapLabelTier.minor => 3,
      };

  /// Relative type size, multiplied by the renderer's base size.
  double get sizeFactor => switch (this) {
        MapLabelTier.primary => 1.35,
        MapLabelTier.secondary => 1.1,
        MapLabelTier.tertiary => 0.95,
        MapLabelTier.minor => 0.85,
      };

  static MapLabelTier forRank(int rank) => switch (rank) {
        >= 6 => MapLabelTier.primary,
        5 => MapLabelTier.secondary,
        4 || 3 => MapLabelTier.tertiary,
        _ => MapLabelTier.minor,
      };
}

/// How much labelling a surface wants.
///
/// The live canvas hides small labels until the author zooms in, because the
/// screen is one window onto a large map. An export has no zoom: the whole map
/// is on the page at once, so a printed map that dropped its villages would
/// simply be missing them with no way to reveal them. Detail is therefore a
/// property of the surface, not a fixed rule.
enum MapLabelDetail { essential, standard, full }

extension MapLabelDetailScale on MapLabelDetail {
  /// The scale the planner is asked to consider. Anything at or below this
  /// tier threshold is eligible; collision avoidance decides the rest.
  double get scale => switch (this) {
        MapLabelDetail.essential => 0.5,
        MapLabelDetail.standard => 1.5,
        MapLabelDetail.full => 1000,
      };

  String get label => switch (this) {
        MapLabelDetail.essential => 'Major places only',
        MapLabelDetail.standard => 'Standard',
        MapLabelDetail.full => 'Every place that fits',
      };
}

/// One label the renderer should draw, already placed.
class MapLabel {
  const MapLabel({
    required this.id,
    required this.text,
    required this.tier,
    required this.x,
    required this.y,
    this.subtitle = '',
  });

  final String id;
  final String text;
  final String subtitle;
  final MapLabelTier tier;

  /// Canvas position, in the renderer's own pixel space.
  final double x;
  final double y;
}

/// Places labels without letting them collide.
///
/// Deliberately simple and deliberately deterministic: labels are considered in
/// tier order and then by id, and one that would overlap a label already placed
/// is dropped rather than nudged. An author can zoom in to see it. The
/// alternative — shifting labels away from what they name — moves a place on a
/// map, which is exactly the lie this Studio has refused since Phase 1.
class MapLabelPlanner {
  const MapLabelPlanner({
    this.lineHeight = 14,
    this.characterWidth = 6.2,
    this.padding = 3,
  });

  final double lineHeight;
  final double characterWidth;
  final double padding;

  /// [obstacles] are boxes already occupied by something that is not a label —
  /// an overlay badge, a compass, a title block. A label never overprints one,
  /// because a name obscured by a marker is worse than a name not drawn.
  List<MapLabel> plan(
    List<MapLabel> candidates, {
    required double scale,
    required double canvasWidth,
    required double canvasHeight,
    List<(double left, double top, double right, double bottom)> obstacles =
        const [],
  }) {
    final ordered = [...candidates]..sort((a, b) {
        final byTier = a.tier.index.compareTo(b.tier.index);
        return byTier != 0 ? byTier : a.id.compareTo(b.id);
      });
    final placed = <MapLabel>[];
    final boxes = <_LabelBox>[
      for (final obstacle in obstacles)
        _LabelBox(
          left: obstacle.$1,
          top: obstacle.$2,
          right: obstacle.$3,
          bottom: obstacle.$4,
        ),
    ];
    for (final label in ordered) {
      if (scale < label.tier.minimumScale) continue;
      final box = _boxFor(label);
      if (box.right < 0 ||
          box.bottom < 0 ||
          box.left > canvasWidth ||
          box.top > canvasHeight) {
        continue;
      }
      if (boxes.any((other) => other.overlaps(box))) continue;
      boxes.add(box);
      placed.add(label);
    }
    return placed;
  }

  _LabelBox _boxFor(MapLabel label) {
    final width = label.text.length * characterWidth * label.tier.sizeFactor;
    final height = lineHeight * label.tier.sizeFactor;
    return _LabelBox(
      left: label.x - width / 2 - padding,
      top: label.y - height / 2 - padding,
      right: label.x + width / 2 + padding,
      bottom: label.y + height / 2 + padding,
    );
  }
}

class _LabelBox {
  const _LabelBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  bool overlaps(_LabelBox other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;
}

/// Something a presentation wanted and the canonical model does not carry.
///
/// Reported rather than filled in. Each one names the source that would have to
/// exist, so the gap is actionable instead of merely absent.
class MapPresentationGap {
  const MapPresentationGap({
    required this.element,
    required this.missingSource,
  });

  /// The presentation element that could not be drawn in full.
  final String element;

  /// What the canonical model would have to provide.
  final String missingSource;

  String get message => '$element omitted: $missingSource';
}

/// The metadata an export may carry (§35), read from canonical sources only.
///
/// Every field here comes from somewhere that already owns it: the project from
/// [StarterProject], the author from the profile store, the book from the
/// manuscript node tree, the version from the map record's own revision. There
/// is no export metadata store, and there is no second version system.
class MapPresentationMetadata {
  const MapPresentationMetadata({
    required this.projectTitle,
    required this.mapTitle,
    this.seriesTitle = '',
    this.bookTitle = '',
    this.authorName = '',
    this.eraLabel = '',
    this.revision = 1,
    this.createdAt,
    this.gaps = const [],
  });

  final String projectTitle;
  final String mapTitle;
  final String seriesTitle;
  final String bookTitle;
  final String authorName;

  /// The point in the story this map was read at, if any.
  final String eraLabel;

  /// The map record's own revision — the existing version infrastructure.
  final int revision;

  final DateTime? createdAt;

  /// What could not be filled in, and why.
  final List<MapPresentationGap> gaps;

  String get versionLabel => 'Version 1.$revision';

  /// The lines a title block or export footer prints, in order, skipping
  /// anything the canonical model did not provide.
  List<String> get lines => [
        mapTitle,
        if (seriesTitle.isNotEmpty) seriesTitle,
        if (bookTitle.isNotEmpty) bookTitle,
        if (eraLabel.isNotEmpty) eraLabel,
        if (authorName.isNotEmpty) authorName,
      ];
}

/// A scale bar the map can honestly draw.
///
/// AuthorOS has no canonical statement of how many map units make a mile — the
/// map record declares a `coordinateSystem` but no ratio — so the bar is drawn
/// in map units, labelled with the coordinate system's own name where the
/// author gave one. Converting to real-world distance would require inventing
/// the ratio, which §16's rule forbids just as firmly for presentation as for
/// simulation.
class MapScaleBar {
  const MapScaleBar({
    required this.mapUnits,
    required this.unitLabel,
    this.gap,
  });

  final double mapUnits;
  final String unitLabel;

  /// Set when the bar could not state a real-world distance.
  final MapPresentationGap? gap;

  String get text => '${_trim(mapUnits)} $unitLabel';

  /// A round number of map units that fits comfortably in [availableUnits].
  static MapScaleBar forExtent(
    double availableUnits, {
    String coordinateSystem = '',
  }) {
    const steps = [1.0, 2.0, 5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];
    final target = availableUnits / 4;
    var chosen = steps.first;
    for (final step in steps) {
      if (step <= target) chosen = step;
    }
    final named = coordinateSystem.trim();
    return MapScaleBar(
      mapUnits: chosen,
      unitLabel: named.isEmpty ? 'map units' : named,
      gap: named.isEmpty
          ? const MapPresentationGap(
              element: 'Real-world scale',
              missingSource:
                  'no canonical map scale exists — the map record declares a '
                  'coordinate system but no units-per-distance ratio',
            )
          : null,
    );
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

/// Everything a renderer needs to draw a finished map, and nothing else.
///
/// A presentation is assembled from the canonical projections and thrown away.
/// It holds no world data of its own: what to draw still comes from
/// `MapCanvasData`, `MapOverlayData` and `MapWorldState`, which stay
/// authoritative.
class MapPresentation {
  const MapPresentation({
    required this.metadata,
    this.theme = MapPresentationTheme.studio,
    this.decorations = const MapDecorations({
      MapDecoration.legend,
      MapDecoration.scaleBar,
    }),
    this.subtitle = '',
    this.credit = '',
    this.watermark = '',
    this.scaleBar,
  });

  final MapPresentationMetadata metadata;
  final MapPresentationTheme theme;
  final MapDecorations decorations;
  final String subtitle;
  final String credit;
  final String watermark;
  final MapScaleBar? scaleBar;

  String get title => metadata.mapTitle;

  bool shows(MapDecoration decoration) => decorations.has(decoration);

  /// Every gap this presentation had to work around.
  List<MapPresentationGap> get gaps => [
        ...metadata.gaps,
        if (scaleBar?.gap != null && shows(MapDecoration.scaleBar))
          scaleBar!.gap!,
      ];

  MapPresentation copyWith({
    MapPresentationTheme? theme,
    MapDecorations? decorations,
    String? subtitle,
    String? credit,
    String? watermark,
    MapScaleBar? scaleBar,
  }) =>
      MapPresentation(
        metadata: metadata,
        theme: theme ?? this.theme,
        decorations: decorations ?? this.decorations,
        subtitle: subtitle ?? this.subtitle,
        credit: credit ?? this.credit,
        watermark: watermark ?? this.watermark,
        scaleBar: scaleBar ?? this.scaleBar,
      );

  /// Switching theme adopts that theme's decorations, which the author may then
  /// change. Everything else about the presentation is left alone.
  MapPresentation withTheme(MapPresentationTheme next) => copyWith(
        theme: next,
        decorations: MapDecorations({...next.decorations}),
      );
}
