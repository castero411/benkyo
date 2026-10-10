/// A to-do item. Priority 1 (urgent) … 4 (later).
class Task {
  const Task({
    required this.title,
    this.id,
    this.priority = 4,
    this.due,
    this.completedAt,
    this.notes,
  });

  /// Null until saved.
  final String? id;
  final String title;
  final int priority;
  final DateTime? due;
  final DateTime? completedAt;

  /// Kept so edits never wipe notes written in Reminders.
  final String? notes;

  bool get done => completedAt != null;

  Task copyWith({
    String? title,
    int? priority,
    DateTime? Function()? due,
    DateTime? Function()? completedAt,
  }) => Task(
    id: id,
    title: title ?? this.title,
    priority: priority ?? this.priority,
    due: due == null ? this.due : due(),
    completedAt: completedAt == null ? this.completedAt : completedAt(),
    notes: notes,
  );
}

enum TaskView { today, all, done }

const priorityLabels = {1: 'Urgent', 2: 'High', 3: 'Medium', 4: 'Later'};

/// App priority → EventKit (High 1, Medium 5, Low 9, None 0).
int toReminderPriority(int p) => const {1: 1, 2: 5, 3: 9}[p] ?? 0;

/// EventKit 0–9 → app priority.
int fromReminderPriority(int p) => switch (p) {
  0 => 4,
  < 5 => 1,
  5 => 2,
  _ => 3,
};

/// "Ship docs !1" → ("Ship docs", 1). No marker → priority 4.
(String, int) parseQuickAdd(String input) {
  final marker = RegExp(r'(^|\s)!([1-4])(?=\s|$)');
  final match = marker.firstMatch(input);
  final priority = match == null ? 4 : int.parse(match.group(2)!);
  final title = input
      .replaceAll(marker, ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return (title, priority);
}

/// Tasks for [view], sorted for display.
/// Today = open and due today, overdue, or undated. Done = last 7 days.
List<Task> visibleTasks(List<Task> tasks, TaskView view, DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final weekAgo = now.subtract(const Duration(days: 7));
  final list = tasks
      .where(
        (t) => switch (view) {
          TaskView.today =>
            !t.done && (t.due == null || t.due!.isBefore(tomorrow)),
          TaskView.all => !t.done,
          TaskView.done => t.done && t.completedAt!.isAfter(weekAgo),
        },
      )
      .toList();

  if (view == TaskView.done) {
    return list..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
  }
  // ponytail: priority → due → title; manual drag order when someone asks.
  return list..sort((a, b) {
    final byPriority = a.priority.compareTo(b.priority);
    if (byPriority != 0) return byPriority;
    if (a.due != b.due) {
      if (a.due == null) return 1;
      if (b.due == null) return -1;
      return a.due!.compareTo(b.due!);
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
}
