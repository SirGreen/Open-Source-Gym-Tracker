import 'package:intl/intl.dart';

/// 62.5 -> "62.5", 60.0 -> "60"
String trimNum(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Big numbers get a k suffix so volume tiles stay one line.
String compact(double v) {
  if (v.abs() >= 1000) {
    return '${(v / 1000).toStringAsFixed(v.abs() >= 10000 ? 0 : 1)}k';
  }
  return trimNum(v);
}

final _grouped = NumberFormat.decimalPattern();

/// Energy, to the nearest 10 kcal. "437" would claim a precision that an
/// estimate built from a table of METs does not have; "440" is honest about
/// being a ballpark, and still moves when the training does.
String kcal(double v) => _grouped.format((v / 10).round() * 10);

String clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String durationShort(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  if (d.inHours < 1) return '${d.inMinutes}m';
  final m = d.inMinutes.remainder(60);
  return m == 0 ? '${d.inHours}h' : '${d.inHours}h ${m}m';
}

final _dayMonth = DateFormat('EEE d MMM');
final _monthYear = DateFormat('MMMM yyyy');
final _timeFmt = DateFormat('HH:mm');
final _shortDate = DateFormat('d MMM');

String dayMonth(DateTime d) => _dayMonth.format(d);
String monthYear(DateTime d) => _monthYear.format(d);
String timeOfDay(DateTime d) => _timeFmt.format(d);
String shortDate(DateTime d) => _shortDate.format(d);

const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String weekdayName(int weekday) => weekdayNames[(weekday - 1).clamp(0, 6)];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Human label for a past date: Today / Yesterday / Fri 12 Sep
String relativeDay(DateTime d, DateTime now) {
  final days = dateOnly(now).difference(dateOnly(d)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days > 1 && days < 7) return '$days days ago';
  return dayMonth(d);
}
