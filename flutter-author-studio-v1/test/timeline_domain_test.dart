import 'package:author_studio_v1/archive/authoros_archive.dart';
import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/record_inspection.dart';
import 'package:author_studio_v1/core/safe_delete.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/timeline_domain_fixture.dart';

void main() {
  late AuthorOsDatabase database;
  late DriftConnectedDomainRepository repository;
  late TimelineService timeline;
  final timestamp = DateTime.utc(2026, 8, 20);

  setUp(() {
    database = AuthorOsDatabase(NativeDatabase.memory());
    repository = DriftConnectedDomainRepository(database);
    timeline = TimelineService(projectId: 'project-a', repository: repository);
  });

  tearDown(() => database.close());

  test('calendar event CRUD uses shared search inspector audit and safe delete',
      () async {
    await timeline.createCalendar(_calendar(),
        primary: true, timestamp: timestamp);
    final event = await timeline.createEvent(
      TimelineEventDraft(
        id: 'founding',
        name: 'Founding of Endovier',
        typeId: 'timeline-founding',
        summary: 'The first government is established.',
        start: const TimelineDate(
          calendarId: 'royal-calendar',
          year: 12,
          month: 2,
          day: 4,
        ),
        end: const TimelineDate(
          calendarId: 'royal-calendar',
          year: 12,
          month: 2,
          day: 4,
        ),
        tags: const ['Historical', 'Political'],
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );

    final updated = await timeline.updateTimelineRecord(
      event.copyWith(
        fields: {...event.fields, 'importance': 'critical'},
        updatedAt: timestamp.add(const Duration(days: 1)),
      ),
    );
    final found = await timeline.query.between(
      const TimelineDate(
          calendarId: 'royal-calendar', year: 12, month: 1, day: 1),
      const TimelineDate(
          calendarId: 'royal-calendar', year: 12, month: 3, day: 1),
    );
    final search = await timeline.searchTimeline('Endovier');
    final inspection = await timeline.inspectTimelineRecord(event.id);
    final history = await timeline.getTimelineHistory(event.id);
    final deletion = await timeline.analyzeDelete(event.id);

    expect(updated.revision, 2);
    expect(found.single.id, event.id);
    expect(search.single.recordId, event.id);
    expect(inspection?.recordType, 'timeline-founding');
    expect(inspection?.validation.state, InspectionValidationState.valid);
    expect(history, hasLength(2));
    expect(deletion?.disposition, SafeDeleteDisposition.safeWithWarnings);
  });

  test('calendar supports year zero rules, backwards years and exact ranges',
      () async {
    const backwards = TimelineCalendar(
      id: 'before-fall',
      name: 'Before the Fall',
      months: [
        TimelineCalendarMonth(name: 'Ash', length: 10),
        TimelineCalendarMonth(name: 'Rain', length: 20),
      ],
      hasYearZero: false,
      yearsCountBackward: true,
    );
    expect(
      () => backwards.ordinal(
        const TimelineDate(
            calendarId: 'before-fall', year: 0, month: 1, day: 1),
      ),
      throwsArgumentError,
    );
    expect(
      backwards.ordinal(
        const TimelineDate(
            calendarId: 'before-fall', year: 2, month: 1, day: 1),
      ),
      lessThan(
        backwards.ordinal(
          const TimelineDate(
              calendarId: 'before-fall', year: 1, month: 1, day: 1),
        ),
      ),
    );
  });

  test(
      'relative dates, age calculation and temporal validation are deterministic',
      () async {
    await timeline.createCalendar(_calendar(), timestamp: timestamp);
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'birth',
        name: 'Mara is born',
        typeId: 'timeline-birth',
        start: TimelineDate(
            calendarId: 'royal-calendar', year: 1, month: 1, day: 1),
      ),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'coronation',
        name: 'Mara is crowned',
        start: TimelineDate(
            calendarId: 'royal-calendar', year: 21, month: 1, day: 1),
        relativeDate: RelativeTimelineDate(
          anchorRecordId: 'birth',
          relation: 'after',
          offset: 20,
          unit: 'year',
        ),
      ),
      timestamp: timestamp,
    );

    expect(
      await timeline.ageAt(birthEventId: 'birth', eventId: 'coronation'),
      20,
    );
    expect((await timeline.query.before('coronation')).single.id, 'birth');

    await expectLater(
      timeline.createEvent(
        const TimelineEventDraft(
          id: 'invalid',
          name: 'Invalid range',
          start: TimelineDate(
              calendarId: 'royal-calendar', year: 5, month: 1, day: 2),
          end: TimelineDate(
              calendarId: 'royal-calendar', year: 5, month: 1, day: 1),
        ),
      ),
      throwsA(isA<TimelineValidationException>()),
    );
  });

  test('shared connections and sparse branches preserve canonical events',
      () async {
    await timeline.createCalendar(_calendar(), timestamp: timestamp);
    final event = await timeline.createEvent(
      const TimelineEventDraft(
        id: 'war',
        name: 'The Great War',
        typeId: 'timeline-war',
        start: TimelineDate(calendarId: 'royal-calendar', year: 8),
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.records.createRecord(_record(
      id: 'mara',
      typeId: 'character',
      title: 'Mara',
      timestamp: timestamp,
    ));
    await timeline.connect(
      sourceId: event.id,
      targetId: 'mara',
      typeId: 'involves',
      timestamp: timestamp,
    );
    await timeline.branches.createBranch(StoryBranch(
      id: 'what-if',
      projectId: 'project-a',
      name: 'What If the War Was Lost',
      kind: BranchKind.whatIf,
      createdAt: timestamp,
    ));
    await timeline.overrideInBranch(
      'what-if',
      event.id,
      title: 'The Lost War',
      canonStatus: CanonStatus.alternate,
      timestamp: timestamp,
    );

    final canonical = await timeline.getTimelineRecord(event.id);
    final branch = await timeline.query.all(branchId: 'what-if');
    final involving = await timeline.query.involving('mara');
    final deletion = await timeline.analyzeDelete(event.id);

    expect(canonical?.title, 'The Great War');
    expect(branch.single.title, 'The Lost War');
    expect(involving.single.id, event.id);
    expect(deletion?.incomingConnections.length ?? 0, greaterThanOrEqualTo(0));
    expect(deletion?.outgoingConnections, isNotEmpty);
  });

  test(
      'cross-system fixture supports hierarchy integrations and scoped queries',
      () async {
    await TimelineDomainFixture(timeline).seed();

    final canonical = await timeline.query.all(canonStatus: CanonStatus.canon);
    final bookEvents = await timeline.query.all(bookId: 'book-one');
    final wars = await timeline.query.all(typeId: 'timeline-war');
    final secrets = await timeline.query.all(tag: 'Secret');
    final maraEvents = await timeline.query.involving('character-mara');
    final warLinks = await timeline.connectionsFor('event-war');
    final inspection = await timeline.inspectTimelineRecord('event-betrayal');
    final branch = await timeline.query.all(branchId: 'branch-crown-falls');
    final cycles = await timeline.validateDependencyCycles();

    expect(canonical.map((record) => record.id), contains('timeline-main'));
    expect(bookEvents.map((record) => record.id),
        containsAll(['event-war', 'event-betrayal']));
    expect(wars.single.id, 'event-war');
    expect(secrets.single.id, 'event-betrayal');
    expect(maraEvents.map((record) => record.id),
        containsAll(['event-war', 'event-birth']));
    expect(
      warLinks.map((link) => link.typeId),
      containsAll(['contains', 'occursAt', 'involves', 'relatedTo']),
    );
    expect(inspection?.references, isNotEmpty);
    expect(branch.map((record) => record.id), contains('event-crown-falls'));
    expect(
        branch
            .singleWhere((record) => record.id == 'event-crown-falls')
            .canonStatus,
        CanonStatus.alternate);
    expect(cycles, isEmpty);
  });

  test('multiple calendars remain representations of one event', () async {
    await timeline.createCalendar(_calendar(), timestamp: timestamp);
    await timeline.createCalendar(
      const TimelineCalendar(
        id: 'temple-calendar',
        name: 'Temple Calendar',
        months: [TimelineCalendarMonth(name: 'Vigil', length: 90)],
      ),
      timestamp: timestamp,
    );
    final event = await timeline.createEvent(
      const TimelineEventDraft(
        id: 'eclipse-festival',
        name: 'Eclipse Festival',
        start: TimelineDate(
            calendarId: 'royal-calendar', year: 3, month: 1, day: 1),
        dateRepresentations: [
          TimelineDate(
              calendarId: 'temple-calendar', year: 3, month: 1, day: 31),
        ],
      ),
      timestamp: timestamp,
    );

    expect(await timeline.query.all(), hasLength(1));
    expect(event.fields['dateRepresentations'], hasLength(1));
  });

  test('archive round trip and project isolation preserve timeline records',
      () async {
    await TimelineDomainFixture(timeline).seed();
    final other =
        TimelineService(projectId: 'project-b', repository: repository);
    await other.createCalendar(
      const TimelineCalendar(
        id: 'other-calendar',
        name: 'Other Calendar',
        months: [TimelineCalendarMonth(name: 'Only', length: 10)],
      ),
      timestamp: timestamp,
    );
    await other.createEvent(
      const TimelineEventDraft(id: 'other-event', name: 'Other Event'),
      timestamp: timestamp,
    );

    final snapshot = await repository.snapshot();
    const archive = AuthorOsArchiveService();
    final bytes = archive.exportSnapshot(
      snapshot,
      archiveId: 'timeline-archive',
      rootId: 'project-a',
      applicationVersion: '1.0.0',
      platform: 'windows',
      createdAt: timestamp,
    );
    final restored = archive.importSnapshot(bytes);

    expect((await timeline.query.all()).map((record) => record.id),
        isNot(contains('other-event')));
    expect((await other.query.all()).single.id, 'other-event');
    expect(restored.records.map((record) => record.id),
        containsAll(['event-war', 'event-betrayal', 'other-event']));
    expect(restored.links, isNotEmpty);
    expect(restored.branchRecordOverlays.single.recordId, 'event-crown-falls');
  });

  test('circular temporal dependencies are reported', () async {
    await timeline.createEvent(
      const TimelineEventDraft(id: 'event-a', name: 'Event A'),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(id: 'event-b', name: 'Event B'),
      timestamp: timestamp,
    );
    await timeline.connect(
      sourceId: 'event-a',
      targetId: 'event-b',
      typeId: 'before',
      timestamp: timestamp,
    );
    await timeline.connect(
      sourceId: 'event-b',
      targetId: 'event-a',
      typeId: 'before',
      timestamp: timestamp,
    );

    expect(
      (await timeline.validateDependencyCycles()).single.code,
      'circular-temporal-dependency',
    );
  });
}

TimelineCalendar _calendar() => const TimelineCalendar(
      id: 'royal-calendar',
      name: 'Royal Calendar',
      months: [
        TimelineCalendarMonth(name: 'Dawn', length: 30),
        TimelineCalendarMonth(name: 'Crown', length: 30),
        TimelineCalendarMonth(name: 'Harvest', length: 30),
      ],
      weekDays: ['Firstday', 'Secondday', 'Thirdday'],
      eraNames: ['Before Crown', 'Crowned Age'],
      epoch: {'eventId': 'founding'},
      conversionMetadata: {'ordinalEpoch': 0},
    );

AuthorRecord _record({
  required String id,
  required String typeId,
  required String title,
  required DateTime timestamp,
}) =>
    AuthorRecord(
      id: id,
      typeId: typeId,
      scopeType: RecordScopeType.project,
      scopeId: 'project-a',
      projectId: 'project-a',
      title: title,
      fields: {'name': title, 'identity.fullName': title},
      createdAt: timestamp,
      updatedAt: timestamp,
    );
