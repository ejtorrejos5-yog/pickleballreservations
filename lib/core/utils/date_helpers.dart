import 'package:intl/intl.dart';

class DateHelpers {
  DateHelpers._();

  static final DateFormat _firestoreDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDate = DateFormat('EEEE, MMMM d, yyyy');
  static final DateFormat _shortDate = DateFormat('MMM d, yyyy');
  static final DateFormat _monthDay = DateFormat('MMM d');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _time24 = DateFormat('HH:mm');

  // ─── Formatting ───────────────────────────────────────────────────────────────
  static String toFirestoreDate(DateTime date) => _firestoreDate.format(date);
  static String toDisplayDate(DateTime date) => _displayDate.format(date);
  static String toShortDate(DateTime date) => _shortDate.format(date);
  static String toMonthDay(DateTime date) => _monthDay.format(date);
  static String toTimeString(DateTime time) => _timeFormat.format(time);
  static String toTime24(DateTime time) => _time24.format(time);

  static String toTimeRange(DateTime start, DateTime end) {
    return '${_timeFormat.format(start)} – ${_timeFormat.format(end)}';
  }

  static DateTime fromFirestoreDate(String date) => DateTime.parse(date);

  // ─── Time Slot Generation ────────────────────────────────────────────────────
  static List<DateTime> generateTimeSlots({
    required DateTime date,
    required int startHour,
    required int endHour,
    int slotMinutes = 60,
  }) {
    final slots = <DateTime>[];
    var current = DateTime(date.year, date.month, date.day, startHour, 0);
    final end = DateTime(date.year, date.month, date.day, endHour, 0);

    while (current.isBefore(end)) {
      slots.add(current);
      current = current.add(Duration(minutes: slotMinutes));
    }
    return slots;
  }

  // ─── Countdown ───────────────────────────────────────────────────────────────
  static String formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static int secondsUntilEnd(DateTime endTime) {
    final diff = endTime.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inSeconds;
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool slotHasPassed(DateTime slot) =>
      slot.isBefore(DateTime.now());

  static String relativeDay(DateTime date) {
    if (isToday(date)) return 'Today';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (isSameDay(date, tomorrow)) return 'Tomorrow';
    return toDisplayDate(date);
  }
}
