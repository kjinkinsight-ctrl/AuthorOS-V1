/// Map Studio Phase 6 — presentation mode, and the raster renderer.
///
/// The screen paints the same [MapDrawing] that the SVG and PDF renderers
/// paint. That is the whole point of this file: a presentation preview cannot
/// show the author one map and export another, because there is one drawing and
/// three painters, not three descriptions of a map.
///
/// PNG is produced here rather than in `map_export.dart` because rasterising
/// needs `dart:ui`, and the export domain stays free of Flutter. It records the
/// drawing into a [PictureRecorder] rather than capturing a widget, so a PNG can
/// be produced — and inspected — without anything being on screen.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'manuscript_export.dart' show ExportFileSaver;
import 'map_export.dart';
import 'map_reader.dart';

export 'map_export.dart';

/// Paints a drawing onto a Flutter canvas.
///
/// The switch mirrors the SVG and PDF backends primitive for primitive. Where
/// they differ, the drawing is the arbiter.
class MapDrawingPainter extends CustomPainter {
  const MapDrawingPainter({required this.drawing});

  final MapDrawing drawing;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / drawing.width;
    if (scale != 1) canvas.scale(scale);

    for (final primitive in drawing.ordered) {
      switch (primitive) {
        case MapDrawRect():
          final rect = Rect.fromLTWH(
            primitive.left,
            primitive.top,
            primitive.width,
            primitive.height,
          );
          if (primitive.fill != null) {
            canvas.drawRect(
              rect,
              Paint()..color = _colour(primitive.fill!, primitive.opacity),
            );
          }
          if (primitive.stroke != null) {
            canvas.drawRect(
              rect,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = primitive.strokeWidth
                ..color = _colour(primitive.stroke!, primitive.opacity),
            );
          }
        case MapDrawCircle():
          final centre = Offset(primitive.x, primitive.y);
          if (primitive.fill != null) {
            canvas.drawCircle(
              centre,
              primitive.radius,
              Paint()..color = _colour(primitive.fill!, 1),
            );
          }
          if (primitive.stroke != null) {
            canvas.drawCircle(
              centre,
              primitive.radius,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = primitive.strokeWidth
                ..color = _colour(primitive.stroke!, 1),
            );
          }
        case MapDrawPolygon():
          if (primitive.points.length < 4) continue;
          final path = Path()
            ..moveTo(primitive.points[0], primitive.points[1]);
          for (var index = 2; index + 1 < primitive.points.length; index += 2) {
            path.lineTo(primitive.points[index], primitive.points[index + 1]);
          }
          if (primitive.closed) path.close();
          if (primitive.fill != null) {
            canvas.drawPath(
              path,
              Paint()..color = _colour(primitive.fill!, primitive.opacity),
            );
          }
          if (primitive.stroke != null) {
            canvas.drawPath(
              primitive.dashed ? _dash(path) : path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = primitive.strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..strokeCap = StrokeCap.round
                ..color = _colour(primitive.stroke!, primitive.opacity),
            );
          }
        case MapDrawText():
          final painter = TextPainter(
            text: TextSpan(
              text: primitive.text,
              style: TextStyle(
                fontSize: primitive.size,
                fontWeight:
                    primitive.bold ? FontWeight.w700 : FontWeight.w400,
                color: _colour(primitive.colour, primitive.opacity),
                // The same family the SVG and PDF backends ask for, so a map
                // exported three ways is set in one typeface rather than three.
                fontFamily: 'Helvetica',
                fontFamilyFallback: const ['Arial', 'Liberation Sans', 'Roboto'],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final dx = switch (primitive.align) {
            MapTextAlign.start => primitive.x,
            MapTextAlign.centre => primitive.x - painter.width / 2,
            MapTextAlign.end => primitive.x - painter.width,
          };
          // SVG and PDF place text on its baseline; Flutter places it from the
          // top. Aligning to the actual baseline is what stops the same map
          // printing its labels a descender lower in one format than another.
          final baseline =
              painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
          painter.paint(canvas, Offset(dx, primitive.y - baseline));
      }
    }
  }

  /// Dashes a path the same way the SVG backend's `stroke-dasharray` does, so
  /// a hidden road looks hidden in every format.
  Path _dash(Path source) {
    const on = 6.0;
    const off = 4.0;
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + on).clamp(0.0, metric.length);
        dashed.addPath(metric.extractPath(distance, end), Offset.zero);
        distance = end + off;
      }
    }
    return dashed;
  }

  static Color _colour(int argb, double opacity) =>
      Color(argb).withValues(alpha: ((argb >> 24 & 0xFF) / 255) * opacity);

  @override
  bool shouldRepaint(MapDrawingPainter oldDelegate) =>
      oldDelegate.drawing != drawing;
}

