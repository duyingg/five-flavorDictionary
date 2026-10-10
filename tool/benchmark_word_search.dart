import 'dart:io';
import 'dart:typed_data';

import 'package:wuwei_dictionary/features/data/word_binary_codec.dart';

void main() {
  final bytes = File('assets/data/word_entries.wvd').readAsBytesSync();
  final fallback = WordBinaryCodec.open(ByteData.sublistView(bytes));
  final scan = Stopwatch()..start();
  final scanResults = fallback.searchPinyin(['zhong', 'guo']);
  scan.stop();
  stdout.writeln(
    'first pinyin without asset: ${scanResults.length} results, '
    '${scan.elapsedMilliseconds} ms',
  );
  final catalog = WordBinaryCodec.open(ByteData.sublistView(bytes));
  final index = File('assets/data/word_pinyin_index.wpi').readAsBytesSync();
  final install = Stopwatch()..start();
  catalog.installFirstReadingIndex(ByteData.sublistView(index));
  install.stop();
  stdout.writeln('index install: ${install.elapsedMilliseconds} ms');
  for (final (label, query) in [
    ('first pinyin', ['zhong', 'guo']),
    ('next pinyin', ['ren', 'min']),
    ('repeated pinyin', ['zhong', 'guo']),
  ]) {
    final watch = Stopwatch()..start();
    final count = catalog.searchPinyin(query).length;
    watch.stop();
    stdout.writeln('$label: $count results, ${watch.elapsedMilliseconds} ms');
  }
}
