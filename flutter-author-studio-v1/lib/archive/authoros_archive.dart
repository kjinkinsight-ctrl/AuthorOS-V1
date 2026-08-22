import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import '../core/connected_domain.dart';
import '../core/connection_types.dart';
import '../core/record_types.dart';
import '../core/scene_prose.dart';
import '../core/branch_domain.dart';
import '../core/version_audit.dart';

class AuthorOsArchiveLimits {
  const AuthorOsArchiveLimits({
    this.maximumEntries = 100000,
    this.maximumTotalBytes = 4 * 1024 * 1024 * 1024,
    this.maximumEntryBytes = 16 * 1024 * 1024,
  });

  final int maximumEntries;
  final int maximumTotalBytes;
  final int maximumEntryBytes;
}

class AuthorOsArchiveService {
  const AuthorOsArchiveService({
    this.limits = const AuthorOsArchiveLimits(),
  });

  final AuthorOsArchiveLimits limits;

  Uint8List exportSnapshot(
    ConnectedDomainSnapshot snapshot, {
    required String archiveId,
    required String rootId,
    required String applicationVersion,
    required String platform,
    required DateTime createdAt,
  }) {
    InMemoryConnectedDomainRepository(initial: snapshot);
    final entries = <String, Uint8List>{
      'data/records.jsonl': _jsonLines(
        snapshot.records.map((record) => record.toJson()),
      ),
      'data/manuscript-nodes.jsonl': _jsonLines(
        snapshot.manuscriptNodes.map((node) => node.toJson()),
      ),
      'data/links.jsonl': _jsonLines(
        snapshot.links.map((link) => link.toJson()),
      ),
      'data/record-types.jsonl': _jsonLines(
        snapshot.recordTypeDefinitions.map((definition) => definition.toJson()),
      ),
      'data/connection-types.jsonl': _jsonLines(
        snapshot.connectionTypeDefinitions
            .map((definition) => definition.toJson()),
      ),
      'data/branches.jsonl': _jsonLines(
        snapshot.branches.map((branch) => branch.toJson()),
      ),
      'data/branch-record-overlays.jsonl': _jsonLines(
        snapshot.branchRecordOverlays.map((overlay) => {
              'id': '${overlay.branchId}|${overlay.recordId}',
              ...overlay.toJson(),
            }),
      ),
      'data/branch-link-overlays.jsonl': _jsonLines(
        snapshot.branchLinkOverlays.map((overlay) => {
              'id': '${overlay.branchId}|${overlay.linkId}',
              ...overlay.toJson(),
            }),
      ),
      'data/versions.jsonl': _jsonLines(
        snapshot.versions.map((version) => version.toJson()),
      ),
      'data/audit-events.jsonl': _jsonLines(
        snapshot.auditEvents.map((event) => event.toJson()),
      ),
      // Under content/, not data/: this is the book, not the graph that
      // describes it. An archive without it would back up every fact about
      // the manuscript except what it says.
      'content/scene-prose.jsonl': _jsonLines(
        snapshot.sceneProse.map((prose) => {
              'id': prose.sceneId,
              ...prose.toJson(),
            }),
      ),
    };
    final contentFingerprint = _contentFingerprint(entries);
    final entryMetadata = [
      for (final entry in entries.entries)
        {
          'path': entry.key,
          'role': _roleFor(entry.key),
          'mediaType': 'application/x-ndjson',
          'bytes': entry.value.length,
          'sha256': _digest(entry.value),
          'recordCount': _lineCount(entry.value),
        },
    ]..sort((left, right) =>
        (left['path'] as String).compareTo(right['path'] as String));
    final checksums = {
      'algorithm': 'SHA-256',
      'entries': {
        for (final entry in entryMetadata)
          entry['path'] as String: entry['sha256'] as String,
      },
      'contentFingerprint': contentFingerprint,
    };
    final manifest = {
      'archiveFormat': 'authoros',
      'archiveVersion': 1,
      'archiveId': archiveId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'createdBy': {
        'application': 'AuthorOS',
        'version': applicationVersion,
        'platform': platform,
      },
      'contentScope': 'project',
      'rootIds': [rootId],
      'schemaVersions': const {
        'connectedDomain': 2,
        'recordTypeDefinition': 1,
        'connectionTypeDefinition': 1,
        'scopeCanonBranch': 1,
        'versionAudit': 1,
      },
      'entries': entryMetadata,
      'contentFingerprint': contentFingerprint,
    };

    final archive = Archive();
    for (final entry in entries.entries) {
      archive.add(ArchiveFile.bytes(entry.key, entry.value));
    }
    archive.add(
      ArchiveFile.string('checksums.json', _canonicalJson(checksums)),
    );
    archive.add(
      ArchiveFile.string('manifest.json', _canonicalJson(manifest)),
    );
    return ZipEncoder().encodeBytes(
      archive,
      modified: DateTime.utc(2000),
    );
  }

