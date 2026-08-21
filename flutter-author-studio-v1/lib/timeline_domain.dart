enum TimelinePrecision { exact, approximate, range, relative, unknown }

class TimelineDate {
  const TimelineDate({
    required this.calendarId,
    this.era,
    this.year,
    this.month,
    this.day,
    this.time,
    this.timeZone,
    this.precision = TimelinePrecision.exact,
    this.approximate = false,
    this.displayFormat,
  });

  final String calendarId;
  final String? era;
  final int? year;
  final int? month;
  final int? day;
  final String? time;
  final String? timeZone;
  final TimelinePrecision precision;
  final bool approximate;
  final String? displayFormat;

  bool get isDated => year != null;

  Map<String, Object?> toJson() => {
        'calendarId': calendarId,
        'era': era,
        'year': year,
        'month': month,
        'day': day,
        'time': time,
        'timeZone': timeZone,
        'precision': precision.name,
        'approximate': approximate,
        'displayFormat': displayFormat,
      };

  factory TimelineDate.fromJson(Map<String, Object?> json) => TimelineDate(
        calendarId: json['calendarId'] as String? ?? '',
        era: json['era'] as String?,
        year: json['year'] as int?,
        month: json['month'] as int?,
        day: json['day'] as int?,
        time: json['time'] as String?,
        timeZone: json['timeZone'] as String?,
        precision: TimelinePrecision.values.firstWhere(
          (value) => value.name == json['precision'],
          orElse: () => TimelinePrecision.unknown,
        ),
        approximate: json['approximate'] as bool? ?? false,
        displayFormat: json['displayFormat'] as String?,
      );
}

class TimelineDateRange {
  const TimelineDateRange({this.start, this.end});

  final TimelineDate? start;
  final TimelineDate? end;

  Map<String, Object?> toJson() => {
        'start': start?.toJson(),
        'end': end?.toJson(),
      };
}

class RelativeTimelineDate {
  const RelativeTimelineDate({
    required this.anchorRecordId,
    required this.relation,
    this.offset = 0,
    this.unit = 'day',
    this.description = '',
  });

  final String anchorRecordId;
  final String relation;
  final int offset;
  final String unit;
  final String description;

  Map<String, Object?> toJson() => {
        'anchorRecordId': anchorRecordId,
        'relation': relation,
        'offset': offset,
        'unit': unit,
        'description': description,
      };
}

class TimelineCalendarMonth {
  const TimelineCalendarMonth({required this.name, required this.length});

  final String name;
  final int length;

  Map<String, Object?> toJson() => {'name': name, 'length': length};
}

class TimelineCalendar {
  const TimelineCalendar({
    required this.id,
    required this.name,
    required this.months,
    this.weekDays = const [],
    this.eraNames = const [],
    this.epoch = const {},
    this.dateFormat = '{year}-{month}-{day}',
    this.hasYearZero = true,
    this.yearsCountBackward = false,
    this.conversionMetadata = const {},
  });

  final String id;
  final String name;
  final List<TimelineCalendarMonth> months;
  final List<String> weekDays;
  final List<String> eraNames;
  final Map<String, Object?> epoch;
  final String dateFormat;
  final bool hasYearZero;
  final bool yearsCountBackward;
  final Map<String, Object?> conversionMetadata;

  int get yearLength => months.fold(0, (sum, month) => sum + month.length);

  int ordinal(TimelineDate date) {
    validate(date);
    final year = date.year!;
    final normalizedYear = hasYearZero || year < 0 ? year : year - 1;
    final yearOffset = yearsCountBackward ? -normalizedYear : normalizedYear;
    final precedingMonths = date.month == null
        ? 0
        : months.take(date.month! - 1).fold<int>(
              0,
              (sum, month) => sum + month.length,
            );
    return yearOffset * yearLength + precedingMonths + (date.day ?? 1) - 1;
  }

  /// Renders [date] through this calendar's [dateFormat] template.
  ///
  /// `{year}`, `{month}`, `{day}`, `{monthName}`, `{era}` and `{time}`
  /// placeholders resolve from the date; components the date does not carry
  /// collapse cleanly instead of printing placeholders. An explicit
  /// [TimelineDate.displayFormat] on the date wins over the calendar template.
  String format(TimelineDate date) {
    if (!date.isDated) return 'Undated';
    final monthName =
        date.month != null && date.month! >= 1 && date.month! <= months.length
            ? months[date.month! - 1].name
            : '';
    var text = date.displayFormat ?? dateFormat;
    final replacements = <String, String>{
      '{year}': '${date.year}',
      '{month}': date.month == null ? '' : '${date.month}',
      '{monthName}': monthName,
      '{day}': date.day == null ? '' : '${date.day}',
      '{era}': date.era ?? '',
      '{time}': date.time ?? '',
    };
    replacements.forEach((token, value) {
      text = text.replaceAll(token, value);
    });
    // Collapse separators left behind by missing components.
    text = text
        .replaceAll(RegExp(r'[-/.,:\s]+$'), '')
        .replaceAll(RegExp(r'(--)+'), '-')
        .trim();
    if (text.isEmpty) return 'Year ${date.year}';
    return date.approximate ? '~$text' : text;
  }

  void validate(TimelineDate date) {
    if (date.calendarId != id) {
      throw ArgumentError('Date uses ${date.calendarId}, not calendar $id.');
    }
    if (!date.isDated) return;
    if (!hasYearZero && date.year == 0) {
      throw ArgumentError('Calendar $id does not have year zero.');
    }
    final month = date.month;
    if (month != null && (month < 1 || month > months.length)) {
      throw ArgumentError('Month $month is invalid for calendar $id.');
    }
    final day = date.day;
    if (day != null) {
      if (month == null) {
        throw ArgumentError('A day requires a month.');
      }
      if (day < 1 || day > months[month - 1].length) {
        throw ArgumentError('Day $day is invalid for month $month.');
      }
    }
  }

  Map<String, Object?> toFields() => {
        'summary': name,
        'months': months.map((month) => month.toJson()).toList(),
        'weekStructure': weekDays,
        'yearLength': yearLength,
        'eraNames': eraNames,
        'epoch': [if (epoch.isNotEmpty) epoch],
        'dateFormat': dateFormat,
        'hasYearZero': hasYearZero,
        'yearDirection': yearsCountBackward ? 'backward' : 'forward',
        'conversionMetadata': [
          if (conversionMetadata.isNotEmpty) conversionMetadata,
        ],
      };
}

class TimelineValidationIssue {
  const TimelineValidationIssue({
    required this.code,
    required this.message,
    this.isError = true,
  });

  final String code;
  final String message;
  final bool isError;
}
