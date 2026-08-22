/// Sync — the engine.
///
/// Drains the outbound queue and, for the first time in this app, applies what
/// other devices wrote. Until this existed the protocol was half-built: the
/// app pushed to `sync_records` and never read it back, `SyncStore`'s cursor
/// had no reader, and `base_revision` was written and never compared. A second
/// device saw nothing.
///
/// The engine is deliberately generic. It knows about rows, revisions and a
/// cursor; it knows nothing about goals, series or projects. What a record
/// *means* is a [SyncApplier]'s business, so adding a synced data set is a new
/// applier rather than a new engine.
///
/// Two rules govern it:
///
/// * **Nothing happens when the transport is unavailable** — not a push, not a
///   pull, and not so much as minting a device id. An app that is signed out
///   must not write anything in the course of "syncing".
/// * **Applying a record is idempotent.** That is what lets the cursor overlap
///   by a row rather than risk skipping one.
library;

import 'package:flutter/foundation.dart';

import 'project_sync.dart';
import 'sync_store.dart';
import 'sync_transport.dart';

/// Applies one record type's remote changes to local storage.
///
/// **An applier writes through the repository, never through a store.** The
/// stores enqueue an outbound operation on every write — that is how a local
/// change reaches the server — so an applier that called one would queue an
/// upload of the very change it had just received, and two devices would
/// ping-pong a record between them forever.
///
/// Going to the repository does not weaken the guarantees the stores make,
/// because those guarantees live in the repository methods themselves:
/// `deleteProjectRosterEntry` deletes one roster row and nothing else, and
/// `deleteSeries` releases a series' books in a transaction before removing
/// it. A deletion that arrived from another device is therefore exactly as
/// narrow as one made here.
abstract class SyncApplier {
  const SyncApplier();

  /// The `record_type` this applier answers for.
  String get recordType;

  Future<void> applyUpsert(ProjectSyncEnvelope envelope);

  /// Applies a tombstone. Removes exactly the record named and nothing else.
  Future<void> applyDelete(String recordId);
}

/// Fills in a record's payload immediately before it uploads.
///
/// The queue normally carries the payload it was given. For scenes that would
/// mean a second copy of the whole novel sitting in SharedPreferences — a
/// first sync of a six-hundred-scene manuscript would put every word of it in
/// the queue as well as in the manuscript.
///
/// So a scene queues a reference and resolves its prose here. The size saving
/// is the obvious benefit; the correctness one matters more: what uploads is
/// the scene as it stands at flush time, not a snapshot taken at whichever
/// moment the author last paused typing.
///
/// Returning `null` drops the operation — the record it referred to is gone.
abstract class SyncPayloadResolver {
  const SyncPayloadResolver();

  String get recordType;

  Future<Map<String, dynamic>?> resolve(String recordId);
}

/// What one run of the engine did. Returned rather than logged so a caller —
/// or a test — can see whether anything moved.
class SyncResult {
  const SyncResult({
    this.pushed = 0,
    this.pushFailures = 0,
    this.applied = 0,
    this.skipped = 0,
    this.unknownTypes = 0,
    this.ranOffline = false,
  });

  /// Operations successfully uploaded.
  final int pushed;

  /// Operations that failed to upload and remain queued for the next run.
  final int pushFailures;

  /// Remote records applied locally.
  final int applied;

  /// Remote records deliberately ignored: our own echo, or a revision we are
  /// already level with or ahead of.
  final int skipped;

  /// Remote records of a type this build has no applier for. Counted, not
  /// dropped — see [pull].
  final int unknownTypes;

  /// Whether the run did nothing because the transport was unavailable.
  final bool ranOffline;

  bool get didAnything => pushed > 0 || applied > 0;

  SyncResult merge(SyncResult other) => SyncResult(
        pushed: pushed + other.pushed,
        pushFailures: pushFailures + other.pushFailures,
        applied: applied + other.applied,
        skipped: skipped + other.skipped,
        unknownTypes: unknownTypes + other.unknownTypes,
        ranOffline: ranOffline || other.ranOffline,
      );

  @override
  String toString() => 'SyncResult(pushed $pushed, applied $applied, '
      'skipped $skipped, unknown $unknownTypes, failures $pushFailures'
      '${ranOffline ? ', offline' : ''})';
}

