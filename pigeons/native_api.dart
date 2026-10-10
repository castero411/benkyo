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

@HostApi()
abstract class NotificationsApi {
  /// Asks once; later calls return the saved answer without a prompt.
  @async
  bool requestPermission();

  /// Delivers at [atMillis] (epoch ms) even if Benkyo is napping. Scheduling
  /// the same [id] again replaces it.
  void schedule(String id, String title, String body, int atMillis);

  void cancel(String id);
}

@HostApi()
abstract class SceneryApi {
  /// Re-encodes any image macOS can read (HEIC, TIFF…) as JPEG.
  void convertToJpeg(String inputPath, String outputPath);

  /// Saves a JPEG frame from early in the video, used as its thumbnail.
  @async
  void videoPoster(String inputPath, String outputPath);
}

enum SpotifyAccess { granted, notAsked, denied }

/// What the Spotify desktop app is doing.
class SpotifyState {
  SpotifyState({
    required this.installed,
    required this.running,
    required this.playing,
    required this.access,
    this.title,
    this.artist,
    this.artworkUrl,
    this.durationMs,
    this.positionMs,
  });

  bool installed;
  bool running;
  bool playing;

  /// Whether Benkyo may control Spotify (macOS Automation permission).
  SpotifyAccess access;
  String? title;
  String? artist;
  String? artworkUrl;
  int? durationMs;
  int? positionMs;
}

/// Controls the Spotify app with AppleScript: works for Free and Premium.
/// Nothing here starts Spotify except [launch].
@HostApi()
abstract class SpotifyApi {
  /// Never prompts: reads track details only if access was already granted.
  @async
  SpotifyState state();

  /// The first of these asks macOS for permission to control Spotify.
  @async
  void playPause();

  @async
  void next();

  @async
  void previous();

  /// Plays a `spotify:playlist:…` / `spotify:album:…` / `spotify:track:…`.
  @async
  void play(String uri);

  /// Opens Spotify in the background. False if it isn't installed.
  @async
  bool launch();

  void openDownloadPage();

  void openAutomationSettings();
}

@FlutterApi()
abstract class SpotifyEvents {
  /// Playback changed, Spotify launched or quit.
  void changed(SpotifyState state);
}
