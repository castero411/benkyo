import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/core/widgets/platform_menu.dart';
import 'package:benkyo/features/scenery/domain/scene.dart';
import 'package:benkyo/features/scenery/presentation/scenery_background.dart';
import 'package:benkyo/features/scenery/presentation/scenery_providers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The open sheet, if any.
DialogRoute<void>? _openSheet;

/// ⌘E and the toolbar button: open the sheet, or close it if it's open,
/// never stacking a second copy.
void toggleScenerySheet(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final open = _openSheet;
  if (open != null) {
    navigator.removeRoute(open);
    return;
  }
  final route = DialogRoute<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const _ScenerySheet(),
  );
  _openSheet = route;
  // However it closes (⌘E, Esc, ×, click outside), forget it.
  unawaited(route.popped.whenComplete(() => _openSheet = null));
  navigator.push(route);
}

/// Opens the file picker and imports the choice. Reports in [messenger].
Future<void> pickAndImportScenery(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
) async {
  final files = await openFiles(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Images and videos',
        uniformTypeIdentifiers: ['public.image', 'public.movie'],
      ),
    ],
  );
  if (files.isEmpty) return;
  await importScenery(ref, messenger, files.map((f) => f.path).toList());
}

Future<void> importScenery(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  List<String> paths,
) async {
  final (:added, :failed) = await ref
      .read(sceneryProvider.notifier)
      .import(paths);
  final skipped = paths.length - added - failed;
  final parts = [
    if (added > 0) 'Added $added scene${added == 1 ? '' : 's'}',
    if (failed > 0) "$failed couldn't be read",
    if (skipped > 0) '$skipped not an image or video',
  ];
  if (parts.isNotEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(parts.join(' · '))));
  }
}

class _ScenerySheet extends ConsumerWidget {
  const _ScenerySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scenes = ref.watch(scenesProvider).value ?? builtInScenes;
    final current = ref.watch(currentSceneProvider);
    _Tile tile(Scene s) => _Tile(s, selected: s.id == current?.id);
    final builtIn = [for (final s in builtInScenes) tile(s)];
    final yours = [
      for (final s in scenes.where((s) => !s.isBuiltIn)) tile(s),
      const _AddTile(),
    ];

    // Own messenger so Undo toasts appear above the dialog's barrier.
    return ScaffoldMessenger(
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.transparent,
          // A click outside the panel closes it, like any sheet backdrop.
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // clicks inside the panel stay inside
                child: SizedBox(
                  width: 980,
                  height: 600,
                  child: GlassPanel(
                    radius: 24,
                    opacity: 0.86,
                    padding: const EdgeInsets.fromLTRB(28, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Scenery', style: text.headlineSmall),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Close (Esc)',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: Tokens.s12),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ListView(
                                  children: [
                                    const _Label('BUILT-IN'),
                                    _Grid(builtIn),
                                    const SizedBox(height: Tokens.s16),
                                    const _Label('YOURS'),
                                    _Grid(yours),
                                    const SizedBox(height: Tokens.s8),
                                    Text(
                                      'Photos (JPEG, PNG, HEIC) and videos '
                                      '(MP4, MOV). You can also drop them '
                                      'anywhere on the window.',
                                      style: text.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Tokens.s24),
                              if (current != null)
                                SizedBox(width: 250, child: _Adjust(current)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.s8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: Tokens.textSecondary),
    ),
  );
}

class _Grid extends StatelessWidget {
  const _Grid(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 4,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: Tokens.s12,
    crossAxisSpacing: Tokens.s12,
    childAspectRatio: 1.25,
    children: children,
  );
}

class _Tile extends ConsumerWidget {
  const _Tile(this.scene, {required this.selected});

  final Scene scene;
  final bool selected;

  Future<void> _menu(BuildContext context, WidgetRef ref, Offset at) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await showPlatformMenu(context, at, const [
      MenuEntry('Remove from Benkyo', id: 'remove'),
    ]);
    if (id != 'remove') return;
    final scenery = ref.read(sceneryProvider.notifier);
    final row = await scenery.remove(scene);
    final closed = messenger
        .showSnackBar(
          SnackBar(
            content: Text('Removed “${scene.name}”'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => scenery.restore(row),
            ),
          ),
        )
        .closed;
    // Files go only once Undo is no longer possible.
    unawaited(
      closed.then((reason) async {
        if (reason != SnackBarClosedReason.action) await scenery.purge(row);
      }),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final thumb = scene.thumbnailPath;
    final image = sceneImage(thumb);

    return Semantics(
      button: true,
      selected: selected,
      label: '${scene.name}${scene.isVideo ? ', video' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        onSecondaryTapUp: scene.isBuiltIn
            ? null
            : (d) => _menu(context, ref, d.globalPosition),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.r14),
            side: BorderSide(
              color: selected ? Tokens.accent : Colors.transparent,
              width: 3,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ref.read(sceneryProvider.notifier).select(scene.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Image(
                    image: ResizeImage(image, width: 360),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Tokens.ground,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            scene.name,
                            style: text.bodySmall?.copyWith(
                              color: Tokens.text,
                              fontWeight: selected ? FontWeight.w600 : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (scene.isVideo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('VIDEO', style: text.labelSmall),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends ConsumerWidget {
  const _AddTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.r14),
        side: const BorderSide(color: Colors.white38, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => pickAndImportScenery(ref, ScaffoldMessenger.of(context)),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.s12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 26),
              const SizedBox(height: Tokens.s8),
              Text('Add Scenery…', style: text.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _Adjust extends ConsumerWidget {
  const _Adjust(this.scene);

  final Scene scene;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scenery = ref.watch(sceneryProvider).value;
    if (scenery == null) return const SizedBox.shrink();
    final notifier = ref.read(sceneryProvider.notifier);
    final a = scenery.adjustFor(scene);
    final credit = scene.credit;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Tokens.glassBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: Tokens.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label('ADJUST · ${scene.name.toUpperCase()}'),
            _Slider(
              label: 'Dim',
              value: a.dim,
              max: 0.8,
              display: '${(a.dim * 100).round()}%',
              onChanged: (v, {save = false}) => notifier.setAdjust(scene.id, (
                dim: v,
                blur: a.blur,
              ), save: save),
            ),
            _Slider(
              label: 'Blur',
              value: a.blur,
              max: 20,
              display: a.blur.round().toString(),
              onChanged: (v, {save = false}) => notifier.setAdjust(scene.id, (
                dim: a.dim,
                blur: v,
              ), save: save),
            ),
            const SizedBox(height: Tokens.s8),
            // Own Material: the glass panel would hide the tile's highlight.
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: Text('Change scene each phase', style: text.bodyMedium),
                value: scenery.rotate,
                onChanged: (on) => notifier.setRotate(on: on ?? false),
              ),
            ),
            const Spacer(),
            if (credit != null)
              Text(
                '${scene.isVideo ? 'Video' : 'Photo'} by ${credit.author} '
                'on ${credit.source} · ${credit.license}',
                style: text.bodySmall,
              )
            else
              Text(
                'Right-click your scenes to remove them.',
                style: text.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final String display;
  final void Function(double value, {bool save}) onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: text.bodyMedium),
            const Spacer(),
            Text(display, style: text.bodySmall),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          max: max,
          label: display,
          semanticFormatterCallback: (_) => display,
          onChanged: onChanged,
          onChangeEnd: (v) => onChanged(v, save: true),
        ),
      ],
    );
  }
}
