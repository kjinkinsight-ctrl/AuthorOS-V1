import 'package:flutter/foundation.dart';

import '../onboarding.dart';
import '../supabase_service.dart';
import 'project_sync.dart';
import 'sync_store.dart';

/// Bridges local project saves to the `sync_records` table.
///
/// Every save is queued locally first, so a save made while offline or
/// signed out survives and is uploaded by the next flush. A queued
/// operation is only acknowledged once Supabase has accepted it.
class ProjectSyncService {
  const ProjectSyncService({
    SyncStore store = const SyncStore(),
    StarterProjectSyncAdapter adapter = const StarterProjectSyncAdapter(),
  })  : _store = store,
        _adapter = adapter;

  static const String recordType = 'project';

  final SyncStore _store;
  final StarterProjectSyncAdapter _adapter;

  /// Queues [project] as the next revision and pushes it when possible.
  Future<void> recordProjectSaved(StarterProject project) async {
    final baseRevision = await _store.loadRevision(recordType, project.id);
    final envelope = _adapter.toEnvelope(
      project,
      deviceId: await _store.getOrCreateDeviceId(),
      revision: baseRevision + 1,
      baseRevision: baseRevision,
      updatedAt: DateTime.now().toUtc(),
    );

    await _store.enqueue(
      recordType: recordType,
      recordId: project.id,
      action: 'upsert',
      baseRevision: baseRevision,
      // The whole envelope is stored so a flush can replay the exact
      // revision that was queued, even across app restarts.
      payload: envelope.toJson(),
    );

    await flushQueue();
  }

  /// Uploads every queued operation. Failures stay queued for the next call.
  Future<void> flushQueue() async {
    if (!AppSupabase.hasCredentials || !AppSupabase.isSignedIn) {
      return;
    }

    for (final operation in await _store.loadQueue()) {
      final ProjectSyncEnvelope envelope;
      try {
        envelope = ProjectSyncEnvelope.fromJson(operation.payload);
      } on FormatException catch (error) {
        // A malformed entry can never succeed; drop it rather than
        // blocking every later operation behind it.
        debugPrint('Discarding unreadable sync operation: $error');
        await _store.acknowledge(operation.operationId);
        continue;
      }

      try {
        await AppSupabase.saveSyncRecord(
          recordType: envelope.recordType,
          recordId: envelope.recordId,
          action: operation.action,
          baseRevision: envelope.baseRevision,
          revision: envelope.revision,
          payload: envelope.toJson(),
          deviceId: envelope.deviceId,
        );
      } catch (error) {
        debugPrint('Sync upload failed, leaving operation queued: $error');
        continue;
      }

      await _store.acknowledge(operation.operationId);
      await _store.saveRevision(
        envelope.recordType,
        envelope.recordId,
        envelope.revision,
      );
    }
  }
}
