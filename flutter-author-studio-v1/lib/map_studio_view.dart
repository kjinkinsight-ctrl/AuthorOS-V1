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

import 'map_service.dart';
import 'onboarding.dart';
import 'theme/flutter/authoros_theme.dart';
import 'theme/theme_tokens.dart';

/// The Map Studio workspace.
class MapStudioView extends StatefulWidget {
  const MapStudioView({
    super.key,
    required this.project,
    this.service,
  });

  final StarterProject project;

  /// An explicit service, for tests that drive the Studio against a fixture
  /// database. When absent the Studio binds to the application database.
  final MapService? service;

  @override
  State<MapStudioView> createState() => _MapStudioViewState();
}

class _MapStudioViewState extends State<MapStudioView> {
  late final MapService service;

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

  @override
  void initState() {
    super.initState();
    service = widget.service ?? MapService.forProject(widget.project.id);
    _load();
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
      if (!mounted) return;
      setState(() {
        maps = loaded;
        selectedMapId = active;
        canvas = data;
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
        ),
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
      };

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
enum _DragMode { none, marquee, pan, item, point, region, place }

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
      };
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
        widget.onPlace(
          _clamp(current.toMap(to.dx, to.dy)),
          widget.placementKind,
        );
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
    if (widget.tool == MapEditorTool.place) {
      widget.onPlace(
        _clamp(current.toMap(details.localPosition.dx, details.localPosition.dy)),
        widget.placementKind,
      );
      return;
    }
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
        MapLayer.selection => _selectionLayer(projection),
        MapLayer.interaction => _interactionLayer(projection),
      };

  List<Widget> _baseLayer(MapProjection projection) {
    final palette = widget.palette;
    return [
      Positioned.fill(
        child: CustomPaint(
          painter: _MapGridPainter(color: palette.outline, divisions: 8),
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
        child: GestureDetector(
          key: const Key('map-canvas-surface'),
          behavior: HitTestBehavior.translucent,
          // The pointer's own travel is the edit, so the drag starts where the
          // finger went down rather than where the slop was crossed: what the
          // writer moves by is what the record moves by.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: _onBackgroundTapUp,
          onPanStart: _onBackgroundPanStart,
          onPanUpdate: _onBackgroundPanUpdate,
          onPanEnd: _onBackgroundPanEnd,
        ),
      ),
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
              child: GestureDetector(
                key: Key('map-geometry-handle-$index'),
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
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
      child: GestureDetector(
        key: Key('map-region-${region.id}'),
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
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
        child: GestureDetector(
          key: key,
          dragStartBehavior: DragStartBehavior.down,
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

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.color, required this.divisions});

  final Color color;
  final int divisions;

  @override
  void paint(Canvas canvas, Size size) {
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
      oldDelegate.color != color || oldDelegate.divisions != divisions;
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
