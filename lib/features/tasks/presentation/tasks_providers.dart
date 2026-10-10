import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/tasks/data/task_sources.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<RemindersApi> remindersApiProvider = Provider(
  (_) => RemindersApi(),
);

/// Reminders access. Asked for only when the user taps "Turn on".
class RemindersSync extends AsyncNotifier<AccessStatus> {
  @override
  Future<AccessStatus> build() => ref.read(remindersApiProvider).status();

  Future<void> enable() async {
    final api = ref.read(remindersApiProvider);
    if (await api.requestAccess()) await _moveLocalTasksToReminders(api);
    state = AsyncData(await api.status());
  }

  Future<void> openSettings() =>
      ref.read(remindersApiProvider).openPrivacySettings();

  Future<void> _moveLocalTasksToReminders(RemindersApi api) async {
    final local = LocalTaskSource(ref.read(appDatabaseProvider));
    for (final task in await local.all()) {
      await api.save(reminderFromTask(task)..id = null);
      await local.delete(task.id!); // only after it's safely in Reminders
    }
  }
}

final remindersSyncProvider =
    AsyncNotifierProvider<RemindersSync, AccessStatus>(RemindersSync.new);

final taskSourceProvider = Provider<TaskSource?>((ref) {
  final status = ref.watch(remindersSyncProvider).value;
  if (status == null) return null;
  final source = status == AccessStatus.granted
      ? RemindersTaskSource(ref.read(remindersApiProvider))
      : LocalTaskSource(ref.read(appDatabaseProvider));
  ref.onDispose(source.dispose);
  return source;
});

final tasksProvider = StreamProvider<List<Task>>((ref) {
  final source = ref.watch(taskSourceProvider);
  return source?.watch() ?? const Stream.empty();
});

final taskViewProvider = NotifierProvider<TaskViewNotifier, TaskView>(
  TaskViewNotifier.new,
);

class TaskViewNotifier extends Notifier<TaskView> {
  @override
  TaskView build() => TaskView.today;

  TaskView get view => state;
  set view(TaskView view) => state = view;
}

/// Session-only: the "Sync with Reminders" card was dismissed.
final syncCardDismissedProvider = NotifierProvider<SyncCardDismissed, bool>(
  SyncCardDismissed.new,
);

class SyncCardDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

/// ⌘N focuses this.
final Provider<FocusNode> quickAddFocusProvider = Provider((ref) {
  final node = FocusNode(debugLabel: 'quick-add');
  ref.onDispose(node.dispose);
  return node;
});
