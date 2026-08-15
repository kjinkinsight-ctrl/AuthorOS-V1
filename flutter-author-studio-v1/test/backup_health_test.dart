import 'package:author_studio_v1/backup_health.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('backup health store persists every trust indicator', () async {
    const store = BackupHealthStore();
    final backupTime = DateTime.utc(2026, 8, 11, 10, 30);
    final restoreTime = DateTime.utc(2026, 8, 11, 11, 45);

    await store.save(
      BackupHealth(
        destination: 'External drive',
        lastSuccessfulBackup: backupTime,
        lastRestoreTest: restoreTime,
        restoreTestStatus: RestoreTestStatus.passed,
      ),
    );

    final restored = await store.load();
    expect(restored.destination, 'External drive');
    expect(restored.lastSuccessfulBackup, backupTime);
    expect(restored.lastRestoreTest, restoreTime);
    expect(restored.restoreTestStatus, RestoreTestStatus.passed);
  });

  test('recovery simulation verifies a round trip without mutation', () {
    final snapshot = <String, Object?>{
      'destination': 'External drive',
      'lastSuccessfulBackup': '2026-08-11T10:30:00.000Z',
      'schemaVersion': 1,
    };
    final before = Map<String, Object?>.from(snapshot);

    final report = const BackupRecoverySimulator().verify(
      backupSnapshot: snapshot,
      checkedAt: DateTime.utc(2026, 8, 11, 12),
    );

    expect(report.passed, isTrue);
    expect(report.sourceFingerprint, report.restoredFingerprint);
    expect(report.checks, hasLength(4));
    expect(snapshot, before);
  });

  test('recovery simulation rejects incomplete backup metadata', () {
    final report = const BackupRecoverySimulator().verify(
      backupSnapshot: const {
        'destination': '',
        'lastSuccessfulBackup': null,
      },
      checkedAt: DateTime.utc(2026, 8, 11, 12),
    );

    expect(report.passed, isFalse);
    expect(report.summary, contains('Not restorable'));
  });

  testWidgets('backup health shows honest defaults and records success',
      (tester) async {
    final now = DateTime(2026, 8, 11, 14, 20);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: BackupHealthView(clock: () => now),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Last successful backup'), findsOneWidget);
    expect(find.text('Never'), findsOneWidget);
    expect(find.text('Local backup folder'), findsWidgets);
    expect(find.text('Last restore test'), findsOneWidget);
    expect(find.text('Not tested'), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-backup-button')));
    await tester.pumpAndSettle();
    expect(find.text('2026-08-11 14:20'), findsOneWidget);

    await tester.tap(find.byKey(const Key('record-restore-button')));
    await tester.pumpAndSettle();
    expect(find.text('Passed · 2026-08-11 14:20'), findsOneWidget);
    expect(find.byKey(const Key('recovery-simulation-report')), findsOneWidget);
    expect(find.textContaining('active project data was not overwritten'),
        findsOneWidget);
  });

  testWidgets('compact backup health is suitable for dashboard visibility',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: BackupHealthView(compact: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backup health'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('Last restore test'), findsOneWidget);
    expect(find.byKey(const Key('record-backup-button')), findsNothing);
  });
}
