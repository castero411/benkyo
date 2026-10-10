import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/features/music/domain/spotify_link.dart';
import 'package:benkyo/features/music/presentation/music_controller.dart';
import 'package:benkyo/features/onboarding/presentation/onboarding_providers.dart';
import 'package:benkyo/features/scenery/domain/scene.dart';
import 'package:benkyo/features/scenery/presentation/scenery_background.dart';
import 'package:benkyo/features/scenery/presentation/scenery_providers.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Three skippable steps on first launch: scene → music → first task.
class OnboardingOverlay extends ConsumerStatefulWidget {
  const OnboardingOverlay({super.key});

  @override
  ConsumerState<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends ConsumerState<OnboardingOverlay> {
  static const _scenes = [
    'builtin:night-desk',
    'builtin:rainy-window',
    'builtin:golden-hour',
  ];
  final _task = TextEditingController();
  int _step = 0;
  String? _playlist;

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  Future<void> _finish({bool skipped = false}) async {
    final title = parseQuickAdd(_task.text);
    final source = ref.read(taskSourceProvider);
    if (!skipped && title.$1.isNotEmpty && source != null) {
      await source.save(Task(title: title.$1, priority: title.$2));
    }
    final playlist = _playlist;
    if (!skipped && playlist != null) {
      unawaited(ref.read(musicProvider.notifier).play(playlist));
    }
    await ref.read(onboardingProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _step == 2;

    final body = switch (_step) {
      0 => _StepBody(
        title: 'Pick your scene',
        subtitle: 'You can add your own photos and videos later.',
        child: Row(
          children: [
            for (final id in _scenes) ...[
              Expanded(child: _SceneChoice(id)),
              if (id != _scenes.last) const SizedBox(width: Tokens.s12),
            ],
          ],
        ),
      ),
      1 => _StepBody(
        title: 'Choose your music',
        subtitle:
            'Plays through the Spotify app. Works with free and Premium '
            'accounts. Optional.',
        child: Column(
          children: [
            for (final p in presets.take(3))
              _Choice(
                label: p.name,
                selected: _playlist == p.uri,
                onTap: () => setState(
                  () => _playlist = _playlist == p.uri ? null : p.uri,
                ),
              ),
          ],
        ),
      ),
      _ => _StepBody(
        title: 'What are you working on?',
        subtitle: 'Add your first task. Type !1 to !4 to set its priority.',
        child: TextField(
          controller: _task,
          autofocus: true,
          onSubmitted: (_) => _finish(),
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            labelText: 'First task',
            hintText: 'e.g. Write API docs !1',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Tokens.r12),
            ),
          ),
        ),
      ),
    };

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: SizedBox(
          width: 640,
          child: GlassPanel(
            radius: Tokens.r28,
            opacity: 0.85,
            padding: const EdgeInsets.all(Tokens.s32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'STEP ${_step + 1} OF 3',
                      style: text.labelSmall?.copyWith(color: Tokens.accent),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _finish(skipped: true),
                      child: const Text('Skip setup'),
                    ),
                  ],
                ),
                const SizedBox(height: Tokens.s12),
                AnimatedSwitcher(
                  duration: Tokens.motion(context, Tokens.fast),
                  child: KeyedSubtree(key: ValueKey(_step), child: body),
                ),
                const SizedBox(height: Tokens.s24),
                Row(
                  children: [
                    Semantics(
                      label: 'Step ${_step + 1} of 3',
                      excludeSemantics: true,
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            AnimatedContainer(
                              duration: Tokens.motion(context, Tokens.fast),
                              width: i == _step ? 22 : 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: i == _step
                                    ? Tokens.accent
                                    : Colors.white38,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Back'),
                      ),
                    const SizedBox(width: Tokens.s8),
                    FilledButton(
                      onPressed: last ? _finish : () => setState(() => _step++),
                      child: Text(last ? 'Start Focusing' : 'Continue'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: text.headlineSmall)),
        const SizedBox(height: Tokens.s4),
        Text(
          subtitle,
          style: text.bodyLarge?.copyWith(color: Tokens.textSecondary),
        ),
        const SizedBox(height: Tokens.s16),
        child,
      ],
    );
  }
}

/// A built-in scene; choosing it changes the background right away.
class _SceneChoice extends ConsumerWidget {
  const _SceneChoice(this.id);

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = builtInScenes.firstWhere((s) => s.id == id);
    final selected = ref.watch(currentSceneProvider)?.id == id;
    return Semantics(
      button: true,
      selected: selected,
      label: scene.name,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.r14),
          side: BorderSide(
            color: selected ? Tokens.accent : Colors.transparent,
            width: 3,
          ),
        ),
        child: InkWell(
          onTap: () => ref.read(sceneryProvider.notifier).select(id),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Image(
                  image: ResizeImage(
                    sceneImage(scene.thumbnailPath),
                    width: 360,
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Tokens.s8),
                child: Text(
                  scene.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.s8),
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? Tokens.accent.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.r14),
          side: BorderSide(
            color: selected ? Tokens.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.r14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.queue_music, size: 20),
                const SizedBox(width: Tokens.s12),
                Expanded(child: Text(label)),
                if (selected) const Icon(Icons.check, color: Tokens.accent),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
