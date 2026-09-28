import '../../core/language/pinyin_utils.dart';
import '../domain/character_visibility.dart';
import '../domain/models.dart';

class IndexCatalog {
  IndexCatalog(List<ChineseEntry> source,
      {this.display = ScriptDisplay.simplified, this.maxLevel = 3})
      : entries = List.unmodifiable(source.where(
          (entry) => entry.isVisibleFor(
            display: display,
            maxLevel: maxLevel,
          ),
        )),
        _byCharacter = {for (final entry in source) entry.character: entry};

  final List<ChineseEntry> entries;
  final ScriptDisplay display;
  final int maxLevel;
  final Map<String, ChineseEntry> _byCharacter;
  late final Map<String, _SyllableIndex> _syllableIndexes =
      _buildSyllableIndexes();
  late final Map<String, Map<int, List<ChineseEntry>>> _entriesByRadical =
      _buildEntriesByRadical();
  late final Map<int, List<ChineseEntry>> _entriesByStroke =
      _buildEntriesByStroke();

  late final Map<String, List<String>> pronunciationsByInitial =
      _buildPronunciationsByInitial();

  Map<String, List<String>> _buildPronunciationsByInitial() {
    final groups = <String, Set<String>>{};
    for (final syllable in _syllableIndexes.keys) {
      final section = PinyinUtils.sectionOf(syllable);
      if (section.isNotEmpty) {
        groups.putIfAbsent(section, () => {}).add(syllable);
      }
    }
    return {
      for (final initial in PinyinUtils.pinyinSections)
        if (groups[initial]?.isNotEmpty ?? false)
          initial: _sortReadings(groups[initial]!),
    };
  }

  late final Map<String, List<String>> pronunciationsByFinal =
      _buildPronunciationsByFinal();

  Map<String, List<String>> _buildPronunciationsByFinal() {
    final groups = <String, Set<String>>{};
    for (final syllable in _syllableIndexes.keys) {
      final finalValue = PinyinUtils.finalOf(syllable);
      if (finalValue.isNotEmpty) {
        groups.putIfAbsent(finalValue, () => {}).add(syllable);
      }
    }
    final keys = groups.keys.toList()
      ..sort((a, b) => _finalOrder(a).compareTo(_finalOrder(b)));
    return {for (final key in keys) key: _sortReadings(groups[key]!)};
  }

  Map<int, List<ChineseEntry>> entriesForSyllable(String syllable) {
    final normalized = PinyinUtils.normalize(syllable);
    return _syllableIndexes[normalized]?.entriesByTone ?? const {};
  }

  Map<String, _SyllableIndex> _buildSyllableIndexes() {
    final entryGroups = <String, Map<int, Set<ChineseEntry>>>{};
    final readingGroups = <String, Map<int, Set<String>>>{};
    for (final entry in entries) {
      for (final reading in entry.pinyin) {
        final first = PinyinUtils.firstSyllable(reading);
        final normalized = PinyinUtils.normalize(first);
        if (normalized.isEmpty) continue;
        final tone = PinyinUtils.toneOf(first);
        entryGroups
            .putIfAbsent(normalized, () => {})
            .putIfAbsent(tone, () => {})
            .add(entry);
        readingGroups
            .putIfAbsent(normalized, () => {})
            .putIfAbsent(tone, () => {})
            .add(first);
      }
    }
    return {
      for (final syllable in entryGroups.keys)
        syllable: _SyllableIndex(
          entriesByTone: {
            for (final tone in [1, 2, 3, 4, 5])
              if (entryGroups[syllable]![tone]?.isNotEmpty ?? false)
                tone: entryGroups[syllable]![tone]!.toList()..sort(_entryOrder),
          },
          readingsByTone: {
            for (final group in readingGroups[syllable]!.entries)
              group.key: group.value.toList()..sort(),
          },
        ),
    };
  }

  Map<int, List<String>> readingsForSyllable(String syllable) {
    final normalized = PinyinUtils.normalize(syllable);
    return _syllableIndexes[normalized]?.readingsByTone ?? const {};
  }

  late final Map<int, List<String>> radicalsByStroke = _buildRadicalsByStroke();

