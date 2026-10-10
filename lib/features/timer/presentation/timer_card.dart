import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/features/focus/presentation/focus_ui.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:benkyo/features/timer/domain/pomodoro.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The timer on its glass card, plus the task being focused on.
class TimerCard extends ConsumerWidget {
  const TimerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timerProvider);
    final timer = ref.read(timerProvider.notifier);
    final settings = ref.watch(timerSettingsProvider);
    final text = Theme.of(context).textTheme;
    final mins = s.secondsLeft ~/ 60;
    final secs = s.secondsLeft % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 480,
          child: GlassPanel(
            radius: Tokens.r28,
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoSlidingSegmentedControl<Phase>(
                  groupValue: s.phase,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  thumbColor: Colors.white.withValues(alpha: 0.18),
                  onValueChanged: (p) => timer.select(p ?? Phase.focus),
                  children: const {
                    Phase.focus: _Tab('Focus'),
                    Phase.shortBreak: _Tab('Short break'),
                    Phase.longBreak: _Tab('Long break'),
                  },
                ),
                const SizedBox(height: Tokens.s16),
                Semantics(
                  label: '$mins minutes $secs seconds remaining',
                  excludeSemantics: true,
                  child: Text(
                    formatClock(s.secondsLeft),
                    style: text.displayLarge,
                  ),
                ),
                const SizedBox(height: Tokens.s16),
                _SessionDots(
                  done: s.completedFocus,
                  total: settings.sessionsBeforeLongBreak,
                  current: s.phase == Phase.focus,
                ),
                const SizedBox(height: Tokens.s24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      icon: Icons.replay,
                      tooltip: 'Reset (⌘R)',
                      onPressed: timer.reset,
                    ),
                    const SizedBox(width: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, 56),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: timer.toggle,
                      icon: Icon(s.running ? Icons.pause : Icons.play_arrow),
                      label: Text(s.running ? 'Pause' : 'Start'),
                    ),
                    const SizedBox(width: 14),
                    _RoundButton(
                      icon: Icons.skip_next,
                      tooltip: 'Skip to next phase (⌘→)',
                      onPressed: timer.skip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.s16),
        const _TaskChip(),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

class _SessionDots extends StatelessWidget {
  const _SessionDots({
    required this.done,
    required this.total,
    required this.current,
  });

  final int done;
  final int total;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final label = current
        ? 'Session ${done + 1} of $total'
        : '$done of $total sessions done';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: Tokens.s8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? Tokens.accent : null,
                border: i < done
                    ? null
                    : Border.all(color: Colors.white54, width: 1.5),
              ),
            ),
          const SizedBox(width: Tokens.s4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      fixedSize: const Size(48, 48),
      backgroundColor: Colors.white.withValues(alpha: 0.1),
    ),
  );
}

/// The task being focused on. Click to pick another; × to unlink.
class _TaskChip extends ConsumerWidget {
  const _TaskChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(timerProvider.select((s) => s.taskId));
    final tasks = ref.watch(tasksProvider).value ?? const [];
    final task = tasks.where((t) => t.id == id && !t.done).firstOrNull;
    if (id == null || task == null) return const SizedBox(height: 44);

    final sessions = ref.watch(focusCountProvider(id)).value ?? 0;
    final text = Theme.of(context).textTheme;
    return GlassPanel(
      radius: Tokens.r14,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Tokens.priority(task.priority),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'P${task.priority}',
              style: text.labelSmall?.copyWith(color: Tokens.inkOnAccent),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: ref.read(focusUiProvider.notifier).openTasks,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text.rich(
                TextSpan(
                  text: task.title,
                  style: text.bodyLarge,
                  children: [
                    if (sessions > 0)
                      TextSpan(
                        text: ' · $sessions session${sessions == 1 ? '' : 's'}',
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Stop focusing on this task',
            icon: const Icon(Icons.close, size: 16),
            onPressed: ref.read(timerProvider.notifier).clearTask,
          ),
        ],
      ),
    );
  }
}
