/// Map Studio Phase 2 — the visual map editor.
///
/// The Studio owns no store, no theme and no business rules. Every read and
/// write goes through [MapService], and every colour and type style resolves
/// through the Theme Engine's [StudioThemeScope] under [StudioId.map]. There are
/// no literal colours here and no locally-built `ThemeData`.
///
/// Phase 2 adds the editor over the Phase 1 canvas: place, move, zoom, pan,
/// reset, region geometry, marquee selection, a deterministic draw order and
/// inline editing. The camera is presentation state and never reaches a record;
/// every position that does is map space, produced by [MapProjection].
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'map_overlay_service.dart';
import 'map_service.dart';
import 'manuscript_export.dart' show ExportFileSaver, NativeExportFileSaver;
import 'map_presentation_service.dart';
import 'map_presentation_view.dart';
import 'map_world_service.dart';
import 'onboarding.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

/// The Map Studio workspace.
/// Where an overlay can send the author next.
///
/// Map Studio names a destination; the application shell decides what that
/// means. Keeping the shell's own section enum out of here leaves Map Studio
/// independent of the navigation surface hosting it, exactly as the other
/// Studios do with their own destination enums.
enum MapStudioDestination { characters, timeline, manuscript, world }

class MapStudioView extends StatefulWidget {
  const MapStudioView({
    super.key,
    required this.project,
    this.service,
    this.overlays,
    this.onNavigate,
    this.world,
    this.presentations,
    this.fileSaver = const NativeExportFileSaver(),
  });

  final StarterProject project;

  /// The overlay projection. Read-only, and injectable for tests exactly like
  /// [service].
  final MapOverlayService? overlays;

  /// The world-state projection. Read-only, and injectable for tests exactly
  /// like [service] and [overlays].
  final MapWorldService? world;

  /// The presentation read layer: reveal points and export metadata.
  final MapPresentationService? presentations;

  /// Where an export's bytes go. Injectable so a test can export without a
  /// file dialog.
  final ExportFileSaver fileSaver;

  /// Opens another Studio, using the shell's own navigation. Map Studio adds no
  /// routing of its own.
  final ValueChanged<MapStudioDestination>? onNavigate;

  /// An explicit service, for tests that drive the Studio against a fixture
  /// database. When absent the Studio binds to the application database.
  final MapService? service;

  @override
  State<MapStudioView> createState() => _MapStudioViewState();
}

class _MapStudioViewState extends State<MapStudioView> {
  late final MapService service;
  late final MapOverlayService overlayService;
  late final MapWorldService worldService;
  late final MapPresentationService presentationService;

  bool loading = true;
  bool busy = false;
  String? loadError;
  List<MapSummary> maps = const [];
  String? selectedMapId;
  MapCanvasData? canvas;

  /// Selection is UI state and only UI state: nothing here is ever persisted.
  final Set<MapSelection> selections = <MapSelection>{};
  MapSelection? primarySelection;

  /// The camera. Presentation state — moving it never writes a record.
  MapCamera camera = MapCamera.identity;

  MapEditorTool tool = MapEditorTool.select;
  MapPlacementKind placementKind = MapPlacementKind.location;

  /// The item whose inline editor is open, if any.
  MapSelection? inlineEditing;

  /// Phase 3 editor state. All presentation: none of it is a graph entity.
  MapTerrainBrush brush = const MapTerrainBrush(kind: MapTerrainKind.grass);
  String assetDefinitionId = MapAssetDefinition.library.first.id;
  MapAssetCategory assetCategory = MapAssetCategory.vegetation;

  /// Scenery is selected separately from story items on purpose: an asset is
  /// not a location, a region or a marker, so it never enters [selections] and
  /// never appears in a marquee.
  String? selectedAssetId;

  /// Phase 4 overlay state. All of it is view state: the projection is
  /// recomputed on load and nothing about it is ever written back.
  MapOverlayData? overlayData;
  MapOverlayFilter overlayFilter = const MapOverlayFilter();
  String? selectedOverlayId;
  bool overlaysVisible = true;
  final TextEditingController overlaySearch = TextEditingController();
  String overlayQuery = '';

  /// Phase 5 world state. A projection, recomputed on load and on every change
  /// of era: nothing here is stored, and nothing here is written back.
  MapWorldState? worldData;

  /// The era the map is standing in, or `null` for the whole story.
  int? worldMoment;

  bool worldVisible = true;
  bool bordersVisible = true;
  bool routesVisible = true;

  /// The travel question, and the answer the data supports.
  String? travelFromId;
  String? travelToId;
  MapTravelMode travelMode = MapTravelMode.foot;
  MapSeason travelSeason = MapSeason.none;
  MapTravelEstimate? travelEstimate;

  /// The last world query and what it lit up.
  MapWorldQueryResult? queryResult;
  Set<String> highlightedIds = const {};

  /// Phase 6 presentation state. All of it is how the map is shown, never what
  /// the map is: nothing here is written, and leaving the Studio discards it.
  MapPresentationTheme presentationTheme = MapPresentationTheme.studio;
  MapDecorations decorations = const MapDecorations({
    MapDecoration.legend,
    MapDecoration.scaleBar,
  });

