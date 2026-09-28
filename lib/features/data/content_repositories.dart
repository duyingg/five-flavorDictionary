import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import 'poetry_binary_codec.dart';

class PolyphonicLearningRepository {
  List<PolyphonicLesson>? _cache;

  Future<List<PolyphonicLesson>> all() async {
    if (_cache case final value?) return value;
    final raw =
        await rootBundle.loadString('assets/data/polyphonic_lessons.json');
    return _cache = (jsonDecode(raw) as List)
        .map((item) => PolyphonicLesson.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}

abstract interface class DailyContentRepository {
  Future<List<DailyContent>> getByType(DailyContentType type);
}

class AssetDailyContentRepository implements DailyContentRepository {
  Future<Map<DailyContentType, List<DailyContent>>>? _loading;

  Future<Map<DailyContentType, List<DailyContent>>> _load() =>
      _loading ??= _read();

  Future<Map<DailyContentType, List<DailyContent>>> _read() async {
    final raw = await rootBundle.loadString('assets/data/daily_content.json');
    final items = (jsonDecode(raw) as List)
        .map((item) => DailyContent.fromJson(item as Map<String, dynamic>))
        .where((item) => item.id.isNotEmpty && item.sourceId.isNotEmpty)
        .toList(growable: false);
    return {
      for (final type in DailyContentType.values)
        type: [
          for (final item in items)
            if (item.type == type) item
        ],
    };
  }

  @override
  Future<List<DailyContent>> getByType(DailyContentType type) async =>
      (await _load())[type]!;
}

abstract interface class CultureRepository {
  Future<List<CultureItem>> getByCategory(CultureCategory category);
  Future<CultureItem?> getById(String id);
}

class AssetCultureRepository implements CultureRepository {
  Future<_CultureIndex>? _loading;
  final Map<String, Future<List<CulturePassage>>> _passageLoads = {};

  Future<_CultureIndex> _load() => _loading ??= _read();

  Future<_CultureIndex> _read() async {
    final raw =
        await rootBundle.loadString('assets/data/culture_items_v2.json');
    final items = (jsonDecode(raw) as List)
        .map((item) => CultureItem.fromJson(item as Map<String, dynamic>))
        .where((item) => item.id.isNotEmpty && item.sourceId.isNotEmpty)
        .toList(growable: false);
    return _CultureIndex(
      byCategory: {
        for (final category in CultureCategory.values)
          category: [
            for (final item in items)
              if (item.category == category) item,
          ],
      },
      byId: {for (final item in items) item.id: item},
    );
  }

  @override
  Future<List<CultureItem>> getByCategory(CultureCategory category) async =>
      (await _load()).byCategory[category]!;

  @override
  Future<CultureItem?> getById(String id) async {
    final item = (await _load()).byId[id];
    final asset = item?.passagesAsset;
    if (item == null || asset == null || asset.isEmpty) return item;
    final passages = await (_passageLoads[asset] ??= _readPassages(asset));
    return item.withPassages(passages);
  }

  Future<List<CulturePassage>> _readPassages(String asset) async {
    final raw = await rootBundle.loadString(asset);
    return compute(_decodeCulturePassages, raw);
  }
}

List<CulturePassage> _decodeCulturePassages(String raw) =>
    (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((item) => CulturePassage.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);

class _CultureIndex {
  const _CultureIndex({required this.byCategory, required this.byId});

  final Map<CultureCategory, List<CultureItem>> byCategory;
  final Map<String, CultureItem> byId;
}

abstract interface class PoetryRepository {
  Future<PoetryCatalog> catalog({bool fullLibrary = false});
  Future<PoetryItem?> getById(String id, {bool fullLibrary = false});
}

class AssetPoetryRepository implements PoetryRepository {
  PoetryCatalog? _cache;
  bool? _cachedFullLibrary;
  Future<PoetryCatalog>? _loading;
  bool? _loadingFullLibrary;
  var _loadRevision = 0;

  Future<PoetryCatalog> _load(bool fullLibrary) async {
    final cached = _cache;
    if (_cachedFullLibrary == fullLibrary && cached != null) {
      return cached;
    }
    if (_loadingFullLibrary == fullLibrary) {
      final pending = _loading;
      if (pending != null) return pending;
    }
    final revision = ++_loadRevision;
    final pending = _read(fullLibrary);
    _loadingFullLibrary = fullLibrary;
    _loading = pending;
    try {
      final catalog = await pending;
      if (revision == _loadRevision) {
        _cachedFullLibrary = fullLibrary;
        _cache = catalog;
      }
      return catalog;
    } finally {
      if (identical(_loading, pending)) {
        _loading = null;
        _loadingFullLibrary = null;
      }
    }
  }

  Future<PoetryCatalog> _read(bool fullLibrary) async {
    final asset = fullLibrary
        ? 'assets/data/poetry_items_full.wvp'
        : 'assets/data/poetry_items.wvp';
    final bytes = await rootBundle.load(asset);
    return PoetryBinaryCodec.open(bytes);
  }

  @override
  Future<PoetryCatalog> catalog({bool fullLibrary = false}) =>
      _load(fullLibrary);

  @override
  Future<PoetryItem?> getById(String id, {bool fullLibrary = false}) async {
    return (await _load(fullLibrary)).findById(id);
  }
}
