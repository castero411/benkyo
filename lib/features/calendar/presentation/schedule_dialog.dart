import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/features/calendar/domain/calendar_event.dart';
import 'package:benkyo/features/calendar/presentation/calendar_providers.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Schedule…": puts [task] on the calendar and makes that its due time.
/// Asks for calendar access here, in context, if needed.
Future<void> scheduleTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final access = ref.read(calendarAccessProvider.notifier);
  if (!await access.ensure()) {
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Benkyo needs calendar access to schedule.'),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: access.openSettings,
        ),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  final picked = await showDialog<(DateTime, Duration)>(
    context: context,
    builder: (_) => _ScheduleDialog(task),
  );
  if (picked == null) return;
  final (start, length) = picked;

  final api = ref.read(calendarApiProvider);
  final source = ref.read(taskSourceProvider);
  try {
    final eventId = await api.createEvent(
      task.title,
      start.millisecondsSinceEpoch,
      start.add(length).millisecondsSinceEpoch,
      task.id,
    );
    await source?.save(task.copyWith(due: () => start));
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Scheduled “${task.title}” · ${slotLabel(context, start)}',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await api.deleteEvent(eventId);
            await source?.save(task);
          },
        ),
      ),
    );
  } on PlatformException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text("Couldn't schedule: ${e.message ?? e.code}")),
    );
  }
}

/// "Today, 2:00 PM" / "Tomorrow, 9:00 AM" / "Fri, Oct 17, 9:00 AM".
String slotLabel(BuildContext context, DateTime t) {
  final l10n = MaterialLocalizations.of(context);
  final now = DateTime.now();
  final day = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayLabel = day == today
      ? 'Today'
      : day == today.add(const Duration(days: 1))
      ? 'Tomorrow'
      : l10n.formatMediumDate(t);
  return '$dayLabel, ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
}

class _ScheduleDialog extends ConsumerStatefulWidget {
  const _ScheduleDialog(this.task);

  final Task task;

  @override
  ConsumerState<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<_ScheduleDialog> {
  late Duration _length = ref.read(timerSettingsProvider).focus;
  DateTime? _slot;
  bool _custom = false;
  late DateTime _customTime = _nextFiveMinutes();

  static DateTime _nextFiveMinutes() {
    final n = DateTime.now().add(const Duration(minutes: 5));
    return DateTime(n.year, n.month, n.day, n.hour, n.minute - n.minute % 5);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final focus = ref.watch(timerSettingsProvider).focus;
    final events = ref.watch(upcomingEventsProvider).value ?? const [];
    final slots = freeSlots(
      events: events,
      now: DateTime.now(),
      length: _length,
    );
    final chosen = _custom ? _customTime : (_slot ?? slots.firstOrNull);

    return AlertDialog(
      backgroundColor: Tokens.glass,
      title: Text('Schedule “${widget.task.title}”'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Length', style: text.labelSmall),
            const SizedBox(height: Tokens.s8),
            CupertinoSlidingSegmentedControl<Duration>(
              groupValue: _length,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white.withValues(alpha: 0.18),
              onValueChanged: (v) => setState(() {
                _length = v ?? focus;
                _slot = null; // suggestions depend on length
              }),
              children: {
                focus: Text('${focus.inMinutes} min'),
                focus * 2: Text('${focus.inMinutes * 2} min'),
                const Duration(hours: 1): const Text('1 hr'),
              },
            ),
            const SizedBox(height: Tokens.s16),
            Text('When', style: text.labelSmall),
            const SizedBox(height: Tokens.s8),
            Wrap(
              spacing: Tokens.s8,
              runSpacing: Tokens.s8,
              children: [
                for (final s in slots)
                  ChoiceChip(
                    label: Text(slotLabel(context, s)),
                    selected: !_custom && s == chosen,
                    onSelected: (_) => setState(() {
                      _custom = false;
                      _slot = s;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Other time…'),
                  selected: _custom,
                  onSelected: (_) => setState(() => _custom = true),
                ),
              ],
            ),
            if (slots.isEmpty && !_custom)
              Padding(
                padding: const EdgeInsets.only(top: Tokens.s8),
                child: Text(
                  'No free time left today or tomorrow. Pick another time.',
                  style: text.bodySmall,
                ),
              ),
            if (_custom)
              SizedBox(
                height: 160,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(brightness: Brightness.dark),
                  child: CupertinoDatePicker(
                    initialDateTime: _customTime,
                    minimumDate: DateTime.now().subtract(
                      const Duration(minutes: 5),
                    ),
                    minuteInterval: 5,
                    onDateTimeChanged: (t) => setState(() => _customTime = t),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: chosen == null
              ? null
              : () => Navigator.of(context).pop((chosen, _length)),
          child: const Text('Add to Calendar'),
        ),
      ],
    );
  }
}
