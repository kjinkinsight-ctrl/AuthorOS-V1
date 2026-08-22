import 'dart:convert';

import '../onboarding.dart';

class ProjectSyncEnvelope {
  const ProjectSyncEnvelope({
    required this.recordId,
    required this.revision,
    required this.baseRevision,
    required this.deviceId,
    required this.updatedAt,
    required this.payload,
    this.recordType = 'project',
    this.schemaVersion = 1,
    this.deletedAt,
    this.extensions = const {},
    this.extraFields = const {},
  });

  final String recordId;
  final String recordType;
  final int schemaVersion;
  final int revision;
  final int baseRevision;
  final String deviceId;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> extensions;
  final Map<String, dynamic> extraFields;

  /// The same envelope carrying a different payload.
  ///
  /// Used by the flush path when a record type queues a reference and resolves
  /// its real payload immediately before upload.
  ProjectSyncEnvelope copyWithPayload(Map<String, dynamic> payload) =>
      ProjectSyncEnvelope(
        recordId: recordId,
        recordType: recordType,
        schemaVersion: schemaVersion,
        revision: revision,
        baseRevision: baseRevision,
        deviceId: deviceId,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
        payload: payload,
        extensions: extensions,
        extraFields: extraFields,
      );

  Map<String, dynamic> toJson() => {
        ...extraFields,
        'recordId': recordId,
        'recordType': recordType,
        'schemaVersion': schemaVersion,
        'revision': revision,
        'baseRevision': baseRevision,
        'deviceId': deviceId,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
        'payload': _copyMap(payload),
        'extensions': _copyMap(extensions),
      };

  factory ProjectSyncEnvelope.fromJson(Map<String, dynamic> json) {
    const knownFields = {
      'recordId',
      'recordType',
      'schemaVersion',
      'revision',
      'baseRevision',
      'deviceId',
      'updatedAt',
      'deletedAt',
      'payload',
      'extensions',
    };
    final extraFields = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => knownFields.contains(key));

    return ProjectSyncEnvelope(
      recordId: _requiredString(json['recordId'], 'Sync record id is required.'),
      recordType: json['recordType'] as String? ?? 'project',
      schemaVersion: _nonNegativeInt(json['schemaVersion'], fallback: 1),
      revision: _nonNegativeInt(json['revision']),
      baseRevision: _nonNegativeInt(json['baseRevision']),
      deviceId: _requiredString(json['deviceId'], 'Device id is required.'),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
      payload: _map(json['payload']),
      extensions: _map(json['extensions']),
      extraFields: extraFields,
    );
  }
}

/// A project's place in a series, as it travels on the wire.
///
/// Deliberately not a serialization of [ProjectRosterEntry]: that class holds
/// the whole [StarterProject], and the project already travels in the payload
/// around this. Putting it here too would be a second copy of every book.
class ProjectSeriesMembership {
  const ProjectSeriesMembership({this.seriesId, this.seriesPosition});

  /// A book that belongs to no series. Distinct from omitting membership
  /// entirely, which means "I do not know, leave it alone".
  const ProjectSeriesMembership.standalone()
      : seriesId = null,
        seriesPosition = null;

  final String? seriesId;
  final int? seriesPosition;

  bool get isBook => seriesId != null;

  Map<String, Object?> toJson() => {
        'seriesId': seriesId,
        'seriesPosition': seriesId == null ? null : (seriesPosition ?? 0),
      };

  /// Reads membership from a payload, or `null` when the payload carries none.
  static ProjectSeriesMembership? fromPayload(Map<String, dynamic> payload) {
    final extensions = payload['extensions'];
    if (extensions is! Map) return null;
    final roster = extensions['flutterRoster'];
    if (roster is! Map) return null;

    final seriesId = roster['seriesId'] as String?;
    final rawPosition = roster['seriesPosition'];
    final position = rawPosition is int
        ? (rawPosition < 0 ? 0 : rawPosition)
        : int.tryParse('${rawPosition ?? ''}');
    return ProjectSeriesMembership(
      seriesId: seriesId,
      // A position without a series is meaningless, so it travels with one.
      seriesPosition: seriesId == null ? null : (position ?? 0),
    );
  }
}

class SyncedStarterProject {
  const SyncedStarterProject({
    required this.project,
    required this.sourcePayload,
    this.membership,
  });

  final StarterProject project;
  final Map<String, dynamic> sourcePayload;

