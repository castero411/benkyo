import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/features/focus/presentation/focus_ui.dart';
import 'package:benkyo/features/tasks/presentation/tasks_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home: scenery, timer, and the Tasks / Today panels sliding in.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  // The native title bar strip swallows clicks; keep controls below it.
  static const _titleBar = 36.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(focusUiProvider);
    final notifier = ref.read(focusUiProvider.notifier);
    final slide = Tokens.motion(context, Tokens.panel);
    final fade = Tokens.motion(context, Tokens.fast);
    final chrome = !ui.zen;

    return Scaffold(
      body: Stack(
        children: [
          // Scenery lands here in Phase 4.
          const Positioned.fill(child: ColoredBox(color: Tokens.ground)),
          const Center(child: _TimerCard()),
          _Fade(
            visible: chrome,
            duration: fade,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, _titleBar, 16, 0),
                child: IconButton(
                  tooltip: 'Zen mode (F)',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: notifier.toggleZen,
                ),
              ),
            ),
          ),
          _Fade(
            visible: chrome && !ui.tasksOpen,
            duration: fade,
            child: _EdgeTab(
              side: AxisDirection.left,
              icon: Icons.checklist,
              label: '⌘T',
              semantics: 'Open tasks',
              onTap: notifier.toggleTasks,
            ),
          ),
          _Fade(
            visible: chrome && !ui.todayOpen,
            duration: fade,
            child: _EdgeTab(
              side: AxisDirection.right,
              icon: Icons.calendar_today_outlined,
              label: '⌘D',
              semantics: 'Open today',
              onTap: notifier.toggleToday,
            ),
          ),
          AnimatedPositioned(
            duration: slide,
            curve: Tokens.curve,
            top: _titleBar + Tokens.s16,
            bottom: Tokens.s16,
            left: ui.tasksOpen ? Tokens.s16 : -400,
            width: 370,
            child: TasksPanel(onClose: notifier.toggleTasks),
          ),
          AnimatedPositioned(
            duration: slide,
            curve: Tokens.curve,
            top: _titleBar + Tokens.s16,
            bottom: Tokens.s16,
            right: ui.todayOpen ? Tokens.s16 : -340,
            width: 304,
            child: _Panel(
              title: 'Today',
              empty: 'Nothing scheduled today',
              onClose: notifier.toggleToday,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 480,
      child: GlassPanel(
        radius: Tokens.r28,
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('25:00', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: Tokens.s24),
            // Timer logic arrives in Phase 3.
            const FilledButton(onPressed: null, child: Text('Start')),
          ],
        ),
      ),
    );
  }
}

class _EdgeTab extends StatelessWidget {
  const _EdgeTab({
    required this.side,
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onTap,
  });

  final AxisDirection side;
  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = side == AxisDirection.left;
    const r = Radius.circular(Tokens.r12);
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: Material(
          color: Tokens.glass.withValues(alpha: 0.55),
          borderRadius: left
              ? const BorderRadius.horizontal(right: r)
              : const BorderRadius.horizontal(left: r),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 96,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.empty,
    required this.onClose,
  });

  final String title;
  final String empty;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: title,
      child: GlassPanel(
        opacity: Tokens.glassOpacityStrong,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: text.titleLarge)),
                IconButton(
                  tooltip: 'Close (Esc)',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
            Expanded(
              child: Center(child: Text(empty, style: text.bodySmall)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({
    required this.visible,
    required this.duration,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        child: child,
      ),
    );
  }
}
