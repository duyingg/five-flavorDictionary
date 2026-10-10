import 'dart:io';
import 'dart:typed_data';

import 'package:wuwei_dictionary/features/data/poetry_binary_codec.dart';

void main() {
  final bytes = File('assets/data/poetry_items_full.wvp').readAsBytesSync();
  final catalog = PoetryBinaryCodec.open(ByteData.sublistView(bytes));
  for (final (label, query) in [
    ('translated', const PoetryQuery(translatedOnly: true)),
    ('dynasty', const PoetryQuery(dynasty: '唐')),
    ('text', const PoetryQuery(text: '明月')),
  ]) {
    final times = <int>[];
    for (var run = 0; run < 3; run++) {
      final watch = Stopwatch()..start();
      final count = catalog.select(query).length;
      watch.stop();
      times.add(watch.elapsedMilliseconds);
      if (run == 0) stdout.writeln('$label: $count matches');
    }
    stdout.writeln('$label ms: ${times.join(', ')}');
  }
}
