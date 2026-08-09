import '../models/app_state.dart';
import '../models/models.dart';
import 'dates.dart';
import 'schedule.dart';

/// The heart of the app: **presence is assumed, absence is the exception.**
///
/// There is deliberately no background execution. Android OEMs (Xiaomi, Oppo,
/// Vivo, Realme) aggressively kill background tasks, so a background job would
/// make attendance silently wrong — the exact failure this app exists to
/// prevent. Instead every launch and every resume replays the calendar.
///
/// Two invariants carry the whole design:
///
///  1. **Manual always wins.** Generation only ever *inserts where nothing
///     exists*. It never updates or overwrites, so marking yourself absent is
///     permanent — whether you did it before or after the class.
///  2. **Never mark a class that hasn't happened.** Only slots whose end time
///     has passed are materialised; today's later classes stay projected.
///
/// Together these make "don't open the app for a week" correct by
/// construction: reopening backfills every elapsed slot as present, which is
/// exactly what the user meant by not opening it.
AppState catchUp(AppState state, DateTime now) {
  final term = state.term;
  if (term == null) return state;

  final today = dateOnly(now);
  final from = dateOnly(state.lastGeneratedDate ?? term.startDate);
  if (from.isAfter(today)) return state;

  final existing = <String>{
    for (final r in state.records)
      if (r.slotId != null) '${dateKey(r.date)}#${r.slotId}',
  };

  final added = <AttendanceRecord>[];
  for (final day in eachDay(from, today)) {
    for (final occ in occurrencesOn(state, day)) {
      if (!occ.hasElapsedAt(now)) continue;
      if (existing.contains(occ.key)) continue;

      added.add(
        AttendanceRecord(
          id: newId('r-'),
          componentId: occ.slot.componentId,
          date: day,
          slotId: occ.slot.id,
          status: Status.present,
          units: occ.slot.units,
          isManual: false,
        ),
      );
      existing.add(occ.key);
    }
  }

  // lastGeneratedDate stays at *today*, not tomorrow, so the rest of today's
  // classes get picked up on the next run rather than being skipped forever.
  if (added.isEmpty && state.lastGeneratedDate == today) return state;

  return state.copyWith(
    records: [...state.records, ...added],
    lastGeneratedDate: today,
  );
}

/// Find the record backing a scheduled occurrence, if one exists yet.
AttendanceRecord? recordForOccurrence(AppState state, Occurrence occ) {
  for (final r in state.records) {
    if (r.slotId == occ.slot.id && dateOnly(r.date) == occ.date) return r;
  }
  return null;
}

/// Set the status of a scheduled class, creating the record if the class hasn't
/// elapsed yet. Always marks the result as manual so catch-up leaves it alone.
AppState setOccurrenceStatus(
  AppState state,
  Occurrence occ,
  Status status, {
  int? units,
}) {
  final existing = recordForOccurrence(state, occ);
  if (existing != null) {
    return replaceRecord(
      state,
      existing.copyWith(status: status, units: units, isManual: true),
    );
  }
  return state.copyWith(
    records: [
      ...state.records,
      AttendanceRecord(
        id: newId('r-'),
        componentId: occ.slot.componentId,
        date: occ.date,
        slotId: occ.slot.id,
        status: status,
        units: units ?? occ.slot.units,
        isManual: true,
      ),
    ],
  );
}

AppState replaceRecord(AppState state, AttendanceRecord updated) => state
    .copyWith(
      records: [
        for (final r in state.records) if (r.id == updated.id) updated else r,
      ],
    );

AppState deleteRecord(AppState state, String recordId) => state.copyWith(
  records: [
    for (final r in state.records)
      if (r.id != recordId) r,
  ],
);

/// Teachers hold classes that aren't on the timetable. An extra class is just a
/// record with no backing slot, so it counts identically everywhere.
AppState addExtraClass(
  AppState state, {
  required String componentId,
  required DateTime date,
  Status status = Status.present,
  int units = 1,
  String? note,
}) => state.copyWith(
  records: [
    ...state.records,
    AttendanceRecord(
      id: newId('x-'),
      componentId: componentId,
      date: dateOnly(date),
      slotId: null,
      status: status,
      units: units,
      isManual: true,
      note: note,
    ),
  ],
);

/// Every record already written for [date], plus the scheduled occurrences that
/// have no record yet. This is what the day editor and Home render.
({List<Occurrence> scheduled, List<AttendanceRecord> extras}) dayView(
  AppState state,
  DateTime date,
) {
  final d = dateOnly(date);
  final scheduled = occurrencesOn(state, d);
  final extras = [
    for (final r in state.records)
      if (r.slotId == null && dateOnly(r.date) == d) r,
  ];
  return (scheduled: scheduled, extras: extras);
}

/// Mark an entire day cancelled (strike, faculty absent) or a holiday. Applies
/// to every scheduled class that day and is always manual.
AppState markWholeDay(AppState state, DateTime date, Status status) {
  var s = state;
  for (final occ in occurrencesOn(state, date)) {
    s = setOccurrenceStatus(s, occ, status);
  }
  return s;
}

/// Bulk no-class range for mid-semester breaks and festivals. Adds the dates to
/// the term's holiday set so future generation skips them, and clears any
/// records already generated inside the range.
AppState markRangeAsNoClass(AppState state, DateTime from, DateTime to) {
  final term = state.term;
  if (term == null) return state;

  final days = eachDay(from, to).toSet();
  final keep = [
    for (final r in state.records)
      if (!days.contains(dateOnly(r.date))) r,
  ];

  return state.copyWith(
    term: term.copyWith(holidays: {...term.holidays, ...days}),
    records: keep,
  );
}
