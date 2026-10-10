import 'dart:async';
import 'dart:io';

import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/features/scenery/domain/scene.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final Provider<SceneryApi> sceneryApiProvider = Provider((_) => SceneryApi());

/// Built-in scenes first, then the user's, oldest first.
final StreamProvider<List<Scene>> scenesProvider = StreamProvider((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.userScenes)
    ..orderBy([(s) => OrderingTerm.asc(s.addedAt)]);
  return query.watch().map(
    (rows) => [
      ...builtInScenes,
      for (final r in rows)
        Scene(
          id: r.id,
          name: r.name,
          path: r.path,
          isVideo: r.isVideo,
          posterPath: r.isVideo ? '${r.path}.jpg' : null,
        ),
    ],
  );
});

typedef Adjust = ({double dim, double blur});

@immutable
class SceneryState {
  const SceneryState({
    required this.currentId,
    required this.rotate,
    required this.adjust,
  });

  final String currentId;

  /// Move to the next scene whenever the timer changes phase.
  final bool rotate;
  final Map<String, Adjust> adjust;

  Adjust adjustFor(Scene s) => adjust[s.id] ?? (dim: s.defaultDim, blur: 0);

  SceneryState copyWith({
    String? currentId,
    bool? rotate,
    Map<String, Adjust>? adjust,
  }) => SceneryState(
    currentId: currentId ?? this.currentId,
    rotate: rotate ?? this.rotate,
    adjust: adjust ?? this.adjust,
  );
}

final sceneryProvider = AsyncNotifierProvider<SceneryController, SceneryState>(
  SceneryController.new,
);

/// The scene on screen; falls back to the first built-in if it was removed.
final Provider<Scene?> currentSceneProvider = Provider((ref) {
  final id = ref.watch(sceneryProvider).value?.currentId;
  if (id == null) return null;
  final scenes = ref.watch(scenesProvider).value ?? builtInScenes;
  return scenes.where((s) => s.id == id).firstOrNull ?? builtInScenes.first;
});

class SceneryController extends AsyncNotifier<SceneryState> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<SceneryState> build() async {
    ref.listen(timerProvider.select((s) => s.phase), (prev, next) {
      if (prev != next && (state.value?.rotate ?? false)) {
        final scenes = ref.read(scenesProvider).value ?? builtInScenes;
        unawaited(select(nextSceneId(scenes, state.value!.currentId)));
      }
    });

    final prefs = await _db.prefsWithPrefix('scene.');
    final adjust = <String, Adjust>{};
    for (final MapEntry(:key, :value) in prefs.entries) {
      if (!key.startsWith('scene.adjust.')) continue;
      final [dim, blur] = value.split(',').map(double.parse).toList();
      adjust[key.substring('scene.adjust.'.length)] = (dim: dim, blur: blur);
    }
    return SceneryState(
      currentId: prefs['scene.current'] ?? builtInScenes.first.id,
      rotate: prefs['scene.rotate'] == 'true',
      adjust: adjust,
    );
  }

  Future<void> select(String id) async {
    state = AsyncData(state.requireValue.copyWith(currentId: id));
    await _db.setPref('scene.current', id);
  }

  Future<void> setRotate({required bool on}) async {
    state = AsyncData(state.requireValue.copyWith(rotate: on));
    await _db.setPref('scene.rotate', '$on');
  }

  /// Live while dragging; pass [save] on release to persist.
  Future<void> setAdjust(String id, Adjust value, {bool save = false}) async {
    final s = state.requireValue;
    state = AsyncData(s.copyWith(adjust: {...s.adjust, id: value}));
    if (save) {
      await _db.setPref('scene.adjust.$id', '${value.dim},${value.blur}');
    }
  }

  /// Copies [paths] into the app (so they keep working if the originals
  /// move) and shows the last one. Unsupported files are skipped; one
  /// unreadable file doesn't stop the rest.
  Future<({int added, int failed})> import(List<String> paths) async {
    final api = ref.read(sceneryApiProvider);
    final dir = Directory(
      '${(await getApplicationSupportDirectory()).path}/scenes',
    );
    await dir.create(recursive: true);

    String? lastId;
    var added = 0;
    var failed = 0;
    for (final src in paths) {
      final kind = importKind(src);
      if (kind == null) continue;
      final id = 'user-${DateTime.now().microsecondsSinceEpoch}';
      final ext = kind == ImportKind.convertToJpeg
          ? 'jpg'
          : src.split('.').last.toLowerCase();
      final dest = '${dir.path}/$id.$ext';
      try {
        switch (kind) {
          case ImportKind.image:
            await File(src).copy(dest);
          case ImportKind.convertToJpeg:
            await api.convertToJpeg(src, dest);
          case ImportKind.video:
            await File(src).copy(dest);
            await api.videoPoster(dest, '$dest.jpg');
        }
      } on Object {
        failed++;
        for (final f in [File(dest), File('$dest.jpg')]) {
          if (f.existsSync()) await f.delete();
        }
        continue;
      }
      final name = src.split('/').last;
      await _db
          .into(_db.userScenes)
          .insert(
            UserScenesCompanion.insert(
              id: id,
              name: name.substring(0, name.lastIndexOf('.')),
              path: dest,
              isVideo: kind == ImportKind.video,
              addedAt: DateTime.now(),
            ),
          );
      lastId = id;
      added++;
    }
    if (lastId != null) await select(lastId);
    return (added: added, failed: failed);
  }

  /// Removes [scene] from the list but keeps its files until [purge], so
  /// [restore] can undo it.
  Future<UserScene> remove(Scene scene) async {
    final row = await (_db.select(
      _db.userScenes,
    )..where((s) => s.id.equals(scene.id))).getSingle();
    await (_db.delete(
      _db.userScenes,
    )..where((s) => s.id.equals(scene.id))).go();
    if (state.requireValue.currentId == scene.id) {
      await select(builtInScenes.first.id);
    }
    return row;
  }

  Future<void> restore(UserScene row) => _db.into(_db.userScenes).insert(row);

  Future<void> purge(UserScene row) async {
    for (final path in [row.path, '${row.path}.jpg']) {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    }
  }
}
