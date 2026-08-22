/// Book Studio Phase 1 — font loading and text measurement.
///
/// Everything that decides how wide a string is lives behind
/// [BookFontMetrics]. The layout engine measures through this interface, and so
/// does the preview: the on-screen surface must not measure with Flutter's own
/// text shaper, because then the preview and the exported PDF would break lines
/// in different places and the page counts would disagree.
///
/// The authoritative measurer is therefore the one the exporter actually uses —
/// the PDF font. `package:pdf` parses TrueType in pure Dart with no platform
/// channel, so the same code runs on web, on device, and under `flutter_test`.
///
/// Metrics are returned in **em units**. A glyph advance scales linearly with
/// point size, so a string is measured once and reused at any size.
library;

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/pdf.dart';

import 'book_format.dart';

/// Measures text for the layout engine.
abstract class BookFontMetrics {
  /// The advance width of [text] in [face], in em units.
  double advanceEm(String text, BookFontFace face);

  /// Distance from the baseline to the top of the face, in em units.
  double ascentEm(BookFontFace face);

  /// Distance from the baseline to the bottom of the face, in em units.
  /// Positive, unlike the PDF convention.
  double descentEm(BookFontFace face);

  /// The face actually available for [requested].
  ///
  /// A format may name a face this build does not ship. Rather than fail, the
  /// nearest available face is substituted and [substitutions] records it.
  BookFontFace resolve(BookFontFace requested);

  /// Faces that were requested but substituted, as `requested -> used`.
  Map<BookFontFace, BookFontFace> get substitutions;

  /// The advance width of [text] in points.
  double advancePt(String text, BookFontFace face, double sizePt) =>
      advanceEm(text, face) * sizePt;

  double ascentPt(BookFontFace face, double sizePt) =>
      ascentEm(face) * sizePt;

  double descentPt(BookFontFace face, double sizePt) =>
      descentEm(face) * sizePt;

  /// The advance of a single space, in points. Justification needs this to know
  /// how much slack it is redistributing.
  double spacePt(BookFontFace face, double sizePt) =>
      advancePt(' ', face, sizePt);
}

/// The TrueType bytes for every face this build ships.
///
/// Held as bytes rather than parsed fonts because a `PdfFont` belongs to the
/// document it was built against: the measurement pass and the render pass each
/// build their own from these same bytes, which is why their metrics agree.
class BookFontAssets {
  const BookFontAssets(this._data);

  final Map<BookFontFace, ByteData> _data;

  /// The asset path for each face, or null when this build does not ship it.
  ///
  /// Italic and bold-italic are deliberately absent: `pubspec.yaml` ships only
  /// the 400 and 700 weights of each family. A format that asks for italic gets
  /// the upright face and a recorded substitution rather than a crash. Adding
  /// the italic TTFs here is all that is needed to switch it on.
  /// The face used when a requested one is not shipped at all.
  ///
  /// This lives with the assets rather than with the metrics because it is a
  /// question of what the build contains, not of how text is measured.
  static const fallbackFace = BookFontFace.merriweatherRegular;

  static final Map<BookFontFace, String> assetPaths = {
    BookFontFace.merriweatherRegular: 'assets/fonts/Merriweather-400.ttf',
    BookFontFace.merriweatherBold: 'assets/fonts/Merriweather-700.ttf',
    BookFontFace.interRegular: 'assets/fonts/Inter-400.ttf',
    BookFontFace.interBold: 'assets/fonts/Inter-700.ttf',
  };

  ByteData? bytesFor(BookFontFace face) => _data[face];

  Iterable<BookFontFace> get availableFaces => _data.keys;

  bool has(BookFontFace face) => _data.containsKey(face);

  /// Loads every shipped face from the asset bundle.
  ///
  /// The result is cached for the session: parsing is not free and the studio
  /// repaginates on every format tweak.
  static Future<BookFontAssets> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final data = <BookFontFace, ByteData>{};
    for (final entry in assetPaths.entries) {
      data[entry.key] = await rootBundle.load(entry.value);
    }
    return _cache = BookFontAssets(data);
  }

  static BookFontAssets? _cache;

  /// Drops the cache. For tests.
  static void resetCache() => _cache = null;
}

