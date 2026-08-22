/// Map Studio Phase 3 — terrain, biomes, assets and visual styling.
///
/// Plain Dart on purpose, exactly like `map_domain.dart`: this vocabulary must
/// be resolvable in tests without a Flutter binding, and nothing here may know
/// what a pixel is.
///
/// Three rules hold this file together, and each is pinned by a test:
///
/// 1. **Everything is map space.** Terrain is a grid indexed by column and row
///    over the map's declared extent; assets carry a [MapPosition]. Screen
///    coordinates never appear, here or in a record.
/// 2. **Terrain and assets are presentation data, not story entities.** They
///    live in fields on the map record. They are never `AuthorRecord`s and
///    never endpoints of a `RecordLink`, so a map with two thousand trees adds
///    two thousand pieces of scenery and zero nodes to the story graph.
/// 3. **Colour is derived, never declared.** A terrain kind carries a hue
///    rotation and saturation/lightness factors relative to a Theme Engine
///    token. The engine stays the single source of colour; this file contains
///    no colour at all.
library;

import 'map_domain.dart';

/// The record fields Phase 3 owns, under the same reserved namespace Phase 1
/// established.
class MapVisualFields {
  const MapVisualFields._();

  /// The painted terrain grid, stored as `{columns, rows, runs}`.
  static const terrain = '${MapFields.prefix}terrain';

  /// The biome definitions this map recognises.
  static const biomes = '${MapFields.prefix}biomes';

  /// Placed visual assets, stored as a list of instances.
  static const assets = '${MapFields.prefix}assets';

  /// The map's visual styling: palette and background treatment.
  static const style = '${MapFields.prefix}style';
}

// ---------------------------------------------------------------- terrain ---

/// A kind of ground.
///
/// The set is deliberately closed: an open vocabulary would need its own
/// registry, and a registry of visual kinds is the beginning of a second map
/// system. A world that needs a shade of ground this list lacks is asking for
/// a biome, which [MapBiome] provides on top of these.
enum MapTerrainKind {
  water,
  shallows,
  marsh,
  grass,
  farmland,
  forest,
  hills,
  mountain,
  rock,
  sand,
  snow,
}

extension MapTerrainKindTraits on MapTerrainKind {
  String get label => switch (this) {
        MapTerrainKind.water => 'Deep water',
        MapTerrainKind.shallows => 'Shallows',
        MapTerrainKind.marsh => 'Marsh',
        MapTerrainKind.grass => 'Grassland',
        MapTerrainKind.farmland => 'Farmland',
        MapTerrainKind.forest => 'Forest',
        MapTerrainKind.hills => 'Hills',
        MapTerrainKind.mountain => 'Mountain',
        MapTerrainKind.rock => 'Bare rock',
        MapTerrainKind.sand => 'Sand',
        MapTerrainKind.snow => 'Snow',
      };

  /// Relative elevation, `0.0` (sea floor) to `1.0` (peak).
  ///
  /// This is how Phase 3 represents height. A separate height field per cell
  /// would double the size of every stored map to describe something terrain
  /// kind already implies, and nothing in Phase 3 varies height within a kind.
  double get elevation => switch (this) {
        MapTerrainKind.water => 0.0,
        MapTerrainKind.shallows => 0.1,
        MapTerrainKind.marsh => 0.15,
        MapTerrainKind.sand => 0.2,
        MapTerrainKind.grass => 0.3,
        MapTerrainKind.farmland => 0.32,
        MapTerrainKind.forest => 0.4,
        MapTerrainKind.hills => 0.6,
        MapTerrainKind.rock => 0.75,
        MapTerrainKind.mountain => 0.9,
        MapTerrainKind.snow => 1.0,
      };

  bool get isWater =>
      this == MapTerrainKind.water || this == MapTerrainKind.shallows;

  /// Hue rotation in degrees from the theme's base colour.
  ///
  /// Terrain has to be told apart at a glance, and the Theme Engine publishes
  /// no "forest green". Rather than hard-coding colour — which the Studio's
  /// architecture forbids and a test enforces — each kind rotates the engine's
  /// own colour. The map restyles itself with the theme, and no literal colour
  /// is stored or written anywhere.
  double get hueShift => switch (this) {
        MapTerrainKind.water => 210,
        MapTerrainKind.shallows => 190,
        MapTerrainKind.marsh => 150,
        MapTerrainKind.grass => 110,
        MapTerrainKind.farmland => 80,
        MapTerrainKind.forest => 135,
        MapTerrainKind.hills => 70,
        MapTerrainKind.mountain => 30,
        MapTerrainKind.rock => 20,
        MapTerrainKind.sand => 50,
        MapTerrainKind.snow => 200,
      };

