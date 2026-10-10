import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/native/window.dart';
import 'package:benkyo/features/focus/presentation/focus_screen.dart';
import 'package:benkyo/features/focus/presentation/focus_ui.dart';
import 'package:benkyo/features/notes/presentation/notes_sheet.dart';
import 'package:benkyo/features/scenery/presentation/scenery_sheet.dart';
import 'package:benkyo/features/settings/presentation/settings_sheet.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lets menu-bar items (which sit above MaterialApp) open dialogs.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class BenkyoApp extends ConsumerWidget {
  const BenkyoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.read(focusUiProvider.notifier);
    final timer = ref.read(timerProvider.notifier);
    final running = ref.watch(timerProvider.select((s) => s.running));

    // ⌘ shortcuts live in the native menu bar so they are discoverable.
    // Bare keys (F, Esc) are handled in-app so they never fire while typing.
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Benkyo',
          menus: [
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.about,
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Settings…',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.comma,
                    meta: true,
                  ),
                  onSelected: () {
                    final context = rootNavigatorKey.currentContext;
                    if (context != null) toggleSettingsSheet(context);
                  },
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: [
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.hide,
                ),
                PlatformProvidedMenuItem(
                  type: PlatformProvidedMenuItemType.quit,
                ),
              ],
            ),
          ],
        ),
        PlatformMenu(
          label: 'Task',
          menus: [
            PlatformMenuItem(
              label: 'New Task',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
              ),
              onSelected: () {
                ui.openTasks();
                ref.read(quickAddFocusProvider).requestFocus();
              },
            ),
          ],
        ),
        PlatformMenu(
          label: 'Notes',
          menus: [
            PlatformMenuItem(
              label: 'Show Notes',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyJ,
                meta: true,
              ),
              onSelected: () {
                final context = rootNavigatorKey.currentContext;
                if (context != null) toggleNotesSheet(context);
              },
            ),
            PlatformMenuItem(
              label: 'New Note',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyN,
                meta: true,
                shift: true,
              ),
              onSelected: () {
                final context = rootNavigatorKey.currentContext;
                if (context != null) unawaited(newNote(context, ref));
              },
            ),
          ],
        ),
        PlatformMenu(
          label: 'Timer',
          menus: [
            // Space also toggles, but only in-app so it never eats typing.
            PlatformMenuItem(
              label: running ? 'Pause' : 'Start',
              onSelected: timer.toggle,
            ),
            PlatformMenuItem(
              label: 'Reset',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyR,
                meta: true,
              ),
              onSelected: timer.reset,
            ),
            PlatformMenuItem(
              label: 'Skip to Next Phase',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.arrowRight,
                meta: true,
              ),
              onSelected: timer.skip,
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: 'Tasks',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyT,
                meta: true,
              ),
              onSelected: ui.toggleTasks,
            ),
            PlatformMenuItem(
              label: 'Today',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyD,
                meta: true,
              ),
              onSelected: ui.toggleToday,
            ),
            // Standard "Enter Full Screen" (⌃⌘F); zen mode (F) is the same.
            const PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
            PlatformMenuItem(
              label: 'Scenery…',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyE,
                meta: true,
              ),
              onSelected: () {
                final context = rootNavigatorKey.currentContext;
                if (context != null) toggleScenerySheet(context);
              },
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Window',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        title: 'Benkyo',
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Focus(
          autofocus: true,
          onKeyEvent: (_, event) => _onKey(event, ui, timer),
          child: const FocusScreen(),
        ),
      ),
    );
  }

  KeyEventResult _onKey(KeyEvent event, FocusUi ui, TimerController timer) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isTyping) {
      // Esc leaves the text field; every other key belongs to it.
      if (event.logicalKey != LogicalKeyboardKey.escape) {
        return KeyEventResult.ignored;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      return KeyEventResult.handled;
    }
    if (HardwareKeyboard.instance.isMetaPressed) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        timer.toggle();
      case LogicalKeyboardKey.keyF:
        unawaited(toggleFullScreen());
      case LogicalKeyboardKey.escape:
        ui.dismiss();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static bool get _isTyping =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorStateOfType<EditableTextState>() !=
      null;
}
