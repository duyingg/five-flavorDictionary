import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/content_repositories.dart';
import 'package:wuwei_dictionary/features/data/preferences_store.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/home/home_page.dart';
import 'package:wuwei_dictionary/features/profile/profile_pages.dart';

class _DailyRepository implements DailyContentRepository {
  @override
  Future<List<DailyContent>> getByType(DailyContentType type) async => [
        DailyContent(
          id: type.name,
          type: type,
          title: type == DailyContentType.verse ? '今日诗句' : '今日词语',
          summary: '今日内容',
          sourceId: 'test',
        ),
      ];
}

void main() {
  testWidgets('首页可直接切换每日内容类型并保存偏好', (tester) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
      PreferencesKeys.keepHistory: false,
      PreferencesKeys.dailyType: DailyContentType.word.name,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyContentRepositoryProvider.overrideWithValue(_DailyRepository()),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('每日词语'), findsOneWidget);

    await tester.tap(find.text('每日词语'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每日诗句').last);
    await tester.pumpAndSettle();

    expect(find.text('每日诗句'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance())
          .getString(PreferencesKeys.dailyType),
      DailyContentType.verse.name,
    );
  });

  testWidgets('查询历史顶部按钮确认后清空全部记录', (tester) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
      PreferencesKeys.searchHistory: ['天地', '玄黄'],
    });
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SearchHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('天地'), findsOneWidget);
    expect(find.text('刚刚查询过'), findsOneWidget);
    expect(find.textContaining('最近优先'), findsNothing);

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(find.text('清空全部查询历史？'), findsOneWidget);
    await tester.tap(find.text('清空').last);
    await tester.pumpAndSettle();

    expect(find.text('暂无查询历史'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance())
          .getStringList(PreferencesKeys.searchHistory),
      isEmpty,
    );
  });
}
