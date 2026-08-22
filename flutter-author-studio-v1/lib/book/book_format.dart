/// Book Studio Phase 1 — the style specification.
///
/// This library is plain Dart. It must not import Flutter, and it must not
/// import `package:pdf`. The layout engine, the PDF renderer and the on-screen
/// preview all read the same [BookFormat]; keeping it free of both bindings is
/// what lets the whole preset table be unit-tested without a Flutter binding.
///
/// Every measurement is in PostScript points (1 inch = 72 pt), which is the
/// unit `PdfPageFormat` uses and the unit `lib/manuscript_export.dart` already
/// expresses its margins in.
library;

/// A physical page size.
///
/// Trim is geometry, not type: changing the trim never requires a new font.
class TrimSize {
  const TrimSize(this.id, this.label, this.widthPt, this.heightPt);

  final String id;
  final String label;
  final double widthPt;
  final double heightPt;

  static const fiveByEight = TrimSize('5x8', '5 x 8 in', 360, 576);
  static const fiveQuarterByEight =
      TrimSize('5.25x8', '5.25 x 8 in', 378, 576);
  static const fiveHalfByEightHalf =
      TrimSize('5.5x8.5', '5.5 x 8.5 in', 396, 612);
  static const sixByNine = TrimSize('6x9', '6 x 9 in', 432, 648);
  static const letter = TrimSize('letter', 'US Letter', 612, 792);
  static const a4 = TrimSize('a4', 'A4', 595.28, 841.89);

  /// The sizes offered for print, in the order the picker shows them.
  static const List<TrimSize> printSizes = [
    fiveByEight,
    fiveQuarterByEight,
    fiveHalfByEightHalf,
    sixByNine,
    letter,
    a4,
  ];

  /// An author-defined trim. [widthPt] and [heightPt] are points, not inches.
  factory TrimSize.custom(double widthPt, double heightPt) => TrimSize(
        'custom',
        '${_inches(widthPt)} x ${_inches(heightPt)} in',
        widthPt,
        heightPt,
      );

  static String _inches(double points) {
    final value = points / 72.0;
    final rounded = (value * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toString();
  }

  static TrimSize byId(String id) => printSizes.firstWhere(
        (size) => size.id == id,
        orElse: () => sixByNine,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'widthPt': widthPt,
        'heightPt': heightPt,
      };

  factory TrimSize.fromJson(Map<String, dynamic> json) => TrimSize(
        (json['id'] as String?) ?? 'custom',
        (json['label'] as String?) ?? 'Custom',
        (json['widthPt'] as num?)?.toDouble() ?? 432,
        (json['heightPt'] as num?)?.toDouble() ?? 648,
      );

  @override
  bool operator ==(Object other) =>
      other is TrimSize &&
      other.id == id &&
      other.widthPt == widthPt &&
      other.heightPt == heightPt;

  @override
  int get hashCode => Object.hash(id, widthPt, heightPt);

  @override
  String toString() => 'TrimSize($id, ${widthPt}x$heightPt)';
}

/// The four margins of one concrete page, already resolved for its side.
class BookPageMargins {
  const BookPageMargins({
    required this.leftPt,
    required this.rightPt,
    required this.topPt,
    required this.bottomPt,
  });

  final double leftPt;
  final double rightPt;
  final double topPt;
  final double bottomPt;

  @override
  bool operator ==(Object other) =>
      other is BookPageMargins &&
      other.leftPt == leftPt &&
      other.rightPt == rightPt &&
      other.topPt == topPt &&
      other.bottomPt == bottomPt;

  @override
  int get hashCode => Object.hash(leftPt, rightPt, topPt, bottomPt);

  @override
  String toString() =>
      'BookPageMargins(l: $leftPt, r: $rightPt, t: $topPt, b: $bottomPt)';
}

/// Margins expressed the way a printer thinks about them.
///
/// [insidePt] is the spine edge and [outsidePt] the fore edge, so which
/// physical side each lands on depends on whether the page is a recto or a
/// verso. [resolve] performs that swap.
class BookMargins {
  const BookMargins({
    required this.topPt,
    required this.bottomPt,
    required this.outsidePt,
    required this.insidePt,
    this.gutterPt = 0,
    this.mirrored = true,
    this.scaleGutterByExtent = false,
  });

  final double topPt;
  final double bottomPt;
  final double outsidePt;
  final double insidePt;

  /// Extra binding allowance added to the inside edge.
  final double gutterPt;

  /// When false the same margins are used on every page (screen-only output,
  /// where there is no spine and no recto/verso).
  final bool mirrored;

  /// When true the gutter grows with the page count, as print-on-demand
  /// printers require. [gutterPt] is then a floor rather than the value used.
  final bool scaleGutterByExtent;

  /// Print-on-demand binding allowance for a book of [pages] pages.
  ///
  /// The bands follow the table print-on-demand services publish: a thicker
  /// book needs more of the inside edge sacrificed to the binding.
  static double podGutter(int pages) {
    if (pages <= 150) return 27;
    if (pages <= 300) return 36;
    if (pages <= 500) return 45;
    if (pages <= 700) return 54;
    return 63;
  }

  double gutterFor(int totalPages) {
    if (!scaleGutterByExtent) return gutterPt;
    final scaled = podGutter(totalPages);
    return scaled > gutterPt ? scaled : gutterPt;
  }

