import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/culture/culture_pages.dart';

Future<List<Map<String, dynamic>>> passages(String id) async {
  final raw = await rootBundle.loadString(
    'assets/data/culture_passages/classic-$id.json',
  );
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('千字文与三字经按固定字数分段', () async {
    for (final (book, width) in [('qianziwen', 8), ('sanzijing', 6)]) {
      for (final passage in await passages(book)) {
        final text = passage['original'] as String;
        final hanCount = text.runes
            .where(
              (rune) =>
                  (rune >= 0x3400 && rune <= 0x9fff) ||
                  (rune >= 0x20000 && rune <= 0x323af),
            )
            .length;
        expect(hanCount, width, reason: '$book: $text');
      }
    }
  });

  test('道德经八十一章按章号排列', () async {
    final headings = (await passages('laozi'))
        .map((passage) => passage['heading'] as String)
        .where((heading) => heading.isNotEmpty)
        .toList();
    expect(headings.length, 81);
    expect(headings.take(3), [
      '道经 · 第一章',
      '道经 · 第二章',
      '道经 · 第三章',
    ]);
    expect(headings.last, '德经 · 第八十一章');
  });

  test('诗词行首孤立标点归入上一句', () {
    expect(readablePoetrySource('甲。\n”乙。\n）。\n丙。'), '甲。”\n乙。）。\n丙。');
    expect(readablePoetrySource('□□\n……残句。'), '〔原文缺字〕……\n残句。');
  });
}