  /// Where this project sits in a series, or `null` when the sender carried no
  /// membership — which means "leave the local membership alone", not
  /// "standalone". [ProjectSeriesMembership.standalone] is how a sender says
  /// a book has left its series.
  final ProjectSeriesMembership? membership;
}

class StarterProjectSyncAdapter {
  const StarterProjectSyncAdapter();

  ProjectSyncEnvelope toEnvelope(
    StarterProject project, {
    required String deviceId,
    required int revision,
    required int baseRevision,
    required DateTime updatedAt,
    Map<String, dynamic> sourcePayload = const {},
    ProjectSeriesMembership? membership,
  }) {
    final existingExtensions = _map(sourcePayload['extensions']);
    final payload = _copyMap(sourcePayload)
      ..addAll({
        'id': project.id,
        'name': project.title,
        'genre': project.genre,
        'type': project.projectType,
        'targetWordCount': project.wordGoal,
        'manuscript': {
          ..._map(sourcePayload['manuscript']),
          'chapters': project.chapters
              .map((chapter) => {
                    'title': chapter.title,
                    'prompt': chapter.prompt,
                  })
              .toList(),
        },
        'story': {
          ..._map(sourcePayload['story']),
          'characters': project.characterSheets
              .map((sheet) => {
                    'name': sheet.name,
                    'role': sheet.role,
                  })
              .toList(),
        },
        'extensions': {
          ...existingExtensions,
          'flutterStarter': project.toJson(),
          // Series membership rides beside the project rather than in a record
          // type of its own — the roster row already is the project.
          //
          // Present or absent carries meaning, and the distinction matters:
          //
          //  * absent  — "this writer knows nothing about series". A receiving
          //    device preserves whatever membership it already has. That is
          //    what lets an onboarding save, which has no roster to consult,
          //    reach another device without knocking a book out of its series.
          //  * present — "membership is exactly this", including
          //    `seriesId: null` for a book that has just left its series.
          //
          // So a standalone project still emits the key when the caller knew
          // to look; only a caller with no roster knowledge omits it.
          if (membership != null) 'flutterRoster': membership.toJson(),
        },
      });

    return ProjectSyncEnvelope(
      recordId: project.id,
      revision: revision < 0 ? 0 : revision,
      baseRevision: baseRevision < 0 ? 0 : baseRevision,
      deviceId: _requiredString(deviceId, 'Device id is required.'),
      updatedAt: updatedAt,
      payload: payload,
      extensions: const {'source': 'flutter'},
    );
  }

  SyncedStarterProject fromEnvelope(ProjectSyncEnvelope envelope) {
    if (envelope.recordType != 'project') {
      throw const FormatException('Unsupported sync record type.');
    }
    if (envelope.deletedAt != null) {
      throw const FormatException('Deleted projects cannot be restored.');
    }

    final payload = _copyMap(envelope.payload);
    final flutterStarter =
        _map(_map(payload['extensions'])['flutterStarter']);
    final manuscript = _map(payload['manuscript']);
    final story = _map(payload['story']);
    final canonicalProject = {
      'id': payload['id'] ?? envelope.recordId,
      'title': payload['name'],
      'genre': payload['genre'],
      'projectType': payload['type'],
      'wordGoal': payload['targetWordCount'],
      'chapters': (manuscript['chapters'] as List? ?? const [])
          .map((value) => {
                'title': _map(value)['title'],
                'prompt': _map(value)['prompt'],
              })
          .toList(),
      'characterSheets': (story['characters'] as List? ?? const [])
          .map((value) => {
                'name': _map(value)['name'],
                'role': _map(value)['role'],
              })
          .toList(),
      'acts': const <String>[],
      'beatChecklist': const <String>[],
      'firstSceneTitle': 'Opening Scene',
    };

    // Null when the writer carried no membership at all — an older client, or
    // an onboarding save. The caller preserves what it has in that case.
    final membership = ProjectSeriesMembership.fromPayload(payload);

    return SyncedStarterProject(
      project: StarterProject.fromJson({
        ...canonicalProject,
        ...flutterStarter,
        'id': envelope.recordId,
      }),
      sourcePayload: payload,
      membership: membership,
    );
  }
}

Map<String, dynamic> _copyMap(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic> _map(Object? value) => value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};

String _requiredString(Object? value, String message) {
  final normalized = value is String ? value.trim() : '';
  if (normalized.isEmpty) {
    throw FormatException(message);
  }
  return normalized;
}

int _nonNegativeInt(Object? value, {int fallback = 0}) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : fallback;
}