  /// The concrete margins for one page.
  ///
  /// On a recto the inside edge is the left; on a verso it is the right. When
  /// [mirrored] is false both sides get the inside value so the text block sits
  /// in the same place on every page.
  BookPageMargins resolve({required bool isRecto, required int totalPages}) {
    final gutter = gutterFor(totalPages);
    final inside = insidePt + gutter;
    if (!mirrored) {
      return BookPageMargins(
        leftPt: inside,
        rightPt: inside,
        topPt: topPt,
        bottomPt: bottomPt,
      );
    }
    return BookPageMargins(
      leftPt: isRecto ? inside : outsidePt,
      rightPt: isRecto ? outsidePt : inside,
      topPt: topPt,
      bottomPt: bottomPt,
    );
  }

  BookMargins copyWith({
    double? topPt,
    double? bottomPt,
    double? outsidePt,
    double? insidePt,
    double? gutterPt,
    bool? mirrored,
    bool? scaleGutterByExtent,
  }) =>
      BookMargins(
        topPt: topPt ?? this.topPt,
        bottomPt: bottomPt ?? this.bottomPt,
        outsidePt: outsidePt ?? this.outsidePt,
        insidePt: insidePt ?? this.insidePt,
        gutterPt: gutterPt ?? this.gutterPt,
        mirrored: mirrored ?? this.mirrored,
        scaleGutterByExtent: scaleGutterByExtent ?? this.scaleGutterByExtent,
      );

  Map<String, Object?> toJson() => {
        'topPt': topPt,
        'bottomPt': bottomPt,
        'outsidePt': outsidePt,
        'insidePt': insidePt,
        'gutterPt': gutterPt,
        'mirrored': mirrored,
        'scaleGutterByExtent': scaleGutterByExtent,
      };

  factory BookMargins.fromJson(Map<String, dynamic> json) => BookMargins(
        topPt: (json['topPt'] as num?)?.toDouble() ?? 54,
        bottomPt: (json['bottomPt'] as num?)?.toDouble() ?? 36,
        outsidePt: (json['outsidePt'] as num?)?.toDouble() ?? 36,
        insidePt: (json['insidePt'] as num?)?.toDouble() ?? 54,
        gutterPt: (json['gutterPt'] as num?)?.toDouble() ?? 0,
        mirrored: (json['mirrored'] as bool?) ?? true,
        scaleGutterByExtent: (json['scaleGutterByExtent'] as bool?) ?? false,
      );
}

/// Which font a run of text is set in.
///
/// Faces are referenced by id rather than by asset path so a format that names
/// a face the build does not ship degrades to the default with a recorded
/// issue, instead of failing to render.
enum BookFontFamilyId { merriweather, inter }

/// The weight and slope of one face within a family.
enum BookFontStyleId { regular, bold, italic, boldItalic }

/// One concrete face: a family plus a style.
class BookFontFace {
  const BookFontFace(this.family, this.style);

  final BookFontFamilyId family;
  final BookFontStyleId style;

  static const merriweatherRegular =
      BookFontFace(BookFontFamilyId.merriweather, BookFontStyleId.regular);
  static const merriweatherBold =
      BookFontFace(BookFontFamilyId.merriweather, BookFontStyleId.bold);
  static const merriweatherItalic =
      BookFontFace(BookFontFamilyId.merriweather, BookFontStyleId.italic);
  static const interRegular =
      BookFontFace(BookFontFamilyId.inter, BookFontStyleId.regular);
  static const interBold =
      BookFontFace(BookFontFamilyId.inter, BookFontStyleId.bold);
  static const interItalic =
      BookFontFace(BookFontFamilyId.inter, BookFontStyleId.italic);

  BookFontFace withStyle(BookFontStyleId style) => BookFontFace(family, style);

  @override
  bool operator ==(Object other) =>
      other is BookFontFace && other.family == family && other.style == style;

  @override
  int get hashCode => Object.hash(family, style);

  @override
  String toString() => 'BookFontFace(${family.name}, ${style.name})';
}

/// How a line of prose fills its measure.
enum BookAlignment { left, justified }

/// Whether the book carries an inline emphasis convention.
///
/// Scene prose is a plain string with no markup, so a book cannot show italics
/// unless the author is given a convention for them. This is opt-in: with
/// [none] an underscore is just an underscore.
enum BookInlineMarkup { none, underscoreItalic }

/// Body-text style.
class BookTypography {
  const BookTypography({
    this.bodyFamily = BookFontFamilyId.merriweather,
    this.displayFamily = BookFontFamilyId.merriweather,
    this.bodySizePt = 11,
    this.leadingMultiple = 1.35,
    this.firstLineIndentPt = 16,
    this.paragraphSpacingPt = 0,
    this.indentAfterBreak = false,
    this.alignment = BookAlignment.justified,
    this.hyphenate = false,
    this.inlineMarkup = BookInlineMarkup.none,
  });

  final BookFontFamilyId bodyFamily;
  final BookFontFamilyId displayFamily;
  final double bodySizePt;

  /// Baseline-to-baseline distance as a multiple of [bodySizePt].
  final double leadingMultiple;

  final double firstLineIndentPt;
  final double paragraphSpacingPt;

