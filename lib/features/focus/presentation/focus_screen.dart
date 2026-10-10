import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/native/window.dart';
import 'package:benkyo/features/calendar/presentation/today_panel.dart';
import 'package:benkyo/features/focus/presentation/focus_ui.dart';
import 'package:benkyo/features/music/presentation/mini_player.dart';
import 'package:benkyo/features/notes/presentation/notes_sheet.dart';
import 'package:benkyo/features/onboarding/presentation/onboarding_overlay.dart';
import 'package:benkyo/features/onboarding/presentation/onboarding_providers.dart';
import 'package:benkyo/features/scenery/presentation/scenery_background.dart';
import 'package:benkyo/features/scenery/presentation/scenery_drop_target.dart';
import 'package:benkyo/features/scenery/presentation/scenery_sheet.dart';
import 'package:benkyo/features/settings/presentation/settings_sheet.dart';
import 'package:benkyo/features/tasks/presentation/tasks_panel.dart';
import 'package:benkyo/features/timer/presentation/timer_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home: scenery, timer, and the Tasks / Today panels sliding in.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  // The native title bar strip swallows clicks; keep controls below it.
  static const _titleBar = 36.0;

  // Panels end above the music bar so they never cover its controls.
  static const double _aboveMiniPlayer =
      Tokens.s16 + MiniPlayer.height + Tokens.s12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(focusUiProvider);
    final notifier = ref.read(focusUiProvider.notifier);
    final slide = Tokens.motion(context, Tokens.panel);
    final fade = Tokens.motion(context, Tokens.fast);

    return Scaffold(
      body: SceneryDropTarget(
        child: Stack(
          children: [
            const Positioned.fill(child: SceneryBackground()),
            const Center(child: TimerCard()),
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: Tokens.s16),
                child: MiniPlayer(),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, _titleBar, 16, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Notes (⌘J)',
                      icon: const Icon(Icons.sticky_note_2_outlined),
                      onPressed: () => toggleNotesSheet(context),
                    ),
                    IconButton(
                      tooltip: 'Scenery (⌘E)',
                      icon: const Icon(Icons.landscape_outlined),
                      onPressed: () => toggleScenerySheet(context),
                    ),
                    IconButton(
                      tooltip: 'Settings (⌘,)',
                      icon: const Icon(Icons.tune),
                      onPressed: () => toggleSettingsSheet(context),
                    ),
                    const IconButton(
                      tooltip: 'Zen mode: full screen (F)',
                      icon: Icon(Icons.fullscreen),
                      onPressed: toggleFullScreen,
                    ),
                  ],
                ),
              ),
            ),
            _Fade(
              visible: !ui.tasksOpen,
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
              visible: !ui.todayOpen,
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
              bottom: _aboveMiniPlayer,
              left: ui.tasksOpen ? Tokens.s16 : -400,
              width: 370,
              child: TasksPanel(onClose: notifier.toggleTasks),
            ),
            AnimatedPositioned(
              duration: slide,
              curve: Tokens.curve,
              top: _titleBar + Tokens.s16,
              bottom: _aboveMiniPlayer,
              right: ui.todayOpen ? Tokens.s16 : -340,
              width: 304,
              child: TodayPanel(onClose: notifier.toggleToday),
            ),
            if (ref.watch(onboardingProvider).value ?? false)
              const Positioned.fill(child: OnboardingOverlay()),
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
