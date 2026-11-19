import 'package:benkyo/core/notifications/alerts.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 19, 9);
  final at10 = DateTime(2026, 11, 19, 10);

  Task task(
    String id, {
    DateTime? due,
    bool hasTime = true,
    int? remind = 0,
    bool done = false,
  }) => Task(
    id: id,
    title: 'Task $id',
    due: due ?? at10,
    dueHasTime: hasTime,
    remindMinutes: remind,
    completedAt: done ? now : null,
  );

  test('a timed task alerts at due time minus the lead time', () {
    final alerts = taskAlerts([task('1', remind: 15)], now);
    expect(alerts.single.at, DateTime(2026, 11, 19, 9, 45));
    expect(alerts.single.id, taskAlertId('1'));
    expect(alerts.single.title, 'Task 1');
    expect(alerts.single.payload, 'task:1');
    expect(alerts.single.repeat, AlertRepeat.none);
  });

  test('no alert: done, date-only, alert off, or already past', () {
    final alerts = taskAlerts([
      task('1', done: true),
      task('2', hasTime: false),
      task('3', remind: null),
      task('4', due: DateTime(2026, 11, 19, 8)),
      task('5', remind: 60), // 9:00 == now: too late to schedule
    ], now);
    expect(alerts, isEmpty);
  });

  test('id ranges never collide', () {
    final ids = {
      phaseEndId,
      ongoingTimerId,
      for (final t in [1, 2, 999999]) taskAlertId('$t'),
      for (final r in [1, 2, 9999999])
        for (final d in [0, 1, 7]) reminderAlertId(r, d),
    };
    expect(ids, hasLength(2 + 3 + 9));
    expect(ids.every((id) => id > 0 && id < 0x7fffffff), isTrue); // int32
    expect(isTaskAlertId(taskAlertId('42')), isTrue);
    expect(isTaskAlertId(reminderAlertId(42, 3)), isFalse);
    expect(isReminderAlertId(reminderAlertId(42, 3)), isTrue);
    expect(isReminderAlertId(phaseEndId), isFalse);
  });
}