  /// Publishing convention indents continuing paragraphs but not the first
  /// paragraph after a chapter opener or a scene break. Leave false for that.
  final bool indentAfterBreak;

  final BookAlignment alignment;
  final bool hyphenate;
  final BookInlineMarkup inlineMarkup;

  double get leadingPt => bodySizePt * leadingMultiple;

  BookTypography copyWith({
    BookFontFamilyId? bodyFamily,
    BookFontFamilyId? displayFamily,
    double? bodySizePt,
    double? leadingMultiple,
    double? firstLineIndentPt,
    double? paragraphSpacingPt,
    bool? indentAfterBreak,
    BookAlignment? alignment,
    bool? hyphenate,
    BookInlineMarkup? inlineMarkup,
  }) =>
      BookTypography(
        bodyFamily: bodyFamily ?? this.bodyFamily,
        displayFamily: displayFamily ?? this.displayFamily,
        bodySizePt: bodySizePt ?? this.bodySizePt,
        leadingMultiple: leadingMultiple ?? this.leadingMultiple,
        firstLineIndentPt: firstLineIndentPt ?? this.firstLineIndentPt,
        paragraphSpacingPt: paragraphSpacingPt ?? this.paragraphSpacingPt,
        indentAfterBreak: indentAfterBreak ?? this.indentAfterBreak,
        alignment: alignment ?? this.alignment,
        hyphenate: hyphenate ?? this.hyphenate,
        inlineMarkup: inlineMarkup ?? this.inlineMarkup,
      );

  Map<String, Object?> toJson() => {
        'bodyFamily': bodyFamily.name,
        'displayFamily': displayFamily.name,
        'bodySizePt': bodySizePt,
        'leadingMultiple': leadingMultiple,
        'firstLineIndentPt': firstLineIndentPt,
        'paragraphSpacingPt': paragraphSpacingPt,
        'indentAfterBreak': indentAfterBreak,
        'alignment': alignment.name,
        'hyphenate': hyphenate,
        'inlineMarkup': inlineMarkup.name,
      };

  factory BookTypography.fromJson(Map<String, dynamic> json) => BookTypography(
        bodyFamily: _enumByName(
            BookFontFamilyId.values, json['bodyFamily'], BookFontFamilyId.merriweather),
        displayFamily: _enumByName(BookFontFamilyId.values,
            json['displayFamily'], BookFontFamilyId.merriweather),
        bodySizePt: (json['bodySizePt'] as num?)?.toDouble() ?? 11,
        leadingMultiple: (json['leadingMultiple'] as num?)?.toDouble() ?? 1.35,
        firstLineIndentPt: (json['firstLineIndentPt'] as num?)?.toDouble() ?? 16,
        paragraphSpacingPt:
            (json['paragraphSpacingPt'] as num?)?.toDouble() ?? 0,
        indentAfterBreak: (json['indentAfterBreak'] as bool?) ?? false,
        alignment: _enumByName(
            BookAlignment.values, json['alignment'], BookAlignment.justified),
        hyphenate: (json['hyphenate'] as bool?) ?? false,
        inlineMarkup: _enumByName(BookInlineMarkup.values, json['inlineMarkup'],
            BookInlineMarkup.none),
      );
}

/// Where a chapter is allowed to begin.
///
/// [recto] is the traditional print choice and is what forces blank versos;
/// screen formats use [nextPage] so a reader never meets a blank page.
enum ChapterStartRule { anyPage, nextPage, recto }

/// How a chapter number is spelled.
enum ChapterNumberStyle { none, arabic, word, romanUpper }

/// The chapter number as the book writes it, prefix included.
///
/// Lives here, beside the enum it switches over, because four things need the
/// same answer: the layout engine that sets the printed page, and the EPUB,
/// DOCX and text exporters. They are all rendering the *same book*, so a
/// chapter that reads `Chapter Twenty-one` in the PDF cannot read `Chapter 21`
/// in the Word file. Each having its own copy is how that drift starts.
String chapterNumberLabel(
  int number, {
  required ChapterNumberStyle style,
  String prefix = '',
}) =>
    switch (style) {
      ChapterNumberStyle.none => '',
      ChapterNumberStyle.arabic => '$prefix$number',
      ChapterNumberStyle.romanUpper => '$prefix${romanUpper(number)}',
      ChapterNumberStyle.word => '$prefix${numberWord(number)}',
    };

/// Upper-case Roman numerals.
String romanUpper(int value) {
  if (value <= 0) return '$value';
  const numerals = <int, String>{
    1000: 'M',
    900: 'CM',
    500: 'D',
    400: 'CD',
    100: 'C',
    90: 'XC',
    50: 'L',
    40: 'XL',
    10: 'X',
    9: 'IX',
    5: 'V',
    4: 'IV',
    1: 'I',
  };
  final buffer = StringBuffer();
  var remaining = value;
  for (final entry in numerals.entries) {
    while (remaining >= entry.key) {
      buffer.write(entry.value);
      remaining -= entry.key;
    }
  }
  return buffer.toString();
}

/// Spells a small number as a word, for `Chapter Seventeen` openers.
String numberWord(int value) {
  const ones = [
    'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
  ];
  const tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
    'Eighty', 'Ninety',
  ];
  if (value < 0) return '$value';
  if (value < 20) return ones[value];
  if (value < 100) {
    final unit = value % 10;
    final ten = tens[value ~/ 10];
    return unit == 0 ? ten : '$ten-${ones[unit].toLowerCase()}';
  }
  if (value < 1000) {
    final hundreds = '${ones[value ~/ 100]} Hundred';
    final rest = value % 100;
    return rest == 0 ? hundreds : '$hundreds ${numberWord(rest)}';
  }
  return '$value';
}

