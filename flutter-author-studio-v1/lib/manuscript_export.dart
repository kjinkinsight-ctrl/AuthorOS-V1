
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

import 'local_image.dart';

enum ManuscriptExportPreset {
  standardManuscript,
  betaReaderPdf,
  printDraft,
}

extension ManuscriptExportPresetDetails on ManuscriptExportPreset {
  String get label => switch (this) {
        ManuscriptExportPreset.standardManuscript => 'Standard Manuscript',
        ManuscriptExportPreset.betaReaderPdf => 'Beta Reader PDF',
        ManuscriptExportPreset.printDraft => 'Print Draft',
      };

  String get description => switch (this) {
        ManuscriptExportPreset.standardManuscript =>
          'US Letter, double-spaced serif type, one-inch margins.',
        ManuscriptExportPreset.betaReaderPdf =>
          'Readable A4 copy with project header and beta-reader marking.',
        ManuscriptExportPreset.printDraft =>
          'Ink-conscious US Letter layout with compact spacing and margins.',
      };

  PdfPageFormat get pageFormat => switch (this) {
        ManuscriptExportPreset.betaReaderPdf => PdfPageFormat.a4,
        _ => PdfPageFormat.letter,
      };

  double get margin => switch (this) {
        ManuscriptExportPreset.printDraft => 43.2,
        _ => 72,
      };

  double get fontSize => switch (this) {
        ManuscriptExportPreset.standardManuscript => 12,
        ManuscriptExportPreset.betaReaderPdf => 11,
        ManuscriptExportPreset.printDraft => 10.5,
      };

  double get lineSpacing => switch (this) {
        ManuscriptExportPreset.standardManuscript => 2,
        ManuscriptExportPreset.betaReaderPdf => 1.45,
        ManuscriptExportPreset.printDraft => 1.15,
      };
}

class ManuscriptExportRequest {
  const ManuscriptExportRequest({
    required this.projectTitle,
    required this.sceneTitle,
    required this.authorName,
    required this.manuscript,
    required this.preset,
    required this.exportedAt,
  });

  final String projectTitle;
  final String sceneTitle;
  final String authorName;
  final String manuscript;
  final ManuscriptExportPreset preset;
  final DateTime exportedAt;
}

class ManuscriptPdfExporter {
  const ManuscriptPdfExporter();

  Future<Uint8List> generate(ManuscriptExportRequest request) async {
    final isPrintDraft = request.preset == ManuscriptExportPreset.printDraft;
    final regularFont = pw.Font.ttf(await rootBundle.load(isPrintDraft
        ? 'assets/fonts/Inter-400.ttf'
        : 'assets/fonts/Merriweather-400.ttf'));
    final boldFont = pw.Font.ttf(await rootBundle.load(isPrintDraft
        ? 'assets/fonts/Inter-700.ttf'
        : 'assets/fonts/Merriweather-700.ttf'));
    final document = pw.Document(
      title: request.projectTitle,
      author: request.authorName,
      creator: 'Author Studio',
      subject: request.preset.label,
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    final preset = request.preset;

    document.addPage(
      pw.MultiPage(
        pageFormat: preset.pageFormat,
        margin: pw.EdgeInsets.all(preset.margin),
        header: (context) {
          if (context.pageNumber == 1 ||
              preset == ManuscriptExportPreset.standardManuscript) {
            return pw.SizedBox();
          }
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border:
                  pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(request.projectTitle,
                    style: const pw.TextStyle(fontSize: 8)),
                if (preset == ManuscriptExportPreset.betaReaderPdf)
                  pw.Text('BETA READER COPY',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      )),
              ],
            ),
          );
        },
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(
              height: preset == ManuscriptExportPreset.standardManuscript
                  ? 96
                  : 20),
          pw.Text(
            request.projectTitle,
            style: pw.TextStyle(
              fontSize:
                  preset == ManuscriptExportPreset.standardManuscript ? 18 : 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(request.sceneTitle,
              style: pw.TextStyle(
                fontSize: preset.fontSize + 1,
                fontWeight: pw.FontWeight.bold,
              )),
          if (request.authorName.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('by ${request.authorName.trim()}',
                style: pw.TextStyle(fontSize: preset.fontSize)),
          ],
          pw.SizedBox(height: 28),
          pw.Text(
            request.manuscript.trim().isEmpty
                ? '[No manuscript text]'
                : request.manuscript.trim(),
            style: pw.TextStyle(
              fontSize: preset.fontSize,
              lineSpacing: preset.lineSpacing,
            ),
            textAlign: pw.TextAlign.left,
          ),
        ],
      ),
    );

    return document.save();
  }

  String suggestedFilename(ManuscriptExportRequest request) {
    final safeTitle = request.projectTitle
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final safePreset = request.preset.label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '${safeTitle.isEmpty ? 'manuscript' : safeTitle}-$safePreset.pdf';
  }
}

/// Where an export ends up.
///
/// Widened in Phase 6 from PDF-only to any file an export produces: a map is
/// exported as PNG, SVG, PDF or JSON, and a second saving mechanism beside this
/// one would be exactly the duplication the architecture forbids. [savePdf] is
/// kept as the name the manuscript exporter already calls, delegating to
/// [saveBytes], so nothing that worked before changes.
abstract class ExportFileSaver {
  const ExportFileSaver();

