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

  group('catchUp (app was killed while running)', () {
    test('not ended yet: unchanged, nothing finished', () {
      final state = PomodoroState.initial(s).start(t0);
      final (next, done) = catchUp(
        state,
        s,
        t0.add(const Duration(minutes: 1)),
      );
      expect(next.endsAt, state.endsAt);
      expect(done, isEmpty);
    });

    test('one phase ended: logged at its end, next phase stopped', () {
      final state = PomodoroState.initial(s).start(t0).withTask('7');
      final (next, done) = catchUp(state, s, t0.add(const Duration(hours: 2)));
      expect(done, hasLength(1));
      expect(done.single.phase, Phase.focus);
      expect(done.single.taskId, '7');
      expect(done.single.start, t0);
      expect(done.single.end, t0.add(s.focus));
      expect(next.phase, Phase.shortBreak);
      expect(next.running, isFalse);
      expect(next.completedFocus, 1);
    });

    test('auto-start: every phase that fit in the gap is logged', () {
      const auto = TimerSettings(autoStartNext: true);
      final state = PomodoroState.initial(auto).start(t0);
      // 25 focus + 5 break + 25 focus = 55 min, then 3 min into a break.
      final now = t0.add(const Duration(minutes: 58));
      final (next, done) = catchUp(state, auto, now);
      expect(done.map((d) => d.phase), [
        Phase.focus,
        Phase.shortBreak,
        Phase.focus,
      ]);
      expect(done[1].start, t0.add(auto.focus));
      expect(next.phase, Phase.shortBreak);
      expect(next.running, isTrue);
      expect(next.tick(now).secondsLeft, 2 * 60);
    });

    test('paused: never catches up', () {
      final state = PomodoroState.initial(s).start(t0).pause(t0);
      final (_, done) = catchUp(state, s, t0.add(const Duration(days: 1)));
      expect(done, isEmpty);
    });
  });
}
