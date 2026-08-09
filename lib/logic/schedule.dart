import '../models/app_state.dart';
import '../models/models.dart';
import 'dates.dart';

/// One concrete class on one concrete date, expanded from the repeating weekly
/// timetable. Occurrences are never stored — they are derived on demand and
/// only become durable once the catch-up engine writes an [AttendanceRecord].
class Occurrence {
  final DateTime date;
  final Slot slot;

  /// Minute of the day at which this class counts as over. For a timed class
  /// that's its end (or start, if no end was given); for an untimed one it's
  /// the user's configured end of day.
  final int endMin;

  const Occurrence({
    required this.date,
    required this.slot,
    required this.endMin,
  });

  bool get isTimed => slot.isTimed;

  DateTime? get startsAt => slot.startMin == null
      ? null
      : DateTime(date.year, date.month, date.day, 0, slot.startMin!);

  DateTime get endsAt =>
      DateTime(date.year, date.month, date.day, 0, endMin);

  bool hasElapsedAt(DateTime now) => !now.isBefore(endsAt);

  String get timeLabel => slot.timeLabel;

  /// Stable identity of a scheduled class, used to test "does a record already
  /// exist for this?" without storing occurrences.
  String get key => '${dateKey(date)}#${slot.id}';
}

/// Key used to match an existing record back to the slot that generated it.
String recordKey(AttendanceRecord r) => r.slotId == null
    ? '${dateKey(r.date)}#adhoc:${r.id}'
    : '${dateKey(r.date)}#${r.slotId}';

/// True when [date] is inside the term and is not a holiday.
bool isTeachingDay(AppState s, DateTime date) {
  final term = s.term;
  if (term == null) return false;
  final d = dateOnly(date);
  if (d.isBefore(dateOnly(term.startDate))) return false;
  final end = term.endDate;
  if (end != null && d.isAfter(dateOnly(end))) return false;
  if (term.isHoliday(d)) return false;
  return true;
}

/// Every class scheduled on [date], timed ones in time order and untimed ones
/// after them.
List<Occurrence> occurrencesOn(AppState s, DateTime date) {
  if (!isTeachingDay(s, date)) return const [];
  final d = dateOnly(date);
  final dayEnd = s.settings.dayEndsAtMinutes;
  final out = <Occurrence>[];

  for (final slot in s.slots) {
    if (slot.weekday != d.weekday) continue;
    // A slot whose subject was deleted generates nothing. Deletion cascades,
    // so this guards against a hand-edited import rather than a normal path.
    if (s.subjectById(slot.subjectId) == null) continue;

    out.add(
      Occurrence(
        date: d,
        slot: slot,
        endMin: slot.effectiveEndMin(dayEnd),
      ),
    );
  }

  out.sort((a, b) => a.slot.sortKey(dayEnd).compareTo(b.slot.sortKey(dayEnd)));
  return out;
}

/// All occurrences in [from]..[to] inclusive. Same expansion the catch-up
/// engine uses, so projections and generation can never disagree.
List<Occurrence> expandSlots(AppState s, DateTime from, DateTime to) {
  final out = <Occurrence>[];
  for (final day in eachDay(from, to)) {
    out.addAll(occurrencesOn(s, day));
  }
  return out;
}

/// Classes still to come for every subject in **one** expansion of the rest of
/// the term, keyed by subject id.
///
/// Doing this per-subject instead would re-walk every remaining day of the term
/// once per subject — around ten times the work on every rebuild, on the kind
/// of phone this app is meant for.
///
/// Returns an empty map when the term has no end date; callers distinguish
/// "nothing left" from "cannot project" via [AppState.term].
Map<String, int> remainingUnitsBySubject(AppState s, DateTime from) {
  final end = s.term?.endDate;
  if (end == null) return const {};

  final existing = <String>{
    for (final r in s.records)
      if (r.slotId != null) '${dateKey(r.date)}#${r.slotId}',
  };

  final out = <String, int>{};
  for (final occ in expandSlots(s, from, end)) {
    if (existing.contains(occ.key)) continue;
    // One timetable entry is one attendance, always.
    out.update(occ.slot.subjectId, (v) => v + 1, ifAbsent: () => 1);
  }
  return out;
}

/// Classes still to come for one subject. Returns null when the term has no end
/// date — the honest answer, since nothing downstream can be projected without
/// one.
int? remainingUnits(AppState s, String subjectId, DateTime from) {
  if (s.term?.endDate == null) return null;
  return remainingUnitsBySubject(s, from)[subjectId] ?? 0;
}

/// Classes per week for a subject, for the "how heavy is this subject" line.
int weeklyUnits(AppState s, String subjectId) {
  var total = 0;
  for (final slot in s.slots) {
    if (slot.subjectId == subjectId) total++;
  }
  return total;
}
