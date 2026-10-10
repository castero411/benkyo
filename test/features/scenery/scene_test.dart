import 'dart:io';

import 'package:benkyo/features/scenery/domain/scene.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every built-in scene ships its files and a credit', () {
    final ids = <String>{};
    final attribution = File('assets/scenery/ATTRIBUTION.md')
        .readAsStringSync();
    for (final s in builtInScenes) {
      expect(ids.add(s.id), isTrue, reason: 'duplicate id ${s.id}');
      expect(File(s.path).existsSync(), isTrue, reason: s.path);
      if (s.isVideo) expect(File(s.posterPath!).existsSync(), isTrue);
      expect(s.credit, isNotNull);
      expect(attribution, contains(s.path.split('/').last));
    }
  });

  test('import kind by extension', () {
    expect(importKind('/a/b.JPG'), ImportKind.image);
    expect(importKind('/a/IMG_0001.HEIC'), ImportKind.convertToJpeg);
    expect(importKind('/a/clip.mov'), ImportKind.video);
    expect(importKind('/a/notes.pdf'), isNull);
  });

  test('next scene wraps around', () {
    final last = builtInScenes.last.id;
    expect(nextSceneId(builtInScenes, last), builtInScenes.first.id);
    expect(
      nextSceneId(builtInScenes, builtInScenes.first.id),
      builtInScenes[1].id,
    );
  });
}
