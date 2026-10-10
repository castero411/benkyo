import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/native/native_api.g.dart';
import 'package:benkyo/core/widgets/glass_panel.dart';
import 'package:benkyo/core/widgets/platform_menu.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const Map<int, Color> _priorityColors = {
  1: Tokens.p1,
  2: Tokens.p2,
  3: Tokens.p3,
  4: Tokens.p4,
};

class TasksPanel extends ConsumerWidget {
  const TasksPanel({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final synced =
        ref.watch(remindersSyncProvider).value == AccessStatus.granted;
    final view = ref.watch(taskViewProvider);

    return Semantics(
      container: true,
      label: 'Tasks',
      child: GlassPanel(
        opacity: Tokens.glassOpacityStrong,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Tasks', style: text.titleLarge),
                const Spacer(),
                if (synced) ...[
                  const Icon(Icons.check, size: 14, color: Tokens.success),
                  const SizedBox(width: Tokens.s4),
                  Text('Synced with Reminders', style: text.bodySmall),
                ],
                IconButton(
                  tooltip: 'Close (Esc)',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
            const _SyncCard(),
            const SizedBox(height: Tokens.s8),
            CupertinoSlidingSegmentedControl<TaskView>(
              groupValue: view,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              thumbColor: Colors.white.withValues(alpha: 0.18),
              onValueChanged: (v) => ref.read(taskViewProvider.notifier).view =
                  v ?? TaskView.today,
              children: const {
                TaskView.today: _Segment('Today'),
                TaskView.all: _Segment('All'),
                TaskView.done: _Segment('Done'),
              },
            ),
            const SizedBox(height: Tokens.s12),
            const _QuickAdd(),
            const SizedBox(height: Tokens.s8),
            const Expanded(child: _TaskList()),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

/// Asks for Reminders access in context, with the reason up front.
class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(remindersSyncProvider).value;
    final dismissed = ref.watch(syncCardDismissedProvider);
    if (status == null || status == AccessStatus.granted || dismissed) {
      return const SizedBox.shrink();
    }
    final sync = ref.read(remindersSyncProvider.notifier);
    final denied = status == AccessStatus.denied;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(top: Tokens.s8),
      padding: const EdgeInsets.all(Tokens.s12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(Tokens.r12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            denied ? 'Reminders access is off' : 'Sync with Apple Reminders',
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Tokens.s4),
          Text(
            denied
                ? 'Tasks are saved on this Mac only. Allow access in '
                      'System Settings to see them on your iPhone.'
                : 'See your tasks on iPhone and Apple Watch. Tasks you '
                      'already added move over.',
            style: text.bodySmall,
          ),
          const SizedBox(height: Tokens.s8),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 32)),
                onPressed: denied ? sync.openSettings : sync.enable,
                child: Text(denied ? 'Open Settings' : 'Turn on'),
              ),
              const SizedBox(width: Tokens.s8),
              TextButton(
                onPressed: ref.read(syncCardDismissedProvider.notifier).dismiss,
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAdd extends ConsumerStatefulWidget {
  const _QuickAdd();

  @override
  ConsumerState<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends ConsumerState<_QuickAdd> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final focus = ref.read(quickAddFocusProvider);
    final (title, priority) = parseQuickAdd(value);
    final source = ref.read(taskSourceProvider);
    if (title.isEmpty || source == null) return;
    final ok = await _guard(
      context,
      () => source.save(Task(title: title, priority: priority)),
    );
    if (ok) _controller.clear(); // keep the text if saving failed
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: ref.watch(quickAddFocusProvider),
      onSubmitted: _submit,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.add, size: 18),
        hintText: 'Add a task…  !1–!4 sets priority',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.r12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.r12),
          borderSide: BorderSide(color: Tokens.accent.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final view = ref.watch(taskViewProvider);

    return ref
        .watch(tasksProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Couldn't load tasks", style: text.bodySmall),
                TextButton(
                  onPressed: () => ref.invalidate(taskSourceProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (all) {
            final tasks = visibleTasks(all, view, DateTime.now());
            if (tasks.isEmpty) {
              return Center(
                child: Text(switch (view) {
                  TaskView.today => 'Nothing for today. Add a task above.',
                  TaskView.all => 'No tasks yet. Add one above.',
                  TaskView.done => 'Completed tasks show up here.',
                }, style: text.bodySmall),
              );
            }
            final rows = <Widget>[];
            int? group;
            for (final t in tasks) {
              if (view != TaskView.done && t.priority != group) {
                group = t.priority;
                rows.add(_GroupHeader(t.priority));
              }
              rows.add(_TaskRow(t, key: ValueKey(t.id)));
            }
            return ListView(children: rows);
          },
        );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.priority);

  final int priority;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
    child: Text(
      'P$priority · ${priorityLabels[priority]!.toUpperCase()}',
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: _priorityColors[priority]),
    ),
  );
}

class _TaskRow extends ConsumerStatefulWidget {
  const _TaskRow(this.task, {super.key});

  final Task task;

  @override
  ConsumerState<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends ConsumerState<_TaskRow> {
  bool _editing = false;

  Task get task => widget.task;

  Future<void> _save(Task updated) async {
    final source = ref.read(taskSourceProvider);
    if (source != null) await _guard(context, () => source.save(updated));
  }

  Future<void> _toggleDone() async {
    final messenger = ScaffoldMessenger.of(context);
    final before = task;
    await _save(
      task.copyWith(completedAt: () => task.done ? null : DateTime.now()),
    );
    if (before.done) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Completed “${before.title}”'),
        action: SnackBarAction(label: 'Undo', onPressed: () => _save(before)),
      ),
    );
  }

  Future<void> _delete() async {
    final source = ref.read(taskSourceProvider);
    if (source == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _guard(context, () => source.delete(task.id!));
    if (!ok) return;
    final copy = Task(
      title: task.title,
      priority: task.priority,
      due: task.due,
      completedAt: task.completedAt,
      notes: task.notes,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted “${task.title}”'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => source.save(copy),
        ),
      ),
    );
  }

  /// Context menu content, grouped and titled per the macOS HIG:
  /// title-case verbs, related choices in submenus with a checkmark on the
  /// current value, destructive action last in its own group.
  Future<void> _showMenu(Offset position) async {
    final due = task.due;
    final dueDay = due == null ? null : DateTime(due.year, due.month, due.day);
    final id = await showPlatformMenu(context, position, [
      MenuEntry(
        task.done ? 'Mark as Not Completed' : 'Mark as Completed',
        id: 'toggle',
      ),
      const MenuEntry.separator(),
      MenuEntry(
        'Priority',
        children: [
          for (final p in priorityLabels.keys)
            MenuEntry(
              'P$p – ${priorityLabels[p]}',
              id: 'p$p',
              checked: p == task.priority,
            ),
        ],
      ),
      MenuEntry(
        'Due Date',
        children: [
          MenuEntry('Today', id: 'today', checked: dueDay == _day(0)),
          MenuEntry('Tomorrow', id: 'tomorrow', checked: dueDay == _day(1)),
          const MenuEntry.separator(),
          MenuEntry('None', id: 'no-due', checked: due == null),
        ],
      ),
      const MenuEntry.separator(),
      const MenuEntry('Rename', id: 'rename'),
      const MenuEntry.separator(),
      const MenuEntry('Delete', id: 'delete'),
    ]);
    if (!mounted || id == null) return;
    switch (id) {
      case 'toggle':
        await _toggleDone();
      case 'today':
        await _save(task.copyWith(due: () => _day(0)));
      case 'tomorrow':
        await _save(task.copyWith(due: () => _day(1)));
      case 'no-due':
        await _save(task.copyWith(due: () => null));
      case 'rename':
        setState(() => _editing = true);
      case 'delete':
        await _delete();
      default: // p1…p4
        await _save(task.copyWith(priority: int.parse(id.substring(1))));
    }
  }

  DateTime _day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset);
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColors[task.priority]!;
    final text = Theme.of(context).textTheme;
    final due = task.due;

