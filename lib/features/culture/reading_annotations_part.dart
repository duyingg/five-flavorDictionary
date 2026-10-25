part of 'culture_pages.dart';

String _readingNumber(int number) {
  if (number < 1) return number.toString();
  if (number <= 20) {
    return String.fromCharCode(0x2460 + number - 1);
  }
  if (number <= 35) return String.fromCharCode(0x3251 + number - 21);
  if (number <= 50) return String.fromCharCode(0x32b1 + number - 36);
  return '($number)';
}

class _ReadingNote {
  const _ReadingNote(this.text, this.term);
  final String text;
  final String term;
}

List<_ReadingNote> _readingNotes(String text) {
  final prefix =
      RegExp(r'^\s*(?:[①-⑳⑴-⒇㉑-㉟㊱-㊿]|[（(]?\d+[)）.．、]|[一二三四五六七八九十百]+[、.．])\s*');
  final result = <_ReadingNote>[];
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final numbered = prefix.hasMatch(line);
    final note = _readingNote(line.replaceFirst(prefix, ''));
    if (result.isNotEmpty && !numbered && note.term.isEmpty) {
      final previous = result.removeLast();
      result.add(_ReadingNote('${previous.text}\n${note.text}', previous.term));
    } else {
      result.add(note);
    }
  }
  return result;
}

_ReadingNote _readingNote(String text) {
  final colon = text.indexOf(RegExp('[：:]'));
  if (colon <= 0 || colon > 32) return _ReadingNote(text, '');
  var term = text.substring(0, colon).trim();
  term = term.replaceAll(RegExp(r'[（(][^）)]*[）)]'), '').trim();
  final quoted = RegExp(r'^[“「『]([^”」』]+)[”」』](?:句|二句|两句)?$').firstMatch(term);
  if (quoted != null) term = quoted.group(1)!;
  if (term.isEmpty ||
      term.characters.length > 12 ||
      term.characters.any((character) => !_isReadingCharacter(character))) {
    term = '';
  }
  return _ReadingNote(text, term);
}

class _ReadingNoteMarker {
  const _ReadingNoteMarker(this.endOffset, this.number);
  final int endOffset;
  final int number;
}

class _InlineReadingNotes extends InheritedWidget {
  const _InlineReadingNotes(
      {required this.notes,
      required this.visibleNumbers,
      required this.markerKeys,
      required this.indentParagraphs,
      this.paragraphNumber,
      required super.child});
  final List<_ReadingNote> notes;
  final Set<int> visibleNumbers;
  final bool indentParagraphs;
  final int? paragraphNumber;
  final Map<int, GlobalKey> markerKeys;
  static List<_ReadingNoteMarker> markersFor(
      BuildContext context, String text) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_InlineReadingNotes>();
    final notes = scope?.notes ?? const <_ReadingNote>[];
    final result = <_ReadingNoteMarker>[];
    for (var index = 0; index < notes.length; index++) {
      if (scope?.visibleNumbers.contains(index + 1) != true) continue;
      final term = notes[index].term;
      if (term.isEmpty) continue;
      final start = text.indexOf(term);
      // Match explicit note headwords only. Do not invent sentence alignment
      // for commentary that has no identifiable reference in the source.
      if (start >= 0) {
        result.add(_ReadingNoteMarker(start + term.length, index + 1));
      }
    }
    result.sort((a, b) {
      final offset = a.endOffset.compareTo(b.endOffset);
      return offset == 0 ? a.number.compareTo(b.number) : offset;
    });
    return result;
  }

  @override
  bool updateShouldNotify(_InlineReadingNotes oldWidget) =>
      paragraphNumber != oldWidget.paragraphNumber ||
      indentParagraphs != oldWidget.indentParagraphs ||
      !identical(notes, oldWidget.notes) ||
      !identical(visibleNumbers, oldWidget.visibleNumbers);
}

List<InlineSpan> _annotatedReadingSpans(
    BuildContext context, String text, List<_ReadingNoteMarker> markers,
    {bool indent = true}) {
  // Add indentation only to display spans, preserving source offsets and pinyin.
  final number = context
      .dependOnInheritedWidgetOfExactType<_InlineReadingNotes>()
      ?.paragraphNumber;
  final spans = <InlineSpan>[
    if (indent) const TextSpan(text: '\u3000\u3000'),
    if (number != null) _readingParagraphLabel(context, '$number '),
  ];
  String indented(String value) => _protectLineInitialPunctuation(value)
      .replaceAll('\n', indent ? '\n\u3000\u3000' : '\n');
  var offset = 0;
  for (final marker in markers) {
    spans.add(
        TextSpan(text: indented(text.substring(offset, marker.endOffset))));
    spans.add(const TextSpan(text: '\u2060'));
    spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Transform.translate(
            offset: Offset(0, -MediaQuery.textScalerOf(context).scale(18) * .4),
            child: _ReadingInlineMarker(number: marker.number))));
    spans.add(const TextSpan(text: '\u2060'));
    offset = marker.endOffset;
  }
  spans.add(TextSpan(text: indented(text.substring(offset))));
  return spans;
}

