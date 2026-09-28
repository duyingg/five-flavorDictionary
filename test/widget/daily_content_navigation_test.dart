import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/app_routes.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/core/widgets/global_han_lookup.dart';
import 'package:wuwei_dictionary/features/culture/culture_pages.dart';
import 'package:wuwei_dictionary/features/data/content_repositories.dart';
import 'package:wuwei_dictionary/features/data/preferences_store.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/home/home_page.dart';

class _CultureTestRepository implements CultureRepository {
  const _CultureTestRepository(this.item);

  final CultureItem item;

  @override
  Future<List<CultureItem>> getByCategory(CultureCategory category) async =>
      [item];

  @override
  Future<CultureItem?> getById(String id) async => id == item.id ? item : null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
        PreferencesKeys.keepHistory: false,
      }));

  testWidgets('每日词语整体点击进入词语查询且不触发单字查询', (tester) async {
    const item = DailyContent(
      id: 'word-test',
      type: DailyContentType.word,
      title: '澄澈',
      summary: '清澈透明。',
      sourceId: 'test',
    );
    String? selectedCharacter;
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: HomePage()),
        ),
        GoRoute(
          path: AppRoutes.wordPattern,
          builder: (_, state) => Scaffold(
            body: Text('词语目标：${state.pathParameters['value']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dailyContentProvider.overrideWith((ref) async => item)],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => GlobalHanLookupRegion(
            enabled: true,
            onCharacter: (value) => selectedCharacter = value,
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('澄澈'));
    await tester.pumpAndSettle();

    expect(find.text('词语目标：澄澈'), findsOneWidget);
    expect(selectedCharacter, isNull);
  });

  testWidgets('每日诗句整体点击进入匹配的原诗页面', (tester) async {
    const item = DailyContent(
      id: 'verse-test',
      type: DailyContentType.verse,
      title: '欲穷千里目，更上一层楼。',
      summary: '登高望远。',
      sourceId: 'test',
      author: '王之涣',
      sourceTitle: '登鹳雀楼',
    );
    const poem = PoetryItem(
      id: 'poetry-test-1',
      title: '登鹳雀楼',
      author: '王之涣',
      dynasty: '唐',
      form: '五绝',
      style: '',
      theme: '',
      emotion: '',
      content: '白日依山尽，黄河入海流。\n欲穷千里目，更上一层楼。',
      shuffleKey: 1,
      sequence: 1,
      searchText: '登鹳雀楼王之涣欲穷千里目，更上一层楼。',
      sourceId: 'test',
    );
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: HomePage()),
        ),
        GoRoute(
          path: AppRoutes.poetryDetailPattern,
          builder: (_, state) => Scaffold(
            body: Text('原诗目标：${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyContentProvider.overrideWith((ref) async => item),
          dailyPoetryTargetProvider(item).overrideWith((ref) async => poem),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('欲穷千里目，'));
    await tester.pumpAndSettle();

    expect(find.text('原诗目标：poetry-test-1'), findsOneWidget);
  });

  testWidgets('二十四节气条目是按钮并进入对应节气作用页面', (tester) async {
    const solarTerms = CultureItem(
      id: 'other-solar',
      category: CultureCategory.other,
      title: '二十四节气',
      subtitle: '传统历法',
      summary: '节气测试数据',
      content: '立春|春季开始|万物复苏',
      sourceId: 'test',
    );
    final router = GoRouter(
      initialLocation: AppRoutes.cultureDetail('other-solar'),
      routes: [
        GoRoute(
          path: AppRoutes.cultureDetailPattern,
          builder: (_, state) =>
              CultureDetailPage(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.solarTermPattern,
          builder: (_, state) =>
              SolarTermDetailPage(name: state.pathParameters['name']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cultureRepositoryProvider.overrideWithValue(
            const _CultureTestRepository(solarTerms),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('solar-term-立春'));
    expect(button, findsOneWidget);
    expect(tester.widget(button), isA<OutlinedButton>());
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('代表含义'), findsOneWidget);
    expect(find.text('节气作用'), findsOneWidget);
    expect(find.textContaining('春耕准备'), findsOneWidget);
  });

  testWidgets('长篇古籍按自然段紧跟显示翻译', (tester) async {
    const item = CultureItem(
      id: 'classic-test',
      category: CultureCategory.schools,
      title: '测试古籍',
      subtitle: '逐段翻译',
      summary: '',
      content: '原文一\n\n原文二',
      translation: '译文一\n\n译文二',
      passages: [
        CulturePassage(
          heading: '第一章',
          original: '原文一',
          translation: '译文一',
        ),
        CulturePassage(original: '原文二', translation: '译文二'),
      ],
      sourceId: 'test',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cultureRepositoryProvider.overrideWithValue(
            const _CultureTestRepository(item),
          ),
        ],
        child: const MaterialApp(home: CultureDetailPage(id: 'classic-test')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('原文一'), findsOneWidget);
    expect(find.text('原文二'), findsOneWidget);
    expect(find.text('译文一'), findsNothing);

    await tester.tap(find.text('翻译'));
    await tester.pump();
    expect(find.text('译文一'), findsOneWidget);
    expect(find.text('译文二'), findsOneWidget);
  });
}
