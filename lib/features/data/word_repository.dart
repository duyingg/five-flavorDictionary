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

class AssetWordRepository implements WordSearchRepository {
  Future<WordCatalog>? _loading;

  Future<WordCatalog> _load() => _loading ??= _read();

  Future<WordCatalog> _read() async {
    final data = await rootBundle.load('assets/data/word_entries.wvd');
    return WordBinaryCodec.open(data);
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
      (await _load()).searchPinyin(readings, limit: limit);
}
