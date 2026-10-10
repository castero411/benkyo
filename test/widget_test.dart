import 'package:benkyo/app/app.dart';
import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/focus/presentation/focus_ui.dart';
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

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        remindersApiProvider.overrideWithValue(_NoRemindersYet()),
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: const BenkyoApp(),
    ),
  );
  addTearDown(db.close);
}

void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  testWidgets('edge tab opens Tasks, Esc closes, F toggles zen + full screen', (
    tester,
  ) async {
    final fullScreen = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      (call) async => fullScreen.add(call.arguments),
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

    double zenOpacity() => tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byTooltip('Zen mode (F)'),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;

    expect(zenOpacity(), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(zenOpacity(), 0);
    expect(fullScreen, [true]);

    // Leaving full screen natively also leaves zen.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      windowChannel.name,
      windowChannel.codec.encodeMethodCall(
        const MethodCall('didExitFullScreen'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(zenOpacity(), 1);
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
      'Due Date',
      null,
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
}
