import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/features/data/preferences_store.dart';
import 'package:wuwei_dictionary/features/profile/profile_pages.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
      }));

  testWidgets('诗词库页面直接显示当前库和两个可切换库', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsPage(kind: 'data')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('当前诗词库'), findsOneWidget);
    expect(find.text('可切换诗词库'), findsOneWidget);
    await tester.tap(find.widgetWithText(RadioListTile<bool>, '全部唐诗宋词'));
    await tester.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getBool(PreferencesKeys.fullPoetryLibrary),
        isTrue);
  });

  testWidgets('关闭历史记录后隐藏我的页面中的查询历史入口', (tester) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
      PreferencesKeys.keepHistory: false,
    });
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: ProfilePage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('查询历史'), findsNothing);
    expect(find.text('关于我们'), findsOneWidget);
    expect(find.text('每日内容偏好'), findsNothing);
  });

  testWidgets('每日内容偏好和左手模式位于设置中', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SettingsPage(kind: 'general')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('每日内容偏好'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('左手模式'), 300,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('左手模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('左手模式'));
    await tester.pumpAndSettle();
    expect(
        (await SharedPreferences.getInstance())
            .getBool(PreferencesKeys.leftHanded),
        isTrue);
    expect(find.textContaining('清空首页搜索框后自动打开键盘'), findsOneWidget);
  });
}
