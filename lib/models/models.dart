import 'package:flutter/foundation.dart';

import '../logic/dates.dart';

/// One row of the institute's fixed bell schedule. Defined once per install and
/// then referenced by index, so changing a period's timing moves every class
/// anchored to it.
@immutable
class Period {
  final int index; // 1..8
  final int startMin; // minutes from midnight
  final int endMin;

  const Period({
    required this.index,
    required this.startMin,
    required this.endMin,
  });

  String get label => 'P$index';
  String get timeRange => '${formatMinutes(startMin)} – ${formatMinutes(endMin)}';

  Period copyWith({int? index, int? startMin, int? endMin}) => Period(
    index: index ?? this.index,
    startMin: startMin ?? this.startMin,
    endMin: endMin ?? this.endMin,
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'startMin': startMin,
    'endMin': endMin,
  };

  factory Period.fromJson(Map<String, dynamic> j) => Period(
    index: j['index'] as int,
    startMin: j['startMin'] as int,
    endMin: j['endMin'] as int,
  );
}

/// A course as printed in the handbook. Display and grouping only — attendance
/// is never computed at this level, always per [Component].
@immutable
class Course {
  final String id;
  final String name; // "Intro to Large Language Models"
  final String shortName; // "ILLM" — what actually fits on a row
  final String? code; // "AI463"
  final int color; // ARGB
  final String? slotLabel; // 'A'|'B'|'C'|'D'|'E'|'H'

  /// Courses sharing an [electiveGroup] are mutually exclusive: the student
  /// takes exactly one. Null means "everybody takes this".
  final String? electiveGroup;

  final String? faculty;
  final String? venue;
  final String? batch; // "Batch-I" for split lab slots

  const Course({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    this.code,
    this.slotLabel,
    this.electiveGroup,
    this.faculty,
    this.venue,
    this.batch,
  });

  Course copyWith({
    String? name,
    String? shortName,
    String? code,
    int? color,
    String? slotLabel,
    String? electiveGroup,
    String? faculty,
    String? venue,
    String? batch,
  }) => Course(
    id: id,
    name: name ?? this.name,
    shortName: shortName ?? this.shortName,
    code: code ?? this.code,
    color: color ?? this.color,
    slotLabel: slotLabel ?? this.slotLabel,
    electiveGroup: electiveGroup ?? this.electiveGroup,
    faculty: faculty ?? this.faculty,
    venue: venue ?? this.venue,
    batch: batch ?? this.batch,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    if (code != null) 'code': code,
    'color': color,
    if (slotLabel != null) 'slotLabel': slotLabel,
    if (electiveGroup != null) 'electiveGroup': electiveGroup,
    if (faculty != null) 'faculty': faculty,
    if (venue != null) 'venue': venue,
    if (batch != null) 'batch': batch,
  };

  factory Course.fromJson(Map<String, dynamic> j) => Course(
    id: j['id'] as String,
    name: j['name'] as String,
    shortName: j['shortName'] as String? ?? j['name'] as String,
    code: j['code'] as String?,
    color: j['color'] as int,
    slotLabel: j['slotLabel'] as String?,
    electiveGroup: j['electiveGroup'] as String?,
    faculty: j['faculty'] as String?,
    venue: j['venue'] as String?,
    batch: j['batch'] as String?,
  );
}

/// Tutorials deliberately fold into [theory]: for a 3-1-0 course the tutorial
/// sits on the same registration line, so the university enforces one combined
/// percentage. Labs are a separate line and therefore a separate component.
enum ComponentKind { theory, lab }

extension ComponentKindX on ComponentKind {
  String get label => switch (this) {
    ComponentKind.theory => 'Theory',
    ComponentKind.lab => 'Lab',
  };
}

/// **The unit of accounting.** Every percentage, bunk budget, must-attend count
/// and danger alert is computed per Component and never pooled across them.
@immutable
class Component {
  final String id;
  final String courseId;
  final ComponentKind kind;
  final double targetPercent; // 0.75

  const Component({
    required this.id,
    required this.courseId,
    required this.kind,
    this.targetPercent = 0.75,
  });

  Component copyWith({ComponentKind? kind, double? targetPercent}) => Component(
    id: id,
    courseId: courseId,
    kind: kind ?? this.kind,
    targetPercent: targetPercent ?? this.targetPercent,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseId': courseId,
    'kind': kind.name,
    'targetPercent': targetPercent,
  };

  factory Component.fromJson(Map<String, dynamic> j) => Component(
    id: j['id'] as String,
    courseId: j['courseId'] as String,
    kind: ComponentKind.values.byName(j['kind'] as String),
    targetPercent: (j['targetPercent'] as num).toDouble(),
  );
}

/// One cell of the repeating weekly timetable.
@immutable
class Slot {
  final String id;
  final String componentId;
  final int weekday; // DateTime.monday..DateTime.sunday (1..7)
  final int periodIndex; // anchors to Period.index
  final int spanPeriods; // 1 for a lecture, 2 for a lab block

  /// Renders as "Tutorial" and is per-slot, not per-course: Monday's D slot is
  /// a lecture for AI459 but a tutorial for AI461. It does **not** split the
  /// component — both still count into one theory percentage.
  final bool isTutorial;

