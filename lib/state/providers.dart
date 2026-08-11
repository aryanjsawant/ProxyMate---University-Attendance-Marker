import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../logic/attendance.dart' as engine;
import '../logic/dates.dart';
import '../logic/notifications.dart';
import '../logic/schedule.dart';
import '../logic/stats.dart';
import '../models/app_state.dart';
import '../models/models.dart';

final storeProvider = Provider<Store>((ref) => Store());

/// Wall clock, bumped on resume and once a minute, so a class flips from
/// "upcoming" to marked without the user pulling to refresh.
final clockProvider = StateProvider<DateTime>((ref) => DateTime.now());

final appProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  @override
  AppState build() => const AppState();

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Read the save file, then immediately replay the calendar so the app is
  /// already correct by the time the first frame renders.
  Future<void> hydrate() async {
    final saved = await ref.read(storeProvider).load();
    state = saved ?? const AppState();
    _loaded = true;
    refreshNow();

    // Re-arm the alarms on every launch. They were previously only scheduled
    // when the timetable or settings changed, so anything that cleared them —
    // a force-stop, an app update, an OEM battery sweep, or simply the initial
    // schedule failing — left the user with no notifications and no way to
    // recover short of editing their timetable. Rescheduling is idempotent and
    // costs a handful of alarm registrations.
    if (state.isConfigured) {
      unawaited(Notifications.instance.reschedule(state));
    }
  }

  /// Run catch-up against the current time. Cheap and idempotent, so it is safe
  /// to call on every resume.
  void refreshNow() {
    final now = DateTime.now();
    ref.read(clockProvider.notifier).state = now;
    final next = engine.catchUp(state, now);
    if (!identical(next, state)) _commit(next);
  }

  /// [checkRisk] gates the danger-alert comparison, which costs two full
  /// expansions of the remaining term. Only marking can *lower* attendance —
  /// catch-up and settings edits never can — so paying for it on every commit
  /// would triple the work behind an ordinary tap for nothing.
  void _commit(AppState next, {bool checkRisk = false}) {
    final before = state;
    state = next;

    // Fire-and-forget: the in-memory state is the source of truth for the UI,
    // and a failed write must never block a tap.
    ref.read(storeProvider).save(next);

    if (checkRisk) {
      // Because presence is assumed, attendance can only fall when the user
      // marks an absence — so checking here catches every crossing below
      // target with no background job at all.
      Notifications.instance.warnIfCrossed(before, next);
    }
  }

  // ---- setup ---------------------------------------------------------------

  void applyImportedTimetable(AppState imported) => _commit(imported);

  /// Finishes onboarding. The timetable may be empty — skipping it during setup
  /// is explicitly supported, so nothing here may assume slots exist.
  void completeSetup({required Term term, List<Subject>? subjects}) {
    final configured = state.copyWith(
      term: term,
      subjects: subjects ?? state.subjects,
      lastGeneratedDate: dateOnly(term.startDate),
    );
    _commit(engine.catchUp(configured, DateTime.now()));

    // Ask for the permission only once the user has committed to a term —
    // prompting on first launch, before they've seen anything, is how apps get
    // their notifications denied.
    Notifications.instance.requestPermission().then(
      (_) => Notifications.instance.reschedule(state),
    );
  }

  void updateTerm(Term term) => _commit(state.copyWith(term: term));

  void updateSettings(Settings s) => _commit(state.copyWith(settings: s));

  void setTargetForSubject(String subjectId, double target) => _commit(
    state.copyWith(
      subjects: [
        for (final s in state.subjects)
          if (s.id == subjectId) s.copyWith(targetPercent: target) else s,
      ],
    ),
  );

  // ---- subjects ------------------------------------------------------------

  void upsertSubject(Subject subject) {
    final exists = state.subjects.any((s) => s.id == subject.id);
    _commit(
      state.copyWith(
        subjects: exists
            ? [
                for (final s in state.subjects)
                  if (s.id == subject.id) subject else s,
              ]
            : [...state.subjects, subject],
      ),
    );
  }

  /// Deleting a subject cascades to its timetable slots and its attendance
  /// history. Leaving orphaned records behind would keep them in the maths
  /// while being invisible and un-editable in the UI — worse than losing them,
  /// because the numbers would silently be wrong.
  ///
  /// The confirm dialog shows both counts before this is called.
  void deleteSubject(String subjectId) => _commit(
    state.copyWith(
      subjects: [
        for (final s in state.subjects)
          if (s.id != subjectId) s,
      ],
      slots: [
        for (final s in state.slots)
          if (s.subjectId != subjectId) s,
      ],
      records: [
        for (final r in state.records)
          if (r.subjectId != subjectId) r,
      ],
    ),
  );

  // ---- marking -------------------------------------------------------------

  void setOccurrenceStatus(Occurrence occ, Status status) => _commit(
    engine.setOccurrenceStatus(state, occ, status),
    checkRisk: true,
  );

  void setOccurrenceUnits(Occurrence occ, int units) {
    final existing = engine.recordForOccurrence(state, occ);
    final status = existing?.status ?? Status.present;
    _commit(
      engine.setOccurrenceStatus(state, occ, status, units: units),
      checkRisk: true,
    );
  }

  void updateRecord(AttendanceRecord r) =>
      _commit(engine.replaceRecord(state, r), checkRisk: true);

  void deleteRecord(String id) =>
      _commit(engine.deleteRecord(state, id), checkRisk: true);

  void addExtraClass({
    required String subjectId,
    required DateTime date,
    Status status = Status.present,
    int units = 1,
    String? note,
  }) => _commit(
    engine.addExtraClass(
      state,
      subjectId: subjectId,
      date: date,
      status: status,
      units: units,
      note: note,
    ),
    checkRisk: true,
  );

  void markWholeDay(DateTime date, Status status) =>
      _commit(engine.markWholeDay(state, date, status), checkRisk: true);

  void markRangeAsNoClass(DateTime from, DateTime to) =>
      _commit(engine.markRangeAsNoClass(state, from, to));

  // ---- timetable editing ---------------------------------------------------

  void upsertSlot(Slot slot) {
    final exists = state.slots.any((s) => s.id == slot.id);
    _commit(
      state.copyWith(
        slots: exists
            ? [
                for (final s in state.slots)
                  if (s.id == slot.id) slot else s,
              ]
            : [...state.slots, slot],
      ),
    );
  }

  void deleteSlot(String slotId) => _commit(
    state.copyWith(
      slots: [
        for (final s in state.slots)
          if (s.id != slotId) s,
      ],
    ),
  );

  /// Copy every slot from one weekday onto another — the single biggest
  /// time-saver when entering a timetable by hand.
  void copyDay(int fromWeekday, int toWeekday) {
    final source = state.slots.where((s) => s.weekday == fromWeekday);
    final kept = state.slots.where((s) => s.weekday != toWeekday);
    _commit(
      state.copyWith(
        slots: [
          ...kept,
          for (final s in source)
            s.copyWith(weekday: toWeekday).withId(newId('s-')),
        ],
      ),
    );
  }

  Future<void> resetEverything() async {
    _commit(const AppState());
  }
}

extension on Slot {
  /// copyWith deliberately can't change id (ids are identity), so cloning a
  /// slot onto another day needs this.
  Slot withId(String newIdValue) => Slot(
    id: newIdValue,
    subjectId: subjectId,
    weekday: weekday,
    startMin: startMin,
    endMin: endMin,
    room: room,
  );
}

// ---- derived state ---------------------------------------------------------

/// Today's classes, timed ones in order and untimed ones after.
final todayProvider = Provider<List<Occurrence>>((ref) {
  final s = ref.watch(appProvider);
  final now = ref.watch(clockProvider);
  return occurrencesOn(s, now);
});

/// Every subject, most-at-risk first.
final allStatsProvider = Provider<List<SubjectStats>>((ref) {
  final s = ref.watch(appProvider);
  final now = ref.watch(clockProvider);
  return allStats(s, now: now);
});

final statsForProvider = Provider.family<SubjectStats, String>((
  ref,
  subjectId,
) {
  final s = ref.watch(appProvider);
  final now = ref.watch(clockProvider);
  return statsFor(s, subjectId, now: now);
});
