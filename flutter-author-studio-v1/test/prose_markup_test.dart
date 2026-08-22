import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/core/prose_markup.dart';
import 'package:flutter_test/flutter_test.dart';

ProseMarkup _bold(String text, int start, int end) => ProseMarkup(
      text: text,
      ranges: [
        MarkedRange(start: start, end: end, marks: const {ProseMark.bold}),
      ],
    );

void main() {
  group('document round trip', () {
    test('plain prose survives unchanged', () {
      const samples = <String>[
        '',
        'One line.',
        'Two\nlines.',
        'A paragraph.\n\nAnother.',
        'Trailing newline.\n',
        '   spaced   ',
      ];
      for (final sample in samples) {
        final document = ProseDocument.fromPlainText(sample);
        final markup = ProseMarkup.fromDocument(document);
        expect(markup.text, sample, reason: sample);
        expect(markup.toDocument(), document, reason: sample);
      }
    });

    test('marks survive the trip out and back', () {
      const document = ProseDocument([
        ProseBlock(spans: [
          ProseSpan('She said '),
          ProseSpan('nothing', marks: {ProseMark.italic}),
          ProseSpan(' at all.'),
        ]),
      ]);

      final markup = ProseMarkup.fromDocument(document);
      expect(markup.text, 'She said nothing at all.');
      expect(markup.ranges, hasLength(1));
      expect(markup.ranges.single.start, 9);
      expect(markup.ranges.single.end, 16);
      expect(markup.toDocument(), document);
    });

    test('marks spanning a line break survive', () {
      final markup = ProseMarkup(
        text: 'first line\nsecond line',
        ranges: [
          const MarkedRange(start: 6, end: 17, marks: {ProseMark.bold}),
        ],
      );
      final restored = ProseMarkup.fromDocument(markup.toDocument());
      expect(restored.text, markup.text);
      expect(restored.ranges, markup.ranges);
    });

    test('block kinds survive an edit that has no UI for them', () {
      // Nothing can create a heading yet, but an archive can carry one. It
      // must not be flattened the first time an author types.
      final markup = ProseMarkup(
        text: 'Part One\nThe harbour.',
        blockKinds: const [ProseBlockKind.heading1, ProseBlockKind.paragraph],
      );

      final edited = markup.withText('Part One\nThe harbour was quiet.');

      expect(edited.blockKinds.first, ProseBlockKind.heading1);
      expect(edited.toDocument().blocks.first.kind, ProseBlockKind.heading1);
    });
  });

  group('toggling', () {
    test('adds a mark to an unmarked selection', () {
      final markup = ProseMarkup(text: 'Kali waited.');
      final bolded = markup.toggle(ProseMark.bold, 0, 4);

      expect(bolded.ranges, hasLength(1));
      expect(bolded.ranges.single.start, 0);
      expect(bolded.ranges.single.end, 4);
      expect(bolded.marksIn(0, 4), {ProseMark.bold});
    });

    test('removes it when the whole selection already has it', () {
      final markup = _bold('Kali waited.', 0, 4);
      expect(markup.toggle(ProseMark.bold, 0, 4).ranges, isEmpty);
    });

    test('adds rather than removes when only part of the selection has it', () {
      // Pressing bold on a half-bold selection should make it all bold, not
      // strip the bold half. Otherwise the button's meaning depends on where
      // the selection started.
      final markup = _bold('Kali waited.', 0, 4);
      final toggled = markup.toggle(ProseMark.bold, 0, 12);

      expect(toggled.marksIn(0, 12), {ProseMark.bold});
      expect(toggled.ranges, hasLength(1));
    });

    test('marks compose rather than replace', () {
      final markup = ProseMarkup(text: 'Kali waited.')
          .toggle(ProseMark.bold, 0, 4)
          .toggle(ProseMark.italic, 0, 4);

      expect(markup.marksIn(0, 4), {ProseMark.bold, ProseMark.italic});
      expect(markup.ranges, hasLength(1));
    });

    test('removing one mark leaves the others', () {
      final markup = ProseMarkup(text: 'Kali waited.')
          .toggle(ProseMark.bold, 0, 4)
          .toggle(ProseMark.italic, 0, 4)
          .toggle(ProseMark.bold, 0, 4);

      expect(markup.marksIn(0, 4), {ProseMark.italic});
    });

    test('splits a run when only its middle is toggled', () {
      final markup = _bold('one two three', 0, 13)
          .toggle(ProseMark.bold, 4, 7);

      expect(markup.marksIn(0, 4), {ProseMark.bold});
      expect(markup.marksIn(4, 7), isEmpty);
      expect(markup.marksIn(7, 13), {ProseMark.bold});
    });

    test('adjacent runs with the same marks are merged', () {
      final markup = ProseMarkup(text: 'Kali waited.')
          .toggle(ProseMark.bold, 0, 4)
          .toggle(ProseMark.bold, 4, 12);

      expect(markup.ranges, hasLength(1));
      expect(markup.ranges.single.start, 0);
      expect(markup.ranges.single.end, 12);
    });

    test('an empty selection changes nothing', () {
      final markup = ProseMarkup(text: 'Kali waited.');
      expect(markup.toggle(ProseMark.bold, 3, 3), markup);
    });
  });

  group('marksIn', () {
    test('reports only what the whole selection shares', () {
      final markup = _bold('Kali waited.', 0, 4);
      expect(markup.marksIn(0, 4), {ProseMark.bold});
      expect(markup.marksIn(0, 12), isEmpty);
    });

    test('an empty selection reports the marks behind the caret', () {
      // What decides the formatting of the next character typed.
      final markup = _bold('Kali waited.', 0, 4);
      expect(markup.marksIn(4, 4), {ProseMark.bold});
      expect(markup.marksIn(0, 0), isEmpty);
      expect(markup.marksIn(6, 6), isEmpty);
    });
  });

  group('re-anchoring after an edit', () {
    test('an insertion before a run pushes it along', () {
      final markup = _bold('Kali waited.', 5, 11);
      final edited = markup.withText('Lady Kali waited.');

      expect(edited.ranges.single.start, 10);
      expect(edited.ranges.single.end, 16);
      expect(
        edited.text.substring(
          edited.ranges.single.start,
          edited.ranges.single.end,
        ),
        'waited',
      );
    });

    test('an insertion after a run leaves it alone', () {
      final markup = _bold('Kali waited.', 0, 4);
      final edited = markup.withText('Kali waited a long time.');

      expect(edited.ranges.single.start, 0);
      expect(edited.ranges.single.end, 4);
    });

    test('typing inside a run extends it', () {
      final markup = _bold('Kali waited.', 0, 4);
      final edited = markup.withText('Kalixi waited.');

      expect(edited.marksIn(0, 6), {ProseMark.bold});
    });

    test('typing at the trailing edge of a run keeps typing in it', () {
      // What every editor does: reaching the end of a bold word and carrying
      // on types more bold.
      final markup = _bold('Kali waited.', 0, 4);
      final edited = markup.withText('Kalis waited.');

      expect(edited.marksIn(0, 5), {ProseMark.bold});
    });

    test('typing at the leading edge does not', () {
      // So a bold word can still be prefixed with plain text.
      final markup = _bold('Kali waited.', 0, 4);
      final edited = markup.withText('OKali waited.');

      expect(edited.marksIn(0, 1), isEmpty);
      expect(edited.marksIn(1, 5), {ProseMark.bold});
    });

    test('deleting a run takes its marks with it', () {
      final markup = _bold('Kali waited.', 0, 5);
      final edited = markup.withText('waited.');

      expect(edited.ranges, isEmpty);
    });

    test('deleting across a run clips it', () {
      final markup = _bold('one two three', 4, 7);
      final edited = markup.withText('one three');

      expect(edited.marksIn(0, edited.text.length), isEmpty);
    });

    test('clearing the text clears the marks', () {
      expect(_bold('Kali waited.', 0, 4).withText('').ranges, isEmpty);
    });

    test('plain prose stays cheap to re-anchor', () {
      final markup = ProseMarkup(text: 'Kali waited.');
      final edited = markup.withText('Kali waited a while.');

      expect(edited.isPlain, isTrue);
      expect(edited.text, 'Kali waited a while.');
    });
  });

  group('isPlain', () {
    test('is true for unmarked paragraphs', () {
      expect(ProseMarkup(text: 'Kali waited.').isPlain, isTrue);
    });

    test('is false once anything is marked', () {
      expect(_bold('Kali waited.', 0, 4).isPlain, isFalse);
    });

    test('is false for a non-paragraph block', () {
      expect(
        ProseMarkup(
          text: 'Part One',
          blockKinds: const [ProseBlockKind.heading1],
        ).isPlain,
        isFalse,
      );
    });
  });
}
