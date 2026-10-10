import 'package:benkyo/app/app.dart';
import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/core/native/window.dart';
import 'package:benkyo/features/calendar/presentation/calendar_providers.dart';
import 'package:benkyo/features/music/domain/spotify_link.dart';
import 'package:benkyo/features/music/presentation/music_controller.dart';
import 'package:benkyo/features/scenery/domain/scene.dart';
import 'package:benkyo/features/scenery/presentation/scenery_providers.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reminders access not asked yet → tasks live in the local database.
class _NoRemindersYet extends RemindersApi {
  @override
  Future<AccessStatus> status() async => AccessStatus.notDetermined;
}

/// Fake wall clock; tests move it to simulate time passing or sleep.
var _now = DateTime(2026, 10, 10, 9);

/// Records commands; [state] is what Spotify reports.
class _FakeSpotify extends SpotifyApi {
  _FakeSpotify(this.state_);

  SpotifyState state_;
  final calls = <String>[];

  @override
  Future<SpotifyState> state() async => state_;
  @override
  Future<void> playPause() async => calls.add('playPause');
  @override
  Future<bool> launch() async {
    calls.add('launch');
    state_ = SpotifyState(
      installed: true,
      running: true,
      playing: false,
      access: SpotifyAccess.granted,
    );
    return true;
  }

  @override
  Future<void> play(String uri) async => calls.add('play $uri');
}

/// Calendar access granted, with [events]; records what Benkyo writes.
class _FakeCalendar extends CalendarApi {
  _FakeCalendar(this.events_);

  final List<CalendarEventDto> events_;
  final created = <String>[];
  final deleted = <String>[];

  @override
  Future<AccessStatus> status() async => AccessStatus.granted;
  @override
  Future<List<CalendarEventDto>> events(int from, int to) async => events_;
  @override
  Future<String> createEvent(
    String title,
    int start,
    int end,
    String? taskId,
  ) async {
    created.add('$title ${(end - start) ~/ 60000}min task:$taskId');
    return 'event-1';
  }

