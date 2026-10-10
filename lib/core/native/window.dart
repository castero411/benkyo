import 'package:flutter/services.dart';

/// Native window helpers, see macos/Runner/MainFlutterWindow.swift.
const windowChannel = MethodChannel('benkyo/window');

/// Zen mode: native macOS full screen, same as View → Enter Full Screen.
Future<void> toggleFullScreen() =>
    windowChannel.invokeMethod<void>('toggleFullScreen');

/// Opens a web or mail link in the default app. Other schemes are ignored.
Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
    return;
  }
  await windowChannel.invokeMethod<void>('openUrl', url);
}
