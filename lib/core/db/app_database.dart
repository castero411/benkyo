import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Tasks kept on this Mac when Reminders access is off.
class LocalTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  IntColumn get priority => integer()();
  DateTimeColumn get due => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

@DriftDatabase(tables: [LocalTasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'benkyo'));

  @override
  int get schemaVersion => 1;
}
