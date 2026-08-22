/// The Command System's query model.
///
/// This library is the boundary between the deterministic grammar that reads an
/// author's phrase and the service layer that answers it. It is intentionally
/// dependency-free beyond [search_models.dart]: it imports no Flutter, no
/// persistence and no Studio, so both halves can depend on it.
///
/// Nothing here executes a query. A [CommandQuery] is a description of what the
/// author asked for; running it belongs to `CommandService` in the service
/// layer, which composes the Studios' existing query surfaces.
library;

import 'search_models.dart';

/// What the author wants done.
enum CommandVerb {
  /// Find and list. The default, and the only read verb.
  show,

  /// Propose a new relationship between two existing entities.
  link,

  /// Propose a new record.
  create,
}

/// The role a run of words played in a parse.
///
/// Every recognised term becomes one chip in the console's "Understood as" row,
/// which is what makes a rule-based parser honest: the author can see which of
/// their words the system actually used, and which it ignored.
enum CommandTermKind { verb, subject, relation, anchor, predicate, scope, ignored }

class CommandTerm {
  const CommandTerm({
    required this.kind,
    required this.text,
    required this.label,
  });

  /// The role this run of words played.
  final CommandTermKind kind;

  /// The author's own words, as typed.
  final String text;

  /// How the system read them, in the author's language.
  final String label;

  @override
  String toString() => '${kind.name}:$text';
}

/// The kind of entity a query is about.
///
/// A subject is a *family*, not one type: "characters" covers every record type
/// that inherits `character`, and the grammar resolves that family from the live
/// [RecordTypeRegistry] rather than from a hardcoded list, so a project's own
/// custom types are queryable the moment they are defined.
///
/// Scenes and chapters are `ManuscriptNodeReference`s rather than records, so a
/// subject carries both sets and a query may span the two node kinds.
class CommandSubject {
  const CommandSubject({
    required this.label,
    this.recordTypeIds = const {},
    this.nodeTypes = const {},
    this.everything = false,
    this.reportId,
  });

  /// Matches any entity of any kind.
  static const anything = CommandSubject(label: 'Everything', everything: true);

  /// The canon-conflict report.
  ///
  /// A few questions an author asks are not "list entities of a type" but
  /// "run this analysis" — canon conflicts is the first. Rather than inventing
  /// a second verb, such a question parses to a subject that names a report,
  /// and the executor dispatches on [reportId].
  static const canonConflicts = CommandSubject(
    label: 'Canon conflicts',
    reportId: canonConflictsReportId,
  );

  static const canonConflictsReportId = 'canon-conflicts';

  /// How the subject is named back to the author.
  final String label;

  /// Record types in the family. Empty with [everything] means "any record".
  final Set<String> recordTypeIds;

  /// Manuscript node types in the family — `scene` and/or `chapter`.
  final Set<String> nodeTypes;

  /// Whether the subject deliberately matches everything.
  final bool everything;

  /// Set when the subject names an analysis rather than a type family.
  final String? reportId;

  bool get isReport => reportId != null;

  bool get includesRecords => everything || recordTypeIds.isNotEmpty;

  bool get includesNodes => everything || nodeTypes.isNotEmpty;

  bool matchesRecordType(String typeId) =>
      everything || recordTypeIds.contains(typeId);

  bool matchesNodeType(String nodeType) =>
      everything || nodeTypes.contains(nodeType);
}

/// A connection type the query cares about.
///
/// A null [typeId] means "any relationship", which is what the generic
/// connectives ("connected to", "linked to") parse to.
class CommandRelation {
  const CommandRelation({this.typeId, required this.label});

  static const any = CommandRelation(label: 'connected to');

  final String? typeId;
  final String label;

  bool get isAny => typeId == null;

  bool matches(String linkTypeId) => typeId == null || typeId == linkTypeId;
}

/// A narrowing condition applied after the subject is gathered.
enum CommandPredicateKind {
  /// Story status is anything other than resolved.
  unresolved,

  /// Story status is resolved.
  resolved,

  /// Story status is active.
  active,

  /// Canon status is canon.
  canon,

  /// Canon status is draft or proposed.
  draft,

  /// Lifecycle status is archived.
  archived,

  /// Has no relationship of the given shape — "with no location",
  /// "not yet assigned to a plot".
  missingRelation,

  /// Ordered before the anchor in the manuscript.
  before,

  /// Ordered after the anchor in the manuscript.
  after,

  /// Scoped to one book.
  inBook,

  /// Placed on a map.
  onMap,
}

class CommandPredicate {
  const CommandPredicate({
    required this.kind,
    required this.label,
    this.target,
    this.anchorPhrase,
  });

  final CommandPredicateKind kind;

  /// How the predicate is named back to the author.
  final String label;

  /// For [CommandPredicateKind.missingRelation], the family that must be absent.
  final CommandSubject? target;

