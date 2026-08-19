import 'package:flutter/foundation.dart';

import '../logic/dates.dart';

/// **The unit of accounting.** Every percentage, bunk budget, must-attend count
/// and danger alert is computed per Subject and never pooled across them.
///
/// A lab is just another Subject. Colleges track "OS" and "OS Lab" as separate
/// registration lines with separate 75% requirements, so modelling a lab as a
/// child of a course would only invite pooling them — which is exactly the bug
/// that lets a healthy lecture percentage hide a failing lab.
@immutable
class Subject {
  final String id;
  final String name; // "Operating Systems Lab" — whatever the user calls it
  final int color; // ARGB
  final String? faculty; // optional
  final String? room; // optional default; a slot can override

  const Subject({
    required this.id,
    required this.name,
    required this.color,
    this.faculty,
    this.room,
  });

  /// What fits on a crowded row. Long names get their first two words.
  String get shortName {
    final trimmed = name.trim();
    if (trimmed.length <= 18) return trimmed;
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 1) return trimmed;
    final two = words.take(2).join(' ');
    return two.length <= 18 ? two : '${trimmed.substring(0, 17)}…';
  }

  Subject copyWith({
    String? name,
    int? color,
    String? faculty,
    bool clearFaculty = false,
    String? room,
    bool clearRoom = false,
  }) => Subject(
    id: id,
    name: name ?? this.name,
    color: color ?? this.color,
    faculty: clearFaculty ? null : (faculty ?? this.faculty),
    room: clearRoom ? null : (room ?? this.room),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    if (faculty != null) 'faculty': faculty,
    if (room != null) 'room': room,
  };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
    id: j['id'] as String,
    name: j['name'] as String,
    color: j['color'] as int,
    faculty: j['faculty'] as String?,
    room: j['room'] as String?,
  );
}

/// One entry of the repeating weekly timetable: a subject on a weekday, with an
/// optional time.
///
/// **One entry is one attendance.** A subject meeting twice on a Tuesday is two
/// entries, not one entry with a multiplier — which is why there is no period
/// grid, no span and no unit count here. A class that runs two hours is still
/// one entry; length and attendance count are unrelated.
@immutable
class Slot {
  final String id;
  final String subjectId;
  final int weekday; // DateTime.monday..DateTime.sunday (1..7)

  /// Minutes from midnight. Both null means "no time set" — the class still
  /// counts, it just settles at the end of the day instead of when it ends.
  final int? startMin;
  final int? endMin;

  final String? room; // overrides the subject's default

  const Slot({
    required this.id,
    required this.subjectId,
    required this.weekday,
    this.startMin,
    this.endMin,
    this.room,
  });

  bool get isTimed => startMin != null;

  /// Minute at which this class is considered over, and therefore markable.
  /// Untimed classes fall back to the user's configured end of day.
  int effectiveEndMin(int dayEndsAtMin) =>
      endMin ?? startMin ?? dayEndsAtMin;

  /// Sort key: timed classes in time order, untimed ones after them.
  int sortKey(int dayEndsAtMin) => startMin ?? (dayEndsAtMin + 1);

  String get timeLabel {
    if (startMin == null) return 'No time set';
    if (endMin == null) return formatMinutes(startMin!);
    return '${formatMinutes(startMin!)} – ${formatMinutes(endMin!)}';
  }

  Slot copyWith({
    String? subjectId,
    int? weekday,
    int? startMin,
    int? endMin,
    bool clearTime = false,
    bool clearEnd = false,
    String? room,
    bool clearRoom = false,
  }) => Slot(
    id: id,
    subjectId: subjectId ?? this.subjectId,
    weekday: weekday ?? this.weekday,
    startMin: clearTime ? null : (startMin ?? this.startMin),
    endMin: (clearTime || clearEnd) ? null : (endMin ?? this.endMin),
    room: clearRoom ? null : (room ?? this.room),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'weekday': weekday,
    if (startMin != null) 'startMin': startMin,
    if (endMin != null) 'endMin': endMin,
    if (room != null) 'room': room,
  };

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
    id: j['id'] as String,
    subjectId: j['subjectId'] as String,
    weekday: j['weekday'] as int,
    startMin: j['startMin'] as int?,
    endMin: j['endMin'] as int?,
    room: j['room'] as String?,
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
  final String subjectId;
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
    required this.subjectId,
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
    bool clearNote = false,
  }) => AttendanceRecord(
    id: id,
    subjectId: subjectId,
    date: date,
    slotId: slotId,
    status: status ?? this.status,
    units: units ?? this.units,
    isManual: isManual ?? this.isManual,
    note: clearNote ? null : (note ?? this.note),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'subjectId': subjectId,
    'date': dateKey(date),
    if (slotId != null) 'slotId': slotId,
    'status': status.name,
    'units': units,
    'isManual': isManual,
    if (note != null) 'note': note,
  };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    id: j['id'] as String,
    subjectId: j['subjectId'] as String,
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
