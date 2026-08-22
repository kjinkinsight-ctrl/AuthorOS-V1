/// Commands that change the project.
///
/// A read command runs the moment it is understood. A command that writes never
/// does. It is turned into a [CommandActionPreview] — a plain statement of what
/// would happen, with the entities already resolved — and nothing reaches the
/// database until the author confirms it. That two-step shape is borrowed from
/// [ContinuityActionService], which solved the same problem for continuity
/// recommendations.
///
/// Every write goes through [RecordService], [ConnectionEngine] or a Studio's
/// own create method. None of them is a formality: they validate against the
/// type registries, enforce project isolation, and write a version and an audit
/// event alongside the change. A command that wrote to the database directly
/// would be a change with no history, which is worse than no command at all.
library;

import 'character_service.dart';
import 'core/command_query.dart';
import 'core/connected_domain.dart';
import 'core/connection_engine.dart';
import 'core/connection_types.dart';
import 'core/record_service.dart';
import 'core/search_models.dart';
import 'core/universal_search.dart';
import 'command_service.dart';
import 'manuscript_service.dart';
import 'persistence/authoros_database.dart';
import 'plot_service.dart';
import 'research_service.dart';
import 'timeline_service.dart';
import 'world_service.dart';

enum CommandActionKind { link, create }

enum CommandActionStatus {
  /// The author declined. Nothing was written.
  cancelled,

  /// The change was made.
  applied,

  /// The command was understood and deliberately not carried out.
  refused,
}

/// One connection type a link could use.
class CommandConnectionChoice {
  const CommandConnectionChoice({
    required this.typeId,
    required this.label,
    required this.isWildcard,
  });

  final String typeId;
  final String label;

  /// Whether the type permits any endpoints at all rather than these ones
  /// specifically. Most types do, so a wildcard match says very little.
  final bool isWildcard;
}

/// What a command would do, stated before it does it.
class CommandActionPreview {
  const CommandActionPreview({
    required this.kind,
    required this.summary,
    this.source,
    this.target,
    this.connectionTypeId,
    this.connectionLabel = '',
    this.connectionChoices = const [],
    this.createTypeId,
    this.createTitle = '',
    this.refusal = '',
  });

  /// A preview that will not run, and why.
  factory CommandActionPreview.refused(
    CommandActionKind kind,
    String reason,
  ) =>
      CommandActionPreview(
        kind: kind,
        summary: reason,
        refusal: reason,
      );

  final CommandActionKind kind;

  /// One sentence naming exactly what would change.
  final String summary;

  final CommandEntity? source;
  final CommandEntity? target;

  final String? connectionTypeId;
  final String connectionLabel;

  /// Offered when more than one connection type fits the endpoints. The author
  /// picks; the command does not guess.
  final List<CommandConnectionChoice> connectionChoices;

  final String? createTypeId;
  final String createTitle;

  final String refusal;

  bool get isRefused => refusal.isNotEmpty;

  /// Whether an endpoint matched more than one entity.
  bool get needsDisambiguation =>
      (source?.isAmbiguous ?? false) || (target?.isAmbiguous ?? false);

  /// Whether the author still has to choose how the two are related.
  bool get needsConnectionChoice =>
      kind == CommandActionKind.link && connectionTypeId == null;

  bool get canApply =>
      !isRefused && !needsDisambiguation && !needsConnectionChoice;
}

class CommandActionResult {
  const CommandActionResult({
    required this.status,
    required this.message,
    this.recordId,
    this.linkId,
  });

  final CommandActionStatus status;
  final String message;
  final String? recordId;
  final String? linkId;

  bool get changedSomething => status == CommandActionStatus.applied;
}

class CommandActionService {
  CommandActionService({required this.commands});

  final CommandService commands;

  String get projectId => commands.projectId;

  DriftConnectedDomainRepository get repository => commands.repository;

  RecordService get records => commands.records;

