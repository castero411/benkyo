import 'dart:async';

import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/db/app_database.dart';
import 'package:benkyo/core/native/window.dart';
import 'package:benkyo/core/widgets/glass_sheet.dart';
import 'package:benkyo/core/widgets/platform_menu.dart';
import 'package:benkyo/features/notes/domain/note_text.dart';
import 'package:benkyo/features/notes/presentation/notes_providers.dart';
import 'package:benkyo/features/tasks/domain/task.dart';
import 'package:benkyo/features/tasks/presentation/tasks_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NoteMode { edit, split, preview }

/// The note shown in the editor.
final selectedNoteProvider = NotifierProvider<SelectedNote, int?>(
  SelectedNote.new,
);

class SelectedNote extends Notifier<int?> {
  @override
  int? build() => null;

  int? get id => state;
  set id(int? value) => state = value;
}

final noteModeProvider = NotifierProvider<NoteModeNotifier, NoteMode>(
  NoteModeNotifier.new,
);

class NoteModeNotifier extends Notifier<NoteMode> {
  @override
  NoteMode build() => NoteMode.split;

  NoteMode get mode => state;
  set mode(NoteMode value) => state = value;
}

final _sheet = SheetToggle((_) => const _NotesSheet());

/// ⌘J and the toolbar button: open Notes, or close it if it's open.
void toggleNotesSheet(BuildContext context) => _sheet.toggle(context);

void _showSheet(BuildContext context) => _sheet.show(context);

/// ⌘⇧N: a fresh note, shown in the (opened) sheet.
Future<void> newNote(BuildContext context, WidgetRef ref) async {
  final id = await ref.read(notesStoreProvider).create();
  ref.read(selectedNoteProvider.notifier).id = id;
  if (context.mounted) _showSheet(context);
}

/// "Add Note…" / "Open Note" on a task: its note, created on first use
/// with the task's title as the heading.
Future<void> openNoteForTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final existing = ref.read(noteByTaskProvider)[task.id];
  final id =
      existing ??
      await ref
          .read(notesStoreProvider)
          .create(body: '# ${task.title}\n\n', taskId: task.id);
  ref.read(selectedNoteProvider.notifier).id = id;
  if (context.mounted) _showSheet(context);
}

class _NotesSheet extends ConsumerStatefulWidget {
  const _NotesSheet();

  @override
  ConsumerState<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends ConsumerState<_NotesSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final notes = ref.watch(notesProvider).value ?? const <Note>[];
    final selectedId = ref.watch(selectedNoteProvider);
    final mode = ref.watch(noteModeProvider);
    final shown = notes.where((n) => noteMatches(n.body, _query)).toList();
    // Only a note the search still shows; otherwise the first match.
    final selected =
        shown.where((n) => n.id == selectedId).firstOrNull ?? shown.firstOrNull;

    return GlassSheet(
      width: 1000,
      height: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Notes', style: text.headlineSmall),
              const SizedBox(width: Tokens.s12),
              IconButton(
                tooltip: 'New Note (⌘⇧N)',
                icon: const Icon(Icons.edit_note),
                onPressed: () => newNote(context, ref),
              ),
              const Spacer(),
              CupertinoSlidingSegmentedControl<NoteMode>(
                groupValue: mode,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                thumbColor: Colors.white.withValues(alpha: 0.18),
                onValueChanged: (m) =>
                    ref.read(noteModeProvider.notifier).mode =
                        m ?? NoteMode.split,
                children: const {
                  NoteMode.edit: _Seg('Edit'),
                  NoteMode.split: _Seg('Split'),
                  NoteMode.preview: _Seg('Preview'),
                },
              ),
              const SizedBox(width: Tokens.s8),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 260,
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (q) => setState(() => _query = q),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Tokens.r12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: Tokens.s8),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final n in shown)
                              _NoteRow(n, selected: n.id == selected?.id),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(
                  width: Tokens.s24,
                  color: Tokens.glassBorder,
                ),
                Expanded(
                  child: selected == null
                      ? _Empty(
                          searching: _query.isNotEmpty,
                          onNew: () => newNote(context, ref),
                        )
                      : _Editor(
                          selected,
                          mode: mode,
                          key: ValueKey(selected.id),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: Text(label, style: const TextStyle(fontSize: 13)),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching, required this.onNew});

  final bool searching;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          searching ? 'No notes match.' : 'No notes yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (!searching) ...[
          const SizedBox(height: Tokens.s12),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.edit_note),
            label: const Text('New Note'),
          ),
        ],
      ],
    ),
  );
}

class _NoteRow extends ConsumerWidget {
  const _NoteRow(this.note, {required this.selected});

  final Note note;
  final bool selected;

  Future<void> _menu(BuildContext context, WidgetRef ref, Offset at) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await showPlatformMenu(context, at, const [
      MenuEntry('Delete', id: 'delete'),
    ]);
    if (id != 'delete') return;
    final store = ref.read(notesStoreProvider);
    final row = await store.delete(note.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Deleted “${noteTitle(row.body)}”'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => store.restore(row),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final l10n = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final edited = note.updatedAt;
    final when =
        edited.year == now.year &&
            edited.month == now.month &&
            edited.day == now.day
        ? l10n.formatTimeOfDay(TimeOfDay.fromDateTime(edited))
        : l10n.formatShortMonthDay(edited);
    final task = (ref.watch(tasksProvider).value ?? const <Task>[])
        .where((t) => t.id == note.taskId)
        .firstOrNull;
    final preview = notePreview(note.body);

    return GestureDetector(
      onSecondaryTapUp: (d) => _menu(context, ref, d.globalPosition),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Tokens.r8),
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.r8),
          onTap: () => ref.read(selectedNoteProvider.notifier).id = note.id,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  noteTitle(note.body),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  preview.isEmpty ? when : '$when  $preview',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                if (task != null)
                  Text(
                    'Task · ${task.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: Tokens.accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor(this.note, {required this.mode, super.key});

  final Note note;
  final NoteMode mode;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late final _controller = TextEditingController(text: widget.note.body);
  late final NotesStore _store = ref.read(notesStoreProvider);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scheduleSave);
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _save);
    setState(() {}); // live preview
  }

  void _save() {
    _debounce = null;
    if (_controller.text != widget.note.body) {
      unawaited(_store.save(widget.note.id, _controller.text));
    }
  }

  @override
  void dispose() {
    // Switching notes or closing the sheet never loses the last keystrokes.
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _save();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editor = TextField(
      controller: _controller,
      autofocus: widget.mode != NoteMode.preview,
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(fontSize: 15, height: 1.5),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: 'Start with a title…',
      ),
    );
    final preview = Markdown(
      data: _controller.text,
      selectable: true,
      padding: const EdgeInsets.only(right: Tokens.s8),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        code: const TextStyle(fontFamily: 'Menlo', fontSize: 13),
        codeblockDecoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(Tokens.r8),
        ),
        blockquoteDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Tokens.r8),
        ),
      ),
      onTapLink: (_, href, _) {
        if (href != null) unawaited(openUrl(href));
      },
    );

    return switch (widget.mode) {
      NoteMode.edit => editor,
      NoteMode.preview => preview,
      NoteMode.split => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: editor),
          const VerticalDivider(width: Tokens.s24, color: Tokens.glassBorder),
          Expanded(child: preview),
        ],
      ),
    };
  }
}
