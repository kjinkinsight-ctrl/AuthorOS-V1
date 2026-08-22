/// Book Studio Phase 2 — how a reflowable book is styled.
///
/// This is deliberately *not* a second [BookFormat]. Half of a print format —
/// trim size, margins, binding allowance, running heads, folios — has no
/// meaning in a book the reader reflows, and carrying it here would put controls
/// in the studio that change nothing. What is left is the set of choices a
/// reading system actually honours.
///
/// Everything here is relative. Body text is `1em`: the reader owns the size,
/// and an absolute value set by the author would fight the size they chose on
/// their own device.
library;

import 'book_format.dart';

/// The style specification for EPUB output.
class EpubSettings {
  const EpubSettings({
    this.bodyFamily = BookFontFamilyId.merriweather,
    this.lineHeight = 1.5,
    this.firstLineIndentEm = 1.2,
    this.paragraphSpacingEm = 0,
    this.alignment = BookAlignment.justified,
    this.indentAfterBreak = false,
    this.chapterNumberStyle = ChapterNumberStyle.arabic,
    this.chapterNumberPrefix = 'Chapter ',
    this.sceneBreak = SceneBreakStyle.blankLine,
    this.sceneBreakGlyph = '* * *',
    this.ornament = BookOrnamentId.asterism,
    this.dropCap = false,
    this.embedFonts = false,
    this.language = 'en',
  });

  /// The family named in the stylesheet. Only honoured when [embedFonts] is on
  /// or the reader happens to have the face; otherwise the reader's own serif
  /// or sans default applies, which is usually what a reader wants.
  final BookFontFamilyId bodyFamily;

  /// CSS `line-height`, unitless as CSS prefers.
  final double lineHeight;

  final double firstLineIndentEm;
  final double paragraphSpacingEm;
  final BookAlignment alignment;

  /// Publishing convention indents continuing paragraphs but not the first
  /// after a chapter opener or scene break.
  final bool indentAfterBreak;

  final ChapterNumberStyle chapterNumberStyle;
  final String chapterNumberPrefix;

  final SceneBreakStyle sceneBreak;
  final String sceneBreakGlyph;
  final BookOrnamentId ornament;

  /// Rendered as a styled span rather than `::first-letter`, which readers
  /// support unevenly.
  final bool dropCap;

  /// Carry the bundled faces into the package.
  ///
  /// Off by default: many reading systems ignore embedded fonts, several let
  /// the reader override them outright, and embedding roughly doubles the file.
  /// When it is on the OFL licence text travels with the fonts, as the licence
  /// requires.
  final bool embedFonts;

  /// BCP 47 language tag. EPUB requires `dc:language`, and a reading system
  /// uses it for hyphenation and speech.
  final String language;

  static const EpubSettings defaults = EpubSettings();

  EpubSettings copyWith({
    BookFontFamilyId? bodyFamily,
    double? lineHeight,
    double? firstLineIndentEm,
    double? paragraphSpacingEm,
    BookAlignment? alignment,
    bool? indentAfterBreak,
    ChapterNumberStyle? chapterNumberStyle,
    String? chapterNumberPrefix,
    SceneBreakStyle? sceneBreak,
    String? sceneBreakGlyph,
    BookOrnamentId? ornament,
    bool? dropCap,
    bool? embedFonts,
    String? language,
  }) =>
      EpubSettings(
        bodyFamily: bodyFamily ?? this.bodyFamily,
        lineHeight: lineHeight ?? this.lineHeight,
        firstLineIndentEm: firstLineIndentEm ?? this.firstLineIndentEm,
        paragraphSpacingEm: paragraphSpacingEm ?? this.paragraphSpacingEm,
        alignment: alignment ?? this.alignment,
        indentAfterBreak: indentAfterBreak ?? this.indentAfterBreak,
        chapterNumberStyle: chapterNumberStyle ?? this.chapterNumberStyle,
        chapterNumberPrefix: chapterNumberPrefix ?? this.chapterNumberPrefix,
        sceneBreak: sceneBreak ?? this.sceneBreak,
        sceneBreakGlyph: sceneBreakGlyph ?? this.sceneBreakGlyph,
        ornament: ornament ?? this.ornament,
        dropCap: dropCap ?? this.dropCap,
        embedFonts: embedFonts ?? this.embedFonts,
        language: language ?? this.language,
      );

  /// The CSS family stack written into the stylesheet.
  ///
  /// A generic fallback always trails the named face so a reader that has
  /// neither the embedded font nor the family still sets the book sensibly.
  String get fontFamilyStack => switch (bodyFamily) {
        BookFontFamilyId.merriweather => "'Merriweather', Georgia, serif",
        BookFontFamilyId.inter => "'Inter', Helvetica, Arial, sans-serif",
      };

  String get cssTextAlign =>
      alignment == BookAlignment.justified ? 'justify' : 'left';

  Map<String, Object?> toJson() => {
        'bodyFamily': bodyFamily.name,
        'lineHeight': lineHeight,
        'firstLineIndentEm': firstLineIndentEm,
        'paragraphSpacingEm': paragraphSpacingEm,
        'alignment': alignment.name,
        'indentAfterBreak': indentAfterBreak,
        'chapterNumberStyle': chapterNumberStyle.name,
        'chapterNumberPrefix': chapterNumberPrefix,
        'sceneBreak': sceneBreak.name,
        'sceneBreakGlyph': sceneBreakGlyph,
        'ornament': ornament.name,
        'dropCap': dropCap,
        'embedFonts': embedFonts,
        'language': language,
      };

  factory EpubSettings.fromJson(Map<String, dynamic> json) => EpubSettings(
        bodyFamily: _enumByName(BookFontFamilyId.values, json['bodyFamily'],
            BookFontFamilyId.merriweather),
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.5,
        firstLineIndentEm:
            (json['firstLineIndentEm'] as num?)?.toDouble() ?? 1.2,
        paragraphSpacingEm:
            (json['paragraphSpacingEm'] as num?)?.toDouble() ?? 0,
        alignment: _enumByName(
            BookAlignment.values, json['alignment'], BookAlignment.justified),
        indentAfterBreak: (json['indentAfterBreak'] as bool?) ?? false,
        chapterNumberStyle: _enumByName(ChapterNumberStyle.values,
            json['chapterNumberStyle'], ChapterNumberStyle.arabic),
        chapterNumberPrefix:
            (json['chapterNumberPrefix'] as String?) ?? 'Chapter ',
        sceneBreak: _enumByName(SceneBreakStyle.values, json['sceneBreak'],
            SceneBreakStyle.blankLine),
        sceneBreakGlyph: (json['sceneBreakGlyph'] as String?) ?? '* * *',
        ornament: _enumByName(
            BookOrnamentId.values, json['ornament'], BookOrnamentId.asterism),
        dropCap: (json['dropCap'] as bool?) ?? false,
        embedFonts: (json['embedFonts'] as bool?) ?? false,
        language: _language(json['language']),
      );

  /// Keeps a stored language usable.
  ///
  /// EPUB requires a well-formed `dc:language`, and a reading system that gets
  /// nonsense there can refuse the book, so anything unparseable falls back to
  /// English rather than travelling into the package.
  static String _language(Object? raw) {
    if (raw is! String) return 'en';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'en';
    return RegExp(r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$').hasMatch(trimmed)
        ? trimmed
        : 'en';
  }

  /// True when [tag] would be accepted as a language.
  static bool isValidLanguage(String tag) => _language(tag) == tag.trim();
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