/// What separates two scenes inside a chapter.
enum SceneBreakStyle { blankLine, glyph, ornament }

/// A vector ornament, drawn as paths by both renderers.
///
/// Drawn rather than typeset on purpose: the bundled faces carry no ornament
/// glyphs, so a character like U+2767 would render as tofu.
enum BookOrnamentId { none, asterism, diamond, rule, leaf }

/// Chapter opener and scene break design.
class ChapterStyle {
  const ChapterStyle({
    this.startRule = ChapterStartRule.recto,
    this.sinkFraction = 0.25,
    this.numberStyle = ChapterNumberStyle.arabic,
    this.numberPrefix = 'Chapter ',
    this.numberSizePt = 12,
    this.titleSizePt = 18,
    this.titleGapPt = 14,
    this.bodyGapPt = 28,
    this.headingAlignment = BookAlignment.left,
    this.dropCap = false,
    this.dropCapLines = 3,
    this.sceneBreak = SceneBreakStyle.blankLine,
    this.sceneBreakGlyph = '* * *',
    this.ornament = BookOrnamentId.none,
  });

  final ChapterStartRule startRule;

  /// How far down the page the opener starts, as a fraction of the text block.
  final double sinkFraction;

  final ChapterNumberStyle numberStyle;
  final String numberPrefix;
  final double numberSizePt;
  final double titleSizePt;

  /// Space between the chapter number and the chapter title.
  final double titleGapPt;

  /// Space between the opener block and the first line of prose.
  final double bodyGapPt;

  final BookAlignment headingAlignment;
  final bool dropCap;
  final int dropCapLines;
  final SceneBreakStyle sceneBreak;
  final String sceneBreakGlyph;
  final BookOrnamentId ornament;

  ChapterStyle copyWith({
    ChapterStartRule? startRule,
    double? sinkFraction,
    ChapterNumberStyle? numberStyle,
    String? numberPrefix,
    double? numberSizePt,
    double? titleSizePt,
    double? titleGapPt,
    double? bodyGapPt,
    BookAlignment? headingAlignment,
    bool? dropCap,
    int? dropCapLines,
    SceneBreakStyle? sceneBreak,
    String? sceneBreakGlyph,
    BookOrnamentId? ornament,
  }) =>
      ChapterStyle(
        startRule: startRule ?? this.startRule,
        sinkFraction: sinkFraction ?? this.sinkFraction,
        numberStyle: numberStyle ?? this.numberStyle,
        numberPrefix: numberPrefix ?? this.numberPrefix,
        numberSizePt: numberSizePt ?? this.numberSizePt,
        titleSizePt: titleSizePt ?? this.titleSizePt,
        titleGapPt: titleGapPt ?? this.titleGapPt,
        bodyGapPt: bodyGapPt ?? this.bodyGapPt,
        headingAlignment: headingAlignment ?? this.headingAlignment,
        dropCap: dropCap ?? this.dropCap,
        dropCapLines: dropCapLines ?? this.dropCapLines,
        sceneBreak: sceneBreak ?? this.sceneBreak,
        sceneBreakGlyph: sceneBreakGlyph ?? this.sceneBreakGlyph,
        ornament: ornament ?? this.ornament,
      );

  Map<String, Object?> toJson() => {
        'startRule': startRule.name,
        'sinkFraction': sinkFraction,
        'numberStyle': numberStyle.name,
        'numberPrefix': numberPrefix,
        'numberSizePt': numberSizePt,
        'titleSizePt': titleSizePt,
        'titleGapPt': titleGapPt,
        'bodyGapPt': bodyGapPt,
        'headingAlignment': headingAlignment.name,
        'dropCap': dropCap,
        'dropCapLines': dropCapLines,
        'sceneBreak': sceneBreak.name,
        'sceneBreakGlyph': sceneBreakGlyph,
        'ornament': ornament.name,
      };

  factory ChapterStyle.fromJson(Map<String, dynamic> json) => ChapterStyle(
        startRule: _enumByName(ChapterStartRule.values, json['startRule'],
            ChapterStartRule.recto),
        sinkFraction: (json['sinkFraction'] as num?)?.toDouble() ?? 0.25,
        numberStyle: _enumByName(ChapterNumberStyle.values, json['numberStyle'],
            ChapterNumberStyle.arabic),
        numberPrefix: (json['numberPrefix'] as String?) ?? 'Chapter ',
        numberSizePt: (json['numberSizePt'] as num?)?.toDouble() ?? 12,
        titleSizePt: (json['titleSizePt'] as num?)?.toDouble() ?? 18,
        titleGapPt: (json['titleGapPt'] as num?)?.toDouble() ?? 14,
        bodyGapPt: (json['bodyGapPt'] as num?)?.toDouble() ?? 28,
        headingAlignment: _enumByName(BookAlignment.values,
            json['headingAlignment'], BookAlignment.left),
        dropCap: (json['dropCap'] as bool?) ?? false,
        dropCapLines: (json['dropCapLines'] as num?)?.toInt() ?? 3,
        sceneBreak: _enumByName(
            SceneBreakStyle.values, json['sceneBreak'], SceneBreakStyle.blankLine),
        sceneBreakGlyph: (json['sceneBreakGlyph'] as String?) ?? '* * *',
        ornament: _enumByName(
            BookOrnamentId.values, json['ornament'], BookOrnamentId.none),
      );
}

