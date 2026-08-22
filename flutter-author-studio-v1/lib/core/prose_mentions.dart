/// Word-boundary matching of a record's name against manuscript prose.
///
/// Three continuity engines — manuscript, world and codex — each carried an
/// identical private copy of this rule. One copy means the Manuscript
/// workspace, World Studio, the Story Codex and the Intelligence Layer all
/// agree on what "the prose names this record" means, and a fix to the rule
/// reaches all four.
///
/// The boundary check is the point. A plain substring match reports the
/// character "Will" for every occurrence of the auxiliary verb, and "Rose" for
/// the flower — the failure recorded as risk R-20 against
/// `AnalyticsService._countCharactersReferenced`. Requiring a non-alphanumeric
/// character (or a string edge) on both sides removes that whole class of
/// false positive. It does not remove all of them: a character genuinely
/// called "Will" still matches the verb, which is why callers also impose a
/// minimum name length.
library;

/// Whether [prose] names [name] at a word boundary.
///
/// [prose] is expected to be lowercase already; [name] is lowercased here.
/// Both are compared without normalising punctuation, so an apostrophe or a
/// hyphen inside a name is matched literally.
bool proseMentions(String prose, String name) {
  final escaped = RegExp.escape(name.toLowerCase());
  return RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)').hasMatch(prose);
}