  Map<int, List<String>> _buildRadicalsByStroke() {
    final groups = <int, Set<String>>{};
    for (final entry in entries) {
      if (entry.radical.isEmpty) continue;
      final count = radicalStrokeCount(entry.radical);
      if (count <= 0) continue;
      groups.putIfAbsent(count, () => {}).add(entry.radical);
    }
    final keys = groups.keys.toList()..sort();
    return {
      for (final key in keys)
        key: groups[key]!.toList()
          ..sort((a, b) =>
              RadicalUtils.orderOf(a).compareTo(RadicalUtils.orderOf(b))),
    };
  }

  int radicalStrokeCount(String radical) =>
      _byCharacter[radical]?.strokeCount ?? 0;

  String? strokeAssetForCharacter(String character) =>
      _byCharacter[character]?.strokeOrderAsset;

  Map<int, List<ChineseEntry>> entriesForRadical(String radical) {
    return _entriesByRadical[radical] ?? const {};
  }

  Map<String, Map<int, List<ChineseEntry>>> _buildEntriesByRadical() {
    final groups = <String, Map<int, List<ChineseEntry>>>{};
    for (final entry in entries) {
      if (entry.radical.isEmpty) continue;
      final remaining = entry.strokeCount - radicalStrokeCount(entry.radical);
      groups
          .putIfAbsent(entry.radical, () => {})
          .putIfAbsent(remaining < 0 ? 0 : remaining, () => [])
          .add(entry);
    }
    for (final strokes in groups.values) {
      for (final values in strokes.values) {
        values.sort((a, b) => a.character.compareTo(b.character));
      }
    }
    return {
      for (final radical in groups.keys)
        radical: Map.fromEntries(
          groups[radical]!.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)),
        ),
    };
  }

  late final List<int> strokeCounts = _entriesByStroke.keys.toList()..sort();

  List<ChineseEntry> entriesForStrokeCount(int count) {
    return _entriesByStroke[count] ?? const [];
  }

  Map<int, List<ChineseEntry>> _buildEntriesByStroke() {
    final groups = <int, List<ChineseEntry>>{};
    for (final entry in entries) {
      if (entry.pinyin.isEmpty) continue;
      groups.putIfAbsent(entry.strokeCount, () => []).add(entry);
    }
    for (final values in groups.values) {
      values.sort(_entryOrder);
    }
    return groups;
  }

  late final Map<int, List<ChineseEntry>> difficultByStroke =
      _buildDifficultByStroke();

  Map<int, List<ChineseEntry>> _buildDifficultByStroke() {
    final groups = <int, List<ChineseEntry>>{};
    final compound = entries
        .where((entry) => entry.pinyin.any(PinyinUtils.isCompoundReading))
        .toList()
      ..sort(_entryOrder);
    if (compound.isNotEmpty) groups[0] = compound;
    for (final entry in entries.where(
      (entry) =>
          entry.difficult &&
          entry.pinyin.isNotEmpty &&
          !entry.pinyin.any(PinyinUtils.isCompoundReading),
    )) {
      groups.putIfAbsent(entry.strokeCount, () => []).add(entry);
    }
    for (final values in groups.values) {
      values.sort(_entryOrder);
    }
    return Map.fromEntries(
        groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  static List<String> _sortReadings(Set<String> values) => values.toList()
    ..sort((a, b) {
      final plain =
          PinyinUtils.normalize(a).compareTo(PinyinUtils.normalize(b));
      return plain != 0 ? plain : a.compareTo(b);
    });

  static int _entryOrder(ChineseEntry a, ChineseEntry b) {
    final radical = RadicalUtils.orderOf(a.radical)
        .compareTo(RadicalUtils.orderOf(b.radical));
    if (radical != 0) return radical;
    return a.character.compareTo(b.character);
  }

  static int _finalOrder(String value) {
    const base = ['a', 'o', 'e', 'i', 'u', 'v'];
    final first = base.indexOf(value[0]);
    return (first < 0 ? 9 : first) * 1000 +
        value.codeUnits.fold(0, (a, b) => a + b);
  }
}

class _SyllableIndex {
  const _SyllableIndex({
    required this.entriesByTone,
    required this.readingsByTone,
  });

  final Map<int, List<ChineseEntry>> entriesByTone;
  final Map<int, List<String>> readingsByTone;
}