  ConnectedDomainSnapshot importSnapshot(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.length > limits.maximumEntries) {
      throw const FormatException('Archive contains too many entries.');
    }

    final files = <String, Uint8List>{};
    final caseFoldedPaths = <String>{};
    var totalBytes = 0;
    for (final entry in archive) {
      if (!entry.isFile || entry.isSymbolicLink) {
        throw const FormatException(
          'Directories and symbolic links are not supported.',
        );
      }
      _validatePath(entry.name);
      if (!caseFoldedPaths.add(entry.name.toLowerCase())) {
        throw FormatException('Duplicate archive path: ${entry.name}');
      }
      final content = entry.readBytes() ?? Uint8List(0);
      if (content.length > limits.maximumEntryBytes) {
        throw FormatException('Archive entry is too large: ${entry.name}');
      }
      totalBytes += content.length;
      if (totalBytes > limits.maximumTotalBytes) {
        throw const FormatException('Archive is too large.');
      }
      files[entry.name] = content;
    }

    final manifest = _jsonObject(files['manifest.json'], 'manifest.json');
    final checksums = _jsonObject(files['checksums.json'], 'checksums.json');
    if (manifest['archiveFormat'] != 'authoros' ||
        manifest['archiveVersion'] != 1) {
      throw const FormatException('Unsupported AuthorOS archive.');
    }
    if (checksums['algorithm'] != 'SHA-256') {
      throw const FormatException('Unsupported checksum algorithm.');
    }

    final declared = <String, Map<String, dynamic>>{};
    final rawEntries = manifest['entries'];
    if (rawEntries is! List) {
      throw const FormatException('Manifest entries are required.');
    }
    for (final value in rawEntries) {
      final entry = Map<String, dynamic>.from(value as Map);
      final path = entry['path'] as String? ?? '';
      _validatePath(path);
      if (declared.putIfAbsent(path, () => entry) != entry) {
        throw FormatException('Duplicate manifest path: $path');
      }
    }
    final expectedPaths = {...declared.keys, 'manifest.json', 'checksums.json'};
    if (files.keys.toSet().difference(expectedPaths).isNotEmpty ||
        expectedPaths.difference(files.keys.toSet()).isNotEmpty) {
      throw const FormatException('Archive entries do not match the manifest.');
    }

    final checksumEntries = checksums['entries'];
    if (checksumEntries is! Map) {
      throw const FormatException('Checksum entries are required.');
    }
    for (final entry in declared.entries) {
      final content = files[entry.key]!;
      final digest = _digest(content);
      if (entry.value['bytes'] != content.length ||
          entry.value['sha256'] != digest ||
          checksumEntries[entry.key] != digest) {
        throw FormatException('Integrity check failed: ${entry.key}');
      }
    }
    final dataEntries = {
      for (final path in declared.keys) path: files[path]!,
    };
    final fingerprint = _contentFingerprint(dataEntries);
    if (manifest['contentFingerprint'] != fingerprint ||
        checksums['contentFingerprint'] != fingerprint) {
      throw const FormatException('Content fingerprint does not match.');
    }

