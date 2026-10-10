import 'package:benkyo/features/timer/domain/pomodoro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const s = TimerSettings();
  final t0 = DateTime(2026, 10, 10, 9);

  test('four focus sessions lead to a long break, then a new cycle', () {
    var state = PomodoroState.initial(s);
    final phases = <Phase>[];
    for (var i = 0; i < 8; i++) {
      state = state.advance(s, t0);
      phases.add(state.phase);
    }
    expect(phases, [
      Phase.shortBreak, Phase.focus, //
      Phase.shortBreak, Phase.focus,
      Phase.shortBreak, Phase.focus,
      Phase.longBreak, Phase.focus,
    ]);
    expect(state.completedFocus, 0);
    expect(state.remaining, s.focus);
    expect(state.running, isFalse);
  });

  test('pause keeps the time left; resuming continues from it', () {
    var state = PomodoroState.initial(s).start(t0);
    state = state.pause(t0.add(const Duration(minutes: 10)));
    expect(state.running, isFalse);
    expect(state.secondsLeft, 15 * 60);

    // An hour away while paused changes nothing.
    final back = t0.add(const Duration(hours: 1));
    state = state.start(back).tick(back.add(const Duration(minutes: 5)));
    expect(state.secondsLeft, 10 * 60);
    expect(state.startedAt, t0); // pauses don't move the session start
  });

  test('a jump past the end (sleep) clamps to zero', () {
    final state = PomodoroState.initial(s)
        .start(t0)
        .tick(t0.add(const Duration(hours: 3)));
    expect(state.remaining, Duration.zero);
    expect(state.secondsLeft, 0);
  });

  test('display rounds up and formats', () {
    final state = PomodoroState.initial(s)
        .start(t0)
        .tick(t0.add(const Duration(milliseconds: 1)));
    expect(formatClock(state.secondsLeft), '25:00');
    expect(formatClock(59), '00:59');
  });

  test('auto-start begins the next phase immediately', () {
    const auto = TimerSettings(autoStartNext: true);
    final next = PomodoroState.initial(auto).advance(auto, t0);
    expect(next.phase, Phase.shortBreak);
    expect(next.endsAt, t0.add(auto.shortBreak));
  });
}
