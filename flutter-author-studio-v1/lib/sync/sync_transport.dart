/// Sync — the transport boundary.
///
/// Everything the sync engine needs from the network, behind one interface:
/// push a record up, pull records down, and say whether either is possible
/// right now.
///
/// It exists because [AppSupabase] is a set of static methods whose
/// `hasCredentials` is always false under test. That meant the upload path had
/// never been exercised by a single test, and a download path would have been
/// born the same way. With the seam, an in-memory fake covers both.
///
/// The interface deliberately speaks in rows rather than domain objects: what
/// crosses the wire is `sync_records`, and the engine is what knows how to turn
/// a row into a goal, a series or a project.
library;

import '../supabase_service.dart';

/// One row of `sync_records` as it comes back from the server.
class RemoteSyncRecord {
  const RemoteSyncRecord({
    required this.recordType,
    required this.recordId,
    required this.action,
    required this.baseRevision,
    required this.revision,
    required this.payload,
    required this.updatedAt,
    this.deviceId,
  });

  final String recordType;
  final String recordId;

  /// `upsert` or `delete`. The server constrains it to those two.
  final String action;

  final int baseRevision;
  final int revision;
  final Map<String, dynamic> payload;

  /// The server's own `updated_at`, which is what the cursor advances on.
  final DateTime updatedAt;

  /// The device that wrote the row, when it said. Used to recognise our own
  /// writes coming back to us.
  final String? deviceId;

  bool get isDelete => action == 'delete';

  /// Reads a row as Supabase returns it. Lenient in the same way
  /// `SyncOperation.fromJson` is: a row missing a field is defaulted rather
  /// than thrown away, because a row written by a newer client should still be
  /// legible to an older one.
  factory RemoteSyncRecord.fromRow(Map<String, dynamic> row) {
    int nonNegative(Object? value) {
      final parsed = value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
      return parsed < 0 ? 0 : parsed;
    }

    final updatedAt = row['updated_at'];
    return RemoteSyncRecord(
      recordType: (row['record_type'] as String?) ?? '',
      recordId: (row['record_id'] as String?) ?? '',
      action: (row['action'] as String?) ?? 'upsert',
      baseRevision: nonNegative(row['base_revision']),
      revision: nonNegative(row['revision']),
      payload: row['payload'] is Map
          ? Map<String, dynamic>.from(row['payload'] as Map)
          : const {},
      updatedAt: updatedAt is String
          ? DateTime.parse(updatedAt).toUtc()
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deviceId: row['device_id'] as String?,
    );
  }
}

/// How the sync engine reaches the server.
abstract class SyncTransport {
  const SyncTransport();

  /// Whether syncing is possible at all — configured, and signed in.
  ///
  /// The engine checks this before doing anything, including anything that
  /// would write locally. An app that is signed out must not so much as mint a
  /// device id in the course of "syncing".
  bool get isAvailable;

  /// Sends one record up.
  Future<void> push({
    required String recordType,
    required String recordId,
    required String action,
    required int baseRevision,
    required int revision,
    required Map<String, dynamic> payload,
    required String deviceId,
  });

  /// Records changed at or after [since], oldest first.
  ///
  /// At-or-after rather than strictly after: see the cursor note in
  /// [SyncEngine.pull]. Applying a record twice is a no-op, so overlapping by
  /// one row is cheaper than the alternative, which is losing one.
  Future<List<RemoteSyncRecord>> pull({DateTime? since, int limit = 500});
}

/// The real transport, over Supabase.
class SupabaseSyncTransport extends SyncTransport {
  const SupabaseSyncTransport();

  @override
  bool get isAvailable => AppSupabase.hasCredentials && AppSupabase.isSignedIn;

  @override
  Future<void> push({
    required String recordType,
    required String recordId,
    required String action,
    required int baseRevision,
    required int revision,
    required Map<String, dynamic> payload,
    required String deviceId,
  }) =>
      AppSupabase.saveSyncRecord(
        recordType: recordType,
        recordId: recordId,
        action: action,
        baseRevision: baseRevision,
        revision: revision,
        payload: payload,
        deviceId: deviceId,
      );

  @override
  Future<List<RemoteSyncRecord>> pull({
    DateTime? since,
    int limit = 500,
  }) async {
    final rows = await AppSupabase.loadSyncRecords(since: since, limit: limit);
    return rows.map(RemoteSyncRecord.fromRow).toList();
  }
}