  /// Saturation multiplier applied after [hueShift].
  double get saturationFactor => switch (this) {
        MapTerrainKind.snow => 0.12,
        MapTerrainKind.rock => 0.25,
        MapTerrainKind.mountain => 0.35,
        MapTerrainKind.sand => 0.55,
        MapTerrainKind.farmland => 0.6,
        MapTerrainKind.marsh => 0.45,
        _ => 0.7,
      };

  /// Lightness multiplier applied after [hueShift]. Higher ground reads
  /// lighter, which is what gives a painted map its sense of relief.
  double get lightnessFactor => switch (this) {
        MapTerrainKind.water => 0.75,
        MapTerrainKind.shallows => 0.95,
        MapTerrainKind.marsh => 0.8,
        MapTerrainKind.grass => 1.0,
        MapTerrainKind.farmland => 1.05,
        MapTerrainKind.forest => 0.8,
        MapTerrainKind.hills => 1.1,
        MapTerrainKind.mountain => 1.15,
        MapTerrainKind.rock => 1.2,
        MapTerrainKind.sand => 1.3,
        MapTerrainKind.snow => 1.45,
      };
}

/// The painted ground of one map.
///
/// A grid over the map's extent: cell `(column, row)` covers the map-space
/// rectangle running from `column / columns * extent.width` to the next column
/// boundary, and likewise for rows. That is what makes it resolution
/// independent — the same stored grid paints correctly on any canvas size and
/// survives a change of canvas entirely.
///
/// `-1` means unpainted, and unpainted is not the same as water: a new map has
/// no terrain at all, and the canvas shows its ground rather than an ocean.
class MapTerrainGrid {
  const MapTerrainGrid({
    required this.columns,
    required this.rows,
    required this.cells,
  });

  /// The default painting resolution.
  ///
  /// 48 x 48 is 2,304 cells: fine enough for coastlines a reader would accept,
  /// small enough that the run-length encoding of a typical map stays a few
  /// hundred bytes in one record field.
  static const int defaultResolution = 48;

  static const int unpainted = -1;

  final int columns;
  final int rows;

  /// Row-major, `columns * rows` entries, each a [MapTerrainKind] index or
  /// [unpainted].
  final List<int> cells;

  factory MapTerrainGrid.empty({
    int columns = defaultResolution,
    int rows = defaultResolution,
  }) =>
      MapTerrainGrid(
        columns: columns,
        rows: rows,
        cells: List<int>.filled(columns * rows, unpainted),
      );

  static const empty0 = MapTerrainGrid(columns: 0, rows: 0, cells: []);

  bool get isEmpty =>
      columns == 0 || rows == 0 || cells.every((cell) => cell == unpainted);

  int get cellCount => columns * rows;

  bool contains(int column, int row) =>
      column >= 0 && row >= 0 && column < columns && row < rows;

  int indexOf(int column, int row) => row * columns + column;

  MapTerrainKind? kindAt(int column, int row) {
    if (!contains(column, row)) return null;
    final value = cells[indexOf(column, row)];
    if (value < 0 || value >= MapTerrainKind.values.length) return null;
    return MapTerrainKind.values[value];
  }

  /// The grid cell a map-space position falls in.
  ///
  /// Positions on the far edge clamp into the last cell rather than falling out
  /// of the grid, so painting at the map boundary works.
  (int column, int row)? cellFor(MapPosition position, MapExtent extent) {
    if (columns == 0 || rows == 0 || !extent.isValid) return null;
    final column =
        (position.x / extent.width * columns).floor().clamp(0, columns - 1);
    final row = (position.y / extent.height * rows).floor().clamp(0, rows - 1);
    return (column, row);
  }

