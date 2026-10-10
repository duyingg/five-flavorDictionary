import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = DailyContentService();
  test('每日偏好内容按日期稳定且不受时分影响', () {
    final date = DateTime(2026, 8, 15, 9);
    for (final type in const [
      DailyContentType.word,
      DailyContentType.idiom,
      DailyContentType.verse,
    ]) {
      expect(
        service.selectIndex(4, date, type, 0),
        service.selectIndex(4, DateTime(2026, 8, 15, 22), type, 0),
      );
    }
  });

  test('词语成语诗句在次日及换一个时不会立即重复', () {
    final date = DateTime(2026, 8, 15);
    for (final type in const [
      DailyContentType.word,
      DailyContentType.idiom,
      DailyContentType.verse,
    ]) {
      final today = service.selectIndex(4, date, type, 0);
      final tomorrow =
          service.selectIndex(4, date.add(const Duration(days: 1)), type, 0);
      final rerolled = service.selectIndex(4, date, type, 1);
      expect(tomorrow, isNot(today), reason: type.name);
      expect(rerolled, isNot(today), reason: type.name);
    }
  });

  test('词语成语诗句连续多天轮换，且换一个不会打乱次日更新', () {
    final start = DateTime(2026, 10, 1);
    for (final type in const [
      DailyContentType.word,
      DailyContentType.idiom,
      DailyContentType.verse,
    ]) {
      for (var offset = 0; offset < 4; offset++) {
        for (var day = 0; day < 20; day++) {
          final date = start.add(Duration(days: day));
          expect(
            service.selectIndex(4, date, type, offset),
            isNot(service.selectIndex(
                4, date.add(const Duration(days: 1)), type, offset)),
            reason: '${type.name} offset=$offset day=$day',
          );
        }
      }
    }
  });

  test('空目录拒绝选择', () {
    expect(
      () => service.selectIndex(0, DateTime(2026), DailyContentType.word, 0),
      throwsRangeError,
    );
  });

  test('词库序列在重复前遍历所有候选', () {
    for (var length = 2; length <= 30; length++) {
      final positions = <int>{
        for (var offset = 0; offset < length; offset++)
          service.selectIndex(
              length, DateTime(2026, 10, 10), DailyContentType.idiom, offset),
      };
      expect(positions.length, length, reason: '$length');
    }
  });

  test('首页每日偏好在真实资源中次日更新', () async {
    for (final type in const [
      DailyContentType.word,
      DailyContentType.idiom,
      DailyContentType.verse,
    ]) {
      Future<String?> titleFor(DateTime day) async {
        SharedPreferences.setMockInitialValues({
          PreferencesKeys.dailyType: type.name,
        });
        final container = ProviderContainer(overrides: [
          currentDayProvider.overrideWithValue(day),
        ]);
        try {
          return (await container.read(dailyContentProvider.future))?.title;
        } finally {
          container.dispose();
        }
      }

      final today = await titleFor(DateTime(2026, 10, 10));
      final tomorrow = await titleFor(DateTime(2026, 10, 11));
      expect(today, isNotNull, reason: type.name);
      expect(tomorrow, isNot(today), reason: type.name);
    }
  });

  test('词语和成语遍历完整词库，译文诗句遍历全部候选', () async {
    final words = await AssetWordRepository().dailyCatalog();
    final verses =
        await AssetDailyContentRepository().getByType(DailyContentType.verse);
    expect(words.count(DailyContentType.word), 302290);
    expect(words.count(DailyContentType.idiom), 48089);
    expect(verses, hasLength(4841));
    for (final type in const [
      DailyContentType.word,
      DailyContentType.idiom,
      DailyContentType.verse,
    ]) {
      final count =
          type == DailyContentType.verse ? verses.length : words.count(type);
      final chosen = <int>{};
      for (var day = 0; day < 30; day++) {
        chosen.add(
            service.selectIndex(count, DateTime(2026, 10, 10 + day), type, 0));
      }
      expect(chosen.length, 30, reason: type.name);
      final cycle = service.selectIndex(count, DateTime(2026, 10, 10), type, 0);
      expect(
          service.selectIndex(count, DateTime(2026, 10, 10 + count), type, 0),
          cycle);
    }
  });

  test('同一应用会话在日期变化后重新选取诗句', () async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.dailyType: DailyContentType.verse.name,
    });
    var day = DateTime(2026, 10, 10);
    final container = ProviderContainer(overrides: [
      currentDayProvider.overrideWith((ref) => day),
    ]);
    addTearDown(container.dispose);
    final first = await container.read(dailyContentProvider.future);
    day = DateTime(2026, 10, 11);
    container.invalidate(currentDayProvider);
    final next = await container.read(dailyContentProvider.future);
    expect(first?.id, isNot(next?.id));
  });

  test('今日汉字遵循简繁体系并保留各字级配额', () async {
    for (final display in ScriptDisplay.values) {
      SharedPreferences.setMockInitialValues({
        PreferencesKeys.scriptDisplay: display.name,
      });
      final container = ProviderContainer(overrides: [
        currentDayProvider.overrideWithValue(DateTime(2026, 10, 10)),
      ]);
      try {
        final selected = await container.read(todayCharactersProvider.future);
        expect(selected, hasLength(10));
        expect(
            selected.where((entry) => entry.characterLevel == 1), hasLength(6));
        expect(
            selected.where((entry) => entry.characterLevel == 2), hasLength(3));
        expect(
            selected.where((entry) => entry.characterLevel == 3), hasLength(1));
        expect(
          selected.every((entry) => display == ScriptDisplay.simplified
              ? entry.script != CharacterScript.traditional
              : entry.script != CharacterScript.simplified),
          isTrue,
        );
      } finally {
        container.dispose();
      }
    }
  });

  test('今日汉字按日期稳定选择一级六个、二级三个、三级一个', () {
    final entries = <ChineseEntry>[
      for (var level = 1; level <= 3; level++)
        for (var index = 0; index < 20; index++)
          ChineseEntry(
            character: String.fromCharCode(0x4e00 + level * 100 + index),
            pinyin: const ['hàn'],
            radical: '一',
            strokeCount: index + 1,
            structure: '独体',
            unicode: 'test-$level-$index',
            senses: const [],
            sourceId: 'test',
            characterLevel: level,
          ),
    ];
    final date = DateTime(2026, 9, 20, 18, 30);
    final first = service.selectCharacters(entries, date);
    final second = service.selectCharacters(entries.reversed.toList(), date);

    expect(first, hasLength(10));
    expect(first.where((entry) => entry.characterLevel == 1), hasLength(6));
    expect(first.where((entry) => entry.characterLevel == 2), hasLength(3));
    expect(first.where((entry) => entry.characterLevel == 3), hasLength(1));
    expect(
      first.map((entry) => entry.character),
      service.selectCharacters(entries, date).map((entry) => entry.character),
    );
    expect(
      first.map((entry) => entry.character).toSet(),
      second.map((entry) => entry.character).toSet(),
    );
    expect(
      first.map((entry) => entry.character),
      isNot(service
          .selectCharacters(entries, date.add(const Duration(days: 1)))
          .map((entry) => entry.character)),
    );
  });
}
