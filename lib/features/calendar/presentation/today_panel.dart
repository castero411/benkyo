import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/core/widgets/platform_menu.dart';
import 'package:benkyo/features/calendar/domain/calendar_event.dart';
import 'package:benkyo/features/calendar/presentation/calendar_providers.dart';
import 'package:benkyo/features/calendar/presentation/schedule_dialog.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's calendar beside your tasks.
class TodayPanel extends ConsumerStatefulWidget {
  const TodayPanel({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  ConsumerState<TodayPanel> createState() => _TodayPanelState();
}

class _TodayPanelState extends ConsumerState<TodayPanel> {
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    // Moves the "now" line and dims finished events.
    _minute = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  Future<void> _pickTaskToSchedule(Offset at) async {
    final all = ref.read(tasksProvider).value ?? const <Task>[];
    final open = visibleTasks(all, TaskView.all, DateTime.now()).take(10);
    if (open.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a task first, then schedule it.')),
      );
      return;
    }
    final id = await showPlatformMenu(context, at, [
      for (final t in open) MenuEntry('P${t.priority}  ${t.title}', id: t.id),
    ]);
    final task = open.where((t) => t.id == id).firstOrNull;
    if (task != null && mounted) await scheduleTask(context, ref, task);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l10n = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final access = ref.watch(calendarAccessProvider).value;
    final events = (ref.watch(upcomingEventsProvider).value ?? const [])
        .where((e) => e.start.day == now.day && e.start.month == now.month)
        .toList();
    final allDay = events.where((e) => e.allDay).toList();
    final timed = events.where((e) => !e.allDay).toList();

    final rows = <Widget>[];
    var nowShown = false;
    for (final e in timed) {
      if (!nowShown && e.start.isAfter(now)) {
        rows.add(_NowLine(now));
        nowShown = true;
      }
      rows.add(_EventRow(e, past: e.end.isBefore(now)));
    }
    if (!nowShown && timed.isNotEmpty) rows.add(_NowLine(now));

    return Semantics(
      container: true,
      label: 'Today',
      child: GlassPanel(
        opacity: Tokens.glassOpacityStrong,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today', style: text.titleLarge),
                      Text(l10n.formatFullDate(now), style: text.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close (Esc)',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: Tokens.s12),
            if (access != AccessStatus.granted)
              _AccessCard(access)
            else ...[
              for (final e in allDay) _AllDayChip(e),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          'Nothing scheduled today.',
                          style: text.bodySmall,
                        ),
                      )
                    : ListView(children: rows),
              ),
            ],
            if (access != AccessStatus.granted) const Spacer(),
            const SizedBox(height: Tokens.s8),
            Builder(
              builder: (button) => OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: Tokens.text,
                ),
                onPressed: () {
                  final box = button.findRenderObject()! as RenderBox;
                  unawaited(
                    _pickTaskToSchedule(
                      box.localToGlobal(box.size.topLeft(Offset.zero)),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule a Task…'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessCard extends ConsumerWidget {
  const _AccessCard(this.status);

  final AccessStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status == null || ref.watch(calendarCardDismissedProvider)) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final access = ref.read(calendarAccessProvider.notifier);
    final denied = status == AccessStatus.denied;
    return Container(
      padding: const EdgeInsets.all(Tokens.s12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Tokens.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            denied ? 'Calendar access is off' : 'Show your calendar',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Tokens.s4),
          Text(
            denied
                ? 'Allow access in System Settings to see today’s events.'
                : 'See today’s events here and schedule tasks into free time.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Tokens.s8),
          // Wraps: narrow panels can't fit both buttons on one line.
          Wrap(
            spacing: Tokens.s8,
            runSpacing: Tokens.s4,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 32)),
                onPressed: denied ? access.openSettings : access.ensure,
                child: Text(denied ? 'Open Settings' : 'Turn on'),
              ),
              TextButton(
                onPressed: ref
                    .read(calendarCardDismissedProvider.notifier)
                    .dismiss,
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip(this.event);

  final CalEvent event;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: Tokens.s8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: event.color.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(Tokens.r8),
    ),
    child: Text(
      'All day · ${event.title}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Tokens.text),
    ),
  );
}

class _NowLine extends StatelessWidget {
  const _NowLine(this.now);

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(now));
    return Semantics(
      label: 'Now, $time',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(
                time,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: Tokens.p1),
              ),
            ),
            const Expanded(child: Divider(color: Tokens.p1, thickness: 2)),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow(this.event, {required this.past});

  final CalEvent event;
  final bool past;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l10n = MaterialLocalizations.of(context);
    final minutes = event.end.difference(event.start).inMinutes;
    final length = minutes >= 60 && minutes % 60 == 0
        ? '${minutes ~/ 60} hr'
        : '$minutes min';
    final taskId = event.taskId;
    final fromTask = taskId != null;

    final block = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fromTask
            ? Tokens.accent.withValues(alpha: 0.18)
            : event.color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(Tokens.r8),
        border: fromTask
            ? Border.all(color: Tokens.accent.withValues(alpha: 0.6))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            fromTask
                ? 'Scheduled task · $length'
                : '${event.calendar} · $length',
            style: text.bodySmall,
          ),
        ],
      ),
    );

    return Opacity(
      opacity: past ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.formatTimeOfDay(TimeOfDay.fromDateTime(event.start)),
                  style: text.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: fromTask
                  ? Tooltip(
                      message: 'Focus on this task',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Tokens.r8),
                        onTap: () =>
                            ref.read(timerProvider.notifier).focusOn(taskId),
                        child: block,
                      ),
                    )
                  : block,
            ),
          ],
        ),
      ),
    );
  }
}
