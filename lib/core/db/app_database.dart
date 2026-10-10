import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

/// Tasks kept on this Mac when Reminders access is off.
class LocalTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get priority => integer()();
  DateTimeColumn get due => dateTime().nullable()();
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

@DriftDatabase(tables: [LocalTasks, Sessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'benkyo'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(sessions);
    },
  );
}

final Provider<AppDatabase> appDatabaseProvider = Provider((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
