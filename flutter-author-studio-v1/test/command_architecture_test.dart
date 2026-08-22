/// Architecture guardrails for the Command System.
///
/// The Command System touches every Studio, which is exactly what makes it a
/// tempting place to take a shortcut: a cache of its own, a direct write, a
/// call to a model to understand a hard phrase. Each test here pins one promise
/// the feature was built on, so breaking it is a decision someone makes on
/// purpose rather than a thing that quietly happens.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _coreFiles = <String>[
  'lib/core/command_grammar.dart',
  'lib/core/command_query.dart',
];

const _serviceFiles = <String>[
  'lib/command_service.dart',
  'lib/command_actions.dart',
];

const _allFiles = <String>[
  ..._coreFiles,
  ..._serviceFiles,
  'lib/command_console.dart',
];

String _read(String path) => File(path).readAsStringSync();

/// [path] with its comments removed.
///
/// Several of these guardrails name the thing they forbid in order to explain
/// why it is forbidden. Checking the prose alongside the code would make those
/// explanations fail the test they belong to.
String _code(String path) => _read(path)
    .split('\n')
    .map((line) {
      final comment = line.indexOf('//');
      return comment == -1 ? line : line.substring(0, comment);
    })
    .join('\n');

void main() {
  test('every Command System file exists where the layering says it does', () {
    for (final path in _allFiles) {
      expect(File(path).existsSync(), isTrue, reason: '$path is missing.');
    }
  });

  test('the grammar depends on nothing but the type system', () {
    // core -> storage -> services -> studios. The grammar is the bottom of that
    // stack: it turns words into a query using the record and connection
    // registries, and it must stay testable without a database or a widget.
    for (final path in _coreFiles) {
      final source = _read(path);
      expect(source, isNot(contains('package:flutter/')),
          reason: '$path must not import Flutter.');
      expect(source, isNot(contains('persistence/')),
          reason: '$path must not reach the database.');
      expect(source, isNot(contains('_service.dart')),
          reason: '$path must not depend on a Studio service.');
    }
  });

  test('the Command System owns no storage', () {
    for (final path in _allFiles) {
      final source = _read(path);
      for (final forbidden in const [
        'class CommandStore',
        'class CommandDatabase',
        'class CommandRepository',
        'class CommandIndex',
        'class CommandCache',
      ]) {
        expect(source, isNot(contains(forbidden)),
            reason: '$path declares $forbidden. The Command System reads the '
                'record graph; it does not keep a copy of it.');
      }
    }
  });

  test('changes go through the engines that validate and audit them', () {
    final source = _code('lib/command_actions.dart');
    for (final bypass in const [
      'putRecord(',
      'putLink(',
      'putRecordsAndLinks(',
      'putManuscriptNodes(',
      'replaceSnapshot(',
    ]) {
      expect(source, isNot(contains(bypass)),
          reason: 'command_actions.dart calls $bypass directly. A write that '
              'skips RecordService or ConnectionEngine is a change with no '
              'version and no audit event.');
    }
    expect(source, contains('ConnectionEngine'));
    expect(source, contains('RecordService'));
  });

  test('reading the manuscript never writes to it', () {
    // ManuscriptStore.loadStudio seeds manuscript nodes as a side effect. A
    // navigation query that called it would change the project just by being
    // asked a question.
    final source = _code('lib/command_service.dart');
    expect(source, isNot(contains('loadStudio')));
    expect(source, isNot(contains('ManuscriptStore')));
    // The manuscript is reached through the graph's projection of
    // manuscript_node_rows, which is a read.
    expect(source, contains('StoryGraphService'));
  });

  test('the parser is rules, not a model', () {
    // AuthorOS is AI-free by design. This is the mechanical version of that
    // promise: nothing in the Command System may reach the network at all.
    for (final path in _allFiles) {
      final source = _read(path).toLowerCase();
      for (final forbidden in const [
        'package:http',
        'httpclient',
        'dart:io',
        'anthropic',
        'openai',
        'api_key',
        'apikey',
      ]) {
        expect(source, isNot(contains(forbidden)),
            reason: '$path references "$forbidden". The command grammar is '
                'deterministic and offline.');
      }
    }
  });

  test('the vocabulary is derived, not hardcoded', () {
    final source = _read('lib/core/command_grammar.dart');
    expect(source, contains('RecordTypeRegistry'));
    expect(source, contains('ConnectionTypeRegistry'));
    expect(source, contains('isTemplateCompatible'));

    // A handful of English function words and category aliases are expected.
    // A long list of domain nouns is not: it would go stale the moment a
    // project defined a type of its own.
    final quoted = RegExp("'[a-z][a-z ]{2,}'")
        .allMatches(source)
        .map((match) => match.group(0)!)
        .toSet();
    expect(quoted.length, lessThan(120),
        reason: 'The grammar has grown a hardcoded vocabulary of '
            '${quoted.length} phrases. Derive them from the registries '
            'instead.');
  });
}
