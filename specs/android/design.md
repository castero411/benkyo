# Benkyo for Android: Design

**Phase:** 2 of 3 (requirements → **design** → tasks) · **Status:** Draft, awaiting approval · **Date:** 2026-11-19
Implements [requirements.md](requirements.md). Privacy-relevant choices are mirrored in
[privacy-notes.md](privacy-notes.md).

## 1. Approach

Same codebase and the same features. Android gets **its own shell** (screen, sheets, clock mode)
and **swaps data sources through Riverpod overrides**, all registered in one place. The domain layer
(`pomodoro.dart`, `task.dart`, `scene.dart`) is shared, so the existing tests keep covering it.

```
main.dart
 ├─ macOS   → BenkyoApp(home: FocusScreen)          (unchanged)
 └─ Android → await initAndroid()
              ProviderScope(overrides: androidOverrides)
              BenkyoApp(home: MobileFocusScreen)
```

`lib/app/android.dart` is the only file that knows about Android wiring: overrides, plugin init,
orientation lock and the notification response router.

## 2. What is reused, what is new

| Area | macOS today | Android | Req |
|---|---|---|---|
| Timer domain | `PomodoroState` | Reused. Adds a `catchUp()` pure function and persistence. | R1 |
| Timer notifications | `NotificationsApi` (Swift) | `LocalNotifications implements NotificationsApi`, wrapping `flutter_local_notifications`. Override of `notificationsApiProvider`. | R1.4–5 |
| Ongoing countdown | — | `timerNotificationSync`, a provider that mirrors `timerProvider` into a chronometer notification. | R1.11–13 |
| Tasks | Reminders or local | `taskSourceProvider` is overridden to always use `LocalTaskSource`. The sync card is hidden. | R4, D2 |
| Task notifications | — | New: a pure `taskAlerts()` function plus reconcile. | R5 |
| Scheduled notifications | — | New `reminders` feature (table, domain, sheet). | R6 |
| Scenery | `file_selector` + drag/drop, Swift `SceneryApi` | The `image_picker` photo picker, plus a Kotlin `SceneryApi` (Pigeon) for HEIC→JPEG and video posters. The import code is unchanged. | R3 |
| Spotify | AppleScript mini player | `SpotifySheet` with presets and pasted links → `openUrl('spotify:…')`. The mini player is hidden. | R7 |
| Window / URLs | `benkyo/window` channel (Swift) | Same channel, implemented in `MainActivity.kt`: `openUrl`, `keepScreenOn`. | R2.5, R7.3–4 |
| Menus | `NSMenu` | Already falls back to Material `showMenu` (`platform_menu.dart`). | — |
| Calendar, Notes, onboarding | Present | Not shown on Android (v2 / out of scope). | — |

## 3. Dependencies

| Package | Why | Notes |
|---|---|---|
| `flutter_local_notifications` | Exact scheduling, repeats, channels, actions, chronometer, boot reschedule, permission requests | Needs core library desugaring in Gradle. |
| `timezone` + `flutter_timezone` | `zonedSchedule` needs the local time zone for daily and weekday repeats across DST | — |
| `image_picker` | `pickMultipleMedia()` uses the Android Photo Picker, with no storage permission | — |
| `drift_flutter` | Already present. Bundles SQLite on Android. | — |

No `url_launcher` and no `wakelock_plus`: both are about 10 lines in `MainActivity.kt` on the existing
channel. **minSdk stays at Flutter's default (24).** None of the packages above require more.

## 4. Components

### 4.1 Android bootstrap: `lib/app/android.dart`

```dart
Future<void> initAndroid() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); // R2.7
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
  await LocalNotifications.instance.init(onResponse: notificationRouter);
}

final androidOverrides = [
  notificationsApiProvider.overrideWithValue(LocalNotifications.instance),
  taskSourceProvider.overrideWith((ref) => LocalTaskSource(ref.read(appDatabaseProvider))),
  pickScenesProvider.overrideWithValue(pickWithPhotoPicker),
];
```

`MobileFocusScreen` watches three Android-only providers so they live as long as the app:
`timerNotificationSync`, `taskAlertsSync` and `remindersSync`.

### 4.2 Notifications core: `lib/core/notifications/local_notifications.dart`

A single wrapper around the plugin. It implements `NotificationsApi`, so `TimerController` is unchanged.

