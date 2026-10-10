import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('priority maps to Reminders and back', () {
    for (final p in [1, 2, 3, 4]) {
      expect(fromReminderPriority(toReminderPriority(p)), p);
    }
    // Values set on iPhone that we never write ourselves.
    expect(fromReminderPriority(3), 1);
    expect(fromReminderPriority(7), 3);
  });

  test('quick-add parses the priority marker', () {
    expect(parseQuickAdd('Ship docs !1'), ('Ship docs', 1));
    expect(parseQuickAdd('!3 Read  notes'), ('Read notes', 3));
    expect(parseQuickAdd('Plain task'), ('Plain task', 4));
    expect(parseQuickAdd('Wow!1 not a marker'), ('Wow!1 not a marker', 4));
    expect(parseQuickAdd('!5 stays'), ('!5 stays', 4));
  });

  test('views filter and sort', () {
    final now = DateTime(2026, 10, 10, 12);
    final tasks = [
      Task(id: 'a', title: 'later', due: DateTime(2026, 10, 20)),
      const Task(id: 'b', title: 'b undated', priority: 2),
      Task(id: 'c', title: 'overdue', priority: 2, due: DateTime(2026, 10, 8)),
      const Task(id: 'd', title: 'urgent', priority: 1),
      Task(id: 'e', title: 'done', completedAt: DateTime(2026, 10, 9)),
      Task(id: 'f', title: 'old done', completedAt: DateTime(2026, 9)),
    ];
    List<String?> ids(TaskView v) =>
        visibleTasks(tasks, v, now).map((t) => t.id).toList();

    expect(ids(TaskView.today), ['d', 'c', 'b']); // future-dated hidden
    expect(ids(TaskView.all), ['d', 'c', 'b', 'a']);
    expect(ids(TaskView.done), ['e']); // older than 7 days hidden
  });
}
