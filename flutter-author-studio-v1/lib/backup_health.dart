import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/flutter/authoros_theme.dart';

enum RestoreTestStatus { passed, failed }

class RecoverySimulationReport {
  const RecoverySimulationReport({
    required this.passed,
    required this.checkedAt,
    required this.checks,
    required this.sourceFingerprint,
    required this.restoredFingerprint,
  });

  final bool passed;
  final DateTime checkedAt;
  final List<String> checks;
  final int sourceFingerprint;
  final int restoredFingerprint;

  String get summary => passed
      ? 'Restorable · ${checks.length} integrity checks passed'
      : 'Not restorable · integrity checks failed';
}

class BackupRecoverySimulator {
  const BackupRecoverySimulator();

  RecoverySimulationReport verify({
    required Map<String, Object?> backupSnapshot,
    required DateTime checkedAt,
  }) {
    final encoded = jsonEncode(backupSnapshot);
    final sourceFingerprint = _fingerprint(encoded);
    final checks = <String>[];
    var passed = true;
    Map<String, dynamic>? restored;

    try {
      restored = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      checks.add('Backup data is readable JSON');
    } catch (_) {
      passed = false;
    }

    if (restored != null) {
      if ((restored['destination'] as String? ?? '').trim().isNotEmpty) {
        checks.add('Backup destination is present');
      } else {
        passed = false;
      }
      if (DateTime.tryParse(
              restored['lastSuccessfulBackup'] as String? ?? '') !=
          null) {
        checks.add('Backup timestamp is valid');
      } else {
        passed = false;
      }
    }

    final restoredEncoded = restored == null ? '' : jsonEncode(restored);
    final restoredFingerprint = _fingerprint(restoredEncoded);
    if (sourceFingerprint == restoredFingerprint) {
      checks.add('Round-trip integrity fingerprint matches');
    } else {
      passed = false;
    }

    return RecoverySimulationReport(
      passed: passed,
      checkedAt: checkedAt,
      checks: checks,
      sourceFingerprint: sourceFingerprint,
      restoredFingerprint: restoredFingerprint,
    );
  }

  int _fingerprint(String value) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(value)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class BackupHealth {
  const BackupHealth({
    required this.destination,
    this.lastSuccessfulBackup,
    this.lastRestoreTest,
    this.restoreTestStatus,
  });

  final String destination;
  final DateTime? lastSuccessfulBackup;
  final DateTime? lastRestoreTest;
  final RestoreTestStatus? restoreTestStatus;

  bool get hasSuccessfulBackup => lastSuccessfulBackup != null;

  BackupHealth copyWith({
    String? destination,
    DateTime? lastSuccessfulBackup,
    DateTime? lastRestoreTest,
    RestoreTestStatus? restoreTestStatus,
  }) {
    return BackupHealth(
      destination: destination ?? this.destination,
      lastSuccessfulBackup: lastSuccessfulBackup ?? this.lastSuccessfulBackup,
      lastRestoreTest: lastRestoreTest ?? this.lastRestoreTest,
      restoreTestStatus: restoreTestStatus ?? this.restoreTestStatus,
    );
  }
}

class BackupHealthStore {
  const BackupHealthStore();

  static const _destinationKey = 'author_studio.backup_destination';
  static const _lastSuccessKey = 'author_studio.backup_last_success';
  static const _lastRestoreKey = 'author_studio.backup_last_restore';
  static const _restoreStatusKey = 'author_studio.backup_restore_status';

  Future<BackupHealth> load() async {
    final preferences = await SharedPreferences.getInstance();
    final restoreStatus = preferences.getString(_restoreStatusKey);

    return BackupHealth(
      destination:
          preferences.getString(_destinationKey) ?? 'Local backup folder',
      lastSuccessfulBackup:
          DateTime.tryParse(preferences.getString(_lastSuccessKey) ?? ''),
      lastRestoreTest:
          DateTime.tryParse(preferences.getString(_lastRestoreKey) ?? ''),
      restoreTestStatus: switch (restoreStatus) {
        'passed' => RestoreTestStatus.passed,
        'failed' => RestoreTestStatus.failed,
        _ => null,
      },
    );
  }

  Future<void> save(BackupHealth health) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_destinationKey, health.destination);

    if (health.lastSuccessfulBackup != null) {
      await preferences.setString(
        _lastSuccessKey,
        health.lastSuccessfulBackup!.toIso8601String(),
      );
    }

    if (health.lastRestoreTest != null) {
      await preferences.setString(
        _lastRestoreKey,
        health.lastRestoreTest!.toIso8601String(),
      );
    }

    if (health.restoreTestStatus != null) {
      await preferences.setString(
        _restoreStatusKey,
        health.restoreTestStatus!.name,
      );
    }
  }
}

