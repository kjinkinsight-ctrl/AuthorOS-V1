/// The Command System's deterministic grammar.
///
/// AuthorOS is AI-free by design, so an author's phrase is read by rules rather
/// than by a model. The rules are not the interesting part: the *vocabulary* is.
/// Almost every noun and verb this grammar knows is derived at run time from
/// [RecordTypeRegistry] and [ConnectionTypeRegistry], which already carry ~224
/// record types and ~130 connection types and already merge a project's own
/// custom definitions. A type a project invents this afternoon is queryable by
/// name this afternoon, with no code change and no list to maintain here.
///
/// The only hardcoded words are English function words — "show", "all", "with
/// no", "before". Those are the grammar; the domain nouns are the data.
///
/// Parsing never throws and never fails. A phrase the rules cannot read becomes
/// a [CommandQuery.freeText], which the service layer runs as a plain full-text
/// search — the thing the author most likely wanted anyway.
library;

import 'command_query.dart';
import 'connection_types.dart';
import 'record_types.dart';

/// The phrase table the grammar matches against.
///
/// Built once per registry pair and safe to reuse: it holds no mutable state.
class CommandVocabulary {
  CommandVocabulary._({
    required Map<String, CommandSubject> subjects,
    required Map<String, CommandRelation> relations,
    required this.longestSubjectPhrase,
    required this.longestRelationPhrase,
  })  : _subjects = subjects,
        _relations = relations;

