import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_state.dart';
import 'stats.dart';

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

  static const _channelId = 'proxymate_daily';
  static const _channelName = 'Attendance reminders';

  // Fixed id ranges so rescheduling can target them precisely.
  static const _nudgeBase = 100; // +weekday
  static const _summaryId = 200;
  static const _alertId = 300;

  /// Why notifications are unavailable, if they are. Surfaced in Settings —
  /// a silent failure here means the user simply never hears from the app
  /// again and has no way to find out why.
  String? lastError;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();

      // Timezone resolution is its own try: a device reporting a zone name the
      // tz database doesn't carry used to throw here and abort the whole
      // init, which silently disabled *every* notification. Falling back to a
      // fixed zone costs at most an hour of drift; failing costs the feature.
      try {
        tz.setLocalLocation(tz.getLocation(await _resolveTimeZone()));
      } catch (e) {
        debugPrint('ProxyMate: timezone fallback (${e.toString()})');
        try {
          tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        } catch (_) {
          /* keep the package default */
        }
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

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  Future<String> _resolveTimeZone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return 'Asia/Kolkata';
    }
  }

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

  /// One weekly-repeating notification per weekday that actually has classes,
  /// fired at *last class end + offset*.
  ///
  /// Its whole job is to make the auto-present model trustworthy: a daily
  /// prompt to correct anything the app got wrong.
  ///
  /// **The text may not claim what was recorded.** Android holds the title and
  /// body from the moment they are scheduled and fires them with the app not
  /// running, so nothing here can know what the user actually marked — it only
  /// knows how many classes the *timetable* has that weekday. Saying "marked
  /// you present for 4 classes" was therefore a lie whenever the user had
  /// already marked an absence. It states the schedule instead, which is a
  /// fact known at schedule time.
  Future<void> _scheduleDailyNudges(AppState state) async {
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final slots = state.activeSlots.where((s) => s.weekday == weekday);
      if (slots.isEmpty) continue;

      // Untimed classes settle at the configured end of day, so that acts as
      // the floor for when the day's confirmation makes sense.
      final dayEnd = state.settings.dayEndsAtMinutes;
      var lastEnd = 0;
      var count = 0;
      for (final s in slots) {
        count++;
        final end = s.effectiveEndMin(dayEnd);
        if (end > lastEnd) lastEnd = end;
      }
      if (lastEnd == 0) continue;

      final fireAt = lastEnd + state.settings.nudgeOffsetMinutes;
      final hour = (fireAt ~/ 60) % 24;
      final minute = fireAt % 60;

      await _plugin.zonedSchedule(
        id: _nudgeBase + weekday,
        title: count == 1
            ? 'You had 1 class today'
            : 'You had $count classes today',
        body: 'Missed any and not marked it yet? Tap to fix.',
        scheduledDate: nextInstanceOfWeekday(weekday, hour, minute),
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

  /// Fired the instant an absence pushes a subject under its target.
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
      for (final s in allStats(before, now: now)) s.subjectId: s.isAtTarget,
    };

    for (final s in allStats(after, now: now)) {
      if (!s.hasData) continue;
      if (s.isAtTarget) continue;
      if (wasSafe[s.subjectId] != true) continue; // already unsafe before

      final subject = after.subjectById(s.subjectId);

      await _plugin.show(
        id: _alertId + s.subjectId.hashCode.abs() % 1000,
        title:
            '${subject?.shortName ?? 'A subject'} dropped below '
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
