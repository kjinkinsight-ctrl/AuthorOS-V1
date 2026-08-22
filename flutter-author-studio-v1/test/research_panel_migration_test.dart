import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/research_record_types.dart';
import 'package:author_studio_v1/migrations/research_panel_migration.dart';
import 'package:author_studio_v1/migrations/research_panel_store.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/research_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const projectA = 'fixture-research-panel';
const projectB = 'project-panel-b';
final timestamp = DateTime.utc(2026, 8, 21, 12);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late ResearchPanelMigrationService migration;
  late ResearchService research;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    migration = ResearchPanelMigrationService(
      projectId: projectA,
      repository: repository,
    );
    research = ResearchService(projectId: projectA, repository: repository);
  });

  tearDown(() => database.close());

  /// Stages a legacy blob the way the panel used to write it.
  Future<void> seedLegacy(
    Map<ResearchTab, List<ResearchReference>> references, {
    String projectId = projectA,
  }) =>
      ProjectResearchStore(projectId: projectId).save(references);

  /// Stages a raw blob, for shapes `save` cannot produce.
  Future<void> seedRaw(String json, {String projectId = projectA}) async {
    SharedPreferences.setMockInitialValues({
      '${ProjectResearchStore.keyPrefix}$projectId': json,
    });
  }

  group('Migrating panel data into records', () {
    test('every reference becomes a canonical research record', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(
            title: 'Bridge district lore',
            detail: 'Lanterns and rain on slate roads.',
            tag: 'World',
          ),
        ],
        ResearchTab.notes: const [
          ResearchReference(
            title: 'Mara timeline',
            detail: 'She returns to the river before every lie.',
            tag: 'Character',
          ),
        ],
        ResearchTab.timeline: const [
          ResearchReference(
            title: 'The long winter',
            detail: 'Three seasons of frost.',
            tag: 'timeline',
          ),
        ],
      });

      final report = await migration.migrate(timestamp: timestamp);

      expect(report.ran, isTrue);
      expect(report.created, hasLength(3));
      expect(report.skipped, isEmpty);

      final records = await research.query.all();
      expect(records.map((r) => r.title).toSet(), {
        'Bridge district lore',
        'Mara timeline',
        'The long winter',
      });
      // They are ordinary research records, readable off the shared repository.
      for (final record in records) {
        expect(record.typeId, ResearchRecordTypes.baseTypeId);
        expect(record.projectId, projectA);
        expect(await repository.recordById(record.id), isNotNull);
      }
    });

    test('detail becomes the summary and tabs choose the kind', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'A source', detail: 'Cited.', tag: 'World'),
        ],
        ResearchTab.notes: const [
          ResearchReference(title: 'A note', detail: 'Jotted.', tag: 'notes'),
        ],
        ResearchTab.timeline: const [
          ResearchReference(title: 'A date', detail: 'Later.', tag: 'timeline'),
        ],
      });
      await migration.migrate(timestamp: timestamp);

      Future<AuthorRecord> byTitle(String title) async =>
          (await research.query.all())
              .firstWhere((record) => record.title == title);

      final source = await byTitle('A source');
      expect(ResearchService.kindOf(source), 'Reference');
      expect(ResearchService.summaryOf(source), 'Cited.');

      expect(ResearchService.kindOf(await byTitle('A note')), 'Note');
      // Timeline entries were prose about chronology, not timeline records,
      // so they become notes rather than invented `timeline-*` records.
      expect(ResearchService.kindOf(await byTitle('A date')), 'Note');
    });

    test('a tag naming a category becomes the category, not a tag', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'Slate roads', detail: '', tag: 'Geography'),
          ResearchReference(title: 'Guild ledger', detail: '', tag: 'research'),
        ],
      });
      await migration.migrate(timestamp: timestamp);

      final records = {
        for (final record in await research.query.all()) record.title: record,
      };

      final categorised = records['Slate roads']!;
      expect(ResearchService.categoryOf(categorised), 'Geography');
      expect(categorised.tags, isEmpty,
          reason: 'A tag consumed as the category must not be duplicated.');

      final uncategorised = records['Guild ledger']!;
      expect(ResearchService.categoryOf(uncategorised),
          ResearchRecordTypes.defaultCategory);
      expect(uncategorised.tags, ['research'],
          reason: "The author's own label must survive as a tag.");
    });

    test('each record carries provenance back to its legacy slot', () async {
      await seedLegacy({
        ResearchTab.notes: const [
          ResearchReference(title: 'Rope knots', detail: '', tag: 'notes'),
        ],
      });
      await migration.migrate(timestamp: timestamp);

      final record = (await research.query.all()).single;
      final provenance = record.extensionData[
          ResearchPanelMigrationService.provenanceField] as Map<String, Object?>;
      expect(provenance['store'], ProjectResearchStore.keyPrefix);
      expect(provenance['projectId'], projectA);
      expect(provenance['tab'], 'notes');
      expect(provenance['index'], 0);
      expect(provenance['tag'], 'notes');
      // Still a Research Studio record, so the Studio's own marker survives.
      expect(record.extensionData['researchStudio'], isTrue);
      // One create, not a create plus a provenance update.
      expect(record.revision, 1);
    });
  });

  group('Never losing author data', () {
    test('the legacy key is left intact after migrating', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'Kept', detail: 'Still here.', tag: 'World'),
        ],
      });
      final report = await migration.migrate(timestamp: timestamp);

      expect(report.legacyDataRetained, isTrue);
      const store = ProjectResearchStore(projectId: projectA);
      expect(await store.hasLegacyData(), isTrue);
      // And it still parses back to the original reference.
      final reloaded = await store.load();
      expect(reloaded[ResearchTab.research]!.single.title, 'Kept');
      expect(reloaded[ResearchTab.research]!.single.detail, 'Still here.');
    });

    test('a marker records what was created', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'Receipted', detail: '', tag: 'World'),
        ],
      });
      final report = await migration.migrate(timestamp: timestamp);

      final marker =
          await const ProjectResearchStore(projectId: projectA).readMarker();
      expect(marker, isNotNull);
      expect(marker!.migratedAt, timestamp);
      expect(marker.createdRecordIds, [report.created.single.id]);
    });

    test('one bad reference never costs the rest of the migration', () async {
      // A whitespace-only title cannot name a record; the others must survive.
      await seedRaw(jsonEncode({
        'research': [
          {'title': 'Good one', 'detail': 'Fine.', 'tag': 'World'},
          {'title': '   ', 'detail': 'Nameless.', 'tag': 'World'},
          {'title': 'Good two', 'detail': 'Also fine.', 'tag': 'World'},
        ],
      }));

      final report = await migration.migrate(timestamp: timestamp);

      expect(report.created.map((r) => r.title), ['Good one', 'Good two']);
      expect(report.skipped, hasLength(1));
      expect(report.skipped.single.reason, ResearchPanelSkipReason.emptyTitle);
      // The skipped one is still in the legacy store, not lost.
      expect(
        await const ProjectResearchStore(projectId: projectA)
            .hasLegacyData(),
        isTrue,
      );
    });

    test('an unknown tab folds in without erasing the known one', () async {
      // A blob from an older build carrying a tab this build dropped. Both
      // that tab and `research` fold onto `research`; neither may be lost.
      await seedRaw(jsonEncode({
        'research': [
          {'title': 'Known tab entry', 'detail': '', 'tag': 'World'},
        ],
        'chronicle': [
          {'title': 'Dropped tab entry', 'detail': '', 'tag': 'History'},
        ],
      }));

      final report = await migration.migrate(timestamp: timestamp);

      expect(
        report.created.map((r) => r.title).toSet(),
        {'Known tab entry', 'Dropped tab entry'},
      );
    });

    test('an unreadable blob migrates nothing and destroys nothing', () async {
      await seedRaw('this is not json');
      final report = await migration.migrate(timestamp: timestamp);

      expect(report.ran, isFalse);
      expect(report.created, isEmpty);
      expect(await research.query.all(), isEmpty);
      // The corrupt value is still on disk for a human to recover.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${ProjectResearchStore.keyPrefix}$projectA'),
        'this is not json',
      );
    });
  });

  group('Idempotency', () {
    test('running twice creates nothing twice', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'Once only', detail: 'x', tag: 'World'),
        ],
      });

      final first = await migration.migrate(timestamp: timestamp);
      expect(first.created, hasLength(1));

      final second = await migration.migrate(timestamp: timestamp);
      expect(second.ran, isFalse, reason: 'The marker should short-circuit.');
      expect(await research.query.all(), hasLength(1));
    });

    test('re-running past the marker still does not duplicate', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'Once only', detail: 'x', tag: 'World'),
        ],
      });
      await migration.migrate(timestamp: timestamp);

      // Ignore the marker entirely — derived ids must carry idempotency alone.
      final forced = await migration.migrateNow(timestamp: timestamp);
      expect(forced.created, isEmpty);
      expect(forced.skipped.single.reason,
          ResearchPanelSkipReason.alreadyMigrated);
      expect(await research.query.all(), hasLength(1));
    });

    test('reordering the legacy list does not create new records', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'First', detail: '', tag: 'World'),
          ResearchReference(title: 'Second', detail: '', tag: 'World'),
        ],
      });
      await migration.migrate(timestamp: timestamp);

      // The author reorders the panel; ids derive from title, not position.
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'Second', detail: '', tag: 'World'),
          ResearchReference(title: 'First', detail: '', tag: 'World'),
        ],
      });
      final again = await migration.migrateNow(timestamp: timestamp);

      expect(again.created, isEmpty);
      expect(await research.query.all(), hasLength(2));
    });

    test('two entries sharing a title collapse onto one record', () async {
      await seedRaw(jsonEncode({
        'research': [
          {'title': 'Salt roads', 'detail': 'First.', 'tag': 'Geography'},
          {'title': 'Salt roads', 'detail': 'Second.', 'tag': 'Geography'},
        ],
      }));

      final report = await migration.migrate(timestamp: timestamp);

      expect(report.created, hasLength(1));
      expect(report.skipped.single.reason,
          ResearchPanelSkipReason.alreadyMigrated);
      expect(await research.query.all(), hasLength(1));
    });

    test('an empty legacy store is a no-op that writes no marker', () async {
      final report = await migration.migrate(timestamp: timestamp);

      expect(report.ran, isFalse);
      expect(await research.query.all(), isEmpty);
      expect(
        await const ProjectResearchStore(projectId: projectA).readMarker(),
        isNull,
        reason: 'Nothing was migrated, so nothing should be marked migrated.',
      );
    });
  });

  group('Derived record ids', () {
    test('are deterministic, namespaced, and title-cased alike', () {
      final first = migration.recordIdFor(
        tab: ResearchTab.research,
        title: 'Salt roads',
      );
      // Same input, same id — this is what makes a re-run a no-op.
      expect(
        migration.recordIdFor(tab: ResearchTab.research, title: 'Salt roads'),
        first,
      );
      // Case and surrounding whitespace do not mint a second record.
      expect(
        migration.recordIdFor(tab: ResearchTab.research, title: '  SALT ROADS '),
        first,
      );
      // Tab and project both namespace the id.
      expect(
        migration.recordIdFor(tab: ResearchTab.notes, title: 'Salt roads'),
        isNot(first),
      );
      expect(
        ResearchPanelMigrationService(
          projectId: projectB,
          repository: repository,
        ).recordIdFor(tab: ResearchTab.research, title: 'Salt roads'),
        isNot(first),
      );
    });

    test('stay within JavaScript-safe integer arithmetic', () {
      // The first cut used a 64-bit FNV-1a, whose constants cannot be
      // represented in JavaScript — `flutter build web` failed to compile
      // while every test still passed. The digest must stay web-safe.
      final source = File('lib/migrations/research_panel_migration.dart')
          .readAsStringSync();
      for (final literal in RegExp(r'0x[0-9a-fA-F]+').allMatches(source)) {
        final value = int.parse(literal.group(0)!.substring(2), radix: 16);
        expect(
          value <= 0x1FFFFFFFFFFFFF,
          isTrue,
          reason: '${literal.group(0)} exceeds 2^53 and will not compile to '
              'JavaScript.',
        );
      }
    });

    test('produce a fixed-width digest', () {
      for (final title in ['a', 'a much longer research entry title', '']) {
        final id =
            migration.recordIdFor(tab: ResearchTab.research, title: title);
        expect(id, startsWith('research-panel-'));
        expect(id.length, 'research-panel-'.length + 16);
      }
    });

    test('do not collide across a realistic body of titles', () {
      final ids = <String>{};
      for (var index = 0; index < 2000; index++) {
        for (final tab in ResearchTab.values) {
          ids.add(migration.recordIdFor(tab: tab, title: 'Entry $index'));
        }
      }
      expect(ids, hasLength(6000));
    });
  });

  group('Project isolation', () {
    test('one project migrates without touching another', () async {
      await seedLegacy({
        ResearchTab.research: const [
          ResearchReference(title: 'Belongs to A', detail: '', tag: 'World'),
        ],
      });
      await seedLegacy(
        {
          ResearchTab.research: const [
            ResearchReference(title: 'Belongs to B', detail: '', tag: 'World'),
          ],
        },
        projectId: projectB,
      );

      await migration.migrate(timestamp: timestamp);

      expect(
        (await research.query.all()).map((r) => r.title),
        ['Belongs to A'],
      );
      // Project B's records do not exist yet, and its marker is unwritten.
      final otherResearch =
          ResearchService(projectId: projectB, repository: repository);
      expect(await otherResearch.query.all(), isEmpty);
      expect(
        await const ProjectResearchStore(projectId: projectB).readMarker(),
        isNull,
      );

      // Migrating B keeps them apart.
      await ResearchPanelMigrationService(
        projectId: projectB,
        repository: repository,
      ).migrate(timestamp: timestamp);

      expect(
        (await research.query.all()).map((r) => r.title),
        ['Belongs to A'],
      );
      expect(
        (await otherResearch.query.all()).map((r) => r.title),
        ['Belongs to B'],
      );
    });

    test('the same title in two projects yields distinct records', () async {
      const shared = ResearchReference(
        title: 'Shared title',
        detail: '',
        tag: 'World',
      );
      await seedLegacy({
        ResearchTab.research: const [shared],
      });
      await seedLegacy(
        {
          ResearchTab.research: const [shared],
        },
        projectId: projectB,
      );

      await migration.migrate(timestamp: timestamp);
      await ResearchPanelMigrationService(
        projectId: projectB,
        repository: repository,
      ).migrate(timestamp: timestamp);

      final a = (await research.query.all()).single;
      final b = (await ResearchService(
        projectId: projectB,
        repository: repository,
      ).query.all())
          .single;
      expect(a.id, isNot(b.id),
          reason: 'Record ids must be namespaced per project.');
    });
  });

  group('Legacy fixtures', () {
    Map<String, dynamic> fixture(String name) => Map<String, dynamic>.from(
          jsonDecode(
            File('test/fixtures/$name.json').readAsStringSync(),
          ) as Map,
        );

    /// Materialises a fixture's preferences the way the app would find them.
    Future<void> installFixture(Map<String, dynamic> data) async {
      final preferences = Map<String, dynamic>.from(
        data['preferences'] as Map,
      );
      final values = <String, Object>{};
      for (final entry in preferences.entries) {
        final stored = Map<String, dynamic>.from(entry.value as Map);
        values[entry.key] = stored['storageType'] == 'json'
            ? jsonEncode(stored['value'])
            : stored['value'] as String;
      }
      SharedPreferences.setMockInitialValues(values);
    }

    test('the panel fixture migrates exactly as recorded', () async {
      final data = fixture('legacy-research-panel');
      await installFixture(data);

      final report = await ResearchPanelMigrationService(
        projectId: data['projectId'] as String,
        repository: repository,
      ).migrate(timestamp: timestamp);

      final expectations = data['expectations'] as Map;
      expect(report.created, hasLength(expectations['referenceCount']));

      final service = ResearchService(
        projectId: data['projectId'] as String,
        repository: repository,
      );
      final records = {
        for (final record in await service.query.all()) record.title: record,
      };

      expect(ResearchService.categoryOf(records['Bridge district lore']!),
          'World');
      expect(ResearchService.categoryOf(records['Mara timeline']!), 'Character');
      expect(records['Harbour customs ledger']!.tags, ['research']);
      expect(ResearchService.kindOf(records['The long winter']!), 'Note');
    });

    test('the malformed fixture degrades without losing readable entries',
        () async {
      final data = fixture('legacy-research-panel-malformed');
      final projectId = data['projectId'] as String;
      await installFixture(data);

      final report = await ResearchPanelMigrationService(
        projectId: projectId,
        repository: repository,
      ).migrate(timestamp: timestamp);

      final titles = report.created.map((record) => record.title).toSet();
      // Readable entries survive, including one from a tab this build dropped
      // and one whose title key was missing entirely.
      expect(titles, contains('Salt roads'));
      expect(titles, contains('Rope knots'));
      expect(titles, contains('Untitled reference'));
      expect(titles, contains('Entry filed under a tab this build does not know'));

      // The whitespace title is skipped, and the duplicate collapses.
      expect(
        report.skipped.map((skip) => skip.reason),
        containsAll(<ResearchPanelSkipReason>[
          ResearchPanelSkipReason.emptyTitle,
          ResearchPanelSkipReason.alreadyMigrated,
        ]),
      );
      expect(
        await ProjectResearchStore(projectId: projectId).hasLegacyData(),
        isTrue,
      );
    });
  });
}