  /// Derives the vocabulary from the live registries.
  factory CommandVocabulary.fromRegistries({
    required RecordTypeRegistry records,
    required ConnectionTypeRegistry connections,
  }) {
    final subjects = <String, CommandSubject>{};
    final relations = <String, CommandRelation>{};

    // A subject is a family, not one type. "characters" must cover every type
    // that inherits `character`, including a project's own, so the family is the
    // inheritance closure the registry can already compute.
    final descendants = <String, Set<String>>{};
    for (final definition in records.definitions) {
      final family = <String>{definition.id};
      for (final candidate in records.definitions) {
        if (candidate.id != definition.id &&
            records.isTemplateCompatible(candidate.id, definition.id)) {
          family.add(candidate.id);
        }
      }
      descendants[definition.id] = family;
    }

    void addSubject(String phrase, CommandSubject subject) {
      final key = _normalize(phrase);
      if (key.isEmpty) return;
      final existing = subjects[key];
      // Two types can legitimately share a name — the `event` alias and
      // `timeline-event` both read as "Event". Merging rather than letting one
      // win means "events" searches both, which is what was meant.
      subjects[key] = existing == null
          ? subject
          : CommandSubject(
              label: existing.label,
              recordTypeIds: {...existing.recordTypeIds, ...subject.recordTypeIds},
              nodeTypes: {...existing.nodeTypes, ...subject.nodeTypes},
            );
    }

    for (final definition in records.definitions) {
      final family = descendants[definition.id] ?? {definition.id};
      final subject = CommandSubject(
        label: definition.name,
        recordTypeIds: family,
      );
      for (final phrase in _inflect(_humanize(definition.id))) {
        addSubject(phrase, subject);
      }
      for (final phrase in _inflect(definition.name)) {
        addSubject(phrase, subject);
      }
    }

    // Categories are how an author speaks when they do not have a type in mind:
    // "show all research", "show every location".
    final byCategory = <String, Set<String>>{};
    for (final definition in records.definitions) {
      byCategory
          .putIfAbsent(definition.categoryId, () => <String>{})
          .addAll(descendants[definition.id] ?? {definition.id});
    }
    byCategory.forEach((categoryId, typeIds) {
      final subject = CommandSubject(
        label: _titleCase(_humanize(categoryId)),
        recordTypeIds: typeIds,
      );
      // A category id may already be plural (`characters`, `locations`), so it
      // is inflected from its singular as well. Without that, "character" and
      // "characters" would resolve to different families and an author would
      // get different answers for the same question.
      for (final phrase in _categoryPhrases(_humanize(categoryId))) {
        addSubject(phrase, subject);
      }
    });

    // Scenes and chapters are manuscript-domain nodes rather than records, and
    // a few unused record types shadow them. Declaring both here is the one
    // place the Command System has to know about the two node kinds.
    for (final nodeType in const ['scene', 'chapter']) {
      final subject = CommandSubject(
        label: _titleCase(nodeType),
        recordTypeIds: descendants[nodeType] ?? {nodeType},
        nodeTypes: {nodeType},
      );
      for (final phrase in _inflect(nodeType)) {
        addSubject(phrase, subject);
      }
    }

    void addRelation(String phrase, CommandRelation relation) {
      final key = _normalize(phrase);
      if (key.isEmpty || subjects.containsKey(key)) return;
      relations.putIfAbsent(key, () => relation);
    }

    for (final definition in connections.definitions) {
      final relation = CommandRelation(
        typeId: definition.id,
        label: definition.displayName,
      );
      // The id, the forward label and the inverse label all name the same edge,
      // so every relationship is speakable from either end for free.
      for (final source in <String>[
        _humanize(definition.id),
        definition.displayName,
        definition.inverseLabel,
      ]) {
        for (final phrase in _verbForms(source)) {
          addRelation(phrase, relation);
        }
      }
    }

    // Registered last so they win: an author writing "connected to" means any
    // edge, not the `relatedTo` type that happens to share the words.
    for (final phrase in const [
      'connected to',
      'connected with',
      'linked to',
      'linked with',
      'related to',
      'attached to',
      'tied to',
    ]) {
      relations[_normalize(phrase)] = CommandRelation.any;
    }

    // A handful of words authors use for a whole category that no type is
    // called. These are English, not domain data: they name an existing
    // category rather than listing types, so a new plot type still arrives
    // automatically. They merge with any same-named type rather than replacing
    // it, so "plot threads" reaches `plot-thread` and every plotline alike.
    _categoryAliases.forEach((phrase, categoryId) {
      final typeIds = byCategory[categoryId];
      if (typeIds == null) return;
      final subject = CommandSubject(
        label: _titleCase(_humanize(phrase)),
        recordTypeIds: typeIds,
      );
      for (final form in _inflect(phrase)) {
        addSubject(form, subject);
      }
    });

    // Reserved phrases override anything derived. "conflicts" as a command is
    // the canon-conflict report, not a list of `conflict` plot records.
    for (final phrase in const [
      'everything',
      'anything',
      'every record',
      'all records',
    ]) {
      subjects[_normalize(phrase)] = CommandSubject.anything;
    }
    for (final phrase in const [
      'canon conflicts',
      'canon conflict',
      'continuity conflicts',
      'continuity issues',
      'continuity problems',
      'conflicts',
    ]) {
      subjects[_normalize(phrase)] = CommandSubject.canonConflicts;
    }

    return CommandVocabulary._(
      subjects: subjects,
      relations: relations,
      longestSubjectPhrase: _longestPhrase(subjects.keys),
      longestRelationPhrase: _longestPhrase(relations.keys),
    );
  }

  final Map<String, CommandSubject> _subjects;
  final Map<String, CommandRelation> _relations;

  /// Word count of the longest known subject phrase, so the matcher knows how
  /// wide a window to try.
  final int longestSubjectPhrase;

  /// Word count of the longest known relation phrase.
  final int longestRelationPhrase;

  CommandSubject? subjectFor(String phrase) => _subjects[_normalize(phrase)];

  CommandRelation? relationFor(String phrase) => _relations[_normalize(phrase)];

  /// Every subject phrase the vocabulary knows, for suggestions and for tests
  /// that assert a custom type became speakable.
  Iterable<String> get subjectPhrases => _subjects.keys;

  /// Every relation phrase the vocabulary knows.
  Iterable<String> get relationPhrases => _relations.keys;
}

/// Reads an author's phrase into a [CommandQuery].
///
/// The parse is a pure function of its input and its vocabulary — no database,
/// no clock, no network — which is what makes the whole grammar testable
/// without seeding a project.
class CommandGrammar {
  const CommandGrammar(this.vocabulary);