/// What a running head shows.
enum RunningHeadContent { none, bookTitle, authorName, chapterTitle, partTitle }

/// The line of type at the top of a page.
class RunningHead {
  const RunningHead({
    this.verso = RunningHeadContent.bookTitle,
    this.recto = RunningHeadContent.chapterTitle,
    this.sizePt = 9,
    this.gapPt = 18,
    this.suppressOnChapterOpener = true,
    this.suppressOnBlank = true,
    this.suppressInFrontMatter = true,
  });

  final RunningHeadContent verso;
  final RunningHeadContent recto;
  final double sizePt;

  /// Distance between the running head baseline and the top of the text block.
  final double gapPt;

  final bool suppressOnChapterOpener;
  final bool suppressOnBlank;
  final bool suppressInFrontMatter;

  bool get isEmpty =>
      verso == RunningHeadContent.none && recto == RunningHeadContent.none;

  /// Vertical space the head reserves above the text block.
  double get reservedPt => isEmpty ? 0 : sizePt + gapPt;

  RunningHead copyWith({
    RunningHeadContent? verso,
    RunningHeadContent? recto,
    double? sizePt,
    double? gapPt,
    bool? suppressOnChapterOpener,
    bool? suppressOnBlank,
    bool? suppressInFrontMatter,
  }) =>
      RunningHead(
        verso: verso ?? this.verso,
        recto: recto ?? this.recto,
        sizePt: sizePt ?? this.sizePt,
        gapPt: gapPt ?? this.gapPt,
        suppressOnChapterOpener:
            suppressOnChapterOpener ?? this.suppressOnChapterOpener,
        suppressOnBlank: suppressOnBlank ?? this.suppressOnBlank,
        suppressInFrontMatter:
            suppressInFrontMatter ?? this.suppressInFrontMatter,
      );

  Map<String, Object?> toJson() => {
        'verso': verso.name,
        'recto': recto.name,
        'sizePt': sizePt,
        'gapPt': gapPt,
        'suppressOnChapterOpener': suppressOnChapterOpener,
        'suppressOnBlank': suppressOnBlank,
        'suppressInFrontMatter': suppressInFrontMatter,
      };

  factory RunningHead.fromJson(Map<String, dynamic> json) => RunningHead(
        verso: _enumByName(RunningHeadContent.values, json['verso'],
            RunningHeadContent.bookTitle),
        recto: _enumByName(RunningHeadContent.values, json['recto'],
            RunningHeadContent.chapterTitle),
        sizePt: (json['sizePt'] as num?)?.toDouble() ?? 9,
        gapPt: (json['gapPt'] as num?)?.toDouble() ?? 18,
        suppressOnChapterOpener:
            (json['suppressOnChapterOpener'] as bool?) ?? true,
        suppressOnBlank: (json['suppressOnBlank'] as bool?) ?? true,
        suppressInFrontMatter:
            (json['suppressInFrontMatter'] as bool?) ?? true,
      );
}

/// Where the folio sits on the page.
enum PageNumberPosition { none, footerCentre, footerOutside, headerOutside }

/// How a folio is spelled.
enum PageNumeralStyle { arabic, romanLower, romanUpper }

/// Page numbering, including the front-matter/body split.
class PageNumbering {
  const PageNumbering({
    this.position = PageNumberPosition.footerCentre,
    this.frontMatterStyle = PageNumeralStyle.romanLower,
    this.bodyStyle = PageNumeralStyle.arabic,
    this.restartAtBody = true,
    this.countFrontMatterSeparately = true,
    this.suppressOnChapterOpener = false,
    this.suppressOnBlank = true,
    this.sizePt = 9,
    this.gapPt = 18,
  });

  final PageNumberPosition position;
  final PageNumeralStyle frontMatterStyle;
  final PageNumeralStyle bodyStyle;

  /// Whether the body's first page is folio 1.
  final bool restartAtBody;

  /// Whether the front matter carries its own numeral sequence.
  ///
  /// True is the traditional arrangement and the one that lets the engine
  /// paginate the body first, so the table of contents is correct on the first
  /// pass. See [BookLayoutEngine] for why that matters.
  final bool countFrontMatterSeparately;

  final bool suppressOnChapterOpener;
  final bool suppressOnBlank;
  final double sizePt;

  /// Distance between the bottom of the text block and the folio baseline.
  final double gapPt;

  bool get isEmpty => position == PageNumberPosition.none;

  /// Vertical space the folio reserves below the text block.
  double get reservedPt => isEmpty ? 0 : sizePt + gapPt;

