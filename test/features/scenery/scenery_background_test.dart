import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/features/scenery/presentation/scenery_background.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: images kept their own aspect ratio and left gaps when the
  // window's shape differed from the photo's.
  for (final size in const [
    Size(1000, 1000),
    Size(1800, 600),
    Size(800, 1200),
  ]) {
    testWidgets('scene image fills a ${size.width}×${size.height} window', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: SceneryBackground()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(Image)), size);
      expect(tester.getTopLeft(find.byType(Image)), Offset.zero);
    });
  }
}