/// Moves records between the local queue and the server.
class SyncEngine {
  SyncEngine({
    SyncStore store = const SyncStore(),
    SyncTransport transport = const SupabaseSyncTransport(),
    List<SyncApplier> appliers = const [],
    List<SyncPayloadResolver> resolvers = const [],
  })  : _store = store,
        _transport = transport,
        _appliers = {
          for (final applier in appliers) applier.recordType: applier,
        },
        _resolvers = {
          for (final resolver in resolvers) resolver.recordType: resolver,
        };

  final SyncStore _store;
  final SyncTransport _transport;
  final Map<String, SyncApplier> _appliers;
  final Map<String, SyncPayloadResolver> _resolvers;

  /// How many records one pull will take at a time.
  static const pullPageSize = 500;

  /// Uploads everything queued, then applies everything new from the server.
  ///
  /// Push first: a record this device has just changed should reach the server
  /// before that same record is pulled back, so the revision check recognises
  /// the echo instead of applying our own change over ourselves.
  Future<SyncResult> sync() async {
    if (!_transport.isAvailable) {
      return const SyncResult(ranOffline: true);
    }
    final pushed = await flush();
    final pulled = await pull();
    return pushed.merge(pulled);
  }

  /// Drains the outbound queue.
  ///
  /// A failed upload leaves its operation queued and moves on, so one
  /// unreachable record cannot block every record behind it. An unreadable
  /// operation is dropped, because it can never succeed.
  Future<SyncResult> flush() async {
    if (!_transport.isAvailable) {
      return const SyncResult(ranOffline: true);
    }

    var pushed = 0;
    var failures = 0;
    final deviceId = await _store.getOrCreateDeviceId();

    for (final operation in await _store.loadQueue()) {
      final ProjectSyncEnvelope envelope;
      try {
        envelope = ProjectSyncEnvelope.fromJson(operation.payload);
      } on FormatException catch (error) {
        // Poison entry: it will never upload, so let it go rather than let it
        // hold up the queue forever.
        debugPrint('Discarding unreadable sync operation: $error');
        await _store.acknowledge(operation.operationId);
        continue;
      }

      // A record type that queues a reference fills in its real payload here,
      // so what uploads is current rather than whatever was true when the
      // author last paused.
      var outbound = envelope;
      final resolver = _resolvers[operation.recordType];
      if (resolver != null && operation.action != 'delete') {
        final resolved = await resolver.resolve(operation.recordId);
        if (resolved == null) {
          // Whatever this referred to no longer exists. Nothing to send, and
          // nothing gained by keeping the operation queued forever.
          await _store.acknowledge(operation.operationId);
          continue;
        }
        outbound = envelope.copyWithPayload(resolved);
      }

      try {
        await _transport.push(
          recordType: operation.recordType,
          recordId: operation.recordId,
          action: operation.action,
          baseRevision: outbound.baseRevision,
          revision: outbound.revision,
          payload: outbound.toJson(),
          deviceId: outbound.deviceId.isEmpty ? deviceId : outbound.deviceId,
        );
      } catch (error) {
        // Stays queued for the next run. No backoff here on purpose: the
        // triggers are already infrequent (start-up, sign-in, a save).
        debugPrint('Sync upload failed, leaving it queued: $error');
        failures++;
        continue;
      }

      await _store.acknowledge(operation.operationId);
      await _store.saveRevision(
        operation.recordType,
        operation.recordId,
        outbound.revision,
      );
      pushed++;
    }

    return SyncResult(pushed: pushed, pushFailures: failures);
  }

