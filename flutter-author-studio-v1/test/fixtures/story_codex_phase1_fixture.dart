import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/story_codex_service.dart';

class StoryCodexPhase1Fixture {
  StoryCodexPhase1Fixture._({
    required this.codex,
    required this.ids,
    required this.links,
  });

  static const projectId = 'codex-phase-1-project';
  static const seriesId = 'codex-series';
  static const bookId = 'codex-book';
  static final timestamp = DateTime.utc(2026, 8, 20, 14);

  final StoryCodexService codex;
  final Map<String, String> ids;
  final Map<String, RecordLink> links;

  static Future<StoryCodexPhase1Fixture> build(
    DriftConnectedDomainRepository repository,
  ) async {
    final codex = StoryCodexService(
      projectId: projectId,
      repository: repository,
    );
    final ids = <String, String>{};

    Future<void> entry(
      String key,
      String type,
      String title,
      String category, {
      Map<String, Object?> fields = const {},
      List<String> tags = const [],
      String? entryBookId,
    }) async {
      final id = 'codex-$key';
      ids[key] = id;
      await codex.createEntry(
        CodexEntryDraft(
          id: id,
          title: title,
          templateId: type,
          categoryId: category,
          summary: '$title fixture record',
          structuredFields: {
            if (type == 'character') 'identity.fullName': title,
            ...fields,
          },
          tagIds: tags,
          seriesId: seriesId,
          bookId: entryBookId,
          canonStatus: CodexCanonStatus.canon,
        ),
        timestamp: timestamp.add(Duration(seconds: ids.length)),
      );
    }

    await entry('world', 'world', 'Avelune', 'world');
    await entry('region', 'region', 'The Ember Reach', 'locations');
    await entry('country', 'country', 'Veyra', 'locations');
    await entry('city', 'city', 'Lumenfall', 'locations');
    await entry('district', 'district', 'Glass Ward', 'locations');
    await entry('faction-a', 'faction', 'The Lantern Court', 'factions');
    await entry('faction-b', 'faction', 'The Ash Compact', 'factions');
    await entry('leader', 'character', 'Mara Venn', 'characters');
    await entry('member', 'character', 'Ilyan Ro', 'characters');
    await entry('enemy', 'character', 'Sevrin Ash', 'characters');
    await entry('civilian', 'character', 'Toma Reed', 'characters');
    await entry('religion', 'religion', 'The Seven Lights', 'religion');
    await entry('magic', 'magic-system', 'Resonance', 'magic');
    await entry('culture', 'culture', 'Veyran', 'culture');
    await entry('event-1', 'historical-event', 'The First Lighting', 'history');
    await entry('event-2', 'historical-event', 'The Glass War', 'history');
    await entry('event-3', 'historical-event', 'The Ember Treaty', 'history');
    await entry('item-1', 'item', 'The Dawn Key', 'items');
    await entry('item-2', 'artefact', 'Ash Crown', 'items');
    await entry('book', 'book', 'A City of Seven Lights', 'manuscript',
        entryBookId: bookId);
    await entry('chapter-1', 'chapter', 'Chapter One', 'manuscript',
        entryBookId: bookId);
    await entry('chapter-2', 'chapter', 'Chapter Two', 'manuscript',
        entryBookId: bookId);
    await entry('scene-1', 'scene', 'The Unlit Gate', 'manuscript',
        entryBookId: bookId);
    await entry('scene-2', 'scene', 'Court of Lanterns', 'manuscript',
        entryBookId: bookId);
    await entry('scene-3', 'scene', 'Treaty in Ash', 'manuscript',
        entryBookId: bookId);

    final links = <String, RecordLink>{};
    Future<void> connect(
      String key,
      String source,
      String target,
      String type, {
      Map<String, Object?> metadata = const {},
      RecordLinkDirection direction = RecordLinkDirection.directed,
    }) async {
      links[key] = await codex.connections.connect(
        sourceId: ids[source]!,
        targetId: ids[target]!,
        typeId: type,
        metadata: metadata,
        direction: direction,
        timestamp: timestamp.add(Duration(minutes: links.length + 1)),
      );
    }

    await connect('region-world', 'region', 'world', 'belongsTo');
    await connect('country-region', 'country', 'region', 'belongsTo');
    await connect('city-country', 'city', 'country', 'belongsTo');
    await connect('district-city', 'district', 'city', 'belongsTo');
    await connect('leader-faction', 'leader', 'faction-a', 'memberOf',
        metadata: const {'rank': 'High Lantern', 'status': 'Active'});
    await connect('member-faction', 'member', 'faction-a', 'memberOf');
    await connect('enemy-faction', 'enemy', 'faction-b', 'memberOf');
    await connect('faction-rivalry', 'faction-a', 'faction-b', 'connectedTo',
        metadata: const {
          'strength': 5,
          'startDate': '342-01-01',
          'status': 'Hostile',
          'secret': false,
          'context': 'Control of the Glass Ward',
          'confidence': 5,
        });
    await connect('culture-country', 'culture', 'country', 'belongsTo');
    await connect('religion-culture', 'culture', 'religion', 'practices');
    await connect('leader-religion', 'leader', 'religion', 'worships');
    await connect('magic-culture', 'magic', 'culture', 'influences');
    await connect('event-1-city', 'event-1', 'city', 'occursAt');
    await connect('event-2-leader', 'event-2', 'leader', 'involves');
    await connect('event-3-faction-a', 'event-3', 'faction-a', 'involves');
    await connect('event-order-1', 'event-1', 'event-2', 'precedes');
    await connect('event-order-2', 'event-2', 'event-3', 'precedes');
    await connect('item-owner', 'leader', 'item-1', 'owns');
    await connect('item-location', 'item-2', 'city', 'locatedIn');
    await connect('book-chapter-1', 'chapter-1', 'book', 'partOf');
    await connect('book-chapter-2', 'chapter-2', 'book', 'partOf');
    await connect('chapter-scene-1', 'scene-1', 'chapter-1', 'partOf');
    await connect('chapter-scene-2', 'scene-2', 'chapter-1', 'partOf');
    await connect('chapter-scene-3', 'scene-3', 'chapter-2', 'partOf');
    await connect('city-scene', 'city', 'scene-1', 'appearsIn');
    await connect('religion-scene', 'religion', 'scene-2', 'revealedIn');
    await connect('event-scene', 'event-3', 'scene-3', 'confirmedIn');

    return StoryCodexPhase1Fixture._(
      codex: codex,
      ids: Map.unmodifiable(ids),
      links: Map.unmodifiable(links),
    );
  }
}