  /// The map-space rectangle a cell covers.
  MapRect rectFor(int column, int row, MapExtent extent) {
    final cellWidth = extent.width / columns;
    final cellHeight = extent.height / rows;
    return MapRect(
      left: column * cellWidth,
      top: row * cellHeight,
      right: (column + 1) * cellWidth,
      bottom: (row + 1) * cellHeight,
    );
  }

  /// The map-space centre of a cell.
  MapPosition centreOf(int column, int row, MapExtent extent) =>
      rectFor(column, row, extent).centre;

  MapTerrainGrid withCell(int column, int row, MapTerrainKind? kind) {
    if (!contains(column, row)) return this;
    final next = [...cells];
    next[indexOf(column, row)] = kind?.index ?? unpainted;
    return MapTerrainGrid(columns: columns, rows: rows, cells: next);
  }

  /// Applies [brush] centred on a map-space position.
  ///
  /// The brush radius is in **map units**, not pixels, so the same stroke
  /// covers the same ground whatever the zoom was when it was painted.
  MapTerrainGrid painted(
    MapTerrainBrush brush,
    MapPosition centre,
    MapExtent extent,
  ) {
    if (columns == 0 || rows == 0 || !extent.isValid) return this;
    final next = [...cells];
    final radius = brush.radius <= 0 ? 0.0 : brush.radius;
    final value = brush.erases ? unpainted : brush.kind.index;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final point = centreOf(column, row, extent);
        final dx = point.x - centre.x;
        final dy = point.y - centre.y;
        if (dx * dx + dy * dy <= radius * radius) {
          next[indexOf(column, row)] = value;
        }
      }
    }
    return MapTerrainGrid(columns: columns, rows: rows, cells: next);
  }

  /// Fills every cell, the fastest way to give a map a sea or a plain to carve.
  MapTerrainGrid filled(MapTerrainKind kind) => MapTerrainGrid(
        columns: columns,
        rows: rows,
        cells: List<int>.filled(cellCount, kind.index),
      );

  /// How much of the map each painted kind covers, as a fraction of the whole.
  Map<MapTerrainKind, double> get coverage {
    if (cellCount == 0) return const {};
    final counts = <MapTerrainKind, int>{};
    for (final value in cells) {
      if (value < 0 || value >= MapTerrainKind.values.length) continue;
      final kind = MapTerrainKind.values[value];
      counts[kind] = (counts[kind] ?? 0) + 1;
    }
    return {
      for (final entry in counts.entries) entry.key: entry.value / cellCount,
    };
  }

  /// The kinds actually painted, in enum order — the map's legend.
  List<MapTerrainKind> get paintedKinds => [
        for (final kind in MapTerrainKind.values)
          if (cells.contains(kind.index)) kind,
      ];

  /// Run-length encoded so a full 48x48 map is a short string rather than
  /// 2,304 JSON numbers. Format: `value:count` pairs separated by `,`.
  String encodeRuns() {
    if (cells.isEmpty) return '';
    final buffer = StringBuffer();
    var current = cells.first;
    var run = 1;
    for (var i = 1; i < cells.length; i++) {
      if (cells[i] == current) {
        run++;
        continue;
      }
      buffer.write('$current:$run,');
      current = cells[i];
      run = 1;
    }
    buffer.write('$current:$run');
    return buffer.toString();
  }

  static List<int> decodeRuns(String encoded, int expected) {
    final cells = <int>[];
    if (encoded.isNotEmpty) {
      for (final run in encoded.split(',')) {
        final parts = run.split(':');
        if (parts.length != 2) continue;
        final value = int.tryParse(parts[0]);
        final count = int.tryParse(parts[1]);
        if (value == null || count == null || count <= 0) continue;
        for (var i = 0; i < count; i++) {
          cells.add(value);
        }
      }
    }
    if (cells.length > expected) return cells.sublist(0, expected);
    while (cells.length < expected) {
      cells.add(unpainted);
    }
    return cells;
  }

  Map<String, Object?> toJson() => {
        'columns': columns,
        'rows': rows,
        'runs': encodeRuns(),
      };

  factory MapTerrainGrid.fromJson(Map<String, Object?> json) {
    final columns = _asInt(json['columns']) ?? 0;
    final rows = _asInt(json['rows']) ?? 0;
    final runs = json['runs'];
    return MapTerrainGrid(
      columns: columns,
      rows: rows,
      cells: MapTerrainGrid.decodeRuns(
        runs is String ? runs : '',
        columns * rows,
      ),
    );
  }

  static MapTerrainGrid read(Map<String, Object?> fields) {
    final raw = fields[MapVisualFields.terrain];
    if (raw is Map) {
      return MapTerrainGrid.fromJson(Map<String, Object?>.from(raw));
    }
    return MapTerrainGrid.empty0;
  }

  @override
  bool operator ==(Object other) =>
      other is MapTerrainGrid &&
      other.columns == columns &&
      other.rows == rows &&
      _sameCells(other.cells, cells);

  @override
  int get hashCode => Object.hash(columns, rows, encodeRuns());

  static bool _sameCells(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One terrain stroke.
class MapTerrainBrush {
  const MapTerrainBrush({
    required this.kind,
    this.radius = defaultRadius,
    this.erases = false,
  });

  /// Brush radius in **map units**.
  static const double defaultRadius = 40;
  static const double minRadius = 5;
  static const double maxRadius = 300;

  final MapTerrainKind kind;
  final double radius;

  /// An erasing brush returns ground to unpainted rather than painting a kind.
  final bool erases;

  MapTerrainBrush withRadius(double value) => MapTerrainBrush(
        kind: kind,
        radius: value.clamp(minRadius, maxRadius).toDouble(),
        erases: erases,
      );

  MapTerrainBrush withKind(MapTerrainKind value) =>
      MapTerrainBrush(kind: value, radius: radius, erases: erases);

  MapTerrainBrush withErases(bool value) =>
      MapTerrainBrush(kind: kind, radius: radius, erases: value);
}

// ------------------------------------------------------------------ biome ---

/// A named combination of terrain kinds.
///
/// A biome is an editorial grouping on top of terrain, not a second kind of
/// ground: it names a palette a writer paints with, and it records what the
/// region of a world is meant to feel like. It owns no cells of its own.
class MapBiome {
  const MapBiome({
    required this.id,
    required this.name,
    required this.kinds,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;
  final List<MapTerrainKind> kinds;

  MapTerrainKind get dominant => kinds.isEmpty ? MapTerrainKind.grass : kinds.first;

  /// The biomes every map starts knowing. A writer may add their own.
  static const List<MapBiome> builtIn = [
    MapBiome(
      id: 'temperate',
      name: 'Temperate',
      description: 'Grass, woodland and worked fields.',
      kinds: [
        MapTerrainKind.grass,
        MapTerrainKind.forest,
        MapTerrainKind.farmland,
        MapTerrainKind.hills,
      ],
    ),
    MapBiome(
      id: 'highland',
      name: 'Highland',
      description: 'Hills rising into bare rock and peaks.',
      kinds: [
        MapTerrainKind.hills,
        MapTerrainKind.mountain,
        MapTerrainKind.rock,
        MapTerrainKind.snow,
      ],
    ),
    MapBiome(
      id: 'arid',
      name: 'Arid',
      description: 'Sand and stone, little water.',
      kinds: [
        MapTerrainKind.sand,
        MapTerrainKind.rock,
        MapTerrainKind.hills,
      ],
    ),
    MapBiome(
      id: 'coastal',
      name: 'Coastal',
      description: 'Where the land meets the sea.',
      kinds: [
        MapTerrainKind.water,
        MapTerrainKind.shallows,
        MapTerrainKind.sand,
        MapTerrainKind.grass,
      ],
    ),
    MapBiome(
      id: 'wetland',
      name: 'Wetland',
      description: 'Marsh, shallow water and reed.',
      kinds: [
        MapTerrainKind.marsh,
        MapTerrainKind.shallows,
        MapTerrainKind.grass,
      ],
    ),
    MapBiome(
      id: 'arctic',
      name: 'Arctic',
      description: 'Snow and ice over rock.',
      kinds: [
        MapTerrainKind.snow,
        MapTerrainKind.rock,
        MapTerrainKind.water,
      ],
    ),
  ];

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'kinds': [for (final kind in kinds) kind.name],
      };

  factory MapBiome.fromJson(Map<String, Object?> json) => MapBiome(
        id: _asString(json['id']),
        name: _asString(json['name']),
        description: _asString(json['description']),
        kinds: [
          for (final raw in (json['kinds'] as List? ?? const []))
            ...MapTerrainKind.values.where((kind) => kind.name == raw),
        ],
      );

  static List<MapBiome> read(Map<String, Object?> fields) {
    final raw = fields[MapVisualFields.biomes];
    if (raw is! List) return builtIn;
    final parsed = [
      for (final entry in raw)
        if (entry is Map) MapBiome.fromJson(Map<String, Object?>.from(entry)),
    ];
    return parsed.isEmpty ? builtIn : parsed;
  }
}

// ------------------------------------------------------------------ assets --

/// What a placed asset is for.
enum MapAssetCategory { vegetation, landform, settlement, structure, landmark }

extension MapAssetCategoryLabel on MapAssetCategory {
  String get label => switch (this) {
        MapAssetCategory.vegetation => 'Vegetation',
        MapAssetCategory.landform => 'Landform',
        MapAssetCategory.settlement => 'Settlement',
        MapAssetCategory.structure => 'Structure',
        MapAssetCategory.landmark => 'Landmark',
      };
}

/// A kind of thing that can be placed on a map.
///
/// Deliberately data, not drawing: [iconId] is a name the view resolves to a
/// glyph. The domain stays free of Flutter, and a later asset library — drawn,
/// procedural or licensed — can supply richer artwork for the same id without
/// touching the map architecture.
class MapAssetDefinition {
  const MapAssetDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.iconId,
    this.defaultScale = 1.0,
  });

  final String id;
  final String label;
  final MapAssetCategory category;
  final String iconId;
  final double defaultScale;

  static const List<MapAssetDefinition> library = [
    MapAssetDefinition(
        id: 'tree', label: 'Tree', category: MapAssetCategory.vegetation, iconId: 'park'),
    MapAssetDefinition(
        id: 'forest-clump',
        label: 'Woodland',
        category: MapAssetCategory.vegetation,
        iconId: 'forest'),
    MapAssetDefinition(
        id: 'reed', label: 'Reeds', category: MapAssetCategory.vegetation, iconId: 'grass'),
    MapAssetDefinition(
        id: 'mountain',
        label: 'Mountain',
        category: MapAssetCategory.landform,
        iconId: 'terrain'),
    MapAssetDefinition(
        id: 'hill', label: 'Hill', category: MapAssetCategory.landform, iconId: 'landscape'),
    MapAssetDefinition(
        id: 'volcano',
        label: 'Volcano',
        category: MapAssetCategory.landform,
        iconId: 'volcano'),
    MapAssetDefinition(
        id: 'village',
        label: 'Village',
        category: MapAssetCategory.settlement,
        iconId: 'cottage'),
    MapAssetDefinition(
        id: 'town', label: 'Town', category: MapAssetCategory.settlement, iconId: 'holiday_village'),
    MapAssetDefinition(
        id: 'city', label: 'City', category: MapAssetCategory.settlement, iconId: 'location_city'),
    MapAssetDefinition(
        id: 'castle', label: 'Castle', category: MapAssetCategory.structure, iconId: 'castle'),
    MapAssetDefinition(
        id: 'tower', label: 'Tower', category: MapAssetCategory.structure, iconId: 'tower'),
    MapAssetDefinition(
        id: 'bridge', label: 'Bridge', category: MapAssetCategory.structure, iconId: 'bridge'),
    MapAssetDefinition(
        id: 'ruin', label: 'Ruin', category: MapAssetCategory.landmark, iconId: 'temple_buddhist'),
    MapAssetDefinition(
        id: 'standing-stone',
        label: 'Standing stone',
        category: MapAssetCategory.landmark,
        iconId: 'monument'),
    MapAssetDefinition(
        id: 'harbour', label: 'Harbour', category: MapAssetCategory.landmark, iconId: 'anchor'),
  ];

  static MapAssetDefinition? byId(String id) =>
      library.where((definition) => definition.id == id).firstOrNull;

  static List<MapAssetDefinition> inCategory(MapAssetCategory category) =>
      [for (final item in library) if (item.category == category) item];
}