  PageNumbering copyWith({
    PageNumberPosition? position,
    PageNumeralStyle? frontMatterStyle,
    PageNumeralStyle? bodyStyle,
    bool? restartAtBody,
    bool? countFrontMatterSeparately,
    bool? suppressOnChapterOpener,
    bool? suppressOnBlank,
    double? sizePt,
    double? gapPt,
  }) =>
      PageNumbering(
        position: position ?? this.position,
        frontMatterStyle: frontMatterStyle ?? this.frontMatterStyle,
        bodyStyle: bodyStyle ?? this.bodyStyle,
        restartAtBody: restartAtBody ?? this.restartAtBody,
        countFrontMatterSeparately:
            countFrontMatterSeparately ?? this.countFrontMatterSeparately,
        suppressOnChapterOpener:
            suppressOnChapterOpener ?? this.suppressOnChapterOpener,
        suppressOnBlank: suppressOnBlank ?? this.suppressOnBlank,
        sizePt: sizePt ?? this.sizePt,
        gapPt: gapPt ?? this.gapPt,
      );

  Map<String, Object?> toJson() => {
        'position': position.name,
        'frontMatterStyle': frontMatterStyle.name,
        'bodyStyle': bodyStyle.name,
        'restartAtBody': restartAtBody,
        'countFrontMatterSeparately': countFrontMatterSeparately,
        'suppressOnChapterOpener': suppressOnChapterOpener,
        'suppressOnBlank': suppressOnBlank,
        'sizePt': sizePt,
        'gapPt': gapPt,
      };

  factory PageNumbering.fromJson(Map<String, dynamic> json) => PageNumbering(
        position: _enumByName(PageNumberPosition.values, json['position'],
            PageNumberPosition.footerCentre),
        frontMatterStyle: _enumByName(PageNumeralStyle.values,
            json['frontMatterStyle'], PageNumeralStyle.romanLower),
        bodyStyle: _enumByName(
            PageNumeralStyle.values, json['bodyStyle'], PageNumeralStyle.arabic),
        restartAtBody: (json['restartAtBody'] as bool?) ?? true,
        countFrontMatterSeparately:
            (json['countFrontMatterSeparately'] as bool?) ?? true,
        suppressOnChapterOpener:
            (json['suppressOnChapterOpener'] as bool?) ?? false,
        suppressOnBlank: (json['suppressOnBlank'] as bool?) ?? true,
        sizePt: (json['sizePt'] as num?)?.toDouble() ?? 9,
        gapPt: (json['gapPt'] as num?)?.toDouble() ?? 18,
      );
}

/// Rules that decide where the engine is allowed to break a page.
class BookBreakRules {
  const BookBreakRules({
    this.minLinesAtPageBottom = 2,
    this.minLinesAtPageTop = 2,
    this.blankVersoBeforeChapter = false,
    this.maxWordSpaceMultiple = 3.0,
  });

  /// Orphan control: a paragraph may not leave fewer than this many lines at
  /// the foot of a page.
  final int minLinesAtPageBottom;

  /// Widow control: a paragraph may not carry fewer than this many lines to the
  /// head of the next page.
  final int minLinesAtPageTop;

  /// Force a blank verso before every chapter opener, over and above what
  /// [ChapterStartRule.recto] already implies.
  final bool blankVersoBeforeChapter;

  /// A justified line whose word spacing exceeds this multiple of the natural
  /// space is reported as a river.
  final double maxWordSpaceMultiple;

  BookBreakRules copyWith({
    int? minLinesAtPageBottom,
    int? minLinesAtPageTop,
    bool? blankVersoBeforeChapter,
    double? maxWordSpaceMultiple,
  }) =>
      BookBreakRules(
        minLinesAtPageBottom: minLinesAtPageBottom ?? this.minLinesAtPageBottom,
        minLinesAtPageTop: minLinesAtPageTop ?? this.minLinesAtPageTop,
        blankVersoBeforeChapter:
            blankVersoBeforeChapter ?? this.blankVersoBeforeChapter,
        maxWordSpaceMultiple:
            maxWordSpaceMultiple ?? this.maxWordSpaceMultiple,
      );

  Map<String, Object?> toJson() => {
        'minLinesAtPageBottom': minLinesAtPageBottom,
        'minLinesAtPageTop': minLinesAtPageTop,
        'blankVersoBeforeChapter': blankVersoBeforeChapter,
        'maxWordSpaceMultiple': maxWordSpaceMultiple,
      };

  factory BookBreakRules.fromJson(Map<String, dynamic> json) => BookBreakRules(
        minLinesAtPageBottom:
            (json['minLinesAtPageBottom'] as num?)?.toInt() ?? 2,
        minLinesAtPageTop: (json['minLinesAtPageTop'] as num?)?.toInt() ?? 2,
        blankVersoBeforeChapter:
            (json['blankVersoBeforeChapter'] as bool?) ?? false,
        maxWordSpaceMultiple:
            (json['maxWordSpaceMultiple'] as num?)?.toDouble() ?? 3.0,
      );
}

/// A complete style specification for one book.
///
/// A customised format stores every resolved value rather than a preset id plus
/// a diff. That is deliberate: if only the diff were stored, shipping a change
/// to a preset default would silently reflow every existing author's book.
/// [basePresetId] records provenance so the studio can still offer "reset".
class BookFormat {
  const BookFormat({
    required this.id,
    required this.label,
    required this.trim,
    required this.margins,
    required this.typography,
    required this.chapter,
    required this.runningHead,
    required this.numbering,
    required this.breaks,
    this.basePresetId,
    this.reflowable = false,
  });

  final String id;
  final String label;

  /// The preset this format was cloned from, when it was customised.
  final String? basePresetId;

