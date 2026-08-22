/// Book Studio Phase 3 — offline spelling.
///
/// The dictionary is a plain sorted word list, gzipped, loaded from the asset
/// bundle. Three properties matter and each cost a decision:
///
/// **It is offline.** No lookup leaves the device, which is the same promise
/// the rest of AuthorOS makes. An author's unpublished manuscript is not sent
/// anywhere to be checked.
///
/// **It is loaded lazily.** 350 KB is a real download, and most sessions never
/// open the Proofing stage. Nothing touches the asset until a proofing pass
/// actually runs, so it stays off the path that decides how long the app takes
/// to start.
///
/// **It errs towards silence.** Under-flagging is a mild annoyance;
/// over-flagging makes a spellchecker useless in a novel, where the author's
/// own invented words are the point. So the list is the full 128,000 rather
/// than a trimmed common-words set, possessives are derived at lookup, and the
/// author's records supply their proper nouns for free.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'proofing.dart';

/// An English dictionary backed by the bundled word list.
class BookDictionary implements SpellingDictionary {
  BookDictionary._(this._words, this._personal);

  final Set<String> _words;
  final Set<String> _personal;

  static const assetPath = 'assets/dictionaries/en.txt.gz';

  /// Held for the session once loaded. Inflating and splitting 128,000 words
  /// is not free, and the studio re-proofs on every edit.
  static BookDictionary? _cache;

  @override
  Set<String> get personal => Set.unmodifiable(_personal);

  int get wordCount => _words.length;

  /// Loads the bundled list, decompressing it in pure Dart so this works on
  /// the web as well as on device.
  ///
  /// [personal] are the author's own words — record titles, invented terms —
  /// and are matched case-insensitively like everything else.
  static Future<BookDictionary> load({
    Set<String> personal = const {},
  }) async {
    final cached = _cache;
    if (cached != null) return cached.withPersonal(personal);

    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return (_cache = fromGzip(bytes)).withPersonal(personal);
  }

  /// Builds a dictionary from gzipped bytes. Exposed for tests.
  static BookDictionary fromGzip(Uint8List bytes) {
    final inflated = const GZipDecoder().decodeBytes(bytes);
    final text = utf8.decode(inflated, allowMalformed: true);
    return BookDictionary._(
      text.split('\n').where((word) => word.isNotEmpty).toSet(),
      <String>{},
    );
  }

  /// The same word list with a different set of the author's own words.
  ///
  /// Shares the underlying list rather than copying it: the personal words
  /// change whenever a record is renamed, and the 128,000 do not.
  BookDictionary withPersonal(Set<String> personal) => BookDictionary._(
        _words,
        {
          for (final word in personal)
            if (word.trim().isNotEmpty) word.trim().toLowerCase(),
        },
      );

  /// Drops the cached list. For tests.
  static void resetCache() => _cache = null;

  @override
  bool contains(String word) {
    final lower = word.toLowerCase().replaceAll('’', "'");
    if (_known(lower)) return true;

    // A possessive is looked up as its stem, so neither the word list nor the
    // author has to carry both forms.
    if (lower.endsWith("'s") && _known(lower.substring(0, lower.length - 2))) {
      return true;
    }
    if (lower.endsWith("'") && _known(lower.substring(0, lower.length - 1))) {
      return true;
    }

    // A hyphenated compound counts as spelled correctly when both halves are.
    // English coins these freely, and listing them all is hopeless.
    if (lower.contains('-')) {
      final parts = lower.split('-').where((part) => part.isNotEmpty).toList();
      if (parts.length > 1 && parts.every(_known)) return true;
    }

    // British spellings, mapped back to the forms the list holds.
    for (final variant in _americanForms(lower)) {
      if (_known(variant)) return true;
    }

    return false;
  }

  bool _known(String candidate) =>
      _personal.contains(candidate) || _words.contains(candidate);

  /// The American spellings a British word might be listed under.
  ///
  /// The bundled list is American: it has `color` and not `colour`, `realize`
  /// and not `realise`. Left alone that would flag a British author on nearly
  /// every page, which is precisely the over-flagging that gets a spellchecker
  /// switched off for good.
  ///
  /// Rather than carry a second word list, the systematic differences are
  /// undone at lookup. This costs no download at all, and it cannot turn a
  /// typo into a word unless the typo happens to map onto a real American
  /// spelling — which is both rare and harmless.
  static Iterable<String> _americanForms(String word) sync* {
    final irregular = _irregulars[word];
    if (irregular != null) yield irregular;

    // -our -> -or: colour, honour, neighbour, labour.
    if (word.contains('our')) {
      yield word.replaceAll('our', 'or');
    }
    // -ise/-isation -> -ize/-ization: realise, organisation.
    if (word.contains('is')) {
      yield word
          .replaceAll('isation', 'ization')
          .replaceAll('ising', 'izing')
          .replaceAll('ised', 'ized')
          .replaceAll('ises', 'izes')
          .replaceAll(RegExp(r'ise$'), 'ize');
    }
    // -re -> -er: centre, metre, theatre, fibre.
    if (word.endsWith('re')) {
      yield '${word.substring(0, word.length - 2)}er';
    }
    if (word.endsWith('res')) {
      yield '${word.substring(0, word.length - 3)}ers';
    }
    // -ence -> -ense: defence, offence, pretence.
    if (word.endsWith('ence')) {
      yield '${word.substring(0, word.length - 4)}ense';
    }
    // -ogue -> -og: catalogue, dialogue.
    if (word.endsWith('ogue')) {
      yield '${word.substring(0, word.length - 4)}og';
    }
    // Doubled l before a suffix: travelling, cancelled, marvellous.
    if (word.contains('ll')) {
      yield word
          .replaceAll('lling', 'ling')
          .replaceAll('lled', 'led')
          .replaceAll('llor', 'lor')
          .replaceAll('llous', 'lous');
    }
    // ae and oe ligatures: anaemia, foetus, oesophagus.
    if (word.contains('ae') || word.contains('oe')) {
      yield word.replaceAll('ae', 'e').replaceAll('oe', 'e');
    }
  }

  /// Differences no rule covers.
  static const _irregulars = <String, String>{
    'aeroplane': 'airplane',
    'aluminium': 'aluminum',
    'axe': 'ax',
    'draught': 'draft',
    'draughts': 'drafts',
    'grey': 'gray',
    'greyer': 'grayer',
    'greyest': 'grayest',
    'jewellery': 'jewelry',
    'kerb': 'curb',
    'manoeuvre': 'maneuver',
    'manoeuvred': 'maneuvered',
    'manoeuvres': 'maneuvers',
    'moustache': 'mustache',
    'plough': 'plow',
    'ploughed': 'plowed',
    'pyjamas': 'pajamas',
    'sceptic': 'skeptic',
    'sceptical': 'skeptical',
    'scepticism': 'skepticism',
    'sepulchre': 'sepulcher',
    'storey': 'story',
    'storeys': 'stories',
    'sulphur': 'sulfur',
    'tyre': 'tire',
    'tyres': 'tires',
    'whilst': 'while',
  };
}
