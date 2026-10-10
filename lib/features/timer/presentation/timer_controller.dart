import 'dart:async';

import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/timer/domain/pomodoro.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timerSettingsProvider =
    NotifierProvider<TimerSettingsController, TimerSettings>(
      TimerSettingsController.new,
    );

/// Timer lengths from Settings, stored in the prefs table.
class TimerSettingsController extends Notifier<TimerSettings> {
  @override
  TimerSettings build() {
    unawaited(_load());
    return const TimerSettings();
  }

  Future<void> _load() async {
    final p = await ref.read(appDatabaseProvider).prefsWithPrefix('timer.');
    Duration? mins(String key) {
      final v = int.tryParse(p[key] ?? '');
      return v == null ? null : Duration(minutes: v);
    }

    state = state.copyWith(
      focus: mins('timer.focus'),
      shortBreak: mins('timer.short'),
      longBreak: mins('timer.long'),
      sessionsBeforeLongBreak: int.tryParse(p['timer.cycle'] ?? ''),
      autoStartNext: p['timer.auto'] == null ? null : p['timer.auto'] == 'true',
    );
  }

  Future<void> update(TimerSettings s) async {
    state = s;
    final db = ref.read(appDatabaseProvider);
    await db.setPref('timer.focus', '${s.focus.inMinutes}');
    await db.setPref('timer.short', '${s.shortBreak.inMinutes}');
    await db.setPref('timer.long', '${s.longBreak.inMinutes}');
    await db.setPref('timer.cycle', '${s.sessionsBeforeLongBreak}');
    await db.setPref('timer.auto', '${s.autoStartNext}');
  }
}

/// Injectable wall clock, so tests can jump time (e.g. across a sleep).
final Provider<DateTime Function()> clockProvider = Provider(
  (_) => DateTime.now,
);

final Provider<NotificationsApi> notificationsApiProvider = Provider(
  (_) => NotificationsApi(),
);

final timerProvider = NotifierProvider<TimerController, PomodoroState>(
  TimerController.new,
);

class TimerController extends Notifier<PomodoroState> {
  static const _notificationId = 'phase-end';
  Timer? _ticker;
  bool _askedPermission = false;

  TimerSettings get _settings => ref.read(timerSettingsProvider);
  DateTime get _now => ref.read(clockProvider)();
  NotificationsApi get _notifications => ref.read(notificationsApiProvider);

  @override
  PomodoroState build() {
    ref
      ..onDispose(() => _ticker?.cancel())
      // New lengths apply right away to a phase that hasn't started.
      ..listen(timerSettingsProvider, (_, next) {
        if (!state.running && state.startedAt == null) {
          state = state.reset(next);
        }
      });
    return PomodoroState.initial(_settings);
  }

  void toggle() => state.running ? pause() : start();

  void start() {
    if (!_askedPermission) {
      _askedPermission = true; // asked in context: the first time you start
      unawaited(_quietly(_notifications.requestPermission));
    }
    _set(state.start(_now));
  }

  void pause() => _set(state.pause(_now));

  void reset() => _set(state.reset(_settings));

  void skip() => _set(state.advance(_settings, _now));

  void select(Phase phase) => _set(state.select(phase, _settings));

  /// "Focus on This": link [taskId] and start a focus session.
  void focusOn(String taskId) {
    final focusing = state.phase == Phase.focus;
    _set(
      (focusing ? state : state.select(Phase.focus, _settings)).withTask(
        taskId,
      ),
    );
    if (!state.running) start();
  }

  void clearTask() => state = state.withTask(null);

  /// Applies [next], then keeps the ticker and notification in step with it.
  void _set(PomodoroState next) {
    state = next;
    _ticker?.cancel();
    _ticker = null;
    if (next.running) {
      // Short interval: only repaints when the shown second changes, and
      // catches up within 250 ms after sleep since it compares wall clock.
      _ticker = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _tick(),
      );
      _scheduleNotification(next);
    } else {
      unawaited(_quietly(() => _notifications.cancel(_notificationId)));
    }
  }

  void _tick() {
    final now = _now;
    final next = state.tick(now);
    if (next.remaining == Duration.zero) {
      unawaited(_log(next, now));
      _set(next.advance(_settings, now));
    } else if (next.secondsLeft != state.secondsLeft) {
      state = next;
    }
  }

  Future<void> _log(PomodoroState finished, DateTime now) async {
    final db = ref.read(appDatabaseProvider);
    await db
        .into(db.sessions)
        .insert(
          SessionsCompanion.insert(
            phase: finished.phase.name,
            taskId: Value(finished.taskId),
            startedAt: finished.startedAt ?? now,
            endedAt: now,
          ),
        );
  }

  void _scheduleNotification(PomodoroState s) {
    final (title, body) = switch (s.phase) {
      Phase.focus => (
        'Focus session done',
        s.completedFocus + 1 >= _settings.sessionsBeforeLongBreak
            ? 'Great work. Time for a long break.'
            : 'Time for a short break.',
      ),
      Phase.shortBreak ||
      Phase.longBreak => ('Break’s over', 'Ready for the next focus session?'),
    };
    unawaited(
      _quietly(
        () => _notifications.schedule(
          _notificationId,
          title,
          body,
          s.endsAt!.millisecondsSinceEpoch,
        ),
      ),
    );
  }

  /// Notifications are a nice-to-have: never let them break the timer.
  static Future<void> _quietly(Future<Object?> Function() call) async {
    try {
      await call();
    } on Object {
      // Not allowed, or not available (tests, other platforms).
    }
  }
}

/// Finished focus sessions for a task, live.
// The family type isn't exported publicly, so it can't be spelled out.
// ignore: specify_nonobvious_property_types
final focusCountProvider = StreamProvider.family<int, String>((ref, taskId) {
  final db = ref.watch(appDatabaseProvider);
  final count = db.sessions.id.count();
  final query = db.selectOnly(db.sessions)
    ..addColumns([count])
    ..where(
      db.sessions.taskId.equals(taskId) &
          db.sessions.phase.equals(Phase.focus.name),
    );
  return query.watchSingle().map((row) => row.read(count) ?? 0);
});
