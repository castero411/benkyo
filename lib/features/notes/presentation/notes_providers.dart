import 'package:benkyo/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All notes, most recently edited first.
final StreamProvider<List<Note>> notesProvider = StreamProvider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(
    db.notes,
  )..orderBy([(n) => OrderingTerm.desc(n.updatedAt)])).watch();
});

/// Task id → its note id (the newest, if a task has several).
final Provider<Map<String, int>> noteByTaskProvider = Provider((ref) {
  final notes = ref.watch(notesProvider).value ?? const <Note>[];
  return {
    for (final n in notes.reversed)
      if (n.taskId != null) n.taskId!: n.id,
  };
});

final Provider<NotesStore> notesStoreProvider = Provider(
  (ref) => NotesStore(ref.watch(appDatabaseProvider)),
);

class NotesStore {
  NotesStore(this._db);

  final AppDatabase _db;

  Future<int> create({String body = '', String? taskId}) {
    final now = DateTime.now();
    return _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            body: body,
            taskId: Value(taskId),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> save(int id, String body) =>
      (_db.update(_db.notes)..where((n) => n.id.equals(id))).write(
        NotesCompanion(body: Value(body), updatedAt: Value(DateTime.now())),
      );

  /// Returns the removed row so it can be restored (Undo).
  Future<Note> delete(int id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((n) => n.id.equals(id))).getSingle();
    await (_db.delete(_db.notes)..where((n) => n.id.equals(id))).go();
    return row;
  }

  Future<void> restore(Note row) => _db.into(_db.notes).insert(row);
}