  /// Resolves a command into a proposal. Reads only.
  ///
  /// [sourceId], [targetId] and [connectionTypeId] are how the console feeds a
  /// choice back in: the author disambiguated a name or picked a relationship,
  /// and the same command is prepared again with that decision applied.
  Future<CommandActionPreview> prepare(
    CommandQuery query, {
    String? sourceId,
    String? targetId,
    String? connectionTypeId,
  }) async {
    switch (query.verb) {
      case CommandVerb.link:
        return _prepareLink(
          query,
          sourceId: sourceId,
          targetId: targetId,
          connectionTypeId: connectionTypeId,
        );
      case CommandVerb.create:
        return _prepareCreate(query);
      case CommandVerb.show:
        return CommandActionPreview.refused(
          CommandActionKind.link,
          'That command only reads.',
        );
    }
  }

  /// Carries out a proposal, but only when [confirmed].
  ///
  /// An unconfirmed apply is not an error and not a no-op to be papered over —
  /// it is the author saying no, and it writes nothing.
  Future<CommandActionResult> apply(
    CommandActionPreview preview, {
    required bool confirmed,
    DateTime? timestamp,
  }) async {
    if (!confirmed) {
      return const CommandActionResult(
        status: CommandActionStatus.cancelled,
        message: 'Nothing was changed.',
      );
    }
    if (!preview.canApply) {
      return CommandActionResult(
        status: CommandActionStatus.refused,
        message: preview.isRefused
            ? preview.refusal
            : 'That command still needs a choice before it can run.',
      );
    }
    try {
      return switch (preview.kind) {
        CommandActionKind.link => await _applyLink(preview, timestamp),
        CommandActionKind.create => await _applyCreate(preview, timestamp),
      };
    } on StateError catch (error) {
      // The engines refuse an invalid write by throwing. That refusal is the
      // right answer, so it is reported rather than swallowed.
      return CommandActionResult(
        status: CommandActionStatus.refused,
        message: _clean(error.message),
      );
    } on ArgumentError catch (error) {
      return CommandActionResult(
        status: CommandActionStatus.refused,
        message: _clean('${error.message}'),
      );
    }
  }

  // -------------------------------------------------------------------- link

  Future<CommandActionPreview> _prepareLink(
    CommandQuery query, {
    String? sourceId,
    String? targetId,
    String? connectionTypeId,
  }) async {
    final sourcePhrase = query.anchorPhrase ?? '';
    final targetPhrase = query.linkTargetPhrase ?? '';
    if (sourcePhrase.isEmpty || targetPhrase.isEmpty) {
      return CommandActionPreview.refused(
        CommandActionKind.link,
        'Say what to link to what — for example, '
        '"link Kali to Endovier".',
      );
    }

    final source =
        await commands.resolveEntity(sourcePhrase, entityId: sourceId);
    if (source == null) {
      return CommandActionPreview.refused(
        CommandActionKind.link,
        'Nothing in this project is called "$sourcePhrase".',
      );
    }
    final target =
        await commands.resolveEntity(targetPhrase, entityId: targetId);
    if (target == null) {
      return CommandActionPreview.refused(
        CommandActionKind.link,
        'Nothing in this project is called "$targetPhrase".',
      );
    }
    if (source.id == target.id) {
      return CommandActionPreview.refused(
        CommandActionKind.link,
        'A record cannot be connected to itself.',
      );
    }
    if (source.isAmbiguous || target.isAmbiguous) {
      return CommandActionPreview(
        kind: CommandActionKind.link,
        summary: 'More than one thing goes by that name.',
        source: source,
        target: target,
      );
    }

    final registry = await records.connectionRegistry();
    final choices = _choicesBetween(registry, source.typeId, target.typeId);
    if (choices.isEmpty) {
      return CommandActionPreview.refused(
        CommandActionKind.link,
        'No connection type joins a ${source.typeLabel.toLowerCase()} to a '
        '${target.typeLabel.toLowerCase()}.',
      );
    }

    final chosen = connectionTypeId ?? _soleSensibleChoice(choices)?.typeId;
    if (chosen == null) {
      return CommandActionPreview(
        kind: CommandActionKind.link,
        summary: 'How is ${source.title} related to ${target.title}?',
        source: source,
        target: target,
        connectionChoices: choices,
      );
    }
    if (!choices.any((choice) => choice.typeId == chosen)) {
      return CommandActionPreview.refused(
        CommandActionKind.link,
        '$chosen cannot join a ${source.typeLabel.toLowerCase()} to a '
        '${target.typeLabel.toLowerCase()}.',
      );
    }

    for (final link in await repository.backlinks(source.id)) {
      if (link.typeId == chosen &&
          (link.sourceId == target.id || link.targetId == target.id)) {
        return CommandActionPreview.refused(
          CommandActionKind.link,
          '${source.title} and ${target.title} are already connected '
          'that way.',
        );
      }
    }

    final label = registry.resolve(chosen).displayName;
    return CommandActionPreview(
      kind: CommandActionKind.link,
      summary: 'Connect ${source.title} to ${target.title} '
          '(${label.toLowerCase()}).',
      source: source,
      target: target,
      connectionTypeId: chosen,
      connectionLabel: label,
      connectionChoices: choices,
    );
  }