  @override
  Future<void> deleteEvent(String id) async => deleted.add(id);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  SpotifyApi? spotify,
  CalendarApi? calendar,
  bool firstLaunch = false,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  if (!firstLaunch) await db.setPref('onboarding.done', 'true');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        remindersApiProvider.overrideWithValue(_NoRemindersYet()),
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => _now),
        if (spotify != null) spotifyApiProvider.overrideWithValue(spotify),
        if (calendar != null) calendarApiProvider.overrideWithValue(calendar),
      ],
      child: const BenkyoApp(),
    ),
  );
  addTearDown(db.close);
}

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('edge tab opens Tasks, Esc closes, F toggles full screen', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      (call) async => calls.add(call.method),
    );
    await _pumpApp(tester);

    double tasksLeft() => tester.getTopLeft(find.text('Tasks')).dx;

    expect(tasksLeft(), lessThan(0)); // off-screen
    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.pumpAndSettle();
    expect(tasksLeft(), greaterThan(0));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tasksLeft(), lessThan(0));

    // Zen mode is plain native full screen; nothing in the UI hides.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.tap(find.byTooltip('Zen mode: full screen (F)'));
    await tester.pumpAndSettle();
    expect(calls, ['toggleFullScreen', 'toggleFullScreen']);
    expect(find.byTooltip('Scenery (⌘E)'), findsOneWidget);
  }, variant: macOS);

  testWidgets('quick-add saves a prioritized task; F types while focused', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Sync with Apple Reminders'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Fix login !1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Fix login'), findsOneWidget);
    expect(find.text('P1 · URGENT'), findsOneWidget);

    // Typing "f" in the field must not toggle zen.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.text('Fix login'), findsOneWidget);
  }, variant: macOS);

  testWidgets('right-click opens the native menu; choosing P1 regroups', (
    tester,
  ) async {
    List<Object?>? shown;
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.benkyo.MenuApi.show',
      (data) async {
        shown =
            (MenuApi.pigeonChannelCodec.decodeMessage(data)! as List)[0]
                as List<Object?>;
        return MenuApi.pigeonChannelCodec.encodeMessage(['p1']);
      },
    );
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ship it');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('P4 · LATER'), findsOneWidget);

    await tester.tap(find.text('Ship it'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    final titles = shown!.cast<NativeMenuItem>().map((i) => i.title);
    expect(titles, [
      'Focus on This Task',
      null,
      'Mark as Completed',
      null,
      'Priority',
      'Schedule…',
      'Due Date',
      null,
      'Add Note…',
      'Rename',
      null,
      'Delete',
    ]);
    expect(find.text('P1 · URGENT'), findsOneWidget);
    expect(find.text('P4 · LATER'), findsNothing);
  }, variant: macOS);

  testWidgets('focus on a task, sleep through the end, session is logged', (
    tester,
  ) async {
    final scheduled = <Object?>[];
    tester.binding.defaultBinaryMessenger
      ..setMockMessageHandler('dev.flutter.pigeon.benkyo.MenuApi.show', (
        _,
      ) async {
        return MenuApi.pigeonChannelCodec.encodeMessage(['focus']);
      })
      ..setMockMessageHandler(
        'dev.flutter.pigeon.benkyo.NotificationsApi.schedule',
        (data) async {
          scheduled.add(
            NotificationsApi.pigeonChannelCodec.decodeMessage(data),
          );
          return NotificationsApi.pigeonChannelCodec.encodeMessage([null]);
        },
      );
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write docs !1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Native menu → "Focus on This Task" starts a linked focus session.
    await tester.tap(find.text('Write docs'), buttons: kSecondaryButton);
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(scheduled, hasLength(1)); // phase-end notification booked

    // The Mac sleeps past the end; the next tick catches up.
    _now = _now.add(const Duration(minutes: 26));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('05:00'), findsOneWidget); // short break, stopped
    expect(find.text('Start'), findsOneWidget);
    expect(find.textContaining('1 session'), findsOneWidget); // logged
  }, variant: macOS);

  testWidgets('pick a scene in the sheet; it rotates with the timer', (
    tester,
  ) async {
    await _pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BenkyoApp)),
    );
    String? currentId() => container.read(currentSceneProvider)?.id;
    await tester.pumpAndSettle();
    expect(currentId(), builtInScenes.first.id);

    await tester.tap(find.byTooltip('Scenery (⌘E)'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Golden hour'));
    await tester.pumpAndSettle();
    expect(currentId(), 'builtin:golden-hour');

    await tester.tap(find.text('Change scene each phase'));
    // The same button (and ⌘E) closes it instead of stacking another.
    await tester.tap(find.byTooltip('Scenery (⌘E)'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Scenery'), findsNothing);
    await tester.tap(find.byTooltip('Scenery (⌘E)'));
    await tester.pumpAndSettle();
    expect(find.text('Scenery'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // Esc also closes
    await tester.pumpAndSettle();
    expect(find.text('Scenery'), findsNothing);

    await tester.tap(find.byTooltip('Skip to next phase (⌘→)'));
    await tester.pumpAndSettle();
    expect(currentId(), nextSceneId(builtInScenes, 'builtin:golden-hour'));

    // Choices survive a restart: they're in the database.
    final db = container.read(appDatabaseProvider);
    expect(await db.prefsWithPrefix('scene.'), {
      'scene.current': nextSceneId(builtInScenes, 'builtin:golden-hour'),
      'scene.rotate': 'true',
    });
  }, variant: macOS);

  testWidgets('Spotify closed: a preset opens it, then plays', (tester) async {
    final spotify = _FakeSpotify(
      SpotifyState(
        installed: true,
        running: false,
        playing: false,
        access: SpotifyAccess.notAsked,
      ),
    );
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.benkyo.MenuApi.show',
      (_) async => MenuApi.pigeonChannelCodec.encodeMessage([presets[0].uri]),
    );
    await _pumpApp(tester, spotify: spotify);
    await tester.pumpAndSettle();
    expect(find.text('Open Spotify'), findsOneWidget);

    await tester.tap(find.byTooltip('Choose playlist'));
    await tester.pumpAndSettle();
    expect(spotify.calls, ['launch', 'play ${presets[0].uri}']);
  }, variant: macOS);

  testWidgets('now playing shows the track; pause goes to Spotify', (
    tester,
  ) async {
    final spotify = _FakeSpotify(
      SpotifyState(
        installed: true,
        running: true,
        playing: true,
        access: SpotifyAccess.granted,
        title: 'Snowfall',
        artist: 'Øneheart',
        durationMs: 171000,
        positionMs: 72000,
      ),
    );
    await _pumpApp(tester, spotify: spotify);
    await tester.pump();
    expect(find.text('Snowfall'), findsOneWidget);
    expect(find.text('1:12'), findsOneWidget);
    expect(find.text('2:51'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause music'));
    await tester.pump();
    expect(spotify.calls, ['playPause']);
  }, variant: macOS);

  testWidgets('control denied: explains and links to Settings', (tester) async {
    await _pumpApp(
      tester,
      spotify: _FakeSpotify(
        SpotifyState(
          installed: true,
          running: true,
          playing: false,
          access: SpotifyAccess.denied,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Benkyo can’t control Spotify'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  }, variant: macOS);

  testWidgets('Today panel lists events; a scheduled task starts focus', (
    tester,
  ) async {
    final now = DateTime.now();
    int ms(int minutes) =>
        now.add(Duration(minutes: minutes)).millisecondsSinceEpoch;
    final calendar = _FakeCalendar([
      CalendarEventDto(
        id: 'a',
        title: 'Standup',
        startMillis: ms(-1),
        endMillis: ms(1),
        allDay: false,
        calendarTitle: 'Work',
        colorHex: '#7FB5FF',
      ),
      CalendarEventDto(
        id: 'b',
        title: 'Write docs',
        startMillis: ms(2),
        endMillis: ms(27),
        allDay: false,
        calendarTitle: 'Work',
        colorHex: '#7FB5FF',
        taskId: '7',
      ),
    ]);
    await _pumpApp(tester, calendar: calendar);
    await tester.tap(find.bySemanticsLabel('Open today'));
    await tester.pumpAndSettle();

    expect(find.text('Standup'), findsOneWidget);
    expect(find.text('Work · 2 min'), findsOneWidget);
    expect(find.text('Scheduled task · 25 min'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Now, ')), findsOneWidget);

    await tester.tap(find.text('Write docs'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget); // focus session started
    await tester.tap(find.text('Pause')); // stop the ticker
    await tester.pump();
  }, variant: macOS);

  testWidgets('Schedule… adds a calendar block and sets the due time', (
    tester,
  ) async {
    final calendar = _FakeCalendar([]);
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.benkyo.MenuApi.show',
      (_) async => MenuApi.pigeonChannelCodec.encodeMessage(['schedule']),
    );
    await _pumpApp(tester, calendar: calendar);
    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write docs !1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Write docs'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Schedule “Write docs”'), findsOneWidget);
    await tester.tap(find.text('Add to Calendar')); // first free slot, 25 min
    await tester.pumpAndSettle();

    expect(calendar.created, ['Write docs 25min task:1']);
    expect(find.textContaining('Scheduled “Write docs”'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(calendar.deleted, ['event-1']);
  }, variant: macOS);

  testWidgets('write a note: title from first line, saved, searchable', (
    tester,
  ) async {
    await _pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BenkyoApp)),
    );
    await tester.tap(find.byTooltip('Notes (⌘J)'));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet.'), findsOneWidget);

    await tester.tap(find.text('New Note'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '# Sprint plan\n\n- ship the docs',
    );
    await tester.pump(const Duration(milliseconds: 500)); // autosave
    await tester.pumpAndSettle();

    expect(find.text('Sprint plan'), findsWidgets); // list + preview
    final db = container.read(appDatabaseProvider);
    final saved = await db.select(db.notes).get();
    expect(saved.single.body, '# Sprint plan\n\n- ship the docs');

    await tester.enterText(find.widgetWithText(TextField, 'Search'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No notes match.'), findsOneWidget);

    // ⌘J / the button closes it again.
    await tester.tap(find.byTooltip('Notes (⌘J)'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsNothing);
  }, variant: macOS);

  testWidgets('Add Note… on a task creates a linked note', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.benkyo.MenuApi.show',
      (_) async => MenuApi.pigeonChannelCodec.encodeMessage(['note']),
    );
    await _pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Write docs !1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Write docs'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Task · Write docs'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape); // close sheet
    await tester.pumpAndSettle();
    expect(find.text('Note'), findsOneWidget); // indicator on the task row
  }, variant: macOS);

  testWidgets('first launch: tour picks a scene and adds the first task', (
    tester,
  ) async {
    await _pumpApp(tester, firstLaunch: true);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BenkyoApp)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pick your scene'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Golden hour').last);
    await tester.pumpAndSettle();
    expect(container.read(currentSceneProvider)?.id, 'builtin:golden-hour');

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your music'), findsOneWidget);
    await tester.tap(find.text('Continue')); // music is optional
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'First task'),
      'Read paper !2',
    );
    await tester.tap(find.text('Start Focusing'));
    await tester.pumpAndSettle();
    expect(find.text('Pick your scene'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Read paper'), findsOneWidget);
    expect(find.text('P2 · HIGH'), findsOneWidget);
    final db = container.read(appDatabaseProvider);
    expect(
      (await db.prefsWithPrefix('onboarding.'))['onboarding.done'],
      'true',
    );
  }, variant: macOS);

  testWidgets('Settings: a longer focus applies to the idle timer', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Settings (⌘,)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More Focus'));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);

    await tester.tap(find.byTooltip('Close (Esc)').last);
    await tester.pumpAndSettle();
    expect(find.text('30:00'), findsOneWidget);
  }, variant: macOS);
}
