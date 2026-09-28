import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/preferences_store.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/home/home_page.dart';

void main() {
  testWidgets('每日诗句按标点结束完整分句且分句内部不换行', (tester) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
      PreferencesKeys.dailyType: DailyContentType.verse.name,
      PreferencesKeys.keepHistory: false,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyContentProvider.overrideWith(
            (ref) async => const DailyContent(
              id: 'verse-test',
              type: DailyContentType.verse,
              title: '白日依山尽，黄河入海流。',
              summary: '登高望远。',
              sourceId: 'test',
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('白日依山尽，'), findsOneWidget);
    expect(find.text('黄河入海流。'), findsOneWidget);
    for (var index = 0; index < 2; index++) {
      final text = tester.widget<Text>(
        find.byKey(ValueKey('daily-verse-line-$index')),
      );
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    }
  });
}
