# Benkyo for Android: Requirements

**Phase:** 1 of 3 (requirements → design → tasks) · **Status:** Draft, awaiting approval · **Date:** 2026-11-19

Port the macOS Benkyo pomodoro app to Android phones from the same Flutter codebase. Requirements use
EARS wording (*WHEN / WHILE / IF … THE app SHALL …*). Each one has an ID so the design and tasks
documents can point back to it.

## Decisions taken

| # | Decision | Why |
|---|---|---|
| D1 | **Android only** for this port. The macOS app keeps working. | The user picked this platform. |
| D2 | **Tasks live in the local drift DB** (`LocalTaskSource`). No Reminders or cloud sync. | Android has no Apple Reminders, and the local source already exists. |
| D3 | **Spotify by deep link only:** the app opens the Spotify app on a playlist. No login, no in-app controls. | Works on Free, needs no Spotify developer app, and avoids the App Remote SDK. |
| D4 | **Shared code stays shared:** the timer domain, task model, scene model and DB are reused. Android adds data sources; it does not fork the features. | Follows the "Future: Windows port" approach in PLAN.md. |

## Glossary

- **Phase:** focus, short break or long break (existing `Phase` enum).
- **Focus screen:** the home screen, with the scenery background and the timer card.
- **Clock mode:** the full-screen landscape view that shows only the timer.
- **Scene:** a background image or looping video, either built-in or added by the user.
- **Task reminder:** a local notification tied to a task's due time.
- **Scheduled notification:** a reminder the user creates for a chosen time, either linked to a task or standalone.

---

## R1 Pomodoro timer (same concept as desktop)

**Story:** As a student, I want focus/break cycles on my phone so I can study the same way I do on my Mac.

| ID | Requirement |
|---|---|
| R1.1 | THE app SHALL offer focus, short break and long break phases, with defaults of 25 / 5 / 15 minutes and a long break after 4 focus sessions. |
| R1.2 | THE user SHALL be able to start, pause, reset and skip the current phase, and pick a phase by hand. |
| R1.3 | WHILE the timer runs, THE app SHALL derive the remaining time from the wall-clock end time (`endsAt`) so it stays correct when the app is backgrounded, killed or in Doze. |
| R1.4 | WHEN a phase starts, THE app SHALL schedule a local notification for its end time, and SHALL cancel it on pause, reset or skip. |
| R1.5 | WHEN a phase ends while the app is closed or in the background, THE user SHALL get a notification within ±5 s of the end time (needs exact alarms, see R6.4). |
| R1.6 | WHEN a phase ends, THE app SHALL log a session row `(taskId, start, end, phase)`, as the desktop app does. |
| R1.7 | WHERE "auto-start next phase" is on, THE app SHALL start the next phase immediately. |
| R1.8 | THE user SHALL be able to change the phase lengths, the number of sessions before a long break and auto-start in Settings, and the values SHALL persist. |
| R1.9 | THE user SHALL be able to attach a task to the timer ("Focus on this task"), and the Focus screen SHALL show that task's title. |
| R1.10 | IF the app is killed while the timer is running, THEN THE app SHALL restore the running timer on next launch. *(Deferred on desktop; required on mobile, where Android routinely kills apps.)* |

| R1.11 | WHILE a phase is running, THE app SHALL show an ongoing "timer running" notification with a live countdown to `endsAt`, the phase and task, and Pause and Skip actions. |
| R1.12 | WHEN the timer is paused, reset or reaches its end, THE app SHALL update or remove the ongoing notification. Pause SHALL show the frozen remaining time with a Resume action. |
| R1.13 | THE ongoing notification SHALL NOT require a long-running service: the countdown is rendered by the system (notification chronometer). IF the design finds a foreground service unavoidable, THEN it SHALL be declared as recorded in [privacy-notes.md](privacy-notes.md). |

**Acceptance:** start a 1-minute focus, swipe the app away, and the end notification arrives on time.
While it runs, the notification shade shows a live countdown, and Pause there pauses the timer.
Reopen the app and it shows the next phase with the session logged.

## R2 Clock mode (full screen, landscape)

**Story:** As a user, I want to rotate into a big, distraction-free clock while I study.

