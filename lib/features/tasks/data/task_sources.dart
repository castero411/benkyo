import 'dart:async';

import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:drift/drift.dart';

/// Where tasks live: Apple Reminders when allowed, this Mac otherwise.
abstract interface class TaskSource {
  Stream<List<Task>> watch();
  Future<void> save(Task task);
  Future<void> delete(String id);
  void dispose();
}

class RemindersTaskSource implements TaskSource, RemindersEvents {
  RemindersTaskSource(this._api) {
    RemindersEvents.setUp(this);
  }

  final RemindersApi _api;
  final _changes = StreamController<void>.broadcast();

  @override
  void changed() => _changes.add(null);

  @override
  Stream<List<Task>> watch() async* {
    yield await _fetch();
    await for (final _ in _changes.stream) {
      yield await _fetch();
    }
  }

  Future<List<Task>> _fetch() async =>
      (await _api.fetch()).map(taskFromReminder).toList();

  @override
  Future<void> save(Task task) async {
    await _api.save(reminderFromTask(task));
    changed(); // don't wait for EventKit's notification to refresh
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete(id);
    changed();
  }

  @override
  void dispose() {
    RemindersEvents.setUp(null);
    unawaited(_changes.close());
  }
}

class LocalTaskSource implements TaskSource {
  LocalTaskSource(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Task>> watch() => _db
      .select(_db.localTasks)
      .watch()
      .map((rows) => rows.map(_toTask).toList());

  /// One-off read, used to move tasks into Reminders.
  Future<List<Task>> all() async =>
      (await _db.select(_db.localTasks).get()).map(_toTask).toList();

  @override
  Future<void> save(Task task) async {
    final row = LocalTasksCompanion(
      title: Value(task.title),
      priority: Value(task.priority),
      due: Value(task.due),
      completedAt: Value(task.completedAt),
    );
    if (task.id == null) {
      await _db.into(_db.localTasks).insert(row);
    } else {
      await (_db.update(
        _db.localTasks,
      )..where((t) => t.id.equals(int.parse(task.id!)))).write(row);
    }
  }

  @override
  Future<void> delete(String id) => (_db.delete(
    _db.localTasks,
  )..where((t) => t.id.equals(int.parse(id)))).go();

  @override
  void dispose() {}

  static Task _toTask(LocalTask row) => Task(
    id: '${row.id}',
    title: row.title,
    priority: row.priority,
    due: row.due,
    completedAt: row.completedAt,
  );
}

Task taskFromReminder(ReminderDto r) => Task(
  id: r.id,
  title: r.title,
  notes: r.notes,
  priority: fromReminderPriority(r.priority),
  due: _date(r.dueMillis),
  completedAt: r.completed ? _date(r.completedMillis) ?? DateTime.now() : null,
);

ReminderDto reminderFromTask(Task t) => ReminderDto(
  id: t.id,
  title: t.title,
  notes: t.notes,
  priority: toReminderPriority(t.priority),
  dueMillis: t.due?.millisecondsSinceEpoch,
  completed: t.done,
);

DateTime? _date(int? millis) =>
    millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
