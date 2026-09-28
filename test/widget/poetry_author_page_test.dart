import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/app_routes.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/culture/culture_pages.dart';
import 'package:wuwei_dictionary/features/culture/poetry_author_page.dart';
import 'package:wuwei_dictionary/features/data/poetry_binary_codec.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  expect(finder, findsWidgets,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data)
          .join(' | '));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
      }));

  testWidgets('诗词详情的作者按钮进入带简介和作品的作者页', (tester) async {
    final repository = AssetPoetryRepository();
    final catalog = await repository.catalog();
    final selection = catalog.select(const PoetryQuery(author: '李白'));
    expect(selection.length, greaterThan(0));
    final poem = selection.itemAt(0);
    final router = GoRouter(
      initialLocation: AppRoutes.poetryDetail(poem.id),
      routes: [
        GoRoute(
          path: AppRoutes.poetryDetailPattern,
          builder: (_, state) =>
              PoetryDetailPage(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: AppRoutes.poetryAuthorPattern,
          builder: (_, state) => PoetryAuthorPage(
            author: state.pathParameters['author']!,
            dynasty: state.pathParameters['dynasty']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        poetryRepositoryProvider.overrideWithValue(repository),
        hanScriptConverterProvider.overrideWith(
            (ref) => Future.value(const HanScriptConverter.empty())),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await pumpUntilFound(tester, find.text('李白'));

    await tester.tap(find.text('李白'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await pumpUntilFound(tester, find.text('人物简介'));

    expect(find.textContaining('盛唐诗人'), findsOneWidget);
    expect(find.textContaining('本库作品 ·'), findsOneWidget);
    expect(find.byType(PoetryAuthorPage), findsOneWidget);
  });

  testWidgets('诗词列表的作者按钮独立于作品卡片', (tester) async {
    final repository = AssetPoetryRepository();
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: PoetryBrowser())),
      GoRoute(
        path: AppRoutes.poetryDetailPattern,
        builder: (_, state) =>
            PoetryDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.poetryAuthorPattern,
        builder: (_, state) => PoetryAuthorPage(
          author: state.pathParameters['author']!,
          dynasty: state.pathParameters['dynasty']!,
        ),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        poetryRepositoryProvider.overrideWithValue(repository),
        hanScriptConverterProvider.overrideWith(
            (ref) => Future.value(const HanScriptConverter.empty())),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await pumpUntilFound(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), '李白');
    await pumpUntilFound(tester, find.widgetWithText(TextButton, '李白'));
    expect(find.text('有注释'), findsNothing);
    expect(find.text('有翻译'), findsNothing);
    expect(find.text('有赏析'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, '李白').first);
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)));
    await pumpUntilFound(tester, find.text('人物简介'));
    expect(find.byType(PoetryAuthorPage), findsOneWidget);
  });
}
