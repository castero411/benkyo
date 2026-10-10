// Typed contract between Dart and Swift. Regenerate after editing:
//   dart run pigeon --input pigeons/native_api.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/native/native_api.g.dart',
    swiftOut: 'macos/Runner/NativeApi.g.swift',
  ),
)
enum AccessStatus { notDetermined, granted, denied }

/// One reminder in the app's Reminders list. `priority` is EventKit's 0–9.
class ReminderDto {
  ReminderDto({
    required this.title,
    required this.priority,
    required this.completed,
    this.id,
    this.notes,
    this.dueMillis,
    this.completedMillis,
  });

  String? id;
  String title;
  String? notes;
  int priority;

  /// Midnight means "date only, no time".
  int? dueMillis;
  bool completed;
  int? completedMillis;
}

@HostApi()
abstract class RemindersApi {
  AccessStatus status();

  @async
  bool requestAccess();

  /// Open incomplete reminders + those completed in the last 7 days.
  @async
  List<ReminderDto> fetch();

  /// Creates when `id` is null. Returns the reminder id.
  String save(ReminderDto reminder);

  void delete(String id);

  void openPrivacySettings();
}

@FlutterApi()
abstract class RemindersEvents {
  /// Reminders changed anywhere (this app, Reminders.app, iCloud sync).
  void changed();
}

/// A native NSMenu entry. A null [title] is a separator.
class NativeMenuItem {
  NativeMenuItem({required this.checked, this.id, this.title, this.children});

  String? id;
  String? title;
  bool checked;
  List<NativeMenuItem>? children;
}

@HostApi()
abstract class MenuApi {
  /// Shows a native menu at ([x], [y]) in window coordinates (top-left
  /// origin). Returns the chosen item's id, or null if dismissed.
  @async
  String? show(List<NativeMenuItem> items, double x, double y);
}
