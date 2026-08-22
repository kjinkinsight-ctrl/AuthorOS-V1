import 'dart:convert';

import 'package:author_studio_v1/core/prose_document.dart';
import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plain-text round trip', () {
    // The migration turns every existing scene into a document and reads it
    // back as a string. If any input survives that trip changed, prose is lost
    // the first time a manuscript is opened -- so this is checked exhaustively
    // rather than with one happy example.
    const inputs = <String>[
      '',
      'One line.',
      'One line.\n',
      '\nLeading blank line.',
      'Two\nlines.',
      'A paragraph.\n\nAnother paragraph.',
      'Three\n\n\nblank lines between.',
      '   leading and trailing spaces   ',
      'Trailing newlines.\n\n\n',
      'Tabs\tand  double  spaces.',
      'Unicode: Kali — “the red knife” — ✦',
    ];

    for (final input in inputs) {
      test('returns ${jsonEncode(input)} unchanged', () {
        expect(ProseDocument.fromPlainText(input).plainText, input);
      });
    }

    test('survives a JSON round trip', () {
      for (final input in inputs) {
        final encoded = jsonEncode(ProseDocument.fromPlainText(input).toJson());
        final decoded = ProseDocument.fromJson(
          Map<String, dynamic>.from(jsonDecode(encoded) as Map),
        );
        expect(decoded.plainText, input, reason: input);
      }
    });
  });

  group('word count', () {
    test('agrees with the scene word count it replaced', () {
      // The two must not drift: writing sessions, streaks, goals and progress
      // bars are all built on this number.
      const samples = <String>[
        '',
        '   ',
        'One',
        'Two words',
        'Spaced   out   words',
        'Line one\nline two',
        '\n\nKali crosses the causeway.\n\n',
      ];
      for (final sample in samples) {
        final scene = ManuscriptScene(
          id: 'scene',
          chapterId: 'chapter',
          title: 'Scene',
          order: 1,
          content: sample,
          status: ManuscriptNodeStatus.draft,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        expect(
          ProseDocument.fromPlainText(sample).wordCount,
          scene.wordCount,
          reason: jsonEncode(sample),
        );
      }
    });

    test('counts nothing in whitespace', () {
      expect(ProseDocument.fromPlainText('  \n \t \n ').wordCount, 0);
    });
  });

  group('encoding', () {
    test('unformatted prose is stored as text, not as blocks', () {
      // Every scene written before the document model has this shape. Storing
      // it as a block list would inflate the manuscript on disk for nothing.
      final json = ProseDocument.fromPlainText('A plain scene.').toJson();
      expect(json['text'], 'A plain scene.');
      expect(json.containsKey('blocks'), isFalse);
      expect(json['schema'], ProseDocument.schemaVersion);
    });

    test('formatted prose is stored as blocks', () {
      const document = ProseDocument([
        ProseBlock(kind: ProseBlockKind.heading1, spans: [ProseSpan('Part One')]),
        ProseBlock(spans: [
          ProseSpan('She said '),
          ProseSpan('nothing', marks: {ProseMark.italic}),
          ProseSpan('.'),
        ]),
      ]);
      final json = document.toJson();
      expect(json.containsKey('blocks'), isTrue);
      expect(json.containsKey('text'), isFalse);

      final restored = ProseDocument.fromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map),
      );
      expect(restored, document);
      expect(restored.plainText, 'Part One\nShe said nothing.');
      expect(restored.blocks.first.kind, ProseBlockKind.heading1);
      expect(restored.blocks[1].spans[1].marks, {ProseMark.italic});
    });

    test('a mark this build does not know is dropped, the words are not', () {
      // An older build opening a newer build's document loses the styling it
      // cannot draw. Losing the sentence instead would be unforgivable.
      final restored = ProseDocument.fromJson({
        'schema': 1,
        'blocks': [
          {
            'kind': 'someFutureBlock',
            'spans': [
              {
                'text': 'Kali waited.',
                'marks': ['bold', 'someFutureMark'],
              }
            ],
          }
        ],
      });
      expect(restored.plainText, 'Kali waited.');
      expect(restored.blocks.single.kind, ProseBlockKind.paragraph);
      expect(restored.blocks.single.spans.single.marks, {ProseMark.bold});
    });

    test('an empty document is the same as empty text', () {
      expect(ProseDocument.fromPlainText(''), ProseDocument.empty);
      expect(ProseDocument.empty.isEmpty, isTrue);
      expect(ProseDocument.empty.wordCount, 0);
    });
  });

  group('equality', () {
    test('documents compare by content, so a save can tell nothing changed',
        () {
      expect(
        ProseDocument.fromPlainText('Kali waited.'),
        ProseDocument.fromPlainText('Kali waited.'),
      );
      expect(
        ProseDocument.fromPlainText('Kali waited.'),
        isNot(ProseDocument.fromPlainText('Kali waited')),
      );
    });

    test('marks compare regardless of the order they were written in', () {
      expect(
        const ProseSpan('x', marks: {ProseMark.bold, ProseMark.italic}),
        const ProseSpan('x', marks: {ProseMark.italic, ProseMark.bold}),
      );
    });
  });
}