  /// Applies everything the server has that this device has not seen.
  ///
  /// The cursor is the server's own `updated_at`, and the query is
  /// at-or-after it rather than strictly after. Strictly after would silently
  /// skip a record sharing the cursor's exact instant; overlapping by one row
  /// costs nothing, because a record at or below the revision this device
  /// already holds is skipped anyway.
  Future<SyncResult> pull() async {
    if (!_transport.isAvailable) {
      return const SyncResult(ranOffline: true);
    }

    final cursor = await _readCursor();
    final records = await _transport.pull(
      since: cursor,
      limit: pullPageSize,
    );
    if (records.isEmpty) return const SyncResult();

    final deviceId = await _store.getOrCreateDeviceId();
    var applied = 0;
    var skipped = 0;
    var unknown = 0;
    DateTime? newestSeen;

    for (final record in records) {
      // Track the high-water mark across every record, including the ones
      // skipped: a record this device wrote, or already has, is still proof
      // that the server has nothing older left to give.
      if (newestSeen == null || record.updatedAt.isAfter(newestSeen)) {
        newestSeen = record.updatedAt;
      }

      if (record.recordId.isEmpty || record.recordType.isEmpty) {
        skipped++;
        continue;
      }

      // Our own write coming back to us. Checked before the revision guard
      // because the guard now applies on a tie, and a tie with ourselves is
      // just this device re-reading what it already pushed.
      if (record.deviceId != null && record.deviceId == deviceId) {
        skipped++;
        continue;
      }

      final local = await _store.loadRevision(
        record.recordType,
        record.recordId,
      );
      // Strictly older than what this device holds: never apply.
      if (record.revision < local) {
        skipped++;
        continue;
      }

      // A tie is applied rather than skipped, which looks wrong and is not.
      // Two devices offline at revision 5 both push 6; the server keeps
      // whichever landed last. Skip on a tie and the losing device keeps a
      // revision 6 that no one else will ever hold — the two diverge
      // permanently and silently. Apply on a tie and both converge on what the
      // server has. The losing edit is still lost, but consistently, rather
      // than lingering as a phantom local truth.
      //
      // Except for a tie this device has already seen. The query is
      // at-or-after the cursor, so every row sharing the newest instant comes
      // back on every pull; without this it would be re-applied on every
      // launch forever. A row at or before the cursor was in a previous batch
      // and was already decided, so leave it alone.
      final alreadySeen = cursor != null && !record.updatedAt.isAfter(cursor);
      if (record.revision == local && alreadySeen) {
        skipped++;
        continue;
      }

      final applier = _appliers[record.recordType];
      if (applier == null) {
        // A record type this build does not know — written by a newer client,
        // most likely. Counted and stepped over, but the cursor still advances
        // past it, because refusing to move would wedge every later record
        // behind something this build will never understand.
        unknown++;
        continue;
      }

      try {
        if (record.isDelete) {
          await applier.applyDelete(record.recordId);
        } else {
          await applier.applyUpsert(_envelopeFor(record));
        }
      } catch (error) {
        // One bad record must not abandon the rest of the batch, and must not
        // advance this record's revision — so the next pull tries it again.
        debugPrint(
          'Could not apply ${record.recordType}/${record.recordId}: $error',
        );
        skipped++;
        continue;
      }

      await _store.saveRevision(
        record.recordType,
        record.recordId,
        record.revision,
      );
      applied++;
    }

    if (newestSeen != null) {
      await _store.saveCursor(newestSeen.toUtc().toIso8601String());
    }

    return SyncResult(applied: applied, skipped: skipped, unknownTypes: unknown);
  }

  /// The envelope a remote record carries.
  ///
  /// Rebuilt from the row rather than trusted wholesale: the row's own
  /// `record_type`, `record_id` and revisions are authoritative, because they
  /// are what the server keyed and constrained.
  ProjectSyncEnvelope _envelopeFor(RemoteSyncRecord record) {
    final payload = Map<String, dynamic>.from(record.payload);
    return ProjectSyncEnvelope.fromJson({
      ...payload,
      'recordId': record.recordId,
      'recordType': record.recordType,
      'revision': record.revision,
      'baseRevision': record.baseRevision,
      'deviceId': record.deviceId ?? 'remote',
      'updatedAt': record.updatedAt.toUtc().toIso8601String(),
    });
  }

  Future<DateTime?> _readCursor() async {
    final stored = await _store.loadCursor();
    if (stored == null || stored.isEmpty) return null;
    try {
      return DateTime.parse(stored).toUtc();
    } on FormatException {
      // An unreadable cursor means a full re-pull, which is safe: every apply
      // is idempotent. Better than never syncing again.
      return null;
    }
  }
}