/// One asset placed on one map.
///
/// This is scenery. It is a value in a field on the map record — never an
/// `AuthorRecord`, never a `RecordLink` endpoint — so a densely wooded map adds
/// nothing at all to the story graph. A forest a story turns on is a `region`,
/// which Phase 1 already supports and which *is* a graph entity.
class MapAssetInstance {
  const MapAssetInstance({
    required this.id,
    required this.definitionId,
    required this.position,
    this.rotation = 0,
    this.scale = 1.0,
    this.layer = 0,
    this.label = '',
  });

  static const double minScale = 0.25;
  static const double maxScale = 6.0;

  final String id;
  final String definitionId;

  /// Map space, always.
  final MapPosition position;

  /// Degrees clockwise, normalised to `0 <= rotation < 360`.
  final double rotation;
  final double scale;

  /// Draw order within the asset layer. Higher sits in front.
  final int layer;
  final String label;

  MapAssetDefinition? get definition => MapAssetDefinition.byId(definitionId);

  MapAssetInstance movedTo(MapPosition value) => copyWith(position: value);

  MapAssetInstance copyWith({
    MapPosition? position,
    double? rotation,
    double? scale,
    int? layer,
    String? label,
  }) =>
      MapAssetInstance(
        id: id,
        definitionId: definitionId,
        position: position ?? this.position,
        rotation: normaliseRotation(rotation ?? this.rotation),
        scale: clampScale(scale ?? this.scale),
        layer: layer ?? this.layer,
        label: label ?? this.label,
      );

