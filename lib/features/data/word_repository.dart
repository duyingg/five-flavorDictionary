import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../domain/models.dart';
import 'word_binary_codec.dart';

abstract interface class WordRepository {
  Future<WordEntry?> findExact(String word);
}

abstract interface class WordSearchRepository implements WordRepository {
  Future<List<WordEntry>> searchText(String query, {int limit = 50});
  Future<List<WordEntry>> searchPinyin(List<String> readings, {int limit = 50});
}

class DailyWordCatalog {
  const DailyWordCatalog(this._words, this._idiomPositions);

  final WordCatalog _words;
  final Uint32List _idiomPositions;

  int count(DailyContentType type) => switch (type) {
        DailyContentType.word => _words.length,
        DailyContentType.idiom => _idiomPositions.length,
        _ => 0,
      };

  WordEntry entryAt(DailyContentType type, int position) => switch (type) {
        DailyContentType.word => _words.entryAt(position),
        DailyContentType.idiom => _words.entryAt(_idiomPositions[position]),
        _ => throw ArgumentError.value(type, 'type', '不是词语或成语'),
      };
}

abstract interface class DailyWordRepository {
  Future<DailyWordCatalog> dailyCatalog();
}

class AssetWordRepository implements WordSearchRepository, DailyWordRepository {
  Future<WordCatalog>? _loading;
  Future<DailyWordCatalog>? _dailyLoading;
  Future<WordCatalog>? _pinyinLoading;

  Future<WordCatalog> _load() => _loading ??= _read();

  Future<WordCatalog> _read() async {
    final data = await rootBundle.load('assets/data/word_entries.wvd');
    return WordBinaryCodec.open(data);
  }

  @override
  Future<DailyWordCatalog> dailyCatalog() =>
      _dailyLoading ??= _readDailyCatalog();

  Future<DailyWordCatalog> _readDailyCatalog() async {
    final words = await _load();
    final index = await rootBundle.load('assets/data/idiom_positions.wvi');
    return DailyWordCatalog(words, words.idiomPositions(index));
  }

  Future<WordCatalog> _loadPinyinCatalog() =>
      _pinyinLoading ??= _readPinyinCatalog();

  Future<WordCatalog> _readPinyinCatalog() async {
    final words = await _load();
    final index = await rootBundle.load('assets/data/word_pinyin_index.wpi');
    words.installFirstReadingIndex(index);
    return words;
  }

  @override
  Future<WordEntry?> findExact(String word) async =>
      (await _load()).findExact(word);

  @override
  Future<List<WordEntry>> searchText(String query, {int limit = 50}) async =>
      (await _load()).searchText(query, limit: limit);

  @override
  Future<List<WordEntry>> searchPinyin(List<String> readings,
          {int limit = 50}) async =>
      (await _loadPinyinCatalog()).searchPinyin(readings, limit: limit);
}
