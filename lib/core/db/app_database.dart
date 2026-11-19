import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Tasks kept on this device (always on Android; on macOS when Reminders
/// access is off).
class LocalTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get priority => integer()();
  DateTimeColumn get due => dateTime().nullable()();
  BoolColumn get dueHasTime => boolean().withDefault(const Constant(false))();

  /// Minutes before [due] to alert; null = no alert.
  IntColumn get remindMinutes => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Finished timer phases. [phase] is a `Phase` name.
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get phase => text()();
  TextColumn get taskId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
}

/// Scenery the user imported, copied into Application Support/scenes.
class UserScenes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Absolute path of the copy (a video's poster sits next to it + ".jpg").
  TextColumn get path => text()();
  BoolColumn get isVideo => boolean()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Small app settings as key → value text.
class Prefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Markdown notes. The first line is the title, as in Apple Notes.
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get body => text()();
  TextColumn get taskId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Notifications the user scheduled. [repeat] is a `Repeat` name;
/// [weekdays] is "1,3,5" (Mon = 1).
class ScheduledReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get repeat => text()();
  TextColumn get weekdays => text().withDefault(const Constant(''))();
  TextColumn get taskId => text().nullable()();
}

@DriftDatabase(
  tables: [LocalTasks, Sessions, UserScenes, Prefs, Notes, ScheduledReminders],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'benkyo'));

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(sessions);
      if (from < 3) {
        await m.createTable(userScenes);
        await m.createTable(prefs);
      }
      if (from < 4) await m.createTable(notes);
      if (from < 5) {
        await m.addColumn(localTasks, localTasks.dueHasTime);
        await m.addColumn(localTasks, localTasks.remindMinutes);
        await m.createTable(scheduledReminders);
      }
    },
  );
}

final Provider<AppDatabase> appDatabaseProvider = Provider((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Key–value settings on top of the [Prefs] table.
extension PrefsStore on AppDatabase {
  Future<Map<String, String>> prefsWithPrefix(String prefix) async => {
    for (final row in await (select(
      prefs,
    )..where((p) => p.key.like('$prefix%'))).get())
      row.key: row.value,
  };

  Future<void> setPref(String key, String value) => into(prefs)
      .insertOnConflictUpdate(PrefsCompanion.insert(key: key, value: value));
}
