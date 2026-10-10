import 'package:benkyo/core/native/native_api.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// An Apple Calendar event, as the Today panel shows it.
@immutable
class CalEvent {
  const CalEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.calendar = '',
    this.color = const Color(0xFF8E8E93),
    this.taskId,
  });

  CalEvent.fromDto(CalendarEventDto d)
    : this(
        id: d.id,
        title: d.title,
        start: DateTime.fromMillisecondsSinceEpoch(d.startMillis),
        end: DateTime.fromMillisecondsSinceEpoch(d.endMillis),
        allDay: d.allDay,
        calendar: d.calendarTitle,
        color: Color(int.parse('FF${d.colorHex.substring(1)}', radix: 16)),
        taskId: d.taskId,
      );

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String calendar;
  final Color color;

  /// The Benkyo task this was scheduled from, if any.
  final String? taskId;
}

/// Up to [count] start times for a [length]-long block that don't overlap
/// timed [events], from now (rounded up to the quarter hour) through
/// tomorrow, within [dayStartHour]–[dayEndHour].
List<DateTime> freeSlots({
  required List<CalEvent> events,
  required DateTime now,
  required Duration length,
  int count = 3,
  int dayStartHour = 8,
  int dayEndHour = 22,
}) {
  const step = Duration(minutes: 15);
  final busy = events.where((e) => !e.allDay).toList();
  bool free(DateTime s, DateTime e) =>
      busy.every((b) => !(b.start.isBefore(e) && b.end.isAfter(s)));

  final slots = <DateTime>[];
  for (var day = 0; day < 2 && slots.length < count; day++) {
    final date = DateTime(now.year, now.month, now.day + day);
    final dayEnd = date.add(Duration(hours: dayEndHour));
    var t = date.add(Duration(hours: dayStartHour));
    if (day == 0 && now.isAfter(t)) {
      final q = (now.minute / 15).ceil() * 15;
      t = DateTime(now.year, now.month, now.day, now.hour, q);
    }
    while (slots.length < count && !t.add(length).isAfter(dayEnd)) {
      if (free(t, t.add(length))) {
        slots.add(t);
        t = t.add(length); // suggest distinct blocks, not 15-min nudges
      } else {
        t = t.add(step);
      }
    }
  }
  return slots;
}
