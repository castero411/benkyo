import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/features/reminders/data/reminder_store.dart';
import 'package:benkyo/features/reminders/domain/reminder.dart';
import 'package:benkyo/features/tasks/data/task_sources.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(
    () => db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    ),
  );
  tearDown(() => db.close());

  test('local tasks keep due time and alert lead time', () async {
    final source = LocalTaskSource(db);
    await source.save(
      Task(
        title: 'Essay',
        due: DateTime(2026, 11, 20, 14),
        dueHasTime: true,
        remindMinutes: 15,
      ),
    );
    final task = (await source.all()).single;
    expect(task.dueHasTime, isTrue);
    expect(task.remindMinutes, 15);

    await source.save(task.copyWith(remindMinutes: () => null));
    expect((await source.all()).single.remindMinutes, isNull);
  });

  test('reminders: save, edit, list, delete', () async {
    final store = ReminderStore(db);
    final id = await store.save(
      Reminder(
        title: 'Study',
        at: DateTime(2026, 11, 20, 18),
        repeat: Repeat.weekdays,
        weekdays: const {1, 3},
        taskId: '2',
      ),
    );
    var saved = (await store.watch().first).single;
    expect(saved.id, id);
    expect(saved.weekdays, {1, 3});
    expect(saved.repeat, Repeat.weekdays);
    expect(saved.taskId, '2');

    await store.save(
      Reminder(id: id, title: 'Revise', at: saved.at, repeat: Repeat.daily),
    );
    saved = (await store.watch().first).single;
    expect(saved.title, 'Revise');
    expect(saved.weekdays, isEmpty);

    await store.delete(id);
    expect(await store.watch().first, isEmpty);
  });
}
