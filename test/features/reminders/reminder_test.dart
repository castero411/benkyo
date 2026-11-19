import 'package:benkyo/core/notifications/alerts.dart';
import 'package:benkyo/features/reminders/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Thursday 19 Nov 2026, 09:00.
  final now = DateTime(2026, 11, 19, 9);

  Reminder r(DateTime at, {Repeat repeat = Repeat.none, Set<int>? days}) =>
      Reminder(
        id: 4,
        title: 'Study',
        at: at,
        repeat: repeat,
        weekdays: days ?? const {},
      );

  test('one-off: one alert at its time, none once past', () {
    final a = reminderAlerts(r(DateTime(2026, 11, 19, 18)), now).single;
    expect(a.id, reminderAlertId(4, 0));
    expect(a.at, DateTime(2026, 11, 19, 18));
    expect(a.repeat, AlertRepeat.none);
    expect(a.title, 'Study');
    expect(a.payload, 'reminder:4');
    expect(reminderAlerts(r(DateTime(2026, 11, 19, 8)), now), isEmpty);
  });

  test('daily: next occurrence of the time, repeating daily', () {
    // Created days ago at 08:00: today's 08:00 passed, so tomorrow.
    final a = reminderAlerts(
      r(DateTime(2026, 11, 1, 8), repeat: Repeat.daily),
      now,
    ).single;
    expect(a.at, DateTime(2026, 11, 20, 8));
    expect(a.repeat, AlertRepeat.daily);
  });

  test('weekdays: one weekly alert per chosen day', () {
    final alerts = reminderAlerts(
      r(
        DateTime(2026, 11, 1, 18),
        repeat: Repeat.weekdays,
        days: {DateTime.monday, DateTime.thursday},
      ),
      now,
    )..sort((a, b) => a.at.compareTo(b.at));
    expect(alerts.map((a) => a.at), [
      DateTime(2026, 11, 19, 18), // today, later
      DateTime(2026, 11, 23, 18), // next Monday
    ]);
    expect(alerts.map((a) => a.id), [
      reminderAlertId(4, DateTime.thursday),
      reminderAlertId(4, DateTime.monday),
    ]);
    expect(alerts.every((a) => a.repeat == AlertRepeat.weekly), isTrue);
  });

  test('weekdays with no days chosen: nothing', () {
    expect(reminderAlerts(r(now, repeat: Repeat.weekdays), now), isEmpty);
  });
}
