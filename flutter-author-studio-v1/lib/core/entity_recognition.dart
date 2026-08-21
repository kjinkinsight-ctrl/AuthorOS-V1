import 'connected_domain.dart';

/// How AuthorOS recognises an entity named in prose.
///
/// Three Studios were doing this separately — Manuscript, Codex and World each
/// carried a byte-identical private `_mentions`, its own name splitter, and its
/// own idea of what counts as an alias. One matcher means one answer: a name
/// that resolves in the manuscript resolves the same way in the Codex.
///
/// Deliberately not clever. Exact, case-insensitive, word-boundary matching
/// against titles and aliases the author wrote down — no fuzzy matching, no
/// stemming, no scoring, no inference. A name AuthorOS cannot resolve exactly
/// is reported as unconfirmed for the author to judge, never guessed at.
class EntityNames {
  const EntityNames._();

  /// Every field an entity's alternate names can live in.
  ///
  /// The union of what the three Studios read individually: the Codex writes
  /// `aliases`, World Studio also writes `alternateNames`, `historicalNames`,
  /// `localNames` and `nicknames`. Reading all of them means a location's
  /// historical name is recognised in the manuscript, which it was not before.
  static const aliasFieldIds = <String>[
    'aliases',
    'alternateNames',
    'historicalNames',
    'localNames',
    'nicknames',
  ];

