/// Map Studio Phase 1 — the business layer.
///
/// `MapService` is the only place Map Studio reads or writes. It owns no store:
/// every map, place, region and marker is an ordinary Universal Record written
/// through the existing [RecordService] and connected through the existing
/// [ConnectionEngine], on the one AuthorOS Drift database. There is deliberately
/// no Map-owned repository, database or key-value store: AuthorOS already has
/// one, and Map Studio uses it.
library;

import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/record_inspector.dart';
import 'core/record_service.dart';
import 'core/safe_delete_service.dart';
import 'core/universal_search.dart';
import 'core/version_audit.dart';
import 'core/version_audit_service.dart';
import 'core/world_record_types.dart';
import 'map_domain.dart';
import 'map_terrain.dart';
import 'persistence/authoros_database.dart';

export 'map_domain.dart';
export 'map_terrain.dart';

/// The values needed to create or re-describe a map.
class MapDraft {
  const MapDraft({
    required this.id,
    required this.title,
    this.description = '',
    this.mapType = '',
    this.typeId = MapTypes.map,
    this.extent = MapExtent.standard,
    this.backgroundReference = '',
    this.tags = const [],
  });

  final String id;
  final String title;
  final String description;
  final String mapType;

  /// One of [WorldRecordTypes.mapTypeIds]; the plain `map` unless a caller
  /// picks a narrower kind that already exists in the record vocabulary.
  final String typeId;
  final MapExtent extent;
  final String backgroundReference;
  final List<String> tags;
}

/// The values needed to place a location on a map.
class MapLocationDraft {
  const MapLocationDraft({
    required this.id,
    required this.mapId,
    required this.name,
    this.description = '',
    this.locationType = '',
    this.typeId = MapTypes.location,
    this.position,
    this.tags = const [],
  });

  final String id;
  final String mapId;
  final String name;
  final String description;

  /// A free-text category shown on the pin; distinct from [typeId], which is
  /// the record type the place is stored as.
  final String locationType;
  final String typeId;

  /// Map-space position. Defaults to the centre of the map's extent.
  final MapPosition? position;
  final List<String> tags;
}

/// The values needed to place a region on a map.
class MapRegionDraft {
  const MapRegionDraft({
    required this.id,
    required this.mapId,
    required this.name,
    this.description = '',
    this.category = '',
    this.geometry = MapGeometry.empty,
    this.tags = const [],
  });

  final String id;
  final String mapId;
  final String name;
  final String description;
  final String category;

  /// Phase 1 stores whatever shape it is given and renders its bounding box.
  final MapGeometry geometry;
  final List<String> tags;
}

/// The values needed to place a marker on a map.
class MapMarkerDraft {
  const MapMarkerDraft({
    required this.id,
    required this.mapId,
    required this.label,
    this.position,
    this.category = '',
    this.icon = '',
    this.notes = '',
    this.linkedRecordId,
  });

  final String id;
  final String mapId;
  final String label;
  final MapPosition? position;
  final String category;
  final String icon;
  final String notes;

  /// Optional. When present the marker is connected to that record with the
  /// existing `represents` link, which is the seam Phase 4 builds its character,
  /// plot, timeline and research connections on.
  final String? linkedRecordId;
}

/// Raised when Map Studio is asked for something the project does not hold.
class MapStudioException implements Exception {
  const MapStudioException(this.message);

  final String message;

  @override
  String toString() => 'MapStudioException: $message';
}

class MapService {
  const MapService({required this.projectId, required this.repository});

  /// The service the shell uses, bound to the application database.
  ///
  /// Widgets never reach for the repository themselves; this factory is the
  /// only wiring point between Map Studio and AuthorOS persistence.
  factory MapService.forProject(String projectId) =>
      MapService(projectId: projectId, repository: authorOsRepository);

  final String projectId;
  final DriftConnectedDomainRepository repository;

  RecordService get records =>
      RecordService(projectId: projectId, repository: repository);
  ConnectionEngine get connections =>
      ConnectionEngine(scopeId: projectId, repository: repository);
  UniversalSearchService get search =>
      UniversalSearchService(projectId: projectId, repository: repository);
  VersionAuditService get history =>
      VersionAuditService(projectId: projectId, repository: repository);
  UniversalRecordInspector get inspector =>
      UniversalRecordInspector(projectId: projectId, repository: repository);
  SafeDeleteService get safeDelete =>
      SafeDeleteService(projectId: projectId, repository: repository);

  // ---------------------------------------------------------------- maps ----

