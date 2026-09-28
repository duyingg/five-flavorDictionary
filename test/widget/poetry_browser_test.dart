import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/app_routes.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/culture/culture_pages.dart';
import 'package:wuwei_dictionary/features/data/poetry_binary_codec.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

class _SinglePoetryRepository implements PoetryRepository {
  const _SinglePoetryRepository(this.item);

  final PoetryItem item;

  @override
  Future<PoetryCatalog> catalog({bool fullLibrary = false}) async =>
      _emptyPoetryCatalog();

  @override
  Future<PoetryItem?> getById(String id, {bool fullLibrary = false}) async =>
      id == item.id ? item : null;
}

PoetryCatalog _emptyPoetryCatalog() {
  final bytes = Uint8List(24);
  bytes.setRange(
      0, PoetryBinaryCodec.signature.length, PoetryBinaryCodec.signature);
  // item count, shared-string count, sole record offset and index count are 0.
  return PoetryBinaryCodec.open(ByteData.sublistView(bytes));
}

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 40,
}) async {
  for (var attempt = 0;
      attempt < attempts && finder.evaluate().isEmpty;
      attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(finder, findsWidgets);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
      }));

  testWidgets('标准诗词库搜索无结果时末尾功能条目完整显示并跳转', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: PoetryBrowser()),
      ),
      GoRoute(
        path: AppRoutes.settingsData,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: const Text('数据管理')),
          body: const Text('导入诗词数据'),
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        poetryRepositoryProvider.overrideWithValue(
          const _SinglePoetryRepository(
            PoetryItem(
              id: '',
              title: '',
              author: '',
              dynasty: '',
              form: '',
              style: '',
              theme: '',
              emotion: '',
              content: '',
              shuffleKey: 0,
              sequence: 0,
              searchText: '',
              sourceId: 'test',
            ),
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    await pumpUntilFound(tester, find.byType(TextField));

    await tester.enterText(find.byType(TextField), '绝不存在的诗词检索条件');
    await pumpUntilFound(tester, find.text('没有找到目标诗?'));

    final title = tester.widget<Text>(find.text('没有找到目标诗?'));
    final content = tester.widget<Text>(find.text('试试导入全部诗词库'));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNull);
    expect(content.maxLines, isNull);
    expect(content.overflow, isNull);

    await tester.tap(find.text('没有找到目标诗?'));
    await tester.pumpAndSettle();
    expect(find.text('数据管理'), findsOneWidget);
    expect(find.text('导入诗词数据'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('诗词原文始终显示且注释翻译可以同时开启', (tester) async {
    const item = PoetryItem(
      id: 'poetry-test-1',
      title: '关雎',
      author: '佚名',
      dynasty: '先秦',
      form: '诗',
      style: '其他',
      theme: '爱情闺怨',
      emotion: '其他',
      content: '关关雎鸠，在河之洲。\n窈窕淑女，君子好逑。',
      notes: '雎鸠：一种水鸟。',
      translation: '雎鸠关关和鸣，相伴在河中小洲。',
      appreciation: '',
      shuffleKey: 1,
      sequence: 1,
      searchText: '关雎佚名关关雎鸠',
      sourceId: 'test',
    );
    const converter = HanScriptConverter.empty();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poetryRepositoryProvider.overrideWithValue(
            const _SinglePoetryRepository(item),
          ),
          hanScriptConverterProvider.overrideWith(
            (ref) => Future.value(converter),
          ),
        ],
        child: MaterialApp(home: PoetryDetailPage(id: item.id)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await pumpUntilFound(tester, find.textContaining('关关雎鸠'));

    await tester.tap(find.text('注释'));
    await tester.pump();
    await tester.tap(find.text('翻译'));
    await tester.pump();

    expect(find.textContaining('关关雎鸠'), findsWidgets);
    expect(find.text('注释'), findsWidgets);
    expect(find.text('翻译'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.textContaining('雎鸠'),
      ),
      findsWidgets,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
