import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/sync/project_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = StarterProjectSyncAdapter();

  test('Flutter project sync preserves payload sections it does not render', () {
    final project = NovelStarterKit.create(
      title: 'Glass Harbor',
      genre: 'Fantasy',
      projectType: 'Novel',
      wordGoal: 90000,
    );
    final envelope = adapter.toEnvelope(
      project,
      deviceId: 'device-1',
      revision: 4,
      baseRevision: 3,
      updatedAt: DateTime.utc(2026, 8, 11),
      sourcePayload: const {
        'futureClientField': {'retained': true},
        'story': {
          'timeline': [
            {'id': 'event-1', 'title': 'Arrival'}
          ],
        },
      },
    );
    final decoded = adapter.fromEnvelope(envelope);
    final reencoded = adapter.toEnvelope(
      decoded.project,
      deviceId: 'device-1',
      revision: 5,
      baseRevision: 4,
      updatedAt: DateTime.utc(2026, 8, 12),
      sourcePayload: decoded.sourcePayload,
    );

    expect(reencoded.payload['futureClientField'], {'retained': true});
    expect(
      (reencoded.payload['story'] as Map)['timeline'],
      [
        {'id': 'event-1', 'title': 'Arrival'}
      ],
    );
    expect(decoded.project.title, 'Glass Harbor');
  });

  test('envelope round trip retains fields from a newer schema', () {
    final envelope = ProjectSyncEnvelope.fromJson({
      'recordId': 'project-1',
      'recordType': 'project',
      'schemaVersion': 2,
      'revision': 2,
      'baseRevision': 1,
      'deviceId': 'device-1',
      'updatedAt': '2026-08-11T00:00:00.000Z',
      'deletedAt': null,
      'payload': {
        'id': 'project-1',
        'name': 'Novel',
        'type': 'Novel',
        'genre': 'Fantasy',
        'targetWordCount': 80000,
      },
      'extensions': {'source': 'web'},
      'futureEnvelopeField': {'retained': true},
    });

    expect(envelope.toJson()['futureEnvelopeField'], {'retained': true});
    expect(envelope.schemaVersion, 2);
  });

  test('deleted envelopes cannot restore a Flutter project', () {
    final envelope = ProjectSyncEnvelope(
      recordId: 'project-1',
      revision: 1,
      baseRevision: 0,
      deviceId: 'device-1',
      updatedAt: DateTime.utc(2026, 8, 11),
      deletedAt: DateTime.utc(2026, 8, 11),
      payload: const {},
    );

    expect(
      () => adapter.fromEnvelope(envelope),
      throwsA(isA<FormatException>()),
    );
  });
}