  /// Reveal points, and the levels a reader map can stand at.
  Map<String, MapRevealPoint> revealPoints = const {};
  List<MapSpoilerLevel> spoilerLevels = const [MapSpoilerLevel.everything];
  MapSpoilerLevel spoilerLevel = MapSpoilerLevel.everything;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? MapService.forProject(widget.project.id);
    presentationService = widget.presentations ??
        MapPresentationService(
          projectId: widget.project.id,
          repository: service.repository,
        );
    worldService = widget.world ??
        MapWorldService(
          projectId: widget.project.id,
          repository: service.repository,
        );
    overlayService = widget.overlays ??
        MapOverlayService(
          projectId: widget.project.id,
          repository: service.repository,
        );
    _load();
  }

  @override
  void dispose() {
    overlaySearch.dispose();
    super.dispose();
  }

  MapSummary? get selectedMap =>
      maps.where((map) => map.id == selectedMapId).firstOrNull;

  /// The single selected item, or `null` when none or many are selected.
  MapSelection? get selection =>
      selections.length == 1 ? selections.first : null;

  MapExtent get extent => selectedMap?.extent ?? MapExtent.standard;

  Future<void> _load({String? focusMapId}) async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final loaded = await service.listMaps();
      final wanted = focusMapId ?? selectedMapId;
      final active = loaded.any((map) => map.id == wanted)
          ? wanted
          : (loaded.isEmpty ? null : loaded.first.id);
      final data = active == null ? null : await service.loadCanvas(active);
      final overlays =
          active == null ? null : await overlayService.loadOverlays(active);
      final world = active == null
          ? null
          : await worldService.loadWorldState(active, moment: worldMoment);
      final reveals =
          active == null ? const <String, MapRevealPoint>{} : await presentationService.revealPoints();
      final levels = active == null
          ? const <MapSpoilerLevel>[MapSpoilerLevel.everything]
          : await presentationService.spoilerLevels();
      if (!mounted) return;
      setState(() {
        maps = loaded;
        selectedMapId = active;
        canvas = data;
        overlayData = overlays;
        worldData = world;
        revealPoints = reveals;
        spoilerLevels = levels;
        if (!levels.contains(spoilerLevel)) {
          spoilerLevel = MapSpoilerLevel.everything;
        }
        travelEstimate = null;
        queryResult = null;
        highlightedIds = const {};
        if (selectedOverlayId != null &&
            !(overlays?.items.any((item) => item.id == selectedOverlayId) ??
                false)) {
          selectedOverlayId = null;
        }
        selections.removeWhere((value) => !_stillPresent(data, value));
        if (primarySelection != null &&
            !selections.contains(primarySelection)) {
          primarySelection = selections.isEmpty ? null : selections.last;
        }
        if (inlineEditing != null && !selections.contains(inlineEditing)) {
          inlineEditing = null;
        }
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = '$error';
        loading = false;
      });
    }
  }

  bool _stillPresent(MapCanvasData? data, MapSelection value) =>
      data != null && data.contains(value);

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  // ------------------------------------------------------------ selection ---

  void _select(MapSelection value, {bool toggle = true}) {
    setState(() {
      if (toggle && selections.length == 1 && selections.contains(value)) {
        selections.clear();
        primarySelection = null;
        inlineEditing = null;
        return;
      }
      selections
        ..clear()
        ..add(value);
      primarySelection = value;
      if (inlineEditing != value) inlineEditing = null;
    });
  }

  void _replaceSelection(List<MapSelection> values) {
    setState(() {
      selections
        ..clear()
        ..addAll(values);
      primarySelection = values.isEmpty ? null : values.last;
      inlineEditing = null;
    });
  }

  void _clearSelection() => _replaceSelection(const []);

  // --------------------------------------------------------------- camera ---

  void _zoomIn() => setState(
        () => camera = camera.zoomedAroundCentre(MapCamera.zoomStep, extent),
      );

  void _zoomOut() => setState(
        () => camera = camera.zoomedAroundCentre(1 / MapCamera.zoomStep, extent),
      );

  /// Restores the map's normal starting view. Touches no record.
  void _resetView() => setState(() => camera = MapCamera.identity);

  void _onCameraChanged(MapCamera value) => setState(() => camera = value);

  void _selectTool(MapEditorTool value) => setState(() {
        tool = value;
        inlineEditing = null;
      });

  // -------------------------------------------------------------- authoring -

  Future<void> _createMap() async {
    final draft = await showDialog<_TextDraft>(
      context: context,
      builder: (context) => const _DetailsDialog(
        title: 'Create Map',
        nameLabel: 'Title',
        keyPrefix: 'map-create',
        confirmLabel: 'Create',
      ),
    );
    if (draft == null) return;
    await _runBusy(() async {
      final created = await service.createMap(
        MapDraft(
          id: _id('map'),
          title: draft.name,
          description: draft.description,
        ),
      );
      camera = MapCamera.identity;
      await _load(focusMapId: created.id);
    });
  }

  Future<void> _editMapMetadata() async {
    final map = selectedMap;
    if (map == null) return;
    final draft = await showDialog<_TextDraft>(
      context: context,
      builder: (context) => _DetailsDialog(
        title: 'Map Settings',
        nameLabel: 'Title',
        keyPrefix: 'map-settings',
        confirmLabel: 'Save',
        initialName: map.title,
        initialDescription: map.description,
      ),
    );
    if (draft == null) return;
    await _runBusy(() async {
      await service.updateMap(
        map.id,
        title: draft.name,
        description: draft.description,
      );
      await _load();
    });
  }

  Future<void> _archiveMap() async {
    final map = selectedMap;
    if (map == null) return;
    await _runBusy(() async {
      await service.archiveMap(map.id);
      selections.clear();
      primarySelection = null;
      camera = MapCamera.identity;
      await _load(focusMapId: null);
    });
  }

  Future<void> _addLocation() async {
    final map = selectedMap;
    if (map == null) return;
    final draft = await showDialog<_TextDraft>(
      context: context,
      builder: (context) => const _DetailsDialog(
        title: 'Add Location',
        nameLabel: 'Name',
        keyPrefix: 'location-create',
        confirmLabel: 'Save',
        showCategory: true,
        categoryLabel: 'Type',
      ),
    );
    if (draft == null) return;
    await _runBusy(() async {
      final created = await service.createLocation(
        MapLocationDraft(
          id: _id('location'),
          mapId: map.id,
          name: draft.name,
          description: draft.description,
          locationType: draft.category,
          position: _nextPosition(map, canvas?.locations.length ?? 0),
        ),
      );
      _stageSelection(
        MapSelection(kind: MapSelectionKind.location, id: created.id),
      );
      await _load();
    });
  }

  Future<void> _addRegion() async {
    final map = selectedMap;
    if (map == null) return;
    final draft = await showDialog<_TextDraft>(
      context: context,
      builder: (context) => const _DetailsDialog(
        title: 'Add Region',
        nameLabel: 'Name',
        keyPrefix: 'region-create',
        confirmLabel: 'Save',
        showCategory: true,
        categoryLabel: 'Category',
      ),
    );
    if (draft == null) return;
    await _runBusy(() async {
      final extent = map.extent;
      final created = await service.createRegion(
        MapRegionDraft(
          id: _id('region'),
          mapId: map.id,
          name: draft.name,
          description: draft.description,
          category: draft.category,
          geometry: MapGeometry.box(
            MapPosition(extent.width * 0.2, extent.height * 0.2),
            MapPosition(extent.width * 0.6, extent.height * 0.6),
          ),
        ),
      );
      _stageSelection(
        MapSelection(kind: MapSelectionKind.region, id: created.id),
      );
      await _load();
    });
  }

  Future<void> _addMarker() async {
    final map = selectedMap;
    if (map == null) return;
    final draft = await showDialog<_TextDraft>(
      context: context,
      builder: (context) => const _DetailsDialog(
        title: 'Add Marker',
        nameLabel: 'Label',
        keyPrefix: 'marker-create',
        confirmLabel: 'Save',
        descriptionLabel: 'Notes',
        showCategory: true,
        categoryLabel: 'Marker type',
      ),
    );
    if (draft == null) return;
    await _runBusy(() async {
      final created = await service.createMarker(
        MapMarkerDraft(
          id: _id('marker'),
          mapId: map.id,
          label: draft.name,
          notes: draft.description,
          category: draft.category,
          position: _nextPosition(map, (canvas?.markers.length ?? 0) + 3),
        ),
      );
      _stageSelection(
        MapSelection(kind: MapSelectionKind.marker, id: created.id),
      );
      await _load();
    });
  }

  /// Selects a freshly written record. Called inside `_runBusy`, so the reload
  /// that follows is what actually paints it.
  void _stageSelection(MapSelection value) {
    selections
      ..clear()
      ..add(value);
    primarySelection = value;
  }

  /// Spreads dialog-authored pins across the map rather than stacking them.
  ///
  /// The editor places by pointer; this is only for the "Add …" dialogs, which
  /// have no pointer position to work from.
  MapPosition _nextPosition(MapSummary map, int index) {
    final extent = map.extent;
    final column = index % 4;
    final row = (index ~/ 4) % 4;
    return MapPosition(
      extent.width * (0.2 + column * 0.2),
      extent.height * (0.2 + row * 0.2),
    );
  }

  // ------------------------------------------------------- editor actions ---

  /// Places a new location or marker at a map-space position.
  ///
  /// The pointer's pixels were converted by [MapProjection] before they got
  /// here; what reaches the service is map space and nothing else.
  Future<void> _placeAt(MapPosition position, MapPlacementKind kind) async {
    final map = selectedMap;
    if (map == null) return;
    await _runBusy(() async {
      switch (kind) {
        case MapPlacementKind.location:
          final created = await service.createLocation(
            MapLocationDraft(
              id: _id('location'),
              mapId: map.id,
              name: 'New Location',
              position: position,
            ),
          );
          _stageSelection(
            MapSelection(kind: MapSelectionKind.location, id: created.id),
          );
        case MapPlacementKind.marker:
          final created = await service.createMarker(
            MapMarkerDraft(
              id: _id('marker'),
              mapId: map.id,
              label: 'New Marker',
              position: position,
            ),
          );
          _stageSelection(
            MapSelection(kind: MapSelectionKind.marker, id: created.id),
          );
      }
      await _load();
      if (mounted) setState(() => inlineEditing = primarySelection);
    });
  }

  /// Persists the end of a drag. The record keeps its id; only its map-space
  /// position changes, and its links are untouched.
  Future<void> _moveItem(MapSelection item, MapPosition position) =>
      _runBusy(() async {
        switch (item.kind) {
          case MapSelectionKind.location:
            await service.moveLocation(item.id, position);
          case MapSelectionKind.marker:
            await service.moveMarker(item.id, position);
          case MapSelectionKind.region:
            await service.moveRegion(item.id, position);
        }
        await _load();
      });

  Future<void> _drawRegion(MapRect rect) async {
    final map = selectedMap;
    if (map == null) return;
    await _runBusy(() async {
      final created = await service.createRegion(
        MapRegionDraft(
          id: _id('region'),
          mapId: map.id,
          name: 'New Region',
          geometry: MapGeometry.box(rect.topLeft, rect.bottomRight),
        ),
      );
      _stageSelection(
        MapSelection(kind: MapSelectionKind.region, id: created.id),
      );
      await _load();
    });
  }

  Future<void> _moveGeometryPoint(
    String regionId,
    int index,
    MapPosition position,
  ) =>
      _runBusy(() async {
        await service.moveRegionPoint(regionId, index, position);
        await _load();
      });

  Future<void> _reshapeRegion(MapGeometryKind kind) async {
    final region = _selectedRegion;
    if (region == null) return;
    await _runBusy(() async {
      await service.reshapeRegion(region.id, kind);
      await _load();
    });
  }

  Future<void> _addGeometryPoint() async {
    final region = _selectedRegion;
    if (region == null) return;
    final geometry = region.geometry;
    final points = geometry.points;
    if (points.isEmpty) return;
    // A new point half way along the last edge: predictable, and always inside
    // the shape the writer can already see.
    final a = points[points.length - 1];
    final b = points.first;
    await _runBusy(() async {
      await service.addRegionPoint(
        region.id,
        MapPosition((a.x + b.x) / 2, (a.y + b.y) / 2),
      );
      await _load();
    });
  }

  Future<void> _removeGeometryPoint() async {
    final region = _selectedRegion;
    if (region == null) return;
    if (region.geometry.points.isEmpty) return;
    await _runBusy(() async {
      await service.removeRegionPoint(
        region.id,
        region.geometry.points.length - 1,
      );
      await _load();
    });
  }

  MapRegionView? get _selectedRegion {
    final current = selection;
    if (current == null || current.kind != MapSelectionKind.region) return null;
    return canvas?.regionById(current.id);
  }

  // -------------------------------------------------- terrain and scenery ---

  Future<void> _paintStroke(List<MapPosition> positions) async {
    final map = selectedMap;
    if (map == null || positions.isEmpty) return;
    await _runBusy(() async {
      await service.paintTerrainStroke(map.id, brush, positions);
      await _load();
    });
  }

  Future<void> _fillTerrain(MapTerrainKind kind) async {
    final map = selectedMap;
    if (map == null) return;
    await _runBusy(() async {
      await service.fillTerrain(map.id, kind);
      await _load();
    });
  }

  Future<void> _clearTerrain() async {
    final map = selectedMap;
    if (map == null) return;
    await _runBusy(() async {
      await service.clearTerrain(map.id);
      await _load();
    });
  }

  Future<void> _setStyle(MapVisualStyle style) async {
    final map = selectedMap;
    if (map == null) return;
    await _runBusy(() async {
      await service.setVisualStyle(map.id, style);
      await _load();
    });
  }

  Future<void> _placeAsset(MapPosition position) async {
    final map = selectedMap;
    if (map == null) return;
    final id = _id('asset');
    await _runBusy(() async {
      await service.addAsset(
        map.id,
        MapAssetInstance(
          id: id,
          definitionId: assetDefinitionId,
          position: position,
          scale: MapAssetDefinition.byId(assetDefinitionId)?.defaultScale ?? 1,
          layer: map.assets.length,
        ),
      );
      await _load();
      if (mounted) setState(() => selectedAssetId = id);
    });
  }

  Future<void> _moveAsset(String assetId, MapPosition position) async {
    final map = selectedMap;
    if (map == null) return;
    await _runBusy(() async {
      await service.moveAsset(map.id, assetId, position);
      await _load();
    });
  }

  Future<void> _transformAsset({
    double? rotation,
    double? scale,
    int? layer,
  }) async {
    final map = selectedMap;
    final assetId = selectedAssetId;
    if (map == null || assetId == null) return;
    await _runBusy(() async {
      await service.transformAsset(
        map.id,
        assetId,
        rotation: rotation,
        scale: scale,
        layer: layer,
      );
      await _load();
    });
  }

  Future<void> _removeAsset() async {
    final map = selectedMap;
    final assetId = selectedAssetId;
    if (map == null || assetId == null) return;
    await _runBusy(() async {
      await service.removeAsset(map.id, assetId);
      if (mounted) selectedAssetId = null;
      await _load();
    });
  }

  MapAssetInstance? get _selectedAsset {
    final id = selectedAssetId;
    if (id == null) return null;
    return selectedMap?.assets.where((asset) => asset.id == id).firstOrNull;
  }

  // --------------------------------------------------------- story overlays -
  //
  // Every action here changes what is drawn. None of them writes: the overlay
  // layer reads canonical data and shows it, and a filter is a question about
  // the view, never a change to the story.

  MapOverlayItem? get selectedOverlay {
    final id = selectedOverlayId;
    final data = overlayData;
    if (id == null || data == null) return null;
    return data.items.where((item) => item.id == id).firstOrNull;
  }

  void _toggleOverlayKind(MapOverlayKind kind) => setState(
        () => overlayFilter = overlayFilter.toggling(kind),
      );

  void _selectOverlay(String? id) => setState(() => selectedOverlayId = id);

  void _toggleJourney(String characterId) => setState(
        () => overlayFilter = overlayFilter.togglingJourney(characterId),
      );

  /// Moves the story clock. `null` means the whole story.
  void _setMoment(int? sortKey) => setState(() {
        overlayFilter = sortKey == null
            ? overlayFilter.copyWith(clearMoment: true)
            : overlayFilter.copyWith(moment: sortKey);
      });

  void _stepMoment(int direction) {
    final data = overlayData;
    if (data == null || data.moments.isEmpty) return;
    final keys = [for (final moment in data.moments) moment.sortKey];
    final current = overlayFilter.moment;
    if (current == null) {
      // Entering the clock from the whole story starts at the beginning of the
      // story, whichever way the author stepped.
      _setMoment(keys.first);
      return;
    }
    final index = keys.indexOf(current);
    final next = (index < 0 ? 0 : index) + direction;
    if (next < 0 || next >= keys.length) return;
    _setMoment(keys[next]);
  }

  /// Story moment mode: stand at one point in the story and hide the rest.
  void _enterStoryMoment() {
    final data = overlayData;
    if (data == null || data.moments.isEmpty) return;
    setState(() {
      overlayFilter = overlayFilter.copyWith(
        moment: overlayFilter.moment ?? data.moments.first.sortKey,
        showPast: false,
        showFuture: false,
      );
    });
  }

  void _showWholeStory() => setState(() {
        overlayFilter = overlayFilter.copyWith(
          clearMoment: true,
          showPast: true,
          showFuture: true,
        );
      });

  /// Finds an entity, centres the map on it and selects it.
  ///
  /// An entity with no mapped position is reported as exactly that. The map
  /// never invents coordinates to make a search result land somewhere.
  void _focusOverlay(MapOverlayItem item) {
    setState(() {
      selectedOverlayId = item.id;
      final extent = selectedMap?.extent ?? MapExtent.standard;
      // Focusing means going there, so it closes in as well as centres: at the
      // default scale the whole map is already in frame and centring alone
      // would move nothing. Nothing here reaches a record — the camera is
      // presentation state and stays that way.
      final scale = camera.scale < _focusScale
          ? _focusScale
          : camera.scale;
      camera = MapCamera(
        scale: scale,
        offset: MapPosition(
          item.position.x - extent.width / (2 * scale),
          item.position.y - extent.height / (2 * scale),
        ),
      ).clampedTo(extent);
    });
  }

  /// How close the map comes when the author focuses something.
  static const _focusScale = 2.0;

  /// Hands the author to the Studio that owns the entity behind an overlay.
  void _openOwningStudio(MapOverlayItem item) {
    final navigate = widget.onNavigate;
    if (navigate == null) return;
    navigate(switch (item.kind) {
      MapOverlayKind.character => MapStudioDestination.characters,
      MapOverlayKind.event => MapStudioDestination.timeline,
      MapOverlayKind.scene => MapStudioDestination.manuscript,
      MapOverlayKind.location => MapStudioDestination.world,
    });
  }

  // ---------------------------------------------------------- world state ---
  //
  // Every action here changes which world the map is showing. None of them
  // writes: the world state is a reading of canonical records and links, and
  // asking to see the year 412 is a question, not an edit.

  /// Re-reads the world at [moment], where `null` means the whole story.
  Future<void> _setEra(int? moment) async {
    final mapId = selectedMapId;
    if (mapId == null) return;
    setState(() => worldMoment = moment);
    final state = await worldService.loadWorldState(mapId, moment: moment);
    if (!mounted) return;
    setState(() {
      worldData = state;
      // The old answer belonged to the old world.
      travelEstimate = null;
      queryResult = null;
      highlightedIds = const {};
    });
  }

  void _stepEra(int direction) {
    final state = worldData;
    if (state == null || state.moments.isEmpty) return;
    final keys = [for (final moment in state.moments) moment.sortKey];
    final current = worldMoment;
    if (current == null) {
      _setEra(keys.first);
      return;
    }
    final index = keys.indexOf(current);
    final next = (index < 0 ? 0 : index) + direction;
    if (next < 0 || next >= keys.length) return;
    _setEra(keys[next]);
  }

  /// Answers the travel question, or reports why it cannot be answered.
  void _calculateTravel() {
    final state = worldData;
    final from = travelFromId;
    final to = travelToId;
    if (state == null || from == null || to == null) return;
    final terrain = canvas?.map.terrain;
    final extent = selectedMap?.extent ?? MapExtent.standard;
    setState(() {
      travelEstimate = state.travelBetween(
        from,
        to,
        mode: travelMode,
        season: travelSeason,
        // Terrain is read from the painted map where there is any: the ground
        // the author painted is the ground the traveller crosses.
        terrainAt: terrain == null || terrain.isEmpty
            ? null
            : (position) {
                final cell = terrain.cellFor(position, extent);
                if (cell == null) return '';
                return terrain.kindAt(cell.$1, cell.$2)?.name ?? '';
              },
      );
      final estimate = travelEstimate!;
      highlightedIds = {
        for (final leg in estimate.legs) leg.route.id,
      };
    });
  }

  Future<void> _runQuery(MapWorldQueryKind kind, String subjectId) async {
    final mapId = selectedMapId;
    if (mapId == null) return;
    final result = switch (kind) {
      MapWorldQueryKind.controlledBy =>
        await worldService.controlledBy(mapId, subjectId, moment: worldMoment),
      MapWorldQueryKind.visitedBy => await worldService.visitedBy(
          mapId,
          subjectId,
        ),
      MapWorldQueryKind.scenesIn => await worldService.scenesIn(
          mapId,
          subjectId,
        ),
      MapWorldQueryKind.affectedBy => await worldService.affectedBy(
          mapId,
          subjectId,
        ),
      MapWorldQueryKind.routesBetween || MapWorldQueryKind.worldAt =>
        await worldService.controlledBy(mapId, subjectId, moment: worldMoment),
    };
    if (!mounted) return;
    setState(() {
      queryResult = result;
      highlightedIds = result.highlightedIds.toSet();
    });
  }

  void _clearQuery() => setState(() {
        queryResult = null;
        highlightedIds = const {};
      });

  // ---------------------------------------------------------- presentation ---
  //
  // Phase 6 is a projection of everything above it. It reads the canvas, the
  // overlays and the world state, applies a theme, a set of decorations and a
  // reader level, and paints or writes the result. It changes no record.

  /// The colours an export uses, resolved from the Theme Engine.
  ///
  /// The drawing model carries plain integers so it can live outside Flutter;
  /// this is the one place that turns engine tokens into them, so an exported
  /// map is coloured by the same theme as the map on screen.
  MapDrawPalette _drawPalette(_MapPalette palette, MapVisualStyle style) =>
      MapDrawPalette(
        background: palette.surfaceContainer.toARGB32(),
        surface: palette.canvasSurface.toARGB32(),
        ink: palette.onSurface.toARGB32(),
        muted: palette.onSurfaceVariant.toARGB32(),
        outline: palette.outline.toARGB32(),
        accent: palette.primary.toARGB32(),
        regionFill: palette.regionFill.toARGB32(),
        terrain: {
          for (final kind in MapTerrainKind.values)
            kind: palette.terrainColor(kind, style).toARGB32(),
        },
      );

  /// What a reader at the current level is allowed to see.
  ///
  /// At [MapSpoilerLevel.everything] this is the author's own map, unfiltered.
  MapReaderView _readerView(MapCanvasData data) => MapReaderProjection.apply(
        level: spoilerLevel,
        canvas: data,
        overlays: overlayData,
        world: worldData,
        revealed: revealPoints,
      );

  Future<MapExportRequest?> _exportRequest(_MapPalette palette) async {
    final data = canvas;
    final map = selectedMap;
    if (data == null || map == null) return null;
    final metadata = await presentationService.metadataFor(
      map,
      projectTitle: widget.project.title,
      eraLabel: worldData?.moment?.label ?? '',
    );
    final view = _readerView(data);
    final style = presentationTheme.styleFor(map.visualStyle);
    return MapExportRequest(
      presentation: MapPresentation(
        metadata: metadata,
        theme: presentationTheme,
        decorations: decorations,
        credit: metadata.authorName.isEmpty ? '' : '© ${metadata.authorName}',
        scaleBar: presentationService.scaleBarFor(map),
      ),
      canvas: view.canvas,
      overlays: view.overlays,
      world: view.world,
      palette: _drawPalette(palette, style),
      preset: MapExportPreset.screen,
      format: MapExportFormat.png,
    );
  }

  Future<void> _present(_MapPalette palette) async {
    final request = await _exportRequest(palette);
    if (request == null || !mounted) return;
    final drawing = const MapDrawingBuilder().build(request);
    final data = canvas;
    final view = data == null ? null : _readerView(data);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MapPresentationPage(
          drawing: drawing,
          title: request.presentation.title,
          background: palette.surfaceContainer,
          semanticsLabel: _presentationSummary(request),
          notice: view == null || spoilerLevel.isEverything ? '' : view.notice,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// What a screen reader is told the map shows.
  ///
  /// A map is a picture, and a picture with no description is nothing at all to
  /// a reader who cannot see it — so the description names the map, the era and
  /// what is actually on it.
  String _presentationSummary(MapExportRequest request) {
    final parts = <String>[
      request.presentation.title,
      if (request.presentation.metadata.eraLabel.isNotEmpty)
        request.presentation.metadata.eraLabel,
      '${request.canvas.locations.length} places',
      if (request.canvas.regions.isNotEmpty)
        '${request.canvas.regions.length} regions',
      if ((request.world?.routes.length ?? 0) > 0)
        '${request.world!.routes.length} routes',
      if ((request.overlays?.items.length ?? 0) > 0)
        '${request.overlays!.items.length} story overlays',
    ];
    return parts.join(', ');
  }

  Future<void> _export(_MapPalette palette) async {
    final request = await _exportRequest(palette);
    if (request == null || !mounted) return;
    final drawing = const MapDrawingBuilder().build(request);
    await showDialog<void>(
      context: context,
      builder: (context) => MapExportDialog(
        drawing: drawing,
        request: request,
        saver: widget.fileSaver,
      ),
    );
  }

  // ------------------------------------------------------- inline editing ---

  void _openInlineEditor(MapSelection value) => setState(() {
        selections
          ..clear()
          ..add(value);
        primarySelection = value;
        inlineEditing = value;
      });

  void _closeInlineEditor() => setState(() => inlineEditing = null);

  Future<void> _submitInlineEdit(
    MapSelection item,
    String name,
    String category,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() => inlineEditing = null);
    await _runBusy(() async {
      switch (item.kind) {
        case MapSelectionKind.location:
          await service.updateLocation(
            item.id,
            name: trimmed,
            locationType: category,
          );
        case MapSelectionKind.marker:
          await service.updateMarker(
            item.id,
            label: trimmed,
            category: category,
          );
        case MapSelectionKind.region:
          await service.updateRegion(
            item.id,
            name: trimmed,
            category: category,
          );
      }
      await _load();
    });
  }

  // ----------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    if (scope == null) return _buildStudio(context);
    // Layer this Studio's overrides on the shell theme; the engine and its
    // tokens stay the single source of truth.
    return StudioThemeScope(
      theme: scope.theme,
      studio: StudioId.map,
      child: Builder(builder: _buildStudio),
    );
  }

  Widget _buildStudio(BuildContext context) {
    final palette = _MapPalette.of(context);
    if (loading) {
      return Column(
        key: const Key('map-loading'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, palette),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 96),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    if (loadError != null) {
      return Column(
        key: const Key('map-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, palette),
          const SizedBox(height: 16),
          _Panel(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Map Studio could not load.', style: palette.ui),
                const SizedBox(height: 8),
                Text(loadError!, style: palette.body),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _load(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (maps.isEmpty) {
      return Column(
        key: const Key('map-studio'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, palette),
          const SizedBox(height: 16),
          _MapEmptyState(palette: palette, onCreate: busy ? null : _createMap),
        ],
      );
    }
    return FocusTraversalGroup(
      child: Column(
        key: const Key('map-studio'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, palette),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final selector = _MapSelector(
                palette: palette,
                maps: maps,
                selectedId: selectedMapId,
                onSelected: busy
                    ? null
                    : (id) {
                        selections.clear();
                        primarySelection = null;
                        inlineEditing = null;
                        camera = MapCamera.identity;
                        _load(focusMapId: id);
                      },
              );
              final workspace = _buildWorkspace(context, palette);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 240, child: selector),
                    const SizedBox(width: 16),
                    Expanded(child: workspace),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  selector,
                  const SizedBox(height: 16),
                  workspace,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace(BuildContext context, _MapPalette palette) {
    final data = canvas;
    if (data == null) {
      return _Panel(
        palette: palette,
        child: Text('Select a map to begin.', style: palette.body),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(context, palette),
        if (tool == MapEditorTool.region) ...[
          const SizedBox(height: 8),
          _buildRegionTools(palette),
        ],
        if (tool == MapEditorTool.terrain) ...[
          const SizedBox(height: 8),
          _buildTerrainTools(palette),
        ],
        if (tool == MapEditorTool.asset) ...[
          const SizedBox(height: 8),
          _buildAssetTools(palette),
        ],
        const SizedBox(height: 12),
        _MapCanvas(
          data: data,
          palette: palette,
          camera: camera,
          tool: tool,
          placementKind: placementKind,
          selections: selections,
          primarySelection: primarySelection,
          inlineEditing: inlineEditing,
          interactive: !busy,
          onSelected: _select,
          onSelectionReplaced: _replaceSelection,
          onSelectionCleared: _clearSelection,
          onCameraChanged: _onCameraChanged,
          onPlace: _placeAt,
          onMoveItem: _moveItem,
          onRegionDrawn: _drawRegion,
          onGeometryPointMoved: _moveGeometryPoint,
          onInlineEditRequested: _openInlineEditor,
          onInlineEditSubmitted: _submitInlineEdit,
          onInlineEditCancelled: _closeInlineEditor,
          onPaintStroke: _paintStroke,
          onPlaceAsset: _placeAsset,
          onMoveAsset: _moveAsset,
          onAssetSelected: (id) => setState(() => selectedAssetId = id),
          brush: brush,
          selectedAssetId: selectedAssetId,
          overlayData: overlayData,
          overlayFilter: overlayFilter,
          selectedOverlayId: selectedOverlayId,
          overlaysVisible: overlaysVisible,
          onOverlaySelected: _selectOverlay,
          worldData: worldData,
          worldVisible: worldVisible,
          bordersVisible: bordersVisible,
          routesVisible: routesVisible,
          highlightedIds: highlightedIds,
        ),
        if (data.map.visualStyle.showLegend && data.map.legend.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MapLegend(
            palette: palette,
            entries: data.map.legend,
            style: data.map.visualStyle,
          ),
        ],
        const SizedBox(height: 12),
        _buildPresentationPanel(palette),
        if (worldData != null) ...[
          const SizedBox(height: 12),
          _buildWorldPanel(palette, worldData!),
        ],
        if (overlayData != null) ...[
          const SizedBox(height: 12),
          _buildOverlayPanel(palette, overlayData!),
          const SizedBox(height: 12),
          _OverlayLegend(palette: palette, filter: overlayFilter),
          if (selectedOverlay != null) ...[
            const SizedBox(height: 12),
            _OverlayDetail(
              palette: palette,
              item: selectedOverlay!,
              onFocus: () => _focusOverlay(selectedOverlay!),
              onOpen: widget.onNavigate == null
                  ? null
                  : () => _openOwningStudio(selectedOverlay!),
              onClear: () => _selectOverlay(null),
            ),
          ],
        ],
        const SizedBox(height: 12),
        _SelectionDetail(
          palette: palette,
          data: data,
          selection: selection,
          selectionCount: selections.length,
          onEdit: busy ? null : _openInlineEditor,
        ),
      ],
    );
  }

  /// The Phase 6 presentation controls.
  ///
  /// Theme, decorations, reader level, and the two things an author actually
  /// wants: show me the map, and give me a file.
  Widget _buildPresentationPanel(_MapPalette palette) {
    final data = canvas;
    final view = data == null ? null : _readerView(data);
    return _Panel(
      key: const Key('map-presentation-panel'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Presentation',
                  style: palette.ui.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('map-present-button'),
                onPressed: busy ? null : () => _present(palette),
                icon: const Icon(Icons.slideshow_outlined),
                label: const Text('Present'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('map-export-button'),
                onPressed: busy ? null : () => _export(palette),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Export'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Theme', style: palette.label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in MapPresentationTheme.values)
                _ToolButton(
                  key: Key('map-theme-${theme.name}'),
                  palette: palette,
                  icon: Icons.palette_outlined,
                  label: theme.label,
                  selected: presentationTheme == theme,
                  onPressed: () => setState(() {
                    presentationTheme = theme;
                    decorations = MapDecorations({...theme.decorations});
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Decorations', style: palette.label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final decoration in MapDecoration.values)
                _ToolButton(
                  key: Key('map-decoration-${decoration.name}'),
                  palette: palette,
                  icon: Icons.check_box_outlined,
                  label: decoration.label,
                  selected: decorations.has(decoration),
                  onPressed: () => setState(
                    () => decorations = decorations.toggling(decoration),
                  ),
                ),
            ],
          ),
          if (spoilerLevels.length > 1) ...[
            const SizedBox(height: 12),
            Text('Reader map', style: palette.label),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final level in spoilerLevels)
                  _ToolButton(
                    key: Key('map-spoiler-${level.label.hashCode}'),
                    palette: palette,
                    icon: level.isEverything
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    label: level.label,
                    selected: spoilerLevel.label == level.label,
                    onPressed: () => setState(() => spoilerLevel = level),
                  ),
              ],
            ),
            if (view != null && !spoilerLevel.isEverything) ...[
              const SizedBox(height: 8),
              Text(
                view.notice,
                key: const Key('map-reader-notice'),
                style: palette.body,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// The Phase 5 world controls: era, world state, simulation and queries.
  ///
  /// Optional by construction. An author who only wants to draw a map never has
  /// to touch any of it, and a map with no world data shows the panel with
  /// nothing in it rather than inventing something to show.
  Widget _buildWorldPanel(_MapPalette palette, MapWorldState state) {
    return _Panel(
      key: const Key('map-world-panel'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'World',
                  style: palette.ui.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                state.kind.label,
                key: const Key('map-world-state-kind'),
                style: palette.label,
              ),
              const SizedBox(width: 8),
              _ToolButton(
                key: const Key('map-world-toggle'),
                palette: palette,
                icon: worldVisible
                    ? Icons.public_outlined
                    : Icons.public_off_outlined,
                label: worldVisible ? 'Hide world' : 'Show world',
                selected: worldVisible,
                onPressed: () => setState(() => worldVisible = !worldVisible),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildEraControl(palette, state),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            key: const Key('map-world-summary'),
            children: [
              _WorldCount(
                palette: palette,
                label: 'Settlements',
                value: state.settlements.length,
              ),
              _WorldCount(
                palette: palette,
                label: 'Territories',
                value: state.territories.length,
              ),
              _WorldCount(
                palette: palette,
                label: 'Borders',
                value: state.borders.length,
              ),
              _WorldCount(
                palette: palette,
                label: 'Routes',
                value: state.routes.length,
              ),
              _WorldCount(
                palette: palette,
                label: 'Resources',
                value: state.resources.length,
              ),
              _WorldCount(
                palette: palette,
                label: 'Conditions',
                value: state.conditions.length,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToolButton(
                key: const Key('map-world-borders-toggle'),
                palette: palette,
                icon: Icons.timeline_outlined,
                label: 'Borders',
                selected: bordersVisible,
                onPressed: () =>
                    setState(() => bordersVisible = !bordersVisible),
              ),
              _ToolButton(
                key: const Key('map-world-routes-toggle'),
                palette: palette,
                icon: Icons.alt_route_outlined,
                label: 'Routes',
                selected: routesVisible,
                onPressed: () => setState(() => routesVisible = !routesVisible),
              ),
            ],
          ),
          if (state.routes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildTravelControl(palette, state),
          ],
          if (state.factions.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildQueryControl(palette, state),
          ],
          if (queryResult != null) ...[
            const SizedBox(height: 10),
            _buildQueryResult(palette, queryResult!),
          ],
        ],
      ),
    );
  }

  /// The era scrubber: which point in the story the world is read at.
  Widget _buildEraControl(_MapPalette palette, MapWorldState state) {
    final keys = [for (final moment in state.moments) moment.sortKey];
    final index = worldMoment == null ? -1 : keys.indexOf(worldMoment!);
    final label = index < 0
        ? 'The whole story'
        : state.moments[index].label;
    return Column(
      key: const Key('map-world-era'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ToolButton(
              key: const Key('map-world-era-prev'),
              palette: palette,
              icon: Icons.chevron_left,
              label: 'Earlier',
              selected: false,
              onPressed: state.moments.isEmpty ? null : () => _stepEra(-1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                key: const Key('map-world-era-label'),
                textAlign: TextAlign.center,
                style: palette.ui.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _ToolButton(
              key: const Key('map-world-era-next'),
              palette: palette,
              icon: Icons.chevron_right,
              label: 'Later',
              selected: false,
              onPressed: state.moments.isEmpty ? null : () => _stepEra(1),
            ),
          ],
        ),
        if (state.moments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Nothing on this map is dated yet, so there is one world to show.',
              key: const Key('map-world-no-eras'),
              style: palette.label,
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _ToolButton(
                key: const Key('map-world-whole-story'),
                palette: palette,
                icon: Icons.all_inclusive_outlined,
                label: 'Whole story',
                selected: worldMoment == null,
                onPressed: () => _setEra(null),
              ),
            ),
          ),
      ],
    );
  }

  /// The travel calculator.
  ///
  /// It answers only where the author's own data supports an answer; where it
  /// does not, it says which data is missing instead of producing a number.
  Widget _buildTravelControl(_MapPalette palette, MapWorldState state) {
    final places = [...state.settlements]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final estimate = travelEstimate;
    return Column(
      key: const Key('map-world-travel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Travel',
            style: palette.ui.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              key: const Key('map-world-travel-from'),
              value: travelFromId,
              hint: Text('From', style: palette.label),
              items: [
                for (final place in places)
                  DropdownMenuItem(value: place.id, child: Text(place.name)),
              ],
              onChanged: (value) => setState(() => travelFromId = value),
            ),
            DropdownButton<String>(
              key: const Key('map-world-travel-to'),
              value: travelToId,
              hint: Text('To', style: palette.label),
              items: [
                for (final place in places)
                  DropdownMenuItem(value: place.id, child: Text(place.name)),
              ],
              onChanged: (value) => setState(() => travelToId = value),
            ),
            DropdownButton<MapTravelMode>(
              key: const Key('map-world-travel-mode'),
              value: travelMode,
              items: [
                for (final mode in MapTravelMode.values)
                  DropdownMenuItem(value: mode, child: Text(mode.label)),
              ],
              onChanged: (value) =>
                  setState(() => travelMode = value ?? travelMode),
            ),
            DropdownButton<MapSeason>(
              key: const Key('map-world-travel-season'),
              value: travelSeason,
              items: [
                for (final season in MapSeason.values)
                  DropdownMenuItem(value: season, child: Text(season.label)),
              ],
              onChanged: (value) =>
                  setState(() => travelSeason = value ?? travelSeason),
            ),
            FilledButton.icon(
              key: const Key('map-world-travel-button'),
              onPressed: travelFromId == null || travelToId == null
                  ? null
                  : _calculateTravel,
              icon: const Icon(Icons.directions_outlined),
              label: const Text('How long?'),
            ),
          ],
        ),
        if (estimate != null) ...[
          const SizedBox(height: 8),
          Text(
            estimate.summary,
            key: const Key('map-world-travel-result'),
            style: palette.ui.copyWith(
              fontWeight: estimate.isAvailable ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          for (var index = 0; index < estimate.explanation.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                estimate.explanation[index],
                key: Key('map-world-travel-line-$index'),
                style: palette.label,
              ),
            ),
        ],
      ],
    );
  }

  /// The world queries: what a faction holds, at the selected era.
  Widget _buildQueryControl(_MapPalette palette, MapWorldState state) {
    final factions = state.factions.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return Column(
      key: const Key('map-world-query'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ask the map',
            style: palette.ui.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final faction in factions)
              _ToolButton(
                key: Key('map-world-query-${faction.key}'),
                palette: palette,
                icon: Icons.flag_outlined,
                label: 'Held by ${faction.value}',
                selected: queryResult?.subject == faction.value,
                onPressed: () => _runQuery(
                  MapWorldQueryKind.controlledBy,
                  faction.key,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQueryResult(_MapPalette palette, MapWorldQueryResult result) {
    return Container(
      key: const Key('map-world-query-result'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.headline,
                  style: palette.ui.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                key: const Key('map-world-query-clear'),
                tooltip: 'Clear this answer',
                onPressed: _clearQuery,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (result.note.isNotEmpty)
            Text(
              result.note,
              key: const Key('map-world-query-note'),
              style: palette.body,
            ),
          for (final line in result.lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(line, style: palette.label),
            ),
        ],
      ),
    );
  }

  /// The Phase 4 overlay controls.
  ///
  /// Everything in here asks a question about the view — which kinds are drawn,
  /// where the story clock is standing, whose journey is traced, what the author
  /// is looking for. Nothing in here writes: the overlay layer is a reading of
  /// canonical data and stays one.
  Widget _buildOverlayPanel(_MapPalette palette, MapOverlayData data) {
    final results = data.search(overlayQuery);
    return _Panel(
      key: const Key('map-overlay-panel'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Story overlays',
                  style: palette.ui.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _ToolButton(
                key: const Key('map-overlays-toggle'),
                palette: palette,
                icon: overlaysVisible
                    ? Icons.layers_outlined
                    : Icons.layers_clear_outlined,
                label: overlaysVisible ? 'Hide overlays' : 'Show overlays',
                selected: overlaysVisible,
                onPressed: () =>
                    setState(() => overlaysVisible = !overlaysVisible),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final kind in MapOverlayKind.values)
                _ToolButton(
                  key: Key('map-overlay-filter-${kind.name}'),
                  palette: palette,
                  icon: _overlayIcon(kind),
                  label: '${kind.label} (${data.ofKind(kind).length})',
                  selected: overlayFilter.shows(kind),
                  onPressed: () => _toggleOverlayKind(kind),
                ),
            ],
          ),
          // Story entities that exist but have nowhere to be drawn are counted,
          // never silently dropped.
          for (final kind in MapOverlayKind.values)
            if (data.unmappedOf(kind) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${data.unmappedOf(kind)} ${kind.label.toLowerCase()} '
                  'have no mapped location',
                  key: Key('map-overlay-unmapped-${kind.name}'),
                  style: palette.label,
                ),
              ),
          if (data.moments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTimelineControl(palette, data),
          ],
          if (data.journeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Journeys',
                style: palette.ui.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final journey in data.journeys)
                  _ToolButton(
                    key: Key('map-journey-${journey.characterId}'),
                    palette: palette,
                    icon: Icons.timeline_outlined,
                    label: journey.isDrawable
                        ? '${journey.characterName} (${journey.stops.length})'
                        : '${journey.characterName} (no path)',
                    selected: overlayFilter.journeyCharacterIds
                        .contains(journey.characterId),
                    onPressed: journey.isDrawable
                        ? () => _toggleJourney(journey.characterId)
                        : null,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const Key('map-overlay-search'),
            controller: overlaySearch,
            onChanged: (value) => setState(() => overlayQuery = value),
            decoration: const InputDecoration(
              labelText: 'Find a character, event, scene or place',
              prefixIcon: Icon(Icons.search_outlined),
              isDense: true,
            ),
          ),
          if (overlayQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            if (results.isEmpty)
              Text(
                'Nothing on this map matches that.',
                key: const Key('map-overlay-no-results'),
                style: palette.label,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in results.take(8))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Semantics(
                        button: true,
                        label: 'Focus ${item.semanticLabel}',
                        child: InkWell(
                          key: Key('map-overlay-result-${item.id}'),
                          onTap: () => _focusOverlay(item),
                          child: Row(
                            children: [
                              Icon(
                                _overlayIcon(item.kind),
                                size: 16,
                                color: palette.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.locationName.isEmpty
                                      ? item.label
                                      : '${item.label} — ${item.locationName}',
                                  style: palette.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  /// The story clock.
  ///
  /// Scrubbing it changes which overlays are drawn and nothing else. Story
  /// moment mode narrows the map to a single point in the story; the whole
  /// story is always one button away.
  Widget _buildTimelineControl(_MapPalette palette, MapOverlayData data) {
    final keys = [for (final moment in data.moments) moment.sortKey];
    final current = overlayFilter.moment;
    final index = current == null ? -1 : keys.indexOf(current);
    final label = index < 0
        ? 'Whole story'
        : data.moments[index].label +
            (data.moments[index].approximate ? ' (approximate)' : '');
    return Column(
      key: const Key('map-overlay-timeline'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                key: const Key('map-overlay-moment-label'),
                style: palette.ui.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              index < 0
                  ? '${data.moments.length} moments'
                  : '${index + 1} of ${data.moments.length}',
              key: const Key('map-overlay-moment-position'),
              style: palette.label,
            ),
          ],
        ),
        if (keys.length > 1)
          Slider(
            key: const Key('map-overlay-moment-slider'),
            value: (index < 0 ? 0 : index).toDouble(),
            min: 0,
            max: (keys.length - 1).toDouble(),
            divisions: keys.length - 1,
            label: data.moments[index < 0 ? 0 : index].label,
            activeColor: palette.primary,
            inactiveColor: palette.outline,
            onChanged: (value) => _setMoment(keys[value.round()]),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ToolButton(
              key: const Key('map-overlay-moment-prev'),
              palette: palette,
              icon: Icons.chevron_left,
              label: 'Earlier',
              selected: false,
              onPressed: () => _stepMoment(-1),
            ),
            _ToolButton(
              key: const Key('map-overlay-moment-next'),
              palette: palette,
              icon: Icons.chevron_right,
              label: 'Later',
              selected: false,
              onPressed: () => _stepMoment(1),
            ),
            _ToolButton(
              key: const Key('map-overlay-story-moment'),
              palette: palette,
              icon: Icons.hourglass_bottom_outlined,
              label: 'Story moment',
              selected: !overlayFilter.isWholeStory &&
                  !overlayFilter.showPast &&
                  !overlayFilter.showFuture,
              onPressed: _enterStoryMoment,
            ),
            _ToolButton(
              key: const Key('map-overlay-whole-story'),
              palette: palette,
              icon: Icons.all_inclusive_outlined,
              label: 'Whole story',
              selected: overlayFilter.isWholeStory,
              onPressed: _showWholeStory,
            ),
            _ToolButton(
              key: const Key('map-overlay-show-past'),
              palette: palette,
              icon: Icons.history_outlined,
              label: 'Keep past',
              selected: overlayFilter.showPast,
              onPressed: () => setState(() {
                overlayFilter = overlayFilter.copyWith(
                  showPast: !overlayFilter.showPast,
                );
              }),
            ),
            _ToolButton(
              key: const Key('map-overlay-show-future'),
              palette: palette,
              icon: Icons.update_outlined,
              label: 'Reveal future',
              selected: overlayFilter.showFuture,
              onPressed: () => setState(() {
                overlayFilter = overlayFilter.copyWith(
                  showFuture: !overlayFilter.showFuture,
                );
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, _MapPalette palette) {
    final map = selectedMap;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MAP STUDIO',
                key: const Key('map-studio-title'),
                style: palette.label.copyWith(letterSpacing: 1.6),
              ),
              const SizedBox(height: 4),
              Text(
                map?.title ?? 'No map selected',
                key: const Key('map-studio-heading'),
                style: palette.heading.copyWith(fontWeight: FontWeight.w700),
              ),
              if (map != null && map.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(map.description, style: palette.body),
              ],
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            if (map != null)
              OutlinedButton.icon(
                key: const Key('map-settings-button'),
                onPressed: busy ? null : _editMapMetadata,
                icon: const Icon(Icons.tune_outlined),
                label: const Text('Settings'),
              ),
            if (map != null)
              OutlinedButton.icon(
                key: const Key('map-archive-button'),
                onPressed: busy ? null : _archiveMap,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive'),
              ),
            FilledButton.icon(
              key: const Key('map-create-button'),
              onPressed: busy ? null : _createMap,
              icon: const Icon(Icons.add),
              label: const Text('Create Map'),
            ),
          ],
        ),
      ],
    );
  }

  /// The Phase 2 editor toolbar.
  ///
  /// Tools, the placement palette, the camera controls and the Phase 1 authoring
  /// dialogs, all drawn from engine tokens.
  Widget _buildToolbar(BuildContext context, _MapPalette palette) {
    return Container(
      key: const Key('map-editor-toolbar'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.outline),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final value in MapEditorTool.values)
            _ToolButton(
              key: Key('map-tool-${value.name}'),
              palette: palette,
              icon: _toolIcon(value),
              label: value.label,
              selected: tool == value,
              onPressed: busy ? null : () => _selectTool(value),
            ),
          _ToolbarDivider(palette: palette),
          for (final kind in MapPlacementKind.values)
            _PlacementChip(
              key: Key('map-place-${kind.name}-chip'),
              palette: palette,
              kind: kind,
              selected:
                  tool == MapEditorTool.place && placementKind == kind,
              onPressed: busy
                  ? null
                  : () => setState(() {
                        tool = MapEditorTool.place;
                        placementKind = kind;
                      }),
            ),
          _ToolbarDivider(palette: palette),
          _ToolButton(
            key: const Key('map-zoom-in-button'),
            palette: palette,
            icon: Icons.zoom_in,
            label: 'Zoom in',
            selected: false,
            onPressed: busy ? null : _zoomIn,
          ),
          _ToolButton(
            key: const Key('map-zoom-out-button'),
            palette: palette,
            icon: Icons.zoom_out,
            label: 'Zoom out',
            selected: false,
            onPressed: busy ? null : _zoomOut,
          ),
          _ToolButton(
            key: const Key('map-reset-view-button'),
            palette: palette,
            icon: Icons.center_focus_strong_outlined,
            label: 'Reset view',
            selected: false,
            onPressed: busy ? null : _resetView,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${(camera.scale * 100).round()}%',
              key: const Key('map-zoom-level'),
              style: palette.label,
            ),
          ),
          _ToolbarDivider(palette: palette),
          OutlinedButton.icon(
            key: const Key('map-add-location-button'),
            onPressed: busy ? null : _addLocation,
            icon: const Icon(Icons.place_outlined),
            label: const Text('Add Location'),
          ),
          OutlinedButton.icon(
            key: const Key('map-add-region-button'),
            onPressed: busy ? null : _addRegion,
            icon: const Icon(Icons.crop_square_outlined),
            label: const Text('Add Region'),
          ),
          OutlinedButton.icon(
            key: const Key('map-add-marker-button'),
            onPressed: busy ? null : _addMarker,
            icon: const Icon(Icons.push_pin_outlined),
            label: const Text('Add Marker'),
          ),
        ],
      ),
    );
  }

  static IconData _toolIcon(MapEditorTool value) => switch (value) {
        MapEditorTool.select => Icons.highlight_alt_outlined,
        MapEditorTool.place => Icons.add_location_alt_outlined,
        MapEditorTool.move => Icons.open_with_outlined,
        MapEditorTool.region => Icons.pentagon_outlined,
        MapEditorTool.pan => Icons.pan_tool_outlined,
        MapEditorTool.terrain => Icons.brush_outlined,
        MapEditorTool.asset => Icons.forest_outlined,
      };

  /// Terrain painting controls, shown while the terrain brush is held.
  Widget _buildTerrainTools(_MapPalette palette) {
    final style = selectedMap?.visualStyle ?? MapVisualStyle.standard;
    return Container(
      key: const Key('map-terrain-tools'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final kind in MapTerrainKind.values)
                _SwatchChip(
                  key: Key('map-terrain-kind-${kind.name}'),
                  palette: palette,
                  label: kind.label,
                  color: palette.terrainColor(kind, style),
                  selected: brush.kind == kind && !brush.erases,
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => brush = brush.withKind(kind).withErases(false)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Brush', style: palette.label),
              IconButton(
                key: const Key('map-brush-smaller'),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: 'Smaller brush',
                color: palette.onSurfaceVariant,
                onPressed: busy
                    ? null
                    : () => setState(
                        () => brush = brush.withRadius(brush.radius / 1.5)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '${brush.radius.round()}',
                key: const Key('map-brush-size'),
                style: palette.label,
              ),
              IconButton(
                key: const Key('map-brush-larger'),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: 'Larger brush',
                color: palette.onSurfaceVariant,
                onPressed: busy
                    ? null
                    : () => setState(
                        () => brush = brush.withRadius(brush.radius * 1.5)),
                icon: const Icon(Icons.add_circle_outline),
              ),
              _ToolButton(
                key: const Key('map-terrain-erase'),
                palette: palette,
                icon: Icons.cleaning_services_outlined,
                label: 'Erase',
                selected: brush.erases,
                onPressed: busy
                    ? null
                    : () =>
                        setState(() => brush = brush.withErases(!brush.erases)),
              ),
              _ToolbarDivider(palette: palette),
              OutlinedButton(
                key: const Key('map-terrain-fill'),
                onPressed: busy ? null : () => _fillTerrain(brush.kind),
                child: const Text('Fill map'),
              ),
              OutlinedButton(
                key: const Key('map-terrain-clear'),
                onPressed: busy ? null : _clearTerrain,
                child: const Text('Clear terrain'),
              ),
              _ToolbarDivider(palette: palette),
              for (final treatment in MapBackgroundTreatment.values)
                _ToolButton(
                  key: Key('map-style-treatment-${treatment.name}'),
                  palette: palette,
                  icon: Icons.texture_outlined,
                  label: treatment.label,
                  selected: style.treatment == treatment,
                  onPressed: busy
                      ? null
                      : () => _setStyle(style.copyWith(treatment: treatment)),
                ),
              _ToolButton(
                key: const Key('map-style-legend-toggle'),
                palette: palette,
                icon: Icons.list_alt_outlined,
                label: 'Legend',
                selected: style.showLegend,
                onPressed: busy
                    ? null
                    : () => _setStyle(
                        style.copyWith(showLegend: !style.showLegend)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Biomes: ${(selectedMap?.biomes ?? MapBiome.builtIn).map((biome) => biome.name).join(', ')}',
            key: const Key('map-biome-summary'),
            style: palette.label,
          ),
        ],
      ),
    );
  }

  /// Scenery controls, shown while the scenery tool is held.
  Widget _buildAssetTools(_MapPalette palette) {
    final selected = _selectedAsset;
    return Container(
      key: const Key('map-asset-tools'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final category in MapAssetCategory.values)
                _ToolButton(
                  key: Key('map-asset-category-${category.name}'),
                  palette: palette,
                  icon: Icons.category_outlined,
                  label: category.label,
                  selected: assetCategory == category,
                  onPressed: busy
                      ? null
                      : () => setState(() {
                            assetCategory = category;
                            assetDefinitionId =
                                MapAssetDefinition.inCategory(category)
                                    .first
                                    .id;
                          }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final definition
                  in MapAssetDefinition.inCategory(assetCategory))
                _ToolButton(
                  key: Key('map-asset-def-${definition.id}'),
                  palette: palette,
                  icon: _assetIcon(definition.id),
                  label: definition.label,
                  selected: assetDefinitionId == definition.id,
                  onPressed: busy
                      ? null
                      : () => setState(
                          () => assetDefinitionId = definition.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                selected == null
                    ? 'Tap the map to place. Select scenery to shape it.'
                    : 'Editing ${selected.definition?.label ?? selected.definitionId} '
                        '— ${selected.rotation.round()}°, '
                        '${selected.scale.toStringAsFixed(2)}x, layer ${selected.layer}',
                key: const Key('map-asset-status'),
                style: palette.label,
              ),
              OutlinedButton(
                key: const Key('map-asset-rotate'),
                onPressed: busy || selected == null
                    ? null
                    : () => _transformAsset(rotation: selected.rotation + 45),
                child: const Text('Rotate 45°'),
              ),
              OutlinedButton(
                key: const Key('map-asset-scale-up'),
                onPressed: busy || selected == null
                    ? null
                    : () => _transformAsset(scale: selected.scale * 1.25),
                child: const Text('Larger'),
              ),
              OutlinedButton(
                key: const Key('map-asset-scale-down'),
                onPressed: busy || selected == null
                    ? null
                    : () => _transformAsset(scale: selected.scale / 1.25),
                child: const Text('Smaller'),
              ),
              OutlinedButton(
                key: const Key('map-asset-forward'),
                onPressed: busy || selected == null
                    ? null
                    : () => _transformAsset(layer: selected.layer + 1),
                child: const Text('Bring forward'),
              ),
              OutlinedButton(
                key: const Key('map-asset-back'),
                onPressed: busy || selected == null
                    ? null
                    : () => _transformAsset(layer: selected.layer - 1),
                child: const Text('Send back'),
              ),
              OutlinedButton(
                key: const Key('map-asset-remove'),
                onPressed: busy || selected == null ? null : _removeAsset,
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The region geometry controls, shown while the region tool is held.
  Widget _buildRegionTools(_MapPalette palette) {
    final region = _selectedRegion;
    return Container(
      key: const Key('map-region-tools'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.outline),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            region == null
                ? 'Drag on the map to draw a region.'
                : 'Editing ${region.name} — ${region.geometry.kind.name}, '
                    '${region.geometry.points.length} points',
            key: const Key('map-region-tools-status'),
            style: palette.label,
          ),
          OutlinedButton(
            key: const Key('map-region-polygon-button'),
            onPressed: busy || region == null
                ? null
                : () => _reshapeRegion(MapGeometryKind.polygon),
            child: const Text('Edit as polygon'),
          ),
          OutlinedButton(
            key: const Key('map-region-bounds-button'),
            onPressed: busy || region == null
                ? null
                : () => _reshapeRegion(MapGeometryKind.bounds),
            child: const Text('Reduce to box'),
          ),
          OutlinedButton(
            key: const Key('map-region-add-point-button'),
            onPressed: busy || region == null ? null : _addGeometryPoint,
            child: const Text('Add point'),
          ),
          OutlinedButton(
            key: const Key('map-region-remove-point-button'),
            onPressed: busy || region == null ? null : _removeGeometryPoint,
            child: const Text('Remove point'),
          ),
        ],
      ),
    );
  }
}

/// What a drag on the canvas currently means.
enum _DragMode { none, marquee, pan, item, point, region, place, terrain }

/// The map surface, and the Phase 2 editor's pointer surface.
///
/// The canvas holds no store and no domain state: it is handed [MapCanvasData]
/// and a [MapCamera], projects every stored map-space position onto whatever
/// pixel size the layout gives it, and converts every pointer position back into
/// map space through [MapProjection] before handing it up. Pixels stop here.
class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    required this.data,
    required this.palette,
    required this.camera,
    required this.tool,
    required this.placementKind,
    required this.selections,
    required this.primarySelection,
    required this.inlineEditing,
    required this.interactive,
    required this.onSelected,
    required this.onSelectionReplaced,
    required this.onSelectionCleared,
    required this.onCameraChanged,
    required this.onPlace,
    required this.onMoveItem,
    required this.onRegionDrawn,
    required this.onGeometryPointMoved,
    required this.onInlineEditRequested,
    required this.onInlineEditSubmitted,
    required this.onInlineEditCancelled,
    required this.onPaintStroke,
    required this.onPlaceAsset,
    required this.onMoveAsset,
    required this.onAssetSelected,
    required this.brush,
    required this.selectedAssetId,
    required this.overlayData,
    required this.overlayFilter,
    required this.selectedOverlayId,
    required this.overlaysVisible,
    required this.onOverlaySelected,
    required this.worldData,
    required this.worldVisible,
    required this.bordersVisible,
    required this.routesVisible,
    required this.highlightedIds,
  });

  final MapCanvasData data;
  final _MapPalette palette;
  final MapCamera camera;
  final MapEditorTool tool;
  final MapPlacementKind placementKind;
  final Set<MapSelection> selections;
  final MapSelection? primarySelection;
  final MapSelection? inlineEditing;
  final bool interactive;

  final void Function(MapSelection value) onSelected;
  final void Function(List<MapSelection> values) onSelectionReplaced;
  final VoidCallback onSelectionCleared;
  final ValueChanged<MapCamera> onCameraChanged;
  final void Function(MapPosition position, MapPlacementKind kind) onPlace;
  final void Function(MapSelection item, MapPosition position) onMoveItem;
  final ValueChanged<MapRect> onRegionDrawn;
  final void Function(String regionId, int index, MapPosition position)
      onGeometryPointMoved;
  final ValueChanged<MapSelection> onInlineEditRequested;
  final void Function(MapSelection item, String name, String category)
      onInlineEditSubmitted;
  final VoidCallback onInlineEditCancelled;

  final ValueChanged<List<MapPosition>> onPaintStroke;
  final ValueChanged<MapPosition> onPlaceAsset;
  final void Function(String assetId, MapPosition position) onMoveAsset;
  final ValueChanged<String?> onAssetSelected;
  final MapTerrainBrush brush;
  final String? selectedAssetId;

  final MapOverlayData? overlayData;
  final MapOverlayFilter overlayFilter;
  final String? selectedOverlayId;
  final bool overlaysVisible;
  final ValueChanged<String?> onOverlaySelected;

  final MapWorldState? worldData;
  final bool worldVisible;
  final bool bordersVisible;
  final bool routesVisible;

  /// Ids a query or a travel answer has lit up. Presentation only.
  final Set<String> highlightedIds;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> {
  _DragMode mode = _DragMode.none;
  Offset? startLocal;
  Offset? currentLocal;
  MapSelection? dragItem;
  int? dragPointIndex;
  MapPosition grabOffset = MapPosition.origin;
  MapPosition? previewPosition;
  MapPosition? previewPoint;

  /// Map-space dabs collected while a terrain stroke is in progress. Drawn as
  /// a preview and sent as one write on release.
  List<MapPosition> strokePoints = const [];

  /// The scenery item being dragged, if any. Kept apart from [dragItem]
  /// because an asset is not a [MapSelection].
  String? dragAssetId;

  /// The projection built by the last layout, so pointer signals outside the
  /// layout callback still have one to convert through.
  MapProjection? projection;

  bool get canEdit => widget.interactive;

  bool get canDragItems =>
      canEdit &&
      (widget.tool == MapEditorTool.move ||
          widget.tool == MapEditorTool.select);

  bool _isSelected(MapSelection value) => widget.selections.contains(value);

  MapPosition _clamp(MapPosition position) =>
      position.clampTo(widget.data.extent);

  // ------------------------------------------------------------- gestures ---

  void _onBackgroundPanStart(DragStartDetails details) {
    if (!canEdit) return;
    setState(() {
      startLocal = details.localPosition;
      currentLocal = details.localPosition;
      mode = switch (widget.tool) {
        MapEditorTool.select => _DragMode.marquee,
        MapEditorTool.region => _DragMode.region,
        MapEditorTool.place => _DragMode.place,
        MapEditorTool.pan => _DragMode.pan,
        MapEditorTool.move => _DragMode.pan,
        MapEditorTool.terrain => _DragMode.terrain,
        MapEditorTool.asset => _DragMode.place,
      };
      if (mode == _DragMode.terrain) {
        final current = projection;
        strokePoints = current == null
            ? <MapPosition>[]
            : <MapPosition>[
                current.toMap(details.localPosition.dx, details.localPosition.dy),
              ];
      }
    });
  }

  void _onBackgroundPanUpdate(DragUpdateDetails details) {
    if (mode == _DragMode.none) return;
    if (mode == _DragMode.pan) {
      final current = projection;
      if (current == null) return;
      widget.onCameraChanged(
        current.pannedBy(details.delta.dx, details.delta.dy),
      );
      return;
    }
    if (mode == _DragMode.terrain) {
      final current = projection;
      if (current == null) return;
      final point = current.toMap(
        details.localPosition.dx,
        details.localPosition.dy,
      );
      setState(() {
        currentLocal = details.localPosition;
        strokePoints = [...strokePoints, point];
      });
      return;
    }
    setState(() => currentLocal = details.localPosition);
  }

  void _onBackgroundPanEnd(DragEndDetails details) {
    final current = projection;
    final from = startLocal;
    final to = currentLocal;
    final finished = mode;
    setState(() {
      mode = _DragMode.none;
      startLocal = null;
      currentLocal = null;
    });
    if (current == null || from == null || to == null) return;
    switch (finished) {
      case _DragMode.marquee:
        final rect = current.toMapRect(from.dx, from.dy, to.dx, to.dy);
        widget.onSelectionReplaced(
          MapMarquee.selectionsWithin(widget.data, rect),
        );
      case _DragMode.region:
        final rect = current
            .toMapRect(from.dx, from.dy, to.dx, to.dy)
            .clampTo(widget.data.extent);
        if (rect.width > 0 && rect.height > 0) widget.onRegionDrawn(rect);
      case _DragMode.place:
        if (widget.tool == MapEditorTool.asset) {
          widget.onPlaceAsset(_clamp(current.toMap(to.dx, to.dy)));
        } else {
          widget.onPlace(
            _clamp(current.toMap(to.dx, to.dy)),
            widget.placementKind,
          );
        }
      case _DragMode.terrain:
        final stroke = strokePoints;
        setState(() => strokePoints = const []);
        if (stroke.isNotEmpty) widget.onPaintStroke(stroke);
      case _DragMode.none:
      case _DragMode.pan:
      case _DragMode.item:
      case _DragMode.point:
        break;
    }
  }

  void _onBackgroundTapUp(TapUpDetails details) {
    if (!canEdit) return;
    final current = projection;
    if (current == null) return;
    final at = _clamp(
      current.toMap(details.localPosition.dx, details.localPosition.dy),
    );
    if (widget.tool == MapEditorTool.place) {
      widget.onPlace(at, widget.placementKind);
      return;
    }
    if (widget.tool == MapEditorTool.terrain) {
      widget.onPaintStroke([at]);
      return;
    }
    if (widget.tool == MapEditorTool.asset) {
      widget.onPlaceAsset(at);
      return;
    }
    widget.onAssetSelected(null);
    widget.onSelectionCleared();
  }

  void _onItemPanStart(MapSelection item, MapPosition anchor, Offset local) {
    final current = projection;
    if (current == null) return;
    final pointer = current.toMap(local.dx, local.dy);
    setState(() {
      mode = _DragMode.item;
      dragItem = item;
      grabOffset = MapPosition(anchor.x - pointer.x, anchor.y - pointer.y);
      previewPosition = anchor;
    });
  }

  void _onItemPanUpdate(Offset local) {
    final current = projection;
    if (current == null || mode != _DragMode.item) return;
    final pointer = current.toMap(local.dx, local.dy);
    setState(
      () => previewPosition = _clamp(
        MapPosition(pointer.x + grabOffset.x, pointer.y + grabOffset.y),
      ),
    );
  }

  void _onItemPanEnd() {
    final item = dragItem;
    final position = previewPosition;
    setState(() {
      mode = _DragMode.none;
      dragItem = null;
      previewPosition = null;
    });
    if (item == null || position == null) return;
    widget.onMoveItem(item, position);
  }

  void _onPointPanStart(int index, MapPosition point, Offset local) {
    final current = projection;
    if (current == null) return;
    final pointer = current.toMap(local.dx, local.dy);
    setState(() {
      mode = _DragMode.point;
      dragPointIndex = index;
      grabOffset = MapPosition(point.x - pointer.x, point.y - pointer.y);
      previewPoint = point;
    });
  }

  void _onPointPanUpdate(Offset local) {
    final current = projection;
    if (current == null || mode != _DragMode.point) return;
    final pointer = current.toMap(local.dx, local.dy);
    setState(
      () => previewPoint = _clamp(
        MapPosition(pointer.x + grabOffset.x, pointer.y + grabOffset.y),
      ),
    );
  }

  void _onPointPanEnd(String regionId) {
    final index = dragPointIndex;
    final point = previewPoint;
    setState(() {
      mode = _DragMode.none;
      dragPointIndex = null;
      previewPoint = null;
    });
    if (index == null || point == null) return;
    widget.onGeometryPointMoved(regionId, index, point);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!canEdit || event is! PointerScrollEvent) return;
    final current = projection;
    if (current == null) return;
    final factor = event.scrollDelta.dy < 0
        ? MapCamera.zoomStep
        : 1 / MapCamera.zoomStep;
    widget.onCameraChanged(
      current.zoomedBy(
        factor,
        focusDx: event.localPosition.dx,
        focusDy: event.localPosition.dy,
      ),
    );
  }

  // ---------------------------------------------------------------- render --

  MapPosition _anchorFor(MapSelection item, MapPosition stored) =>
      (mode == _DragMode.item && dragItem == item && previewPosition != null)
          ? previewPosition!
          : stored;

  MapGeometry _geometryFor(MapRegionView region) {
    final item = MapSelection(kind: MapSelectionKind.region, id: region.id);
    if (mode == _DragMode.point &&
        dragItem == item &&
        dragPointIndex != null &&
        previewPoint != null) {
      return region.geometry.withPointAt(dragPointIndex!, previewPoint!);
    }
    if (mode == _DragMode.item && dragItem == item && previewPosition != null) {
      return region.geometry.movedTo(previewPosition!);
    }
    return region.geometry;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = widget.data.extent;
        final available =
            constraints.hasBoundedWidth ? constraints.maxWidth : 720.0;
        final width = available.clamp(280.0, 1200.0);
        final height = extent.width == 0
            ? width
            : (width * (extent.height / extent.width)).clamp(240.0, 720.0);
        final current = MapProjection(
          extent: extent,
          canvasWidth: width,
          canvasHeight: height,
          camera: widget.camera,
        );
        projection = current;
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: Container(
            key: const Key('map-canvas'),
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: palette.canvasSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            // The frame is painted over the content rather than around it, so
            // the pixel box the projection converts through is exactly the box
            // the pointer lands in, with no one-pixel skew between them.
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Declaration order of MapLayer is the draw order, back to
                // front. Walking the enum is what makes it deterministic.
                for (final layer in MapLayer.values)
                  Positioned.fill(
                    key: Key('map-layer-${layer.name}'),
                    child: Stack(children: _layer(layer, current)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _layer(MapLayer layer, MapProjection projection) =>
      switch (layer) {
        MapLayer.base => _baseLayer(projection),
        MapLayer.terrain => _terrainLayer(projection),
        MapLayer.assets => _assetLayer(projection),
        MapLayer.regions => [
            for (final region in widget.data.regions)
              _buildRegion(region, projection),
          ],
        MapLayer.locations => [
            for (final location in widget.data.locations)
              _buildPin(
                key: Key('map-location-${location.id}'),
                projection: projection,
                item: MapSelection(
                  kind: MapSelectionKind.location,
                  id: location.id,
                ),
                stored: location.position,
                label: location.name,
                icon: Icons.place,
              ),
          ],
        MapLayer.markers => [
            for (final marker in widget.data.markers)
              _buildPin(
                key: Key('map-marker-${marker.id}'),
                projection: projection,
                item: MapSelection(
                  kind: MapSelectionKind.marker,
                  id: marker.id,
                ),
                stored: marker.position,
                label: marker.label,
                icon: Icons.push_pin,
              ),
          ],
        MapLayer.borders => _borderLayer(projection),
        MapLayer.worldRoutes => _worldRouteLayer(projection),
        MapLayer.storyPaths => _storyPathLayer(projection),
        MapLayer.storyOverlays => _storyOverlayLayer(projection),
        MapLayer.selection => _selectionLayer(projection),
        MapLayer.interaction => _interactionLayer(projection),
      };

  List<Widget> _baseLayer(MapProjection projection) {
    final palette = widget.palette;
    return [
      if (widget.data.map.visualStyle.treatment !=
          MapBackgroundTreatment.plain)
        Positioned.fill(
          child: CustomPaint(
            key: const Key('map-background'),
            painter: _MapGridPainter(
              color: palette.outline,
              divisions: 8,
              treatment: widget.data.map.visualStyle.treatment,
              wash: palette.regionFill,
            ),
          ),
        ),
      if (widget.data.isEmpty)
        Center(
          child: Padding(
            key: const Key('map-canvas-empty'),
            padding: const EdgeInsets.all(24),
            child: Text(
              'This map has no locations, regions or markers yet.',
              textAlign: TextAlign.center,
              style: palette.body,
            ),
          ),
        ),
      // The pointer surface for everything that starts on empty ground:
      // marquee, pan, region drawing and placement. It sits at the bottom of
      // the stack so pins and regions above it answer for themselves first.
      Positioned.fill(
        child: _MapGestureArea(
          key: const Key('map-canvas-surface'),
          behavior: HitTestBehavior.translucent,
          onTapUp: _onBackgroundTapUp,
          onPanStart: _onBackgroundPanStart,
          onPanUpdate: _onBackgroundPanUpdate,
          onPanEnd: _onBackgroundPanEnd,
        ),
      ),
    ];
  }

  /// Painted ground.
  ///
  /// One painter for the whole grid rather than a widget per cell: a 48x48 map
  /// is 2,304 cells, and 2,304 widgets would cost more to lay out than the map
  /// costs to store.
  List<Widget> _terrainLayer(MapProjection projection) {
    final terrain = widget.data.map.terrain;
    final style = widget.data.map.visualStyle;
    // The stroke in progress is previewed locally so the ground follows the
    // brush; the write happens once, on release.
    var preview = terrain;
    if (mode == _DragMode.terrain && strokePoints.isNotEmpty) {
      if (preview.cellCount == 0) preview = MapTerrainGrid.empty();
      for (final point in strokePoints) {
        preview = preview.painted(widget.brush, point, widget.data.extent);
      }
    }
    if (preview.cellCount == 0) return const [];
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const Key('map-terrain'),
            painter: _TerrainPainter(
              terrain: preview,
              extent: widget.data.extent,
              projection: projection,
              palette: widget.palette,
              style: style,
            ),
          ),
        ),
      ),
    ];
  }

  /// Placed scenery, in its stored draw order.
  List<Widget> _assetLayer(MapProjection projection) {
    final palette = widget.palette;
    final assets = widget.data.map.assetsInDrawOrder;
    final canDrag = widget.interactive &&
        (widget.tool == MapEditorTool.asset ||
            widget.tool == MapEditorTool.move);
    return [
      for (final asset in assets)
        () {
          final point = projection.toCanvas(
            (mode == _DragMode.item &&
                    dragAssetId == asset.id &&
                    previewPosition != null)
                ? previewPosition!
                : asset.position,
          );
          final selected = widget.selectedAssetId == asset.id;
          final size = 22.0 * asset.scale;
          return Positioned(
            left: point.x - size,
            top: point.y - size,
            width: size * 2,
            height: size * 2,
            child: _MapGestureArea(
              key: Key('map-asset-${asset.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.interactive
                  ? () => widget.onAssetSelected(selected ? null : asset.id)
                  : null,
              onPanStart: canDrag
                  ? (details) {
                      dragAssetId = asset.id;
                      _onAssetPanStart(
                        asset.position,
                        _toCanvasLocal(details.globalPosition),
                      );
                    }
                  : null,
              onPanUpdate: canDrag
                  ? (details) => _onItemPanUpdate(
                      _toCanvasLocal(details.globalPosition))
                  : null,
              onPanEnd: canDrag ? (details) => _onAssetPanEnd() : null,
              child: Center(
                child: Transform.rotate(
                  angle: asset.rotation * 3.1415926535897932 / 180,
                  child: Icon(
                    _assetIcon(asset.definitionId),
                    size: size,
                    color: selected ? palette.primary : palette.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }(),
    ];
  }

  void _onAssetPanStart(MapPosition anchor, Offset local) {
    final current = projection;
    if (current == null) return;
    final pointer = current.toMap(local.dx, local.dy);
    setState(() {
      mode = _DragMode.item;
      grabOffset = MapPosition(anchor.x - pointer.x, anchor.y - pointer.y);
      previewPosition = anchor;
    });
  }

  void _onAssetPanEnd() {
    final assetId = dragAssetId;
    final position = previewPosition;
    setState(() {
      mode = _DragMode.none;
      dragAssetId = null;
      previewPosition = null;
    });
    if (assetId == null || position == null) return;
    widget.onMoveAsset(assetId, position);
  }

  /// Journeys, drawn as lines between the stops the story actually names.
  /// Political borders, read from the world state.
  ///
  /// A border is drawn as the shape the author gave it; the dash pattern says
  /// what kind it is, so a disputed line and a settled one never look alike in
  /// greyscale.
  List<Widget> _borderLayer(MapProjection projection) {
    final state = widget.worldData;
    if (!widget.worldVisible || !widget.bordersVisible || state == null) {
      return const [];
    }
    if (state.borders.isEmpty) return const [];
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const Key('map-borders'),
            painter: _BorderPainter(
              borders: state.borders,
              projection: projection,
              color: widget.palette.onSurfaceVariant,
              highlight: widget.palette.primary,
              highlightedIds: widget.highlightedIds,
            ),
          ),
        ),
      ),
    ];
  }

  /// Roads, rivers, passes and sea lanes between placed settlements.
  List<Widget> _worldRouteLayer(MapProjection projection) {
    final state = widget.worldData;
    if (!widget.worldVisible || !widget.routesVisible || state == null) {
      return const [];
    }
    if (state.routes.isEmpty) return const [];
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const Key('map-world-routes'),
            painter: _WorldRoutePainter(
              routes: state.routes,
              projection: projection,
              color: widget.palette.onSurfaceVariant,
              highlight: widget.palette.primary,
              highlightedIds: widget.highlightedIds,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _storyPathLayer(MapProjection projection) {
    final data = widget.overlayData;
    if (!widget.overlaysVisible || data == null) return const [];
    final journeys = data.journeysUnder(widget.overlayFilter);
    if (journeys.isEmpty) return const [];
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const Key('map-story-paths'),
            painter: _JourneyPainter(
              journeys: journeys,
              projection: projection,
              color: widget.palette.primary,
            ),
          ),
        ),
      ),
    ];
  }

  /// Characters, events, scenes and story locations, clustered where they
  /// share a position so none of them can hide behind another.
  List<Widget> _storyOverlayLayer(MapProjection projection) {
    final data = widget.overlayData;
    if (!widget.overlaysVisible || data == null) return const [];
    final palette = widget.palette;
    final visible = data.visibleUnder(widget.overlayFilter);
    // Location overlays would sit exactly on the Phase 1 pins that already
    // draw them, so they contribute context to the panels rather than a second
    // marker on the canvas.
    final drawn = [
      for (final item in visible)
        if (item.kind != MapOverlayKind.location) item,
    ];
    return [
      for (final cluster in MapOverlayCluster.clusterAll(drawn))
        () {
          final point = projection.toCanvas(cluster.position);
          final selected = cluster.items
              .any((item) => item.id == widget.selectedOverlayId);
          return Positioned(
            left: point.x - 16,
            top: point.y - 40,
            width: 32,
            height: 32,
            child: Semantics(
              button: true,
              selected: selected,
              label: cluster.semanticLabel,
              child: Tooltip(
                message: cluster.semanticLabel,
                child: GestureDetector(
                  key: Key('map-overlay-${cluster.primary.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onOverlaySelected(
                    selected ? null : cluster.primary.id,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected ? palette.selection : palette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? palette.primary : palette.outline,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: cluster.isSingle
                        ? Icon(
                            _overlayIcon(cluster.primary.kind),
                            size: 16,
                            color: selected
                                ? palette.primary
                                : palette.onSurfaceVariant,
                          )
                        : Text(
                            '${cluster.count}',
                            key: Key('map-overlay-count-${cluster.id}'),
                            style: palette.label,
                          ),
                  ),
                ),
              ),
            ),
          );
        }(),
    ];
  }

  List<Widget> _selectionLayer(MapProjection projection) {
    final palette = widget.palette;
    final primary = widget.primarySelection;
    final widgets = <Widget>[];

    // Geometry handles for the region being shaped.
    if (widget.tool == MapEditorTool.region &&
        primary != null &&
        primary.kind == MapSelectionKind.region) {
      final region = widget.data.regionById(primary.id);
      if (region != null) {
        final geometry = _geometryFor(region);
        for (var index = 0; index < geometry.points.length; index++) {
          final point = projection.toCanvas(geometry.points[index]);
          widgets.add(
            Positioned(
              left: point.x - 9,
              top: point.y - 9,
              child: _MapGestureArea(
                key: Key('map-geometry-handle-$index'),
                behavior: HitTestBehavior.opaque,
                onPanStart: canEdit
                    ? (details) {
                        dragItem = primary;
                        _onPointPanStart(
                          index,
                          geometry.points[index],
                          _toCanvasLocal(details.globalPosition),
                        );
                      }
                    : null,
                onPanUpdate: canEdit
                    ? (details) =>
                        _onPointPanUpdate(_toCanvasLocal(details.globalPosition))
                    : null,
                onPanEnd:
                    canEdit ? (details) => _onPointPanEnd(region.id) : null,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: palette.selection,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.primary, width: 2),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    // The inline-edit affordance for the single selected item.
    if (primary != null && widget.inlineEditing == null) {
      final anchor = widget.data.anchorOf(primary);
      if (anchor != null) {
        final point = projection.toCanvas(_anchorFor(primary, anchor));
        widgets.add(
          Positioned(
            left: point.x + 14,
            top: point.y - 34,
            child: IconButton(
              key: Key('map-inline-edit-${primary.id}'),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit name',
              color: palette.primary,
              onPressed: canEdit
                  ? () => widget.onInlineEditRequested(primary)
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  List<Widget> _interactionLayer(MapProjection projection) {
    final palette = widget.palette;
    final widgets = <Widget>[];
    final from = startLocal;
    final to = currentLocal;
    if (from != null &&
        to != null &&
        (mode == _DragMode.marquee || mode == _DragMode.region)) {
      final left = from.dx < to.dx ? from.dx : to.dx;
      final top = from.dy < to.dy ? from.dy : to.dy;
      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: (to.dx - from.dx).abs(),
          height: (to.dy - from.dy).abs(),
          child: IgnorePointer(
            child: Container(
              key: Key(
                mode == _DragMode.marquee
                    ? 'map-marquee'
                    : 'map-region-preview',
              ),
              decoration: BoxDecoration(
                color: palette.marquee,
                border: Border.all(color: palette.primary, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
    }

    final editing = widget.inlineEditing;
    if (editing != null) {
      final anchor = widget.data.anchorOf(editing);
      if (anchor != null) {
        final point = projection.toCanvas(anchor);
        widgets.add(
          Positioned(
            left: (point.x - 120)
                .clamp(4.0, (projection.canvasWidth - 244).clamp(4.0, 4000.0)),
            top: (point.y + 20)
                .clamp(4.0, (projection.canvasHeight - 140).clamp(4.0, 4000.0)),
            width: 240,
            child: _InlineEditor(
              palette: palette,
              item: editing,
              initialName: _nameOf(editing),
              initialCategory: _categoryOf(editing),
              onSubmit: (name, category) =>
                  widget.onInlineEditSubmitted(editing, name, category),
              onCancel: widget.onInlineEditCancelled,
            ),
          ),
        );
      }
    }
    return widgets;
  }

  String _nameOf(MapSelection item) => switch (item.kind) {
        MapSelectionKind.location =>
          widget.data.locationById(item.id)?.name ?? '',
        MapSelectionKind.region => widget.data.regionById(item.id)?.name ?? '',
        MapSelectionKind.marker =>
          widget.data.markerById(item.id)?.label ?? '',
      };

  String _categoryOf(MapSelection item) => switch (item.kind) {
        MapSelectionKind.location =>
          widget.data.locationById(item.id)?.locationType ?? '',
        MapSelectionKind.region =>
          widget.data.regionById(item.id)?.category ?? '',
        MapSelectionKind.marker =>
          widget.data.markerById(item.id)?.category ?? '',
      };

  /// A global pointer position, in canvas pixels.
  ///
  /// Handles and pins are small boxes of their own, so their local coordinates
  /// are not canvas coordinates; this puts them back on the canvas before the
  /// projection turns them into map space.
  Offset _toCanvasLocal(Offset global) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.globalToLocal(global);
    return global;
  }

  Widget _buildRegion(MapRegionView region, MapProjection projection) {
    final palette = widget.palette;
    final item = MapSelection(kind: MapSelectionKind.region, id: region.id);
    final geometry = _geometryFor(region);
    final box = geometry.bounds;
    if (box == null) return const SizedBox.shrink();
    final topLeft = projection.toCanvas(box.topLeft);
    final bottomRight = projection.toCanvas(box.bottomRight);
    final width = (bottomRight.x - topLeft.x).abs().clamp(8.0, 100000.0);
    final height = (bottomRight.y - topLeft.y).abs().clamp(8.0, 100000.0);
    final selected = _isSelected(item);
    return Positioned(
      left: topLeft.x,
      top: topLeft.y,
      width: width,
      height: height,
      child: _MapGestureArea(
        key: Key('map-region-${region.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelected(item),
        onPanStart: canDragItems
            ? (details) => _onItemPanStart(
                  item,
                  geometry.centre ?? region.anchor,
                  _toCanvasLocal(details.globalPosition),
                )
            : null,
        onPanUpdate: canDragItems
            ? (details) => _onItemPanUpdate(_toCanvasLocal(details.globalPosition))
            : null,
        onPanEnd: canDragItems ? (details) => _onItemPanEnd() : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RegionShapePainter(
                  points: [
                    for (final point in geometry.points)
                      () {
                        final canvasPoint = projection.toCanvas(point);
                        return Offset(
                          canvasPoint.x - topLeft.x,
                          canvasPoint.y - topLeft.y,
                        );
                      }(),
                  ],
                  kind: geometry.kind,
                  fill: palette.regionFill,
                  stroke: selected ? palette.primary : palette.outline,
                  strokeWidth: selected ? 2 : 1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                region.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: palette.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPin({
    required Key key,
    required MapProjection projection,
    required MapSelection item,
    required MapPosition stored,
    required String label,
    required IconData icon,
  }) {
    final palette = widget.palette;
    final point = projection.toCanvas(_anchorFor(item, stored));
    final selected = _isSelected(item);
    return Positioned(
      left: point.x - 60,
      top: point.y - 16,
      width: 120,
      child: Semantics(
        button: true,
        label: label,
        child: _MapGestureArea(
          key: key,
          onTap: () => widget.onSelected(item),
          onPanStart: canDragItems
              ? (details) => _onItemPanStart(
                    item,
                    stored,
                    _toCanvasLocal(details.globalPosition),
                  )
              : null,
          onPanUpdate: canDragItems
              ? (details) =>
                  _onItemPanUpdate(_toCanvasLocal(details.globalPosition))
              : null,
          onPanEnd: canDragItems ? (details) => _onItemPanEnd() : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: selected ? 26 : 20,
                color: selected ? palette.primary : palette.onSurfaceVariant,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? palette.selection : palette.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.outline),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: palette.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a region's stored shape in canvas space.
///
/// Rendering order and rendering only: the shape comes from the record, the
/// colours come from the engine, and how a region is *styled* beyond this is
/// deliberately not a Phase 2 concern.
/// Draws the ways between places.
///
/// One line per route, through [MapProjection] like everything else on the
/// canvas. A route the author has just asked about is drawn heavier rather than
/// merely recoloured, so the answer is visible without relying on colour.
class _WorldRoutePainter extends CustomPainter {
  const _WorldRoutePainter({
    required this.routes,
    required this.projection,
    required this.color,
    required this.highlight,
    required this.highlightedIds,
  });

  final List<MapWorldRoute> routes;
  final MapProjection projection;
  final Color color;
  final Color highlight;
  final Set<String> highlightedIds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final route in routes) {
      final lit = highlightedIds.contains(route.id);
      final start = projection.toCanvas(route.fromPosition);
      final end = projection.toCanvas(route.toPosition);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = lit ? 4 : 2
        ..color = (lit ? highlight : color)
            .withValues(alpha: lit ? 0.95 : 0.55);
      final from = Offset(start.x, start.y);
      final to = Offset(end.x, end.y);
      if (_isDashed(route.kind)) {
        _dashedLine(canvas, from, to, paint);
      } else {
        canvas.drawLine(from, to, paint);
      }
    }
  }

  /// Ways that are not open ground are dashed: a hidden path and a king's road
  /// should not read the same at a glance.
  bool _isDashed(MapRouteKind kind) =>
      kind == MapRouteKind.hidden ||
      kind == MapRouteKind.magical ||
      kind == MapRouteKind.path ||
      kind == MapRouteKind.mountainPass;

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return;
    final step = delta / length;
    var travelled = 0.0;
    while (travelled < length) {
      final end = travelled + dash > length ? length : travelled + dash;
      canvas.drawLine(
        from + step * travelled,
        from + step * end,
        paint,
      );
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(_WorldRoutePainter oldDelegate) =>
      oldDelegate.routes != routes ||
      oldDelegate.color != color ||
      oldDelegate.highlightedIds != highlightedIds ||
      oldDelegate.projection.camera != projection.camera ||
      oldDelegate.projection.canvasWidth != projection.canvasWidth ||
      oldDelegate.projection.canvasHeight != projection.canvasHeight;
}

/// Draws political borders.
class _BorderPainter extends CustomPainter {
  const _BorderPainter({
    required this.borders,
    required this.projection,
    required this.color,
    required this.highlight,
    required this.highlightedIds,
  });

  final List<MapBorder> borders;
  final MapProjection projection;
  final Color color;
  final Color highlight;
  final Set<String> highlightedIds;

  @override
  void paint(Canvas canvas, Size size) {
    for (final border in borders) {
      final points = border.geometry.points;
      if (points.length < 2) continue;
      final lit = highlightedIds.contains(border.id);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lit ? 3.5 : 2
        ..strokeJoin = StrokeJoin.round
        ..color = (lit ? highlight : color)
            .withValues(alpha: border.kind == MapBorderKind.historical ? 0.4 : 0.8);
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final point = projection.toCanvas(points[index]);
        if (index == 0) {
          path.moveTo(point.x, point.y);
        } else {
          path.lineTo(point.x, point.y);
        }
      }
      if (border.geometry.kind == MapGeometryKind.polygon) path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_BorderPainter oldDelegate) =>
      oldDelegate.borders != borders ||
      oldDelegate.color != color ||
      oldDelegate.highlightedIds != highlightedIds ||
      oldDelegate.projection.camera != projection.camera ||
      oldDelegate.projection.canvasWidth != projection.canvasWidth ||
      oldDelegate.projection.canvasHeight != projection.canvasHeight;
}

/// A pan recognizer that keeps a map drag on the map.
///
/// Map Studio is a page, and a page scrolls. A scroll view accepts a vertical
/// drag as soon as the pointer passes the touch slop, while an ordinary pan
/// waits for the larger pan slop, so a mostly-vertical drag over the canvas is
/// taken by the page and the pin the author grabbed never moves. Accepting at
/// the same distance the page does settles it in favour of the pointer's own
/// target: the deeper recognizer is offered the movement first.
class _MapPanRecognizer extends PanGestureRecognizer {
  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings);
}

/// The canvas's tap and drag surface.
///
/// A thin stand-in for `GestureDetector` that uses [_MapPanRecognizer], so
/// every draggable thing on the map — ground, pins, regions, scenery, geometry
/// handles — answers to the pointer rather than to the page behind it.
class _MapGestureArea extends StatelessWidget {
  const _MapGestureArea({
    super.key,
    this.behavior = HitTestBehavior.deferToChild,
    this.onTap,
    this.onTapUp,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.child,
  });

  final HitTestBehavior behavior;
  final VoidCallback? onTap;
  final GestureTapUpCallback? onTapUp;
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  /// Optional: the background surface is a bare pointer area with nothing in
  /// it, exactly as it was before.
  final Widget? child;

  bool get _drags =>
      onPanStart != null || onPanUpdate != null || onPanEnd != null;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
        behavior: behavior,
        gestures: <Type, GestureRecognizerFactory>{
          if (onTap != null || onTapUp != null)
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (recognizer) => recognizer
                ..onTap = onTap
                ..onTapUp = onTapUp,
            ),
          if (_drags)
            _MapPanRecognizer:
                GestureRecognizerFactoryWithHandlers<_MapPanRecognizer>(
              _MapPanRecognizer.new,
              // The pointer's own travel is the edit, so the drag starts where
              // the finger went down rather than where the slop was crossed:
              // what the writer moves by is what the record moves by.
              (recognizer) => recognizer
                ..dragStartBehavior = DragStartBehavior.down
                ..onStart = onPanStart
                ..onUpdate = onPanUpdate
                ..onEnd = onPanEnd,
            ),
        },
        child: child,
      );
}

class _RegionShapePainter extends CustomPainter {
  const _RegionShapePainter({
    required this.points,
    required this.kind,
    required this.fill,
    required this.stroke,
    required this.strokeWidth,
  });

  final List<Offset> points;
  final MapGeometryKind kind;
  final Color fill;
  final Color stroke;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = fill;
    final strokePaint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (kind == MapGeometryKind.polygon || kind == MapGeometryKind.polyline) {
      if (points.length < 2) return;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (kind == MapGeometryKind.polygon) {
        path.close();
        canvas.drawPath(path, fillPaint);
      }
      canvas.drawPath(path, strokePaint);
      return;
    }
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(rounded, fillPaint);
    canvas.drawRRect(rounded, strokePaint);
  }

  @override
  bool shouldRepaint(_RegionShapePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.kind != kind ||
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Draws the painted ground.
///
/// Cells are converted through [MapProjection] like everything else, so terrain
/// zooms and pans with the map and no pixel ever reaches a record.
class _TerrainPainter extends CustomPainter {
  const _TerrainPainter({
    required this.terrain,
    required this.extent,
    required this.projection,
    required this.palette,
    required this.style,
  });

  final MapTerrainGrid terrain;
  final MapExtent extent;
  final MapProjection projection;
  final _MapPalette palette;
  final MapVisualStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (terrain.cellCount == 0) return;
    final cached = <MapTerrainKind, Paint>{};
    for (var row = 0; row < terrain.rows; row++) {
      for (var column = 0; column < terrain.columns; column++) {
        final kind = terrain.kindAt(column, row);
        if (kind == null) continue;
        final rect = terrain.rectFor(column, row, extent);
        final topLeft = projection.toCanvas(rect.topLeft);
        final bottomRight = projection.toCanvas(rect.bottomRight);
        // A half-pixel bleed stops hairline seams between neighbouring cells.
        final drawn = Rect.fromLTRB(
          topLeft.x - 0.5,
          topLeft.y - 0.5,
          bottomRight.x + 0.5,
          bottomRight.y + 0.5,
        );
        if (drawn.right < 0 ||
            drawn.bottom < 0 ||
            drawn.left > size.width ||
            drawn.top > size.height) {
          continue;
        }
        final paint = cached.putIfAbsent(
          kind,
          () => Paint()..color = palette.terrainColor(kind, style),
        );
        canvas.drawRect(drawn, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TerrainPainter oldDelegate) =>
      oldDelegate.terrain != terrain ||
      oldDelegate.extent != extent ||
      oldDelegate.style != style ||
      oldDelegate.projection.camera != projection.camera ||
      oldDelegate.projection.canvasWidth != projection.canvasWidth ||
      oldDelegate.projection.canvasHeight != projection.canvasHeight;
}

/// Resolves an asset definition's [MapAssetDefinition.iconId] to a glyph.
///
/// The mapping lives here rather than in the domain so the domain stays free of
/// Flutter, and so a later asset library can supply real artwork for the same
/// ids without the map architecture changing.
IconData _assetIcon(String definitionId) =>
    switch (MapAssetDefinition.byId(definitionId)?.iconId) {
      'park' => Icons.park_outlined,
      'forest' => Icons.forest_outlined,
      'grass' => Icons.grass_outlined,
      'terrain' => Icons.terrain_outlined,
      'landscape' => Icons.landscape_outlined,
      'volcano' => Icons.volcano_outlined,
      'cottage' => Icons.cottage_outlined,
      'holiday_village' => Icons.holiday_village_outlined,
      'location_city' => Icons.location_city_outlined,
      'castle' => Icons.castle_outlined,
      'tower' => Icons.account_balance_outlined,
      'bridge' => Icons.commit_outlined,
      'temple_buddhist' => Icons.temple_buddhist_outlined,
      'monument' => Icons.hardware_outlined,
      'anchor' => Icons.anchor_outlined,
      _ => Icons.circle_outlined,
    };

/// Draws character journeys as lines between consecutive stops.
///
/// The line is derived, never stored: every point comes from a
/// [MapJourneyStop.position] that a placed location already owns, converted
/// through [MapProjection] like every other drawn thing, so journeys zoom and
/// pan with the map and no pixel is ever written back.
class _JourneyPainter extends CustomPainter {
  const _JourneyPainter({
    required this.journeys,
    required this.projection,
    required this.color,
  });

  final List<MapJourney> journeys;
  final MapProjection projection;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.7);
    final head = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.85);
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.9);

    for (final journey in journeys) {
      if (!journey.isDrawable) continue;
      for (final (from, to) in journey.legs) {
        final start = projection.toCanvas(from.position);
        final end = projection.toCanvas(to.position);
        final a = Offset(start.x, start.y);
        final b = Offset(end.x, end.y);
        canvas.drawLine(a, b, line);
        _drawArrowHead(canvas, a, b, head);
      }
      for (final stop in journey.stops) {
        final point = projection.toCanvas(stop.position);
        canvas.drawCircle(Offset(point.x, point.y), 3, dot);
      }
    }
  }

  /// Marks the direction of travel halfway along a leg.
  ///
  /// Direction matters more than decoration here: a journey read backwards is
  /// a different story, so the cue is drawn even at small zoom levels.
  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Paint paint) {
    final delta = to - from;
    final length = delta.distance;
    if (length < 12) return;
    final direction = delta / length;
    final normal = Offset(-direction.dy, direction.dx);
    final centre = from + delta / 2;
    const reach = 6.0;
    const spread = 3.5;
    final path = Path()
      ..moveTo(centre.dx + direction.dx * reach, centre.dy + direction.dy * reach)
      ..lineTo(
        centre.dx - direction.dx * reach + normal.dx * spread,
        centre.dy - direction.dy * reach + normal.dy * spread,
      )
      ..lineTo(
        centre.dx - direction.dx * reach - normal.dx * spread,
        centre.dy - direction.dy * reach - normal.dy * spread,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_JourneyPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.journeys != journeys ||
      oldDelegate.projection.camera != projection.camera ||
      oldDelegate.projection.canvasWidth != projection.canvasWidth ||
      oldDelegate.projection.canvasHeight != projection.canvasHeight;
}

/// Resolves an overlay category's [MapOverlayKindLabel.shapeId] to a glyph.
///
/// Shape carries the category, not colour: the four overlay kinds stay
/// distinguishable in greyscale and to a reader who cannot separate the theme's
/// hues. Like [_assetIcon], the mapping lives in the view so the overlay domain
/// stays free of Flutter.
IconData _overlayIcon(MapOverlayKind kind) => switch (kind.shapeId) {
      'square' => Icons.square_outlined,
      'circle' => Icons.person_outline,
      'diamond' => Icons.change_history_outlined,
      'book' => Icons.menu_book_outlined,
      _ => Icons.circle_outlined,
    };

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({
    required this.color,
    required this.divisions,
    this.treatment = MapBackgroundTreatment.graticule,
    this.wash,
  });

  final Color color;
  final int divisions;
  final MapBackgroundTreatment treatment;

  /// A theme-derived wash for the parchment treatment. Never a literal colour.
  final Color? wash;

  @override
  void paint(Canvas canvas, Size size) {
    if (treatment == MapBackgroundTreatment.parchment) {
      // Concentric washes from the engine's own colour give the ground a worn
      // centre without a texture asset and without a literal colour.
      final tint = wash;
      if (tint != null) {
        final centre = Offset(size.width / 2, size.height / 2);
        for (var ring = 4; ring >= 1; ring--) {
          canvas.drawCircle(
            centre,
            size.longestSide * ring / 6,
            Paint()..color = tint.withValues(alpha: 0.05 * ring),
          );
        }
      }
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    for (var i = 1; i < divisions; i++) {
      final dx = size.width * i / divisions;
      final dy = size.height * i / divisions;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.divisions != divisions ||
      oldDelegate.treatment != treatment ||
      oldDelegate.wash != wash;
}

/// A toolbar tool. Selected state comes from the engine's selection token.
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final _MapPalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? palette.selection : palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? palette.primary : palette.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? palette.primary : palette.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(label, style: palette.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A terrain kind chip, showing the colour the engine derives for it.
class _SwatchChip extends StatelessWidget {
  const _SwatchChip({
    super.key,
    required this.palette,
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final _MapPalette palette;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? palette.selection : palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? palette.primary : palette.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: palette.outline),
                  ),
                ),
                const SizedBox(width: 6),
                Text(label, style: palette.label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The map's terrain legend: what the ground is made of, most of it first.
class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.palette,
    required this.entries,
    required this.style,
  });

  final _MapPalette palette;
  final List<MapLegendEntry> entries;
  final MapVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      key: const Key('map-legend'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Terrain',
              style: palette.ui.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final entry in entries)
                Row(
                  key: Key('map-legend-entry-${entry.kind.name}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: palette.terrainColor(entry.kind, style),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: palette.outline),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.label} ${(entry.coverage * 100).round()}%',
                      style: palette.label,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The overlay key: what each shape on the map means.
///
/// Shape and text carry the category. Colour is a reinforcement, never the only
/// signal, so the map stays readable in greyscale and to a reader who cannot
/// separate the theme's hues.
/// One counted thing in the world summary.
class _WorldCount extends StatelessWidget {
  const _WorldCount({
    required this.palette,
    required this.label,
    required this.value,
  });

  final _MapPalette palette;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$value $label',
        child: Row(
          key: Key('map-world-count-${label.toLowerCase()}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              style: palette.ui.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 4),
            Text(label, style: palette.label),
          ],
        ),
      );
}

class _OverlayLegend extends StatelessWidget {
  const _OverlayLegend({required this.palette, required this.filter});

  final _MapPalette palette;
  final MapOverlayFilter filter;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      key: const Key('map-overlay-legend'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overlay key',
              style: palette.ui.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final kind in MapOverlayKind.values)
                Row(
                  key: Key('map-overlay-legend-${kind.name}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _overlayIcon(kind),
                      size: 16,
                      color: filter.shows(kind)
                          ? palette.primary
                          : palette.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      filter.shows(kind) ? kind.label : '${kind.label} (hidden)',
                      style: palette.label,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// What a selected overlay stands for, and the way back to the Studio that owns
/// it.
///
/// The panel shows a reading of a record; it never edits one. Editing happens
/// in the owning Studio, which is exactly what [onOpen] is for.
class _OverlayDetail extends StatelessWidget {
  const _OverlayDetail({
    required this.palette,
    required this.item,
    required this.onFocus,
    required this.onOpen,
    required this.onClear,
  });

  final _MapPalette palette;
  final MapOverlayItem item;
  final VoidCallback onFocus;
  final VoidCallback? onOpen;
  final VoidCallback onClear;

  String get _openLabel => switch (item.kind) {
        MapOverlayKind.character => 'Open in Character Studio',
        MapOverlayKind.event => 'Open in Timeline Studio',
        MapOverlayKind.scene => 'Open in Manuscript',
        MapOverlayKind.location => 'Open in World Board',
      };

  @override
  Widget build(BuildContext context) {
    return _Panel(
      key: const Key('map-overlay-detail'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_overlayIcon(item.kind),
                  size: 18, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label,
                  key: const Key('map-overlay-detail-title'),
                  style: palette.ui.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('map-overlay-detail-close'),
                tooltip: 'Clear overlay selection',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            item.semanticLabel,
            key: const Key('map-overlay-detail-summary'),
            style: palette.body,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('map-overlay-focus-button'),
                onPressed: onFocus,
                icon: const Icon(Icons.my_location_outlined),
                label: const Text('Centre on map'),
              ),
              FilledButton.icon(
                key: const Key('map-overlay-open-button'),
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                label: Text(_openLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider({required this.palette});

  final _MapPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 24,
        color: palette.outline,
      );
}

/// Picks what the place tool drops onto the canvas.
class _PlacementChip extends StatelessWidget {
  const _PlacementChip({
    super.key,
    required this.palette,
    required this.kind,
    required this.selected,
    required this.onPressed,
  });

  final _MapPalette palette;
  final MapPlacementKind kind;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Place ${kind.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? palette.selection : palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? palette.primary : palette.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                kind == MapPlacementKind.location
                    ? Icons.place_outlined
                    : Icons.push_pin_outlined,
                size: 18,
                color: selected ? palette.primary : palette.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(kind.label, style: palette.label),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edits a name — and a marker's or region's category — on the canvas.
///
/// It writes nothing itself: it hands the values back and the Studio puts them
/// through [MapService], so revisioning and history behave exactly as they do
/// for a record edited anywhere else in AuthorOS.
class _InlineEditor extends StatefulWidget {
  const _InlineEditor({
    required this.palette,
    required this.item,
    required this.initialName,
    required this.initialCategory,
    required this.onSubmit,
    required this.onCancel,
  });

  final _MapPalette palette;
  final MapSelection item;
  final String initialName;
  final String initialCategory;
  final void Function(String name, String category) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_InlineEditor> createState() => _InlineEditorState();
}

class _InlineEditorState extends State<_InlineEditor> {
  late final TextEditingController nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController categoryController =
      TextEditingController(text: widget.initialCategory);

  @override
  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  String get _nameLabel =>
      widget.item.kind == MapSelectionKind.marker ? 'Label' : 'Name';

  String get _categoryLabel => switch (widget.item.kind) {
        MapSelectionKind.marker => 'Marker type',
        MapSelectionKind.region => 'Category',
        MapSelectionKind.location => 'Type',
      };

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.primary),
        ),
        child: Column(
          key: const Key('map-inline-editor'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('map-inline-name'),
              controller: nameController,
              autofocus: true,
              style: palette.body,
              decoration: InputDecoration(
                isDense: true,
                labelText: _nameLabel,
              ),
              onSubmitted: (value) =>
                  widget.onSubmit(value, categoryController.text),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('map-inline-category'),
              controller: categoryController,
              style: palette.body,
              decoration: InputDecoration(
                isDense: true,
                labelText: _categoryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('map-inline-cancel'),
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  key: const Key('map-inline-save'),
                  onPressed: () => widget.onSubmit(
                    nameController.text,
                    categoryController.text,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSelector extends StatelessWidget {
  const _MapSelector({
    required this.palette,
    required this.maps,
    required this.selectedId,
    required this.onSelected,
  });

  final _MapPalette palette;
  final List<MapSummary> maps;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      key: const Key('map-selector'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Maps', style: palette.ui.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final map in maps)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                key: Key('map-selector-${map.id}'),
                borderRadius: BorderRadius.circular(10),
                onTap: onSelected == null ? null : () => onSelected!(map.id),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: map.id == selectedId
                        ? palette.selection
                        : palette.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.outline),
                  ),
                  child: Text(
                    map.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: palette.body.copyWith(color: palette.onSurface),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectionDetail extends StatelessWidget {
  const _SelectionDetail({
    required this.palette,
    required this.data,
    required this.selection,
    required this.selectionCount,
    required this.onEdit,
  });

  final _MapPalette palette;
  final MapCanvasData data;
  final MapSelection? selection;
  final int selectionCount;
  final ValueChanged<MapSelection>? onEdit;

  @override
  Widget build(BuildContext context) {
    final current = selection;
    if (current == null && selectionCount > 1) {
      return _Panel(
        key: const Key('map-detail-multi'),
        palette: palette,
        child: Text(
          '$selectionCount items selected.',
          style: palette.ui.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }
    if (current == null) {
      return _Panel(
        key: const Key('map-detail-empty'),
        palette: palette,
        child: Text(
          'Select a location, region or marker to see its details.',
          style: palette.body,
        ),
      );
    }
    final (title, subtitle, body) = switch (current.kind) {
      MapSelectionKind.location => () {
          final item =
              data.locations.where((value) => value.id == current.id).first;
          return (item.name, item.locationType, item.description);
        }(),
      MapSelectionKind.region => () {
          final item =
              data.regions.where((value) => value.id == current.id).first;
          return (item.name, item.category, item.description);
        }(),
      MapSelectionKind.marker => () {
          final item =
              data.markers.where((value) => value.id == current.id).first;
          return (item.label, item.category, item.notes);
        }(),
    };
    return _Panel(
      key: const Key('map-detail'),
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: palette.ui.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('map-detail-edit-button'),
                onPressed: onEdit == null ? null : () => onEdit!(current),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: palette.label),
          ],
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body, style: palette.body),
          ],
        ],
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.palette, required this.onCreate});

  final _MapPalette palette;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('map-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          Icon(Icons.map_outlined, size: 56, color: palette.primary),
          const SizedBox(height: 16),
          Text(
            'No maps yet',
            style: palette.heading.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first map to begin building your world.',
            textAlign: TextAlign.center,
            style: palette.body,
          ),
          const SizedBox(height: 20),
          Semantics(
            button: true,
            label: 'Create the first map',
            child: FilledButton.icon(
              key: const Key('map-empty-create-button'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Map'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.palette, required this.child});

  final _MapPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.outline),
        ),
        child: child,
      );
}

/// What a create/edit dialog returns.
class _TextDraft {
  const _TextDraft({
    required this.name,
    required this.description,
    this.category = '',
  });

  final String name;
  final String description;
  final String category;
}

/// One dialog serves map, location, region and marker creation.
///
/// The editor authors by pointer; this dialog is the keyboard path, and the one
/// place a description is written.
class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({
    required this.title,
    required this.nameLabel,
    required this.keyPrefix,
    required this.confirmLabel,
    this.descriptionLabel = 'Description',
    this.showCategory = false,
    this.categoryLabel = 'Type',
    this.initialName = '',
    this.initialDescription = '',
  });

  final String title;
  final String nameLabel;
  final String descriptionLabel;
  final String keyPrefix;
  final String confirmLabel;
  final bool showCategory;
  final String categoryLabel;
  final String initialName;
  final String initialDescription;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late final TextEditingController nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController descriptionController =
      TextEditingController(text: widget.initialDescription);
  late final TextEditingController categoryController =
      TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: Key('${widget.keyPrefix}-dialog'),
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: Key('${widget.keyPrefix}-name'),
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: widget.nameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: Key('${widget.keyPrefix}-description'),
              controller: descriptionController,
              maxLines: 3,
              decoration:
                  InputDecoration(labelText: widget.descriptionLabel),
            ),
            if (widget.showCategory) ...[
              const SizedBox(height: 12),
              TextField(
                key: Key('${widget.keyPrefix}-category'),
                controller: categoryController,
                decoration: InputDecoration(labelText: widget.categoryLabel),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: Key('${widget.keyPrefix}-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: Key('${widget.keyPrefix}-confirm'),
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              _TextDraft(
                name: name,
                description: descriptionController.text.trim(),
                category: categoryController.text.trim(),
              ),
            );
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Every colour and type style Map Studio draws with, resolved from the engine.
class _MapPalette {
  const _MapPalette({
    required this.surface,
    required this.surfaceContainer,
    required this.canvasSurface,
    required this.regionFill,
    required this.marquee,
    required this.primary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.selection,
    required this.heading,
    required this.ui,
    required this.body,
    required this.label,
  });

  final Color surface;
  final Color surfaceContainer;
  final Color canvasSurface;
  final Color regionFill;
  final Color marquee;

  /// Terrain colour is *derived*, never declared.
  ///
  /// The Theme Engine publishes no "forest green", and Map Studio may not
  /// hard-code colour. So each terrain kind rotates the engine's own primary
  /// and adjusts its saturation and lightness. The ground tells itself apart at
  /// a glance, the map restyles itself with the theme, and no literal colour is
  /// written down anywhere.
  Color terrainColor(MapTerrainKind kind, MapVisualStyle style) {
    final base = HSLColor.fromColor(primary);
    final saturation =
        (base.saturation * kind.saturationFactor * style.saturation)
            .clamp(0.0, 1.0)
            .toDouble();
    final target = (base.lightness * kind.lightnessFactor).clamp(0.05, 0.95);
    final lightness = (0.5 + (target - 0.5) * style.contrast)
        .clamp(0.05, 0.95)
        .toDouble();
    return base
        .withHue(kind.hueShift % 360)
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor()
        .withValues(alpha: style.terrainOpacity);
  }
  final Color primary;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color selection;

  final TextStyle heading;
  final TextStyle ui;
  final TextStyle body;
  final TextStyle label;

  static _MapPalette of(BuildContext context) {
    final scope = StudioThemeScope.maybeOf(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    TextStyle text(
      ThemeTextRole role,
      ThemeColorRef ref,
      TextStyle? fallback,
    ) =>
        scope?.text(role, colorRef: ref) ??
        (fallback ?? const TextStyle()).copyWith(
          color: ref == ThemeColorRef.onSurfaceVariant
              ? scheme.onSurfaceVariant
              : scheme.onSurface,
        );
    final surfaceContainer = scope?.color(ThemeColorRef.surfaceContainer) ??
        scheme.surfaceContainerHighest;
    final selection =
        scope?.color(ThemeColorRef.selection) ?? scheme.primaryContainer;
    final highlight =
        scope?.color(ThemeColorRef.highlight) ?? scheme.primaryContainer;
    return _MapPalette(
      surface: scope?.color(ThemeColorRef.surface) ?? scheme.surface,
      surfaceContainer: surfaceContainer,
      // The canvas ground, the region fill and the marquee wash are the
      // engine's own surfaces at reduced opacity — never a literal colour.
      canvasSurface: surfaceContainer,
      regionFill: selection.withValues(alpha: 0.35),
      marquee: highlight.withValues(alpha: 0.25),
      primary: scope?.color(ThemeColorRef.primary) ?? scheme.primary,
      onSurface: scope?.color(ThemeColorRef.onSurface) ?? scheme.onSurface,
      onSurfaceVariant: scope?.color(ThemeColorRef.onSurfaceVariant) ??
          scheme.onSurfaceVariant,
      outline:
          scope?.color(ThemeColorRef.outlineVariant) ?? scheme.outlineVariant,
      selection: selection,
      heading: text(ThemeTextRole.heading, ThemeColorRef.onSurface,
          theme.textTheme.headlineSmall),
      ui: text(ThemeTextRole.ui, ThemeColorRef.onSurface,
          theme.textTheme.titleSmall),
      body: text(ThemeTextRole.body, ThemeColorRef.onSurfaceVariant,
          theme.textTheme.bodyMedium),
      label: text(ThemeTextRole.label, ThemeColorRef.onSurfaceVariant,
          theme.textTheme.labelMedium),
    );
  }
}
