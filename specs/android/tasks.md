# Benkyo for Android: Tasks

**Phase:** 3 of 3 · Implements [design.md](design.md) · **Method: TDD.** Each task goes through three
steps: **Red** (write the test and watch it fail), **Green** (write the least code that passes), then
**Refactor**. After each task, `flutter analyze` and `flutter test` must both be clean.
"Manual" marks steps that only a device can verify.

| # | Task | Red (test first) | Green | Req | Status |
|---|---|---|---|---|---|
| T0 | Restore Spotify link parser | `spotify_link_test.dart` (restored) | Restore `spotify_link.dart` from `8bc14b1` | N7, R7.5 | ✅ |
| T1 | Timer catch-up | `catchUp`: not ended; one phase ended; several with auto-start; ended with auto-start off | `catchUp()` in `pomodoro.dart` | R1.10 | ✅ |
| T2 | Timer state persistence | Round-trip `toJson`/`fromJson`; controller restores a running timer and logs the missed phase | `PomodoroState` JSON; `_set` saves; `build` restores + catch-up | R1.10 | ✅ |
| T3 | Notification IDs + task alerts | `taskAlerts`: completed, past, date-only, lead times; ID ranges don't collide | `core/notifications/alerts.dart` | R5.1–3, R5.6 | ✅ |
| T4 | Reminder alerts | `reminderAlerts`: one-off, daily, weekdays → IDs + match | `features/reminders/domain/reminder.dart` | R6.1–2 | ✅ |
| T5 | Schema v5 | `LocalTaskSource` round-trips `dueHasTime`, `remindMinutes`; reminders table CRUD | drift columns, table, migration, `Task` fields | R4.1, R5.2, R6 | ✅ |
| T6 | Android project | — (build: `flutter build apk --debug`) | `flutter create`, `com.benkyo.app`, desugaring, manifest, deps | N1, N1.1 | ✅ |
| T7 | Notifications wrapper + sync | Reconcile: fake plugin gets the right schedule/cancel calls | `LocalNotifications`, `taskAlertsSync`, `remindersSync`, `timerNotificationSync` | R1.4–5, R1.11–13, R5, R6 | ⬜ |
| T8 | Android bootstrap + mobile shell | Widget test: Android variant shows `MobileFocusScreen`, bottom bar opens each sheet | `android.dart`, `mobile_focus_screen.dart`, extracted panel bodies | R4.5–6, N2–3 | ⬜ |
| T9 | Clock mode | Widget test: entering sets landscape + immersive; back restores; tap shows controls that hide after 3 s | `clock_mode_screen.dart`, `keepScreenOn` | R2 | ⬜ |
| T10 | Spotify sheet | Widget test: invalid link rejected; preset tap calls `openUrl('spotify:…')`; custom link saved | `spotify_sheet.dart`, `openUrl` schemes, `MainActivity.openUrl` | R7 | ⬜ |
| T11 | Scenery on Android | Widget test: Add uses `pickScenesProvider` | provider + `image_picker`; Kotlin `SceneryApi` | R3.3, R3.9 | ⬜ |
| T12 | Reminders sheet | Widget test: add, edit, delete with Undo | `reminders_sheet.dart` | R6.1–3 | ⬜ |
| T13 | Settings (Android) | Widget test: privacy link, permission rows | settings section | R8 | ⬜ |
| T14 | Device verification | Manual: acceptance steps for R1, R2, R3, R6 (reboot), TalkBack pass | fixes | all | ⬜ |