  Future<MapSummary> createMap(MapDraft draft, {DateTime? timestamp}) async {
    final title = draft.title.trim();
    if (draft.id.trim().isEmpty || title.isEmpty) {
      throw ArgumentError('A map needs an id and a title.');
    }
    if (!MapTypes.mapTypeIds.contains(draft.typeId)) {
      throw ArgumentError.value(draft.typeId, 'typeId', 'is not a map type');
    }
    if (!draft.extent.isValid) {
      throw ArgumentError('A map extent needs a positive width and height.');
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final record = await records.createRecord(
      _record(
        id: draft.id,
        typeId: draft.typeId,
        title: title,
        fields: {
          MapFields.primaryName: title,
          MapFields.description: draft.description.trim(),
          MapFields.mapType: draft.mapType.trim(),
          MapFields.width: draft.extent.width,
          MapFields.height: draft.extent.height,
          MapFields.backgroundReference: draft.backgroundReference.trim(),
          MapFields.coordinateSystem: 'map-space',
        },
        tags: draft.tags,
        now: now,
      ),
    );
    return MapSummary(record: record);
  }

  Future<MapSummary?> getMap(String id) async {
    final record = await records.getRecord(id);
    if (record == null || !MapTypes.mapTypeIds.contains(record.typeId)) {
      return null;
    }
    return MapSummary(record: record);
  }

  Future<List<MapSummary>> listMaps({bool includeArchived = false}) async {
    final all = await repository.recordsByProject(projectId);
    final maps = [
      for (final record in all)
        if (MapTypes.mapTypeIds.contains(record.typeId) &&
            record.status != AuthorRecordStatus.deleted &&
            (includeArchived || record.status == AuthorRecordStatus.active))
          MapSummary(record: record),
    ];
    maps.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return maps;
  }

  /// Rewrites a map's metadata surface: title, description and extent.
  Future<MapSummary> updateMap(
    String id, {
    String? title,
    String? description,
    String? mapType,
    MapExtent? extent,
    String? backgroundReference,
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    if (extent != null && !extent.isValid) {
      throw ArgumentError('A map extent needs a positive width and height.');
    }
    final nextTitle = title?.trim();
    if (nextTitle != null && nextTitle.isEmpty) {
      throw ArgumentError('A map title cannot be cleared.');
    }
    final fields = Map<String, Object?>.from(existing.fields);
    if (nextTitle != null) fields[MapFields.primaryName] = nextTitle;
    if (description != null) {
      fields[MapFields.description] = description.trim();
    }
    if (mapType != null) fields[MapFields.mapType] = mapType.trim();
    if (extent != null) {
      fields[MapFields.width] = extent.width;
      fields[MapFields.height] = extent.height;
    }
    if (backgroundReference != null) {
      fields[MapFields.backgroundReference] = backgroundReference.trim();
    }
    final updated = await records.updateRecord(
      existing.copyWith(
        title: nextTitle ?? existing.title,
        fields: fields,
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
    return MapSummary(record: updated);
  }

  Future<MapSummary> archiveMap(String id, {DateTime? timestamp}) async {
    await _requireMap(id);
    return MapSummary(
      record: await records.archiveRecord(id, timestamp: timestamp),
    );
  }

  Future<MapSummary> restoreMap(String id, {DateTime? timestamp}) async {
    await _requireMap(id);
    return MapSummary(
      record: await records.restoreRecord(id, timestamp: timestamp),
    );
  }

  /// Soft-deletes a map through the shared record lifecycle.
  ///
  /// Nothing is erased: the record moves to [AuthorRecordStatus.deleted] and its
  /// version history survives, exactly as for every other AuthorOS record.
  Future<MapSummary> deleteMap(String id, {DateTime? timestamp}) async {
    await _requireMap(id);
    return MapSummary(
      record: await records.deleteRecord(id, timestamp: timestamp),
    );
  }

  // ----------------------------------------------------------- locations ----

  Future<MapLocationView> createLocation(
    MapLocationDraft draft, {
    DateTime? timestamp,
  }) async {
    final name = draft.name.trim();
    if (draft.id.trim().isEmpty || name.isEmpty) {
      throw ArgumentError('A location needs an id and a name.');
    }
    if (!MapTypes.locationTypeIds.contains(draft.typeId)) {
      throw ArgumentError.value(
          draft.typeId, 'typeId', 'is not a location type');
    }
    final map = await _requireMap(draft.mapId);
    final extent = MapExtent.fromRecord(map);
    final position = (draft.position ?? extent.centre).clampTo(extent);
    final now = (timestamp ?? DateTime.now()).toUtc();
    final record = await records.createRecord(
      _record(
        id: draft.id,
        typeId: draft.typeId,
        title: name,
        fields: {
          MapFields.primaryName: name,
          MapFields.description: draft.description.trim(),
          MapFields.locationType: draft.locationType.trim(),
          MapFields.mapId: draft.mapId,
          MapFields.x: position.x,
          MapFields.y: position.y,
        },
        tags: draft.tags,
        now: now,
      ),
    );
    await _place(mapId: draft.mapId, placeId: record.id, timestamp: now);
    return MapLocationView(record: record, mapId: draft.mapId);
  }

  Future<MapLocationView> updateLocation(
    String id, {
    String? name,
    String? description,
    String? locationType,
    MapPosition? position,
    DateTime? timestamp,
  }) async {
    final existing = await _requirePlace(id, MapTypes.locationTypeIds);
    final mapId = _mapIdOf(existing);
    final nextName = name?.trim();
    if (nextName != null && nextName.isEmpty) {
      throw ArgumentError('A location name cannot be cleared.');
    }
    final fields = Map<String, Object?>.from(existing.fields);
    if (nextName != null) fields[MapFields.primaryName] = nextName;
    if (description != null) {
      fields[MapFields.description] = description.trim();
    }
    if (locationType != null) {
      fields[MapFields.locationType] = locationType.trim();
    }
    if (position != null) {
      final clamped = position.clampTo(await _extentOf(mapId));
      fields[MapFields.x] = clamped.x;
      fields[MapFields.y] = clamped.y;
    }
    final updated = await records.updateRecord(
      existing.copyWith(
        title: nextName ?? existing.title,
        fields: fields,
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
    return MapLocationView(record: updated, mapId: mapId);
  }

  /// Moves a location to [position], clamped into the map's extent.
  Future<MapLocationView> moveLocation(
    String id,
    MapPosition position, {
    DateTime? timestamp,
  }) =>
      updateLocation(id, position: position, timestamp: timestamp);

  Future<MapLocationView> archiveLocation(String id,
          {DateTime? timestamp}) async =>
      MapLocationView(
        record: await _archivePlace(id, MapTypes.locationTypeIds, timestamp),
        mapId: _mapIdOf(await _requirePlace(id, MapTypes.locationTypeIds)),
      );

  Future<MapLocationView> deleteLocation(String id,
      {DateTime? timestamp}) async {
    final existing = await _requirePlace(id, MapTypes.locationTypeIds);
    return MapLocationView(
      record: await records.deleteRecord(id, timestamp: timestamp),
      mapId: _mapIdOf(existing),
    );
  }

  Future<List<MapLocationView>> locationsForMap(
    String mapId, {
    bool includeArchived = false,
  }) async {
    final records = await _placesOn(mapId, MapTypes.locationTypeIds,
        includeArchived: includeArchived);
    return [
      for (final record in records) MapLocationView(record: record, mapId: mapId),
    ];
  }

  // ------------------------------------------------------------- regions ----

  Future<MapRegionView> createRegion(
    MapRegionDraft draft, {
    DateTime? timestamp,
  }) async {
    final name = draft.name.trim();
    if (draft.id.trim().isEmpty || name.isEmpty) {
      throw ArgumentError('A region needs an id and a name.');
    }
    final map = await _requireMap(draft.mapId);
    final extent = MapExtent.fromRecord(map);
    final geometry = _clampGeometry(draft.geometry, extent);
    final anchor = geometry.centre ?? extent.centre;
    final now = (timestamp ?? DateTime.now()).toUtc();
    final record = await records.createRecord(
      _record(
        id: draft.id,
        typeId: MapTypes.region,
        title: name,
        fields: {
          MapFields.primaryName: name,
          MapFields.description: draft.description.trim(),
          MapFields.locationType: draft.category.trim(),
          MapFields.mapId: draft.mapId,
          MapFields.x: anchor.x,
          MapFields.y: anchor.y,
          MapFields.geometry: geometry.toJson(),
        },
        tags: draft.tags,
        now: now,
      ),
    );
    await _place(mapId: draft.mapId, placeId: record.id, timestamp: now);
    return MapRegionView(record: record, mapId: draft.mapId);
  }

  Future<MapRegionView> updateRegion(
    String id, {
    String? name,
    String? description,
    String? category,
    MapGeometry? geometry,
    DateTime? timestamp,
  }) async {
    final existing = await _requirePlace(id, const {MapTypes.region});
    final mapId = _mapIdOf(existing);
    final nextName = name?.trim();
    if (nextName != null && nextName.isEmpty) {
      throw ArgumentError('A region name cannot be cleared.');
    }
    final fields = Map<String, Object?>.from(existing.fields);
    if (nextName != null) fields[MapFields.primaryName] = nextName;
    if (description != null) {
      fields[MapFields.description] = description.trim();
    }
    if (category != null) fields[MapFields.locationType] = category.trim();
    if (geometry != null) {
      final clamped = _clampGeometry(geometry, await _extentOf(mapId));
      fields[MapFields.geometry] = clamped.toJson();
      final anchor = clamped.centre;
      if (anchor != null) {
        fields[MapFields.x] = anchor.x;
        fields[MapFields.y] = anchor.y;
      }
    }
    final updated = await records.updateRecord(
      existing.copyWith(
        title: nextName ?? existing.title,
        fields: fields,
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
    return MapRegionView(record: updated, mapId: mapId);
  }

  /// Replaces a region's shape.
  ///
  /// The whole geometry editor funnels through here: every point the writer
  /// drags is map space, clamped into the map's extent, written onto the same
  /// record. No new record, no second store, no pixels.
  Future<MapRegionView> setRegionGeometry(
    String id,
    MapGeometry geometry, {
    DateTime? timestamp,
  }) =>
      updateRegion(id, geometry: geometry, timestamp: timestamp);

  /// Moves one point of a region's shape.
  Future<MapRegionView> moveRegionPoint(
    String id,
    int index,
    MapPosition position, {
    DateTime? timestamp,
  }) async {
    final geometry = await regionGeometry(id);
    if (index < 0 || index >= geometry.points.length) {
      throw MapStudioException(
        'Region $id has no geometry point at index $index.',
      );
    }
    return updateRegion(
      id,
      geometry: geometry.withPointAt(index, position),
      timestamp: timestamp,
    );
  }

  /// Adds a point to a region's shape, appended when [index] is absent.
  Future<MapRegionView> addRegionPoint(
    String id,
    MapPosition position, {
    int? index,
    DateTime? timestamp,
  }) async {
    final geometry = await regionGeometry(id);
    return updateRegion(
      id,
      geometry: geometry.withPointAdded(position, index: index),
      timestamp: timestamp,
    );
  }

  /// Removes a point, unless that would leave the shape with too few.
  Future<MapRegionView> removeRegionPoint(
    String id,
    int index, {
    DateTime? timestamp,
  }) async {
    final geometry = await regionGeometry(id);
    return updateRegion(
      id,
      geometry: geometry.withPointRemoved(index),
      timestamp: timestamp,
    );
  }

  /// Re-expresses a region as another kind of shape.
  ///
  /// A bounds region becomes the four corners of its box; a polygon collapses
  /// back to the box it occupies. The record and its history are the same.
  Future<MapRegionView> reshapeRegion(
    String id,
    MapGeometryKind kind, {
    DateTime? timestamp,
  }) async {
    final geometry = await regionGeometry(id);
    final next = switch (kind) {
      MapGeometryKind.polygon => geometry.asPolygon(),
      MapGeometryKind.bounds => geometry.asBounds(),
      MapGeometryKind.polyline => MapGeometry(
          kind: MapGeometryKind.polyline,
          points: geometry.asPolygon().points,
        ),
      MapGeometryKind.point => MapGeometry(
          kind: MapGeometryKind.point,
          points: [
            if (geometry.centre != null) geometry.centre!,
          ],
        ),
    };
    return updateRegion(id, geometry: next, timestamp: timestamp);
  }

  /// Drags a whole region so its centre lands on [anchor].
  Future<MapRegionView> moveRegion(
    String id,
    MapPosition anchor, {
    DateTime? timestamp,
  }) async {
    final geometry = await regionGeometry(id);
    if (geometry.isEmpty) {
      throw MapStudioException('Region $id has no geometry to move.');
    }
    return updateRegion(
      id,
      geometry: geometry.movedTo(anchor),
      timestamp: timestamp,
    );
  }

  /// The stored shape of a region.
  Future<MapGeometry> regionGeometry(String id) async =>
      MapGeometry.read((await _requirePlace(id, const {MapTypes.region})).fields);

  Future<MapRegionView> archiveRegion(String id, {DateTime? timestamp}) async {
    final existing = await _requirePlace(id, const {MapTypes.region});
    return MapRegionView(
      record: await records.archiveRecord(id, timestamp: timestamp),
      mapId: _mapIdOf(existing),
    );
  }

  Future<MapRegionView> deleteRegion(String id, {DateTime? timestamp}) async {
    final existing = await _requirePlace(id, const {MapTypes.region});
    return MapRegionView(
      record: await records.deleteRecord(id, timestamp: timestamp),
      mapId: _mapIdOf(existing),
    );
  }

  Future<List<MapRegionView>> regionsForMap(
    String mapId, {
    bool includeArchived = false,
  }) async {
    final records = await _placesOn(mapId, const {MapTypes.region},
        includeArchived: includeArchived);
    return [
      for (final record in records) MapRegionView(record: record, mapId: mapId),
    ];
  }

  // -------------------------------------------------- terrain and scenery ---
  //
  // Phase 3 stores how a map *looks* in fields on the map record itself. It is
  // presentation data: terrain, scenery and styling are never AuthorRecords and
  // never endpoints of a RecordLink, so a densely painted map adds nothing to
  // the story graph. A place a story turns on is a location or a region, which
  // Phase 1 already provides and which are graph entities.

  /// Replaces a map's painted ground.
  Future<MapSummary> setTerrain(
    String id,
    MapTerrainGrid terrain, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    final fields = Map<String, Object?>.from(existing.fields);
    if (terrain.isEmpty && terrain.cellCount == 0) {
      fields.remove(MapVisualFields.terrain);
    } else {
      fields[MapVisualFields.terrain] = terrain.toJson();
    }
    return MapSummary(record: await _write(existing, fields, timestamp));
  }

  /// Applies one brush stroke at a map-space position.
  ///
  /// The pointer's pixels were converted by [MapProjection] before they reached
  /// here, and the brush radius is in map units, so the same stroke covers the
  /// same ground at any zoom.
  Future<MapSummary> paintTerrain(
    String id,
    MapTerrainBrush brush,
    MapPosition position, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    final extent = MapExtent.fromRecord(existing);
    var terrain = MapTerrainGrid.read(existing.fields);
    if (terrain.cellCount == 0) {
      terrain = MapTerrainGrid.empty();
    }
    final painted = terrain.painted(
      brush,
      position.clampTo(extent),
      extent,
    );
    final fields = Map<String, Object?>.from(existing.fields)
      ..[MapVisualFields.terrain] = painted.toJson();
    return MapSummary(record: await _write(existing, fields, timestamp));
  }

  /// Applies a whole brush stroke in one write.
  ///
  /// A stroke is one editing act, so it is one record revision and one audit
  /// event -- not one per pointer move. The canvas previews the stroke locally
  /// while the writer drags and sends it here on release.
  Future<MapSummary> paintTerrainStroke(
    String id,
    MapTerrainBrush brush,
    List<MapPosition> positions, {
    DateTime? timestamp,
  }) async {
    if (positions.isEmpty) return MapSummary(record: await _requireMap(id));
    final existing = await _requireMap(id);
    final extent = MapExtent.fromRecord(existing);
    var terrain = MapTerrainGrid.read(existing.fields);
    if (terrain.cellCount == 0) {
      terrain = MapTerrainGrid.empty();
    }
    for (final position in positions) {
      terrain = terrain.painted(brush, position.clampTo(extent), extent);
    }
    final fields = Map<String, Object?>.from(existing.fields)
      ..[MapVisualFields.terrain] = terrain.toJson();
    return MapSummary(record: await _write(existing, fields, timestamp));
  }

  /// Floods the whole map with one kind — the usual way to start.
  Future<MapSummary> fillTerrain(
    String id,
    MapTerrainKind kind, {
    int resolution = MapTerrainGrid.defaultResolution,
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    var terrain = MapTerrainGrid.read(existing.fields);
    if (terrain.cellCount == 0) {
      terrain = MapTerrainGrid.empty(columns: resolution, rows: resolution);
    }
    return setTerrain(id, terrain.filled(kind), timestamp: timestamp);
  }

  /// Returns the map to unpainted ground. Removes the field entirely rather
  /// than storing an empty grid, so an unpainted map costs nothing.
  Future<MapSummary> clearTerrain(String id, {DateTime? timestamp}) async {
    final existing = await _requireMap(id);
    final fields = Map<String, Object?>.from(existing.fields)
      ..remove(MapVisualFields.terrain);
    return MapSummary(record: await _write(existing, fields, timestamp));
  }

  Future<MapTerrainGrid> terrainFor(String id) async =>
      MapTerrainGrid.read((await _requireMap(id)).fields);

  /// Replaces the biome vocabulary this map recognises.
  Future<MapSummary> setBiomes(
    String id,
    List<MapBiome> biomes, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    final fields = Map<String, Object?>.from(existing.fields)
      ..[MapVisualFields.biomes] = [
        for (final biome in biomes) biome.toJson(),
      ];
    return MapSummary(record: await _write(existing, fields, timestamp));
  }

  Future<List<MapBiome>> biomesFor(String id) async =>
      MapBiome.read((await _requireMap(id)).fields);

  /// Rewrites the map's visual styling.
  Future<MapSummary> setVisualStyle(
    String id,
    MapVisualStyle style, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    final fields = Map<String, Object?>.from(existing.fields)
      ..[MapVisualFields.style] = style.toJson();
    return MapSummary(record: await _write(existing, fields, timestamp));
  }

  Future<MapVisualStyle> visualStyleFor(String id) async =>
      MapVisualStyle.read((await _requireMap(id)).fields);

  // ------------------------------------------------------------- scenery ----

  /// Places a visual asset on the map.
  Future<MapSummary> addAsset(
    String id,
    MapAssetInstance asset, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    if (asset.id.trim().isEmpty) {
      throw ArgumentError('An asset needs an id.');
    }
    if (MapAssetDefinition.byId(asset.definitionId) == null) {
      throw ArgumentError.value(
        asset.definitionId,
        'definitionId',
        'is not in the asset library',
      );
    }
    final extent = MapExtent.fromRecord(existing);
    final assets = MapAssetInstance.read(existing.fields);
    if (assets.any((item) => item.id == asset.id)) {
      throw MapStudioException('Asset ${asset.id} is already on $id.');
    }
    final placed = asset.copyWith(position: asset.position.clampTo(extent));
    return _writeAssets(existing, [...assets, placed], timestamp);
  }

  /// Moves an asset to a map-space position, clamped into the map.
  Future<MapSummary> moveAsset(
    String id,
    String assetId,
    MapPosition position, {
    DateTime? timestamp,
  }) =>
      _updateAsset(
        id,
        assetId,
        (asset, extent) => asset.copyWith(position: position.clampTo(extent)),
        timestamp: timestamp,
      );

  /// Rotates, scales, re-layers or relabels an asset.
  Future<MapSummary> transformAsset(
    String id,
    String assetId, {
    double? rotation,
    double? scale,
    int? layer,
    String? label,
    DateTime? timestamp,
  }) =>
      _updateAsset(
        id,
        assetId,
        (asset, _) => asset.copyWith(
          rotation: rotation,
          scale: scale,
          layer: layer,
          label: label,
        ),
        timestamp: timestamp,
      );

  Future<MapSummary> removeAsset(
    String id,
    String assetId, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    final assets = MapAssetInstance.read(existing.fields);
    if (!assets.any((item) => item.id == assetId)) {
      throw MapStudioException('Asset $assetId is not on $id.');
    }
    return _writeAssets(
      existing,
      [for (final item in assets) if (item.id != assetId) item],
      timestamp,
    );
  }

  Future<List<MapAssetInstance>> assetsFor(String id) async =>
      MapAssetInstance.inDrawOrder(
        MapAssetInstance.read((await _requireMap(id)).fields),
      );

  Future<MapSummary> _updateAsset(
    String id,
    String assetId,
    MapAssetInstance Function(MapAssetInstance asset, MapExtent extent) change, {
    DateTime? timestamp,
  }) async {
    final existing = await _requireMap(id);
    final extent = MapExtent.fromRecord(existing);
    final assets = MapAssetInstance.read(existing.fields);
    if (!assets.any((item) => item.id == assetId)) {
      throw MapStudioException('Asset $assetId is not on $id.');
    }
    return _writeAssets(
      existing,
      [
        for (final item in assets)
          if (item.id == assetId) change(item, extent) else item,
      ],
      timestamp,
    );
  }

  Future<MapSummary> _writeAssets(
    AuthorRecord existing,
    List<MapAssetInstance> assets,
    DateTime? timestamp,
  ) async {
    final fields = Map<String, Object?>.from(existing.fields);
    if (assets.isEmpty) {
      fields.remove(MapVisualFields.assets);
    } else {
      fields[MapVisualFields.assets] = [
        for (final asset in MapAssetInstance.inDrawOrder(assets))
          asset.toJson(),
      ];
    }
    return MapSummary(record: await _write(existing, fields, timestamp));
  }

  /// One write path for every Phase 3 change, so styling inherits the same
  /// revisioning, version snapshots and audit events as everything else.
  Future<AuthorRecord> _write(
    AuthorRecord existing,
    Map<String, Object?> fields,
    DateTime? timestamp,
  ) =>
      records.updateRecord(
        existing.copyWith(
          fields: fields,
          updatedAt: (timestamp ?? DateTime.now()).toUtc(),
        ),
      );

  // ------------------------------------------------------------- markers ----

  /// Marks [recordId] as becoming known to the reader in manuscript node
  /// [nodeId], by writing the canonical `revealedIn` relationship.
  ///
  /// **The only write in the whole of Phase 6.** Presentation, projection,
  /// export and reader filtering are read-only by construction; this is the one
  /// place a reveal comes into existence, and it exists only because an author
  /// asked for it. Nothing infers a reveal point, and nothing creates one as a
  /// side effect of drawing, exporting or opening anything.
  ///
  /// The relationship is the one AuthorOS already defines — "Revealed in",
  /// inverse "Reveals" — written through the same [ConnectionEngine] as every
  /// other Map Studio link, so it validates, versions and audits like any
  /// other. There is no second spoiler system and no Map-owned reveal store.
  ///
  /// [nodeId] must be a manuscript node of a type a reveal can point at. The
  /// registry defines `revealedIn` with wildcard endpoints, so it would accept
  /// anything at all; the discipline has to come from here. A reveal that
  /// pointed at a character rather than a scene would order by nothing and
  /// filter by nothing, so it is refused rather than stored.
  ///
  /// Reversible by [removeRevealPoint], which deletes the link outright.
  Future<RecordLink> addRevealPoint({
    required String recordId,
    required String nodeId,
    DateTime? timestamp,
  }) async {
    final record = await records.getRecord(recordId);
    if (record == null || (record.projectId ?? record.scopeId) != projectId) {
      throw MapStudioException('$recordId is not a record in $projectId.');
    }
    final node = await repository.manuscriptNodeById(nodeId);
    if (node == null || node.projectId != projectId) {
      throw MapStudioException(
        '$nodeId is not a manuscript node in $projectId.',
      );
    }
    if (!MapTypes.revealTargetTypes.contains(node.nodeType)) {
      throw MapStudioException(
        'A reveal point must be a ${MapTypes.revealTargetTypes.join(', ')} — '
        '$nodeId is a ${node.nodeType}.',
      );
    }
    // Source is the thing revealed, target the place it is revealed: "the
    // Drowned City is revealed in Chapter 7", which is the direction the
    // relationship's own label reads in.
    return connections.connect(
      sourceId: recordId,
      targetId: nodeId,
      typeId: MapTypes.revealedIn,
      timestamp: timestamp,
    );
  }

  /// Undoes [addRevealPoint], returning true where there was one to undo.
  ///
  /// A reveal point is an editorial decision, and editorial decisions get
  /// changed. Removing one restores the record to "the author has not said when
  /// this becomes known", which every reader level below the author's own
  /// treats as hidden — so unrevealing is safe by the same rule that makes an
  /// untouched project safe.
  Future<bool> removeRevealPoint({
    required String recordId,
    required String nodeId,
    DateTime? timestamp,
  }) async {
    final link = await _revealLink(recordId, nodeId);
    if (link == null) return false;
    await connections.disconnect(link.id, timestamp: timestamp);
    return true;
  }

  /// Every reveal point on [recordId], earliest first by manuscript order.
  ///
  /// Read-only, and returns the links themselves so a caller can show the
  /// author what exists and remove any one of them.
  Future<List<MapRevealLink>> revealPointsFor(String recordId) async {
    final links = await repository.outgoingLinks(recordId);
    final reveals = <MapRevealLink>[];
    for (final link in links) {
      if (link.scopeId != projectId) continue;
      if (link.typeId != MapTypes.revealedIn) continue;
      final node = await repository.manuscriptNodeById(link.targetId);
      if (node == null) continue;
      reveals.add(MapRevealLink(link: link, node: node));
    }
    reveals.sort((a, b) => a.node.id.compareTo(b.node.id));
    return reveals;
  }

  Future<RecordLink?> _revealLink(String recordId, String nodeId) async {
    for (final link in await repository.outgoingLinks(recordId)) {
      if (link.scopeId == projectId &&
          link.typeId == MapTypes.revealedIn &&
          link.targetId == nodeId) {
        return link;
      }
    }
    return null;
  }

  Future<MapMarkerView> createMarker(
    MapMarkerDraft draft, {
    DateTime? timestamp,
  }) async {
    final label = draft.label.trim();
    if (draft.id.trim().isEmpty || label.isEmpty) {
      throw ArgumentError('A marker needs an id and a label.');
    }
    final map = await _requireMap(draft.mapId);
    final extent = MapExtent.fromRecord(map);
    final position = (draft.position ?? extent.centre).clampTo(extent);
    final linkedId = draft.linkedRecordId?.trim();
    if (linkedId != null && linkedId.isNotEmpty) {
      if (await records.getRecord(linkedId) == null) {
        throw MapStudioException(
          'Marker target $linkedId does not exist in $projectId.',
        );
      }
    }
    final now = (timestamp ?? DateTime.now()).toUtc();
    final record = await records.createRecord(
      _record(
        id: draft.id,
        typeId: MapTypes.marker,
        title: label,
        fields: {
          MapFields.markerMapId: draft.mapId,
          MapFields.markerX: position.x,
          MapFields.markerY: position.y,
          MapFields.markerLabel: label,
          MapFields.markerIcon: draft.icon.trim(),
          MapFields.markerCategory: draft.category.trim(),
          MapFields.markerVisibility: 'visible',
          MapFields.markerNotes: draft.notes.trim(),
          if (linkedId != null && linkedId.isNotEmpty)
            MapFields.markerRecordId: linkedId,
        },
        now: now,
      ),
    );
    await connections.connect(
      sourceId: record.id,
      targetId: draft.mapId,
      typeId: MapTypes.markerOnMap,
      timestamp: now,
    );
    if (linkedId != null && linkedId.isNotEmpty) {
      await connections.connect(
        sourceId: record.id,
        targetId: linkedId,
        typeId: MapTypes.markerRepresents,
        timestamp: now,
      );
    }
    return MapMarkerView(record: record, mapId: draft.mapId);
  }

  Future<MapMarkerView> updateMarker(
    String id, {
    String? label,
    String? category,
    String? icon,
    String? notes,
    MapPosition? position,
    DateTime? timestamp,
  }) async {
    final existing = await _requireMarker(id);
    final mapId = _markerMapIdOf(existing);
    final nextLabel = label?.trim();
    if (nextLabel != null && nextLabel.isEmpty) {
      throw ArgumentError('A marker label cannot be cleared.');
    }
    final fields = Map<String, Object?>.from(existing.fields);
    if (nextLabel != null) fields[MapFields.markerLabel] = nextLabel;
    if (category != null) {
      fields[MapFields.markerCategory] = category.trim();
    }
    if (icon != null) fields[MapFields.markerIcon] = icon.trim();
    if (notes != null) fields[MapFields.markerNotes] = notes.trim();
    if (position != null) {
      final clamped = position.clampTo(await _extentOf(mapId));
      fields[MapFields.markerX] = clamped.x;
      fields[MapFields.markerY] = clamped.y;
    }
    final updated = await records.updateRecord(
      existing.copyWith(
        title: nextLabel ?? existing.title,
        fields: fields,
        updatedAt: (timestamp ?? DateTime.now()).toUtc(),
      ),
    );
    return MapMarkerView(record: updated, mapId: mapId);
  }

  Future<MapMarkerView> moveMarker(
    String id,
    MapPosition position, {
    DateTime? timestamp,
  }) =>
      updateMarker(id, position: position, timestamp: timestamp);

  Future<MapMarkerView> archiveMarker(String id, {DateTime? timestamp}) async {
    final existing = await _requireMarker(id);
    return MapMarkerView(
      record: await records.archiveRecord(id, timestamp: timestamp),
      mapId: _markerMapIdOf(existing),
    );
  }

  Future<MapMarkerView> deleteMarker(String id, {DateTime? timestamp}) async {
    final existing = await _requireMarker(id);
    return MapMarkerView(
      record: await records.deleteRecord(id, timestamp: timestamp),
      mapId: _markerMapIdOf(existing),
    );
  }

  Future<List<MapMarkerView>> markersForMap(
    String mapId, {
    bool includeArchived = false,
  }) async {
    await _requireMap(mapId);
    final all = await repository.recordsByProject(projectId);
    final markers = [
      for (final record in all)
        if (record.typeId == MapTypes.marker &&
            _markerMapIdOf(record) == mapId &&
            record.status != AuthorRecordStatus.deleted &&
            (includeArchived || record.status == AuthorRecordStatus.active))
          MapMarkerView(record: record, mapId: mapId),
    ];
    markers.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return markers;
  }

  // -------------------------------------------------------------- canvas ----

  /// Everything the canvas needs for one map, in a single read.
  Future<MapCanvasData> loadCanvas(
    String mapId, {
    bool includeArchived = false,
  }) async {
    final map = await _requireMap(mapId);
    return MapCanvasData(
      map: MapSummary(record: map),
      locations: await locationsForMap(mapId, includeArchived: includeArchived),
      regions: await regionsForMap(mapId, includeArchived: includeArchived),
      markers: await markersForMap(mapId, includeArchived: includeArchived),
    );
  }

  /// The version trail for any Map Studio record, from the shared audit log.
  Future<List<RecordVersion>> mapHistory(String id) =>
      history.getVersionHistory(recordId: id);

  // ------------------------------------------------------------ internals ---

  AuthorRecord _record({
    required String id,
    required String typeId,
    required String title,
    required Map<String, Object?> fields,
    required DateTime now,
    List<String> tags = const [],
  }) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        templateId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: projectId,
        projectId: projectId,
        canonStatus: CanonStatus.draft,
        title: title,
        fields: fields,
        tags: tags,
        createdAt: now,
        updatedAt: now,
        // Map Studio records stay ordinary World-domain records; the flag only
        // records which Studio authored them.
        extensionData: const {MapFields.studioFlag: true, 'worldDomain': true},
      );

  Future<void> _place({
    required String mapId,
    required String placeId,
    required DateTime timestamp,
  }) =>
      connections.connect(
        sourceId: mapId,
        targetId: placeId,
        typeId: MapTypes.placedOn,
        timestamp: timestamp,
      );

  Future<AuthorRecord> _requireMap(String id) async {
    final record = await records.getRecord(id);
    if (record == null || !MapTypes.mapTypeIds.contains(record.typeId)) {
      throw MapStudioException('$id is not a map in $projectId.');
    }
    return record;
  }

  Future<AuthorRecord> _requirePlace(String id, Set<String> typeIds) async {
    final record = await records.getRecord(id);
    if (record == null || !typeIds.contains(record.typeId)) {
      throw MapStudioException('$id is not a Map Studio place in $projectId.');
    }
    return record;
  }

  Future<AuthorRecord> _requireMarker(String id) async {
    final record = await records.getRecord(id);
    if (record == null || record.typeId != MapTypes.marker) {
      throw MapStudioException('$id is not a marker in $projectId.');
    }
    return record;
  }

  Future<AuthorRecord> _archivePlace(
    String id,
    Set<String> typeIds,
    DateTime? timestamp,
  ) async {
    await _requirePlace(id, typeIds);
    return records.archiveRecord(id, timestamp: timestamp);
  }

  Future<List<AuthorRecord>> _placesOn(
    String mapId,
    Set<String> typeIds, {
    required bool includeArchived,
  }) async {
    await _requireMap(mapId);
    final all = await repository.recordsByProject(projectId);
    final placed = [
      for (final record in all)
        if (typeIds.contains(record.typeId) &&
            _mapIdOf(record) == mapId &&
            record.status != AuthorRecordStatus.deleted &&
            (includeArchived || record.status == AuthorRecordStatus.active))
          record,
    ];
    placed.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return placed;
  }

  Future<MapExtent> _extentOf(String mapId) async =>
      MapExtent.fromRecord(await _requireMap(mapId));

  static String _mapIdOf(AuthorRecord record) {
    final value = record.fields[MapFields.mapId];
    return value is String ? value : '';
  }

  static String _markerMapIdOf(AuthorRecord record) {
    final value = record.fields[MapFields.markerMapId];
    return value is String ? value : '';
  }

  static MapGeometry _clampGeometry(MapGeometry geometry, MapExtent extent) =>
      MapGeometry(
        kind: geometry.kind,
        points: [
          for (final point in geometry.points) point.clampTo(extent),
        ],
      );
}
