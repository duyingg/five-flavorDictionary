import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/dictionary/word_detail_page.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

ChineseEntry _entry(
  String character,
  List<String> pinyin,
  String definition,
) =>
    ChineseEntry(
      character: character,
      pinyin: pinyin,
      radical: '一',
      strokeCount: 1,
      structure: '独体',
      unicode: 'test-$character',
      senses: [
        ChineseSense(definition: definition, examples: const []),
      ],
      sourceId: 'test',
    );

class _WordTestDictionary implements DictionaryRepository {
  _WordTestDictionary(this.entries);

  final List<ChineseEntry> entries;

  @override
  Future<List<ChineseEntry>> all() async => entries;

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async =>
      entries.where((entry) => entry.character == character).firstOrNull;

  @override
  Future<Map<String, String>> primaryPinyinFor(
    Iterable<String> characters,
  ) async =>
      {
        for (final character in characters)
          character: entries
                  .where((entry) => entry.character == character)
                  .firstOrNull
                  ?.pinyin
                  .firstOrNull ??
              '',
      };
}

class _WordTestRepository implements WordRepository {
  const _WordTestRepository(this.entry);

  final WordEntry? entry;

  @override
  Future<WordEntry?> findExact(String word) async =>
      entry?.word == word ? entry : null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
      }));

  testWidgets('已收录词语逐字标注词语级读音并展示整体及单字释义', (tester) async {
    final entries = [
      _entry('银', const ['yín'], '一种白色金属。'),
      _entry('行', const ['xíng', 'háng', 'hàng'], '行走或行业。'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _WordTestDictionary(entries),
          ),
          wordRepositoryProvider.overrideWithValue(
            const _WordTestRepository(
              WordEntry(
                word: '银行',
                pinyin: 'yín háng',
                definition: '经营存款、贷款等业务的金融机构。',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: WordDetailPage(value: '银行')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('yín'), findsWidgets);
    expect(find.text('háng'), findsOneWidget);
    expect(find.text('经营存款、贷款等业务的金融机构。'), findsOneWidget);
    expect(find.textContaining('一种白色金属'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('行走或行业'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('行走或行业'), findsOneWidget);
  });

  testWidgets('未收录词语为多音字显示前两个读音', (tester) async {
    final entries = [
      _entry('重', const ['zhòng', 'chóng', 'tóng'], '分量大。'),
      _entry('行', const ['xíng', 'háng', 'hàng'], '行走或行业。'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _WordTestDictionary(entries),
          ),
          wordRepositoryProvider.overrideWithValue(
            const _WordTestRepository(null),
          ),
        ],
        child: const MaterialApp(home: WordDetailPage(value: '重行')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('zhòng / chóng'), findsOneWidget);
    expect(find.text('xíng / háng'), findsOneWidget);
    expect(find.textContaining('当前词语库尚未收录'), findsOneWidget);
    expect(find.text('zhòng / chóng / tóng'), findsNothing);
    expect(find.text('xíng / háng / hàng'), findsNothing);
  });

  testWidgets('目标词语每行固定显示四个字', (tester) async {
    final entries = [
      _entry('春', const ['chūn'], '春季。'),
      _entry('夏', const ['xià'], '夏季。'),
      _entry('秋', const ['qiū'], '秋季。'),
      _entry('冬', const ['dōng'], '冬季。'),
      _entry('风', const ['fēng'], '空气流动。'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _WordTestDictionary(entries),
          ),
          wordRepositoryProvider.overrideWithValue(
            const _WordTestRepository(null),
          ),
        ],
        child: const MaterialApp(home: WordDetailPage(value: '春夏秋冬风')),
      ),
    );
    await tester.pumpAndSettle();

    final positions = [
      for (var index = 0; index < 5; index++)
        tester
            .getTopLeft(find.byKey(ValueKey('word-heading-character-$index'))),
    ];
    expect(positions.take(4).map((point) => point.dy).toSet(), hasLength(1));
    expect(positions[4].dy, greaterThan(positions[3].dy));
  });
}
