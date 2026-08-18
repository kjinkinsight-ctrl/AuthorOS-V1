import 'dart:convert';
import 'dart:io';

import 'package:author_studio_v1/manuscript_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fixtureDirectory = Directory('test/fixtures');

  test('legacy migration fixture set has every required scenario', () {
    final fixtures = _loadFixtures(fixtureDirectory);

    expect(
      fixtures.map((fixture) => fixture['name']).toSet(),
      containsAll({
        'legacy-simple',
        'legacy-large',
        'legacy-malformed',
        'legacy-partial',
        'legacy-future-fields',
      }),
    );
  });

  test('legacy migration fixtures satisfy the fixture contract', () {
    final fixtures = _loadFixtures(fixtureDirectory);
    final names = <String>{};

    for (final fixture in fixtures) {
      expect(fixture['fixtureVersion'], 1);
      expect(fixture['name'], isA<String>());
      expect((fixture['name'] as String).trim(), isNotEmpty);
      expect(names.add(fixture['name'] as String), isTrue,
          reason: 'Fixture names must be unique.');
      expect((fixture['description'] as String?)?.trim(), isNotEmpty);
      expect((fixture['projectId'] as String?)?.startsWith('fixture-'), isTrue);
      expect(fixture['mode'], anyOf('literal', 'generated'));
      expect(fixture['expectations'], isA<Map>());
      expect(
        (fixture['expectations'] as Map)['mustRemainReadable'],
        isTrue,
      );

      if (fixture['mode'] == 'literal') {
        final preferences = fixture['preferences'];
        expect(preferences, isA<Map>());
        expect(preferences as Map, isNotEmpty);
        for (final entry in preferences.entries) {
          expect(entry.key, startsWith('author_studio.'));
          expect(entry.value, isA<Map>());
          expect(
            (entry.value as Map)['storageType'],
            anyOf('json', 'rawString', 'string', 'stringList', 'bool'),
          );
          expect((entry.value as Map).containsKey('value'), isTrue);
        }
      } else {
        final generator = fixture['generator'] as Map;
        expect(generator['seed'], isA<int>());
        expect(generator['chapterCount'], greaterThanOrEqualTo(100));
        expect(generator['scenesPerChapter'], greaterThan(0));
        expect(
          generator['chapterCount'] * generator['scenesPerChapter'],
          (fixture['expectations'] as Map)['sceneCount'],
        );
      }

      final encoded = jsonEncode(fixture).toLowerCase();
      expect(encoded, isNot(contains('@')),
          reason: 'Migration fixtures must not contain email addresses.');
      expect(encoded, isNot(contains('author_studio.profile.email')),
          reason: 'Project migration fixtures must not carry profile PII.');
    }
  });

  test('simple fixture loads through the current manuscript store', () async {
    final fixture = _fixture(fixtureDirectory, 'legacy-simple');
    SharedPreferences.setMockInitialValues(_materializePreferences(fixture));

    final manuscript = await const ManuscriptStore().loadStudio(
      fixture['projectId'] as String,
      manuscriptTitle: 'Fallback title',
      defaultChapters: const [],
    );

    expect(manuscript.manuscriptTitle, 'The Glass Harbor');
    expect(manuscript.sceneCount, 1);
    expect(manuscript.sceneById('scene-simple-1')?.content,
        'Ari unfolded the salt-stained letter.');
  });

  test('partial fixture prefers structured data and repairs scene structure',
      () async {
    final fixture = _fixture(fixtureDirectory, 'legacy-partial');
    SharedPreferences.setMockInitialValues(_materializePreferences(fixture));

    final manuscript = await const ManuscriptStore().loadStudio(
      fixture['projectId'] as String,
      manuscriptTitle: 'Fallback title',
      defaultChapters: const [],
    );
    final scene = manuscript.sceneById('scene-partial-1');

    expect(manuscript.manuscriptTitle, 'Northbound');
    expect(scene?.chapterId, 'chapter-partial-1');
    expect(scene?.order, 1);
    expect(scene?.content, 'The train left before dawn.');
  });

  test('malformed fixture retains readable text through migration fallback',
      () async {
    final fixture = _fixture(fixtureDirectory, 'legacy-malformed');
    SharedPreferences.setMockInitialValues(_materializePreferences(fixture));

    final manuscript = await const ManuscriptStore().loadStudio(
      fixture['projectId'] as String,
      manuscriptTitle: 'Recovered project',
      defaultChapters: const [
        ManuscriptChapterSeed(title: 'Recovered chapter'),
      ],
    );

    expect(manuscript.sceneCount, 1);
    expect(manuscript.chapters.first.scenes.first.content,
        'This readable fallback must survive migration failure.');
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString(
          'author_studio.manuscript_legacy_backup.fixture-project-malformed'),
      'This readable fallback must survive migration failure.',
    );
  });
}

List<Map<String, dynamic>> _loadFixtures(Directory directory) {
  expect(directory.existsSync(), isTrue);
  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((first, second) => first.path.compareTo(second.path));
  expect(files, isNotEmpty);

  return [
    for (final file in files)
      Map<String, dynamic>.from(
        jsonDecode(file.readAsStringSync()) as Map,
      ),
  ];
}

Map<String, dynamic> _fixture(Directory directory, String name) =>
    _loadFixtures(directory).singleWhere((fixture) => fixture['name'] == name);

Map<String, Object> _materializePreferences(Map<String, dynamic> fixture) {
  final result = <String, Object>{};
  final preferences = Map<String, dynamic>.from(fixture['preferences'] as Map);
  for (final entry in preferences.entries) {
    final stored = Map<String, dynamic>.from(entry.value as Map);
    final value = stored['value'];
    result[entry.key] = switch (stored['storageType']) {
      'json' => jsonEncode(value),
      'stringList' => List<String>.from(value as List),
      'bool' => value as bool,
      _ => value as String,
    };
  }
  return result;
}