/// Rasterises a drawing to PNG bytes.
///
/// Deterministic and headless: the same drawing at the same pixel ratio always
/// produces the same image, and no widget need be mounted to produce one.
class MapPngRenderer {
  const MapPngRenderer();

  Future<Uint8List> render(
    MapDrawing drawing, {
    double pixelRatio = 1,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);
    MapDrawingPainter(drawing: drawing).paint(
      canvas,
      Size(drawing.width, drawing.height),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (drawing.width * pixelRatio).round(),
      (drawing.height * pixelRatio).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    if (data == null) {
      throw StateError('The map could not be rasterised.');
    }
    return data.buffer.asUint8List();
  }
}

/// The map, shown as it will be exported and nothing else.
///
/// No toolbar, no panels, no selection: presentation mode is the finished map.
class MapPresentationSurface extends StatelessWidget {
  const MapPresentationSurface({
    super.key,
    required this.drawing,
    this.semanticsLabel = '',
  });

  final MapDrawing drawing;

  /// What a screen reader is told this map shows. A picture of a world is
  /// useless without it, so it is required in practice even where the framework
  /// would allow silence.
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticsLabel.isEmpty ? 'Map' : semanticsLabel,
      child: AspectRatio(
        aspectRatio: drawing.width / drawing.height,
        child: CustomPaint(
          key: const Key('map-presentation-surface'),
          painter: MapDrawingPainter(drawing: drawing),
          isComplex: true,
        ),
      ),
    );
  }
}

/// The finished map, full screen, with the editor gone.
///
/// Everything an author sees here is the drawing an export would produce, so
/// "this is what my map will look like" is a statement the Studio can actually
/// make.
class MapPresentationPage extends StatelessWidget {
  const MapPresentationPage({
    super.key,
    required this.drawing,
    required this.title,
    required this.background,
    required this.onClose,
    this.semanticsLabel = '',
    this.notice = '',
  });

  final MapDrawing drawing;
  final String title;
  final Color background;
  final VoidCallback onClose;
  final String semanticsLabel;

