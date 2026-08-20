import 'package:author_studio_v1/core/branch_domain.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:author_studio_v1/timeline_service.dart';

class TimelineDomainFixture {
  TimelineDomainFixture(this.timeline);

  final TimelineService timeline;
  final timestamp = DateTime.utc(2026, 8, 20);

  Future<void> seed() async {
    await timeline.createCalendar(
      const TimelineCalendar(
        id: 'calendar-crown',
        name: 'Crown Calendar',
        months: [
          TimelineCalendarMonth(name: 'Ember', length: 30),
          TimelineCalendarMonth(name: 'Rain', length: 30),
          TimelineCalendarMonth(name: 'Bloom', length: 30),
          TimelineCalendarMonth(name: 'Sun', length: 30),
        ],
        weekDays: ['Firstday', 'Secondday', 'Thirdday', 'Fourthday'],
        eraNames: ['Before Crown', 'Crowned Age'],
        conversionMetadata: {'epochOrdinal': 0},
      ),
      primary: true,
      timestamp: timestamp,
    );

    for (final record in [
      _record('series-ashes', 'series', 'The Ashes Cycle'),
      _record('book-one', 'book', 'A Crown of Ash',
          seriesId: 'series-ashes', bookId: 'book-one'),
      _record('character-mara', 'character', 'Mara Vale'),
      _record('character-cassian', 'character', 'Cassian Rook'),
      _record('location-endovier', 'city', 'Endovier'),
      _record('location-harbor', 'location', 'Ashfall Harbor'),
      _record('faction-crown', 'faction', 'The Crown'),
      _record('codex-tradition', 'custom-tradition', 'First Bell Rite'),
      _record('codex-government', 'political-system', 'Crown Council'),
      _record('chapter-one', 'chapter', 'Chapter One',
          seriesId: 'series-ashes', bookId: 'book-one'),
      _record('chapter-four', 'chapter', 'Chapter Four',
          seriesId: 'series-ashes', bookId: 'book-one'),
      _record('scene-opening', 'scene', 'The First Bell',
          seriesId: 'series-ashes', bookId: 'book-one'),
      _record('scene-flashback', 'scene', 'Memory of Fire',
          seriesId: 'series-ashes', bookId: 'book-one'),
    ]) {
      await timeline.records.createRecord(record);
    }

    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'timeline-main',
        name: 'Crowned Age Timeline',
        typeId: 'timeline',
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'era-founding',
        name: 'Age of Founding',
        typeId: 'timeline-era',
        start: TimelineDate(calendarId: 'calendar-crown', year: 1),
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'era-war',
        name: 'The War Years',
        typeId: 'timeline-era',
        start: TimelineDate(calendarId: 'calendar-crown', year: 18),
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'event-founding',
        name: 'Founding of Endovier',
        typeId: 'timeline-founding',
        summary: 'The settlement becomes the first Crown city.',
        start: TimelineDate(
            calendarId: 'calendar-crown', year: 1, month: 1, day: 1),
        importance: 'major',
        tags: ['Historical', 'Political'],
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'event-war',
        name: 'The Ash War',
        typeId: 'timeline-war',
        summary: 'The Crown and the harbor rebels fight for Endovier.',
        start: TimelineDate(
            calendarId: 'calendar-crown', year: 18, month: 1, day: 1),
        end: TimelineDate(
            calendarId: 'calendar-crown', year: 20, month: 4, day: 30),
        importance: 'critical',
        tags: ['War', 'World', 'Political'],
        seriesId: 'series-ashes',
        bookId: 'book-one',
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'event-betrayal',
        name: 'The Harbor Betrayal',
        typeId: 'timeline-turning-point',
        start: TimelineDate(
            calendarId: 'calendar-crown', year: 20, month: 2, day: 12),
        relativeDate: RelativeTimelineDate(
          anchorRecordId: 'event-war',
          relation: 'during',
          description: 'During the final year of the Ash War',
        ),
        narrativeTime: {
          'mode': 'flashback',
          'revealedInRecordId': 'chapter-four',
          'readerOrder': 4,
        },
        importance: 'critical',
        tags: ['Secret', 'Revelation'],
        seriesId: 'series-ashes',
        bookId: 'book-one',
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );
    await timeline.createEvent(
      const TimelineEventDraft(
        id: 'event-birth',
        name: 'Mara is born',
        typeId: 'timeline-birth',
        start: TimelineDate(
            calendarId: 'calendar-crown', year: 2, month: 3, day: 3),
        canonStatus: CanonStatus.canon,
      ),
      timestamp: timestamp,
    );

