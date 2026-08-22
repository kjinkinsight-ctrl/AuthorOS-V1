/// Map Studio Phase 6 — the presentation read layer.
///
/// Read-only by construction, like the Phase 4 and Phase 5 services before it:
/// no create, update or delete method, no write path, no store of its own. It
/// gathers two things a presentation needs and neither of which it owns:
///
/// 1. **Reveal points** — from `revealedIn` links to manuscript nodes, ordered
///    by the manuscript's own chapter and scene ordering.
/// 2. **Export metadata** — the project, the book, the author, the map's own
///    revision, each read from whichever layer already owns it.
///
/// Where a canonical source does not exist, the gap is reported through
/// [MapPresentationGap] and the element is omitted. Nothing here invents a
/// value to make an export look complete.
library;

import 'author_profile_store.dart';
import 'core/connected_domain.dart';
import 'map_domain.dart';
import 'map_presentation.dart';
import 'map_reader.dart';
import 'persistence/authoros_database.dart';

export 'map_presentation.dart';
export 'map_reader.dart';

/// The links and node types the presentation layer reads.
class MapPresentationLinks {
  const MapPresentationLinks._();

  /// Where something becomes known to the reader. Canonical, and read-only.
  static const revealedIn = 'revealedIn';

  /// Manuscript node types a reveal may point at.
  static const revealTargets = {'chapter', 'scene', 'book'};
}

class MapPresentationService {
  const MapPresentationService({
    required this.projectId,
    required this.repository,
    this.profiles = const AuthorProfileStore(),
  });

  final String projectId;
  final DriftConnectedDomainRepository repository;
  final AuthorProfileStore profiles;

  /// Every reveal point on this project, by the id of the thing revealed.
  ///
  /// Walks `revealedIn` links from the manuscript inwards: a reveal is a claim
  /// the manuscript makes about a record, so the manuscript nodes are the
  /// authority on when it happens. Where a record is revealed more than once,
  /// the earliest reveal wins — a thing is known from the first time the reader
  /// meets it.
  Future<Map<String, MapRevealPoint>> revealPoints() async {
    final nodes = await _manuscriptNodes();
    final points = <String, MapRevealPoint>{};
    for (final node in nodes.values) {
      for (final link in await repository.backlinks(node.id)) {
        if (link.scopeId != projectId) continue;
        if (link.typeId != MapPresentationLinks.revealedIn) continue;
        final revealed =
            link.sourceId == node.id ? link.targetId : link.sourceId;
        if (revealed == node.id) continue;
        final point = _pointFor(node, nodes);
        final existing = points[revealed];
        if (existing == null || point.compareTo(existing) < 0) {
          points[revealed] = point;
        }
      }
    }
    return points;
  }

  /// The reveal points an author can stand at, in reading order.
  ///
  /// These are the spoiler levels the Studio offers: "through chapter 3" means
  /// the chapter the manuscript calls the third one.
  Future<List<MapSpoilerLevel>> spoilerLevels() async {
    final nodes = await _manuscriptNodes();
    final chapters = [
      for (final node in nodes.values)
        if (node.nodeType == 'chapter') _pointFor(node, nodes),
    ]..sort();
    return [
      MapSpoilerLevel.public,
      for (final point in chapters) MapSpoilerLevel.through(point),
      MapSpoilerLevel.everything,
    ];
  }

  /// The manuscript nodes an author may choose as a reveal point, in reading
  /// order.
  ///
  /// The choosing is the Studio's; the writing is `MapService.addRevealPoint`'s.
  /// This service stays read-only, as it has been since Phase 6 landed — it
  /// offers the list and never acts on it.
  Future<List<MapRevealPoint>> revealTargets() async {
    final nodes = await _manuscriptNodes();
    return [for (final node in nodes.values) _pointFor(node, nodes)]..sort();
  }