  /// Splits a stored name value into individual names.
  ///
  /// Accepts a list, or a single string separated by commas, semicolons or
  /// newlines — the three shapes authors actually type into these fields.
  static List<String> split(Object? value) {
    if (value is String) {
      return value
          .split(RegExp(r'[,;\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Every alternate name recorded for [record].
  static List<String> aliasesOf(
    AuthorRecord record, {
    List<String> fieldIds = aliasFieldIds,
  }) {
    final seen = <String>{};
    final aliases = <String>[];
    for (final fieldId in fieldIds) {
      for (final alias in split(record.fields[fieldId])) {
        if (seen.add(alias.toLowerCase())) aliases.add(alias);
      }
    }
    return aliases;
  }

  /// [record]'s title followed by its aliases.
  static List<String> namesOf(
    AuthorRecord record, {
    List<String> fieldIds = aliasFieldIds,
  }) =>
      <String>[
        record.title.trim(),
        ...aliasesOf(record, fieldIds: fieldIds),
      ].where((name) => name.isNotEmpty).toList();

  /// Every title and alias in a project, for missing-record checks.
  ///
  /// A name owned by another Studio counts as known, so the Codex never
  /// reports a character World Studio already has.
  static Set<String> knownNames(Iterable<AuthorRecord> records) => <String>{
        for (final record in records) ...namesOf(record),
      }..remove('');
}

/// Matches a written name inside prose.
///
/// Case-insensitive and bounded by non-alphanumerics, so "Kali" matches
/// `Kali entered` and `"Kali,"` but not `Kalinda`.
class EntityNameMatcher {
  const EntityNameMatcher({this.minimumLength = 4});

  /// Names shorter than this are ignored so common words produce no noise.
  ///
  /// It is a blunt rule and it will miss a genuinely short name. That is the
  /// deliberate trade: a recognition engine that cries wolf gets switched off.
  final int minimumLength;

  bool isLongEnough(String name) => name.trim().length >= minimumLength;

  /// Whether [name] appears in [prose] as a whole word.
  bool mentions(String prose, String name) {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return false;
    final escaped = RegExp.escape(needle);
    return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)')
        .hasMatch(prose.toLowerCase());
  }

  /// Where [name] appears in [prose], as character ranges.
  List<({int start, int end})> spans(String prose, String name) {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final escaped = RegExp.escape(needle);
    final pattern = RegExp('(^|[^a-z0-9])($escaped)([^a-z0-9]|\$)');
    final haystack = prose.toLowerCase();
    final found = <({int start, int end})>[];
    var offset = 0;
    while (offset <= haystack.length) {
      final match = pattern.firstMatch(haystack.substring(offset));
      if (match == null) break;
      final start = offset + match.start + (match.group(1)?.length ?? 0);
      found.add((start: start, end: start + needle.length));
      // Resume one character past this name, not past the whole match, so two
      // mentions separated by a single space are both found.
      offset = start + needle.length;
    }
    return found;
  }
}

/// One entity named in a stretch of prose.
class EntityMention {
  const EntityMention({
    required this.entityIds,
    required this.matchedName,
    required this.canonicalTitle,
    required this.isAlias,
    required this.start,
    required this.end,
  });

  /// Every entity this name could mean. More than one means the name is
  /// ambiguous and the author has to decide.
  final List<String> entityIds;

  /// The name as it was written, matched case-insensitively.
  final String matchedName;

  /// The title of the first candidate, for display.
  final String canonicalTitle;

  /// Whether the match was on an alias rather than the entity's title.
  final bool isAlias;

  final int start;
  final int end;

  bool get isAmbiguous => entityIds.length > 1;
  String? get entityId => entityIds.length == 1 ? entityIds.single : null;
}

/// Every name in a project, indexed for recognition.
///
/// Built once per scan rather than per scene, because the expensive part is
/// walking the records, not matching the prose.
class EntityNameIndex {
  EntityNameIndex._({
    required this.matcher,
    required Map<String, List<String>> idsByName,
    required Map<String, String> titlesById,
    required Set<String> aliasNames,
  })  : _idsByName = idsByName,
        _titlesById = titlesById,
        _aliasNames = aliasNames;

  factory EntityNameIndex.fromRecords(
    Iterable<AuthorRecord> records, {
    int minimumLength = 4,
    List<String> aliasFieldIds = EntityNames.aliasFieldIds,
  }) {
    final idsByName = <String, List<String>>{};
    final titlesById = <String, String>{};
    final aliasNames = <String>{};
    for (final record in records) {
      if (record.status == AuthorRecordStatus.deleted) continue;
      titlesById[record.id] = record.title;
      final title = record.title.trim().toLowerCase();
      if (title.isNotEmpty) {
        (idsByName[title] ??= <String>[]).add(record.id);
      }
      for (final alias
          in EntityNames.aliasesOf(record, fieldIds: aliasFieldIds)) {
        final key = alias.toLowerCase();
        if (key.isEmpty) continue;
        aliasNames.add(key);
        final ids = idsByName[key] ??= <String>[];
        if (!ids.contains(record.id)) ids.add(record.id);
      }
    }
    return EntityNameIndex._(
      matcher: EntityNameMatcher(minimumLength: minimumLength),
      idsByName: idsByName,
      titlesById: titlesById,
      aliasNames: aliasNames,
    );
  }

  final EntityNameMatcher matcher;
  final Map<String, List<String>> _idsByName;
  final Map<String, String> _titlesById;
  final Set<String> _aliasNames;

  /// Every name in the index, longest first.
  ///
  /// Longest first so "House Noxmere" is recognised before "Noxmere" and the
  /// more specific entity wins.
  List<String> get names {
    final all = _idsByName.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return all;
  }

  /// Every title and alias, as written.
  Set<String> get knownNames => <String>{
        for (final title in _titlesById.values) title.trim(),
        ..._aliasNames,
      }..remove('');

  /// The entities [name] could refer to.
  List<String> idsFor(String name) =>
      _idsByName[name.trim().toLowerCase()] ?? const [];

  String? titleOf(String id) => _titlesById[id];

  bool isKnown(String name) => idsFor(name).isNotEmpty;

  /// Every entity named in [prose].
  ///
  /// Overlapping matches are dropped, longest name first, so a mention of
  /// "House Noxmere" does not also report "Noxmere".
  List<EntityMention> scan(String prose, {int? limit}) {
    if (prose.trim().isEmpty) return const [];
    final claimed = <int>{};
    final mentions = <EntityMention>[];
    for (final name in names) {
      if (limit != null && mentions.length >= limit) break;
      if (!matcher.isLongEnough(name)) continue;
      for (final span in matcher.spans(prose, name)) {
        if (limit != null && mentions.length >= limit) break;
        final overlaps = List.generate(
          span.end - span.start,
          (offset) => span.start + offset,
        ).any(claimed.contains);
        if (overlaps) continue;
        claimed.addAll(
          List.generate(span.end - span.start, (o) => span.start + o),
        );
        final ids = idsFor(name);
        mentions.add(EntityMention(
          entityIds: ids,
          matchedName: prose.substring(span.start, span.end),
          canonicalTitle: ids.isEmpty ? name : (titleOf(ids.first) ?? name),
          isAlias: _aliasNames.contains(name),
          start: span.start,
          end: span.end,
        ));
      }
    }
    mentions.sort((a, b) => a.start.compareTo(b.start));
    return mentions;
  }
}
