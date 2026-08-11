import '../models/app_state.dart';
import '../models/models.dart';
import 'dates.dart';

/// One concrete class on one concrete date, expanded from the repeating weekly
/// timetable. Occurrences are never stored — they are derived on demand and
/// only become durable once the catch-up engine writes an [AttendanceRecord].
class Occurrence {
  final DateTime date;
  final Slot slot;
  final Period startPeriod;
  final Period endPeriod;

  const Occurrence({
    required this.date,
    required this.slot,
    required this.startPeriod,
    required this.endPeriod,
  });

  DateTime get startsAt =>
      DateTime(date.year, date.month, date.day, 0, startPeriod.startMin);

  DateTime get endsAt =>
      DateTime(date.year, date.month, date.day, 0, endPeriod.endMin);

  bool hasElapsedAt(DateTime now) => !now.isBefore(endsAt);

  String get timeRange =>
      '${formatMinutes(startPeriod.startMin)} – ${formatMinutes(endPeriod.endMin)}';

  /// Stable identity of a scheduled class, used to test "does a record already
  /// exist for this?" without storing occurrences.
  String get key => '${dateKey(date)}#${slot.id}';
}

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

/// Every enrolled class scheduled on [date], sorted by start time.
///
/// Slots belonging to the elective the user did *not* take generate nothing —
/// this is what turns the shared class timetable into a personal one.
List<Occurrence> occurrencesOn(AppState s, DateTime date) {
  if (!isTeachingDay(s, date)) return const [];
  final d = dateOnly(date);
  final out = <Occurrence>[];

  for (final slot in s.slots) {
    if (slot.weekday != d.weekday) continue;
    if (!s.isSlotActive(slot)) continue;

    final start = s.periodByIndex(slot.periodIndex);
    final end = s.periodByIndex(slot.periodIndex + slot.spanPeriods - 1);
    if (start == null || end == null) continue; // timetable references a period that no longer exists

    out.add(
      Occurrence(date: d, slot: slot, startPeriod: start, endPeriod: end),
    );
  }

  out.sort((a, b) => a.startPeriod.startMin.compareTo(b.startPeriod.startMin));
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

/// Units still to come for every component in **one** expansion of the rest of
/// the term, keyed by component id.
///
/// Doing this per-component instead would re-walk every remaining day of the
/// semester once per subject — around ten times the work on every rebuild, on
/// the kind of phone this app is meant for.
///
/// Returns an empty map when the term has no end date; callers distinguish
/// "nothing left" from "cannot project" via [AppState.term].
Map<String, int> remainingUnitsByComponent(AppState s, DateTime from) {
  final end = s.term?.endDate;
  if (end == null) return const {};

  final existing = <String>{
    for (final r in s.records)
      if (r.slotId != null) '${dateKey(r.date)}#${r.slotId}',
  };

  final out = <String, int>{};
  for (final occ in expandSlots(s, from, end)) {
    if (existing.contains(occ.key)) continue;
    out.update(
      occ.slot.componentId,
      (v) => v + occ.slot.units,
      ifAbsent: () => occ.slot.units,
    );
  }
  return out;
}

/// Units still to come for one component. Returns null when the term has no end
/// date — the honest answer, since nothing downstream can be projected without
/// one.
int? remainingUnits(AppState s, String componentId, DateTime from) {
  if (s.term?.endDate == null) return null;
  return remainingUnitsByComponent(s, from)[componentId] ?? 0;
}

