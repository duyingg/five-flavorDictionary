import 'package:flutter/services.dart';

import '../domain/models.dart';
import 'word_binary_codec.dart';

abstract interface class WordRepository {
  Future<WordEntry?> findExact(String word);
}

class AssetWordRepository implements WordRepository {
  Future<WordCatalog>? _loading;

  Future<WordCatalog> _load() => _loading ??= _read();

  Future<WordCatalog> _read() async {
    final data = await rootBundle.load('assets/data/word_entries.wvd');
    return WordBinaryCodec.open(data);
  }

  @override
  Future<WordEntry?> findExact(String word) async =>
      (await _load()).findExact(word);
}
