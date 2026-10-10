import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/learning/classical_dictionary_page.dart';

class _Words implements WordRepository {
  @override
  Future<WordEntry?> findExact(String word) async => word == '无为'
      ? const WordEntry(word: '无为', pinyin: 'wú wéi', definition: '顺应事物的自然变化。')
      : null;
}

void main() {
  testWidgets('文言文字典查询离线释义与典籍原文', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [wordRepositoryProvider.overrideWithValue(_Words())],
      child: const MaterialApp(home: ClassicalDictionaryPage()),
    ));

    await tester.tap(find.widgetWithText(ActionChip, '无为'));
    for (var i = 0; i < 60 && find.text('顺应事物的自然变化。').evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('顺应事物的自然变化。'), findsOneWidget);
    expect(find.text('典籍用例'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
    expect(find.text('本机文献中未找到相同字词。'), findsNothing);
  });
}