  Future<CommandActionResult> _applyLink(
    CommandActionPreview preview,
    DateTime? timestamp,
  ) async {
    final source = preview.source!;
    final target = preview.target!;
    final typeId = preview.connectionTypeId!;

    // A scene or chapter is a manuscript node, and Manuscript Studio owns which
    // way an edge to one points. Asking it is the difference between a link the
    // manuscript understands and one it merely tolerates.
    if (source.isManuscriptNode || target.isManuscriptNode) {
      if (source.isManuscriptNode && target.isManuscriptNode) {
        return const CommandActionResult(
          status: CommandActionStatus.refused,
          message: 'Two manuscript nodes are connected in Manuscript Studio, '
              'where their order is known.',
        );
      }
      final node = source.isManuscriptNode ? source : target;
      final record = source.isManuscriptNode ? target : source;
      final manuscript =
          ManuscriptService(projectId: projectId, repository: repository);
      final link = await manuscript.connectNode(
        nodeId: node.id,
        recordId: record.id,
        typeId: typeId,
        timestamp: timestamp,
      );
      return CommandActionResult(
        status: CommandActionStatus.applied,
        message: '${source.title} is now connected to ${target.title}.',
        linkId: link.id,
      );
    }

    final engine = ConnectionEngine(
      scopeId: projectId,
      repository: repository,
      registry: await records.connectionRegistry(),
    );
    final link = await engine.connect(
      sourceId: source.id,
      targetId: target.id,
      typeId: typeId,
      timestamp: timestamp,
    );
    return CommandActionResult(
      status: CommandActionStatus.applied,
      message: '${source.title} is now connected to ${target.title}.',
      linkId: link.id,
    );
  }

  // ------------------------------------------------------------------ create

  Future<CommandActionPreview> _prepareCreate(CommandQuery query) async {
    final title = (query.anchorPhrase ?? '').trim();
    if (title.isEmpty) {
      return CommandActionPreview.refused(
        CommandActionKind.create,
        'Say what to call it — for example, "create character Cassian".',
      );
    }
    final typeId = _createTypeFor(query.subject);
    if (typeId == null) {
      return CommandActionPreview.refused(
        CommandActionKind.create,
        'Name the kind of record to create — for example, '
        '"create location Endovier".',
      );
    }

    // Creating a second record with the same name and type is almost always a
    // mistake, and the author usually meant to connect the one they have.
    for (final existing in await repository.recordsByProject(projectId)) {
      if (existing.status == AuthorRecordStatus.deleted) continue;
      if (existing.typeId == typeId &&
          existing.title.toLowerCase() == title.toLowerCase()) {
        return CommandActionPreview.refused(
          CommandActionKind.create,
          'A ${query.subject.label.toLowerCase()} called "$title" already '
          'exists. Connect it instead of creating another.',
        );
      }
    }

    return CommandActionPreview(
      kind: CommandActionKind.create,
      summary: 'Create a ${query.subject.label.toLowerCase()} called "$title".',
      createTypeId: typeId,
      createTitle: title,
    );
  }

