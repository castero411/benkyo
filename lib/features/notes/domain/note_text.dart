/// A note's title: its first non-empty line, without Markdown heading or
/// list markers, as in Apple Notes.
String noteTitle(String body) {
  for (final line in body.split('\n')) {
    final t = line.replaceFirst(RegExp(r'^\s*(#{1,6}|[-*+]|>)\s*'), '').trim();
    if (t.isNotEmpty) return t;
  }
  return 'New Note';
}

/// The line after the title, for the list subtitle.
String notePreview(String body) {
  final lines = body
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[#>*_`\[\]]'), '').trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return lines.length > 1 ? lines[1] : '';
}

/// Case-insensitive search over the whole note.
bool noteMatches(String body, String query) =>
    query.trim().isEmpty || body.toLowerCase().contains(query.toLowerCase());
