import 'dart:math';

import '../domain/models.dart';

class DailyContentService {
  const DailyContentService();

  int stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash;
  }

  int _dailySeed(DateTime date, String namespace) => stableHash(
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}|$namespace',
      );

  DailyContent? select(List<DailyContent> items, DateTime date,
      DailyContentType type, int offset) {
    if (items.isEmpty) return null;
    final dailyOrder = [...items]
      ..sort((left, right) => left.id.compareTo(right.id))
      ..shuffle(Random(_dailySeed(date, 'daily-content-${type.name}')));
    return dailyOrder[offset % dailyOrder.length];
  }

  List<ChineseEntry> selectCharacters(
    List<ChineseEntry> entries,
    DateTime date,
  ) {
    final random = Random(_dailySeed(date, 'daily-characters'));
    final byLevel = <int, List<ChineseEntry>>{
      1: <ChineseEntry>[],
      2: <ChineseEntry>[],
      3: <ChineseEntry>[],
    };
    for (final entry in entries) {
      if (entry.pinyin.isNotEmpty) byLevel[entry.characterLevel]?.add(entry);
    }

    final result = <ChineseEntry>[];
    for (final requirement in const [(1, 6), (2, 3), (3, 1)]) {
      final pool = [...byLevel[requirement.$1]!]
        ..sort((left, right) => left.character.compareTo(right.character));
      pool.shuffle(random);
      result.addAll(pool.take(requirement.$2));
    }
    result.shuffle(random);
    return result;
  }
}
