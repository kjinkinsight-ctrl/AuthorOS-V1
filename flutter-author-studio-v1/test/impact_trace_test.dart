import 'package:author_studio_v1/impact_trace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const entities = [
    TraceEntity(id: 'scene:1', label: 'Opening', type: TraceEntityType.scene),
    TraceEntity(id: 'scene:2', label: 'Council', type: TraceEntityType.scene),
    TraceEntity(
        id: 'character:mara', label: 'Mara', type: TraceEntityType.character),
    TraceEntity(
        id: 'character:jon', label: 'Jon', type: TraceEntityType.character),
    TraceEntity(
        id: 'plotline:main',
        label: 'Main Plot',
        type: TraceEntityType.plotline),
    TraceEntity(id: 'note:1', label: 'Harbor clue', type: TraceEntityType.note),
    TraceEntity(
        id: 'beat:1',
        label: 'Inciting incident',
        type: TraceEntityType.plotBeat),
  ];
  const links = [
    TraceLink(
        sourceId: 'scene:1', targetId: 'character:mara', label: 'features'),
    TraceLink(
        sourceId: 'scene:1', targetId: 'character:jon', label: 'features'),
    TraceLink(
        sourceId: 'scene:1', targetId: 'plotline:main', label: 'advances'),
    TraceLink(sourceId: 'scene:1', targetId: 'note:1', label: 'references'),
    TraceLink(sourceId: 'scene:1', targetId: 'beat:1', label: 'fulfills'),
    TraceLink(
        sourceId: 'scene:2', targetId: 'character:mara', label: 'features'),
    TraceLink(
        sourceId: 'scene:2', targetId: 'character:jon', label: 'features'),
  ];

  test('impact trace follows linked entities to depth two', () {
    final result = const ImpactTraceAnalyzer().trace(
      sourceId: 'scene:1',
      entities: entities,
      links: links,
    );

    expect(
        result.affected.map((entity) => entity.label),
        containsAll([
          'Mara',
          'Jon',
          'Main Plot',
          'Harbor clue',
          'Inciting incident',
          'Council',
        ]));
  });

  test('relationship view counts shared character scenes', () {
    final relationships = const ImpactTraceAnalyzer()
        .characterRelationships(entities: entities, links: links);

    expect(relationships, hasLength(1));
    expect(relationships.single.firstCharacter, 'Mara');
    expect(relationships.single.secondCharacter, 'Jon');
    expect(relationships.single.sharedSceneCount, 2);
  });

  testWidgets('impact panel surfaces every linked entity type', (tester) async {
    final result = const ImpactTraceAnalyzer().trace(
      sourceId: 'scene:1',
      entities: entities,
      links: links,
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
          body: SingleChildScrollView(child: ImpactTracePanel(result: result))),
    ));

    expect(find.byKey(const Key('impact-group-note')), findsOneWidget);
    expect(find.byKey(const Key('impact-group-plotBeat')), findsOneWidget);
    expect(find.textContaining('Mara ↔ Jon'), findsOneWidget);
  });
}
