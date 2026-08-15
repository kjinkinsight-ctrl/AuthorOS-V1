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

class SyncedStarterProject {
  const SyncedStarterProject({
    required this.project,
    required this.sourcePayload,
  });

  final StarterProject project;
  final Map<String, dynamic> sourcePayload;
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

    return SyncedStarterProject(
      project: StarterProject.fromJson({
        ...canonicalProject,
        ...flutterStarter,
        'id': envelope.recordId,
      }),
      sourcePayload: payload,
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