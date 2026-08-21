import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/timeline_record_types.dart';
import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/persistence/authoros_database.dart';
import 'package:author_studio_v1/timeline_domain.dart';
import 'package:author_studio_v1/timeline_service.dart';
import 'package:author_studio_v1/timeline_studio_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  StarterProject project(String id) => StarterProject(
        id: id,
        title: 'Timeline Studio Test',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 50000,
        acts: const ['Act I'],
        chapters: const [
          StarterChapter(title: 'Chapter 1', prompt: 'Begin'),
        ],
        characterSheets: const [
          StarterCharacterSheet(name: 'Mara', role: 'Protagonist'),
        ],
        beatChecklist: const ['Opening Image'],
        firstSceneTitle: 'Opening Scene',
      );

  testWidgets('timeline studio shows empty state', (tester) async {
    final testProject = project('timeline-empty');

    await tester.pumpWidget(
      MaterialApp(
        home: TimelineStudioView(project: testProject),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Timeline Studio'), findsOneWidget);
    expect(find.text('Your story has no events yet.'), findsOneWidget);
    expect(find.text('Create Event'), findsWidgets);
  });

  testWidgets('timeline studio shows project events in chronological order',
      (tester) async {
    final testProject = project('timeline-populated');
    final service = TimelineService(
      projectId: testProject.id,
      repository: authorOsRepository,
    );

    await service.createEvent(
      TimelineEventDraft(
        id: 'timeline-event-1',
        name: 'Battle of Dawn',
        summary: 'The first major battle begins.',
        typeId: TimelineRecordTypes.eventTypeId,
        start: const TimelineDate(
          calendarId: 'default-calendar',
          year: 12,
          month: 3,
          day: 14,
        ),
      ),
    );
    await service.createEvent(
      TimelineEventDraft(
        id: 'timeline-event-2',
        name: 'Council at Sunset',
        summary: 'The council reaches a dangerous compromise.',
        typeId: TimelineRecordTypes.eventTypeId,
        start: const TimelineDate(
          calendarId: 'default-calendar',
          year: 13,
          month: 1,
          day: 2,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TimelineStudioView(project: testProject, service: service),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Battle of Dawn'), findsOneWidget);
    expect(find.text('Council at Sunset'), findsOneWidget);
    expect(find.byTooltip('Event actions'), findsNWidgets(2));
  });

  testWidgets('timeline studio exposes edit and delete actions',
      (tester) async {
    final testProject = project('timeline-actions');
    final service = TimelineService(
      projectId: testProject.id,
      repository: authorOsRepository,
    );

    await service.createEvent(
      TimelineEventDraft(
        id: 'timeline-event-actions',
        name: 'Final Assembly',
        summary: 'A final gathering decides the fate of the kingdom.',
        typeId: TimelineRecordTypes.eventTypeId,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TimelineStudioView(project: testProject, service: service),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Event actions').first);
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