  final CommandVocabulary vocabulary;

  CommandQuery parse(String input) {
    final words = _words(input);
    if (words.isEmpty) return CommandQuery.freeText(input.trim());
    return _Parse(vocabulary, input.trim(), words).run();
  }
}

// ---------------------------------------------------------------- the parser

class _Parse {
  _Parse(this.vocabulary, this.raw, this.words)
      : lower = words.map((word) => word.toLowerCase()).toList();

  final CommandVocabulary vocabulary;
  final String raw;
  final List<String> words;
  final List<String> lower;

  int index = 0;
  CommandVerb verb = CommandVerb.show;
  bool sawVerb = false;
  CommandSubject? subject;
  CommandRelation? relation;
  String? anchorPhrase;
  String? linkTargetPhrase;
  final List<CommandPredicate> predicates = [];
  final List<CommandTerm> terms = [];
  final List<String> ignored = [];

  CommandQuery run() {
    _readVerb();
    if (verb == CommandVerb.link) return _readLink();
    if (verb == CommandVerb.create) return _readCreate();
    _readBody();
    return _build();
  }

  // ------------------------------------------------------------------- verbs

  void _readVerb() {
    final match = _matchPhrase(_verbs, index, 3);
    if (match == null) return;
    verb = _verbs[match.phrase]!;
    sawVerb = true;
    terms.add(CommandTerm(
      kind: CommandTermKind.verb,
      text: match.text,
      label: _verbLabel(verb),
    ));
    index = match.end;
  }

  /// `link Kali to Endovier` — the only place " to " is structural.
  CommandQuery _readLink() {
    final separator = lower.indexOf('to', index);
    if (separator <= index || separator >= words.length - 1) {
      return CommandQuery.freeText(raw);
    }
    anchorPhrase = _slice(index, separator);
    linkTargetPhrase = _slice(separator + 1, words.length);
    terms
      ..add(CommandTerm(
        kind: CommandTermKind.anchor,
        text: anchorPhrase!,
        label: anchorPhrase!,
      ))
      ..add(CommandTerm(
        kind: CommandTermKind.anchor,
        text: linkTargetPhrase!,
        label: 'to ${linkTargetPhrase!}',
      ));
    return _build();
  }

  /// `create character Cassian` — a subject, then the new record's title.
  CommandQuery _readCreate() {
    _skipQuantifiers();
    final match = _matchSubject(index);
    if (match != null) {
      subject = match.subject;
      terms.add(CommandTerm(
        kind: CommandTermKind.subject,
        text: match.text,
        label: match.subject.label,
      ));
      index = match.end;
    }
    if (index >= words.length) return CommandQuery.freeText(raw);
    anchorPhrase = _slice(index, words.length);
    terms.add(CommandTerm(
      kind: CommandTermKind.anchor,
      text: anchorPhrase!,
      label: 'named ${anchorPhrase!}',
    ));
    index = words.length;
    return _build();
  }

  // -------------------------------------------------------------------- body

  void _readBody() {
    while (index < words.length) {
      if (_skipQuantifier()) continue;
      if (_readReservedSubject()) continue;
      if (_readMapPredicate()) continue;
      if (_readScopePredicate()) continue;
      if (_readOrderPredicate()) continue;
      if (_readMissingPredicate()) continue;
      if (_readStatusPredicate()) continue;
      if (_readRelation()) continue;
      if (_readSubject()) continue;
      if (_fillers.contains(lower[index])) {
        index += 1;
        continue;
      }
      ignored.add(words[index]);
      index += 1;
    }
  }

  bool _skipQuantifier() {
    if (index < words.length && _quantifiers.contains(lower[index])) {
      index += 1;
      return true;
    }
    return false;
  }

  void _skipQuantifiers() {
    while (_skipQuantifier()) {}
  }