class _ReadingInlineMarker extends StatelessWidget {
  const _ReadingInlineMarker({required this.number});
  final int number;
  @override
  Widget build(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_InlineReadingNotes>();
    return Text(_readingNumber(number),
        key: scope?.markerKeys.putIfAbsent(number, GlobalKey.new),
        style: TextStyle(
            fontSize: 11,
            height: 1.1,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary));
  }
}

class _ArticleOriginalText extends StatelessWidget {
  const _ArticleOriginalText(
      {required this.text,
      required this.showPinyin,
      this.readings,
      this.style = const TextStyle(fontSize: 18, height: 2)});
  final String text;
  final bool showPinyin;
  final Future<List<String>>? readings;
  final TextStyle style;
  @override
  Widget build(BuildContext context) {
    final indent = context
            .dependOnInheritedWidgetOfExactType<_InlineReadingNotes>()
            ?.indentParagraphs ??
        true;
    final content = indent
        ? text.replaceAll(RegExp(r'^[ \t\u3000]+', multiLine: true), '')
        : text;
    final markers = _InlineReadingNotes.markersFor(context, content);
    if (showPinyin) {
      return _PinyinText(
          text: content, readings: readings, markers: markers, indent: indent);
    }
    return Text.rich(
        TextSpan(
            children: _annotatedReadingSpans(context, content, markers,
                indent: indent)),
        style: style);
  }
}

TextSpan _readingParagraphLabel(BuildContext context, String label) => TextSpan(
    text: label,
    style: TextStyle(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary));

Widget _readingReferenceParagraph(BuildContext context, String text,
        {required bool indent, int? number, bool paragraph = false}) =>
    Text.rich(
        TextSpan(children: [
          if (indent) const TextSpan(text: '\u3000\u3000'),
          if (number != null)
            _readingParagraphLabel(
                context, paragraph ? '$number ' : '${_readingNumber(number)} '),
          TextSpan(
              text: _protectLineInitialPunctuation(text.trimLeft())
                  .replaceAll('\n', indent ? '\n\u3000\u3000' : '\n')),
        ]),
        style: TextStyle(
            fontSize: 18,
            height: 1.85,
            color: Theme.of(context).colorScheme.onSurface));

// Keep marker offsets inside punctuation-joined runs, rather than moving a
// marker after the punctuation when reading mode is enabled.
Iterable<(_PinyinRun, List<_ReadingNoteMarker>)> _markedPinyinRuns(String text,
    List<String> readings, List<_ReadingNoteMarker> markers) sync* {
  var offset = 0;
  var markerIndex = 0;
  for (final run in _pinyinRuns(text, readings)) {
    final start = offset;
    offset += run.isLineBreak ? 1 : run.text.length;
    final attached = <_ReadingNoteMarker>[];
    while (markerIndex < markers.length &&
        markers[markerIndex].endOffset <= offset) {
      final marker = markers[markerIndex++];
      attached.add(_ReadingNoteMarker(marker.endOffset - start, marker.number));
    }
    yield (run, attached);
  }
}

Iterable<(String, List<int>)> _markedPinyinCharacters(
    String text, List<_ReadingNoteMarker> markers) sync* {
  var offset = 0;
  var markerIndex = 0;
  for (final character in text.characters) {
    offset += character.length;
    final numbers = <int>[];
    while (markerIndex < markers.length &&
        markers[markerIndex].endOffset <= offset) {
      numbers.add(markers[markerIndex++].number);
    }
    yield (character, numbers);
  }
}

String _cleanReadingAppreciation(String text) {
  const headings = {'创作背景', '写作背景', '赏析', '作品赏析', '鉴赏', '评析', '解析', '赏读'};
  final lines = <String>[];
  String? previous;
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final normalized = raw.trim().replaceFirst(RegExp(r'[：:]$'), '');
    if (normalized.isNotEmpty) {
      if (normalized == previous && headings.contains(normalized)) continue;
      previous = normalized;
    }
    lines.add(raw);
  }
  return lines.join('\n');
}
