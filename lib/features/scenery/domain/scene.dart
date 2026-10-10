import 'package:flutter/foundation.dart';

/// A background: a photo or a looping video, built in or imported.
@immutable
class Scene {
  const Scene({
    required this.id,
    required this.name,
    required this.path,
    this.isVideo = false,
    this.posterPath,
    this.credit,
    this.defaultDim = 0.25,
  });

  final String id;
  final String name;

  /// Asset key when built in, absolute file path when imported.
  final String path;
  final bool isVideo;

  /// Still frame shown while a video loads, and as its thumbnail.
  final String? posterPath;

  /// Shown in Settings → credits. Null for the user's own scenes.
  final Credit? credit;

  /// Starting dim; bright scenes get more so text stays readable.
  final double defaultDim;

  bool get isBuiltIn => credit != null;

  /// What thumbnails should draw.
  String get thumbnailPath => posterPath ?? path;
}

@immutable
class Credit {
  const Credit(this.author, this.source, this.url, this.license);

  final String author;
  final String source;
  final String url;
  final String license;
}

const _unsplash = 'Unsplash License';
const _mixkit = 'Mixkit Stock Video Free License';

/// Built-in scenes. Keep assets/scenery/ATTRIBUTION.md in sync.
const builtInScenes = [
  Scene(
    id: 'builtin:night-desk',
    name: 'Night desk',
    path: 'assets/scenery/night-desk.jpg',
    credit: Credit(
      'Zoshua Colah',
      'Unsplash',
      'https://unsplash.com/photos/IUKdnYUlDco',
      _unsplash,
    ),
    defaultDim: 0.15,
  ),
  Scene(
    id: 'builtin:rainy-window',
    name: 'Rainy window',
    path: 'assets/scenery/rainy-window.mov',
    posterPath: 'assets/scenery/rainy-window.jpg',
    isVideo: true,
    credit: Credit(
      'Mixkit',
      'Mixkit',
      'https://mixkit.co/free-stock-video/window-on-a-rainy-day-2846/',
      _mixkit,
    ),
    defaultDim: 0.35,
  ),
  Scene(
    id: 'builtin:golden-hour',
    name: 'Golden hour',
    path: 'assets/scenery/golden-hour.jpg',
    credit: Credit(
      'Ashe Walker',
      'Unsplash',
      'https://unsplash.com/photos/F4XigKgMwIw',
      _unsplash,
    ),
    defaultDim: 0.4,
  ),
  Scene(
    id: 'builtin:rainy-neon',
    name: 'Rainy neon',
    path: 'assets/scenery/rainy-neon.jpg',
    credit: Credit(
      'Lesha Tuman',
      'Unsplash',
      'https://unsplash.com/photos/H8R6aIW_OdE',
      _unsplash,
    ),
  ),
  Scene(
    id: 'builtin:roof-rain',
    name: 'Rain on the roof',
    path: 'assets/scenery/roof-rain.mov',
    posterPath: 'assets/scenery/roof-rain.jpg',
    isVideo: true,
    credit: Credit(
      'Mixkit',
      'Mixkit',
      'https://mixkit.co/free-stock-video/rain-falling-from-the-roof-on-a-rainy-day-2716/',
      _mixkit,
    ),
  ),
  Scene(
    id: 'builtin:cozy-room',
    name: 'Cozy room',
    path: 'assets/scenery/cozy-room.jpg',
    credit: Credit(
      'Poojan Thanekar',
      'Unsplash',
      'https://unsplash.com/photos/rS0d3l1YRgI',
      _unsplash,
    ),
    defaultDim: 0.35,
  ),
  Scene(
    id: 'builtin:city-lights',
    name: 'City lights',
    path: 'assets/scenery/city-lights.jpg',
    credit: Credit(
      'Kouji Tsuru',
      'Unsplash',
      'https://unsplash.com/photos/ItbUUTYhfXw',
      _unsplash,
    ),
  ),
  Scene(
    id: 'builtin:rain-bokeh',
    name: 'Rain bokeh',
    path: 'assets/scenery/rain-bokeh.jpg',
    credit: Credit(
      'Jahanzeb Ahsan',
      'Unsplash',
      'https://unsplash.com/photos/PQyC6hrKPS4',
      _unsplash,
    ),
    defaultDim: 0.3,
  ),
];

enum ImportKind { image, convertToJpeg, video }

/// How an imported file is handled, by extension. Null = not supported.
ImportKind? importKind(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' || 'png' || 'webp' => ImportKind.image,
    'heic' || 'heif' || 'tif' || 'tiff' => ImportKind.convertToJpeg,
    'mp4' || 'mov' || 'm4v' => ImportKind.video,
    _ => null,
  };
}

/// The scene after [currentId] in [scenes], wrapping around.
String nextSceneId(List<Scene> scenes, String currentId) {
  final i = scenes.indexWhere((s) => s.id == currentId);
  return scenes[(i + 1) % scenes.length].id;
}