    for (final link in [
      ('timeline-main', 'era-founding', 'contains'),
      ('timeline-main', 'era-war', 'contains'),
      ('era-founding', 'event-founding', 'contains'),
      ('era-war', 'event-war', 'contains'),
      ('event-war', 'event-betrayal', 'contains'),
      ('event-founding', 'location-endovier', 'occursAt'),
      ('event-founding', 'codex-tradition', 'established'),
      ('event-founding', 'codex-government', 'created'),
      ('event-war', 'location-harbor', 'occursAt'),
      ('event-war', 'faction-crown', 'involves'),
      ('event-war', 'character-mara', 'involves'),
      ('event-betrayal', 'character-cassian', 'involves'),
      ('event-betrayal', 'chapter-four', 'revealedIn'),
      ('event-betrayal', 'scene-flashback', 'depictedIn'),
      ('scene-flashback', 'event-betrayal', 'occursDuring'),
      ('event-birth', 'character-mara', 'involves'),
      ('event-war', 'book-one', 'relatedTo'),
      ('event-founding', 'event-war', 'precedes'),
      ('event-betrayal', 'event-war', 'during'),
    ]) {
      await timeline.connect(
        sourceId: link.$1,
        targetId: link.$2,
        typeId: link.$3,
        direction: link.$3 == 'relatedTo'
            ? RecordLinkDirection.undirected
            : RecordLinkDirection.directed,
        timestamp: timestamp,
      );
    }

    await timeline.branches.createBranch(StoryBranch(
      id: 'branch-crown-falls',
      projectId: timeline.projectId,
      name: 'What If the Crown Falls',
      kind: BranchKind.whatIf,
      createdAt: timestamp,
    ));
    await timeline.branches.createRecord(
      'branch-crown-falls',
      AuthorRecord(
        id: 'event-crown-falls',
        typeId: 'timeline-destruction',
        scopeType: RecordScopeType.branch,
        scopeId: 'branch-crown-falls',
        projectId: timeline.projectId,
        seriesId: 'series-ashes',
        bookId: 'book-one',
        branchId: 'branch-crown-falls',
        canonStatus: CanonStatus.alternate,
        title: 'The Crown Falls',
        fields: const {
          'name': 'The Crown Falls',
          'eventType': 'timeline-destruction',
          'start': [
            {
              'calendarId': 'calendar-crown',
              'year': 20,
              'month': 4,
              'day': 30,
              'precision': 'exact',
              'approximate': false,
            }
          ],
          'precision': 'exact',
          'importance': 'critical',
        },
        tags: const ['Alternate', 'Political'],
        createdAt: timestamp,
        updatedAt: timestamp,
        extensionData: const {'timelineStudio': true},
      ),
      timestamp: timestamp,
    );
  }

  AuthorRecord _record(
    String id,
    String typeId,
    String title, {
    String? seriesId,
    String? bookId,
  }) =>
      AuthorRecord(
        id: id,
        typeId: typeId,
        scopeType: RecordScopeType.project,
        scopeId: timeline.projectId,
        projectId: timeline.projectId,
        seriesId: seriesId,
        bookId: bookId,
        canonStatus: CanonStatus.canon,
        title: title,
        fields: {'name': title, 'identity.fullName': title},
        createdAt: timestamp,
        updatedAt: timestamp,
      );
}
