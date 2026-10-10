import 'package:benkyo/app/app.dart';
import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoRemindersYet extends RemindersApi {
  @override
  Future<AccessStatus> status() async => AccessStatus.notDetermined;
}

/// Every tappable thing has a label VoiceOver can read, and text meets
/// WCAG contrast, on the main screen and in each sheet.
void main() {
  final macOS = TargetPlatformVariant.only(TargetPlatform.macOS);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);
    await db.setPref('onboarding.done', 'true');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          remindersApiProvider.overrideWithValue(_NoRemindersYet()),
        ],
        child: const BenkyoApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> audit(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('Focus screen with both panels', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await audit(tester);
    await tester.tap(find.bySemanticsLabel('Open tasks'));
    await tester.tap(find.bySemanticsLabel('Open today'));
    await tester.pumpAndSettle();
    await audit(tester);
    handle.dispose();
  }, variant: macOS);

  for (final sheet in ['Scenery (⌘E)', 'Notes (⌘J)', 'Settings (⌘,)']) {
    testWidgets('$sheet sheet', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(find.byTooltip(sheet));
      await tester.pumpAndSettle();
      await audit(tester);
      handle.dispose();
    }, variant: macOS);
  }
}
