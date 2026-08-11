import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_state.dart';
import '../models/models.dart';
import 'stats.dart';

/// One scheduled end-of-day nudge, computed without touching the platform so
/// it can be tested. [Notifications] turns these into actual alarms.
class NudgePlan {
  final int weekday;
  final int hour;
  final int minute;
  final String title;
  final String body;

  const NudgePlan({
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
  });

  int get minuteOfDay => hour * 60 + minute;

  @override
  String toString() =>
      'NudgePlan(day $weekday at $hour:${minute.toString().padLeft(2, '0')})';
}

/// Work out when each weekday's nudge should fire and what it should say.
///
/// The text states how many classes the *timetable* has, never what was
/// recorded. Android holds the text from the moment the alarm is scheduled and
/// fires it with nothing of ours running, so any claim about attendance would
/// be a guess that goes stale the moment the user marks something.
List<NudgePlan> buildNudgePlans(AppState state) {
  final out = <NudgePlan>[];

  for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
    final slots =
        state.enrolledSlots.where((s) => s.weekday == weekday).toList();
    if (slots.isEmpty) continue;

    var lastEnd = 0;
    for (final s in slots) {
      final endPeriod = state.periodByIndex(s.periodIndex + s.spanPeriods - 1);
      if (endPeriod != null && endPeriod.endMin > lastEnd) {
        lastEnd = endPeriod.endMin;
      }
    }
    if (lastEnd == 0) continue;

    // Clamped to 23:59 rather than allowed to wrap. `(fireAt ~/ 60) % 24` used
    // to roll a late finish past midnight back to the small hours of the *same*
    // weekday, so the reminder arrived before the classes it summarises.
    final fireAt =
        (lastEnd + state.settings.nudgeOffsetMinutes).clamp(0, 23 * 60 + 59);

    // Classes, not periods: a two-period lab is one class, matching how
    // attendance is actually counted.
    final count = slots.length;
    out.add(
      NudgePlan(
        weekday: weekday,
        hour: fireAt ~/ 60,
        minute: fireAt % 60,
        title: count == 1
            ? 'You had 1 class today'
            : 'You had $count classes today',
        body: 'Missed any and not marked it yet? Tap to fix.',
      ),
    );
  }
  return out;
}

/// Local notifications only — no Firebase, no push server, no backend.
///
/// Attendance correctness never depends on these firing. They are a convenience
/// layer over the catch-up engine, which is why aggressive OEM battery killers
/// can delay them without making the data wrong.
class Notifications {
  Notifications._();
  static final instance = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Why notifications are unavailable, if they are. Surfaced in Settings —
  /// this feature's failure mode is silence, so without it a user cannot tell
  /// "working" from "broken".
  String? lastError;

  bool get isReady => _ready;

  static const _channelId = 'proxymate_daily';
  static const _channelName = 'Attendance reminders';

  // Fixed id ranges so rescheduling can target them precisely.
  static const _nudgeBase = 100; // +weekday
  static const _summaryId = 200;
  static const _alertId = 300;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();

      // Its own try: a device reporting a zone name the tz database doesn't
      // carry used to throw here, before the plugin was even initialised,
      // which silently disabled *every* notification for that install.
      try {
        tz.setLocalLocation(tz.getLocation(await _resolveTimeZone()));
      } catch (e) {
        debugPrint('ProxyMate: timezone lookup failed ($e), using offset');
        _setZoneFromDeviceOffset();
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      // The channel must exist before the Android 13+ permission prompt.
      await _android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'End-of-day confirmations and attendance warnings',
          importance: Importance.defaultImportance,
        ),
      );
      _ready = true;
      lastError = null;
    } catch (e) {
      lastError = e.toString();
      debugPrint('ProxyMate: notifications unavailable: $e');
    }
  }

  /// How many notifications Android currently holds for this app. Zero while
  /// a timetable exists means something went wrong arming them.
  Future<int> pendingCount() async {
    if (!_ready) return 0;
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> permissionGranted() async {
    if (!_ready) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Last resort when the device reports a zone the tz database doesn't carry:
  /// pick any zone whose current UTC offset matches. Not a hardcoded region —
  /// what matters here is only what "6 pm local" means.
  void _setZoneFromDeviceOffset() {
    final offset = DateTime.now().timeZoneOffset;
    final now = DateTime.now().toUtc();
    try {
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.from(now, location).timeZoneOffset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (_) {
      // Leaving tz.local at its default still lets notifications fire.
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  Future<String> _resolveTimeZone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  Future<bool> requestPermission() async {
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Rebuild every schedule from scratch. Called whenever the timetable,
  /// enrollment or notification settings change.
  Future<void> reschedule(AppState state) async {
    if (!_ready) return;
    await cancelAll();
    if (state.term == null) return;

    if (state.settings.nudgeEnabled) {
      await _scheduleDailyNudges(state);
    }
    if (state.settings.weeklySummaryEnabled) {
      await _scheduleWeeklySummary();
    }
  }

  /// Turns [buildNudgePlans] into alarms. All the decisions live there so
  /// they can be tested; this only talks to the platform.
  Future<void> _scheduleDailyNudges(AppState state) async {
    for (final plan in buildNudgePlans(state)) {
      await _plugin.zonedSchedule(
        id: _nudgeBase + plan.weekday,
        title: plan.title,
        body: plan.body,
        scheduledDate: nextInstanceOfWeekday(
          plan.weekday,
          plan.hour,
          plan.minute,
        ),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _scheduleWeeklySummary() async {
    await _plugin.zonedSchedule(
      id: _summaryId,
      title: 'Weekly attendance check',
      body: 'See where you stand before the week starts.',
      scheduledDate: nextInstanceOfWeekday(DateTime.sunday, 19, 0),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Fired the instant an absence pushes a component under its target.
  ///
  /// Because presence is assumed, attendance can *only* fall when the user
  /// marks an absence — so checking here catches every crossing with no
  /// background job at all.
  Future<void> warnIfCrossed(
    AppState before,
    AppState after, {
    DateTime? now,
  }) async {
    if (!_ready) return;

    final wasSafe = {
      for (final s in allStats(before, now: now)) s.componentId: s.isAtTarget,
    };

    for (final s in allStats(after, now: now)) {
      if (!s.hasData) continue;
      if (s.isAtTarget) continue;
      if (wasSafe[s.componentId] != true) continue; // already unsafe before

      final course = after.courseForComponent(s.componentId);
      final component = after.componentById(s.componentId);

      await _plugin.show(
        id: _alertId + s.componentId.hashCode.abs() % 1000,
        title:
            '${course?.shortName ?? 'A subject'} '
            '${component?.kind.label ?? ''} dropped below '
            '${(s.target * 100).round()}%',
        body: s.headline,
        notificationDetails: _details,
      );
    }
  }

  Future<void> sendTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 1,
      title: 'ProxyMate is working',
      body: 'Notifications are set up correctly.',
      notificationDetails: _details,
    );
  }

  static tz.TZDateTime nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