  /// Set when the class timetable splits this session across lab batches (the
  /// IMAES lab runs Batch-I at 2:00 and Batch-II at 4:00 on the same Monday).
  /// A slot with a batch only applies to the student in that batch; null means
  /// "everyone in the course".
  final String? batch;

  final String? room;
  final int units; // a 2-period lab counts 2

  const Slot({
    required this.id,
    required this.componentId,
    required this.weekday,
    required this.periodIndex,
    this.spanPeriods = 1,
    this.isTutorial = false,
    this.batch,
    this.room,
    int? units,
  }) : units = units ?? spanPeriods;

  Slot copyWith({
    String? componentId,
    int? weekday,
    int? periodIndex,
    int? spanPeriods,
    bool? isTutorial,
    String? batch,
    String? room,
    int? units,
  }) => Slot(
    id: id,
    componentId: componentId ?? this.componentId,
    weekday: weekday ?? this.weekday,
    periodIndex: periodIndex ?? this.periodIndex,
    spanPeriods: spanPeriods ?? this.spanPeriods,
    isTutorial: isTutorial ?? this.isTutorial,
    batch: batch ?? this.batch,
    room: room ?? this.room,
    units: units ?? this.units,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'componentId': componentId,
    'weekday': weekday,
    'periodIndex': periodIndex,
    'spanPeriods': spanPeriods,
    'isTutorial': isTutorial,
    if (batch != null) 'batch': batch,
    if (room != null) 'room': room,
    'units': units,
  };

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    id: j['id'] as String,
    componentId: j['componentId'] as String,
    weekday: j['weekday'] as int,
    periodIndex: j['periodIndex'] as int,
    spanPeriods: j['spanPeriods'] as int? ?? 1,
    isTutorial: j['isTutorial'] as bool? ?? false,
    batch: j['batch'] as String?,
    room: j['room'] as String?,
    units: j['units'] as int?,
  );
}

enum Status { present, absent, cancelled, holiday }

extension StatusX on Status {
  String get label => switch (this) {
    Status.present => 'Present',
    Status.absent => 'Absent',
    Status.cancelled => 'Cancelled',
    Status.holiday => 'Holiday',
  };

  /// Cancelled and holiday sessions never happened, so they leave both the
  /// numerator and the denominator untouched.
  bool get countsTowardHeld => this == Status.present || this == Status.absent;
  bool get countsTowardAttended => this == Status.present;
}

/// Named AttendanceRecord because `Record` is a Dart 3 language feature.
@immutable
class AttendanceRecord {
  final String id;
  final String componentId;
  final DateTime date; // local midnight
  final String? slotId; // null = ad-hoc extra class the teacher added
  final Status status;
  final int units;

  /// Manual always wins: the catch-up engine only ever *inserts where nothing
  /// exists*, so a user edit is permanent.
  final bool isManual;

  final String? note;

  const AttendanceRecord({
    required this.id,
    required this.componentId,
    required this.date,
    required this.status,
    required this.units,
    this.slotId,
    this.isManual = false,
    this.note,
  });

  AttendanceRecord copyWith({
    Status? status,
    int? units,
    bool? isManual,
    String? note,
  }) => AttendanceRecord(
    id: id,
    componentId: componentId,
    date: date,
    slotId: slotId,
    status: status ?? this.status,
    units: units ?? this.units,
    isManual: isManual ?? this.isManual,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'componentId': componentId,
    'date': dateKey(date),
    if (slotId != null) 'slotId': slotId,
    'status': status.name,
    'units': units,
    'isManual': isManual,
    if (note != null) 'note': note,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    id: j['id'] as String,
    componentId: j['componentId'] as String,
    date: parseDateKey(j['date'] as String),
    slotId: j['slotId'] as String?,
    status: Status.values.byName(j['status'] as String),
    units: j['units'] as int,
    isManual: j['isManual'] as bool? ?? false,
    note: j['note'] as String?,
  );
}

@immutable
class Term {
  final String name;
  final DateTime startDate;

  /// Optional. Without it the app still works; it just can't project the
  /// semester total or the "misses left for the whole term" figure.
  final DateTime? endDate;

  final double defaultTarget; // 0.75
  final Set<DateTime> holidays;

  const Term({
    required this.name,
    required this.startDate,
    this.endDate,
    this.defaultTarget = 0.75,
    this.holidays = const {},
  });

  bool isHoliday(DateTime d) => holidays.contains(dateOnly(d));

  Term copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    double? defaultTarget,
    Set<DateTime>? holidays,
  }) => Term(
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    defaultTarget: defaultTarget ?? this.defaultTarget,
    holidays: holidays ?? this.holidays,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'startDate': dateKey(startDate),
    if (endDate != null) 'endDate': dateKey(endDate!),
    'defaultTarget': defaultTarget,
    'holidays': holidays.map(dateKey).toList()..sort(),
  };

  factory Term.fromJson(Map<String, dynamic> j) => Term(
    name: j['name'] as String,
    startDate: parseDateKey(j['startDate'] as String),
    endDate: j['endDate'] == null ? null : parseDateKey(j['endDate'] as String),
    defaultTarget: (j['defaultTarget'] as num?)?.toDouble() ?? 0.75,
    holidays: ((j['holidays'] as List?) ?? const [])
        .map((e) => parseDateKey(e as String))
        .toSet(),
  );
}