  /// True for targets where pagination is nominal because the reader reflows
  /// the text. Such a format is never used to drive a paginated export.
  final bool reflowable;

  final TrimSize trim;
  final BookMargins margins;
  final BookTypography typography;
  final ChapterStyle chapter;
  final RunningHead runningHead;
  final PageNumbering numbering;
  final BookBreakRules breaks;

  /// Whether the format aligns openers to the right-hand page.
  ///
  /// Only a bound book needs this. It is what produces blank versos, so a
  /// screen format must not inherit it: a blank page a reader has to swipe past
  /// reads as a bug rather than as typography.
  bool get requiresRectoStarts =>
      chapter.startRule == ChapterStartRule.recto ||
      breaks.blankVersoBeforeChapter;

  bool get isBuiltIn => basePresetId == null &&
      BookFormatPresets.all.any((preset) => preset.id == id);

  /// True when this format was cloned from a preset and then edited.
  bool get isCustomised => basePresetId != null;

  BookFormat copyWith({
    String? id,
    String? label,
    String? basePresetId,
    bool? reflowable,
    TrimSize? trim,
    BookMargins? margins,
    BookTypography? typography,
    ChapterStyle? chapter,
    RunningHead? runningHead,
    PageNumbering? numbering,
    BookBreakRules? breaks,
  }) =>
      BookFormat(
        id: id ?? this.id,
        label: label ?? this.label,
        basePresetId: basePresetId ?? this.basePresetId,
        reflowable: reflowable ?? this.reflowable,
        trim: trim ?? this.trim,
        margins: margins ?? this.margins,
        typography: typography ?? this.typography,
        chapter: chapter ?? this.chapter,
        runningHead: runningHead ?? this.runningHead,
        numbering: numbering ?? this.numbering,
        breaks: breaks ?? this.breaks,
      );

  /// Clones this preset into an author-owned format that can be edited.
  BookFormat customise() => copyWith(
        id: 'custom:$id',
        label: '$label (customised)',
        basePresetId: basePresetId ?? id,
      );

