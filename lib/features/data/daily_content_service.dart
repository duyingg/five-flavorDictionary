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

  /// Selects up to ten catalog entries for the day, then cycles within that
  /// fixed set. Consecutive days walk a stable permutation of the full library
  /// without allocating or shuffling the full catalog.
  int selectIndex(
      int length, DateTime date, DailyContentType type, int offset) {
    if (length <= 0) throw RangeError.value(length, 'length');
    if (length == 1) return 0;
    final dailySize = min(10, length);
    final dayNumber = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(1970))
        .inDays;
    final start = stableHash('daily-start-${type.name}') % length;
    var step = stableHash('daily-step-${type.name}') % length;
    if (step == 0) step = 1;
    while (_greatestCommonDivisor(step, length) != 1) {
      step = step == length - 1 ? 1 : step + 1;
    }
    final dayStride = length > dailySize ? dailySize : 1;
    final dailyPosition = (dayNumber * dayStride + offset % dailySize) % length;
    return (start + dailyPosition * step) % length;
  }

  int _greatestCommonDivisor(int left, int right) {
    while (right != 0) {
      final remainder = left % right;
      left = right;
      right = remainder;
    }
    return left;
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
