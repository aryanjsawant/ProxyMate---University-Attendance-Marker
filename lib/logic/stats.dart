import '../models/app_state.dart';
import '../models/models.dart';
import 'dates.dart';
import 'schedule.dart';

/// Floating-point guard. Targets like 0.75 make `a / p` land on values such as
/// 39.999999999999996 where the true answer is 40, and a bare `.floor()` would
/// then be off by one — which is the difference between "you can miss 3 more"
/// and "you can miss 2 more" for the rest of the semester.
const _eps = 1e-9;

enum RiskLevel { unknown, safe, warning, danger }

/// Everything the UI needs about one component. Computed per [Component] and
/// never pooled across them, because that is how the university enforces it.
class ComponentStats {
  final String componentId;
  final double target;

  /// All in *units*, so a 2-period lab weighs double automatically.
  final int attended;
  final int held; // present + absent; cancelled/holiday excluded from both
  final int cancelled;

  /// Units still to come before the term ends. Null when no end date is set.
  final int? remaining;

  const ComponentStats({
    required this.componentId,
    required this.target,
    required this.attended,
    required this.held,
    required this.cancelled,
    required this.remaining,
  });

  int get missed => held - attended;
  bool get hasData => held > 0;

  /// Null rather than 0 or 100 when nothing has been held yet — the UI must say
  /// "no classes yet" instead of inventing a number.
  double? get percent => held == 0 ? null : attended / held;

  bool get isAtTarget => hasData && percent! + _eps >= target;

  /// Largest m such that attended / (held + m) >= target.
  int get canMissNow {
    if (held == 0) return 0;
    final v = (attended / target + _eps).floor() - held;
    return v < 0 ? 0 : v;
  }

  /// Smallest n such that (attended + n) / (held + n) >= target.
  /// Zero when already at or above target.
  int get mustAttendNow {
    if (isAtTarget) return 0;
    if (target >= 1) return 0; // guard: 100% target has no finite recovery
    final v = ((target * held - attended) / (1 - target) - _eps).ceil();
    return v < 0 ? 0 : v;
  }

  // ---- projections (need a term end date) ----------------------------------

  int? get projectedTotal => remaining == null ? null : held + remaining!;

  double? get bestAchievable {
    final t = projectedTotal;
    if (t == null || t == 0) return null;
    return (attended + remaining!) / t;
  }

  /// Total further absences affordable across the whole rest of the term.
  int? get canMissRestOfTerm {
    final t = projectedTotal;
    if (t == null) return null;
    final v = (attended + remaining! - target * t + _eps).floor();
    return v < 0 ? 0 : v;
  }

  /// True when even perfect attendance from here can't reach the target.
  bool get isTargetUnreachable {
    final b = bestAchievable;
    return b != null && b + _eps < target;
  }

  /// Extra classes beyond the timetable that would be needed to claw back.
  int? get extraClassesNeeded {
    if (!isTargetUnreachable) return null;
    if (target >= 1) return null;
    final t = projectedTotal!;
    final v = ((target * t - (attended + remaining!)) / (1 - target) - _eps).ceil();
    return v < 0 ? 0 : v;
  }

  RiskLevel get risk {
    if (!hasData) return RiskLevel.unknown;
    final p = percent!;
    if (p + _eps >= target + 0.05) return RiskLevel.safe;
    if (p + _eps >= target) return RiskLevel.warning;
    return RiskLevel.danger;
  }

  /// The single actionable line shown on a card. Deliberately one sentence —
  /// dumping five numbers on a card is what makes other attendance apps read
  /// like spreadsheets.
  String get headline {
    if (!hasData) return 'No classes yet';
    if (isTargetUnreachable) {
      final pct = (bestAchievable! * 100).toStringAsFixed(0);
      return '${_pctLabel(target)} not reachable — best case $pct%';
    }
    if (!isAtTarget) {
      final n = mustAttendNow;
      return 'Attend next $n to reach ${_pctLabel(target)}';
    }
    final n = canMissNow;
    // Note this is *not* the same as "you are exactly at target": early in the
    // term 1/1 is 100% and still has no slack, because a single absence would
    // drop it to 50%.
    if (n == 0) return "Can't miss any right now";
    return 'You can miss $n more';
  }
}

String _pctLabel(double target) => '${(target * 100).toStringAsFixed(0)}%';

/// Aggregate one component's records into stats.
///
/// [precomputedRemaining] lets [allStats] expand the rest of the term once and
/// share the result across every component instead of paying for it per call.
ComponentStats statsFor(
  AppState state,
  String componentId, {
  DateTime? now,
  Map<String, int>? precomputedRemaining,
}) {
  final comp = state.componentById(componentId);
  final target = comp?.targetPercent ?? state.term?.defaultTarget ?? 0.75;

  var attended = 0;
  var held = 0;
  var cancelled = 0;

  for (final r in state.records) {
    if (r.componentId != componentId) continue;
    if (r.status.countsTowardHeld) {
      held += r.units;
      if (r.status.countsTowardAttended) attended += r.units;
    } else {
      cancelled += r.units;
    }
  }

  final int? remaining;
  if (precomputedRemaining != null) {
    remaining = state.term?.endDate == null
        ? null
        : (precomputedRemaining[componentId] ?? 0);
  } else {
    remaining = remainingUnits(
      state,
      componentId,
      dateOnly(now ?? DateTime.now()),
    );
  }

  return ComponentStats(
    componentId: componentId,
    target: target,
    attended: attended,
    held: held,
    cancelled: cancelled,
    remaining: remaining,
  );
}

/// Stats for every enrolled component, most-at-risk first. Home shows the head
/// of this list; Subjects shows all of it.
List<ComponentStats> allStats(AppState state, {DateTime? now}) {
  final remaining = remainingUnitsByComponent(
    state,
    dateOnly(now ?? DateTime.now()),
  );
  final out = [
    for (final c in state.enrolledComponents)
      statsFor(state, c.id, now: now, precomputedRemaining: remaining),
  ];
  out.sort((a, b) {
    // Danger first, then unknown last, then by how much slack is left.
    final ra = a.risk.index, rb = b.risk.index;
    if (ra != rb) return rb.compareTo(ra); // danger(3) -> warning -> safe -> unknown(0)
    if (!a.hasData || !b.hasData) return 0;
    return a.percent!.compareTo(b.percent!);
  });
  return out;
}

/// Components currently below their own target.
List<ComponentStats> atRisk(AppState state, {DateTime? now}) =>
    allStats(state, now: now).where((s) => s.hasData && !s.isAtTarget).toList();