  /// Everything an export may print about itself (§35).
  ///
  /// Each field names its own source, and anything the canonical model does not
  /// carry is returned as a gap rather than a blank that looks deliberate.
  Future<MapPresentationMetadata> metadataFor(
    MapSummary map, {
    required String projectTitle,
    String eraLabel = '',
  }) async {
    final gaps = <MapPresentationGap>[];

    // The roster is ordered most recently active first, so the first profile
    // is the author currently writing. The pen name wins where there is one:
    // it is the name that belongs on a published map.
    final roster = await profiles.loadProfiles();
    final profile = roster.isEmpty ? null : roster.first;
    final authorName = profile == null
        ? ''
        : (profile.penName.trim().isEmpty
            ? profile.displayName.trim()
            : profile.penName.trim());
    if (authorName.isEmpty) {
      gaps.add(
        const MapPresentationGap(
          element: 'Author credit',
          missingSource: 'no author profile has a name or pen name set',
        ),
      );
    }

    final nodes = await _manuscriptNodes();
    final book = nodes.values.where((node) => node.nodeType == 'book').toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final bookTitle = book.isEmpty ? '' : book.first.title;
    if (bookTitle.isEmpty) {
      gaps.add(
        const MapPresentationGap(
          element: 'Book title',
          missingSource: 'this project has no manuscript root node',
        ),
      );
    }

    // A series is a declared record type that nothing in AuthorOS creates, so a
    // project cannot yet state which series it belongs to. Reported once here
    // rather than guessed from the project title.
    final series = await _seriesTitle();
    if (series.isEmpty) {
      gaps.add(
        const MapPresentationGap(
          element: 'Series title',
          missingSource:
              "'series' is a declared record type that no Studio creates, so "
              'no project can name its series yet',
        ),
      );
    }

    return MapPresentationMetadata(
      projectTitle: projectTitle,
      mapTitle: map.title,
      seriesTitle: series,
      bookTitle: bookTitle,
      authorName: authorName,
      eraLabel: eraLabel,
      revision: map.record.revision,
      createdAt: map.record.updatedAt,
      gaps: gaps,
    );
  }

  /// The scale bar this map can honestly draw.
  MapScaleBar scaleBarFor(MapSummary map) => MapScaleBar.forExtent(
        MapExtent.fromRecord(map.record).width,
        coordinateSystem: _string(map.record.fields[MapFields.coordinateSystem]),
      );

  Future<String> _seriesTitle() async {
    final records = await repository.recordsByProject(projectId);
    final series = [
      for (final record in records)
        if (record.typeId == 'series' &&
            record.status == AuthorRecordStatus.active)
          record,
    ]..sort((a, b) => a.id.compareTo(b.id));
    return series.isEmpty ? '' : series.first.title;
  }

  Future<Map<String, ManuscriptNodeReference>> _manuscriptNodes() async {
    final nodes = await repository.manuscriptNodesForProject(projectId);
    return {
      for (final node in nodes)
        if (MapPresentationLinks.revealTargets.contains(node.nodeType))
          node.id: node,
    };
  }

  /// Turns a manuscript node into an ordered reveal point.
  ///
  /// Chapter order comes from the node's own `order`; a scene borrows its
  /// chapter's order and keeps its own within it, so scene 2 of chapter 3 sorts
  /// after scene 1 of chapter 3 and before anything in chapter 4. A book node
  /// sorts last, because "revealed somewhere in the book" says nothing narrower.
  MapRevealPoint _pointFor(
    ManuscriptNodeReference node,
    Map<String, ManuscriptNodeReference> nodes,
  ) {
    final order = _int(node.extensionData['order']) ?? 0;
    if (node.nodeType == 'scene') {
      final chapterId = _string(node.extensionData['chapterId']);
      final chapter = nodes[chapterId];
      final chapterOrder =
          chapter == null ? 0 : (_int(chapter.extensionData['order']) ?? 0);
      return MapRevealPoint(
        nodeId: node.id,
        nodeType: node.nodeType,
        label: node.title,
        chapterOrder: chapterOrder,
        sceneOrder: order,
      );
    }
    if (node.nodeType == 'book') {
      return MapRevealPoint(
        nodeId: node.id,
        nodeType: node.nodeType,
        label: node.title,
        chapterOrder: 1 << 20,
      );
    }
    return MapRevealPoint(
      nodeId: node.id,
      nodeType: node.nodeType,
      label: node.title,
      chapterOrder: order,
    );
  }

  static String _string(Object? value) => value is String ? value.trim() : '';

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
