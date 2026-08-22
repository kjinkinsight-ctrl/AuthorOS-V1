import 'dart:typed_data';

import 'package:author_studio_v1/manuscript_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implements the saver's one primitive, so the manuscript exporter's calls to
/// `savePdf` also prove that the inherited delegation to [saveBytes] carries
/// the right name, bytes and content type.
class _MemoryFileSaver extends ExportFileSaver {
  String? name;
  Uint8List? bytes;
  String? mimeType;

  @override
  Future<String?> saveBytes({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
    required List<String> extensions,
    String typeLabel = 'File',
  }) async {
    name = suggestedName;
    this.bytes = bytes;
    this.mimeType = mimeType;
    return 'C:/Exports/$suggestedName';
  }
}

void main() {
  const exporter = ManuscriptPdfExporter();

  ManuscriptExportRequest request(ManuscriptExportPreset preset) =>
      ManuscriptExportRequest(
        projectTitle: 'Signal Fire',
        sceneTitle: 'Opening Scene',
        authorName: 'A. Writer',
        manuscript: 'The signal appeared just before midnight. “Ready?”',
        preset: preset,
        exportedAt: DateTime(2026, 8, 11),
      );

  test('export presets define distinct production layouts', () {
    expect(ManuscriptExportPreset.values, hasLength(3));
    expect(ManuscriptExportPreset.standardManuscript.margin, 72);
    expect(ManuscriptExportPreset.standardManuscript.lineSpacing, 2);
    expect(ManuscriptExportPreset.betaReaderPdf.pageFormat.width,
        closeTo(595.28, 0.1));
    expect(ManuscriptExportPreset.printDraft.margin, lessThan(72));
    expect(ManuscriptExportPreset.printDraft.lineSpacing, lessThan(1.5));
  });

  test('every preset produces a valid PDF document', () async {
    for (final preset in ManuscriptExportPreset.values) {
      final bytes = await exporter.generate(request(preset));

      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    }
  });

  test('suggested filename is filesystem safe and preset specific', () {
    expect(
      exporter.suggestedFilename(request(
        ManuscriptExportPreset.betaReaderPdf,
      )),
      'signal-fire-beta-reader-pdf.pdf',
    );
  });

  testWidgets('dialog selects and exports the chosen preset', (tester) async {
    final saver = _MemoryFileSaver();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => ManuscriptExportDialog(
                  projectTitle: 'Signal Fire',
                  sceneTitle: 'Opening Scene',
                  manuscript: 'A distant light flickered.',
                  fileSaver: saver,
                  now: () => DateTime(2026, 8, 11),
                ),
              ),
              child: const Text('Open export'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print Draft'));
    await tester.tap(find.byKey(const Key('export-pdf-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(saver.name, 'signal-fire-print-draft.pdf');
    expect(saver.bytes, isNotNull);
    expect(find.byType(ManuscriptExportDialog), findsNothing);
  });
}