  /// A stable fingerprint of every value that affects layout.
  ///
  /// The studio caches a laid-out book against this, so a format tweak
  /// repaginates and a repaint does not.
  String get layoutFingerprint => toJson().toString();

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        if (basePresetId != null) 'basePresetId': basePresetId,
        'reflowable': reflowable,
        'trim': trim.toJson(),
        'margins': margins.toJson(),
        'typography': typography.toJson(),
        'chapter': chapter.toJson(),
        'runningHead': runningHead.toJson(),
        'numbering': numbering.toJson(),
        'breaks': breaks.toJson(),
      };

  factory BookFormat.fromJson(Map<String, dynamic> json) => BookFormat(
        id: (json['id'] as String?) ?? BookFormatPresets.paperback.id,
        label: (json['label'] as String?) ?? 'Paperback',
        basePresetId: json['basePresetId'] as String?,
        reflowable: (json['reflowable'] as bool?) ?? false,
        trim: TrimSize.fromJson(
            (json['trim'] as Map?)?.cast<String, dynamic>() ?? const {}),
        margins: BookMargins.fromJson(
            (json['margins'] as Map?)?.cast<String, dynamic>() ?? const {}),
        typography: BookTypography.fromJson(
            (json['typography'] as Map?)?.cast<String, dynamic>() ?? const {}),
        chapter: ChapterStyle.fromJson(
            (json['chapter'] as Map?)?.cast<String, dynamic>() ?? const {}),
        runningHead: RunningHead.fromJson(
            (json['runningHead'] as Map?)?.cast<String, dynamic>() ?? const {}),
        numbering: PageNumbering.fromJson(
            (json['numbering'] as Map?)?.cast<String, dynamic>() ?? const {}),
        breaks: BookBreakRules.fromJson(
            (json['breaks'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );
}

/// The built-in format presets.
class BookFormatPresets {
  const BookFormatPresets._();

  /// Trade paperback: the default a novel is printed at.
  static const paperback = BookFormat(
    id: 'paperback',
    label: 'Paperback',
    trim: TrimSize.fiveHalfByEightHalf,
    margins: BookMargins(
      topPt: 54,
      bottomPt: 36,
      outsidePt: 36,
      insidePt: 54,
      gutterPt: 18,
    ),
    typography: BookTypography(
      bodySizePt: 11,
      leadingMultiple: 1.35,
      firstLineIndentPt: 16,
    ),
    chapter: ChapterStyle(
      startRule: ChapterStartRule.recto,
      sinkFraction: 0.25,
    ),
    runningHead: RunningHead(),
    numbering: PageNumbering(),
    breaks: BookBreakRules(),
  );

  /// Hardcover: a larger trim, more generous margins, and a decorated opener.
  static const hardcover = BookFormat(
    id: 'hardcover',
    label: 'Hardcover',
    trim: TrimSize.sixByNine,
    margins: BookMargins(
      topPt: 63,
      bottomPt: 45,
      outsidePt: 45,
      insidePt: 63,
      gutterPt: 27,
    ),
    typography: BookTypography(
      bodySizePt: 11.5,
      leadingMultiple: 1.4,
      firstLineIndentPt: 18,
    ),
    chapter: ChapterStyle(
      startRule: ChapterStartRule.recto,
      sinkFraction: 0.3,
      numberStyle: ChapterNumberStyle.word,
      numberPrefix: 'Chapter ',
      dropCap: true,
      dropCapLines: 3,
      sceneBreak: SceneBreakStyle.ornament,
      ornament: BookOrnamentId.asterism,
    ),
    runningHead: RunningHead(
      verso: RunningHeadContent.authorName,
      recto: RunningHeadContent.bookTitle,
    ),
    numbering: PageNumbering(position: PageNumberPosition.footerOutside),
    breaks: BookBreakRules(),
  );

  /// Large print: bigger type, looser leading, and ragged right.
  ///
  /// Left-aligned deliberately. Justifying large type on a narrow measure opens
  /// rivers, and accessibility guidance prefers a ragged right edge.
  static const largePrint = BookFormat(
    id: 'large-print',
    label: 'Large Print',
    trim: TrimSize.sixByNine,
    margins: BookMargins(
      topPt: 54,
      bottomPt: 36,
      outsidePt: 36,
      insidePt: 54,
      gutterPt: 27,
    ),
    typography: BookTypography(
      bodyFamily: BookFontFamilyId.inter,
      displayFamily: BookFontFamilyId.inter,
      bodySizePt: 16,
      leadingMultiple: 1.6,
      firstLineIndentPt: 0,
      paragraphSpacingPt: 8,
      alignment: BookAlignment.left,
    ),
    chapter: ChapterStyle(
      startRule: ChapterStartRule.nextPage,
      sinkFraction: 0.2,
      titleSizePt: 22,
      numberSizePt: 16,
    ),
    runningHead: RunningHead(
      verso: RunningHeadContent.none,
      recto: RunningHeadContent.none,
    ),
    numbering: PageNumbering(
      frontMatterStyle: PageNumeralStyle.arabic,
      restartAtBody: false,
      countFrontMatterSeparately: false,
      sizePt: 12,
    ),
    breaks: BookBreakRules(),
  );

  /// Print-on-demand: the gutter grows with the page count.
  static const printOnDemand = BookFormat(
    id: 'print-on-demand',
    label: 'Print-on-Demand',
    trim: TrimSize.sixByNine,
    margins: BookMargins(
      topPt: 54,
      bottomPt: 36,
      outsidePt: 36,
      insidePt: 54,
      gutterPt: 27,
      scaleGutterByExtent: true,
    ),
    typography: BookTypography(
      bodySizePt: 11,
      leadingMultiple: 1.35,
      firstLineIndentPt: 16,
    ),
    chapter: ChapterStyle(startRule: ChapterStartRule.recto),
    runningHead: RunningHead(),
    numbering: PageNumbering(suppressOnBlank: true),
    breaks: BookBreakRules(blankVersoBeforeChapter: true),
  );

  /// A fixed-layout PDF meant to be read on a screen.
  ///
  /// No mirroring and no recto starts: there is no spine, and a blank page that
  /// exists to satisfy a printer reads as a bug on a screen.
  static const ebook = BookFormat(
    id: 'ebook',
    label: 'Ebook (fixed PDF)',
    trim: TrimSize.sixByNine,
    margins: BookMargins(
      topPt: 40,
      bottomPt: 40,
      outsidePt: 40,
      insidePt: 40,
      mirrored: false,
    ),
    typography: BookTypography(
      bodyFamily: BookFontFamilyId.inter,
      displayFamily: BookFontFamilyId.inter,
      bodySizePt: 11.5,
      leadingMultiple: 1.5,
      firstLineIndentPt: 14,
      alignment: BookAlignment.left,
    ),
    chapter: ChapterStyle(startRule: ChapterStartRule.nextPage),
    runningHead: RunningHead(
      verso: RunningHeadContent.none,
      recto: RunningHeadContent.none,
    ),
    numbering: PageNumbering(
      frontMatterStyle: PageNumeralStyle.arabic,
      restartAtBody: false,
      countFrontMatterSeparately: false,
    ),
    breaks: BookBreakRules(),
  );

  /// Reflowable ebook. Pagination is nominal; the reader owns it.
  static const epub = BookFormat(
    id: 'epub',
    label: 'EPUB',
    reflowable: true,
    trim: TrimSize.sixByNine,
    margins: BookMargins(
      topPt: 36,
      bottomPt: 36,
      outsidePt: 36,
      insidePt: 36,
      mirrored: false,
    ),
    typography: BookTypography(
      bodySizePt: 11,
      leadingMultiple: 1.5,
      firstLineIndentPt: 14,
    ),
    chapter: ChapterStyle(startRule: ChapterStartRule.nextPage),
    runningHead: RunningHead(
      verso: RunningHeadContent.none,
      recto: RunningHeadContent.none,
    ),
    numbering: PageNumbering(position: PageNumberPosition.none),
    breaks: BookBreakRules(),
  );

  /// Every built-in, in the order the picker shows them.
  static const List<BookFormat> all = [
    paperback,
    hardcover,
    largePrint,
    printOnDemand,
    ebook,
    epub,
  ];

  /// The presets that can drive a paginated export.
  static List<BookFormat> get paginated =>
      all.where((format) => !format.reflowable).toList(growable: false);

  static BookFormat byId(String id) => all.firstWhere(
        (format) => format.id == id,
        orElse: () => paperback,
      );
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
