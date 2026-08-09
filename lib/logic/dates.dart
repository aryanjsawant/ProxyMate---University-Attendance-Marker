import 'dart:math';

/// Every "date" in ProxyMate is local midnight. Records are keyed by calendar
/// day, never by instant, so all comparisons go through here.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDateKey(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Inclusive on both ends. Rebuilds the DateTime each step rather than adding a
/// Duration so a DST boundary can never shift the clock off midnight.
Iterable<DateTime> eachDay(DateTime from, DateTime to) sync* {
  var d = dateOnly(from);
  final end = dateOnly(to);
  while (!d.isAfter(end)) {
    yield d;
    d = DateTime(d.year, d.month, d.day + 1);
  }
}

/// Minutes from midnight -> "9:20 am"
String formatMinutes(int m) {
  final h24 = m ~/ 60;
  final min = m % 60;
  final suffix = h24 < 12 ? 'am' : 'pm';
  var h = h24 % 12;
  if (h == 0) h = 12;
  return '$h:${min.toString().padLeft(2, '0')} $suffix';
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// [weekday] uses DateTime.monday..DateTime.sunday (1..7).
String weekdayName(int weekday) => _weekdayNames[weekday - 1];
String weekdayShort(int weekday) => _weekdayNames[weekday - 1].substring(0, 3);

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Tuesday, 2 Aug"
String formatLongDate(DateTime d) =>
    '${weekdayName(d.weekday)}, ${d.day} ${_monthNames[d.month - 1]}';

/// "2 Aug 2026"
String formatShortDate(DateTime d) =>
    '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

final _rand = Random();
int _counter = 0;

/// Stable-enough local id. Seed data uses hand-written ids instead so imports
/// and tests stay readable.
String newId([String prefix = '']) {
  _counter++;
  final r = _rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  return '$prefix$t-$_counter-$r';
}
