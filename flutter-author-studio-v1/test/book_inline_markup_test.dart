import 'package:author_studio_v1/book/book_format.dart';
import 'package:author_studio_v1/book/inline_markup.dart';
import 'package:flutter_test/flutter_test.dart';

const _on = BookInlineMarkup.underscoreItalic;
const _off = BookInlineMarkup.none;

List<ProseSpan> parse(String text) => parseProse(text, _on);

/// The emphasised text, in order.
List<String> italics(String text) =>
    parse(text).where((s) => s.italic).map((s) => s.text).toList();

void main() {
  group('with the convention off', () {
    test('an underscore is just an underscore', () {
      final spans = parseProse('She wrote _quickly_ and left.', _off);
      expect(spans, hasLength(1));
      expect(spans.single.italic, isFalse);
      expect(spans.single.text, 'She wrote _quickly_ and left.');
    });

    test('nothing is stripped', () {
      expect(stripProse('a _b_ c', _off), 'a _b_ c');
      expect(hasEmphasis('a _b_ c', _off), isFalse);
    });
  });

  group('what emphasis looks like', () {
    test('a phrase between markers', () {
      expect(italics('She read _The Kestrel_ twice.'), ['The Kestrel']);
    });

    test('one word', () {
      expect(italics('He _knew_.'), ['knew']);
    });

    test('the whole paragraph', () {
      expect(italics('_Everything, all of it._'), ['Everything, all of it.']);
    });

    test('more than once', () {
      expect(italics('_Yes_, she thought, _finally_.'), ['Yes', 'finally']);
    });

    test('the markers are removed and nothing else changes', () {
      expect(stripProse('She read _The Kestrel_ twice.', _on),
          'She read The Kestrel twice.');
    });

    test('the spans concatenate back to the stripped paragraph', () {
      const source = 'A _b_ c _d_ e';
      expect(parse(source).map((s) => s.text).join(), stripProse(source, _on));
    });

    test('emphasis ending on punctuation, which is how prose actually ends it',
        () {
      for (final ending in const ['.', ',', '!', '?', ';', ':', ')', '”', '—']) {
        expect(italics('The _Kestrel_$ending sailed'), ['Kestrel'],
            reason: 'emphasis must be allowed to close before $ending');
      }
    });

    test('emphasis opening after punctuation', () {
      expect(italics('("_Now_")'), ['Now']);
      expect(italics('She said—_no_—and stopped.'), ['no']);
    });
  });

  group('underscores that are not emphasis', () {
    // Every one of these, wrongly italicised, silently rewrites a page.
    test('inside a word', () {
      expect(italics('The file was called snake_case_name today.'), isEmpty);
      expect(stripProse('snake_case_name', _on), 'snake_case_name');
    });

    test('a lone opener with no close', () {
      expect(italics('An underscore _ on its own.'), isEmpty);
      expect(italics('She started _but never finished'), isEmpty);
      expect(stripProse('She started _but never finished', _on),
          'She started _but never finished');
    });

    test('a marker with a space after it opens nothing', () {
      expect(italics('a _ b _ c'), isEmpty);
    });

    test('a doubled underscore is a literal one', () {
      expect(italics('__not emphasis__'), isEmpty);
      expect(stripProse('__not emphasis__', _on), '_not emphasis_');
    });

    test('emphasis never runs past the end of a paragraph', () {
      // The failure that would matter most: one dropped marker italicising
      // everything after it.
      final spans = parse('He said _wait and then the whole rest of it went on');
      expect(spans.every((s) => !s.italic), isTrue);
      expect(spans.map((s) => s.text).join(),
          'He said _wait and then the whole rest of it went on');
    });
  });

  group('unclosed emphasis is reported rather than guessed at', () {
    test('an opener with no closer is noticed', () {
      expect(hasUnclosedEmphasis('She started _but never finished', _on),
          isTrue);
    });

    test('properly closed emphasis is not', () {
      expect(hasUnclosedEmphasis('She _finished_ it.', _on), isFalse);
    });

    test('an underscore that was never a marker is not', () {
      expect(hasUnclosedEmphasis('snake_case_name', _on), isFalse);
      expect(hasUnclosedEmphasis('nothing here at all', _on), isFalse);
    });

    test('nothing is reported when the convention is off', () {
      expect(hasUnclosedEmphasis('She started _but never finished', _off),
          isFalse);
    });
  });

  group('edges', () {
    test('an empty paragraph is still one span', () {
      expect(parse(''), [const ProseSpan('')]);
      expect(parseProse('', _off), [const ProseSpan('')]);
    });

    test('emphasis at the very start and very end', () {
      expect(italics('_Start_ of it'), ['Start']);
      expect(italics('the end of _it_'), ['it']);
    });

    test('adjacent emphasis', () {
      expect(italics('_one_ _two_'), ['one', 'two']);
    });

    test('a marker inside a word opens nothing, and that is the trade', () {
      // `un_believable_` and `snake_case_name` are the same shape: a letter,
      // a marker, a letter. Only one of them can win, and protecting prose
      // that was never meant as emphasis matters more than mid-word italics,
      // which novels barely use.
      expect(italics('It was un_believable_.'), isEmpty);
      expect(stripProse('It was un_believable_.', _on),
          'It was un_believable_.');
    });

    test('a word can still span two faces, where a closer meets punctuation',
        () {
      // The line breaker has to cope with this: `Kestrel_'s` is one word for
      // breaking purposes and two segments for measuring and drawing.
      final spans = parse("The _Kestrel_'s deck");
      expect(spans.map((s) => s.text).join(), "The Kestrel's deck");
      expect(italics("The _Kestrel_'s deck"), ['Kestrel']);
      expect(spans.map((s) => (s.text, s.italic)), [
        ('The ', false),
        ('Kestrel', true),
        ("'s deck", false),
      ]);
    });

    test('curly quotes around emphasis', () {
      expect(italics('She said “_no_” and left.'), ['no']);
    });

    test('an escaped underscore inside emphasis', () {
      expect(italics('The _snake__case_ rule'), ['snake_case']);
    });

    test('parsing is stable — the same input twice gives the same spans', () {
      const source = 'A _b_ c __d__ e_f_g _h_';
      expect(parse(source), parse(source));
    });
  });
}