    return GestureDetector(
      onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
      onDoubleTap: () => setState(() => _editing = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            IconButton(
              tooltip: task.done ? 'Mark as not done' : 'Complete',
              onPressed: _toggleDone,
              icon: Icon(
                task.done ? Icons.check_circle : Icons.circle_outlined,
                color: task.done ? Tokens.success : color,
                size: 22,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editing)
                    _RenameField(
                      initial: task.title,
                      onDone: (title) {
                        setState(() => _editing = false);
                        if (title.isNotEmpty && title != task.title) {
                          unawaited(_save(task.copyWith(title: title)));
                        }
                      },
                    )
                  else
                    Text(
                      task.title,
                      style: text.bodyMedium?.copyWith(
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.done ? Tokens.textSecondary : null,
                      ),
                    ),
                  if (due != null && !task.done)
                    Text(_dueLabel(context, due), style: text.bodySmall),
                ],
              ),
            ),
            Builder(
              builder: (button) => IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz, size: 18),
                color: Tokens.textSecondary,
                // Pull-down: opens below the button, leading edges aligned.
                onPressed: () {
                  final box = button.findRenderObject()! as RenderBox;
                  unawaited(
                    _showMenu(
                      box.localToGlobal(box.size.bottomLeft(Offset.zero)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dueLabel(BuildContext context, DateTime due) {
    final l10n = MaterialLocalizations.of(context);
    final day = DateTime(due.year, due.month, due.day);
    final today = _day(0);
    final label = day == today
        ? 'Today'
        : day == _day(1)
        ? 'Tomorrow'
        : day.isBefore(today)
        ? 'Overdue · ${l10n.formatShortMonthDay(due)}'
        : l10n.formatMediumDate(due);
    final hasTime = due.hour != 0 || due.minute != 0;
    return hasTime
        ? '$label, ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(due))}'
        : label;
  }
}

class _RenameField extends StatefulWidget {
  const _RenameField({required this.initial, required this.onDone});

  final String initial;
  final ValueChanged<String> onDone;

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    // Saves on Enter or when focus leaves (click away, Esc).
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish();
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone(_controller.text.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    autofocus: true,
    style: const TextStyle(fontSize: 14),
    decoration: const InputDecoration.collapsed(hintText: 'Task name'),
    onSubmitted: (_) => _finish(),
  );
}

/// Runs [action]; on failure shows an inline error instead of losing input.
Future<bool> _guard(
  BuildContext context,
  Future<void> Function() action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on PlatformException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text("Couldn't save: ${e.message ?? e.code}")),
    );
    return false;
  }
}