  /// "everything", "canon conflicts" — phrases that must beat the derived
  /// vocabulary, so they are tried before the adjective and subject tables.
  bool _readReservedSubject() {
    final match = _matchSubject(index);
    if (match == null) return false;
    if (!match.subject.everything && !match.subject.isReport) return false;
    subject = match.subject;
    terms.add(CommandTerm(
      kind: CommandTermKind.subject,
      text: match.text,
      label: match.subject.label,
    ));
    index = match.end;
    return true;
  }

  bool _readMapPredicate() {
    final match = _matchPhrase(_mapMarkers, index, 3);
    if (match == null) return false;
    predicates.add(const CommandPredicate(
      kind: CommandPredicateKind.onMap,
      label: 'placed on a map',
    ));
    terms.add(CommandTerm(
      kind: CommandTermKind.predicate,
      text: match.text,
      label: 'on a map',
    ));
    index = match.end;
    return true;
  }

  bool _readScopePredicate() {
    final match = _matchPhrase(_scopeMarkers, index, 3);
    if (match == null) return false;
    final rest = _collectAnchor(match.end);
    if (rest.isEmpty) return false;
    final phrase = 'book $rest';
    predicates.add(CommandPredicate(
      kind: CommandPredicateKind.inBook,
      label: 'in $phrase',
      anchorPhrase: phrase,
    ));
    terms.add(CommandTerm(
      kind: CommandTermKind.scope,
      text: '${match.text} $rest',
      label: 'in $phrase',
    ));
    return true;
  }

  bool _readOrderPredicate() {
    final word = lower[index];
    final kind = switch (word) {
      'before' || 'preceding' => CommandPredicateKind.before,
      'after' || 'following' => CommandPredicateKind.after,
      _ => null,
    };
    if (kind == null) return false;
    final start = index;
    final rest = _collectAnchor(index + 1);
    if (rest.isEmpty) return false;
    predicates.add(CommandPredicate(
      kind: kind,
      label: '$word $rest',
      anchorPhrase: rest,
    ));
    terms.add(CommandTerm(
      kind: CommandTermKind.predicate,
      text: '${words[start]} $rest',
      label: '$word $rest',
    ));
    return true;
  }

  /// "with no location", "not yet assigned to a plot".
  bool _readMissingPredicate() {
    final match = _matchPhrase(_missingMarkers, index, 4);
    if (match == null) return false;
    var cursor = match.end;
    while (cursor < words.length && _articles.contains(lower[cursor])) {
      cursor += 1;
    }
    final target = _matchSubject(cursor);
    if (target == null) return false;
    predicates.add(CommandPredicate(
      kind: CommandPredicateKind.missingRelation,
      label: 'with no ${target.subject.label.toLowerCase()}',
      target: target.subject,
    ));
    terms.add(CommandTerm(
      kind: CommandTermKind.predicate,
      text: '${match.text} ${target.text}',
      label: 'with no ${target.subject.label.toLowerCase()}',
    ));
    index = target.end;
    return true;
  }

  bool _readStatusPredicate() {
    final kind = _statusWords[lower[index]];
    if (kind == null) return false;
    predicates.add(CommandPredicate(kind: kind, label: lower[index]));
    terms.add(CommandTerm(
      kind: CommandTermKind.predicate,
      text: words[index],
      label: lower[index],
    ));
    index += 1;
    return true;
  }

  bool _readRelation() {
    if (relation != null) return false;
    final match = _matchRelation(index);
    if (match == null) return false;
    relation = match.relation;
    terms.add(CommandTerm(
      kind: CommandTermKind.relation,
      text: match.text,
      label: match.relation.label,
    ));
    final rest = _collectAnchor(match.end);
    if (rest.isNotEmpty) {
      anchorPhrase = rest;
      terms.add(CommandTerm(
        kind: CommandTermKind.anchor,
        text: rest,
        label: rest,
      ));
    }
    return true;
  }

  bool _readSubject() {
    if (subject != null) return false;
    final match = _matchSubject(index);
    if (match == null) return false;
    subject = match.subject;
    terms.add(CommandTerm(
      kind: CommandTermKind.subject,
      text: match.text,
      label: match.subject.label,
    ));
    index = match.end;
    return true;
  }

