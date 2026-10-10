import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef FocusUiState = ({bool tasksOpen, bool todayOpen, bool zen});

/// Native window control, see macos/Runner/MainFlutterWindow.swift.
const windowChannel = MethodChannel('benkyo/window');

/// Which overlays are visible on the Focus screen.
/// Zen mode also puts the window into native full screen.
class FocusUi extends Notifier<FocusUiState> {
  @override
  FocusUiState build() {
    listenSelf((prev, next) {
      if (prev != null && prev.zen != next.zen) {
        unawaited(windowChannel.invokeMethod<void>('setFullScreen', next.zen));
      }
    });
    // User left full screen natively (green button, ⌃⌘F): leave zen too.
    windowChannel.setMethodCallHandler((call) async {
      if (call.method == 'didExitFullScreen' && state.zen) dismiss();
    });
    return (tasksOpen: false, todayOpen: false, zen: false);
  }

  void toggleTasks() => state = (
    tasksOpen: !state.tasksOpen,
    todayOpen: state.todayOpen,
    zen: false,
  );

  void openTasks() =>
      state = (tasksOpen: true, todayOpen: state.todayOpen, zen: false);

  void toggleToday() => state = (
    tasksOpen: state.tasksOpen,
    todayOpen: !state.todayOpen,
    zen: false,
  );

  void toggleZen() =>
      state = (tasksOpen: false, todayOpen: false, zen: !state.zen);

  /// Esc: close panels first, then leave zen.
  void dismiss() => state = (tasksOpen: false, todayOpen: false, zen: false);
}

final focusUiProvider = NotifierProvider<FocusUi, FocusUiState>(FocusUi.new);