    final snapshot = ConnectedDomainSnapshot(
      records: _decodeJsonLines(files['data/records.jsonl'])
          .map(AuthorRecord.fromJson)
          .toList(),
      manuscriptNodes: _decodeJsonLines(files['data/manuscript-nodes.jsonl'])
          .map(ManuscriptNodeReference.fromJson)
          .toList(),
      links: _decodeJsonLines(files['data/links.jsonl'])
          .map(RecordLink.fromJson)
          .toList(),
      recordTypeDefinitions: files.containsKey('data/record-types.jsonl')
          ? _decodeJsonLines(files['data/record-types.jsonl'])
              .map(RecordTypeDefinition.fromJson)
              .toList()
          : const [],
      connectionTypeDefinitions:
          files.containsKey('data/connection-types.jsonl')
              ? _decodeJsonLines(files['data/connection-types.jsonl'])
                  .map(ConnectionTypeDefinition.fromJson)
                  .toList()
              : const [],
      branches: files.containsKey('data/branches.jsonl')
          ? _decodeJsonLines(files['data/branches.jsonl'])
              .map(StoryBranch.fromJson)
              .toList()
          : const [],
      branchRecordOverlays:
          files.containsKey('data/branch-record-overlays.jsonl')
              ? _decodeJsonLines(files['data/branch-record-overlays.jsonl'])
                  .map(BranchRecordOverlay.fromJson)
                  .toList()
              : const [],
      branchLinkOverlays: files.containsKey('data/branch-link-overlays.jsonl')
          ? _decodeJsonLines(files['data/branch-link-overlays.jsonl'])
              .map(BranchLinkOverlay.fromJson)
              .toList()
          : const [],
      versions: files.containsKey('data/versions.jsonl')
          ? _decodeJsonLines(files['data/versions.jsonl'])
              .map(RecordVersion.fromJson)
              .toList()
          : const [],
      auditEvents: files.containsKey('data/audit-events.jsonl')
          ? _decodeJsonLines(files['data/audit-events.jsonl'])
              .map(AuditEvent.fromJson)
              .toList()
          : const [],
      // Optional on read: archives written before prose moved into the
      // database do not carry this entry, and must still restore.
      sceneProse: files.containsKey('content/scene-prose.jsonl')
          ? _decodeJsonLines(files['content/scene-prose.jsonl'])
              .map(SceneProse.fromJson)
              .toList()
          : const [],
    );
    InMemoryConnectedDomainRepository(initial: snapshot);
    return snapshot;
  }

  Future<ConnectedDomainSnapshot> importAndCommit(
    Uint8List bytes,
    Future<void> Function(ConnectedDomainSnapshot snapshot) commit,
  ) async {
    final snapshot = importSnapshot(bytes);
    await commit(snapshot);
    return snapshot;
  }
}

Uint8List _jsonLines(Iterable<Map<String, Object?>> values) {
  final sorted = values.toList()
    ..sort((left, right) =>
        (left['id'] as String).compareTo(right['id'] as String));
  final encoded = sorted.map(_canonicalJson).join('\n');
  return Uint8List.fromList(utf8.encode(encoded.isEmpty ? '' : '$encoded\n'));
}

List<Map<String, dynamic>> _decodeJsonLines(Uint8List? bytes) {
  if (bytes == null) {
    throw const FormatException('Required data entry is missing.');
  }
  final content = utf8.decode(bytes, allowMalformed: false);
  return [
    for (final line in const LineSplitter().convert(content))
      if (line.trim().isNotEmpty)
        Map<String, dynamic>.from(jsonDecode(line) as Map),
  ];
}

Map<String, dynamic> _jsonObject(Uint8List? bytes, String path) {
  if (bytes == null) {
    throw FormatException('$path is missing.');
  }
  try {
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(bytes, allowMalformed: false)) as Map,
    );
  } catch (_) {
    throw FormatException('$path is invalid.');
  }
}

void _validatePath(String path) {
  if (path.isEmpty ||
      path.contains('\\') ||
      path.contains('\u0000') ||
      path.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(path) ||
      path.split('/').any((segment) => segment.isEmpty || segment == '..')) {
    throw FormatException('Unsafe archive path: $path');
  }
}

String _contentFingerprint(Map<String, Uint8List> entries) {
  final buffer = BytesBuilder(copy: false);
  final paths = entries.keys.toList()..sort();
  for (final path in paths) {
    buffer.add(utf8.encode(path));
    buffer.addByte(0);
    buffer.add(utf8.encode(_digest(entries[path]!)));
    buffer.addByte(10);
  }
  return _digest(buffer.takeBytes());
}

String _digest(List<int> bytes) => sha256.convert(bytes).toString();

int _lineCount(Uint8List bytes) =>
    const LineSplitter().convert(utf8.decode(bytes)).length;

String _roleFor(String path) => switch (path) {
      'data/records.jsonl' => 'records',
      'data/manuscript-nodes.jsonl' => 'manuscript-nodes',
      'data/links.jsonl' => 'links',
      'data/record-types.jsonl' => 'record-type-definitions',
      'data/connection-types.jsonl' => 'connection-type-definitions',
      'data/branches.jsonl' => 'branches',
      'data/branch-record-overlays.jsonl' => 'branch-record-overlays',
      'data/branch-link-overlays.jsonl' => 'branch-link-overlays',
      'data/versions.jsonl' => 'record-versions',
      'data/audit-events.jsonl' => 'audit-events',
      'content/scene-prose.jsonl' => 'scene-content',
      _ => throw ArgumentError.value(path, 'path', 'Unknown archive role'),
    };

String _canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys) key: _canonicalValue(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalValue).toList();
  }
  return value;
}