  static double normaliseRotation(double value) {
    final wrapped = value % 360;
    return wrapped < 0 ? wrapped + 360 : wrapped;
  }

  static double clampScale(double value) =>
      value.clamp(minScale, maxScale).toDouble();

  Map<String, Object?> toJson() => {
        'id': id,
        'definitionId': definitionId,
        'x': position.x,
        'y': position.y,
        'rotation': rotation,
        'scale': scale,
        'layer': layer,
        'label': label,
      };

  factory MapAssetInstance.fromJson(Map<String, Object?> json) =>
      MapAssetInstance(
        id: _asString(json['id']),
        definitionId: _asString(json['definitionId']),
        position: MapPosition(
          _asDouble(json['x']) ?? 0,
          _asDouble(json['y']) ?? 0,
        ),
        rotation: normaliseRotation(_asDouble(json['rotation']) ?? 0),
        scale: clampScale(_asDouble(json['scale']) ?? 1),
        layer: _asInt(json['layer']) ?? 0,
        label: _asString(json['label']),
      );

  static List<MapAssetInstance> read(Map<String, Object?> fields) {
    final raw = fields[MapVisualFields.assets];
    if (raw is! List) return const [];
    return [
      for (final entry in raw)
        if (entry is Map)
          MapAssetInstance.fromJson(Map<String, Object?>.from(entry)),
    ];
  }