  /// Consumes words from [start] until the next structural marker, and returns
  /// them as the author wrote them. This is how an entity name that the grammar
  /// has never heard of — "House Noxmere" — survives the parse intact.
  String _collectAnchor(int start) {
    var cursor = start;
    final collected = <String>[];
    while (cursor < words.length) {
      if (_articles.contains(lower[cursor]) && collected.isEmpty) {
        cursor += 1;
        continue;
      }
      if (_isMarker(cursor)) break;
      collected.add(words[cursor]);
      cursor += 1;
    }
    index = cursor;
    return collected.join(' ');
  }

  bool _isMarker(int at) =>
      _statusWords.containsKey(lower[at]) ||
      lower[at] == 'before' ||
      lower[at] == 'after' ||
      _matchPhrase(_missingMarkers, at, 4) != null ||
      _matchPhrase(_scopeMarkers, at, 3) != null ||
      _matchPhrase(_mapMarkers, at, 3) != null;

  CommandQuery _build() {
    if (ignored.isNotEmpty) {
      terms.add(CommandTerm(
        kind: CommandTermKind.ignored,
        text: ignored.join(' '),
        label: 'ignored',
      ));
    }
    final resolved = subject ?? CommandSubject.anything;
    // Leftover words with nowhere else to go are the author naming something.
    if (anchorPhrase == null && ignored.isNotEmpty) {
      anchorPhrase = ignored.join(' ');
      terms.removeLast();
      terms.add(CommandTerm(
        kind: CommandTermKind.anchor,
        text: anchorPhrase!,
        label: anchorPhrase!,
      ));
    }
    final recognisedNothing = !sawVerb &&
        subject == null &&
        relation == null &&
        predicates.isEmpty;
    if (recognisedNothing) return CommandQuery.freeText(raw);
    return CommandQuery(
      text: raw,
      verb: verb,
      subject: resolved,
      relation: relation,
      anchorPhrase: anchorPhrase,
      linkTargetPhrase: linkTargetPhrase,
      predicates: List.unmodifiable(predicates),
      terms: List.unmodifiable(terms),
    );
  }

  // ------------------------------------------------------------- matchers

  String _slice(int start, int end) => words.sublist(start, end).join(' ');

  _PhraseMatch? _matchPhrase(
    Map<String, Object?> table,
    int start,
    int maxWords,
  ) {
    final limit = start + maxWords > words.length ? words.length : start + maxWords;
    for (var end = limit; end > start; end -= 1) {
      final phrase = lower.sublist(start, end).join(' ');
      if (table.containsKey(phrase)) {
        return _PhraseMatch(phrase, _slice(start, end), end);
      }
    }
    return null;
  }

  _SubjectMatch? _matchSubject(int start) {
    if (start >= words.length) return null;
    final maxWords = vocabulary.longestSubjectPhrase;
    final limit = start + maxWords > words.length ? words.length : start + maxWords;
    for (var end = limit; end > start; end -= 1) {
      final phrase = lower.sublist(start, end).join(' ');
      final subject = vocabulary.subjectFor(phrase);
      if (subject != null) {
        return _SubjectMatch(subject, _slice(start, end), end);
      }
    }
    return null;
  }

  _RelationMatch? _matchRelation(int start) {
    final maxWords = vocabulary.longestRelationPhrase;
    final limit = start + maxWords > words.length ? words.length : start + maxWords;
    for (var end = limit; end > start; end -= 1) {
      final phrase = lower.sublist(start, end).join(' ');
      final relation = vocabulary.relationFor(phrase);
      if (relation != null) {
        return _RelationMatch(relation, _slice(start, end), end);
      }
    }
    return null;
  }
}

class _PhraseMatch {
  const _PhraseMatch(this.phrase, this.text, this.end);
  final String phrase;
  final String text;
  final int end;
}

class _SubjectMatch {
  const _SubjectMatch(this.subject, this.text, this.end);
  final CommandSubject subject;
  final String text;
  final int end;
}

