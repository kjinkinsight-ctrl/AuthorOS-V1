import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_types.dart';
import 'package:author_studio_v1/main.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/theme/flutter/authoros_theme.dart';
import 'package:author_studio_v1/theme/theme_definition.dart';
import 'package:author_studio_v1/theme/theme_engine.dart';
import 'package:author_studio_v1/theme/theme_persistence.dart';
import 'package:author_studio_v1/theme/theme_tokens.dart';
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:author_studio_v1/timeline_studio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const projectId = 'project-timeline';
final timestamp = DateTime.utc(2026, 8, 20, 10);

const crownCalendar = TimelineCalendar(
  id: 'calendar-crown',
  name: 'Crown Calendar',
  months: [
    TimelineCalendarMonth(name: 'Ember', length: 30),
    TimelineCalendarMonth(name: 'Rain', length: 30),
    TimelineCalendarMonth(name: 'Bloom', length: 30),
    TimelineCalendarMonth(name: 'Sun', length: 30),
  ],
);

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late TimelineService timeline;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    timeline = TimelineService(projectId: projectId, repository: repository);
  });

  tearDown(() => database.close());

  Future<AuthorRecord> seedEvent(
    String id,
    String name, {
    int? year,
    int? month,
    int? day,
    String typeId = 'timeline-event',
    String summary = '',
    List<String> tags = const [],
  }) =>
      timeline.createEvent(
        TimelineEventDraft(
          id: id,
          name: name,
          typeId: typeId,
          summary: summary,
          tags: tags,
          start: year == null
              ? null
              : TimelineDate(
                  calendarId: crownCalendar.id,
                  year: year,
                  month: month,
                  day: day,
                ),
        ),
        timestamp: timestamp,
      );

  group('TimelineService studio operations', () {
    test('create, retrieve, update, and delete stay in Universal Records',
        () async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      final created = await seedEvent('event-fall', 'The Fall of Endovier',
          year: 12, typeId: 'timeline-battle');
      expect(created.typeId, 'timeline-battle');
      expect(created.projectId, projectId);
      expect(created.extensionData['timelineStudio'], isTrue);

      final loaded = await timeline.getTimelineRecord('event-fall');
      expect(loaded, isNotNull);
      expect(loaded!.title, 'The Fall of Endovier');

      final updated = await timeline.updateEvent(
        const TimelineEventDraft(
          id: 'event-fall',
          name: 'The Fall of the Harbor',
          typeId: 'timeline-battle',
          summary: 'The harbor burns.',
          importance: 'critical',
          start: TimelineDate(calendarId: 'calendar-crown', year: 14),
        ),
        timestamp: timestamp,
      );
      expect(updated.title, 'The Fall of the Harbor');
      expect(updated.typeId, 'timeline-battle');
      expect(updated.fields['importance'], 'critical');

      // The shared record service forbids type changes on update; the
      // Timeline facade surfaces the same rule.
      expect(
        () => timeline.updateEvent(
          const TimelineEventDraft(
            id: 'event-fall',
            name: 'The Fall of the Harbor',
            typeId: 'timeline-disaster',
          ),
          timestamp: timestamp,
        ),
        throwsArgumentError,
      );
      expect(updated.revision, greaterThan(created.revision));
      expect(
        await timeline.history.getVersionHistory(recordId: 'event-fall'),
        hasLength(2),
      );

      final deleted = await timeline.deleteTimelineRecord('event-fall');
      expect(deleted.status, AuthorRecordStatus.deleted);
      final active = await timeline.query.all(
        status: AuthorRecordStatus.active,
      );
      expect(active.where((record) => record.id == 'event-fall'), isEmpty);
    });

    test('updateEvent rejects an end date before its start', () async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-war', 'The War Years', year: 18);
      expect(
        () => timeline.updateEvent(
          const TimelineEventDraft(
            id: 'event-war',
            name: 'The War Years',
            start: TimelineDate(calendarId: 'calendar-crown', year: 18),
            end: TimelineDate(calendarId: 'calendar-crown', year: 4),
          ),
          timestamp: timestamp,
        ),
        throwsA(isA<TimelineValidationException>()),
      );
    });

    test('chronological ordering follows calendar ordinals', () async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-late', 'Zenith of the Age', year: 40);
      await seedEvent('event-early', 'Age of Founding', year: 1);
      await seedEvent('event-mid', 'A Rain Wedding', year: 18, month: 2, day: 5);
      await seedEvent('event-undated', 'A Rumor Without a Year');

      final ordered = await timeline.query.chronological();
      expect(ordered.map((record) => record.id).toList(), [
        'event-early',
        'event-mid',
        'event-late',
        'event-undated',
      ]);

      final reversed = await timeline.query.chronological(descending: true);
      expect(reversed.map((record) => record.id).toList(), [
        'event-late',
        'event-mid',
        'event-early',
        'event-undated',
      ]);
    });

    test('timeline events stay isolated per project', () async {
      final other = TimelineService(
        projectId: 'project-other',
        repository: repository,
      );
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await other.createCalendar(
        const TimelineCalendar(
          id: 'calendar-other',
          name: 'Other Calendar',
          months: [TimelineCalendarMonth(name: 'One', length: 30)],
        ),
        timestamp: timestamp,
      );
      await seedEvent('event-a', 'Only In Project A', year: 3);
      await other.createEvent(
        const TimelineEventDraft(
          id: 'event-b',
          name: 'Only In Project B',
          start: TimelineDate(calendarId: 'calendar-other', year: 9),
        ),
        timestamp: timestamp,
      );

      final inA = await timeline.query.chronological();
      final inB = await other.query.chronological();
      expect(inA.map((record) => record.id), ['event-a']);
      expect(inB.map((record) => record.id), ['event-b']);
      expect(await timeline.getTimelineRecord('event-b'), isNull);
      expect(await other.getTimelineRecord('event-a'), isNull);
      expect((await timeline.calendars()).map((calendar) => calendar.id),
          ['calendar-crown']);
      expect((await other.calendars()).map((calendar) => calendar.id),
          ['calendar-other']);
    });

    test('calendar formatting renders project dates', () async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      final calendar = await timeline.getCalendar('calendar-crown');
      expect(
        calendar!.format(const TimelineDate(
          calendarId: 'calendar-crown',
          year: 18,
          month: 2,
          day: 5,
        )),
        '18-2-5',
      );
      expect(
        calendar.format(
            const TimelineDate(calendarId: 'calendar-crown', year: 18)),
        '18',
      );
    });
  });

  Future<void> pumpStudio(
    WidgetTester tester, {
    DriftConnectedDomainRepository? repositoryOverride,
    List<TimelineNavigationRequest>? navigations,
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TimelineStudioView(
            projectId: projectId,
            repository: repositoryOverride ?? repository,
            onNavigate: navigations?.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('Timeline Studio widget', () {
    testWidgets('the empty timeline explains itself and creates a first event',
        (tester) async {
      await pumpStudio(tester);

      expect(find.byKey(const Key('timeline-studio')), findsOneWidget);
      expect(find.byKey(const Key('timeline-empty-state')), findsOneWidget);
      expect(find.text('Your story has no events yet.'), findsOneWidget);

      await tapKey(tester, const Key('timeline-empty-create-button'));
      expect(find.byKey(const Key('timeline-event-dialog')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('timeline-event-title-field')),
        'The First Bell',
      );
      await tester.enterText(
        find.byKey(const Key('timeline-event-start-year-field')),
        '3',
      );
      await tester.enterText(
        find.byKey(const Key('timeline-event-summary-field')),
        'The city wakes.',
      );
      await tapKey(tester, const Key('timeline-event-save-button'));

      expect(find.byKey(const Key('timeline-empty-state')), findsNothing);
      expect(find.text('The First Bell'), findsWidgets);

      final records = await timeline.query.chronological();
      expect(records, hasLength(1));
      final created = records.single;
      expect(created.title, 'The First Bell');
      expect(created.typeId, 'timeline-event');
      expect(created.fields['summary'], 'The city wakes.');
      expect(created.projectId, projectId);

      // A dated first event provisions the default project calendar through
      // the service rather than a second persistence path.
      final calendars = await timeline.calendars();
      expect(calendars, hasLength(1));
      expect(calendars.single.id, 'calendar-$projectId');
    });

    testWidgets('a populated timeline renders markers in chronological order',
        (tester) async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-late', 'Zenith of the Age', year: 40);
      await seedEvent('event-early', 'Age of Founding', year: 1);
      await seedEvent('event-mid', 'A Rain Wedding',
          year: 18, month: 2, day: 5, summary: 'Vows in the rain.');
      await seedEvent('event-undated', 'A Rumor Without a Year');

      await pumpStudio(tester);

      expect(find.byKey(const Key('timeline-event-event-early')),
          findsOneWidget);
      expect(
          find.byKey(const Key('timeline-marker-event-early')), findsOneWidget);
      expect(find.byKey(const Key('timeline-undated-header')), findsOneWidget);
      expect(find.text('18-2-5'), findsOneWidget);
      expect(find.text('Undated'), findsWidgets);

      final earlyY = tester
          .getTopLeft(find.byKey(const Key('timeline-event-event-early')))
          .dy;
      final midY = tester
          .getTopLeft(find.byKey(const Key('timeline-event-event-mid')))
          .dy;
      final lateY = tester
          .getTopLeft(find.byKey(const Key('timeline-event-event-late')))
          .dy;
      final undatedY = tester
          .getTopLeft(find.byKey(const Key('timeline-event-event-undated')))
          .dy;
      expect(earlyY, lessThan(midY));
      expect(midY, lessThan(lateY));
      expect(lateY, lessThan(undatedY));

      await tapKey(tester, const Key('timeline-sort-toggle'));
      final earlyAfter = tester
          .getTopLeft(find.byKey(const Key('timeline-event-event-early')))
          .dy;
      final lateAfter = tester
          .getTopLeft(find.byKey(const Key('timeline-event-event-late')))
          .dy;
      expect(lateAfter, lessThan(earlyAfter));
    });

    testWidgets('selecting an event opens details and edit persists changes',
        (tester) async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-wedding', 'A Rain Wedding',
          year: 18, summary: 'Vows in the rain.');

      await pumpStudio(tester);
      await tapKey(tester, const Key('timeline-event-event-wedding'));

      expect(find.byKey(const Key('timeline-detail-pane')), findsOneWidget);
      expect(find.text('Vows in the rain.'), findsWidgets);

      await tapKey(tester, const Key('timeline-edit-button'));
      expect(find.byKey(const Key('timeline-event-dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('timeline-event-title-field')),
        'A Storm Wedding',
      );
      await tester.enterText(
        find.byKey(const Key('timeline-event-start-year-field')),
        '21',
      );
      await tapKey(tester, const Key('timeline-event-save-button'));

      expect(find.text('A Storm Wedding'), findsWidgets);
      final record = await timeline.getTimelineRecord('event-wedding');
      expect(record!.title, 'A Storm Wedding');
      final start = (record.fields['start'] as List).first as Map;
      expect(start['year'], 21);
      expect(
        await timeline.history.getVersionHistory(recordId: 'event-wedding'),
        hasLength(2),
      );
    });

    testWidgets('deleting an event soft-deletes through the shared lifecycle',
        (tester) async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-doomed', 'A Doomed Feast', year: 7);

      await pumpStudio(tester);
      await tapKey(tester, const Key('timeline-event-event-doomed'));
      await tapKey(tester, const Key('timeline-delete-button'));
      expect(find.byKey(const Key('timeline-delete-dialog')), findsOneWidget);
      await tapKey(tester, const Key('timeline-delete-confirm'));

      expect(find.byKey(const Key('timeline-event-event-doomed')),
          findsNothing);
      expect(find.byKey(const Key('timeline-empty-state')), findsOneWidget);
      final record = await repository.recordById('event-doomed');
      expect(record!.status, AuthorRecordStatus.deleted);
    });

    testWidgets('archive hides an event until archived events are shown',
        (tester) async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-old', 'An Old Rite', year: 2);
      await seedEvent('event-new', 'A New Rite', year: 30);

      await pumpStudio(tester);
      await tapKey(tester, const Key('timeline-event-event-old'));
      await tapKey(tester, const Key('timeline-archive-button'));
      expect(find.byKey(const Key('timeline-event-event-old')), findsNothing);

      await tapKey(tester, const Key('timeline-show-archived'));
      expect(find.byKey(const Key('timeline-event-event-old')), findsOneWidget);
      final record = await repository.recordById('event-old');
      expect(record!.status, AuthorRecordStatus.archived);
    });

    testWidgets('search and type filters narrow the rail', (tester) async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-battle', 'Battle of the Bluffs',
          year: 20, typeId: 'timeline-battle');
      await seedEvent('event-birth', 'Birth of Mara',
          year: 5, typeId: 'timeline-birth');

      await pumpStudio(tester);
      await tester.enterText(
        find.byKey(const Key('timeline-search-field')),
        'bluffs',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('timeline-event-event-battle')),
          findsOneWidget);
      expect(find.byKey(const Key('timeline-event-event-birth')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('timeline-search-field')),
        'no such event',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('timeline-no-matches')), findsOneWidget);
    });

    testWidgets('a failing repository surfaces the error state and retry',
        (tester) async {
      final failing = _FailingRepository(database);
      await pumpStudio(tester, repositoryOverride: failing);

      expect(find.byKey(const Key('timeline-error-state')), findsOneWidget);
      expect(find.byKey(const Key('timeline-retry-button')), findsOneWidget);

      failing.failing = false;
      await tapKey(tester, const Key('timeline-retry-button'));
      expect(find.byKey(const Key('timeline-error-state')), findsNothing);
      expect(find.byKey(const Key('timeline-empty-state')), findsOneWidget);
    });

    testWidgets('the studio resolves colours from the Theme Engine scope',
        (tester) async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-lit', 'A Lit Beacon', year: 9);

      final resolved = ThemeEngine.standard(store: MemoryThemeSettingsStore())
          .resolveSelection(
        selection: const ThemeSelection(
          themeId: 'light',
          mode: AuthorOsThemeMode.light,
          accessibility: ThemeAccessibility.none,
        ),
        hostBrightness: ThemeBrightness.light,
      );
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AuthorOsTheme.toThemeData(resolved),
        home: StudioThemeScope(
          theme: resolved,
          studio: StudioId.shell,
          child: Scaffold(
            body: SingleChildScrollView(
              child: TimelineStudioView(
                projectId: projectId,
                repository: repository,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final marker = tester.widget<Container>(
        find.byKey(const Key('timeline-marker-event-lit')),
      );
      final decoration = marker.decoration! as BoxDecoration;
      final expected = AuthorOsTheme.color(
        resolved.colorFor(StudioId.timeline, ThemeColorRef.primary),
      );
      expect(decoration.border!.top.color, expected);
    });

    testWidgets('the studio stays usable at the supported desktop sizes',
        (tester) async {
      await timeline.createCalendar(crownCalendar, timestamp: timestamp);
      await seedEvent('event-one', 'Age of Founding', year: 1);
      await seedEvent('event-two', 'A Rain Wedding', year: 18);

      for (final size in const [
        Size(1280, 720),
        Size(1440, 900),
        Size(1920, 1080),
      ]) {
        await pumpStudio(tester, size: size);
        await tapKey(tester, const Key('timeline-event-event-one'));
        expect(find.byKey(const Key('timeline-detail-pane')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Sidebar navigation', () {
    testWidgets('the Timeline chip opens the real Timeline Studio',
        (tester) async {
      final project = NovelStarterKit.create(
        title: 'Northstar',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 90000,
      );
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        home: AuthorStudioShell(
          project: project,
          themeId: 'paper',
          accentId: 'default',
          onThemeChanged: (_, __) {},
          initialSection: StudioSection.dashboard,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));

      final tile = find.widgetWithText(InkWell, 'Timeline');
      await tester.ensureVisible(tile);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(tile);
      // The studio loads against the app-default repository; a few plain
      // pumps let the loading state resolve without waiting on animations.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(TimelineStudioView), findsOneWidget);
      expect(find.text('Timeline Studio'), findsWidgets);
      // The legacy SharedPreferences board is gone.
      expect(find.text('Add Era'), findsNothing);
      expect(find.text('Add Sequence'), findsNothing);
    });
  });
}

/// Fails every read until [failing] is cleared, so the Studio's error and
/// retry paths can be exercised against the real service stack.
class _FailingRepository extends DriftConnectedDomainRepository {
  _FailingRepository(super.database);

  bool failing = true;

  @override
  Future<List<RecordTypeDefinition>> recordTypeDefinitionsByScope({
    required RecordScopeType scopeType,
    required String scopeId,
  }) {
    if (failing) throw StateError('storage offline');
    return super.recordTypeDefinitionsByScope(
      scopeType: scopeType,
      scopeId: scopeId,
    );
  }
}
