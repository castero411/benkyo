import 'package:benkyo/features/notes/domain/note_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('title is the first non-empty line, without Markdown markers', () {
    expect(noteTitle('# Sprint plan\n\nShip it'), 'Sprint plan');
    expect(noteTitle('\n\n- buy milk'), 'buy milk');
    expect(noteTitle('> quote first'), 'quote first');
    expect(noteTitle('   '), 'New Note');
  });

  test('preview is the next line, stripped of syntax', () {
    expect(notePreview('# Plan\n\n**Ship** the [docs](x)'), 'Ship the docs(x)');
    expect(notePreview('# Only a title'), '');
  });

  test('search is case-insensitive over the whole body', () {
    expect(noteMatches('# Plan\nShip DOCS', 'docs'), isTrue);
    expect(noteMatches('# Plan', 'zzz'), isFalse);
    expect(noteMatches('anything', '  '), isTrue);
  });
}
