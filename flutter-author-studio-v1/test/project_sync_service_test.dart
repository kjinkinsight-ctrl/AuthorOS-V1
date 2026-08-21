import 'package:author_studio_v1/onboarding.dart';
import 'package:author_studio_v1/sync/project_sync.dart';
import 'package:author_studio_v1/sync/project_sync_service.dart';
import 'package:author_studio_v1/sync/sync_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const service = ProjectSyncService();
  const store = SyncStore();

  StarterProject buildProject() => NovelStarterKit.create(
        title: 'Glass Harbor',
        genre: 'Fantasy',
        projectType: 'Novel',
        wordGoal: 90000,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // Supabase is unconfigured under test, so these cover the offline path:
  // the save is queued locally and only cleared once an upload succeeds.
  test('a save is queued as an upsert envelope while signed out', () async {
    final project = buildProject();
    await service.recordProjectSaved(project);

    final queue = await store.loadQueue();
    expect(queue, hasLength(1));
    expect(queue.single.recordType, 'project');
    expect(queue.single.recordId, project.id);
    expect(queue.single.action, 'upsert');
    expect(queue.single.baseRevision, 0);

    final envelope = ProjectSyncEnvelope.fromJson(queue.single.payload);
    expect(envelope.recordId, project.id);
    expect(envelope.revision, 1);
    expect(envelope.baseRevision, 0);
    expect(envelope.deviceId, await store.getOrCreateDeviceId());
    expect(envelope.payload['name'], 'Glass Harbor');
  });

  test('an unacknowledged save does not advance the stored revision',
      () async {
    final project = buildProject();
    await service.recordProjectSaved(project);
    await service.recordProjectSaved(project);

    // enqueue collapses by record identity, so the queue stays one deep and
    // the revision cannot move until Supabase accepts the upload.
    final queue = await store.loadQueue();
    expect(queue, hasLength(1));
    expect(await store.loadRevision('project', project.id), 0);
    expect(
      ProjectSyncEnvelope.fromJson(queue.single.payload).revision,
      1,
    );
  });

  test('flushing while signed out leaves the queue intact', () async {
    final project = buildProject();
    await service.recordProjectSaved(project);
    await service.flushQueue();

    expect(await store.loadQueue(), hasLength(1));
    expect(await store.loadRevision('project', project.id), 0);
  });
}
