import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/app.dart';
import 'package:wuwei_dictionary/app/app_routes.dart';
import 'package:wuwei_dictionary/app/router.dart';
import 'package:wuwei_dictionary/core/privacy/privacy_policy.dart';
import 'package:wuwei_dictionary/features/data/preferences_store.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/profile/profile_pages.dart';

void main() {
  setUp(() => appRouter.go(AppRoutes.home));

  testWidgets(
      '150% setting scales text with explicit font sizes throughout the app',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
      PreferencesKeys.fontScale: AppFontScale.veryLarge.name,
      PrivacyPolicy.acceptedKey: true,
    });

    await tester.pumpWidget(const ProviderScope(child: DictionaryApp()));
    await tester.pump(const Duration(seconds: 1));

    final homeText = find.text('五味字典').first;
    expect(MediaQuery.textScalerOf(tester.element(homeText)).scale(12), 18);
    expect(Theme.of(tester.element(homeText)).textTheme.bodyMedium!.fontSize,
        lessThan(20));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('我的').last);
    await tester.pump(const Duration(seconds: 1));
    final profileText = find.text('本产品无内购、无会员');
    expect(MediaQuery.textScalerOf(tester.element(profileText)).scale(12), 18);
    final profile = find.byType(ProfilePage);
    expect(find.descendant(of: profile, matching: find.byType(Card)),
        findsOneWidget);
    final menuTiles = tester.widgetList<ListTile>(
      find.descendant(of: profile, matching: find.byType(ListTile)),
    );
    expect(menuTiles.length, 7);
    expect(menuTiles.every((tile) => tile.subtitle == null), isTrue);
    expect(find.text('功能与数据'), findsNothing);
    expect(find.text('帮助与支持'), findsNothing);
    expect(AppFontScale.values.last.label, '特大');
    expect(AppFontScale.values.last.factor, 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '150% font scale does not overflow narrow home and profile screens',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
      PreferencesKeys.fontScale: AppFontScale.veryLarge.name,
      PrivacyPolicy.acceptedKey: true,
    });

    await tester.pumpWidget(const ProviderScope(child: DictionaryApp()));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('我的').last);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