  /// Assets in the order they should be drawn: by layer, then by id so the
  /// order never depends on how the list happened to be stored.
  static List<MapAssetInstance> inDrawOrder(List<MapAssetInstance> assets) {
    final sorted = [...assets];
    sorted.sort((a, b) {
      final byLayer = a.layer.compareTo(b.layer);
      return byLayer != 0 ? byLayer : a.id.compareTo(b.id);
    });
    return sorted;
  }

  @override
  bool operator ==(Object other) =>
      other is MapAssetInstance &&
      other.id == id &&
      other.definitionId == definitionId &&
      other.position == position &&
      other.rotation == rotation &&
      other.scale == scale &&
      other.layer == layer &&
      other.label == label;

  @override
  int get hashCode =>
      Object.hash(id, definitionId, position, rotation, scale, layer, label);
}

// ------------------------------------------------------------------ style ---

/// How the ground beneath the terrain is treated.
enum MapBackgroundTreatment { plain, graticule, parchment }

extension MapBackgroundTreatmentLabel on MapBackgroundTreatment {
  String get label => switch (this) {
        MapBackgroundTreatment.plain => 'Plain',
        MapBackgroundTreatment.graticule => 'Graticule',
        MapBackgroundTreatment.parchment => 'Parchment',
      };
}

/// A map's visual styling.
///
/// [saturation] and [contrast] scale the derived terrain colours; [treatment]
/// chooses the ground. No colour is stored: the Theme Engine supplies it and
/// this only says how far to push it.
class MapVisualStyle {
  const MapVisualStyle({
    this.treatment = MapBackgroundTreatment.graticule,
    this.saturation = 1.0,
    this.contrast = 1.0,
    this.showLegend = true,
    this.terrainOpacity = 0.85,
  });

