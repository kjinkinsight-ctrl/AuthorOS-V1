import 'package:author_studio_v1/book/book_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookDictionary dictionary;

  setUpAll(() async {
    BookDictionary.resetCache();
    dictionary = await BookDictionary.load();
  });

  test('the bundled list loads and is the size we shipped', () {
    expect(dictionary.wordCount, greaterThan(100000));
  });

  test('knows ordinary and uncommon words alike', () {
    // Under-flagging is a mild annoyance; over-flagging a novelist's prose is
    // what makes a spellchecker get switched off. The list is the full one.
    for (final word in [
      'knife', 'house', 'winter', 'river',
      'crenellated', 'palimpsest', 'susurrus', 'thaumaturgy', 'sepulcher',
    ]) {
      expect(dictionary.contains(word), isTrue, reason: '"$word" should be known');
    }
  });

  test('knows British spellings, which the American list does not hold', () {
    // The bundled list is American. A British author flagged on "colour" and
    // "realise" every page is an author who switches the checker off, so the
    // systematic differences are undone at lookup rather than shipped as a
    // second word list.
    for (final word in [
      'colour', 'honour', 'favourite', 'neighbour', 'labour', 'armour',
      'realise', 'organise', 'apologise', 'organisation', 'realised',
      'centre', 'metre', 'theatre', 'fibre',
      'defence', 'offence', 'pretence',
      'catalogue', 'dialogue',
      'travelling', 'cancelled', 'marvellous',
      'sceptical', 'pyjamas', 'aluminium', 'jewellery', 'sepulchre',
      'manoeuvre', 'plough', 'grey', 'tyre', 'moustache', 'whilst',
    ]) {
      expect(dictionary.contains(word), isTrue,
          reason: '"$word" is how a British author spells it');
    }
  });

  test('mapping British forms does not start accepting typos', () {
    for (final word in ['colouur', 'realiise', 'centrre', 'neighbourr']) {
      expect(dictionary.contains(word), isFalse, reason: '"$word" is a typo');
    }
  });

  test('does not know a typo', () {
    for (final word in ['teh', 'knfie', 'hte', 'recieveing']) {
      expect(dictionary.contains(word), isFalse, reason: '"$word" is a typo');
    }
  });

  test('is case insensitive', () {
    expect(dictionary.contains('Knife'), isTrue);
    expect(dictionary.contains('KNIFE'), isTrue);
  });

  test('derives possessives rather than listing them', () {
    expect(dictionary.contains("knife's"), isTrue);
    expect(dictionary.contains('knife’s'), isTrue, reason: 'typographic too');
    expect(dictionary.contains("boys'"), isTrue);
  });

  test('accepts a compound whose halves are both known', () {
    expect(dictionary.contains('blood-red'), isTrue);
    expect(dictionary.contains('knife-edge'), isTrue);
    expect(dictionary.contains('blood-xyzzy'), isFalse);
  });

  test('the author\'s own words are accepted without touching the list', () {
    final withNames = dictionary.withPersonal({'Endovier', 'Noxmere'});
    expect(withNames.contains('endovier'), isTrue);
    expect(withNames.contains('Noxmere'), isTrue);
    expect(withNames.contains("Endovier's"), isTrue);
    expect(dictionary.contains('Endovier'), isFalse,
        reason: 'the shared list is not mutated by one book\'s names');
  });
}