| ID | Requirement |
|---|---|
| R2.1 | THE Focus screen SHALL have a button that enters clock mode. |
| R2.2 | WHEN clock mode is entered, THE app SHALL lock the orientation to landscape (either side) and hide the system status and navigation bars (immersive sticky). |
| R2.3 | WHILE in clock mode, THE screen SHALL show the scenery background and a large timer (≥ 40% of screen height) with the phase label and current task. Panels and other controls stay hidden. |
| R2.4 | WHILE in clock mode, a single tap SHALL show controls (start/pause, skip, exit) that auto-hide after 3 s. |
| R2.5 | WHILE in clock mode and the timer is running, THE screen SHALL stay awake. |
| R2.6 | WHEN the user exits clock mode (exit control or system back), THE app SHALL restore portrait orientation and the system bars. |
| R2.7 | Outside clock mode, THE app SHALL be portrait-only (phones). |

**Acceptance:** tap clock mode and the screen turns landscape with no system bars and a large ticking clock. Press
back and the app returns to portrait with the bars back.

## R3 Backgrounds (scenery)

**Story:** As a user, I want a calm background and the option to use my own photos and videos.

| ID | Requirement |
|---|---|
| R3.1 | THE app SHALL ship the existing built-in scenes (images and video loops) with their credits. |
| R3.2 | THE user SHALL be able to pick the active scene from a gallery sheet, and the choice SHALL persist. |
| R3.3 | THE user SHALL be able to add custom images (jpg, png, webp, and heic where the device decodes it) and videos (mp4) through the Android system photo picker. The app requests **no** storage permission. |
| R3.4 | WHEN media is added, THE app SHALL copy it into app-private storage so it survives the source being deleted. |
| R3.5 | THE user SHALL be able to delete custom scenes. Built-in scenes cannot be deleted. |
| R3.6 | THE user SHALL be able to set dim and blur for each scene. |
| R3.7 | Video scenes SHALL loop muted, and SHALL pause while the app is in the background. |
| R3.8 | WHERE "change scene each phase" is on, THE app SHALL rotate the scene at each phase change. |
| R3.9 | IF an imported file can't be decoded, THEN THE app SHALL skip it and report "N added, M failed". |

**Acceptance:** add a gallery photo, select it, and it shows behind the timer. It's still there after the app restarts.

## R4 Tasks

**Story:** As a user, I want a prioritized task list on my phone.

| ID | Requirement |
|---|---|
| R4.1 | THE app SHALL store tasks locally (D2), with title, priority P1–P4, optional due date/time and completion. |
| R4.2 | THE user SHALL be able to quick-add a task, where `!1`–`!4` in the title sets the priority (the existing `parseQuickAdd`). |
| R4.3 | THE app SHALL offer Today / All / Done views, sorted by priority, then due time, then manual order. |
| R4.4 | THE user SHALL be able to rename, complete, un-complete, set a due date and time on, and delete a task. Deleting offers Undo. |
| R4.5 | Task actions SHALL be reachable by touch: swipe to complete or delete, and long-press or a menu for the rest. |
| R4.6 | THE tasks list SHALL open from the Focus screen as a bottom sheet. |

## R5 Task notifications ("when tasks come")

**Story:** As a user, I want my phone to tell me when a task is due.

| ID | Requirement |
|---|---|
| R5.1 | WHEN a task has a due date **with a time**, THE app SHALL schedule a notification at that time. |
| R5.2 | THE user SHALL be able to pick a lead time for each task: at due time (default), 5, 15 or 30 minutes before, or 1 hour before. |
| R5.3 | WHEN a task is completed, deleted or its due time changes, THE app SHALL cancel or reschedule its notification. |
| R5.4 | WHEN the user taps a task notification, THE app SHALL open with that task shown. |
| R5.5 | A task notification SHALL have a **"Start focus"** action that starts the timer on that task without opening the full UI first. |
| R5.6 | A task due with a date only (no time) SHALL get no notification by default. |

## R6 Scheduled notifications

**Story:** As a user, I want to set reminders for specific times, such as "start studying at 18:00".

