import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/learning/favorite_item.dart';
import 'package:wuwei_dictionary/features/learning/word_study_page.dart';

class _WordRepository implements WordSearchRepository {
  static const bank = WordEntry(
    word: '银行',
    pinyin: 'yín háng',
    definition: '金融机构',
  );

  @override
  Future<WordEntry?> findExact(String word) async => word == '银行' ? bank : null;

  @override
  Future<List<WordEntry>> searchText(String query, {int limit = 50}) async =>
      query == '银行' ? [bank] : [];

  @override
  Future<List<WordEntry>> searchPinyin(List<String> readings,
          {int limit = 50}) async =>
      readings.join(' ') == 'yin hang' ? [bank] : [];
}

class _Dictionary implements DictionaryRepository {
  @override
  Future<List<ChineseEntry>> all() async => const [
        ChineseEntry(
          character: '银',
          pinyin: ['yín'],
          radical: '钅',
          strokeCount: 11,
          structure: '左右',
          unicode: 'U+94F6',
          senses: [],
          sourceId: 'test',
        ),
        ChineseEntry(
          character: '行',
          pinyin: ['háng'],
          radical: '行',
          strokeCount: 6,
          structure: '左右',
          unicode: 'U+884C',
          senses: [],
          sourceId: 'test',
        ),
      ];

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async => null;

  @override
  Future<Map<String, String>> primaryPinyinFor(
          Iterable<String> characters) async =>
      {};
}

void main() {
  testWidgets('词语成语学习可文字查询、自定义查询和逐字拼音查找收藏', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        wordRepositoryProvider.overrideWithValue(_WordRepository()),
        dictionaryRepositoryProvider.overrideWithValue(_Dictionary()),
      ],
      child: const MaterialApp(home: WordStudyPage()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('word-study-text')), '自定义词语');
    await tester.tap(find.byTooltip('文字查找'));
    await tester.pumpAndSettle();
    expect(find.text('查询“自定义词语”'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('word-study-pinyin')), 'yin');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'yin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('word-study-pinyin')), 'hang');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'hang'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 字：yin'), findsOneWidget);
    expect(find.text('第 2 字：hang'), findsOneWidget);
    await tester.tap(find.text('按拼音查找'));
    await tester.pumpAndSettle();
    expect(find.text('银行'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('收藏词语'));
    await tester.tap(find.byTooltip('收藏词语'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('取消收藏词语'), findsOneWidget);
    expect(find.text('收藏成功'), findsOneWidget);
    final stored = (await SharedPreferences.getInstance())
        .getStringList(PreferencesKeys.favorites);
    expect(stored,
        contains(const FavoriteItem(FavoriteKind.word, '银行').storageKey));
  });
}