  static const standard = MapVisualStyle();

  final MapBackgroundTreatment treatment;
  final double saturation;
  final double contrast;
  final bool showLegend;
  final double terrainOpacity;

  MapVisualStyle copyWith({
    MapBackgroundTreatment? treatment,
    double? saturation,
    double? contrast,
    bool? showLegend,
    double? terrainOpacity,
  }) =>
      MapVisualStyle(
        treatment: treatment ?? this.treatment,
        saturation: (saturation ?? this.saturation).clamp(0.0, 2.0).toDouble(),
        contrast: (contrast ?? this.contrast).clamp(0.5, 2.0).toDouble(),
        showLegend: showLegend ?? this.showLegend,
        terrainOpacity:
            (terrainOpacity ?? this.terrainOpacity).clamp(0.1, 1.0).toDouble(),
      );

  Map<String, Object?> toJson() => {
        'treatment': treatment.name,
        'saturation': saturation,
        'contrast': contrast,
        'showLegend': showLegend,
        'terrainOpacity': terrainOpacity,
      };

  factory MapVisualStyle.fromJson(Map<String, Object?> json) => MapVisualStyle(
        treatment: MapBackgroundTreatment.values
                .where((value) => value.name == json['treatment'])
                .firstOrNull ??
            MapBackgroundTreatment.graticule,
        saturation: (_asDouble(json['saturation']) ?? 1).clamp(0.0, 2.0).toDouble(),
        contrast: (_asDouble(json['contrast']) ?? 1).clamp(0.5, 2.0).toDouble(),
        showLegend: json['showLegend'] is bool ? json['showLegend'] as bool : true,
        terrainOpacity:
            (_asDouble(json['terrainOpacity']) ?? 0.85).clamp(0.1, 1.0).toDouble(),
      );

  static MapVisualStyle read(Map<String, Object?> fields) {
    final raw = fields[MapVisualFields.style];
    if (raw is Map) {
      return MapVisualStyle.fromJson(Map<String, Object?>.from(raw));
    }
    return standard;
  }

  @override
  bool operator ==(Object other) =>
      other is MapVisualStyle &&
      other.treatment == treatment &&
      other.saturation == saturation &&
      other.contrast == contrast &&
      other.showLegend == showLegend &&
      other.terrainOpacity == terrainOpacity;

  @override
  int get hashCode =>
      Object.hash(treatment, saturation, contrast, showLegend, terrainOpacity);
}

/// One entry in the map's terrain legend.
class MapLegendEntry {
  const MapLegendEntry({
    required this.kind,
    required this.coverage,
  });

  final MapTerrainKind kind;

  /// Fraction of the map this kind covers, `0.0`..`1.0`.
  final double coverage;

  String get label => kind.label;
}

/// Builds the legend for a painted map: the kinds present, most of the map
/// first, so the legend reads as a description of the world.
List<MapLegendEntry> mapLegendFor(MapTerrainGrid terrain) {
  final coverage = terrain.coverage;
  final entries = [
    for (final entry in coverage.entries)
      MapLegendEntry(kind: entry.key, coverage: entry.value),
  ];
  entries.sort((a, b) {
    final byCoverage = b.coverage.compareTo(a.coverage);
    return byCoverage != 0 ? byCoverage : a.kind.index.compareTo(b.kind.index);
  });
  return entries;
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

String _asString(Object? value) => value is String ? value.trim() : '';

/// The Phase 3 surface of a map, read from the same record Phase 1 stores.
///
/// An extension rather than fields on [MapSummary] so the Phase 1 domain never
/// has to know Phase 3 exists: `map_terrain.dart` depends on `map_domain.dart`
/// and never the other way round.
extension MapVisualSummary on MapSummary {
  MapTerrainGrid get terrain => MapTerrainGrid.read(record.fields);
  List<MapAssetInstance> get assets => MapAssetInstance.read(record.fields);
  List<MapAssetInstance> get assetsInDrawOrder =>
      MapAssetInstance.inDrawOrder(assets);
  MapVisualStyle get visualStyle => MapVisualStyle.read(record.fields);
  List<MapBiome> get biomes => MapBiome.read(record.fields);
  List<MapLegendEntry> get legend => mapLegendFor(terrain);
}
