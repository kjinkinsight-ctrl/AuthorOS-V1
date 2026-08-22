/// Sweeps a project for deterministic recommendations and remembers which ones
/// the author has already said no to.
///
/// This service owns no intelligence. It gathers inputs, hands them to the
/// analyzers that already exist, and returns their findings as one ranked list.
/// Accepting a suggestion goes back through `ContinuityActionService`, the same
/// path the per-entry Continuity tab has always used.
library;

import 'codex_continuity.dart';
import 'core/codex_intelligence.dart';
import 'core/connected_domain.dart';
import 'core/entity_recognition.dart';
import 'core/story_codex_domain.dart';
import 'manuscript_continuity.dart';
import 'manuscript_store.dart';
import 'persistence/authoros_database.dart';
import 'story_codex_service.dart';

/// The record type that stores dismissals.
///
/// Codex bookkeeping, like categories, tags and collections — not an entry, and
/// excluded from every entry list by [CodexInfrastructureTypes].
const String kCodexSuggestionStateType = 'codexSuggestionState';

const String _suggestionStateRecordId = 'codex-suggestion-state';
const String _dismissedField = 'dismissedIds';

/// A sweep's result: what to show, and how much was looked at to find it.
class CodexSuggestionSweep {
  const CodexSuggestionSweep({
    required this.suggestions,
    required this.entriesScanned,
    required this.scenesScanned,
    required this.dismissedCount,
    this.proseUnavailable = false,
  });

  static const empty = CodexSuggestionSweep(
    suggestions: [],
    entriesScanned: 0,
    scenesScanned: 0,
    dismissedCount: 0,
  );

  final List<CodexSuggestion> suggestions;
  final int entriesScanned;
  final int scenesScanned;

  /// How many recommendations were suppressed because the author dismissed
  /// them. Shown so a quiet inbox is never mistaken for an empty one.
  final int dismissedCount;

  /// Whether the manuscript could not be read at all.
  ///
  /// Reported rather than folded into a scene count of zero: "I read no scenes"
  /// and "I could not read your book" are different answers, and only one of
  /// them means there is nothing to find.
  final bool proseUnavailable;

  bool get isEmpty => suggestions.isEmpty;
}

/// Gathers recommendations across a whole project.
class CodexSuggestionService {
  CodexSuggestionService({
    required this.codex,
    ManuscriptStore? manuscripts,
    this.builder = const CodexSuggestionBuilder(),
    this.entryIntelligence = const CodexContinuityIntelligence(),
    this.sceneIntelligence = const ManuscriptContinuityIntelligence(),
    this.discovery = const CoOccurrenceDiscovery(),
    this.maxEntriesScanned = 200,
    this.maxScenesScanned = 400,
  }) : manuscripts = manuscripts ?? ManuscriptStore(repository: codex.repository);

  final StoryCodexService codex;
  final ManuscriptStore manuscripts;
  final CodexSuggestionBuilder builder;
  final CodexContinuityIntelligence entryIntelligence;
  final ManuscriptContinuityIntelligence sceneIntelligence;
  final CoOccurrenceDiscovery discovery;

  /// Caps, so a large project produces a usable inbox rather than a hang.
  ///
  /// A sweep that stops early says so through [CodexSuggestionSweep], because
  /// silently truncating reads as "nothing more to find".
  final int maxEntriesScanned;
  final int maxScenesScanned;

  String get projectId => codex.projectId;

  DriftConnectedDomainRepository get repository => codex.repository;

