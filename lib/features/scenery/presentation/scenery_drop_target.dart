import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/features/scenery/presentation/scenery_sheet.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Drop images or videos anywhere on [child] to add them as scenery.
class SceneryDropTarget extends ConsumerStatefulWidget {
  const SceneryDropTarget({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SceneryDropTarget> createState() => _SceneryDropTargetState();
}

class _SceneryDropTargetState extends ConsumerState<SceneryDropTarget> {
  bool _over = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _over = true),
      onDragExited: (_) => setState(() => _over = false),
      onDragDone: (detail) {
        setState(() => _over = false);
        unawaited(
          importScenery(
            ref,
            ScaffoldMessenger.of(context),
            detail.files.map((f) => f.path).toList(),
          ),
        );
      },
      child: Stack(
        children: [
          widget.child,
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _over ? 1 : 0,
              duration: Tokens.motion(context, Tokens.fast),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined),
                        const SizedBox(width: Tokens.s12),
                        Text(
                          'Drop to add as scenery',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
