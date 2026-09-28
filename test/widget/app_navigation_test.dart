import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/app/app.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/core/privacy/privacy_policy.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/dictionary/dictionary_pages.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/index_search/index_search_page.dart';
import 'package:wuwei_dictionary/features/learning/learning_pages.dart';
import 'package:wuwei_dictionary/features/profile/profile_pages.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 30,
}) async {
  for (var attempt = 0;
      attempt < attempts && finder.evaluate().isEmpty;
      attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(finder, findsWidgets);
}

class _IndexTestRepository implements DictionaryRepository {
  final entries = List.generate(300, (index) {
    const initials = [
      'b',
      'p',
      'm',
      'f',
      'd',
      't',
      'n',
      'l',
      'g',
      'k',
      'h',
      'j',
      'q',
      'x',
      'r',
      'z',
      'c',
      's',
      'y',
      'w',
    ];
    const finals = [
      'a',
      'o',
      'e',
      'ai',
      'ei',
      'ao',
      'ou',
      'an',
      'en',
      'ang',
      'eng',
      'i',
      'ia',
      'ie',
      'iao',
    ];
    final character = String.fromCharCode(0x4e00 + index);
    return ChineseEntry(
      character: character,
      pinyin: [
        '${initials[index % initials.length]}${finals[index ~/ initials.length]}',
      ],
      radical: character,
      strokeCount: index + 1,
      structure: '独体',
      unicode: 'test-$index',
      senses: const [],
      sourceId: 'test',
    );
  });

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

class _CharacterTestRepository extends _IndexTestRepository {
  _CharacterTestRepository(this.entry);
  final ChineseEntry entry;

  @override
  Future<List<ChineseEntry>> all() async => [entry];

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async =>
      character == entry.character ? entry : null;
}

class _HomeWordDictionaryRepository implements DictionaryRepository {
  static const entries = [
    ChineseEntry(
      character: '苹',
      pinyin: ['píng'],
      radical: '艹',
      strokeCount: 8,
      structure: '上下',
      unicode: 'test-苹',
      senses: [],
      sourceId: 'test',
    ),
    ChineseEntry(
      character: '果',
      pinyin: ['guǒ'],
      radical: '木',
      strokeCount: 8,
      structure: '独体',
      unicode: 'test-果',
      senses: [],
      sourceId: 'test',
    ),
  ];

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

class _HomeWordRepository implements WordRepository {
  @override
  Future<WordEntry?> findExact(String word) async => word == '苹果'
      ? const WordEntry(
          word: '苹果',
          pinyin: 'píng guǒ',
          definition: '苹果树的果实。',
        )
      : null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
        PrivacyPolicy.acceptedKey: true,
      }));

  testWidgets('首次启动显示隐私提示且确认后记录同意状态', (tester) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
    });
    await tester.pumpWidget(const ProviderScope(child: DictionaryApp()));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('隐私政策提示'), findsOneWidget);
    expect(find.text('不同意并退出'), findsOneWidget);
    expect(find.text('查看完整政策'), findsOneWidget);
    await tester.tap(find.text('同意并继续'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('隐私政策提示'), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(PrivacyPolicy.acceptedKey), isTrue);
  });

  testWidgets('底部四页可切换并显示无内购声明', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DictionaryApp()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('五味字典'), findsOneWidget);
    expect(find.text('龘'), findsOneWidget);
    await tester.tap(find.text('学习').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('今日汉字'), findsOneWidget);
    await tester.tap(find.text('文化').last);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('诸子百家'), findsOneWidget);
    await tester.tap(find.text('我的').last);
    await tester.pumpAndSettle();
    expect(find.text('本产品无内购、无会员'), findsOneWidget);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('汉字查询偏好'));
    await tester.pumpAndSettle();
    expect(find.text('汉字查询偏好'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('全局点击查字'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('全局点击查字'), findsOneWidget);
    expect(
      find.text('开启后可点击正文汉字快速查询；设置页默认加入白名单，在此页点击汉字不会触发查询'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('侧边栏宽度'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('侧边栏宽度'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('首页支持词语查询并进入词语详情', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _HomeWordDictionaryRepository(),
          ),
          wordRepositoryProvider.overrideWithValue(_HomeWordRepository()),
        ],
        child: const DictionaryApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('首页').last);
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const Key('home-search')), '苹果');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntilFound(tester, find.text('词语释义'));
    expect(find.text('词语详情'), findsOneWidget);
    expect(find.text('词语释义'), findsOneWidget);
    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();
    expect(find.text('五味字典'), findsOneWidget);
  });

  testWidgets('拼音索引切换简繁后保持滚动位置', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _IndexTestRepository(),
          ),
        ],
        child: const MaterialApp(
          home: IndexSearchPage(type: IndexSearchType.pinyin),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.byType(Scrollbar));

    final mainScrollbar = find.byType(Scrollbar);
    expect(mainScrollbar, findsOneWidget);
    final mainScrollable = find.descendant(
      of: mainScrollbar,
      matching: find.byType(Scrollable),
    );
    await tester.drag(mainScrollable, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    final before =
        tester.state<ScrollableState>(mainScrollable).position.pixels;
    expect(before, greaterThan(100));

    await tester.tap(find.text('繁'));
    await tester.pump(const Duration(seconds: 1));
    final after = tester.state<ScrollableState>(mainScrollable).position.pixels;
    expect(after, greaterThan(50));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('部首侧边栏可跳到尚未渲染的远处分组', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _IndexTestRepository(),
          ),
        ],
        child: const MaterialApp(
          home: IndexSearchPage(type: IndexSearchType.radical),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('8画'));

    await tester.tap(find.text('8画'));
    await tester.pumpAndSettle();

    final mainScrollable = find.descendant(
      of: find.byType(Scrollbar),
      matching: find.byType(Scrollable),
    );
    expect(
      tester.state<ScrollableState>(mainScrollable).position.pixels,
      greaterThan(100),
    );
    expect(find.text('8 画部首'), findsOneWidget);
  });

  testWidgets('汉字详情只标注不同的对应字形', (tester) async {
    const entry = ChineseEntry(
      character: '汉',
      pinyin: ['hàn'],
      radical: '氵',
      strokeCount: 5,
      structure: '左右',
      unicode: 'U+6C49',
      senses: [],
      sourceId: 'test',
      script: CharacterScript.simplified,
      traditionalForms: ['漢'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _CharacterTestRepository(entry),
          ),
        ],
        child: const MaterialApp(home: CharacterDetailPage(value: '汉')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('繁体字：漢', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('简体字：汉', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('简繁同形', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('汉字详情对同形字标注简繁同形', (tester) async {
    const entry = ChineseEntry(
      character: '中',
      pinyin: ['zhōng'],
      radical: '丨',
      strokeCount: 4,
      structure: '独体',
      unicode: 'U+4E2D',
      senses: [],
      sourceId: 'test',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _CharacterTestRepository(entry),
          ),
        ],
        child: const MaterialApp(home: CharacterDetailPage(value: '中')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('简繁同形', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('简体字：', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('繁体字：', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('320×568 小屏首页不溢出且我的保持竖排', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ProviderScope(child: DictionaryApp()));
    await pumpUntilFound(tester, find.text('我的'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('我的').last);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ListTile), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('反馈与建议'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('反馈与建议'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('反馈页展示问卷二维码和可复制链接且不显示邮箱', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: InformationPage(kind: 'feedback')),
    );
    await tester.pumpAndSettle();

    expect(find.text('https://v.wjx.cn/vm/wk2BGhD.aspx#'), findsOneWidget);
    expect(find.bySemanticsLabel('五味字典使用反馈问卷二维码'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);

    final linkTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('点击复制问卷链接'),
        matching: find.byType(ListTile),
      ),
    );
    expect(linkTile.onTap, isNotNull);
  });

  testWidgets('多音字学习提供闯关和无尽入口', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PolyphonicLearningPage()),
      ),
    );
    await tester.pump();
    expect(find.text('当前第 1 关'), findsOneWidget);
    expect(find.text('当前第 1 轮'), findsOneWidget);
    await tester.tap(find.text('闯关'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 关'), findsOneWidget);
    for (final finder in [
      find.widgetWithText(ChoiceChip, 'x'),
      find.widgetWithText(ChoiceChip, 'ing'),
      find.widgetWithText(ChoiceChip, '2 声'),
      find.text('确认答案'),
    ]) {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('本音达成'), findsOneWidget);
    expect(find.text('行走'), findsWidgets);
    expect(find.textContaining('走路'), findsOneWidget);
  });
}
