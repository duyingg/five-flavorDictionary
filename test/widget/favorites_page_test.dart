import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/poetry_binary_codec.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/learning/favorite_item.dart';
import 'package:wuwei_dictionary/features/learning/learning_pages.dart';

class _PoetryRepository implements PoetryRepository {
  @override
  Future<PoetryCatalog> catalog({bool fullLibrary = false}) =>
      throw UnimplementedError();

  @override
  Future<PoetryItem?> getById(String id, {bool fullLibrary = false}) async =>
      PoetryItem(
        id: id,
        title: '测试古诗',
        author: '作者',
        dynasty: '唐',
        form: '绝句',
        style: '',
        theme: '',
        emotion: '',
        content: '正文',
        shuffleKey: 0,
        sequence: 0,
        searchText: '',
        sourceId: 'test',
      );
}

void main() {
  testWidgets('收藏页同时展示旧汉字、词语和古诗', (tester) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.favorites: [
        '汉',
        const FavoriteItem(FavoriteKind.word, '自定义词语').storageKey,
        const FavoriteItem(FavoriteKind.word, '海阔天空').storageKey,
        const FavoriteItem(FavoriteKind.poetry, 'poetry-test').storageKey,
      ],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        poetryRepositoryProvider.overrideWithValue(_PoetryRepository()),
      ],
      child: const MaterialApp(home: FavoritesPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('汉'), findsWidgets);
    expect(find.text('自定义词语'), findsOneWidget);
    expect(find.text('海阔天空'), findsOneWidget);
    expect(find.text('测试古诗'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '词语'));
    await tester.pumpAndSettle();
    expect(find.text('自定义词语'), findsOneWidget);
    expect(find.text('海阔天空'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '成语'));
    await tester.pumpAndSettle();
    expect(find.text('海阔天空'), findsOneWidget);
    expect(find.text('自定义词语'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '古诗'));
    await tester.pumpAndSettle();
    expect(find.text('测试古诗'), findsOneWidget);
    expect(find.text('海阔天空'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '汉字'));
    await tester.pumpAndSettle();
    expect(find.text('汉'), findsWidgets);
    expect(find.text('测试古诗'), findsNothing);

    await tester.tap(find.byTooltip('取消收藏'));
    await tester.pump();
    expect(find.text('已取消收藏'), findsOneWidget);
    expect(find.text('此类暂无收藏'), findsOneWidget);
  });
}