  /// Anything the author should know about what is on the map — a reader level
  /// in force, a decoration omitted for want of canonical data.
  final String notice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          },
          child: Actions(
            actions: {
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (intent) {
                  onClose();
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: MapPresentationSurface(
                        drawing: drawing,
                        semanticsLabel: semanticsLabel,
                      ),
                    ),
                  ),
                  if (notice.isNotEmpty)
                    Positioned(
                      left: 16,
                      bottom: 12,
                      child: Text(
                        notice,
                        key: const Key('map-presentation-notice'),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      key: const Key('map-presentation-close'),
                      tooltip: 'Leave presentation mode',
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chooses a format and a preset, renders, and saves.
///
/// The rendering is the same drawing the author has been looking at; the dialog
/// only decides which painter writes it out and where the bytes go.
class MapExportDialog extends StatefulWidget {
  const MapExportDialog({
    super.key,
    required this.drawing,
    required this.request,
    required this.saver,
    this.onExported,
  });

  final MapDrawing drawing;
  final MapExportRequest request;
  final ExportFileSaver saver;

  /// Called with the saved path, or an empty string where the platform does not
  /// report one.
  final ValueChanged<String>? onExported;

  @override
  State<MapExportDialog> createState() => _MapExportDialogState();
}

class _MapExportDialogState extends State<MapExportDialog> {
  late MapExportFormat format = widget.request.format;
  late MapExportPreset preset = widget.request.preset;
  bool working = false;
  String? error;
  String? saved;

  Future<void> _export() async {
    setState(() {
      working = true;
      error = null;
      saved = null;
    });
    try {
      final request = MapExportRequest(
        presentation: widget.request.presentation,
        canvas: widget.request.canvas,
        overlays: widget.request.overlays,
        world: widget.request.world,
        palette: widget.request.palette,
        preset: preset,
        format: format,
        landscape: widget.request.landscape,
      );
      final drawing = const MapDrawingBuilder().build(request);
      final bytes = switch (format) {
        MapExportFormat.svg => Uint8List.fromList(
            const MapSvgRenderer().render(drawing).codeUnits,
          ),
        MapExportFormat.pdf => await const MapPdfRenderer().render(
            drawing,
            title: request.presentation.title,
          ),
        MapExportFormat.png => await const MapPngRenderer().render(
            drawing,
            pixelRatio: preset.pixelRatio,
          ),
        MapExportFormat.json => Uint8List.fromList(
            const MapJsonExporter().render(request).codeUnits,
          ),
      };
      final path = await widget.saver.saveBytes(
        suggestedName: request.suggestedFileName,
        bytes: bytes,
        mimeType: format.mimeType,
        extensions: [format.extension],
        typeLabel: format.label,
      );
      if (!mounted) return;
      setState(() {
        working = false;
        saved = path ?? '';
      });
      widget.onExported?.call(path ?? '');
    } on Object catch (failure) {
      if (!mounted) return;
      setState(() {
        working = false;
        error = '$failure';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gaps = widget.request.presentation.gaps;
    return AlertDialog(
      key: const Key('map-export-dialog'),
      title: const Text('Export map'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Format', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: [
                for (final value in MapExportFormat.values)
                  ChoiceChip(
                    key: Key('map-export-format-${value.name}'),
                    label: Text(value.label),
                    selected: format == value,
                    onSelected: (_) => setState(() => format = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Preset', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: [
                for (final value in MapExportPreset.values)
                  ChoiceChip(
                    key: Key('map-export-preset-${value.name}'),
                    label: Text(value.label),
                    selected: preset == value,
                    onSelected: (_) => setState(() => preset = value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preset.description,
              key: const Key('map-export-preset-description'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (gaps.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final gap in gaps)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    gap.message,
                    key: Key('map-export-gap-${gap.element}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                'The map could not be exported: $error',
                key: const Key('map-export-error'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (saved != null) ...[
              const SizedBox(height: 12),
              Text(
                saved!.isEmpty ? 'Map exported.' : 'Map exported to $saved',
                key: const Key('map-export-saved'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('map-export-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          key: const Key('map-export-run'),
          onPressed: working ? null : _export,
          icon: const Icon(Icons.download_outlined),
          label: Text(working ? 'Exporting…' : 'Export'),
        ),
      ],
    );
  }
}

/// Authoring a reveal point: the one Phase 6 control that changes the story.
///
/// Everything else in Phase 6 is a view setting — a theme, a decoration, a
/// spoiler level — that can be changed freely because changing it changes
/// nothing. This one writes a canonical relationship, so it is deliberately
/// heavier than a toggle: it names the place and the moment in a full sentence,
/// says in as many words that this is story metadata, and requires a second
/// press. No reveal is ever created as a side effect of anything.
class MapRevealPointDialog extends StatefulWidget {
  const MapRevealPointDialog({
    super.key,
    required this.placeName,
    required this.targets,
  });

  /// The thing being revealed, named in the confirmation.
  final String placeName;

  /// The manuscript nodes this reveal may point at, in reading order.
  final List<MapRevealPoint> targets;

  @override
  State<MapRevealPointDialog> createState() => _MapRevealPointDialogState();
}

class _MapRevealPointDialogState extends State<MapRevealPointDialog> {
  MapRevealPoint? choice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = choice;
    return AlertDialog(
      key: const Key('map-reveal-dialog'),
      title: const Text('Add a reveal point'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This changes your story, not just this map. It records that '
              '${widget.placeName} becomes known to the reader at the point '
              'you choose, as an ordinary connection other Studios can see.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (widget.targets.isEmpty)
              Text(
                'This project has no chapters or scenes yet, so there is '
                'nowhere for a reveal to point.',
                key: const Key('map-reveal-no-targets'),
                style: theme.textTheme.bodySmall,
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final target in widget.targets)
                      ListTile(
                        key: Key('map-reveal-target-${target.nodeId}'),
                        selected: selected?.nodeId == target.nodeId,
                        leading: Icon(
                          selected?.nodeId == target.nodeId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(target.label),
                        subtitle: Text(target.nodeType),
                        onTap: () => setState(() => choice = target),
                      ),
                  ],
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Text(
                '${widget.placeName} is revealed in ${selected.label}.',
                key: const Key('map-reveal-summary'),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('map-reveal-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('map-reveal-confirm'),
          // Disabled until something is chosen: there is no default reveal
          // point, because guessing one would be inferring a reveal.
          onPressed: selected == null
              ? null
              : () => Navigator.of(context).pop(selected.nodeId),
          child: const Text('Add reveal point'),
        ),
      ],
    );
  }
}
