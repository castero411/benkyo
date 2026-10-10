import 'package:flutter/foundation.dart';

enum Phase { focus, shortBreak, longBreak }

@immutable
class TimerSettings {
  const TimerSettings({
    this.focus = const Duration(minutes: 25),
    this.shortBreak = const Duration(minutes: 5),
    this.longBreak = const Duration(minutes: 15),
    this.sessionsBeforeLongBreak = 4,
    this.autoStartNext = false,
  });

  final Duration focus;
  final Duration shortBreak;
  final Duration longBreak;
  final int sessionsBeforeLongBreak;
  final bool autoStartNext;

  Duration of(Phase phase) => switch (phase) {
    Phase.focus => focus,
    Phase.shortBreak => shortBreak,
    Phase.longBreak => longBreak,
  };
}

/// Timer state. While running, [endsAt] (wall clock) is the truth, so the
/// timer stays correct across sleep and App Nap; [remaining] is the last
/// computed value and the truth while paused.
@immutable
class PomodoroState {
  const PomodoroState({
    required this.phase,
    required this.remaining,
    this.endsAt,
    this.startedAt,
    this.completedFocus = 0,
    this.taskId,
  });

  PomodoroState.initial(TimerSettings s)
    : this(phase: Phase.focus, remaining: s.focus);

  final Phase phase;
  final Duration remaining;
  final DateTime? endsAt;

  /// First start of this phase (pauses don't reset it). Null if never started.
  final DateTime? startedAt;

  /// Focus sessions finished in the current cycle (0 … sessionsBeforeLong-1).
  final int completedFocus;
  final String? taskId;

  bool get running => endsAt != null;

  /// Whole seconds left, rounded up: shows 25:00 at start, 0:00 at the end.
  int get secondsLeft => (remaining.inMilliseconds / 1000).ceil();

  PomodoroState _copy({
    Phase? phase,
    Duration? remaining,
    DateTime? Function()? endsAt,
    DateTime? Function()? startedAt,
    int? completedFocus,
    String? Function()? taskId,
  }) => PomodoroState(
    phase: phase ?? this.phase,
    remaining: remaining ?? this.remaining,
    endsAt: endsAt == null ? this.endsAt : endsAt(),
    startedAt: startedAt == null ? this.startedAt : startedAt(),
    completedFocus: completedFocus ?? this.completedFocus,
    taskId: taskId == null ? this.taskId : taskId(),
  );

  PomodoroState start(DateTime now) => running
      ? this
      : _copy(
          endsAt: () => now.add(remaining),
          startedAt: () => startedAt ?? now,
        );

  PomodoroState pause(DateTime now) =>
      running ? tick(now)._copy(endsAt: () => null) : this;

  PomodoroState tick(DateTime now) {
    if (!running) return this;
    final left = endsAt!.difference(now);
    return _copy(remaining: left.isNegative ? Duration.zero : left);
  }

  /// Stops and refills the current phase.
  PomodoroState reset(TimerSettings s) =>
      _copy(remaining: s.of(phase), endsAt: () => null, startedAt: () => null);

  /// Switches to [next], stopped and full.
  PomodoroState select(Phase next, TimerSettings s) => _copy(
    phase: next,
    remaining: s.of(next),
    endsAt: () => null,
    startedAt: () => null,
  );

  /// Moves to the phase after this one (on completion or skip). Starts it
  /// right away when [TimerSettings.autoStartNext] is on.
  PomodoroState advance(TimerSettings s, DateTime now) {
    final PomodoroState next;
    if (phase == Phase.focus) {
      final done = completedFocus + 1;
      final long = done >= s.sessionsBeforeLongBreak;
      next = select(
        long ? Phase.longBreak : Phase.shortBreak,
        s,
      )._copy(completedFocus: long ? 0 : done);
    } else {
      next = select(Phase.focus, s);
    }
    return s.autoStartNext ? next.start(now) : next;
  }

  PomodoroState withTask(String? id) => _copy(taskId: () => id);
}

/// "24:13"
String formatClock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
