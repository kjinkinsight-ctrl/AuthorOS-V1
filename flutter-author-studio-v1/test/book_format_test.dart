import 'package:author_studio_v1/book/book_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trim sizes', () {
    test('are expressed in points at 72 to the inch', () {
      expect(TrimSize.fiveHalfByEightHalf.widthPt, 5.5 * 72);
      expect(TrimSize.fiveHalfByEightHalf.heightPt, 8.5 * 72);
      expect(TrimSize.sixByNine.widthPt, 6 * 72);
      expect(TrimSize.sixByNine.heightPt, 9 * 72);
      expect(TrimSize.fiveByEight.widthPt, 5 * 72);
      expect(TrimSize.fiveQuarterByEight.widthPt, 5.25 * 72);
    });

    test('a custom trim labels itself in inches', () {
      expect(TrimSize.custom(5.5 * 72, 8.5 * 72).label, '5.5 x 8.5 in');
      expect(TrimSize.custom(6 * 72, 9 * 72).label, '6 x 9 in');
    });

    test('round-trip through JSON', () {
      final restored =
          TrimSize.fromJson(TrimSize.fiveHalfByEightHalf.toJson());
      expect(restored, TrimSize.fiveHalfByEightHalf);
    });

    test('an unknown id falls back rather than throwing', () {
      expect(TrimSize.byId('not-a-trim'), TrimSize.sixByNine);
    });
  });

  group('margins', () {
    const margins = BookMargins(
      topPt: 54,
      bottomPt: 36,
      outsidePt: 36,
      insidePt: 54,
      gutterPt: 18,
    );

    test('the binding allowance sits on the spine edge of each side', () {
      final recto = margins.resolve(isRecto: true, totalPages: 200);
      final verso = margins.resolve(isRecto: false, totalPages: 200);

      expect(recto.leftPt, 54 + 18, reason: 'a recto binds on its left');
      expect(recto.rightPt, 36);
      expect(verso.rightPt, 54 + 18, reason: 'a verso binds on its right');
      expect(verso.leftPt, 36);
    });

    test('an unmirrored format puts the text block in the same place', () {
      const flat = BookMargins(
        topPt: 40,
        bottomPt: 40,
        outsidePt: 40,
        insidePt: 40,
        mirrored: false,
      );
      final recto = flat.resolve(isRecto: true, totalPages: 100);
      final verso = flat.resolve(isRecto: false, totalPages: 100);
      expect(recto, verso);
    });

    test('the measure is the same on both sides', () {
      const trim = TrimSize.sixByNine;
      final recto = margins.resolve(isRecto: true, totalPages: 200);
      final verso = margins.resolve(isRecto: false, totalPages: 200);
      expect(
        trim.widthPt - recto.leftPt - recto.rightPt,
        trim.widthPt - verso.leftPt - verso.rightPt,
        reason: 'this is why line breaking does not depend on the page side',
      );
    });

    test('the print-on-demand gutter grows by band', () {
      expect(BookMargins.podGutter(100), 27);
      expect(BookMargins.podGutter(200), 36);
      expect(BookMargins.podGutter(400), 45);
      expect(BookMargins.podGutter(600), 54);
      expect(BookMargins.podGutter(900), 63);
    });

    test('a fixed gutter ignores the page count', () {
      expect(margins.gutterFor(100), 18);
      expect(margins.gutterFor(900), 18);
    });

    test('a scaling gutter never falls below its floor', () {
      const scaling = BookMargins(
        topPt: 54,
        bottomPt: 36,
        outsidePt: 36,
        insidePt: 54,
        gutterPt: 40,
        scaleGutterByExtent: true,
      );
      expect(scaling.gutterFor(100), 40, reason: '27 would be below the floor');
      expect(scaling.gutterFor(900), 63);
    });
  });

  group('presets', () {
    test('every preset has a unique id and label', () {
      final ids = BookFormatPresets.all.map((format) => format.id);
      final labels = BookFormatPresets.all.map((format) => format.label);
      expect(ids.toSet(), hasLength(BookFormatPresets.all.length));
      expect(labels.toSet(), hasLength(BookFormatPresets.all.length));
    });

    test('the six presets from the brief are all present', () {
      expect(
        BookFormatPresets.all.map((format) => format.id),
        containsAll(<String>[
          'paperback',
          'hardcover',
          'epub',
          'ebook',
          'large-print',
          'print-on-demand',
        ]),
      );
    });

    test('only EPUB is reflowable, and it is excluded from paginated output',
        () {
      expect(BookFormatPresets.epub.reflowable, isTrue);
      expect(BookFormatPresets.paginated, isNot(contains(BookFormatPresets.epub)));
      for (final format in BookFormatPresets.paginated) {
        expect(format.reflowable, isFalse);
      }
    });

    test('only print formats align openers to a recto', () {
      expect(BookFormatPresets.paperback.requiresRectoStarts, isTrue);
      expect(BookFormatPresets.hardcover.requiresRectoStarts, isTrue);
      expect(BookFormatPresets.printOnDemand.requiresRectoStarts, isTrue);
      expect(BookFormatPresets.ebook.requiresRectoStarts, isFalse,
          reason: 'a blank verso reads as a bug on a screen');
      expect(BookFormatPresets.largePrint.requiresRectoStarts, isFalse);
    });

    test('large print is set ragged right at a readable size', () {
      const large = BookFormatPresets.largePrint;
      expect(large.typography.bodySizePt, greaterThanOrEqualTo(16));
      expect(large.typography.alignment, BookAlignment.left,
          reason: 'justifying large type on a narrow measure opens rivers');
      expect(large.chapter.dropCap, isFalse);
    });

    test('print-on-demand scales its gutter with the page count', () {
      expect(BookFormatPresets.printOnDemand.margins.scaleGutterByExtent,
          isTrue);
    });

    test('an unknown preset id falls back to paperback', () {
      expect(BookFormatPresets.byId('nope').id, 'paperback');
    });
  });

  group('customising a preset', () {
    test('a clone keeps its provenance so it can be reset', () {
      final custom = BookFormatPresets.hardcover.customise();
      expect(custom.basePresetId, 'hardcover');
      expect(custom.isCustomised, isTrue);
      expect(custom.id, isNot('hardcover'));
      expect(BookFormatPresets.hardcover.isCustomised, isFalse);
    });

    test('customising twice does not lose the original base', () {
      final once = BookFormatPresets.paperback.customise();
      final twice = once.customise();
      expect(twice.basePresetId, 'paperback');
    });

    test('a customised format stores every resolved value, not a diff', () {
      final custom = BookFormatPresets.paperback
          .customise()
          .copyWith(trim: TrimSize.sixByNine);
      final json = custom.toJson();

      // The whole specification must be present: storing only the difference
      // from a preset would silently reflow an author's book if a preset
      // default ever changed in an update.
      expect(json['trim'], isNotNull);
      expect(json['margins'], isNotNull);
      expect(json['typography'], isNotNull);
      expect(json['chapter'], isNotNull);
      expect(json['runningHead'], isNotNull);
      expect(json['numbering'], isNotNull);
      expect(json['breaks'], isNotNull);
    });
  });

  group('serialisation', () {
    test('every preset survives a JSON round trip', () {
      for (final preset in BookFormatPresets.all) {
        final restored = BookFormat.fromJson(preset.toJson());
        expect(restored.id, preset.id);
        expect(restored.label, preset.label);
        expect(restored.reflowable, preset.reflowable);
        expect(restored.trim, preset.trim);
        expect(restored.typography.bodySizePt, preset.typography.bodySizePt);
        expect(restored.typography.alignment, preset.typography.alignment);
        expect(restored.chapter.startRule, preset.chapter.startRule);
        expect(restored.numbering.frontMatterStyle,
            preset.numbering.frontMatterStyle);
        expect(restored.margins.scaleGutterByExtent,
            preset.margins.scaleGutterByExtent);
        expect(restored.breaks.minLinesAtPageTop,
            preset.breaks.minLinesAtPageTop);
      }
    });

    test('an empty or malformed blob yields a usable default', () {
      final fromNothing = BookFormat.fromJson(const {});
      expect(fromNothing.trim.widthPt, greaterThan(0));
      expect(fromNothing.typography.bodySizePt, greaterThan(0));

      final fromNonsense = BookFormat.fromJson(const {
        'typography': {'alignment': 'sideways'},
        'chapter': {'startRule': 'diagonally'},
      });
      expect(fromNonsense.typography.alignment, BookAlignment.justified);
      expect(fromNonsense.chapter.startRule, ChapterStartRule.recto);
    });

    test('two formats with the same values fingerprint the same', () {
      expect(
        BookFormatPresets.paperback.layoutFingerprint,
        BookFormat.fromJson(BookFormatPresets.paperback.toJson())
            .layoutFingerprint,
      );
      expect(
        BookFormatPresets.paperback.layoutFingerprint,
        isNot(BookFormatPresets.hardcover.layoutFingerprint),
      );
    });
  });

  group('reserved space', () {
    test('an empty running head reserves no vertical space', () {
      const empty = RunningHead(
        verso: RunningHeadContent.none,
        recto: RunningHeadContent.none,
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.reservedPt, 0);
      expect(const RunningHead().reservedPt, greaterThan(0));
    });

    test('suppressed page numbering reserves no vertical space', () {
      const none = PageNumbering(position: PageNumberPosition.none);
      expect(none.isEmpty, isTrue);
      expect(none.reservedPt, 0);
      expect(const PageNumbering().reservedPt, greaterThan(0));
    });
  });
}
