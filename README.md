# Benkyo

**Benkyo** (勉強, "study") is a calm macOS desktop app for focused work. It brings together a
Pomodoro timer, prioritized tasks synced with Apple Reminders, your calendar, notes, Spotify
control, and a lofi scenery background in one window, so you never have to leave it while you work.

Built with Flutter, with a small native Swift layer for macOS-only features.

> **Status:** early development. Phases 1–4 (skeleton, tasks + Reminders sync, timer, scenery) are done. See [Roadmap](#roadmap) for
> what works today and what's coming. The full product plan lives in [PLAN.md](PLAN.md).

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Using the app](#using-the-app)
- [Project structure](#project-structure)
- [Architecture](#architecture)
- [Design system](#design-system)
- [Native macOS layer](#native-macos-layer)
- [Permissions](#permissions)
- [Code quality and testing](#code-quality-and-testing)
- [Roadmap](#roadmap)
- [Contributing conventions](#contributing-conventions)

---

## Features

| Feature | What it does | Status |
|---|---|---|
| **Focus screen** | A single home screen: full-window scenery, a large timer on a glass card, and slide-in Tasks and Today panels. | ✅ Layout and panels |
| **Zen mode** | Native macOS full screen (same as View → Enter Full Screen). | ✅ |
| **Keyboard-first** | Every main action has a shortcut, and each one is listed in the native menu bar. | ✅ Core shortcuts |
| **Pomodoro timer** | Focus, short break and long break (25 / 5 / 15 minutes, long break after 4 sessions), with macOS notifications, a session log, and "Focus on This Task". Stays correct across sleep. | ✅ |
| **Tasks** | Priorities P1 to P4, quick-add (`!1` to `!4` in the title sets the priority), Today / All / Done views, rename, due today/tomorrow, delete with Undo. "Focus on this task" comes with the timer. | ✅ |
| **Apple Reminders sync** | Tasks live in a "Benkyo" list in Apple Reminders, so they show up on iPhone and Apple Watch. If you deny access, tasks are kept in the app only. | ✅ |
| **Calendar** | A Today panel showing your Calendar events, plus scheduling a task as an event. | Phase 6 |
| **Scenery** | 6 built-in lofi photos + 2 rain video loops (openly licensed, credited). Add your own photos (incl. iPhone HEIC) and videos by picker or drag & drop. Per-scene dim and blur; optional change each phase. | ✅ |
| **Spotify** | Play, pause, skip, see the current track and choose playlists. Works with **free and Premium** accounts. | Phase 5 |
| **Notes** | Markdown notes, optionally linked to a task or a focus session. | Phase 7 |

---

## Requirements

| Tool | Version |
|---|---|
| macOS | **14 (Sonoma) or later**, because the Reminders and Calendar access APIs need it. |
| Flutter | 3.47 or later, stable channel |
| Dart | 3.13 or later (comes with Flutter) |
| Xcode | A recent version that can build for macOS, with its command-line tools installed |
| Spotify desktop app | Optional. Needed only for music control (Phase 5). |

Check your setup:

```sh
flutter doctor
```

---

## Getting started

```sh
# 1. Install dependencies
flutter pub get

# 2. Regenerate code (only after editing tables or the native contract)
dart run build_runner build            # drift → lib/core/db/app_database.g.dart
dart run pigeon --input pigeons/native_api.dart   # → native_api.g.dart + NativeApi.g.swift

# 3. Run in debug mode
flutter run -d macos

# 4. Build a release app
flutter build macos
# → build/macos/Build/Products/Release/Benkyo.app
```

To work on the native code, open `macos/Runner.xcworkspace` in Xcode.

---

## Using the app

### Keyboard shortcuts

| Key | Action | Where it's handled |
|---|---|---|
| `⌘N` | New task (opens Tasks and focuses the quick-add field) | Menu bar: Task |
| `⌘T` | Show or hide Tasks | Menu bar: View |
| `⌘D` | Show or hide Today | Menu bar: View |
| `F` | Zen mode: enter or exit full screen | In-app |
| `⌃⌘F` | Enter / Exit Full Screen (standard macOS item) | Menu bar: View |
| `Esc` | Leave a text field; otherwise close panels or the Scenery sheet | In-app |
| `Space` | Start or pause the timer | In-app (also in the Timer menu) |
| `⌘R` | Reset the current phase | Menu bar: Timer |
| `⌘→` | Skip to the next phase | Menu bar: Timer |
| `⌘E` | Open or close Scenery | Menu bar: View |
| `⌘,` | Settings | Coming with Settings |

**Why some shortcuts are in the menu bar and some are in the app:** `⌘` shortcuts are native
menu items, so you can find them in the menus as usual on macOS. Single keys (`F`, `Esc`, `Space`) are
handled inside the app instead. That way they **never trigger while you're typing** in a text field,
since a menu-bar shortcut would catch those keys even mid-sentence.

### Timer

- Pick **Focus**, **Short break** or **Long break** with the tabs, then press **Start** (or `Space`).
- After each focus session, you get a short break. Every 4th focus session is followed by a long
  break. The dots show where you are in the cycle.
- When a phase ends, macOS shows a notification (Benkyo asks for permission the first time you press
  Start), and the next phase is loaded, ready to start.
- **Focus on a task:** right-click a task (or `⋯`) and choose **Focus on This Task**. The task
  appears under the timer with how many focus sessions it has received. Click it to open Tasks,
  or click × to unlink it.
- **Sleep-proof:** the timer stores when the phase *ends* (wall clock), not a countdown. Close the
  lid mid-session and on wake it shows the right time, or moves on if the phase already ended.
- Durations are fixed at 25 / 5 / 15 for now. They become editable with the Settings screen.

### Scenery

- Open **Scenery** with the landscape button (top right) or `⌘E`; the same button or `⌘E`
  closes it again (as do `Esc` and clicking outside). Click a scene to switch; it cross-fades in.
- **Adjust** (per scene, remembered): **Dim** darkens the scene so the timer stays readable,
  **Blur** softens busy photos. **Change scene each phase** moves to the next scene whenever the
  timer moves to a new phase.
- **Add your own:** *Add Scenery…* in the sheet, or drop files anywhere on the window. JPEG, PNG,
  WebP, HEIC/HEIF and TIFF photos (HEIC/TIFF are converted to JPEG), and MP4/MOV/M4V videos.
  Files are copied into Benkyo, so moving or deleting the originals doesn't break them.
- **Remove** your own scene: right-click it → *Remove from Benkyo* (Undo available). The copy is
  deleted only once Undo is no longer possible.
- Videos play muted and looped, and pause while Benkyo is hidden or minimized.
- Built-in media credits: [`assets/scenery/ATTRIBUTION.md`](assets/scenery/ATTRIBUTION.md), also
  shown in the sheet for the selected scene.

### Tasks

- **Quick-add:** type a title and press Enter. Add `!1` to `!4` anywhere to set the priority
  (`Fix login !1`). With no marker, the task is P4.
- **Views:** *Today* shows open tasks that are due today, overdue, or have no date. *All* shows
  every open task. *Done* shows tasks completed in the last 7 days.
- **Order:** priority, then due date, then title.
- **Edit:** double-click a task to rename it. Right-click it (or use the `⋯` button) to change
  priority, set it due today or tomorrow, rename or delete it. Completing and deleting show an
  **Undo** toast.
- **Reminders sync:** the Tasks panel offers "Sync with Apple Reminders". Tap *Turn on*, allow
  access, and any tasks you already added move into a Reminders list called **Benkyo**. From then
  on, changes made anywhere (Reminders.app, iPhone, Watch) appear in Benkyo straight away. If
  access is denied, tasks stay on this Mac and the card links to System Settings.

### Zen mode (full screen)

Press `F` (or the full-screen button at the top right) to enter native macOS full screen, and
again to exit. It's exactly the standard **View → Enter Full Screen** (`⌃⌘F`); nothing in the
interface hides.

---

## Project structure

The code is organized **by feature**. Everything for one feature lives in one folder, split
into layers only where that helps.

```text
lib/
├── main.dart                     # Entry point: ProviderScope + BenkyoApp
├── app/
│   ├── app.dart                  # MaterialApp, native menu bar, single-key handling
│   └── theme/
│       └── tokens.dart           # Design tokens + ThemeData (single source of the look)
├── core/
│   ├── db/app_database.dart      # drift: local_tasks, sessions, user_scenes, prefs (+ .g.dart)
│   ├── native/native_api.g.dart  # Pigeon-generated Dart side of the native bridge
│   └── widgets/
│       ├── glass_panel.dart      # Shared frosted-glass surface
│       └── platform_menu.dart    # Context/pull-down menus: native NSMenu on macOS
└── features/
    ├── focus/
    │   └── presentation/
    │       ├── focus_screen.dart # Home screen: timer card, edge tabs, panels
    │       └── focus_ui.dart     # Panel state + full-screen channel
    ├── scenery/
    │   ├── domain/scene.dart     # Scene model, built-in catalog + credits, import rules, rotation
    │   └── presentation/
    │       ├── scenery_providers.dart   # Current scene, dim/blur, rotate, import/remove
    │       ├── scenery_background.dart  # Full-window image/video, cross-fade, dim, blur
    │       ├── scenery_sheet.dart       # Picker: grids, Add Scenery…, Adjust, credits
    │       └── scenery_drop_target.dart # Drop files anywhere to import
    ├── timer/
    │   ├── domain/pomodoro.dart  # Pure timer state + transitions (start/pause/tick/advance)
    │   └── presentation/
    │       ├── timer_controller.dart  # Ticker, notifications, session log, focus counts
    │       └── timer_card.dart        # Phase tabs, clock, dots, controls, task chip
    └── tasks/
        ├── domain/task.dart      # Task model, priority mapping, quick-add parser, view filter
        ├── data/task_sources.dart       # TaskSource: Reminders + local (drift)
        └── presentation/
            ├── tasks_providers.dart     # Sync status, active source, task stream
            └── tasks_panel.dart         # Panel UI: sync card, views, quick-add, rows

pigeons/native_api.dart           # Typed Dart ↔ Swift contract (source of truth)

assets/scenery/                   # Built-in photos, video loops + posters, ATTRIBUTION.md

macos/Runner/
├── MainFlutterWindow.swift       # Window chrome, full-screen channel, bridge registration
├── RemindersBridge.swift         # EventKit implementation of RemindersApi
├── MenuBridge.swift              # Native NSMenu pop-ups (MenuApi)
├── NotificationsBridge.swift     # Phase-end notifications (NotificationsApi)
├── SceneryBridge.swift           # HEIC→JPEG, video poster frames (SceneryApi)
└── NativeApi.g.swift             # Pigeon-generated Swift side

test/
├── features/tasks/task_test.dart # Priority mapping, quick-add parsing, view filters
├── features/timer/pomodoro_test.dart # Cycle order, pause/resume, sleep, rounding, auto-start
├── features/scenery/scene_test.dart  # Built-in files + credits exist, import kinds, rotation
└── widget_test.dart              # Panels, shortcuts, full screen, sheet toggle, flows
```

As more features are added (see [PLAN.md](PLAN.md)), each one follows the same shape:

```text
features/<feature>/
├── data/          # Repositories: drift tables, native bridge calls
├── domain/        # Models and real logic (only where it exists, e.g. timer, tasks)
└── presentation/  # Widgets + Riverpod providers
```

Planned feature folders: `timer`, `tasks`, `notes`, `music`, `scenery`, `calendar`, `settings`,
`onboarding`.

---

## Architecture

### State management: Riverpod

The app uses [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) with plain `Notifier`
classes, and no code generation yet.

- **State is immutable.** Simple state uses Dart records. For example, `FocusUiState` is
  `({bool tasksOpen, bool todayOpen})`.
- **Tests replace dependencies through Riverpod overrides** instead of interfaces. An interface is
  added only when a feature really has two implementations (for example, tasks will have a Reminders
  source and a local-only source).

### Why some planned packages aren't added yet

Dependencies are added in the phase that first needs them:

| Package | Added in | Why it waits |
|---|---|---|
| `go_router` | When a second screen exists | Today the app is one screen with overlays. |
| `window_manager` | Windows port | On macOS, a few lines of Swift do the same job. |

### Data flow (target design)

```text
Swift (EventKit / AppleScript)
        │  Pigeon (typed channels)
        ▼
features/*/data  ──►  Riverpod providers  ──►  features/*/presentation
        ▲
drift (SQLite): app-only data (session log, notes, scenes, task sort order)
```

- **Apple Reminders holds the tasks themselves.** The app doesn't keep its own copy, so there is no
  two-way sync and no conflicts. The local database stores only what Reminders can't
  (manual sort order and links to notes and sessions).
- **The timer is based on timestamps.** It stores `endsAt` and works out the remaining time from
  it, so it stays accurate when the Mac sleeps. A 250 ms ticker compares against the wall clock,
  updates the screen only when the displayed second changes, and finishes the phase as soon as
  `endsAt` has passed. The clock is injected (`clockProvider`), so tests can jump time.
- **Notifications are booked when a phase starts**, for its end time, and cancelled on pause,
  reset or skip. They fire on time even if macOS throttles the app in the background (App Nap).
- **Settings** live in the `prefs` key–value table (`db.prefsWithPrefix`, `db.setPref`), e.g.
  `scene.current`, `scene.rotate`, `scene.adjust.<id>` = `dim,blur`.
- **Database migrations:** `schemaVersion` 2 adds `sessions`, 3 adds `user_scenes` and `prefs`. Bump the version and add an
  `onUpgrade` step for every schema change, so existing users keep their data.

---

## Design system

The look comes from the approved Phase 0 design: dark glass panels over the lofi scenery, with a
warm lamp-amber accent.

All values live in [`lib/app/theme/tokens.dart`](lib/app/theme/tokens.dart). **Don't hard-code
colors, sizes or durations in widgets; use the `Tokens` class instead.** This is what will make
the planned appearance presets possible: a preset is just another set of these values.

| Group | Values |
|---|---|
| Colors | Background `#141223`, glass `#161424`, accent `#F2B36B`, text on accent `#1B1530`, success `#8FD3C1` |
| Priority colors | P1 `#FF8A6B`, P2 `#F2B36B`, P3 `#7FB5FF`, P4 `#B4B0C4`. Every priority also has a P1 to P4 text label, so meaning never depends on color alone. |
| Glass | Glass color at 52% opacity (72% for panels), 28 px background blur, white border at 12% |
| Corner radius | 8, 12, 14, 22 (panels), 28 (timer card) |
| Spacing | 4-point scale: 4, 8, 12, 16, 24, 32, 48 |
| Motion | 200 ms (buttons and toasts), 300 ms (panels), 600 ms (scene fade), `easeOutCubic` |
| Type | System font (SF Pro). Timer digits are 112 pt semibold with fixed-width numbers. |

### UX rules

- **Reduce motion:** always get animation durations through `Tokens.motion(context, duration)`. It
  returns zero when macOS "Reduce motion" is turned on.
- **Accessibility:** controls that show only an icon need a `tooltip` or a `Semantics` label, and
  text drawn over scenery needs a background behind it dark enough to meet WCAG AA contrast.
- **Forgiving:** use an "Undo" toast instead of a confirmation dialog, show inline errors with a
  button that fixes the problem, and give every empty state one clear action.
- **Permissions:** ask only when the feature is first used, with a one-line reason. Never ask at
  launch.
- **Title bar:** the hidden title bar still takes the top ~28 px of clicks. Keep interactive
  controls below `FocusScreen._titleBar` (36 px).

The design mockups are on the Phase 0 canvas, linked in [PLAN.md](PLAN.md).

---

## Native macOS layer

### Window chrome

[`MainFlutterWindow.swift`](macos/Runner/MainFlutterWindow.swift) sets up the window directly in
Swift, so no extra package is needed:

- A transparent, hidden title bar with full-size content, so the scenery runs under the traffic
  lights.
- A minimum window size of 1024 × 680.
- The window background matches the app background, so the window never flashes white on launch.
- Full screen is allowed (`fullScreenPrimary`).

### Window channel: `benkyo/window`

| Direction | Method | Effect |
|---|---|---|
| Dart → Swift | `toggleFullScreen` | `NSWindow.toggleFullScreen`, the same as the green button or ⌃⌘F |

### Reminders bridge (Pigeon)

Defined in [`pigeons/native_api.dart`](pigeons/native_api.dart), implemented in
[`RemindersBridge.swift`](macos/Runner/RemindersBridge.swift):

| Method | Notes |
|---|---|
| `status()` | `notDetermined` / `granted` / `denied`. Never shows a prompt. |
| `requestAccess()` | Shows the system prompt (`requestFullAccessToReminders`). |
| `fetch()` | Open reminders plus those completed in the last 7 days, from the **Benkyo** list. Creates the list if it's missing. |
| `save(reminder)` | Creates or updates. Editing loads the existing reminder first, so fields Benkyo doesn't show (alarms, URL, subtasks) are kept. |
| `delete(id)`, `openPrivacySettings()` | |
| `RemindersEvents.changed()` (Swift → Dart) | Fired on `EKEventStoreChanged`, which triggers a refetch. No polling. |

Priority mapping: P1 ↔ High (1), P2 ↔ Medium (5), P3 ↔ Low (9), P4 ↔ None (0). Other EventKit
values map to the nearest group. A due time of exactly midnight is treated as "date only".

### Native menus (Pigeon)

Context menus (right-click) and pull-down menus (the `⋯` button) are real **NSMenu**s on macOS,
shown through `MenuApi.show(items, x, y)` from
[`MenuBridge.swift`](macos/Runner/MenuBridge.swift). That gives them the system's own look and
behavior: blur, SF typography, checkmarks, submenus, arrow-key navigation, typing to jump to an
item, and VoiceOver.

From Dart, call `showPlatformMenu(context, globalPosition, entries)` in
[`platform_menu.dart`](lib/core/widgets/platform_menu.dart). On other platforms it falls back to
a plain Flutter menu for now.

Menu content follows Apple's Human Interface Guidelines for menus:

- Title-case labels: "Mark as Completed", "Due Date".
- Related choices go in a submenu, with a checkmark on the current value ("Priority ▸", "Due Date ▸").
- Groups are divided by separators, and destructive actions ("Delete") come last in their own
  group.
- An ellipsis ("…") is used only when an item opens another window or dialog to collect more
  input. That's why inline "Rename" has none.

New Swift files must be added to the Runner target in Xcode (or with the `xcodeproj` gem).

### Notifications bridge (Pigeon)

`NotificationsApi` ([`NotificationsBridge.swift`](macos/Runner/NotificationsBridge.swift)):
`requestPermission()`, `schedule(id, title, body, atMillis)` (a `UNTimeIntervalNotificationTrigger`;
the same id replaces the previous one), and `cancel(id)`. The bridge also tells macOS to show the
banner while Benkyo is frontmost. Failures are swallowed on purpose: a missing notification must
never break the timer.

### Scenery bridge (Pigeon)

`SceneryApi` ([`SceneryBridge.swift`](macos/Runner/SceneryBridge.swift)) uses the system codecs:
`convertToJpeg(input, output)` (ImageIO, for HEIC/TIFF, which Flutter can't reliably decode) and
`videoPoster(input, output)` (AVFoundation frame at 0.5 s, saved as `<video>.jpg`, used as the
thumbnail and shown while the video loads).

Planned bridges: Calendar (EventKit) and Spotify (AppleScript plus the
`com.spotify.client.PlaybackStateChanged` notification).

---

## Permissions

Benkyo asks for each permission only when you first use the feature that needs it.

| Permission | Needed for | Phase |
|---|---|---|
| Reminders (full access) | Syncing tasks with Apple Reminders | ✅ 2 |
| Notifications | Phase-end banners and sound (asked on first Start) | ✅ 3 |
| Calendars (full access) | The Today panel and scheduling tasks | 6 |
| Automation → Spotify | Controlling the Spotify desktop app | 5 |
| Files you choose (read-only) | Importing your own scenery images and videos | ✅ 4 |
| Network (outgoing) | Loading album artwork | 5 |

The matching entitlements and `Info.plist` descriptions are added in the phase that introduces each
feature.

---

## Code quality and testing

```sh
flutter analyze   # lints: very_good_analysis (strict)
dart format lib test
flutter test
```

**Lint rules:** [`very_good_analysis`](https://pub.dev/packages/very_good_analysis), with two
rules turned off on purpose (see `analysis_options.yaml`):

- `public_member_api_docs`: this is an app, not a library. Write comments only where they explain
  *why* something is done.
- `unnecessary_type_name_in_constructor`: keeps the usual Flutter style of naming constructors
  after the class.

**Testing approach:** each piece of real logic gets one focused test, not a full suite for every
function. Widget tests run as macOS, because the native menu bar only exists there:

```dart
testWidgets('…', (tester) async { … },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS));
```

Native channels are replaced with mocks using
`tester.binding.defaultBinaryMessenger.setMockMethodCallHandler`. The tests cover opening and
closing panels, `Esc`, `F` sending `toggleFullScreen`, and the Scenery sheet toggling instead of
stacking.

Widget tests that use the database run drift in memory with `closeStreamsSynchronously: true`
(otherwise drift leaves a timer pending that the test framework flags), and use a fake
`RemindersApi` through a provider override.

The timer widget test fakes the clock and jumps it 26 minutes ahead ("sleep") to check that the
phase ends, the break loads, and the session is logged against the task.

The scenery widget test picks a scene in the sheet, turns on *Change scene each phase*, skips a
timer phase, and checks the scene advanced and both choices were saved. Writing it caught two
real layout bugs (an overflowing tile and a hidden list-tile highlight).

Planned tests: reading Spotify links.

---

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 | Design: Focus screen, panels, scenery picker, onboarding, tokens | ✅ |
| 1 | Skeleton: lints, tokens and theme, window chrome, menu bar, shortcuts, zen full screen | ✅ |
| 2 | drift and Pigeon setup, tasks with Apple Reminders sync, local-only fallback | ✅ |
| 3 | Timer, notifications, session log | ✅ |
| 4 | Scenery: built-in scenes, importing your own, video, dim and blur | ✅ |
| 5 | Spotify through AppleScript (free and Premium), playlist presets, pasting a link | Next |
| 6 | Calendar Today panel, scheduling a task | |
| 7 | Notes | |
| 8 | Onboarding, accessibility check, app icon, polish | |

**Later:**
- Appearance presets (switchable looks built on the design tokens)
- A **Windows port**
- A timer in the menu bar
- Focus statistics
- Cloud sync for notes
- Browsing your Spotify library inside the app

The plan for the Windows port, including what replaces each macOS-only part, is in
[PLAN.md](PLAN.md#future-windows-port).

---

## Contributing conventions

- **Put new code in the feature it belongs to.** Shared widgets go in `core/widgets` only after
  a second feature needs them.
- **Use tokens, not literal values.** Use `Tokens.*` for colors, spacing, radii and durations.
- **No speculative layers.** Don't add an interface that has only one implementation, scaffolding
  "for later", or a dependency that a few lines of code can replace.
- **Native code goes through typed channels.** Use one clearly named channel per feature
  (`benkyo/<feature>`), and Pigeon once the API is more than one or two methods.
- **Every new shortcut gets a menu item** (`⌘` shortcuts) or a guard so it doesn't fire while
  typing (single keys).
- Before you push, `flutter analyze` must be clean and `flutter test` must pass.
