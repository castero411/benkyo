import 'package:benkyo/features/tasks/domain/task.dart';

/// How a scheduled alert repeats.
enum AlertRepeat { none, daily, weekly }

/// One notification the app wants scheduled. Platform-free, so the rules
/// stay unit-testable; the notifications layer turns it into plugin calls.
typedef Alert = ({
  int id,
  DateTime at,
  String title,
  String body,
  String payload,
  AlertRepeat repeat,
});

// Android notification ids are int32. Fixed ids first, then one range each.
const phaseEndId = 1;
const ongoingTimerId = 2;
const _reminderBase = 1000;
const _taskBase = 1000000000;

/// Local task ids are integers; anything else (e.g. a Reminders id) gets none.
int? taskAlertIdOrNull(String taskId) {
  final n = int.tryParse(taskId);
  return n == null || n < 0 || n >= _taskBase ? null : _taskBase + n;
}

int taskAlertId(String taskId) => taskAlertIdOrNull(taskId)!;

/// [weekday] 0 for one-off/daily, 1–7 (Mon–Sun) for weekly repeats.
int reminderAlertId(int reminderId, int weekday) =>
    _reminderBase + reminderId * 10 + weekday;

bool isTaskAlertId(int id) => id >= _taskBase;
bool isReminderAlertId(int id) => id >= _reminderBase && id < _taskBase;

/// Alerts wanted for [tasks]: open, due at a set time, alert on, still ahead.
List<Alert> taskAlerts(List<Task> tasks, DateTime now) => [
  for (final t in tasks)
    if (!t.done && t.dueHasTime && t.due != null && t.remindMinutes != null)
      if (taskAlertIdOrNull(t.id ?? '') case final id?)
        if (t.due!.subtract(Duration(minutes: t.remindMinutes!)) case final at
            when at.isAfter(now))
          (
            id: id,
            at: at,
            title: t.title,
            body: t.remindMinutes == 0
                ? 'Due now'
                : 'Due in ${t.remindMinutes} min',
            payload: 'task:${t.id}',
            repeat: AlertRepeat.none,
          ),
];
