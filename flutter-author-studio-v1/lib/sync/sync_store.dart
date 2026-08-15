import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class SyncOperation {
  const SyncOperation({
    required this.operationId,
    required this.recordType,
    required this.recordId,
    required this.action,
    required this.baseRevision,
    required this.enqueuedAt,
    required this.payload,
    this.retryCount = 0,
    this.deletedAt,
  });

  final String operationId;
  final String recordType;
  final String recordId;
  final String action;
  final int baseRevision;
  final DateTime enqueuedAt;
  final int retryCount;
  final DateTime? deletedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'operationId': operationId,
        'recordType': recordType,
        'recordId': recordId,
        'action': action,
        'baseRevision': baseRevision,
        'enqueuedAt': enqueuedAt.toUtc().toIso8601String(),
        'retryCount': retryCount,
        'deletedAt': deletedAt?.toUtc().toIso8601String(),
        'payload': payload,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        operationId: json['operationId'] as String? ?? '',
        recordType: json['recordType'] as String? ?? '',
        recordId: json['recordId'] as String? ?? '',
        action: json['action'] as String? ?? 'upsert',
        baseRevision: _nonNegativeInt(json['baseRevision']),
        enqueuedAt: DateTime.tryParse(json['enqueuedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        retryCount: _nonNegativeInt(json['retryCount']),
        deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? ''),
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : <String, dynamic>{},
      );

  SyncOperation copyWith({
    String? action,
    int? baseRevision,
    int? retryCount,
    DateTime? deletedAt,
    Map<String, dynamic>? payload,
  }) =>
      SyncOperation(
        operationId: operationId,
        recordType: recordType,
        recordId: recordId,
        action: action ?? this.action,
        baseRevision: baseRevision ?? this.baseRevision,
        enqueuedAt: enqueuedAt,
        retryCount: retryCount ?? this.retryCount,
        deletedAt: deletedAt ?? this.deletedAt,
        payload: payload ?? this.payload,
      );
}

class SyncStore {
  const SyncStore();

  static const _deviceIdKey = 'author_studio.sync.device_id';
  static const _queueKey = 'author_studio.sync.queue';
  static const _revisionsKey = 'author_studio.sync.revisions';
  static const _cursorKey = 'author_studio.sync.cursor';

  Future<String> getOrCreateDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey)?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final deviceId = _generateUuid();
    if (!await preferences.setString(_deviceIdKey, deviceId)) {
      throw StateError('Unable to persist sync device identity.');
    }
    return deviceId;
  }

  Future<List<SyncOperation>> loadQueue() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_queueKey);
    if (raw == null) {
      return [];
    }

    try {
      return (jsonDecode(raw) as List)
          .map((value) => SyncOperation.fromJson(
              Map<String, dynamic>.from(value as Map)))
          .where((operation) =>
              operation.operationId.isNotEmpty &&
              operation.recordType.isNotEmpty &&
              operation.recordId.isNotEmpty)
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<SyncOperation> enqueue({
    required String recordType,
    required String recordId,
    required String action,
    required int baseRevision,
    required Map<String, dynamic> payload,
    DateTime? deletedAt,
    int retryCount = 0,
  }) async {
    final normalizedType = recordType.trim();
    final normalizedId = recordId.trim();
    if (normalizedType.isEmpty ||
        normalizedId.isEmpty ||
        !const {'upsert', 'delete'}.contains(action)) {
      throw ArgumentError('Invalid sync operation.');
    }

    final queue = await loadQueue();
    final existingIndex = queue.indexWhere((operation) =>
        operation.recordType == normalizedType &&
        operation.recordId == normalizedId);
    final existing = existingIndex >= 0 ? queue[existingIndex] : null;
    final operation = SyncOperation(
      operationId: existing?.operationId ?? _generateUuid(),
      recordType: normalizedType,
      recordId: normalizedId,
      action: action,
      baseRevision: baseRevision < 0 ? 0 : baseRevision,
      enqueuedAt: existing?.enqueuedAt ?? DateTime.now().toUtc(),
      retryCount: retryCount < 0 ? 0 : retryCount,
      deletedAt: deletedAt,
      payload: payload,
    );

    if (existingIndex >= 0) {
      queue[existingIndex] = operation;
    } else {
      queue.add(operation);
    }
    await _saveQueue(queue);
    return operation;
  }

  Future<bool> acknowledge(String operationId) async {
    final queue = await loadQueue();
    final filtered = queue
        .where((operation) => operation.operationId != operationId)
        .toList();
    if (filtered.length == queue.length) {
      return false;
    }
    await _saveQueue(filtered);
    return true;
  }

  Future<int> loadRevision(String recordType, String recordId) async {
    final revisions = await _loadRevisions();
    return _nonNegativeInt(revisions['$recordType:$recordId']);
  }

  Future<void> saveRevision(
      String recordType, String recordId, int revision) async {
    if (recordType.trim().isEmpty || recordId.trim().isEmpty || revision < 0) {
      throw ArgumentError('Valid sync identity and revision are required.');
    }
    final preferences = await SharedPreferences.getInstance();
    final revisions = await _loadRevisions()
      ..['${recordType.trim()}:${recordId.trim()}'] = revision;
    if (!await preferences.setString(_revisionsKey, jsonEncode(revisions))) {
      throw StateError('Unable to persist sync revision.');
    }
  }

  Future<String?> loadCursor() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_cursorKey);
  }

  Future<void> saveCursor(String? cursor) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = cursor == null
        ? await preferences.remove(_cursorKey)
        : await preferences.setString(_cursorKey, cursor);
    if (!saved) {
      throw StateError('Unable to persist sync cursor.');
    }
  }

  Future<Map<String, dynamic>> _loadRevisions() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_revisionsKey);
    if (raw == null) {
      return {};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    }
  }

  Future<void> _saveQueue(List<SyncOperation> queue) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
        _queueKey, jsonEncode(queue.map((item) => item.toJson()).toList()))) {
      throw StateError('Unable to persist sync queue.');
    }
  }
}

int _nonNegativeInt(Object? value) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : 0;
}

String _generateUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}