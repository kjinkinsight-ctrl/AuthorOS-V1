import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding.dart';

class TimelineEra {
  const TimelineEra({
    required this.id,
    required this.title,
    required this.status,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String status;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimelineEra copyWith({
    String? title,
    String? status,
    String? description,
    DateTime? updatedAt,
  }) =>
      TimelineEra(
        id: id,
        title: title ?? this.title,
        status: status ?? this.status,
        description: description ?? this.description,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TimelineEra.fromJson(Map<String, dynamic> json) {
    final createdAt = _date(json['createdAt']);
    return TimelineEra(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Era',
      status: json['status'] as String? ?? 'Planned',
      description: json['description'] as String? ?? '',
      createdAt: createdAt,
      updatedAt: _date(json['updatedAt'], fallback: createdAt),
    );
  }
}

class TimelineSequence {
  const TimelineSequence({
    required this.id,
    required this.title,
    required this.status,
    required this.description,
    required this.eraId,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String status;
  final String description;
  final String eraId;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimelineSequence copyWith({
    String? title,
    String? status,
    String? description,
    String? eraId,
    int? order,
    DateTime? updatedAt,
  }) =>
      TimelineSequence(
        id: id,
        title: title ?? this.title,
        status: status ?? this.status,
        description: description ?? this.description,
        eraId: eraId ?? this.eraId,
        order: order ?? this.order,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        'description': description,
        'eraId': eraId,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TimelineSequence.fromJson(Map<String, dynamic> json) {
    final createdAt = _date(json['createdAt']);
    return TimelineSequence(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Sequence',
      status: json['status'] as String? ?? 'Planned',
      description: json['description'] as String? ?? '',
      eraId: json['eraId'] as String? ?? '',
      order: _integer(json['order']),
      createdAt: createdAt,
      updatedAt: _date(json['updatedAt'], fallback: createdAt),
    );
  }
}

class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.dateLabel,
    required this.startDay,
    required this.endDay,
    required this.pov,
    required this.plotline,
    required this.presentCharacters,
    required this.location,
    required this.travelDaysFromPrevious,
    required this.linkedNote,
    required this.plotBeat,
    required this.status,
    required this.importance,
    required this.type,
    required this.eraId,
    required this.sequenceId,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String description;
  final String dateLabel;
  final int startDay;
  final int endDay;
  final String pov;
  final String plotline;
  final List<String> presentCharacters;
  final String location;
  final int travelDaysFromPrevious;
  final String linkedNote;
  final String plotBeat;
  final String status;
  final String importance;
  final String type;
  final String eraId;
  final String sequenceId;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimelineEvent copyWith({
    String? title,
    String? description,
    String? dateLabel,
    int? startDay,
    int? endDay,
    String? pov,
    String? plotline,
    List<String>? presentCharacters,
    String? location,
    int? travelDaysFromPrevious,
    String? linkedNote,
    String? plotBeat,
    String? status,
    String? importance,
    String? type,
    String? eraId,
    String? sequenceId,
    int? order,
    DateTime? updatedAt,
  }) =>
      TimelineEvent(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        dateLabel: dateLabel ?? this.dateLabel,
        startDay: startDay ?? this.startDay,
        endDay: endDay ?? this.endDay,
        pov: pov ?? this.pov,
        plotline: plotline ?? this.plotline,
        presentCharacters: presentCharacters ?? this.presentCharacters,
        location: location ?? this.location,
        travelDaysFromPrevious:
            travelDaysFromPrevious ?? this.travelDaysFromPrevious,
        linkedNote: linkedNote ?? this.linkedNote,
        plotBeat: plotBeat ?? this.plotBeat,
        status: status ?? this.status,
        importance: importance ?? this.importance,
        type: type ?? this.type,
        eraId: eraId ?? this.eraId,
        sequenceId: sequenceId ?? this.sequenceId,
        order: order ?? this.order,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dateLabel': dateLabel,
        'startDay': startDay,
        'endDay': endDay,
        'pov': pov,
        'plotline': plotline,
        'presentCharacters': presentCharacters,
        'location': location,
        'travelDaysFromPrevious': travelDaysFromPrevious,
        'linkedNote': linkedNote,
        'plotBeat': plotBeat,
        'status': status,
        'importance': importance,
        'type': type,
        'eraId': eraId,
        'sequenceId': sequenceId,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    final createdAt = _date(json['createdAt']);
    return TimelineEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Event',
      description: json['description'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? '',
      startDay: _integer(json['startDay'], fallback: 1),
      endDay: _integer(json['endDay'], fallback: 1),
      pov: json['pov'] as String? ?? '',
      plotline: json['plotline'] as String? ?? 'Main Plot',
      presentCharacters: _strings(json['presentCharacters']),
      location: json['location'] as String? ?? '',
      travelDaysFromPrevious: _integer(json['travelDaysFromPrevious']),
      linkedNote: json['linkedNote'] as String? ?? '',
      plotBeat: json['plotBeat'] as String? ?? '',
      status: json['status'] as String? ?? 'Planned',
      importance: json['importance'] as String? ?? 'Medium',
      type: json['type'] as String? ?? 'Plot',
      eraId: json['eraId'] as String? ?? '',
      sequenceId: json['sequenceId'] as String? ?? '',
      order: _integer(json['order']),
      createdAt: createdAt,
      updatedAt: _date(json['updatedAt'], fallback: createdAt),
    );
  }
}

class TimelineState {
  const TimelineState({
    required this.eras,
    required this.sequences,
    required this.events,
  });

  final List<TimelineEra> eras;
  final List<TimelineSequence> sequences;
  final List<TimelineEvent> events;

  Map<String, Object> toJson() => {
        'eras': eras.map((era) => era.toJson()).toList(),
        'sequences': sequences.map((sequence) => sequence.toJson()).toList(),
        'events': events.map((event) => event.toJson()).toList(),
      };

  factory TimelineState.fromJson(Map<String, dynamic> json) => TimelineState(
        eras: _maps(json['eras']).map(TimelineEra.fromJson).toList(),
        sequences:
            _maps(json['sequences']).map(TimelineSequence.fromJson).toList(),
        events: _maps(json['events']).map(TimelineEvent.fromJson).toList(),
      );
}

class TimelineStore {
  const TimelineStore();

  String _key(String projectId) => 'author_studio.project.$projectId.timeline';

  Future<TimelineState> load(StarterProject project) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(project.id));
    if (encoded == null) {
      return createStarterState(project);
    }

    try {
      return TimelineState.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      return createStarterState(project);
    } on TypeError {
      return createStarterState(project);
    }
  }

  Future<void> save(String projectId, TimelineState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(projectId), jsonEncode(state.toJson()));
  }

  TimelineState createStarterState(StarterProject project) {
    final now = DateTime.now();
    final template = project.templateName.trim().isNotEmpty &&
            StoryTemplateLibrary.templateFor(project.templateName) != null
        ? StoryTemplateLibrary.templateFor(project.templateName)
        : null;
    final defaultSceneName = 'Opening Catalyst';
    final firstCharacter = project.characterSheets.isEmpty
        ? ''
        : project.characterSheets.first.name;
    final firstBeat =
        project.beatChecklist.isEmpty ? '' : project.beatChecklist.first;
    final secondBeat =
        project.beatChecklist.length > 1 ? project.beatChecklist[1] : '';
    final sceneSuggestions = template?.sceneSuggestions ??
        const [
          'Opening Scene',
          'Rising Tension',
          'The Pivot',
          'The Pressure Mounts',
          'The Turn',
          'The Resolution',
        ];
    final arcNames = template?.arcNames ?? const ['Main Plot', 'Character Arc'];

    return TimelineState(
      eras: [
        TimelineEra(
          id: 'era_1',
          title: 'Act I - Setup',
          status: 'Established',
          description: 'Setup arc and normal world.',
          createdAt: now.subtract(const Duration(days: 7)),
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
        TimelineEra(
          id: 'era_2',
          title: 'Act II - Conflict',
          status: 'Planned',
          description: 'Escalation and midpoint changes.',
          createdAt: now.subtract(const Duration(days: 6)),
          updatedAt: now.subtract(const Duration(hours: 12)),
        ),
      ],
      sequences: [
        TimelineSequence(
          id: 'seq_1',
          title: 'Inciting Sequence',
          status: 'Planned',
          description: 'Catalyst and commitment beats.',
          eraId: 'era_1',
          order: 1,
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(hours: 6)),
        ),
        TimelineSequence(
          id: 'seq_2',
          title: 'Reversal Sequence',
          status: 'Planned',
          description: 'Complications after midpoint.',
          eraId: 'era_2',
          order: 2,
          createdAt: now.subtract(const Duration(days: 4)),
          updatedAt: now.subtract(const Duration(hours: 5)),
        ),
      ],
      events: [
        TimelineEvent(
          id: 'event_1',
          title: sceneSuggestions.isNotEmpty
              ? (sceneSuggestions.first == 'Opening Scene'
                  ? defaultSceneName
                  : sceneSuggestions.first)
              : defaultSceneName,
          description: 'The inciting event that pushes the protagonist to act.',
          dateLabel: 'Day 1',
          startDay: 1,
          endDay: 1,
          pov: firstCharacter,
          plotline: arcNames.isNotEmpty ? arcNames.first : 'Main Plot',
          presentCharacters: [if (firstCharacter.isNotEmpty) firstCharacter],
          location: 'Opening location',
          travelDaysFromPrevious: 0,
          linkedNote: 'Opening stakes',
          plotBeat: firstBeat,
          status: 'Planned',
          importance: 'High',
          type: 'Plot',
          eraId: 'era_1',
          sequenceId: 'seq_1',
          order: 1,
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(hours: 8)),
        ),
        TimelineEvent(
          id: 'event_2',
          title: sceneSuggestions.length > 1
              ? sceneSuggestions[1]
              : 'World Rule Revealed',
          description: 'A key discovery defines the stakes of the setting.',
          dateLabel: 'Day 4',
          startDay: 4,
          endDay: 4,
          pov: firstCharacter,
          plotline: arcNames.length > 1
              ? arcNames[1]
              : (arcNames.isNotEmpty ? arcNames.first : 'World Arc'),
          presentCharacters: [if (firstCharacter.isNotEmpty) firstCharacter],
          location: 'Discovery site',
          travelDaysFromPrevious: 2,
          linkedNote: 'World rule reference',
          plotBeat: secondBeat,
          status: 'Established',
          importance: 'Critical',
          type: 'World',
          eraId: 'era_2',
          sequenceId: 'seq_2',
          order: 2,
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(hours: 3)),
        ),
      ],
    );
  }
}

DateTime _date(Object? value, {DateTime? fallback}) =>
    DateTime.tryParse(value as String? ?? '') ??
    fallback ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

int _integer(Object? value, {int fallback = 0}) =>
    value is int ? value : int.tryParse('$value') ?? fallback;

List<String> _strings(Object? value) => value is List
    ? value.whereType<Object>().map((item) => '$item').toList()
    : <String>[];

Iterable<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from)
    : const <Map<String, dynamic>>[];
