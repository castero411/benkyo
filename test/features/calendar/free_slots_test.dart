import 'package:benkyo/features/calendar/domain/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const focus = Duration(minutes: 25);
  DateTime at(int day, int h, [int m = 0]) => DateTime(2026, 10, day, h, m);
  CalEvent busy(DateTime s, DateTime e, {bool allDay = false}) =>
      CalEvent(id: '$s', title: 'x', start: s, end: e, allDay: allDay);

  test('starts at the next quarter hour, distinct blocks', () {
    expect(freeSlots(events: const [], now: at(10, 9, 7), length: focus), [
      at(10, 9, 15),
      at(10, 9, 40),
      at(10, 10, 5),
    ]);
  });

  test('skips busy time; all-day events do not block', () {
    final slots = freeSlots(
      events: [
        busy(at(10, 9), at(10, 10)),
        busy(at(10, 0), at(11, 0), allDay: true),
      ],
      now: at(10, 9),
      length: focus,
      count: 1,
    );
    expect(slots, [at(10, 10)]);
  });

  test('rolls over to tomorrow morning when today is full', () {
    final slots = freeSlots(
      events: const [],
      now: at(10, 21, 50),
      length: const Duration(hours: 1),
      count: 1,
    );
    expect(slots, [at(11, 8)]);
  });
}