  Future<CommandActionResult> _applyCreate(
    CommandActionPreview preview,
    DateTime? timestamp,
  ) async {
    final typeId = preview.createTypeId!;
    final title = preview.createTitle;
    final id = _newRecordId(typeId, title, timestamp);

    // Each Studio knows the template and field defaults its records need. Going
    // through RecordService directly would produce a record that validates but
    // is missing everything the owning Studio expects to find.
    final record = switch (searchDestinationForType(typeId)) {
      SearchDestination.characterStudio =>
        await CharacterService(projectId: projectId, repository: repository)
            .createCharacter(
          id: id,
          displayName: title,
          timestamp: timestamp,
        ),
      SearchDestination.worldStudio =>
        await WorldService(projectId: projectId, repository: repository)
            .createWorldRecord(
          id: id,
          title: title,
          typeId: typeId,
          timestamp: timestamp,
        ),
      SearchDestination.plotStudio =>
        await PlotService(projectId: projectId, repository: repository)
            .createPlotRecord(
          PlotRecordDraft(id: id, typeId: typeId, name: title),
          timestamp: timestamp,
        ),
      SearchDestination.timelineStudio =>
        await TimelineService(projectId: projectId, repository: repository)
            .createEvent(
          TimelineEventDraft(id: id, name: title, typeId: typeId),
          timestamp: timestamp,
        ),
      _ => await ResearchService(projectId: projectId, repository: repository)
            .createResearch(
          ResearchDraft(id: id, title: title, typeId: typeId),
          timestamp: timestamp,
        ),
    };

    return CommandActionResult(
      status: CommandActionStatus.applied,
      message: '${record.title} was created.',
      recordId: record.id,
    );
  }

  /// The single type a "create" command means.
  ///
  /// A subject is a family, and a family with many members does not say which
  /// one to make. "create character" is unambiguous because `character` is the
  /// family's root; "create plot" is not, and is refused rather than guessed.
  String? _createTypeFor(CommandSubject subject) {
    if (subject.everything || subject.isReport) return null;
    if (subject.recordTypeIds.length == 1) return subject.recordTypeIds.single;
    for (final candidate in subject.recordTypeIds) {
      if (subject.label.toLowerCase().replaceAll(' ', '-') == candidate) {
        return candidate;
      }
    }
    return null;
  }

  List<CommandConnectionChoice> _choicesBetween(
    ConnectionTypeRegistry registry,
    String sourceTypeId,
    String targetTypeId,
  ) =>
      registry.definitions
          .where((definition) =>
              definition.permits(sourceTypeId, targetTypeId) ||
              definition.permits(targetTypeId, sourceTypeId))
          .map((definition) => CommandConnectionChoice(
                typeId: definition.id,
                label: definition.displayName,
                isWildcard: definition.sourceTypeIds.contains('*') &&
                    definition.targetTypeIds.contains('*'),
              ))
          .toList()
        ..sort((left, right) => left.label.compareTo(right.label));

  /// The one obviously-right connection type, if there is one.
  ///
  /// Most connection types accept any endpoints, so a wildcard match is not
  /// evidence of anything. Only a type that names these two kinds specifically,
  /// and is the only such type, is safe to choose without asking.
  CommandConnectionChoice? _soleSensibleChoice(
    List<CommandConnectionChoice> choices,
  ) {
    final specific = choices.where((choice) => !choice.isWildcard).toList();
    return specific.length == 1 ? specific.single : null;
  }
}

String _newRecordId(String typeId, String title, DateTime? timestamp) {
  final slug = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final stamp = (timestamp ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
  return 'command-$typeId-${slug.isEmpty ? 'record' : slug}-$stamp';
}

String _clean(String message) =>
    message.endsWith('.') ? message : '$message.';
