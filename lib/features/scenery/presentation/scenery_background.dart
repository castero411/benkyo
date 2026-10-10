import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/features/scenery/domain/scene.dart';
import 'package:benkyo/features/scenery/presentation/scenery_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// Full-window scene with the user's dim and blur, cross-fading on change.
class SceneryBackground extends ConsumerWidget {
  const SceneryBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(currentSceneProvider);
    final scenery = ref.watch(sceneryProvider).value;
    if (scene == null || scenery == null) {
      return const ColoredBox(color: Tokens.ground);
    }
    final adjust = scenery.adjustFor(scene);

    var view = scene.isVideo
        ? _VideoScene(scene, key: ValueKey(scene.id))
        : _image(scene.path, key: ValueKey(scene.id));
    if (adjust.blur > 0) {
      view = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: adjust.blur,
          sigmaY: adjust.blur,
          tileMode: TileMode.mirror, // no dark halo at the window edges
        ),
        child: view,
      );
    }

    return ColoredBox(
      color: Tokens.ground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: Tokens.motion(context, Tokens.sceneFade),
            // The default layout gives children loose constraints, so images
            // kept their own aspect ratio and left gaps on resize. Fill
            // instead.
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: KeyedSubtree(key: ValueKey(scene.id), child: view),
          ),
          IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: adjust.dim),
            ),
          ),
        ],
      ),
    );
  }
}

/// A built-in asset path or an imported file path, as an image.
ImageProvider sceneImage(String path) =>
    path.startsWith('assets/') ? AssetImage(path) : FileImage(File(path));

/// [path] filling the window.
Widget _image(String path, {Key? key}) {
  return Image(
    key: key,
    image: sceneImage(path),
    width: double.infinity,
    height: double.infinity,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    // A missing file (deleted outside Benkyo) just shows the ground color.
    errorBuilder: (_, _, _) => const SizedBox.expand(),
  );
}

class _VideoScene extends StatefulWidget {
  const _VideoScene(this.scene, {super.key});

  final Scene scene;

  @override
  State<_VideoScene> createState() => _VideoSceneState();
}

class _VideoSceneState extends State<_VideoScene> {
  late final VideoPlayerController _video;
  late final AppLifecycleListener _lifecycle;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final path = widget.scene.path;
    _video = path.startsWith('assets/')
        ? VideoPlayerController.asset(path)
        : VideoPlayerController.file(File(path));
    unawaited(_start());
    // Save battery: no decoding while the window can't be seen.
    _lifecycle = AppLifecycleListener(
      onHide: () => unawaited(_video.pause()),
      onShow: () => unawaited(_video.play()),
    );
  }

  Future<void> _start() async {
    try {
      await _video.initialize();
      await _video.setVolume(0);
      await _video.setLooping(true);
      await _video.play();
      if (mounted) setState(() => _ready = true);
    } on Object {
      // Unplayable file: the poster stays up.
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_video.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poster = widget.scene.posterPath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (poster != null) _image(poster),
        if (_ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _video.value.size.width,
              height: _video.value.size.height,
              child: VideoPlayer(_video),
            ),
          ),
      ],
    );
  }
}