  /// For [CommandPredicateKind.before], [CommandPredicateKind.after] and
  /// [CommandPredicateKind.inBook], the entity the predicate is relative to.
  final String? anchorPhrase;
}

/// One parsed command.
///
/// A query always carries [terms] so the console can show its reading back, and
/// always carries [text] so an unrecognised or partly recognised phrase can fall
/// through to plain full-text search rather than failing.
class CommandQuery {
  const CommandQuery({
    required this.text,
    this.verb = CommandVerb.show,
    this.subject = CommandSubject.anything,
    this.relation,
    this.anchorPhrase,
    this.linkTargetPhrase,
    this.predicates = const [],
    this.terms = const [],
    this.isFreeText = false,
  });

  /// A phrase the grammar could not read as a command.
  ///
  /// This is not an error state. The console runs it as a plain search, which is
  /// what the author most likely wanted, and shows no "Understood as" chips.
  factory CommandQuery.freeText(String text) => CommandQuery(
        text: text,
        isFreeText: true,
        terms: [
          CommandTerm(
            kind: CommandTermKind.ignored,
            text: text,
            label: 'searched as text',
          ),
        ],
      );

  /// The author's phrase, as typed.
  final String text;

  final CommandVerb verb;

  final CommandSubject subject;

  /// The relationship the query traverses, when it traverses one.
  final CommandRelation? relation;

  /// The name of the entity the query is anchored on — "Kali", "Chapter 20".
  final String? anchorPhrase;

  /// For [CommandVerb.link], the name of the second endpoint.
  final String? linkTargetPhrase;

  final List<CommandPredicate> predicates;

  final List<CommandTerm> terms;

  final bool isFreeText;

  bool get isAction => verb == CommandVerb.link || verb == CommandVerb.create;

  bool get hasAnchor => (anchorPhrase ?? '').trim().isNotEmpty;

  bool hasPredicate(CommandPredicateKind kind) =>
      predicates.any((predicate) => predicate.kind == kind);
}

// --------------------------------------------------------------------- results

/// Which store a result row came from.
///
/// Both kinds are first-class: the graph spans Universal Records and
/// manuscript-domain nodes, and a navigation layer that showed only one would be
/// lying about the story.
enum CommandRowKind { record, manuscriptNode, issue }

/// One answer, normalised across the two node kinds.
class CommandRow {
  const CommandRow({
    required this.id,
    required this.title,
    required this.kind,
    required this.typeLabel,
    this.subtitle = '',
    this.detail = '',
    this.navigationTarget,
  });

  final String id;
  final String title;
  final CommandRowKind kind;

  /// The record or node type, in the author's language.
  final String typeLabel;

  /// How this row relates to what was asked — a relationship label, a chapter
  /// name, a status.
  final String subtitle;

  /// Longer supporting text, used by issue rows to carry their message.
  final String detail;

  /// Where tapping this row goes. Null when the row is not navigable, as an
  /// issue with no single subject is not.
  final SearchNavigationTarget? navigationTarget;
}

/// Rows gathered under a heading — usually a record category.
class CommandGroup {
  const CommandGroup({required this.label, required this.rows});

  final String label;
  final List<CommandRow> rows;
}

/// A candidate the author must choose between before a query can run.
class CommandCandidate {
  const CommandCandidate({
    required this.id,
    required this.title,
    required this.typeLabel,
  });

  final String id;
  final String title;
  final String typeLabel;
}

/// One entity a command names, resolved to something real.
///
/// Carries [candidates] when the name matched more than one thing, so the
/// caller can ask rather than pick.
class CommandEntity {
  const CommandEntity({
    required this.id,
    required this.title,
    required this.typeId,
    required this.typeLabel,
    this.isManuscriptNode = false,
    this.candidates = const [],
  });

  final String id;
  final String title;

  /// The record type, or the manuscript node type for a scene or chapter.
  final String typeId;

  final String typeLabel;

  final bool isManuscriptNode;

  final List<CommandCandidate> candidates;

  bool get isAmbiguous => candidates.isNotEmpty;
}

/// The answer to one command.
class CommandResult {
  const CommandResult({
    required this.query,
    this.groups = const [],
    this.message = '',
    this.candidates = const [],
    this.candidatePrompt = '',
  });

  final CommandQuery query;

  final List<CommandGroup> groups;

  /// Shown when there is nothing to list — an empty result, or a refusal.
  final String message;

  /// When set, the query did not run: the author must pick an anchor first.
  final List<CommandCandidate> candidates;

  /// What the author is being asked to choose.
  final String candidatePrompt;

  List<CommandTerm> get terms => query.terms;

  bool get needsDisambiguation => candidates.isNotEmpty;

  int get rowCount =>
      groups.fold(0, (total, group) => total + group.rows.length);

  bool get isEmpty => rowCount == 0;
}