  /// Every recommendation this project has, ranked, minus the dismissed ones.
  Future<CodexSuggestionSweep> sweep({DateTime? timestamp}) async {
    var proseUnavailable = false;
    final entries = await codex.getEntries();
    final records = await codex.connectableRecords();
    final titles = {for (final record in records) record.id: record.title};
    final knownNames = CodexContinuityIntelligence.knownNames(records);
    final dismissed = await dismissedIds();

    final gathered = <CodexSuggestion>[];

    // 1. Codex entries: names mentioned in an entry's own prose, and roster
    //    fields naming records that do not exist.
    final scannedEntries = entries.take(maxEntriesScanned).toList();
    for (final entry in scannedEntries) {
      final links = await codex.getCodexConnections(entry.id);
      final report = entryIntelligence.analyze(
        entry: entry,
        entries: entries,
        links: links,
        knownNames: knownNames,
      );
      if (report.isClean) continue;
      gathered.addAll(builder.fromCodexReport(
        entry: entry,
        report: report,
        titles: titles,
      ));
    }

    // 2. Manuscript prose: the same recognition, over the book itself.
    late final List<_SceneInChapter> scenes;
    try {
      scenes = await _scenes();
    } catch (_) {
      // Prose lives in shared preferences, which a host may not provide. The
      // Codex still has plenty to say about its own entries, so a sweep
      // continues without the manuscript rather than failing outright.
      proseUnavailable = true;
      scenes = const [];
    }
    final scanned = scenes.take(maxScenesScanned).toList();
    final known = ManuscriptContinuityIntelligence.knownRecords(records);
    for (final scene in scanned) {
      final report = sceneIntelligence.analyzeScene(
        scene: scene.scene,
        chapter: scene.chapter,
        records: known,
        connectedIds: await _connectedIds(scene.scene.id),
        knownNames: knownNames,
      );
      if (report.isClean) continue;
      gathered.addAll(builder.fromManuscriptReport(
        sceneTitle: scene.scene.title,
        report: report,
        titles: titles,
      ));
    }

    // 3. Relationship discovery: records that keep appearing together.
    final mentions = builder.mentionsIn(
      scenes: [
        for (final scene in scanned)
          SceneProse(
            id: scene.scene.id,
            title: scene.scene.title,
            prose: [
              scene.scene.title,
              scene.scene.content,
              scene.scene.notes,
            ].join('\n'),
          ),
      ],
      records: known,
    );
    gathered.addAll(builder.fromDerivedEdges(
      edges: discovery.discover(
        scenes: mentions,
        linkedPairs: await _linkedPairs(),
      ),
      titles: titles,
    ));

    final ranked = builder.rank(gathered);
    final visible =
        ranked.where((suggestion) => !dismissed.contains(suggestion.id)).toList();
    return CodexSuggestionSweep(
      suggestions: visible,
      entriesScanned: scannedEntries.length,
      scenesScanned: scanned.length,
      dismissedCount: ranked.length - visible.length,
      proseUnavailable: proseUnavailable,
    );
  }

  // ------------------------------------------------------------- dismissals

  /// The recommendations the author has said no to.
  Future<Set<String>> dismissedIds() async {
    final record = await repository.recordById(_recordId);
    if (record == null) return const {};
    return splitNames(record.fields[_dismissedField]).toSet();
  }

  Future<void> dismiss(String suggestionId, {DateTime? timestamp}) async {
    final current = await dismissedIds();
    if (current.contains(suggestionId)) return;
    await _writeDismissed({...current, suggestionId}, timestamp: timestamp);
  }

  /// Brings every dismissed recommendation back.
  Future<void> restoreDismissed({DateTime? timestamp}) =>
      _writeDismissed(const {}, timestamp: timestamp);

  String get _recordId => '$_suggestionStateRecordId-$projectId';

  Future<void> _writeDismissed(
    Set<String> ids, {
    DateTime? timestamp,
  }) async {
    final now = (timestamp ?? DateTime.now()).toUtc();
    final existing = await repository.recordById(_recordId);
    await repository.putRecord(AuthorRecord(
      id: _recordId,
      typeId: kCodexSuggestionStateType,
      scopeType: RecordScopeType.project,
      scopeId: projectId,
      projectId: projectId,
      title: 'Dismissed suggestions',
      revision: (existing?.revision ?? 0) + 1,
      fields: {_dismissedField: ids.toList()..sort()},
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    ));
  }

  // ------------------------------------------------------------------ input

  Future<Set<String>> _connectedIds(String nodeId) async {
    final links = await repository.backlinks(nodeId);
    return {
      for (final link in links)
        link.sourceId == nodeId ? link.targetId : link.sourceId,
    };
  }

  /// Every already-connected pair, keyed the way discovery keys them.
  Future<Set<String>> _linkedPairs() async {
    final links = await repository.linksByScope(projectId);
    return {
      for (final link in links)
        CoOccurrenceDiscovery.pairKey(link.sourceId, link.targetId),
    };
  }

  /// The project's scenes, or none when it has no manuscript yet.
  ///
  /// Reads through [ManuscriptStore.peekStudio], which never writes. Asking for
  /// prose must not be what causes a manuscript to exist.
  Future<List<_SceneInChapter>> _scenes() async {
    final manuscript = await manuscripts.peekStudio(projectId);
    if (manuscript == null) return const [];
    return [
      for (final chapter in manuscript.chapters)
        for (final scene in chapter.scenes)
          _SceneInChapter(scene: scene, chapter: chapter),
    ];
  }
}

class _SceneInChapter {
  const _SceneInChapter({required this.scene, required this.chapter});

  final ManuscriptScene scene;
  final ManuscriptChapter chapter;
}
