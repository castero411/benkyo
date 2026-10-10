import 'package:benkyo/core/native/native_api.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One menu entry. Use [MenuEntry.separator] between groups.
class MenuEntry {
  const MenuEntry(this.title, {this.id, this.checked = false, this.children});

  const MenuEntry.separator()
    : title = null,
      id = null,
      checked = false,
      children = null;

  final String? title;
  final String? id;
  final bool checked;
  final List<MenuEntry>? children;
}

final _menuApi = MenuApi();

/// Shows a context or pull-down menu at [position] (global coordinates) and
/// returns the chosen entry's id, or null if dismissed.
///
/// macOS gets a real NSMenu (see macos/Runner/MenuBridge.swift). Other
/// platforms get a flat Material menu until they have their own native look.
Future<String?> showPlatformMenu(
  BuildContext context,
  Offset position,
  List<MenuEntry> entries,
) {
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    return _menuApi.show(
      entries.map(_native).toList(),
      position.dx,
      position.dy,
    );
  }
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: [
      for (final e in entries.expand((e) => e.children ?? [e]))
        if (e.title == null)
          const PopupMenuDivider()
        else
          CheckedPopupMenuItem(
            value: e.id,
            checked: e.checked,
            child: Text(e.title!),
          ),
    ],
  );
}

NativeMenuItem _native(MenuEntry e) => NativeMenuItem(
  id: e.id,
  title: e.title,
  checked: e.checked,
  children: e.children?.map(_native).toList(),
);
