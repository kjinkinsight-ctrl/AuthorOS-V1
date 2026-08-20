import 'package:author_studio_v1/codex_continuity.dart';
import 'package:author_studio_v1/continuity.dart';
import 'package:author_studio_v1/core/connected_domain.dart';
import 'package:author_studio_v1/core/story_codex_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const intelligence = CodexContinuityIntelligence();
  final timestamp = DateTime.utc(2026, 3, 1, 9);

  CodexEntry entry(
    String id,
    String title, {
    String content = '',
    String summary = '',
    List<String> aliases = const [],
    Map<String, Object?> fields = const {},
    AuthorRecordStatus status = AuthorRecordStatus.active,
  }) =>
      CodexEntry(AuthorRecord(
        id: id,
        typeId: 'general-lore',
        scopeType: RecordScopeType.project,
        scopeId: 'project-codex',
        projectId: 'project-codex',
        title: title,
        status: status,
        templateId: 'general-lore',
        templateVersion: 1,
        fields: {
          'name': title,
          'aliases': aliases,
          CodexFields.summary: summary,
          CodexFields.content: content,
          CodexFields.templateId: 'general-lore',
          CodexFields.categoryId: 'lore',
          ...fields,
        },
        createdAt: timestamp,
        updatedAt: timestamp,
      ));

  RecordLink link(String source, String target) => RecordLink(
        id: 'link-$source-$target',
        sourceId: source,
        targetId: target,
        typeId: 'relatedTo',
        scopeId: 'project-codex',
        direction: RecordLinkDirection.undirected,
        createdAt: timestamp,
        updatedAt: timestamp,
      );

  test('an unlinked mention becomes a link recommendation', () {
    final subject = entry(
      'codex-harbor',
      'Noxmere Harbor',
      content: 'The Widow Network smuggles salt through the harbor.',
    );
    final other = entry('codex-widow', 'Widow Network');

    final report = intelligence.analyze(
      entry: subject,
      entries: [subject, other],
      links: const [],
      knownNames: const {'Noxmere Harbor', 'Widow Network'},
    );

    expect(report.isClean, isFalse);
    expect(report.summary.issues, hasLength(1));
    final issue = report.summary.issues.single;
    expect(issue.type, ContinuityWarningType.missingRelationship);
    expect(issue.actionKind, ContinuityActionKind.link);
    expect(issue.eventIds, ['codex-harbor', 'codex-widow']);

    final finding = report.findingFor(issue);
    expect(finding?.targetId, 'codex-widow');
    expect(finding?.connectionTypeId, 'relatedTo');
  });

  test('an existing connection resolves the mention recommendation', () {
    final subject = entry(
      'codex-harbor',
      'Noxmere Harbor',
      content: 'The Widow Network smuggles salt through the harbor.',
    );
    final other = entry('codex-widow', 'Widow Network');

    final report = intelligence.analyze(
      entry: subject,
      entries: [subject, other],
      links: [link('codex-harbor', 'codex-widow')],
      knownNames: const {'Noxmere Harbor', 'Widow Network'},
    );

    expect(report.isClean, isTrue);
    expect(report.summary.score, 100);
  });

  test('aliases and archived entries are handled', () {
    final subject = entry(
      'codex-harbor',
      'Noxmere Harbor',
      content: 'Locals still call it the Salt Gate after dusk.',
    );
    final aliased = entry(
      'codex-gate',
      'Eastern Customs House',
      aliases: const ['Salt Gate'],
    );
    final archived = entry(
      'codex-old',
      'Salt Gate Registry',
      status: AuthorRecordStatus.archived,
    );

    final report = intelligence.analyze(
      entry: subject,
      entries: [subject, aliased, archived],
      links: const [],
      knownNames: const {},
    );

    expect(
      report.findings.map((finding) => finding.targetId),
      ['codex-gate'],
    );
  });

  test('roster fields naming missing records become create recommendations',
      () {
    final subject = entry(
      'codex-guild',
      'Saltwrights Guild',
      fields: const {
        'members': ['Hesper Vane', 'Odo Kell'],
        'nearbyLocations': ['Grey Quay'],
      },
    );

    final report = intelligence.analyze(
      entry: subject,
      entries: [subject],
      links: const [],
      knownNames: const {'Odo Kell'},
    );

    final types = report.summary.issues.map((issue) => issue.type).toList();
    expect(types, contains(ContinuityWarningType.unknownCharacter));
    expect(types, contains(ContinuityWarningType.unknownLocation));
    expect(
      report.findings.map((finding) => finding.missingName),
      containsAll(['Hesper Vane', 'Grey Quay']),
    );
    expect(
      report.findings.map((finding) => finding.missingName),
      isNot(contains('Odo Kell')),
    );
    expect(
      report.summary.issues
          .where((issue) => issue.type == ContinuityWarningType.unknownCharacter)
          .single
          .actionKind,
      ContinuityActionKind.create,
    );
  });

  test('names owned by other Studios are never reported as missing', () {
    final subject = entry(
      'codex-guild',
      'Saltwrights Guild',
      fields: const {
        'members': ['Kalis Ardent'],
      },
    );
    final characterRecord = AuthorRecord(
      id: 'character-kalis',
      typeId: 'character',
      scopeType: RecordScopeType.project,
      scopeId: 'project-codex',
      projectId: 'project-codex',
      title: 'Kalis Ardent',
      createdAt: timestamp,
      updatedAt: timestamp,
    );

    final report = intelligence.analyze(
      entry: subject,
      entries: [subject],
      links: const [],
      knownNames: CodexContinuityIntelligence.knownNames([characterRecord]),
    );

    expect(report.isClean, isTrue);
  });

  test('short and partial-word mentions do not create noise', () {
    final subject = entry(
      'codex-harbor',
      'Noxmere Harbor',
      content: 'The harborage was rebuilt after the flood.',
    );
    final other = entry('codex-harborage-part', 'Harb');

    final report = intelligence.analyze(
      entry: subject,
      entries: [subject, other],
      links: const [],
      knownNames: const {},
    );

    expect(report.isClean, isTrue);
  });

  test('findings are capped so the panel stays readable', () {
    const capped = CodexContinuityIntelligence(maxFindingsPerEntry: 2);
    final others = [
      for (var index = 0; index < 6; index += 1)
        entry('codex-$index', 'Mentioned Record $index'),
    ];
    final subject = entry(
      'codex-subject',
      'Subject',
      content: others.map((item) => item.title).join(' and '),
    );

    final report = capped.analyze(
      entry: subject,
      entries: [subject, ...others],
      links: const [],
      knownNames: const {},
    );

    expect(report.findings, hasLength(2));
  });
}