class _RelationMatch {
  const _RelationMatch(this.relation, this.text, this.end);
  final CommandRelation relation;
  final String text;
  final int end;
}

// ------------------------------------------------------- closed word classes

/// Everyday words for a whole category of record.
///
/// Deliberately tiny, and deliberately pointing at categories rather than at
/// lists of types: a project that invents a new kind of plot record is covered
/// by these the moment it registers the type.
const _categoryAliases = <String, String>{
  'plot thread': 'plot',
  'story thread': 'plot',
  'storyline': 'plot',
  'world record': 'world',
};

const _verbs = <String, CommandVerb>{
  'show me': CommandVerb.show,
  'show all': CommandVerb.show,
  'show every': CommandVerb.show,
  'show': CommandVerb.show,
  'find': CommandVerb.show,
  'list': CommandVerb.show,
  'display': CommandVerb.show,
  'search for': CommandVerb.show,
  'search': CommandVerb.show,
  'go to': CommandVerb.show,
  'open': CommandVerb.show,
  'who is': CommandVerb.show,
  'what is': CommandVerb.show,
  'link': CommandVerb.link,
  'connect': CommandVerb.link,
  'create': CommandVerb.create,
  'add': CommandVerb.create,
  'new': CommandVerb.create,
};

const _quantifiers = <String>{
  'all',
  'every',
  'each',
  'any',
  'the',
  'me',
  'my',
  'some',
};

const _articles = <String>{'a', 'an', 'the'};

/// Words that carry no query meaning here. They are dropped silently rather
/// than reported as ignored, so the chip row stays about the author's intent.
const _fillers = <String>{
  'occurring',
  'occurs',
  'occur',
  'happening',
  'happens',
  'happened',
  'used',
  'that',
  'which',
  'is',
  'are',
  'was',
  'were',
  'been',
  'still',
  'yet',
};

/// Story-status adjectives. These mirror the values `plotStatus` already takes
/// (`planned`, `active`, `resolved`, `abandoned`) rather than inventing a
/// parallel vocabulary.
const _statusWords = <String, CommandPredicateKind>{
  'unresolved': CommandPredicateKind.unresolved,
  'unfinished': CommandPredicateKind.unresolved,
  'dangling': CommandPredicateKind.unresolved,
  'resolved': CommandPredicateKind.resolved,
  'completed': CommandPredicateKind.resolved,
  'active': CommandPredicateKind.active,
  'archived': CommandPredicateKind.archived,
  'canon': CommandPredicateKind.canon,
  'canonical': CommandPredicateKind.canon,
  'draft': CommandPredicateKind.draft,
};

const _missingMarkers = <String, bool>{
  'with no': true,
  'without': true,
  'with none': true,
  'lacking': true,
  'missing': true,
  'not yet assigned to': true,
  'not assigned to': true,
  'not yet linked to': true,
  'not linked to': true,
  'not connected to': true,
  'unassigned to': true,
};

const _scopeMarkers = <String, bool>{
  'in book': true,
  'in the book': true,
  'from book': true,
  'within book': true,
};

const _mapMarkers = <String, bool>{
  'on the map': true,
  'on a map': true,
  'on map': true,
  'on the maps': true,
};

String _verbLabel(CommandVerb verb) => switch (verb) {
      CommandVerb.show => 'Show',
      CommandVerb.link => 'Link',
      CommandVerb.create => 'Create',
    };

// ------------------------------------------------------------------ helpers

const _vowels = <String>{'a', 'e', 'i', 'o', 'u'};

List<String> _words(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    final isWord = RegExp(r'[A-Za-z0-9]').hasMatch(char) || char == "'";
    buffer.write(isWord ? char : ' ');
  }
  return buffer
      .toString()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
}

String _normalize(String phrase) => phrase
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .join(' ');

