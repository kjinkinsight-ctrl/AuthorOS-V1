import 'dart:io';

import 'package:author_studio_v1/main.dart'
    show StudioSection, StudioSectionData;
import 'package:flutter_test/flutter_test.dart';

/// Guards for the [AuthorOS Architecture Lock][lock].
///
/// The lock document states twelve principles every future feature must build
/// inside. A document depends on someone remembering it; this file does not.
/// Each test below pins one locked principle that can be checked mechanically,
/// so breaking it fails CI at the pull request rather than at the next audit.
///
/// This suite deliberately guards the **model itself** — one record envelope,
/// one edge model, studios that own no persistence, a Flutter-free domain, a
/// bounded navigation surface, and no generative dependency. The per-area
/// guards already in this suite (`map_architecture_test.dart`,
/// `command_architecture_test.dart`, `research_architecture_test.dart`,
/// `scope_architecture_test.dart`, `story_graph_architecture_test.dart`) keep
/// doing their own jobs; nothing here replaces them.
///
/// Every assertion here was true of the tree on the day it was written. A
/// failure means something changed, not that the guard is new.
///
/// [lock]: ../docs/architecture/authoros-architecture-lock.md
void main() {
  String read(String path) => File(path).readAsStringSync();

  List<String> importsIn(String path) => read(path)
      .split('\n')
      .where((line) => line.trimLeft().startsWith('import '))
      .toList();

  /// Every Dart file under `lib/`, generated sources included.
  ///
  /// Generated code is deliberately in scope: a second record envelope arriving
  /// through a `.g.dart` file would be exactly as much of a second record
  /// envelope as one written by hand.
  List<String> libSources() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.path.replaceAll(r'\', '/'))
      .where((path) => path.endsWith('.dart'))
      .toList()
    ..sort();

  /// Files that present a studio to the author.
  ///
  /// A studio is a lens over the canonical model. It reads through a service
  /// and renders; it does not decide where anything is stored.
  const studioSurfaces = <String>[
    'lib/manuscript_studio.dart',
    'lib/manuscript_workspace.dart',
    'lib/character_studio.dart',
    'lib/world_studio.dart',
    'lib/world_workspace.dart',
    'lib/world_board/world_board_view.dart',
    'lib/story_codex_workspace.dart',
    'lib/map_studio_view.dart',
    'lib/timeline_studio_view.dart',
    'lib/plot_studio_view.dart',
    'lib/research_studio_view.dart',
    'lib/series_studio_view.dart',
    'lib/analytics_studio_view.dart',
    'lib/knowledge_graph/knowledge_graph_view.dart',
  ];

  /// The creative model and the intelligence that reads it.
  ///
  /// These must be resolvable in a test without a Flutter binding. A domain
  /// that can only run inside a widget tree is a domain that will eventually be
  /// reasoned about inside one.
  const domainAndIntelligence = <String>[
    // Universal Creative Model
    'lib/core/connected_domain.dart',
    'lib/core/record_service.dart',
    'lib/core/record_graph.dart',
    'lib/core/record_types.dart',
    'lib/core/record_validation.dart',
    'lib/core/universal_records.dart',
    'lib/core/template_engine.dart',
    'lib/core/connection_engine.dart',
    'lib/core/universal_search.dart',
    // Domain vocabularies
    'lib/core/story_codex_domain.dart',
    'lib/core/world_domain.dart',
    'lib/core/story_graph.dart',
    'lib/core/prose_document.dart',
    'lib/core/scene_prose.dart',
    'lib/core/scene_revision.dart',
    'lib/timeline_domain.dart',
    'lib/map_domain.dart',
    'lib/map_terrain.dart',
    'lib/map_world.dart',
    // Deterministic intelligence
    'lib/core/canon_facts.dart',
    'lib/core/entity_recognition.dart',
    'lib/core/codex_intelligence.dart',
  ];

  group('Lock 1 - one canonical representation', () {
    test('AuthorRecord is declared exactly once in the whole tree', () {
      final declaration = RegExp(
        r'^class AuthorRecord($|[^A-Za-z0-9_])',
        multiLine: true,
      );

      final declaring = libSources()
          .where((path) => declaration.hasMatch(read(path)))
          .toList();

      expect(
        declaring,
        ['lib/core/connected_domain.dart'],
        reason: 'There is one canonical representation of creative '
            'information. A feature that needs to say something new about an '
            'entity adds a field, a relationship, or a view - not a second '
            'record type.',
      );
    });
  });

  group('Lock 2 - one relationship model', () {
    test('RecordLink is declared exactly once in the whole tree', () {
      final declaration = RegExp(
        r'^class RecordLink($|[^A-Za-z0-9_])',
        multiLine: true,
      );

      final declaring = libSources()
          .where((path) => declaration.hasMatch(read(path)))
          .toList();

      expect(
        declaring,
        ['lib/core/connected_domain.dart'],
        reason: 'RecordLink is the only edge in AuthorOS. Time-bounded, '
            'directional, labelled and scoped are already expressible; a '
            'genuinely new property is added to the edge model once, for '
            'everyone.',
      );
    });
  });

  group('Lock 12 - studios own no persistence', () {
    test('no studio surface reaches a store, a database or a table', () {
      for (final path in studioSurfaces) {
        final source = read(path);
        for (final banned in const [
          'package:shared_preferences',
          'package:drift',
          'extends Table',
        ]) {
          expect(
            source.contains(banned),
            isFalse,
            reason: '$path is a lens over the canonical model. It reads '
                'through a service; it does not decide where anything is '
                'stored. Found: $banned',
          );
        }
      }
    });
  });

  group('Lock 12 - the domain is presentation-independent', () {
    // The guard is on *direct* imports, which is what a reviewer can act on.
    // One transitive exception is known and tracked: `codex_intelligence.dart`
    // imports `continuity.dart`, which still holds a Flutter widget beside the
    // continuity vocabulary. The compliance audit records that as debt, and
    // Step 3 of the sequence extracts the vocabulary into
    // `lib/core/continuity_domain.dart`. When it does, this guard tightens
    // rather than changes.
    test('the creative model and its intelligence import no Flutter', () {
      for (final path in domainAndIntelligence) {
        for (final line in importsIn(path)) {
          for (final banned in const [
            'package:flutter/',
            'package:flutter_test/',
            'dart:ui',
            '/theme/',
            'theme/theme_',
            'package:drift',
          ]) {
            expect(
              line.contains(banned),
              isFalse,
              reason: '$path belongs to the creative model or the '
                  'deterministic intelligence that reads it, and must resolve '
                  'without a Flutter binding. Found: $line',
            );
          }
        }
      }
    });

    test('no domain file imports a studio', () {
      for (final path in domainAndIntelligence) {
        for (final line in importsIn(path)) {
          expect(
            line.contains('studio') || line.contains('workspace'),
            isFalse,
            reason: 'Dependency direction is core -> persistence -> services '
                '-> studios. $path imports upward: $line',
          );
        }
      }
    });
  });

  group('Lock 10 - navigation is broad domains', () {
    test('the top-level navigation surface has not grown', () {
      // Pinned deliberately. The lock does not say 21 is the right number --
      // the compliance audit records it as debt, and regrouping the existing
      // sections into the five broad domains is scheduled UI work.
      //
      // What this pins is the direction of travel: AuthorOS must not answer
      // "where does this capability live?" with "a new top-level destination",
      // twenty more times, as Systems arrive. A capability belongs inside a
      // domain.
      //
      // Changing this number is an architectural decision. Make it in the lock
      // document first, then here.
      expect(
        StudioSection.values.length,
        21,
        reason: 'Future feature work does not create a permanent top-level '
            'destination for every new capability. Systems live inside the '
            'domain they belong to. See Lock 5 and Lock 10.',
      );
    });

    test('every section is still addressable', () {
      // A destination that cannot be linked to is a destination the author
      // cannot return to. Cheap to assert, and it keeps the count above
      // honest: sections cannot be traded for unaddressable ones.
      final slugs = StudioSection.values.map((section) => section.slug).toSet();
      expect(slugs.length, StudioSection.values.length);
      expect(slugs.any((slug) => slug.trim().isEmpty), isFalse);
    });
  });

  group('Lock 8 - intelligence is deterministic', () {
    test('no generative-AI dependency is declared', () {
      final pubspec = read('pubspec.yaml').toLowerCase();

      for (final banned in const [
        'openai',
        'anthropic',
        'google_generative_ai',
        'langchain',
        'tflite',
        'onnxruntime',
        'llama',
        'huggingface',
        'ollama',
      ]) {
        expect(
          pubspec.contains(banned),
          isFalse,
          reason: 'AuthorOS has no AI layer. It has an inference layer: '
              'canonical data -> relationships -> indexes -> rules -> '
              'inference -> analysis. Found: $banned',
        );
      }
    });
  });

  group('the lock is documented', () {
    test('the lock, the ADR and the audit are all present', () {
      // These three are cited by every implementation map from here on. A test
      // that guards principles while the statement of those principles can be
      // silently deleted is guarding half the contract.
      for (final path in const [
        'docs/architecture/authoros-architecture-lock.md',
        'docs/architecture/ADR-0006-architectural-precedence.md',
        'docs/authoros-architecture-compliance-audit.md',
      ]) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path states what this suite enforces.',
        );
      }
    });
  });
}
