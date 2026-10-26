// Date and time formatting for the Travel screens.
//
// Written by hand — the app has no `intl` dependency, and adding one for date
// formatting would be a poor trade against the offline-only constraint.

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _weekdays = <String>[
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

/// "Thu 12 Mar 2026".
String formatFlightDate(DateTime d) {
  final DateTime local = d.toLocal();
  return '${_weekdays[local.weekday - 1]} ${local.day} '
      '${_months[local.month - 1]} ${local.year}';
}

/// 24-hour, because a mis-read am/pm on a boarding time is a missed flight.
String formatFlightTime(DateTime d) {
  final DateTime local = d.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String formatFlightDateTime(DateTime d) =>
    '${formatFlightDate(d)}, ${formatFlightTime(d)}';

/// "12 Mar".
String formatShortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "7h 20m", "45m", "2h".
String formatFlightDuration(Duration d) {
  final int total = d.inMinutes;
  if (total < 0) return '—';
  final int hours = total ~/ 60;
  final int minutes = total % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

/// "12–20 Mar 2026", "28 Mar – 3 Apr 2026", "30 Dec 2026 – 4 Jan 2027".
String formatTripDates(DateTime start, DateTime end) {
  if (start.year != end.year) {
    return '${formatShortDate(start)} ${start.year} – '
        '${formatShortDate(end)} ${end.year}';
  }
  if (start.month != end.month) {
    return '${formatShortDate(start)} – ${formatShortDate(end)} ${end.year}';
  }
  if (start.day == end.day) return '${formatShortDate(start)} ${start.year}';
  return '${start.day}–${end.day} ${_months[end.month - 1]} ${end.year}';
}
