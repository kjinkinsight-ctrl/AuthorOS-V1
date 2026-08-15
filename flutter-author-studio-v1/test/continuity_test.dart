import 'package:author_studio_v1/continuity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = ContinuityAnalyzer();

  test('detects missing POV character presence in timeline order', () {
    final warnings = analyzer.analyze(const [
      ContinuityEventSnapshot(
        id: 'scene-1',
        title: 'The Discovery',
        startDay: 1,
        endDay: 1,
        order: 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Jon'],
      ),
    ]);

    expect(
      warnings.map((warning) => warning.type),
      contains(ContinuityWarningType.missingPovPresence),
    );
  });

  test('detects character presence outside the project roster', () {
    final warnings = analyzer.analyze(
      const [
        ContinuityEventSnapshot(
          id: 'scene-1',
          title: 'Unexpected Visitor',
          startDay: 1,
          endDay: 1,
          order: 1,
          pov: 'Mara',
          plotline: 'Main Plot',
          presentCharacters: ['Mara', 'Removed Character'],
        ),
      ],
      knownCharacters: const ['Mara'],
    );

    expect(
      warnings.map((warning) => warning.type),
      contains(ContinuityWarningType.unknownCharacter),
    );
  });

  test('detects overlapping character presence across plotlines', () {
    final warnings = analyzer.analyze(const [
      ContinuityEventSnapshot(
        id: 'scene-1',
        title: 'The Chase',
        startDay: 3,
        endDay: 4,
        order: 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Mara'],
      ),
      ContinuityEventSnapshot(
        id: 'scene-2',
        title: 'The Council',
        startDay: 4,
        endDay: 5,
        order: 2,
        pov: 'Mara',
        plotline: 'Political Plot',
        presentCharacters: ['Mara'],
      ),
    ]);

    expect(
      warnings.map((warning) => warning.type),
      contains(ContinuityWarningType.characterOverlap),
    );
  });

  test('detects impossible ranges and backward manual sequence', () {
    final warnings = analyzer.analyze(const [
      ContinuityEventSnapshot(
        id: 'scene-1',
        title: 'Later Event',
        startDay: 8,
        endDay: 8,
        order: 1,
        pov: '',
        plotline: 'Main Plot',
        presentCharacters: [],
      ),
      ContinuityEventSnapshot(
        id: 'scene-2',
        title: 'Broken Event',
        startDay: 5,
        endDay: 2,
        order: 2,
        pov: '',
        plotline: 'Main Plot',
        presentCharacters: [],
      ),
    ]);

    expect(
      warnings.map((warning) => warning.type),
      containsAll([
        ContinuityWarningType.invalidRange,
        ContinuityWarningType.impossibleSequence,
      ]),
    );
  });

  test('detects impossible travel between character appearances', () {
    final warnings = analyzer.analyze(const [
      ContinuityEventSnapshot(
        id: 'scene-1',
        title: 'Harbor Departure',
        startDay: 2,
        endDay: 2,
        order: 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Mara'],
        location: 'North Harbor',
      ),
      ContinuityEventSnapshot(
        id: 'scene-2',
        title: 'Capital Council',
        startDay: 3,
        endDay: 3,
        order: 2,
        pov: 'Mara',
        plotline: 'Political Plot',
        presentCharacters: ['Mara'],
        location: 'The Capital',
        travelDaysFromPrevious: 3,
      ),
    ]);

    expect(
      warnings.map((warning) => warning.type),
      contains(ContinuityWarningType.impossibleTravel),
    );
  });

  test('allows location changes when enough travel time exists', () {
    final warnings = analyzer.analyze(const [
      ContinuityEventSnapshot(
        id: 'scene-1',
        title: 'Harbor Departure',
        startDay: 2,
        endDay: 2,
        order: 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Mara'],
        location: 'North Harbor',
      ),
      ContinuityEventSnapshot(
        id: 'scene-2',
        title: 'Capital Council',
        startDay: 6,
        endDay: 6,
        order: 2,
        pov: 'Mara',
        plotline: 'Political Plot',
        presentCharacters: ['Mara'],
        location: 'The Capital',
        travelDaysFromPrevious: 3,
      ),
    ]);

    expect(
      warnings.map((warning) => warning.type),
      isNot(contains(ContinuityWarningType.impossibleTravel)),
    );
  });

  testWidgets('timeline lanes filter by POV and plotline', (tester) async {
    const events = [
      ContinuityEventSnapshot(
        id: 'scene-1',
        title: 'Opening',
        startDay: 1,
        endDay: 1,
        order: 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Mara'],
      ),
      ContinuityEventSnapshot(
        id: 'scene-2',
        title: 'Council',
        startDay: 2,
        endDay: 2,
        order: 2,
        pov: 'Jon',
        plotline: 'Political Plot',
        presentCharacters: ['Jon'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: ContinuityTimelinePanel(events: events, warnings: []),
          ),
        ),
      ),
    );

    expect(find.text('2 of 2 timeline events'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('continuity-pov-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mara').last);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 timeline events'), findsOneWidget);

    await tester.tap(find.text('By plotline'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timeline-lane-Main Plot')), findsOneWidget);
  });

  test('story integrity summary reflects warning severity and gives fixes', () {
    final warnings = const ContinuityAnalyzer().analyze(const [
      ContinuityEventSnapshot(
        id: 'scene-1',
        title: 'The Discovery',
        startDay: 1,
        endDay: 1,
        order: 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Jon'],
      ),
      ContinuityEventSnapshot(
        id: 'scene-2',
        title: 'Broken Event',
        startDay: 5,
        endDay: 2,
        order: 2,
        pov: 'Jon',
        plotline: 'Main Plot',
        presentCharacters: ['Jon'],
      ),
    ]);

    final summary = ContinuityAnalyzer.summaryFor(warnings);

    expect(summary.score, lessThan(100));
    expect(summary.criticalCount, greaterThanOrEqualTo(1));
    expect(
        summary.issues.any((issue) => issue.recommendation.isNotEmpty), isTrue);
    expect(summary.issues.first.recommendation, isNotEmpty);
  });

  testWidgets('large timelines render incrementally', (tester) async {
    final events = List.generate(
      45,
      (index) => ContinuityEventSnapshot(
        id: 'scene-$index',
        title: 'Scene $index',
        startDay: index + 1,
        endDay: index + 1,
        order: index + 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: const ['Mara'],
      ),
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContinuityTimelinePanel(events: events, warnings: const []),
        ),
      ),
    ));

    expect(
        find.byKey(const Key('timeline-lane-event-scene-19')), findsOneWidget);
    expect(find.byKey(const Key('timeline-lane-event-scene-20')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const Key('load-more-timeline-events')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('load-more-timeline-events')));
    await tester.pump();
    expect(
        find.byKey(const Key('timeline-lane-event-scene-20')), findsOneWidget);
  });

  testWidgets('layered timeline scales ranges and supports zoom and selection',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selectedEventId;
    const events = [
      ContinuityEventSnapshot(
        id: 'opening',
        title: 'Opening',
        startDay: 1,
        endDay: 1,
        order: 1,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Mara'],
        dateLabel: 'First Dawn',
        type: 'Plot',
      ),
      ContinuityEventSnapshot(
        id: 'journey',
        title: 'Long Journey',
        startDay: 3,
        endDay: 5,
        order: 2,
        pov: 'Mara',
        plotline: 'Main Plot',
        presentCharacters: ['Mara'],
        type: 'World',
      ),
    ];
    const warnings = [
      ContinuityWarning(
        type: ContinuityWarningType.impossibleTravel,
        severity: ContinuitySeverity.critical,
        title: 'Impossible travel',
        message: 'Not enough time.',
        eventIds: ['journey'],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ContinuityTimelinePanel(
              events: events,
              warnings: warnings,
              selectedEventId: 'opening',
              onEventSelected: (eventId) => selectedEventId = eventId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day 0 to 6'), findsOneWidget);
    expect(find.byKey(const Key('timeline-event-warning')), findsOneWidget);
    expect(find.text('52 px/day'), findsOneWidget);

    final opening = find.byKey(const Key('timeline-lane-event-opening'));
    final journey = find.byKey(const Key('timeline-lane-event-journey'));
    expect(tester.getSize(opening).width, 46);
    expect(tester.getSize(journey).width, 150);
    expect(tester.getTopLeft(journey).dx - tester.getTopLeft(opening).dx, 104);

    await tester.tap(journey);
    expect(selectedEventId, 'journey');

    await tester.tap(find.byKey(const Key('timeline-zoom-in')));
    await tester.pump();
    expect(find.text('76 px/day'), findsOneWidget);
    expect(tester.getSize(journey).width, 222);

    await tester.tap(find.byKey(const Key('timeline-fit-events')));
    await tester.pump();
    expect(find.text('32 px/day'), findsOneWidget);
  });

  testWidgets('layered timeline handles negative and single-day ranges',
      (tester) async {
    const events = [
      ContinuityEventSnapshot(
        id: 'prologue',
        title: 'Prologue',
        startDay: -3,
        endDay: -3,
        order: 1,
        pov: '',
        plotline: 'History',
        presentCharacters: [],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(
          body: ContinuityTimelinePanel(events: events, warnings: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day -4 to -2'), findsOneWidget);
    expect(
      find.byKey(const Key('timeline-lane-event-prologue')),
      findsOneWidget,
    );
  });
}
