/// Book Studio Phase 1 — export targets and file saving.
///
/// [BookFileSaver] is a new interface rather than an extension of
/// `ExportFileSaver` in `lib/manuscript_export.dart`. That is deliberate:
/// `test/manuscript_export_test.dart` declares a fake that `implements
/// ExportFileSaver`, so adding any member to that interface would break it at
/// compile time. The concrete `NativeExportFileSaver` implements both, which a
/// class may safely do; the abstract contract the test depends on is untouched.
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;

/// A format the book can be exported as.
enum BookExportFormat {
  /// Mirrored margins, binding allowance, and blank pages where a printer
  /// expects them.
  printPdf,

  /// The same layout engine, set for reading on a screen: no mirroring, no
  /// blank versos.
  digitalPdf,

  /// Reflowable ebook.
  epub,

  /// Word, for an editor, an agent, or the author's own revision pass.
  docx,

  /// Plain text.
  txt,
}

extension BookExportFormatX on BookExportFormat {
  String get label => switch (this) {
        BookExportFormat.printPdf => 'Print-ready PDF',
        BookExportFormat.digitalPdf => 'Digital PDF',
        BookExportFormat.epub => 'EPUB',
        BookExportFormat.docx => 'Word (DOCX)',
        BookExportFormat.txt => 'Plain text',
      };

  String get description => switch (this) {
        BookExportFormat.printPdf =>
          'Mirrored margins, binding allowance and blank pages, ready for a '
              'printer.',
        BookExportFormat.digitalPdf =>
          'The same book set for reading on screen, with no blank pages.',
        BookExportFormat.epub =>
          'Reflowable ebook for Kindle, Kobo, Apple Books and libraries. The '
              'reader chooses the type size, so the text reflows to fit.',
        BookExportFormat.docx =>
          'An editable Word document, in real named styles. Either standard '
              'manuscript format for an editor or agent, or a copy of the '
              'book as you have set it.',
        BookExportFormat.txt =>
          'Plain text, which nothing can refuse to open. The whole book, or '
              'the prose on its own for a word count or a diff.',
      };

  String get extension => switch (this) {
        BookExportFormat.printPdf || BookExportFormat.digitalPdf => 'pdf',
        BookExportFormat.epub => 'epub',
        BookExportFormat.docx => 'docx',
        BookExportFormat.txt => 'txt',
      };

  String get mimeType => switch (this) {
        BookExportFormat.printPdf ||
        BookExportFormat.digitalPdf =>
          'application/pdf',
        BookExportFormat.epub => 'application/epub+zip',
        BookExportFormat.docx =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        BookExportFormat.txt => 'text/plain',
      };

  /// Whether this target is built yet. Every one of them now is.
  bool get isAvailable => true;

  /// True when the reader, not the book, decides where the pages fall.
  ///
  /// A reflowable target is built from the book's structure and never from a
  /// paginated layout.
  bool get isReflowable => switch (this) {
        BookExportFormat.epub ||
        BookExportFormat.docx ||
        BookExportFormat.txt =>
          true,
        BookExportFormat.printPdf || BookExportFormat.digitalPdf => false,
      };
}

/// Writes an exported book somewhere the author can find it.
abstract class BookFileSaver {
  /// Returns the path written, an empty string when the platform owns the
  /// destination, or null when the author cancelled.
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
    required BookExportFormat format,
  });
}

class NativeBookFileSaver implements BookFileSaver {
  const NativeBookFileSaver();

  @override
  Future<String?> save({
    required String suggestedName,
    required Uint8List bytes,
    required BookExportFormat format,
  }) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [
        XTypeGroup(
          label: format.label,
          extensions: [format.extension],
          mimeTypes: [format.mimeType],
        ),
      ],
    );
    if (location == null) return null;

    final file = XFile.fromData(
      bytes,
      mimeType: format.mimeType,
      name: suggestedName,
    );
    await file.saveTo(location.path);

    // On the web the browser owns the save dialog and reports no destination
    // back, so there is no path to name: the file lands in downloads. The
    // manuscript exporter already relies on this contract, and the studio
    // branches on an empty path rather than treating it as a failure.
    return kIsWeb ? '' : location.path;
  }
}

/// Builds the filename an export is offered under.
String suggestedBookFilename({
  required String title,
  required BookExportFormat format,
}) {
  final slug = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final variant = format == BookExportFormat.printPdf ? '-print' : '';
  return '${slug.isEmpty ? 'book' : slug}$variant.${format.extension}';
}
