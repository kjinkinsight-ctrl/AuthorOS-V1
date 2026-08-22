/// Book Studio Phase 2 — cover art.
///
/// A cover is the one part of a book that is binary, and that changes where it
/// can live. Every other book setting is a JSON blob in shared preferences,
/// which on the web is `localStorage`: roughly a five-megabyte quota for the
/// whole origin, shared with the author's prose. A cover is hundreds of
/// kilobytes, so keeping it there risks failing to save — or crowding out the
/// manuscript. It goes into the embedded database instead, which is SQLite over
/// IndexedDB in the browser and has no such ceiling.
///
/// The bytes are stored exactly as the author supplied them. Re-encoding is
/// tempting but wrong here: Flutter can only re-encode to PNG, and a
/// photographic cover as PNG is several times *larger* than the JPEG it came
/// from. Import validates instead.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' as drift;

import '../persistence/authoros_database.dart';

/// Why a chosen file was not accepted.
enum BookCoverRejection { empty, tooLarge, unsupportedType, notAnImage, tooSmall }

extension BookCoverRejectionX on BookCoverRejection {
  String get message => switch (this) {
        BookCoverRejection.empty => 'That file is empty.',
        BookCoverRejection.tooLarge =>
          'Cover art must be under ${BookCover.maxBytes ~/ (1024 * 1024)} MB. '
              'Most retailers want a JPEG well under that.',
        BookCoverRejection.unsupportedType =>
          'Covers must be a JPEG or a PNG. Those are the two formats every '
              'reading system understands.',
        BookCoverRejection.notAnImage =>
          'That file could not be read as an image.',
        BookCoverRejection.tooSmall =>
          'That image is smaller than ${BookCover.minEdge} pixels on its '
              'shortest side, which will look soft on a modern screen.',
      };
}

/// A cover image the author attached to a book.
class BookCover {
  const BookCover({
    required this.bytes,
    required this.mediaType,
    this.width,
    this.height,
    this.updatedAt,
  });

  final Uint8List bytes;

  /// The IANA type, determined from the file's own magic bytes rather than its
  /// name — an extension is a claim, not evidence, and an EPUB manifest that
  /// mislabels the media type fails validation.
  final String mediaType;

  final int? width;
  final int? height;
  final DateTime? updatedAt;

  /// Generous enough for a full-resolution retailer cover, bounded so a single
  /// image cannot dominate the database or a future sync payload.
  static const maxBytes = 8 * 1024 * 1024;

  /// Below this a cover looks soft on a modern display.
  static const minEdge = 400;

  int get byteLength => bytes.length;

  String get fileName =>
      mediaType == 'image/png' ? 'cover.png' : 'cover.jpg';

  /// A short human description, for the studio.
  String get summary {
    final size = byteLength < 1024 * 1024
        ? '${(byteLength / 1024).round()} KB'
        : '${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (width == null || height == null) return size;
    return '$width x $height  ·  $size';
  }

  /// The media type of [bytes], or null when it is neither JPEG nor PNG.
  ///
  /// Sniffed from the leading bytes: JPEG starts `FF D8 FF`, PNG starts with the
  /// eight-byte signature `89 50 4E 47 0D 0A 1A 0A`.
  static String? sniffMediaType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    const png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length >= png.length) {
      var matches = true;
      for (var i = 0; i < png.length; i++) {
        if (bytes[i] != png[i]) {
          matches = false;
          break;
        }
      }
      if (matches) return 'image/png';
    }
    return null;
  }

  /// Validates and describes a file the author picked.
  ///
  /// Returns a [BookCoverImport] carrying either the cover or the reason it was
  /// refused. Nothing throws: a bad file is an ordinary answer, not an error.
  static Future<BookCoverImport> fromBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return const BookCoverImport.rejected(BookCoverRejection.empty);
    }
    if (bytes.length > maxBytes) {
      return const BookCoverImport.rejected(BookCoverRejection.tooLarge);
    }
    final mediaType = sniffMediaType(bytes);
    if (mediaType == null) {
      return const BookCoverImport.rejected(
        BookCoverRejection.unsupportedType,
      );
    }

    int? width;
    int? height;
    try {
      // Decoded once to prove the file really is an image and to learn its
      // dimensions. The decoded frame is disposed immediately; the bytes that
      // get stored are the author's originals.
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      return const BookCoverImport.rejected(BookCoverRejection.notAnImage);
    }

    if (width < minEdge || height < minEdge) {
      return const BookCoverImport.rejected(BookCoverRejection.tooSmall);
    }

    return BookCoverImport.accepted(BookCover(
      bytes: bytes,
      mediaType: mediaType,
      width: width,
      height: height,
    ));
  }
}

/// The outcome of offering a file as a cover.
class BookCoverImport {
  const BookCoverImport.accepted(this.cover) : rejection = null;
  const BookCoverImport.rejected(this.rejection) : cover = null;

  final BookCover? cover;
  final BookCoverRejection? rejection;

  bool get isAccepted => cover != null;
  String? get message => rejection?.message;
}

/// Reads and writes book assets.
///
/// Keyed by project and role, so a book has at most one cover and replacing it
/// is an upsert rather than an accumulation.
class BookCoverStore {
  const BookCoverStore({this.database});

  final AuthorOsDatabase? database;

  static const coverRole = 'cover';

  AuthorOsDatabase get _database => database ?? authorOsDatabase;

  Future<BookCover?> load(String projectId) async {
    final query = _database.select(_database.bookAssetRows)
      ..where((row) =>
          row.projectId.equals(projectId) & row.role.equals(coverRole));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return BookCover(
      bytes: Uint8List.fromList(row.bytes),
      mediaType: row.mediaType,
      width: row.width,
      height: row.height,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> save(String projectId, BookCover cover,
      {DateTime? timestamp}) async {
    await _database.into(_database.bookAssetRows).insertOnConflictUpdate(
          BookAssetRowsCompanion.insert(
            projectId: projectId,
            role: coverRole,
            mediaType: cover.mediaType,
            bytes: cover.bytes,
            width: drift.Value(cover.width),
            height: drift.Value(cover.height),
            updatedAt: timestamp ?? DateTime.now().toUtc(),
            extensionJson: '{}',
          ),
        );
  }

  Future<void> remove(String projectId) async {
    await (_database.delete(_database.bookAssetRows)
          ..where((row) =>
              row.projectId.equals(projectId) & row.role.equals(coverRole)))
        .go();
  }
}
