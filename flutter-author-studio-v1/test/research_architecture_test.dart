import 'dart:io';

import 'package:author_studio_v1/core/built_in_connection_types.dart';
import 'package:author_studio_v1/core/built_in_record_types.dart';
import 'package:author_studio_v1/core/research_record_types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Source-level guardrails for Research Studio.
///
/// These read the shipped source so a future change that reintroduces a second
/// research store, a duplicate model, or a hard-coded colour fails here rather
/// than in review.
void main() {
  final researchSources = <String, String>{
    for (final path in const [
      'lib/research_service.dart',
      'lib/research_studio_view.dart',
      'lib/core/research_record_types.dart',
    ])
      path: File(path).readAsStringSync(),
  };

  group('Persistence', () {
    test('Research Studio never touches SharedPreferences', () {
      researchSources.forEach((path, source) {
        expect(
          source.contains('SharedPreferences'),
          isFalse,
          reason: '$path must not read or write SharedPreferences.',
        );
        expect(
          source.contains('shared_preferences'),
          isFalse,
          reason: '$path must not import shared_preferences.',
        );
      });
    });

    test('Research Studio declares no database, table, or store of its own',
        () {
      final forbidden = <RegExp>[
        RegExp(r'class\s+\w*Research\w*(Database|Table|Store|Repository)\b'),
        RegExp(r'extends\s+Table\b'),
        RegExp(r'@DriftDatabase'),
        RegExp(r'\bNativeDatabase\b'),
        RegExp(r'\bcustomStatement\('),
        RegExp(r'\bcustomSelect\('),
      ];
      researchSources.forEach((path, source) {
        for (final pattern in forbidden) {
          expect(
            pattern.hasMatch(source),
            isFalse,
            reason: '$path must not declare its own storage ($pattern).',
          );
        }
      });
    });

    test('the only persistence import is the canonical AuthorOS database', () {
      final imports = RegExp(r"^import '([^']+)';", multiLine: true)
          .allMatches(researchSources['lib/research_service.dart']!)
          .map((match) => match.group(1)!)
          .where((path) => path.contains('persistence'))
          .toList();
      expect(imports, ['persistence/authoros_database.dart']);
    });

    test('every write goes through the shared record and connection services',
        () {
      final service = researchSources['lib/research_service.dart']!;
      expect(service, contains('RecordService('));
      expect(service, contains('ConnectionEngine('));
      expect(service, contains('UniversalSearchService('));
      // The view owns no service construction of its own beyond what the
      // shell injects, and never reaches for the repository directly.
      final view = researchSources['lib/research_studio_view.dart']!;
      expect(view.contains('DriftConnectedDomainRepository'), isFalse);
    });

    test('the view keeps no research cache beyond the loaded records', () {
      final view = researchSources['lib/research_studio_view.dart']!;
      expect(view.contains('static final'), isFalse);
      expect(RegExp(r'\bTimer\b').hasMatch(view), isFalse);
      expect(RegExp(r'\bIsolate\b').hasMatch(view), isFalse);
      expect(RegExp(r'\bcompute\(').hasMatch(view), isFalse);
    });
  });

  group('Data model', () {
    test('no duplicate Research model is declared', () {
      // ResearchDraft is a form payload and ResearchConnection is a read-side
      // pairing; neither may become a persisted model. Nothing declares a
      // Research entity with its own identity and serialisation.
      researchSources.forEach((path, source) {
        expect(
          RegExp(r'class\s+Research(Record|Item|Entry|Model|Entity)\b')
              .hasMatch(source),
          isFalse,
          reason: '$path declares a duplicate research model.',
        );
        expect(
          RegExp(r'\bResearch\w*\.fromJson\b').hasMatch(source),
          isFalse,
          reason: '$path serialises a research model of its own.',
        );
        expect(
          RegExp(r'\bMap<String, Object\?> toJson\(\)').hasMatch(source),
          isFalse,
          reason: '$path serialises a research model of its own.',
        );
      });
    });

    test('research stays the canonical record type it always was', () {
      expect(ResearchRecordTypes.baseTypeId, 'research-entry');
      expect(ResearchRecordTypes.aliasTypeId, 'research');
      final registry = BuiltInRecordTypes.registry();
      final entry = registry.resolve(ResearchRecordTypes.baseTypeId);
      expect(entry.baseTypeId, 'general-lore');
      expect(entry.categoryId, 'research');

      // Exactly one definition owns each research type id.
      for (final id in ResearchRecordTypes.recordTypeIds) {
        expect(
          BuiltInRecordTypes.definitions
              .where((definition) => definition.id == id)
              .length,
          1,
          reason: '$id is defined more than once.',
        );
      }
    });

    test('the categories and statuses live on the record definition', () {
      final registry = BuiltInRecordTypes.registry();
      final entry = registry.resolve(ResearchRecordTypes.baseTypeId);
      final fields = {
        for (final field in entry.fields) field.id: field,
      };
      expect(
        fields[ResearchRecordTypes.categoryFieldId]!.options,
        ResearchRecordTypes.categories,
      );
      expect(
        fields[ResearchRecordTypes.statusFieldId]!.options,
        ResearchRecordTypes.statuses,
      );
      expect(
        fields[ResearchRecordTypes.kindFieldId]!.options,
        ResearchRecordTypes.kinds,
      );
      // Archived is the shared record lifecycle, never a stored option.
      expect(
        ResearchRecordTypes.statuses,
        isNot(contains(ResearchRecordTypes.archivedStatus)),
      );
    });
  });

  group('Search and connections', () {
    test('search runs on canonical records, not a second index', () {
      final service = researchSources['lib/research_service.dart']!;
      expect(service, contains('search.searchAll('));
      expect(
        RegExp(r'\b(buildIndex|reindex|_index\b|SearchIndex\w*\s*=)')
            .hasMatch(service),
        isFalse,
        reason: 'Research Studio must not maintain a search index.',
      );
    });

    test('connections use the shared engine and its built-in types', () {
      final service = researchSources['lib/research_service.dart']!;
      expect(service, contains('connections.connect('));
      expect(
        RegExp(r'class\s+\w*Research\w*(Link|Relationship|Connection)Engine\b')
            .hasMatch(service),
        isFalse,
      );

      final registry = BuiltInConnectionTypes.registry();
      // `documents` is the shared type research uses to attach to any record.
      final documents = registry.resolve('documents');
      for (final typeId in ResearchRecordTypes.recordTypeIds) {
        expect(
          documents.sourceTypeIds,
          contains(typeId),
          reason: '$typeId cannot document a record.',
        );
      }
      expect(documents.targetTypeIds, contains('*'));
      for (final typeId in ResearchRecordTypes.suggestedLinkTypeIds) {
        expect(
          () => registry.resolve(typeId),
          returnsNormally,
          reason: '$typeId is not a built-in connection type.',
        );
      }
    });
  });

  group('Theme Engine', () {
    test('the Studio consumes the Theme Engine instead of bypassing it', () {
      final view = researchSources['lib/research_studio_view.dart']!;
      expect(view, contains('StudioThemeScope'));
      expect(view, contains('StudioId.research'));
      expect(view, contains('Theme.of(context)'));
      expect(
        view.contains('ThemeData('),
        isFalse,
        reason: 'Research Studio must not build its own ThemeData.',
      );
    });

    test('no hard-coded colours exist in the new Research Studio code', () {
      final forbidden = <RegExp>[
        RegExp(r'\bColors\.'),
        RegExp(r'Color\(0x'),
        RegExp(r'Color\.fromARGB\('),
        RegExp(r'Color\.fromRGBO\('),
        RegExp(r'#[0-9a-fA-F]{6}\b'),
      ];
      researchSources.forEach((path, source) {
        for (final pattern in forbidden) {
          expect(
            pattern.hasMatch(source),
            isFalse,
            reason: '$path hard-codes a colour ($pattern).',
          );
        }
      });
    });
  });

  group('Manuscript research side panel', () {
    test('the legacy SharedPreferences panel is left untouched and intact', () {
      // This milestone deliberately does not migrate or delete the panel, so
      // no author loses data. The guard fails if it disappears without a
      // migration landing alongside it.
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('class ProjectResearchStore'));
      expect(main, contains('author_studio.research_panel.'));

      // Research Studio must not read or write that key.
      researchSources.forEach((path, source) {
        expect(
          source.contains('author_studio.research_panel'),
          isFalse,
          reason: '$path touches the legacy research panel store.',
        );
        expect(
          source.contains('ProjectResearchStore'),
          isFalse,
          reason: '$path depends on the legacy research panel store.',
        );
      });
    });
  });
}
