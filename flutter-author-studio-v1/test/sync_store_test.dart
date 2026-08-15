import 'package:author_studio_v1/sync/sync_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = SyncStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('device identity and acknowledged revision persist', () async {
    final deviceId = await store.getOrCreateDeviceId();
    await store.saveRevision('project', 'project-1', 7);

    expect(await store.getOrCreateDeviceId(), deviceId);
    expect(deviceId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(await store.loadRevision('project', 'project-1'), 7);
  });

  test('newer project operation replaces pending payload without changing id',
      () async {
    final first = await store.enqueue(
      recordType: 'project',
      recordId: 'project-1',
      action: 'upsert',
      baseRevision: 2,
      payload: const {'name': 'First'},
    );
    final replacement = await store.enqueue(
      recordType: 'project',
      recordId: 'project-1',
      action: 'delete',
      baseRevision: 2,
      payload: const {},
      deletedAt: DateTime.utc(2026, 8, 11),
    );

    final queue = await store.loadQueue();
    expect(queue, hasLength(1));
    expect(replacement.operationId, first.operationId);
    expect(replacement.enqueuedAt, first.enqueuedAt);
    expect(queue.single.action, 'delete');
  });

  test('acknowledgement removes only the accepted operation', () async {
    final first = await store.enqueue(
      recordType: 'project',
      recordId: 'project-1',
      action: 'upsert',
      baseRevision: 0,
      payload: const {},
    );
    await store.enqueue(
      recordType: 'project',
      recordId: 'project-2',
      action: 'upsert',
      baseRevision: 0,
      payload: const {},
    );

    expect(await store.acknowledge(first.operationId), isTrue);
    expect((await store.loadQueue()).single.recordId, 'project-2');
  });
}