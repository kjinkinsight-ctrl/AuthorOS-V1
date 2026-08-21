/// Map Studio Phase 1 — the writer-facing workspace.
///
/// The Studio owns no store, no theme and no business rules. Every read and
/// write goes through [MapService], and every colour and type style resolves
/// through the Theme Engine's [StudioThemeScope] under [StudioId.map]. There are
/// no literal colours here and no locally-built `ThemeData`.
library;

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
  MapSelection? selection;

  @override
  void initState() {
    super.initState();
    service = widget.service ?? MapService.forProject(widget.project.id);
    _load();
  }

  MapSummary? get selectedMap =>
      maps.where((map) => map.id == selectedMapId).firstOrNull;

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
        if (selection != null && !_selectionStillPresent(data)) {
          selection = null;
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

  bool _selectionStillPresent(MapCanvasData? data) {
    final current = selection;
    if (current == null || data == null) return false;
    return switch (current.kind) {
      MapSelectionKind.location =>
        data.locations.any((item) => item.id == current.id),
      MapSelectionKind.region =>
        data.regions.any((item) => item.id == current.id),
      MapSelectionKind.marker =>
        data.markers.any((item) => item.id == current.id),
    };
  }

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
      selection = null;
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
      selection = MapSelection(
        kind: MapSelectionKind.location,
        id: created.id,
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
      selection = MapSelection(kind: MapSelectionKind.region, id: created.id);
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
      selection = MapSelection(kind: MapSelectionKind.marker, id: created.id);
      await _load();
    });
  }

  /// Spreads new pins across the map rather than stacking them on the centre.
  ///
  /// Phase 2 replaces this with placement by tap; Phase 1 only needs every pin
  /// to land somewhere legible and stay there across a reload.
  MapPosition _nextPosition(MapSummary map, int index) {
    final extent = map.extent;
    final column = index % 4;
    final row = (index ~/ 4) % 4;
    return MapPosition(
      extent.width * (0.2 + column * 0.2),
      extent.height * (0.2 + row * 0.2),
    );
  }

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
                        selection = null;
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
        const SizedBox(height: 12),
        _MapCanvas(
          data: data,
          palette: palette,
          // Phase 1 always frames the whole map; Phase 2 drives this camera.
          camera: MapCamera.identity,
          selection: selection,
          onSelected: (value) => setState(
            () => selection = selection == value ? null : value,
          ),
        ),
        const SizedBox(height: 12),
        _SelectionDetail(palette: palette, data: data, selection: selection),
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

  Widget _buildToolbar(BuildContext context, _MapPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
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
    );
  }
}

/// The map surface.
///
/// The canvas holds no state and reads no store: it is handed [MapCanvasData]
/// and projects every stored map-space position onto whatever pixel size the
/// layout gives it, so nothing here assumes a screen size. Zoom and pan enter
/// through [MapCamera] in Phase 2 without changing this contract.
class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.data,
    required this.palette,
    this.selection,
    this.onSelected,
    this.camera = MapCamera.identity,
  });

  final MapCanvasData data;
  final _MapPalette palette;
  final MapSelection? selection;
  final ValueChanged<MapSelection>? onSelected;
  final MapCamera camera;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = data.extent;
        final available =
            constraints.hasBoundedWidth ? constraints.maxWidth : 720.0;
        final width = available.clamp(280.0, 1200.0);
        final height = extent.width == 0
            ? width
            : (width * (extent.height / extent.width)).clamp(240.0, 720.0);
        final projection = MapProjection(
          extent: extent,
          canvasWidth: width,
          canvasHeight: height,
          camera: camera,
        );
        return Container(
          key: const Key('map-canvas'),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: palette.canvasSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MapGridPainter(
                    color: palette.outline,
                    divisions: 8,
                  ),
                ),
              ),
              for (final region in data.regions)
                _buildRegion(region, projection),
              for (final location in data.locations)
                _buildPin(
                  key: Key('map-location-${location.id}'),
                  projection: projection,
                  position: location.position,
                  label: location.name,
                  icon: Icons.place,
                  selected: selection ==
                      MapSelection(
                        kind: MapSelectionKind.location,
                        id: location.id,
                      ),
                  onTap: () => onSelected?.call(
                    MapSelection(
                      kind: MapSelectionKind.location,
                      id: location.id,
                    ),
                  ),
                ),
              for (final marker in data.markers)
                _buildPin(
                  key: Key('map-marker-${marker.id}'),
                  projection: projection,
                  position: marker.position,
                  label: marker.label,
                  icon: Icons.push_pin,
                  selected: selection ==
                      MapSelection(
                        kind: MapSelectionKind.marker,
                        id: marker.id,
                      ),
                  onTap: () => onSelected?.call(
                    MapSelection(
                      kind: MapSelectionKind.marker,
                      id: marker.id,
                    ),
                  ),
                ),
              if (data.isEmpty)
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegion(MapRegionView region, MapProjection projection) {
    final box = region.geometry.boundingBox;
    if (box == null) return const SizedBox.shrink();
    final topLeft = projection.toCanvas(box.topLeft);
    final bottomRight = projection.toCanvas(box.bottomRight);
    final selected =
        selection == MapSelection(kind: MapSelectionKind.region, id: region.id);
    return Positioned(
      left: topLeft.x,
      top: topLeft.y,
      width: (bottomRight.x - topLeft.x).abs().clamp(8.0, double.infinity),
      height: (bottomRight.y - topLeft.y).abs().clamp(8.0, double.infinity),
      child: GestureDetector(
        key: Key('map-region-${region.id}'),
        onTap: () => onSelected?.call(
          MapSelection(kind: MapSelectionKind.region, id: region.id),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: palette.regionFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? palette.primary : palette.outline,
              width: selected ? 2 : 1,
            ),
          ),
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.all(6),
          child: Text(
            region.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: palette.label,
          ),
        ),
      ),
    );
  }

  Widget _buildPin({
    required Key key,
    required MapProjection projection,
    required MapPosition position,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final point = projection.toCanvas(position);
    return Positioned(
      left: point.x - 60,
      top: point.y - 16,
      width: 120,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: key,
          onTap: onTap,
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
  });

  final _MapPalette palette;
  final MapCanvasData data;
  final MapSelection? selection;

  @override
  Widget build(BuildContext context) {
    final current = selection;
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
          Text(title, style: palette.ui.copyWith(fontWeight: FontWeight.w600)),
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
/// Phase 1 deliberately keeps authoring to a name, a description and an
/// optional category; the richer editors belong to Phase 2.
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
    return _MapPalette(
      surface: scope?.color(ThemeColorRef.surface) ?? scheme.surface,
      surfaceContainer: surfaceContainer,
      // The canvas ground and region fill are the engine's own surfaces at
      // reduced opacity — never a literal colour.
      canvasSurface: surfaceContainer,
      regionFill: selection.withValues(alpha: 0.35),
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
