import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/features/reminders/domain/reminder.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<ReminderStore> reminderStoreProvider = Provider(
  (ref) => ReminderStore(ref.watch(appDatabaseProvider)),
);

/// Scheduled reminders in the local database.
class ReminderStore {
  ReminderStore(this._db);

  final AppDatabase _db;

  Stream<List<Reminder>> watch() =>
      (_db.select(_db.scheduledReminders)
            ..orderBy([(r) => OrderingTerm(expression: r.at)]))
          .watch()
          .map((rows) => rows.map(_toReminder).toList());

  /// Inserts or updates; returns the id.
  Future<int> save(Reminder r) async {
    final row = ScheduledRemindersCompanion(
      title: Value(r.title),
      at: Value(r.at),
      repeat: Value(r.repeat.name),
      weekdays: Value(
        r.repeat == Repeat.weekdays
            ? (r.weekdays.toList()..sort()).join(',')
            : '',
      ),
      taskId: Value(r.taskId),
    );
    if (r.id == null) return await _db.into(_db.scheduledReminders).insert(row);
    await (_db.update(
      _db.scheduledReminders,
    )..where((t) => t.id.equals(r.id!))).write(row);
    return r.id!;
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.scheduledReminders)..where((t) => t.id.equals(id))).go();

  static Reminder _toReminder(ScheduledReminder row) => Reminder(
    id: row.id,
    title: row.title,
    at: row.at,
    repeat: Repeat.values.asNameMap()[row.repeat] ?? Repeat.none,
    weekdays: {for (final d in row.weekdays.split(',')) ?int.tryParse(d)},
    taskId: row.taskId,
  );
}