/// `plot-thread` and `appearsIn` both become spaced lower-case words.
String _humanize(String id) {
  final buffer = StringBuffer();
  for (var i = 0; i < id.length; i += 1) {
    final char = id[i];
    if (char == '-' || char == '_') {
      buffer.write(' ');
      continue;
    }
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i > 0) buffer.write(' ');
    buffer.write(char.toLowerCase());
  }
  return _normalize(buffer.toString());
}

String _titleCase(String value) => value
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

/// Every form of a category name.
///
/// Category ids are written however read best in a type definition — `plot`,
/// but `characters`. Both readings have to answer to both numbers.
List<String> _categoryPhrases(String phrase) {
  final normalized = _normalize(phrase);
  if (normalized.isEmpty) return const [];
  return <String>{
    ..._inflect(normalized),
    ..._inflect(_singularize(normalized)),
  }.toList();
}

String _singularize(String phrase) {
  final words = phrase.split(' ');
  final last = words.removeLast();
  words.add(_singularWord(last));
  return words.join(' ');
}

String _singularWord(String word) {
  if (word.endsWith('ies') && word.length > 3) {
    return '${word.substring(0, word.length - 3)}y';
  }
  for (final ending in const ['ses', 'xes', 'zes', 'ches', 'shes']) {
    if (word.endsWith(ending)) return word.substring(0, word.length - 2);
  }
  if (word.endsWith('s') && !word.endsWith('ss') && word.length > 1) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// Singular and plural, so number is never load-bearing in a command.
List<String> _inflect(String phrase) {
  final normalized = _normalize(phrase);
  if (normalized.isEmpty) return const [];
  return <String>{normalized, _pluralize(normalized)}.toList();
}

String _pluralize(String phrase) {
  final words = phrase.split(' ');
  final last = words.removeLast();
  words.add(_pluralWord(last));
  return words.join(' ');
}

String _pluralWord(String word) {
  if (word.isEmpty) return word;
  if (word.endsWith('y') &&
      word.length > 1 &&
      !_vowels.contains(word[word.length - 2])) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  if (word.endsWith('s') ||
      word.endsWith('x') ||
      word.endsWith('z') ||
      word.endsWith('ch') ||
      word.endsWith('sh')) {
    return '${word}es';
  }
  return '${word}s';
}

/// Every form of a relationship phrase an author might type.
///
/// A connection type reads as "appears in". Authors also write "appear in" and
/// "appearing in", and the difference is grammatical rather than semantic — so
/// the forms are generated from the head verb rather than listed by hand.
List<String> _verbForms(String phrase) {
  final normalized = _normalize(phrase);
  if (normalized.isEmpty) return const [];
  final forms = <String>{normalized};
  final words = normalized.split(' ');
  final head = words.first;
  final tail = words.skip(1).join(' ');
  String join(String verb) => tail.isEmpty ? verb : '$verb $tail';

  final stem = head.endsWith('s') && !head.endsWith('ss')
      ? head.substring(0, head.length - 1)
      : head;
  if (stem.length >= 3) {
    forms.add(join(stem));
    forms.add(join(_pluralWord(stem)));
    for (final gerund in _gerunds(stem)) {
      forms.add(join(gerund));
    }
  }
  return forms.toList();
}

List<String> _gerunds(String stem) {
  if (stem.endsWith('e') && !stem.endsWith('ee')) {
    return ['${stem.substring(0, stem.length - 1)}ing'];
  }
  final forms = <String>['${stem}ing'];
  // A short stem ending vowel-consonant doubles its consonant: occur ->
  // occurring. Longer stems do not: appear -> appearing.
  if (stem.length <= 5 && stem.length >= 3) {
    final last = stem[stem.length - 1];
    final previous = stem[stem.length - 2];
    if (!_vowels.contains(last) &&
        _vowels.contains(previous) &&
        !const {'w', 'x', 'y'}.contains(last)) {
      forms.add('$stem${last}ing');
    }
  }
  return forms;
}

int _longestPhrase(Iterable<String> phrases) {
  var longest = 1;
  for (final phrase in phrases) {
    final count = phrase.split(' ').length;
    if (count > longest) longest = count;
  }
  return longest;
}