/// Measures with the same font objects the PDF exporter will use.
class PdfBookFontMetrics implements BookFontMetrics {
  PdfBookFontMetrics._(this._fonts, this._substitutions);

  final Map<BookFontFace, PdfFont> _fonts;
  final Map<BookFontFace, BookFontFace> _substitutions;

  /// Builds metrics from [assets].
  ///
  /// The fonts are built against a throwaway document. That document is never
  /// written; it exists only because `PdfFont` requires one. Metrics come from
  /// the TrueType tables, so a font built here measures identically to the one
  /// the renderer builds against its own document.
  factory PdfBookFontMetrics(BookFontAssets assets) {
    final scratch = PdfDocument();
    final fonts = <BookFontFace, PdfFont>{};
    for (final face in assets.availableFaces) {
      final bytes = assets.bytesFor(face);
      if (bytes == null) continue;
      fonts[face] = PdfTtfFont(scratch, bytes);
    }
    return PdfBookFontMetrics._(fonts, <BookFontFace, BookFontFace>{});
  }

  @override
  Map<BookFontFace, BookFontFace> get substitutions =>
      Map.unmodifiable(_substitutions);

  @override
  BookFontFace resolve(BookFontFace requested) {
    if (_fonts.containsKey(requested)) return requested;

    // Degrade along the axis that costs the least: drop the slope first, then
    // the weight, then the family.
    final candidates = <BookFontFace>[
      if (requested.style == BookFontStyleId.boldItalic)
        requested.withStyle(BookFontStyleId.bold),
      if (requested.style == BookFontStyleId.boldItalic ||
          requested.style == BookFontStyleId.italic)
        requested.withStyle(BookFontStyleId.regular),
      requested.withStyle(BookFontStyleId.regular),
      BookFontAssets.fallbackFace,
    ];
    for (final candidate in candidates) {
      if (_fonts.containsKey(candidate)) {
        _substitutions[requested] = candidate;
        return candidate;
      }
    }
    return BookFontAssets.fallbackFace;
  }

  PdfFont _font(BookFontFace face) =>
      _fonts[resolve(face)] ?? _fonts.values.first;

  @override
  double advanceEm(String text, BookFontFace face) {
    if (text.isEmpty) return 0;
    return _font(face).stringMetrics(text).advanceWidth;
  }

  @override
  double ascentEm(BookFontFace face) => _font(face).ascent;

  @override
  double descentEm(BookFontFace face) => -_font(face).descent;

  @override
  double advancePt(String text, BookFontFace face, double sizePt) =>
      advanceEm(text, face) * sizePt;

  @override
  double ascentPt(BookFontFace face, double sizePt) =>
      ascentEm(face) * sizePt;

  @override
  double descentPt(BookFontFace face, double sizePt) =>
      descentEm(face) * sizePt;

  @override
  double spacePt(BookFontFace face, double sizePt) =>
      advancePt(' ', face, sizePt);
}

/// Deterministic metrics for tests.
///
/// Every glyph has the same advance, so expected line breaks can be computed by
/// hand and the layout rules can be asserted without loading a font.
class FakeBookFontMetrics implements BookFontMetrics {
  FakeBookFontMetrics({
    this.perCharacterEm = 0.5,
    this.ascent = 0.8,
    this.descent = 0.2,
  });

  final double perCharacterEm;
  final double ascent;
  final double descent;

  @override
  Map<BookFontFace, BookFontFace> get substitutions => const {};

  @override
  BookFontFace resolve(BookFontFace requested) => requested;

  @override
  double advanceEm(String text, BookFontFace face) =>
      text.length * perCharacterEm;

  @override
  double ascentEm(BookFontFace face) => ascent;

  @override
  double descentEm(BookFontFace face) => descent;

  @override
  double advancePt(String text, BookFontFace face, double sizePt) =>
      advanceEm(text, face) * sizePt;

  @override
  double ascentPt(BookFontFace face, double sizePt) => ascent * sizePt;

  @override
  double descentPt(BookFontFace face, double sizePt) => descent * sizePt;

  @override
  double spacePt(BookFontFace face, double sizePt) =>
      perCharacterEm * sizePt;
}
