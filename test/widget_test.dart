import 'package:benkyo/app/app.dart';
import 'package:benkyo/features/focus/presentation/focus_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edge tab opens Tasks, Esc closes, F toggles zen + full screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fullScreen = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      windowChannel,
      (call) async => fullScreen.add(call.arguments),
    );

    await tester.pumpWidget(const ProviderScope(child: BenkyoApp()));

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
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
