import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';

abstract interface class DictionaryRepository {
  Future<ChineseEntry?> findExactCharacter(String character);
  Future<Map<String, String>> primaryPinyinFor(Iterable<String> characters);
  Future<List<ChineseEntry>> all();
}

class AssetDictionaryRepository implements DictionaryRepository {
  List<ChineseEntry>? _cache;
  Map<String, ChineseEntry>? _byCharacter;
  Future<List<ChineseEntry>>? _loading;

  Future<List<ChineseEntry>> _load() async {
    if (_cache case final value?) return value;
    if (_loading case final pending?) return pending;
    final pending = _read();
    _loading = pending;
    try {
      return await pending;
    } finally {
      if (identical(_loading, pending)) _loading = null;
    }
  }

  Future<List<ChineseEntry>> _read() async {
    final raw =
        await rootBundle.loadString('assets/data/chinese_entries_v3.json');
    final entries = await compute(_decodeDictionaryEntries, raw);
    assert(
      entries.map((entry) => entry.character).toSet().length == entries.length,
      '字头不可重复',
    );
    _byCharacter = {for (final entry in entries) entry.character: entry};
    return _cache = entries;
  }

  @override
  Future<List<ChineseEntry>> all() => _load();

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async {
    await _load();
    return _byCharacter![character];
  }

  @override
  Future<Map<String, String>> primaryPinyinFor(
    Iterable<String> characters,
  ) async {
    await _load();
    return {
      for (final character in characters)
        if (_byCharacter![character] case final entry?)
          character: entry.pinyin.firstOrNull ?? '',
    };
  }
}

List<ChineseEntry> _decodeDictionaryEntries(
        String raw) =>
    (jsonDecode(raw) as List)
        .map((item) => ChineseEntry.fromJson(item as Map<String, dynamic>))
        .where((entry) =>
            entry.character.isNotEmpty &&
            entry.sourceId.isNotEmpty &&
            entry.strokeCount > 0)
        .toList(growable: false);
