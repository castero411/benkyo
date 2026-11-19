import 'package:benkyo/core/notifications/alerts.dart';
import 'package:flutter/foundation.dart';

enum Repeat { none, daily, weekdays }

/// A notification the user scheduled ("Start studying at 18:00").
@immutable
class Reminder {
  const Reminder({
    required this.title,
    required this.at,
    this.id,
    this.repeat = Repeat.none,
    this.weekdays = const {},
    this.taskId,
  });

  /// Null until saved.
  final int? id;
  final String title;

  /// The fire time for one-offs; only the time of day matters for repeats.
  final DateTime at;
  final Repeat repeat;

  /// [DateTime.monday] … [DateTime.sunday], used with [Repeat.weekdays].
  final Set<int> weekdays;
  final String? taskId;
}

/// Alerts wanted for [r]. Repeats start at their next occurrence after [now];
/// the platform then repeats them daily or weekly on its own.
List<Alert> reminderAlerts(Reminder r, DateTime now) {
  Alert alert(int weekday, DateTime at, AlertRepeat repeat) => (
    id: reminderAlertId(r.id!, weekday),
    at: at,
    title: r.title,
    body: '',
    payload: 'reminder:${r.id}',
    repeat: repeat,
  );

  // Calendar arithmetic (not Duration) so DST days stay at the right hour.
  DateTime onDay(int daysAhead) => DateTime(
    now.year,
    now.month,
    now.day + daysAhead,
    r.at.hour,
    r.at.minute,
  );
  DateTime next(int daysAhead, int step) {
    final at = onDay(daysAhead);
    return at.isAfter(now) ? at : onDay(daysAhead + step);
  }

  return switch (r.repeat) {
    Repeat.none => [if (r.at.isAfter(now)) alert(0, r.at, AlertRepeat.none)],
    Repeat.daily => [alert(0, next(0, 1), AlertRepeat.daily)],
    Repeat.weekdays => [
      for (final d in r.weekdays)
        alert(d, next((d - now.weekday) % 7, 7), AlertRepeat.weekly),
    ],
  };
}
