import 'package:flutter/foundation.dart';

import '../logic/dates.dart';
import 'models.dart';

/// The entire app in one immutable object. It serializes to a single JSON
/// document which is simultaneously the save file and the export format, so
/// backup/restore is free.
@immutable
class AppState {
  static const int schemaVersion = 2;

  final Term? term;
  final List<Subject> subjects;
  final List<Slot> slots;
  final List<AttendanceRecord> records;

  /// Last date the catch-up engine has walked to, so reopening after a week
  /// backfills from the right place.
  final DateTime? lastGeneratedDate;

  final Settings settings;

  const AppState({
    this.term,
    this.subjects = const [],
    this.slots = const [],
    this.records = const [],
    this.lastGeneratedDate,
    this.settings = const Settings(),
  });

  /// Onboarding is finished once a term exists. A timetable is deliberately
  /// *not* required — you can skip it during setup and add it later, and the
  /// app has to stay coherent in the meantime.
  bool get isConfigured => term != null;

  bool get hasTimetable => slots.isNotEmpty;
  bool get hasSubjects => subjects.isNotEmpty;

  // ---- lookups -------------------------------------------------------------

  Subject? subjectById(String id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  Slot? slotById(String id) {
    for (final s in slots) {
      if (s.id == id) return s;
    }
    return null;
  }

  Subject? subjectForSlot(Slot s) => subjectById(s.subjectId);

  /// Slots whose subject still exists. Deleting a subject cascades to its
  /// slots, so this should normally equal [slots] — it guards against a
  /// hand-edited or partially-migrated import.
  List<Slot> get activeSlots =>
      slots.where((s) => subjectById(s.subjectId) != null).toList();

  int get slotsPerWeek => activeSlots.length;

  List<Slot> slotsForSubject(String subjectId) =>
      slots.where((s) => s.subjectId == subjectId).toList();

  List<AttendanceRecord> recordsForSubject(String subjectId) =>
      records.where((r) => r.subjectId == subjectId).toList();

  AppState copyWith({
    Term? term,
    List<Subject>? subjects,
    List<Slot>? slots,
    List<AttendanceRecord>? records,
    DateTime? lastGeneratedDate,
    bool clearLastGenerated = false,
    Settings? settings,
  }) => AppState(
    term: term ?? this.term,
    subjects: subjects ?? this.subjects,
    slots: slots ?? this.slots,
    records: records ?? this.records,
    lastGeneratedDate: clearLastGenerated
        ? null
        : (lastGeneratedDate ?? this.lastGeneratedDate),
    settings: settings ?? this.settings,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    if (term != null) 'term': term!.toJson(),
    'subjects': subjects.map((e) => e.toJson()).toList(),
    'slots': slots.map((e) => e.toJson()).toList(),
    'records': records.map((e) => e.toJson()).toList(),
    if (lastGeneratedDate != null)
      'lastGeneratedDate': dateKey(lastGeneratedDate!),
    'settings': settings.toJson(),
  };

  factory AppState.fromJson(Map<String, dynamic> j) => AppState(
    term: j['term'] == null
        ? null
        : Term.fromJson(j['term'] as Map<String, dynamic>),
    subjects: _list(j['subjects'], Subject.fromJson),
    slots: _list(j['slots'], Slot.fromJson),
    records: _list(j['records'], AttendanceRecord.fromJson),
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

  /// When an untimed class is considered over, and therefore auto-marked.
  /// Minutes from midnight; defaults to 6 pm.
  final int dayEndsAtMinutes;

  final bool nudgeEnabled;
  final bool weeklySummaryEnabled;

  /// Set once the how-it-works walkthrough has been seen, so it never
  /// reappears — but it stays reachable from More.
  final bool hasSeenWalkthrough;

  const Settings({
    this.nudgeOffsetMinutes = 30,
    this.dayEndsAtMinutes = 18 * 60,
    this.nudgeEnabled = true,
    this.weeklySummaryEnabled = true,
    this.hasSeenWalkthrough = false,
  });

  Settings copyWith({
    int? nudgeOffsetMinutes,
    int? dayEndsAtMinutes,
    bool? nudgeEnabled,
    bool? weeklySummaryEnabled,
    bool? hasSeenWalkthrough,
  }) => Settings(
    nudgeOffsetMinutes: nudgeOffsetMinutes ?? this.nudgeOffsetMinutes,
    dayEndsAtMinutes: dayEndsAtMinutes ?? this.dayEndsAtMinutes,
    nudgeEnabled: nudgeEnabled ?? this.nudgeEnabled,
    weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
    hasSeenWalkthrough: hasSeenWalkthrough ?? this.hasSeenWalkthrough,
  );

  Map<String, dynamic> toJson() => {
    'nudgeOffsetMinutes': nudgeOffsetMinutes,
    'dayEndsAtMinutes': dayEndsAtMinutes,
    'nudgeEnabled': nudgeEnabled,
    'weeklySummaryEnabled': weeklySummaryEnabled,
    'hasSeenWalkthrough': hasSeenWalkthrough,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    nudgeOffsetMinutes: j['nudgeOffsetMinutes'] as int? ?? 30,
    dayEndsAtMinutes: j['dayEndsAtMinutes'] as int? ?? 18 * 60,
    nudgeEnabled: j['nudgeEnabled'] as bool? ?? true,
    weeklySummaryEnabled: j['weeklySummaryEnabled'] as bool? ?? true,
    hasSeenWalkthrough: j['hasSeenWalkthrough'] as bool? ?? false,
  );
}