  Future<String?> saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
    required List<String> extensions,
    String typeLabel = 'File',
  });

  Future<String?> savePdf({
    required String suggestedName,
    required Uint8List bytes,
  }) =>
      saveBytes(
        suggestedName: suggestedName,
        bytes: bytes,
        mimeType: 'application/pdf',
        extensions: const ['pdf'],
        typeLabel: 'PDF document',
      );
}

/// Saves through the platform's own file dialog.
///
/// Works on the web build as well as the desktop ones, despite the name: the
/// web implementation of `file_selector` returns a placeholder location and
/// `XFile.saveTo` triggers a browser download with the suggested name. No
/// second saving path is needed for the web, and none exists.
class NativeExportFileSaver extends ExportFileSaver {
  const NativeExportFileSaver();

  @override
  Future<String?> saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
    required List<String> extensions,
    String typeLabel = 'File',
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(
          label: typeLabel,
          extensions: extensions,
          mimeTypes: [mimeType],
        ),
      ],
    );
    if (location == null) {
      return null;
    }

    final file = XFile.fromData(
      bytes,
      mimeType: mimeType,
      name: suggestedName,
    );
    await file.saveTo(location.path);
    return location.path;
  }
}

class ManuscriptExportDialog extends StatefulWidget {
  const ManuscriptExportDialog({
    super.key,
    required this.projectTitle,
    required this.sceneTitle,
    required this.manuscript,
    this.exporter = const ManuscriptPdfExporter(),
    this.fileSaver = const NativeExportFileSaver(),
    this.now,
  });

  final String projectTitle;
  final String sceneTitle;
  final String manuscript;
  final ManuscriptPdfExporter exporter;
  final ExportFileSaver fileSaver;
  final DateTime Function()? now;

  @override
  State<ManuscriptExportDialog> createState() => _ManuscriptExportDialogState();
}

class _ManuscriptExportDialogState extends State<ManuscriptExportDialog> {
  final authorController = TextEditingController();
  ManuscriptExportPreset selected = ManuscriptExportPreset.standardManuscript;
  bool exporting = false;
  String? error;
  String authorDisplayName = '';
  String authorFocus = '';
  String authorBio = '';
  String authorAvatarPath = '';

  @override
  void initState() {
    super.initState();
    _loadAuthorProfile();
  }

  Future<void> _loadAuthorProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('author_studio.profile.name') ?? '';
    final focus = prefs.getString('author_studio.profile.focus') ?? '';
    final bio = prefs.getString('author_studio.profile.bio') ?? '';
    final avatarPath =
        prefs.getString('author_studio.profile.avatar_path') ?? '';
    if (!mounted) {
      return;
    }
    setState(() {
      authorDisplayName = name;
      authorFocus = focus;
      authorBio = bio;
      authorAvatarPath = avatarPath;
      if (authorController.text.isEmpty) {
        authorController.text = name;
      }
    });
  }

  @override
  void dispose() {
    authorController.dispose();
    super.dispose();
  }

  Future<void> export() async {
    setState(() {
      exporting = true;
      error = null;
    });

    try {
      final request = ManuscriptExportRequest(
        projectTitle: widget.projectTitle,
        sceneTitle: widget.sceneTitle,
        authorName: authorController.text,
        manuscript: widget.manuscript,
        preset: selected,
        exportedAt: widget.now?.call() ?? DateTime.now(),
      );
      final bytes = await widget.exporter.generate(request);
      final path = await widget.fileSaver.savePdf(
        suggestedName: widget.exporter.suggestedFilename(request),
        bytes: bytes,
      );
      if (mounted && path != null) {
        Navigator.of(context).pop(path);
      } else if (mounted) {
        setState(() => exporting = false);
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          exporting = false;
          error = 'Export failed. $exception';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export manuscript'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.7),
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: LocalImage(
                        path: authorAvatarPath,
                        width: 54,
                        height: 54,
                        fallback: Container(
                          alignment: Alignment.center,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            authorDisplayName.trim().isEmpty
                                ? 'A'
                                : authorDisplayName
                                    .trim()
                                    .split(RegExp(r'\s+'))
                                    .first[0]
                                    .toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorDisplayName.trim().isEmpty
                                ? 'Author identity not set'
                                : authorDisplayName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (authorFocus.isNotEmpty)
                            Text(
                              authorFocus,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          const SizedBox(height: 4),
                          if (authorBio.isNotEmpty)
                            Text(
                              authorBio,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white60,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('export-author-field'),
                controller: authorController,
                decoration: const InputDecoration(
                  labelText: 'Author name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Preset', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<ManuscriptExportPreset>(
                segments: ManuscriptExportPreset.values
                    .map(
                      (preset) => ButtonSegment<ManuscriptExportPreset>(
                        value: preset,
                        label: Text(preset.label),
                        tooltip: preset.description,
                      ),
                    )
                    .toList(),
                selected: <ManuscriptExportPreset>{selected},
                onSelectionChanged: exporting
                    ? null
                    : (selection) => setState(() => selected = selection.first),
                multiSelectionEnabled: false,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(color: Colors.red.shade300)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: exporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('export-pdf-button'),
          onPressed: exporting ? null : export,
          icon: exporting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(exporting ? 'Exporting…' : 'Export PDF'),
        ),
      ],
    );
  }
}
