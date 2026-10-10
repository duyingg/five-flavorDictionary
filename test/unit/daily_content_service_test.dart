import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = DailyContentService();
  final items = List.generate(
    4,
    (index) => DailyContent(
      id: '$index',
      type: DailyContentType.character,
      title: '$index',
      summary: 'summary',
      sourceId: 'app-original',
    ),
  );

  test('每日偏好内容按日期稳定且不受资源原始顺序影响', () {
    final date = DateTime(2026, 8, 15, 9);
    for (final type in const [
      DailyContentType.word,
      DailyContentType.idiom,
      DailyContentType.verse,
    ]) {
      expect(
        service.select(items, date, type, 0)?.id,
        service.select(items.reversed.toList(), date, type, 0)?.id,
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
      final today = service.select(items, date, type, 0);
      final tomorrow = service.select(
        items,
        date.add(const Duration(days: 1)),
        type,
        0,
      );
      final rerolled = service.select(items, date, type, 1);
      expect(tomorrow?.id, isNot(today?.id), reason: type.name);
      expect(rerolled?.id, isNot(today?.id), reason: type.name);
    }
  });

  test('词语成语诗句连续多天轮换，且换一个不会打乱次日更新', () {
    final start = DateTime(2026, 10, 1);
    for (final type in const [
      DailyContentType.word,
      DailyContentType.idiom,
      DailyContentType.verse,
    ]) {
      for (var offset = 0; offset < items.length; offset++) {
        for (var day = 0; day < 20; day++) {
          final date = start.add(Duration(days: day));
          expect(
            service.select(items, date, type, offset)?.id,
            isNot(service
                .select(items, date.add(const Duration(days: 1)), type, offset)
                ?.id),
            reason: '${type.name} offset=$offset day=$day',
          );
        }
      }
    }
  });

  test('空列表返回 null', () {
    expect(
        service.select([], DateTime(2026), DailyContentType.word, 0), isNull);
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
