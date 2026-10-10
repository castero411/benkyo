import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef FocusUiState = ({bool tasksOpen, bool todayOpen});

/// Native window control, see macos/Runner/MainFlutterWindow.swift.
const windowChannel = MethodChannel('benkyo/window');

/// Zen mode: native macOS full screen, same as View → Enter Full Screen.
Future<void> toggleFullScreen() =>
    windowChannel.invokeMethod<void>('toggleFullScreen');

/// Which panels are open on the Focus screen.
class FocusUi extends Notifier<FocusUiState> {
  @override
  FocusUiState build() => (tasksOpen: false, todayOpen: false);

  void toggleTasks() =>
      state = (tasksOpen: !state.tasksOpen, todayOpen: state.todayOpen);

  void openTasks() => state = (tasksOpen: true, todayOpen: state.todayOpen);

  void toggleToday() =>
      state = (tasksOpen: state.tasksOpen, todayOpen: !state.todayOpen);

  /// Esc: close any open panel.
  void dismiss() => state = (tasksOpen: false, todayOpen: false);
}

final focusUiProvider = NotifierProvider<FocusUi, FocusUiState>(FocusUi.new);