- **Channels (R6.7):** `timer` (high importance, with sound), `timer_ongoing` (low, silent), `tasks`, `reminders`.
- **IDs:** the plugin needs `int` IDs, so each kind gets its own range:

  | Kind | ID |
  |---|---|
  | Phase end (`'phase-end'`) | 1 |
  | Ongoing countdown | 2 |
  | Task alert | 100 000 + taskId |
  | Scheduled reminder | 200 000 + reminderId × 10 + weekday (0 = one-off or daily, 1–7 = weekday) |

- **Schedule mode (R6.4):** `exactAllowWhileIdle` if `canScheduleExactNotifications()`, otherwise
  `inexactAllowWhileIdle`. The result is exposed as `exactAlarmsProvider` for the inline warnings.
- **Permissions (R6.6):** `requestPermission()` (called by the timer's first start, as today) asks
  only for `POST_NOTIFICATIONS`. Exact alarms are asked from inline cards (§4.6).
- **Boot and update (R6.5):** the plugin's `ScheduledNotificationBootReceiver` is registered for
  `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED`. The plugin re-registers its own stored schedule.

### 4.3 Timer persistence and catch-up (R1.10)

- `TimerController._set()` also writes the state to prefs (`timer.state`), as JSON with phase,
  remaining, endsAt, startedAt, completedFocus and taskId.
- `build()` restores it, then runs a new pure domain function:

```dart
/// Advances past every phase that ended while the app was dead.
/// Returns the current state and the finished phases to log.
(PomodoroState, List<FinishedPhase>) catchUp(PomodoroState s, TimerSettings t, DateTime now)
```

  The loop: while running and `endsAt <= now`, record the phase as finished at `endsAt`, then advance
  as of `endsAt`. With auto-start off, this stops after one phase. It is shared with macOS, which also
  gains R1.10 for free.
- Limit: if the app is dead and auto-start is on, only the first phase-end notification fires, because
  the following ones were never scheduled. The log is still correct thanks to catch-up.
  `// ponytail: schedule the next N phase-ends ahead if anyone needs it`.

### 4.4 Ongoing countdown notification (R1.11–13)

`timerNotificationSync` listens to `timerProvider`:

| State | Notification ID 2 |
|---|---|
| Running | `ongoing: true`, `usesChronometer: true`, `chronometerCountDown: true`, `when: endsAt`, `timeoutAfter: remaining`, `onlyAlertOnce: true`. Title: phase. Text: task title. Actions: **Pause**, **Skip**. |
| Paused | Not ongoing. Text: "Paused · 12:34 left". Action: **Resume**. |
| Reset, or idle at full length | Cancelled. |

The system renders the countdown, so there's **no foreground service** (D-P1). `timeoutAfter` removes
the notification at zero, before the chronometer would go negative.

### 4.5 Notification actions and taps

Payloads and action IDs are plain strings: `timer`, `task:<id>`, `reminder:<id>`; `pause`, `resume`,
`skip`, `focus:<taskId>`.

**Every action uses `showsUserInterface: true`:** it brings the app up, and `notificationRouter`
handles it in the main isolate. A cold start reads `getNotificationAppLaunchDetails()` after the first
frame. Routing:

| Input | Effect |
|---|---|
| `pause`, `resume`, `skip` | The matching `TimerController` call. |
| `focus:<id>` | `focusOn(id)`. |
| Tap `task:<id>` | Opens the tasks sheet scrolled to that task. |
| Tap `timer` or `reminder:<id>` | Opens the Focus screen. |

`// ponytail: actions open the app; a background isolate that edits persisted timer state is the upgrade if users want pause without leaving the shade.`
**Requirement change:** R5.5 now reads "Start focus opens the app with the focus started" (updated in requirements.md).

### 4.6 Task alerts (R5)

**Schema v5:** add to `LocalTasks` two columns: `dueHasTime` (bool, default false) and
`remindMinutes` (int, nullable; null means no alert). When the user sets a due **time**,
`remindMinutes` takes the default from settings (`alerts.lead`, default 0). Options: 0, 5, 15, 30 or 60.

```dart
/// Desired alerts: open tasks with a timed due date whose fire time is in the future.
List<Alert> taskAlerts(List<Task> tasks, DateTime now);
```

`taskAlertsSync` listens to `tasksProvider`. On each emission it:
1. computes the alerts;
2. cancels pending IDs in the task range that are no longer wanted;
3. calls `zonedSchedule` for each wanted alert, which overwrites the same ID.

This covers complete, delete and reschedule (R5.3) with no per-action hooks. Each alert has a
**Start focus** action (`focus:<id>`).

`Task` gains `dueHasTime` and `remindMinutes`. The Reminders mapping ignores them on macOS.

### 4.7 Scheduled reminders (R6): `lib/features/reminders/`

```
domain/reminder.dart          Reminder {id, title, at (time of day + date), repeat, taskId?}
                              enum Repeat {none, daily, weekdays}; weekdays: Set<int>
                              List<Alert> reminderAlerts(Reminder r)  // one-off: 1, daily: 1 (time), weekdays: 1 per day
data/                         drift table ScheduledReminders (schema v5)
presentation/reminders_sheet.dart   list, add/edit dialog, delete with Undo
```

- One-off reminders use a `TZDateTime` and no matching. Daily uses `matchDateTimeComponents: time`.
  Weekdays use `dayOfWeekAndTime`, one notification per chosen weekday.
- `remindersSync` reconciles the reminder ID range from the table, the same way as §4.6.
- A one-off reminder whose time has passed is shown greyed out as "Done" and can be deleted.

### 4.8 Clock mode (R2): `features/focus/presentation/clock_mode_screen.dart`

A full-screen route pushed from the Focus screen.

```
initState: setPreferredOrientations([landscapeLeft, landscapeRight])
           setEnabledSystemUIMode(SystemUiMode.immersiveSticky)
           listen(timerProvider) → windowChannel 'keepScreenOn'(running)          // R2.5
dispose:   portraitUp, SystemUiMode.edgeToEdge, keepScreenOn(false)                // R2.6
```

- Layout: `SceneryBackground` with a centered `FittedBox(formatClock(...))` at about 45% of the
  height, and the phase and task labels below.
- Tapping toggles a controls overlay (start/pause, skip, exit) that hides after 3 s using a `Timer`
  (R2.4). The system back button simply pops the route.
- Reduce motion: the fades become instant (N3).

### 4.9 Mobile shell: `features/focus/presentation/mobile_focus_screen.dart`

```
┌───────────────────────────┐
│ scenery (full bleed)      │
│                           │
│     [ TimerCard ]         │  ← existing widget
│     current task          │
│                           │
│ ⛶ clock                   │
├───────────────────────────┤
│ Tasks  Scenes  Music  ⏰  ⚙ │  ← glass bottom bar, 48 dp targets
└───────────────────────────┘
```

Each button opens a `showModalBottomSheet` (draggable, glass background) that holds the existing panel
body: `TasksPanel` body, `ScenerySheet` body, `SettingsSheet` body, the new `SpotifySheet` and the new
`RemindersSheet`. The desktop `GlassSheet` side-panel frame isn't used on Android. Where a panel
builds its own frame, its body is extracted into a public widget so both shells share it.

**Tasks on touch (R4.5):** wrap rows in `Dismissible` (swipe right to complete, swipe left to delete
with Undo). A long-press opens the existing menu through `showPlatformMenu`. Adds a due **time** picker
(`showTimePicker`) and an alert lead time picker.

### 4.10 Scenery on Android (R3)

- `scenery_sheet.dart`'s "Add" calls the new `pickScenesProvider` (a function that returns paths).
  It defaults to the current `file_selector` code, and Android overrides it with
  `ImagePicker().pickMultipleMedia()`. Drag and drop isn't wired on Android.
- `SceneryApi` in Kotlin (generated with Pigeon `kotlinOut`):
  - `convertToJpeg`: `ImageDecoder` (API 28+), `Bitmap.compress(JPEG, 90)`. On API under 28 it throws,
    so the file counts as "failed" (R3.9).
  - `videoPoster`: `MediaMetadataRetriever.getFrameAtTime(0)` → JPEG.
- R3.7: the existing background already pauses video on `AppLifecycleState` changes (to be verified
  during the tasks phase).

### 4.11 Spotify (R7): `features/music/presentation/spotify_sheet.dart`

- **Restore** `lib/features/music/domain/spotify_link.dart` and its test from commit `8bc14b1`.
  They were deleted in `25e435a`, and `mini_player.dart` and `onboarding_overlay.dart` still import
  the file, so **the macOS build is currently broken (N7)**.
- The sheet lists the presets plus saved custom links (prefs `music.custom`, as JSON
  `[{name, uri}]`), and has a "Paste link" field that validates with `parseSpotifyLink` (R7.5).
- A tap calls `openUrl(uri)`. `openUrl` allows `spotify:` and `market:` URIs on Android.
- In `MainActivity`, `openUrl` starts `ACTION_VIEW`. On `ActivityNotFoundException` for a `spotify:`
  URI it opens `market://details?id=com.spotify.music`, with an https Play URL as the next fallback
  (R7.4). No `<queries>` element is needed, because the code relies on catching the exception.

### 4.12 Settings (R8)

The existing settings body gains an Android section:
- **Notifications:** a status row and an "Allow" button (Android 13+), or "Open settings" if denied.
- **Exact alarms:** a status row and "Allow", which calls `requestExactAlarmsPermission()`.
- **Default alert time** (R5.2).
- **Privacy policy** → `openUrl('https://castero411.github.io/benkyo/privacy-policy')` (R8.3).

Statuses are re-read on `AppLifecycleState.resumed`, so they update after the user returns from
system settings.

## 5. Android project

- `flutter create --platforms=android --org com.benkyo --project-name benkyo .`, then:
  - set `applicationId` and `namespace` to `com.benkyo.app`, and move `MainActivity.kt` to match (N1.1);
  - turn on `isCoreLibraryDesugaringEnabled` and add the `desugar_jdk_libs` dependency.
  - `compileSdk = 37`: `flutter_local_notifications` requires it. minSdk stays at 24.
- **Manifest:** `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`; the plugin's
  receivers (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`) and the action
  receiver. **No** `INTERNET` in the release manifest, and no `READ_MEDIA_*`.
- `android:screenOrientation` isn't set; orientation is controlled from Dart (§4.1, §4.8).
- **Pigeon:** add `kotlinOut: 'android/app/src/main/kotlin/com/benkyo/app/NativeApi.g.kt'`. Only
  `SceneryApi` is registered on Android. The other host APIs stay unregistered, and their callers
  already handle `PlatformException`.

## 6. Data model changes (schema v4 → v5)

```dart
// LocalTasks
BoolColumn get dueHasTime => boolean().withDefault(const Constant(false))();
IntColumn  get remindMinutes => integer().nullable()();

// new
class ScheduledReminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get at => dateTime()();          // first/only fire; time of day for repeats
  TextColumn get repeat => text()();              // none | daily | weekdays
  TextColumn get weekdays => text().withDefault(const Constant(''))(); // "1,3,5"
  TextColumn get taskId => text().nullable()();
}
```

The migration adds the two columns and the table if `from < 5`. macOS shares the schema and simply
doesn't use the new columns.

## 7. Testing (N8)

| Test | Type |
|---|---|
| `catchUp`: one phase passed; several phases with auto-start; not yet ended | unit |
| `taskAlerts`: completed, deleted, past, date-only, each lead time | unit |
| `reminderAlerts`: one-off, daily, weekdays → IDs and match components | unit |
| `parseSpotifyLink` (restored test) | unit |
| Clock mode: entering sets landscape and immersive; popping restores them (spies on `SystemChannels.platform`) | widget |
| Notification ID ranges never collide | unit |
| Existing timer, task, scene and accessibility tests | unchanged |

Manual checks on a device: the acceptance steps in requirements R1, R2, R3 and R6, including a reboot.

## 8. Risks

| Risk | Mitigation |
|---|---|
| Android 14+ denies exact alarms by default | Fall back to inexact delivery, with inline cards and the Settings row (§4.2, §4.12). |
| OEM battery killers (Xiaomi, Samsung) drop alarms | Out of our control. A Settings help link can come later if users report it. |
| Ongoing notification is user-dismissible on Android 14+ | Acceptable: the phase-end notification is separate and still fires. |
| HEIC on API under 28 | Reported as failed (R3.9). |
| Desktop panels assume a wide layout | Extract the panel bodies; the sheets give a phone-width layout. Verify with `flutter-fix-layout-issues` at 360 dp. |
