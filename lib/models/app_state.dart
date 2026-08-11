import 'package:flutter/foundation.dart';

import '../logic/dates.dart';
import 'models.dart';

/// The entire app in one immutable object. It serializes to a single JSON
/// document which is simultaneously the save file and the export format, so
/// backup/restore is free.
@immutable
class AppState {
  static const int schemaVersion = 1;

  final Term? term;
  final List<Period> periods;
  final List<Course> courses;
  final List<Component> components;
  final List<Slot> slots;
  final List<AttendanceRecord> records;

  /// Course ids the user is actually taking. Slots whose course is not in here
  /// generate nothing — this is what turns a shared *class* timetable into a
  /// personal one.
  final Set<String> enrolledCourseIds;

  /// Which lab batch the student is in, matched against [Slot.batch]. Null when
  /// the timetable has no batch-split slots.
  final String? selectedBatch;

  /// Last date the catch-up engine has walked to, so reopening after a week
  /// backfills from the right place.
  final DateTime? lastGeneratedDate;

  final Settings settings;

  const AppState({
    this.term,
    this.periods = const [],
    this.courses = const [],
    this.components = const [],
    this.slots = const [],
    this.records = const [],
    this.enrolledCourseIds = const {},
    this.selectedBatch,
    this.lastGeneratedDate,
    this.settings = const Settings(),
  });

  bool get isConfigured => term != null && slots.isNotEmpty;

  // ---- lookups -------------------------------------------------------------

  Course? courseById(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  Component? componentById(String id) {
    for (final c in components) {
      if (c.id == id) return c;
    }
    return null;
  }

  Slot? slotById(String id) {
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }

  Period? periodByIndex(int i) {
    for (final p in periods) {
      if (p.index == i) return p;
    }
    return null;
  }

  Course? courseForComponent(String componentId) {
    final comp = componentById(componentId);
    return comp == null ? null : courseById(comp.courseId);
  }

  /// A component counts only if its course is enrolled.
  bool isComponentEnrolled(String componentId) {
    final comp = componentById(componentId);
    return comp != null && enrolledCourseIds.contains(comp.courseId);
  }

  /// A slot applies to this student only if they take the course *and* are in
  /// the batch it was scheduled for.
  bool isSlotActive(Slot s) =>
      isComponentEnrolled(s.componentId) &&
      (s.batch == null || s.batch == selectedBatch);

  List<Component> get enrolledComponents =>
      components.where((c) => enrolledCourseIds.contains(c.courseId)).toList();

  List<Slot> get enrolledSlots => slots.where(isSlotActive).toList();

  /// Distinct batch labels the timetable defines, for the setup wizard.
  List<String> get availableBatches {
    final out = <String>{};
    for (final s in slots) {
      if (s.batch != null) out.add(s.batch!);
    }
    final list = out.toList()..sort();
    return list;
  }

  /// Both sides of every elective pair, grouped. Used by the setup wizard.
  Map<String, List<Course>> get electiveGroups {
    final out = <String, List<Course>>{};
    for (final c in courses) {
      final g = c.electiveGroup;
      if (g != null) (out[g] ??= []).add(c);
    }
    return out;
  }

  AppState copyWith({
    Term? term,
    List<Period>? periods,
    List<Course>? courses,
    List<Component>? components,
    List<Slot>? slots,
    List<AttendanceRecord>? records,
    Set<String>? enrolledCourseIds,
    String? selectedBatch,
    DateTime? lastGeneratedDate,
    Settings? settings,
  }) => AppState(
    term: term ?? this.term,
    periods: periods ?? this.periods,
    courses: courses ?? this.courses,
    components: components ?? this.components,
    slots: slots ?? this.slots,
    records: records ?? this.records,
    enrolledCourseIds: enrolledCourseIds ?? this.enrolledCourseIds,
    selectedBatch: selectedBatch ?? this.selectedBatch,
    lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
    settings: settings ?? this.settings,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    if (term != null) 'term': term!.toJson(),
    'periods': periods.map((e) => e.toJson()).toList(),
    'courses': courses.map((e) => e.toJson()).toList(),
    'components': components.map((e) => e.toJson()).toList(),
    'slots': slots.map((e) => e.toJson()).toList(),
    'records': records.map((e) => e.toJson()).toList(),
    'enrolledCourseIds': enrolledCourseIds.toList()..sort(),
    if (selectedBatch != null) 'selectedBatch': selectedBatch,
    if (lastGeneratedDate != null) 'lastGeneratedDate': dateKey(lastGeneratedDate!),
    'settings': settings.toJson(),
  };

  factory AppState.fromJson(Map<String, dynamic> j) => AppState(
    term: j['term'] == null
        ? null
        : Term.fromJson(j['term'] as Map<String, dynamic>),
    periods: _list(j['periods'], Period.fromJson),
    courses: _list(j['courses'], Course.fromJson),
    components: _list(j['components'], Component.fromJson),
    slots: _list(j['slots'], Slot.fromJson),
    records: _list(j['records'], AttendanceRecord.fromJson),
    enrolledCourseIds: ((j['enrolledCourseIds'] as List?) ?? const [])
        .map((e) => e as String)
        .toSet(),
    selectedBatch: j['selectedBatch'] as String?,
    lastGeneratedDate: j['lastGeneratedDate'] == null
        ? null
        : parseDateKey(j['lastGeneratedDate'] as String),
    settings: j['settings'] == null
        ? const Settings()
        : Settings.fromJson(j['settings'] as Map<String, dynamic>),
  );

  static List<T> _list<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) fromJson,
  ) => ((raw as List?) ?? const [])
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();
}

@immutable
class Settings {
  /// Minutes after the last class of the day to fire the confirm nudge.
  final int nudgeOffsetMinutes;
  final bool nudgeEnabled;
  final bool weeklySummaryEnabled;

  const Settings({
    this.nudgeOffsetMinutes = 30,
    this.nudgeEnabled = true,
    this.weeklySummaryEnabled = true,
  });

  Settings copyWith({
    int? nudgeOffsetMinutes,
    bool? nudgeEnabled,
    bool? weeklySummaryEnabled,
  }) => Settings(
    nudgeOffsetMinutes: nudgeOffsetMinutes ?? this.nudgeOffsetMinutes,
    nudgeEnabled: nudgeEnabled ?? this.nudgeEnabled,
    weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
  );

  Map<String, dynamic> toJson() => {
    'nudgeOffsetMinutes': nudgeOffsetMinutes,
    'nudgeEnabled': nudgeEnabled,
    'weeklySummaryEnabled': weeklySummaryEnabled,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    nudgeOffsetMinutes: j['nudgeOffsetMinutes'] as int? ?? 30,
    nudgeEnabled: j['nudgeEnabled'] as bool? ?? true,
    weeklySummaryEnabled: j['weeklySummaryEnabled'] as bool? ?? true,
  );
}
