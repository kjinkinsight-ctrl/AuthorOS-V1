import 'package:author_studio_v1/core/version_audit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version and audit snapshots are deeply immutable and round-trip', () {
    final fields = <String, Object?>{
      'title': 'Kali',
      'nested': <String, Object?>{'goal': 'Leave'},
      'tags': <String>['canon'],
    };
    final version = RecordVersion(
      id: 'version-1',
      entityId: 'kali',
      entityKind: VersionEntityKind.record,
      recordId: 'kali',
      recordType: 'character',
      projectId: 'project-a',
      createdAt: DateTime.utc(2026, 8, 19),
      changeType: AuditChangeType.created,
      summary: 'Created Kali',
      schemaVersion: 1,
      snapshot: fields,
      metadata: const {'source': 'test'},
    );
    fields['title'] = 'Changed';
    (fields['nested'] as Map<String, Object?>)['goal'] = 'Remain';

    expect(version.snapshot['title'], 'Kali');
    expect((version.snapshot['nested'] as Map)['goal'], 'Leave');
    expect(() => version.snapshot['title'] = 'Nope', throwsUnsupportedError);
    expect(
      () => (version.snapshot['nested'] as Map)['goal'] = 'Nope',
      throwsUnsupportedError,
    );
    expect(RecordVersion.fromJson(version.toJson()).snapshot, version.snapshot);

    final audit = AuditEvent(
      id: 'audit-1',
      versionId: version.id,
      entityId: version.entityId,
      entityKind: version.entityKind,
      recordId: version.recordId,
      recordType: version.recordType,
      projectId: version.projectId,
      createdAt: version.createdAt,
      changeType: version.changeType,
      summary: version.summary,
      metadata: const {'versionNumber': 1},
    );
    expect(AuditEvent.fromJson(audit.toJson()).versionId, version.id);
    expect(AuditChangeType.values, contains(AuditChangeType.scopeChanged));
  });
}
