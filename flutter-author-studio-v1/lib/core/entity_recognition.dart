/// Deterministic entity recognition: finding an author's names in an author's
/// prose.
///
/// This is the one place in the application that decides what counts as a
/// mention. Before this file existed the same predicate was written three
/// times — in `manuscript_continuity.dart`, `codex_continuity.dart` and
/// `world_continuity.dart` — and three copies of a matching rule are three
/// chances for the Manuscript, the Codex and the World to disagree about
/// whether a character appears in a scene.
///
/// Nothing here is generative and nothing reaches the network. Recognition is
/// author-authored names matched against author-written prose, which is what
/// makes the result reproducible and explainable — the differentiator
/// `NEXT.md` §9 sells and the determinism the master plan §12 requires.
library;

import 'connected_domain.dart';

/// The shortest name worth matching.
///
/// Shorter names are common words far more often than they are entities, and a
/// false positive costs the author more attention than a missed short name.
const int kMinimumMentionLength = 4;

/// Whether [name] appears in [prose] as a whole word.
///
/// [prose] must already be lowercase; callers build one lowercased blob per
/// subject and match many names against it, so lowering here would repeat the
/// work once per name.
///
/// Boundaries are `[^a-z0-9]` rather than `\b`, which is deliberate: it makes
/// possessives and punctuation count as boundaries, so "Kali's blade" and
/// "Kali," both match "Kali", while "Kalina" does not.
bool mentionsName(String prose, String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  final escaped = RegExp.escape(normalized);
  return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)').hasMatch(prose);
}

/// The first of [names] that appears in [prose], or null.
///
/// Returning the matched name rather than a boolean is what lets a
/// recommendation quote the author's own word back at them.
String? firstMention(
  String prose,
  Iterable<String> names, {
  int minimumLength = kMinimumMentionLength,
}) {
  for (final name in names) {
    final trimmed = name.trim();
    if (trimmed.length < minimumLength) continue;
    if (mentionsName(prose, trimmed)) return trimmed;
  }
  return null;
}

/// Splits a delimited roster value into names.
///
/// Accepts the two shapes templates actually store: a delimited string, or a
/// list.
List<String> splitNames(Object? value) {
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

/// The alternative names a record answers to.
///
/// Reads every alias field any Studio writes, so a name recognised in the
/// World is recognised identically in the Codex and the Manuscript.
List<String> aliasesOfRecord(AuthorRecord record) => <String>{
      for (final key in const [
        'aliases',
        'alternateNames',
        'historicalNames',
        'localNames',
        'nicknames',
        'identity.aliases',
      ])
        ...splitNames(record.fields[key]),
    }.toList();