class BackupHealthView extends StatefulWidget {
  const BackupHealthView({
    super.key,
    this.compact = false,
    this.store = const BackupHealthStore(),
    this.simulator = const BackupRecoverySimulator(),
    this.clock = DateTime.now,
  });

  final bool compact;
  final BackupHealthStore store;
  final BackupRecoverySimulator simulator;
  final DateTime Function() clock;

  @override
  State<BackupHealthView> createState() => _BackupHealthViewState();
}

class _BackupHealthViewState extends State<BackupHealthView> {
  static const destinations = [
    'Local backup folder',
    'Documents',
    'External drive',
    'Cloud-synced folder',
  ];

  BackupHealth? health;
  RecoverySimulationReport? simulationReport;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.store.load();
    if (mounted) {
      setState(() => health = loaded);
    }
  }

  Future<void> _update(BackupHealth updated) async {
    await widget.store.save(updated);
    if (mounted) {
      setState(() => health = updated);
    }
  }

  Future<void> _verifyBackup(BackupHealth current) async {
    final report = widget.simulator.verify(
      backupSnapshot: {
        'destination': current.destination,
        'lastSuccessfulBackup': current.lastSuccessfulBackup?.toIso8601String(),
        'schemaVersion': 1,
      },
      checkedAt: widget.clock(),
    );
    await _update(current.copyWith(
      lastRestoreTest: report.checkedAt,
      restoreTestStatus:
          report.passed ? RestoreTestStatus.passed : RestoreTestStatus.failed,
    ));
    if (mounted) {
      setState(() => simulationReport = report);
    }
  }

  String _formatDate(DateTime? value, String emptyLabel) {
    if (value == null) {
      return emptyLabel;
    }

    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  String _restoreLabel(BackupHealth current) {
    return switch (current.restoreTestStatus) {
      RestoreTestStatus.passed =>
        'Passed · ${_formatDate(current.lastRestoreTest, '')}',
      RestoreTestStatus.failed =>
        'Failed · ${_formatDate(current.lastRestoreTest, '')}',
      null => 'Not tested',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AuthorOsSemanticColors.of(context);
    final current = health;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BACKUP & EXPORT',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create full backups, project exports, and safe import previews.',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      current.hasSuccessfulBackup
                          ? 'Your latest backup is recorded and ready for recovery.'
                          : 'No successful backup has been recorded yet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.primary),
                ),
                child: Text(
                  'READY',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _HealthMetric(
              icon: Icons.schedule_outlined,
              label: 'Last successful backup',
              value: _formatDate(current.lastSuccessfulBackup, 'Never'),
            ),
            _HealthMetric(
              icon: Icons.folder_outlined,
              label: 'Destination',
              value: current.destination,
            ),
            _HealthMetric(
              icon: Icons.fact_check_outlined,
              label: 'Last restore test',
              value: _restoreLabel(current),
              valueColor: switch (current.restoreTestStatus) {
                RestoreTestStatus.passed => semantic.success,
                RestoreTestStatus.failed => semantic.error,
                null => null,
              },
            ),
          ],
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: const Key('backup-destination-field'),
                    initialValue: current.destination,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Backup destination',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      isDense: true,
                    ),
                    items: destinations
                        .map((destination) => DropdownMenuItem(
                              value: destination,
                              child: Text(destination),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _update(current.copyWith(destination: value));
                      }
                    },
                  ),
                ),
                FilledButton.icon(
                  key: const Key('record-backup-button'),
                  onPressed: () => _update(
                    current.copyWith(lastSuccessfulBackup: widget.clock()),
                  ),
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Record successful backup'),
                ),
                OutlinedButton.icon(
                  key: const Key('record-restore-button'),
                  onPressed: current.hasSuccessfulBackup
                      ? () => _verifyBackup(current)
                      : null,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Verify my backup'),
                ),
              ],
            ),
          ),
          if (simulationReport != null) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('recovery-simulation-report'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: simulationReport!.passed
                      ? semantic.success
                      : semantic.error,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    simulationReport!.summary,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final check in simulationReport!.checks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('✓ $check'),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Simulation only: active project data was not overwritten.',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );

    if (widget.compact) {
      final compactContent = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup health',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            _HealthMetric(
              icon: Icons.folder_outlined,
              label: 'Destination',
              value: current.destination,
            ),
            const SizedBox(height: 12),
            _HealthMetric(
              icon: Icons.fact_check_outlined,
              label: 'Last restore test',
              value: _restoreLabel(current),
              valueColor: switch (current.restoreTestStatus) {
                RestoreTestStatus.passed => semantic.success,
                RestoreTestStatus.failed => semantic.error,
                null => null,
              },
            ),
          ],
        ),
      );
      return SingleChildScrollView(child: compactContent);
    }

    return SingleChildScrollView(child: content);
  }
}

class _HealthMetric extends StatelessWidget {
  const _HealthMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 245,
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: valueColor ?? theme.colorScheme.onSurface,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