| ID | Requirement |
|---|---|
| R6.1 | THE user SHALL be able to create a scheduled notification with a title, a date and time, and an optional linked task. |
| R6.2 | THE user SHALL be able to repeat a scheduled notification: none, daily, or on chosen weekdays. |
| R6.3 | THE user SHALL be able to list, edit and delete scheduled notifications. |
| R6.4 | THE app SHALL deliver task, timer and scheduled notifications at exact times. On Android 12+ it SHALL ask for exact-alarm access in context, with a one-line reason. IF that access is denied, THEN the app SHALL fall back to inexact delivery and show an inline warning. |
| R6.5 | Scheduled notifications SHALL survive device reboot and app updates. |
| R6.6 | On Android 13+, THE app SHALL request the notification permission the first time a notification is needed, not at launch. IF it is denied, THEN the app SHALL show an inline banner with a button that opens system settings. |
| R6.7 | Notifications SHALL use separate channels (Timer, Tasks, Reminders) so the user can tune each one in system settings. |

**Acceptance:** schedule "Study" at a time 2 minutes away and reboot the phone. The notification still arrives on time.

## R7 Spotify (deep link)

**Story:** As a user, I want to start my focus music from inside the app.

| ID | Requirement |
|---|---|
| R7.1 | THE app SHALL show the 5 focus playlist presets from the desktop app. |
| R7.2 | THE user SHALL be able to paste any Spotify link (`open.spotify.com/...` or `spotify:...`) and save it as a custom preset. |
| R7.3 | WHEN a preset is tapped, THE app SHALL open it in the Spotify app (`spotify:` URI) so music plays on the device. |
| R7.4 | IF Spotify isn't installed, THEN THE app SHALL open the Play Store listing for Spotify. |
| R7.5 | Pasted links that aren't Spotify links SHALL be rejected with an inline message. |
| R7.6 | THE app SHALL NOT show now-playing info or playback controls (D3). |

*Known limit:* the Spotify app decides whether a playlist auto-plays after the deep link opens. Usually
the user taps play once inside Spotify, and the requirements accept that.

## R8 Settings

| ID | Requirement |
|---|---|
| R8.1 | Settings SHALL hold the timer options (R1.8), scene rotation (R3.8), the default task notification lead time (R5.2) and scenery credits (R3.1). |
| R8.2 | Settings SHALL show the notification and exact-alarm permission status, with buttons to fix each. |
| R8.3 | Settings SHALL show a "Privacy policy" link that opens the hosted policy URL in the browser (Play requirement). |

## Non-functional

| ID | Requirement |
|---|---|
| N1 | **Platform:** Flutter's default minimum (currently API 24, Android 7.0). Raise it only when a dependency requires it, and record why. Phones in portrait plus landscape clock mode; tablets work but have no special layout. |
| N1.1 | **Application ID:** `com.benkyo.app`. It can never change after the first Play upload. `flutter create --org com.benkyo` would generate `com.benkyo.benkyo`, so set `applicationId` and `namespace` in `android/app/build.gradle.kts` by hand. |
| N2 | **Look:** reuse `tokens.dart` and the glass style. Touch targets ≥ 48 dp. Follow system light/dark. |
| N3 | **Accessibility:** TalkBack labels on every control, honor the system font scale, WCAG AA contrast over the scenery scrim, and turn animations off when the system removes them. |
| N4 | **Performance:** cold start under 2 s to an interactive Focus screen on a mid-range device. Video scenes play without dropping frames at 1080p. |
| N5 | **Battery:** no background polling. The timer and reminders rely on scheduled alarms, not a running service. |
| N6 | **Privacy:** no network calls except opening Spotify or Play Store links. No analytics. All data stays on the device. Every permission, declaration and data flow is tracked in [privacy-notes.md](privacy-notes.md). |
| N7 | **Desktop unaffected:** the macOS build, its Reminders/Calendar/AppleScript features and its tests keep passing. |
| N8 | **Tests:** unit tests cover notification scheduling (each task-change case in R5.3, plus repeat rules) and Spotify link parsing. A widget test covers entering and exiting clock mode. Existing timer and task tests run unchanged. |

## Next version (v2)

- **Notes:** Markdown notes (already cross-platform).
- **Onboarding tour:** the 3-step welcome on first launch.

## Out of scope

Calendar / Today panel · keyboard shortcuts and menu bar · drag & drop import · Spotify playback
control or now-playing · task or cloud sync with the Mac app · home-screen widgets · tablet layout.

## Open questions

None. Next step: [privacy-notes.md](privacy-notes.md), then `design.md`.
