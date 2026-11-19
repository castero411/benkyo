import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/timer/domain/pomodoro.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records scheduled notifications instead of talking to the platform.
class _FakeNotifications extends NotificationsApi {
  final scheduled = <String, int>{};

  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> schedule(String id, String t, String b, int at) async =>
      scheduled[id] = at;
  @override
  Future<void> cancel(String id) async => scheduled.remove(id);
}

void main() {
  final t0 = DateTime(2026, 10, 10, 9);

  test('state survives a JSON round trip', () {
    final state = PomodoroState.initial(const TimerSettings())
        .start(t0)
        .withTask('3');
    final back = PomodoroState.fromJson(state.toJson());
    expect(back.phase, state.phase);
    expect(back.remaining, state.remaining);
    expect(back.endsAt, state.endsAt);
    expect(back.startedAt, state.startedAt);
    expect(back.completedFocus, state.completedFocus);
    expect(back.taskId, '3');
  });

  test('a running timer is restored after the app is killed', () async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    var now = t0;
    final notifications = _FakeNotifications();
    ProviderContainer app() {
      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          notificationsApiProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    // First run: start focus, then the process dies.
    final first = app();
    first.read(timerProvider.notifier).start();
    await pumpEventQueue();
    first.dispose();

    // Ten minutes later: still running, with the time that's really left.
    now = t0.add(const Duration(minutes: 10));
    final second = app()..read(timerProvider);
    await pumpEventQueue();
    expect(second.read(timerProvider).running, isTrue);
    expect(second.read(timerProvider).secondsLeft, 15 * 60);
    second.dispose();

    // An hour later: the focus ended while dead → logged, now on a break.
    now = t0.add(const Duration(hours: 1));
    final third = app()..read(timerProvider);
    await pumpEventQueue();
    expect(third.read(timerProvider).phase, Phase.shortBreak);
    final sessions = await db.select(db.sessions).get();
    expect(sessions.single.phase, 'focus');
    expect(sessions.single.endedAt, t0.add(const Duration(minutes: 25)));
  });
}
