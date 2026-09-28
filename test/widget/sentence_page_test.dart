import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/app_routes.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/dictionary/dictionary_pages.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/learning/learning_pages.dart';

ChineseEntry _entry(String character, int level) => ChineseEntry(
      character: character,
      pinyin: const ['hàn'],
      radical: '一',
      strokeCount: 1,
      structure: '独体',
      unicode: 'test-$character',
      senses: const [],
      sourceId: 'test',
      characterLevel: level,
    );

class _SingleEntryRepository implements DictionaryRepository {
  _SingleEntryRepository(this.entry);

  final ChineseEntry entry;

  @override
  Future<List<ChineseEntry>> all() async => [entry];

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async =>
      character == entry.character ? entry : null;

  @override
  Future<Map<String, String>> primaryPinyinFor(
    Iterable<String> characters,
  ) async =>
      {for (final character in characters) character: 'hàn'};
}

void main() {
  final today = [
    for (final character in ['学', '习', '天', '地', '人', '和'])
      _entry(character, 1),
    _entry('难', 2),
    _entry('僻', 2),
    _entry('雅', 2),
    _entry('龘', 3),
  ];

  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
      }));

  testWidgets('造句只使用今日六个一级字并可批量删除便签', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayCharactersProvider.overrideWith((ref) async => today),
        ],
        child: const MaterialApp(home: SentencePage()),
      ),
    );
    await tester.pumpAndSettle();

    for (final character in ['学', '习', '天', '地', '人', '和']) {
      expect(find.text(character), findsOneWidget);
    }
    expect(find.text('难'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('sentence-editor')),
      '我们每天认真学习。',
    );
    await tester.tap(find.text('保存便签'));
    await tester.pumpAndSettle();
    expect(find.text('我们每天认真学习。'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^\d{4}年\d{2}月\d{2}日 \d{2}:\d{2}$')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('sentence-editor')),
      '学习使人进步。',
    );
    await tester.tap(find.text('保存便签'));
    await tester.pumpAndSettle();
    expect(find.text('学习使人进步。'), findsOneWidget);

    await tester.tap(find.byTooltip('批量管理'));
    await tester.pump();
    await tester.tap(find.byTooltip('全选'));
    await tester.pump();
    expect(find.text('已选择 2 项'), findsOneWidget);
    await tester.tap(find.byTooltip('删除所选'));
    await tester.pumpAndSettle();
    expect(find.text('将删除选中的 2 条记录，此操作无法撤销。'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('我们每天认真学习。'), findsNothing);
    expect(find.text('学习使人进步。'), findsNothing);
    expect(find.text('还没有造句'), findsOneWidget);
  });

  testWidgets('汉字详情首页按钮清空已有导航栈', (tester) async {
    final entry = _entry('汉', 1);
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/middle',
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('首页目标')),
        ),
        GoRoute(
          path: '/middle',
          builder: (context, __) => Scaffold(
            body: FilledButton(
              onPressed: () => context.push(AppRoutes.character('汉')),
              child: const Text('打开汉字'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.characterPattern,
          builder: (_, state) =>
              CharacterDetailPage(value: state.pathParameters['value']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _SingleEntryRepository(entry),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开汉字'));
    await tester.pumpAndSettle();
    expect(find.text('汉字详情'), findsOneWidget);

    await tester.tap(find.byTooltip('返回首页'));
    await tester.pumpAndSettle();

    expect(find.text('首页目标'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
