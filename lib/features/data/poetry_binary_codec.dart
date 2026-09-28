import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import '../domain/models.dart';

enum PoetryOrder { random, ascending, descending }

class PoetryQuery {
  const PoetryQuery({
    this.text = '',
    this.author = '',
    this.dynasty = '',
    this.form = '',
    this.style = '',
    this.theme = '',
    this.emotion = '',
    this.translatedOnly = false,
    this.order = PoetryOrder.random,
  });

  final String text;
  final String author;
  final String dynasty;
  final String form;
  final String style;
  final String theme;
  final String emotion;
  final bool translatedOnly;
  final PoetryOrder order;

  bool get hasFilters =>
      text.isNotEmpty ||
      author.isNotEmpty ||
      dynasty.isNotEmpty ||
      form.isNotEmpty ||
      style.isNotEmpty ||
      theme.isNotEmpty ||
      emotion.isNotEmpty ||
      translatedOnly;
}

class PoetrySelection {
  const PoetrySelection._(this._catalog, this.order, this._recordIndexes);

  final PoetryCatalog _catalog;
  final PoetryOrder order;
  final Uint32List? _recordIndexes;

  int get length => _recordIndexes?.length ?? _catalog.length;

  PoetryItem itemAt(int position) {
    RangeError.checkValidIndex(position, this, 'position', length);
    final recordIndex =
        _recordIndexes?[position] ?? _catalog.recordIndexAt(position, order);
    return _catalog.itemAt(recordIndex);
  }
}

/// Lazy, indexed view over the on-device poetry resource.
///
/// The catalog retains compact bytes and integer indexes. [PoetryItem] objects
/// are decoded only when a visible row or detail page asks for one. A bounded
/// LRU cache prevents scrolling from recreating recently viewed records without
/// allowing the full library to become a permanent object graph.
class PoetryCatalog {
  PoetryCatalog._({
    required ByteData data,
    required List<String> sharedStrings,
    required Uint32List recordOffsets,
    required Uint32List ascendingRecordIndexes,
    required int recordsStart,
  })  : _data = data,
        _sharedStrings = sharedStrings,
        _recordOffsets = recordOffsets,
        _ascendingRecordIndexes = ascendingRecordIndexes,
        _recordsStart = recordsStart;

  static const _cacheLimit = 256;

  final ByteData _data;
  final List<String> _sharedStrings;
  final Uint32List _recordOffsets;
  final Uint32List _ascendingRecordIndexes;
  final int _recordsStart;
  final LinkedHashMap<int, PoetryItem> _cache = LinkedHashMap();

  int get length => _recordOffsets.length - 1;

  PoetrySelection select(PoetryQuery query) {
    if (!query.hasFilters) {
      return PoetrySelection._(this, query.order, null);
    }
    final matches = Uint32List(length);
    var matchCount = 0;
    for (var position = 0; position < length; position++) {
      final recordIndex = recordIndexAt(position, query.order);
      if (_matches(recordIndex, query)) matches[matchCount++] = recordIndex;
    }
    return PoetrySelection._(
      this,
      query.order,
      Uint32List.sublistView(matches, 0, matchCount),
    );
  }

  Future<PoetrySelection?> selectAsync(
    PoetryQuery query, {
    int chunkSize = 4096,
    bool Function()? isCancelled,
  }) async {
    if (isCancelled?.call() ?? false) return null;
    if (!query.hasFilters) {
      return PoetrySelection._(this, query.order, null);
    }
    final matches = Uint32List(length);
    var matchCount = 0;
    for (var position = 0; position < length; position++) {
      final recordIndex = recordIndexAt(position, query.order);
      if (_matches(recordIndex, query)) matches[matchCount++] = recordIndex;
      if (position > 0 && position % chunkSize == 0) {
        await Future<void>.delayed(Duration.zero);
        if (isCancelled?.call() ?? false) return null;
      }
    }
    return PoetrySelection._(
      this,
      query.order,
      Uint32List.sublistView(matches, 0, matchCount),
    );
  }

  int recordIndexAt(int position, PoetryOrder order) {
    RangeError.checkValidIndex(position, this, 'position', length);
    return switch (order) {
      PoetryOrder.random => position,
      PoetryOrder.ascending => _ascendingRecordIndexes[position],
      PoetryOrder.descending =>
        _ascendingRecordIndexes[_ascendingRecordIndexes.length - position - 1],
    };
  }

  PoetryItem itemAt(int recordIndex) {
    RangeError.checkValidIndex(recordIndex, this, 'recordIndex', length);
    final cached = _cache.remove(recordIndex);
    if (cached != null) {
      _cache[recordIndex] = cached;
      return cached;
    }
    final reader = _recordReader(recordIndex);
    final sequence = reader.readUint32();
    final shuffleKey = reader.readUint32();
    final author = _shared(reader.readUint32());
    reader.readUint32(); // normalized author, used only by filtering
    final dynasty = _shared(reader.readUint32());
    final form = _shared(reader.readUint32());
    final style = _shared(reader.readUint32());
    final theme = _shared(reader.readUint32());
    final emotion = _shared(reader.readUint32());
    final sourceId = _shared(reader.readUint32());
    final item = PoetryItem(
      id: reader.readString(),
      title: reader.readString(),
      searchText: reader.readString(),
      content: reader.readString(),
      notes: reader.readString(),
      translation: reader.readString(),
      appreciation: reader.readString(),
      author: author,
      dynasty: dynasty,
      form: form,
      style: style,
      theme: theme,
      emotion: emotion,
      sourceId: sourceId,
      shuffleKey: shuffleKey,
      sequence: sequence,
    );
    reader.expectEnd();
    _cache[recordIndex] = item;
    if (_cache.length > _cacheLimit) _cache.remove(_cache.keys.first);
    return item;
  }

  PoetryItem? findById(String id) {
    final separator = id.lastIndexOf('-');
    final sequence =
        separator < 0 ? null : int.tryParse(id.substring(separator + 1));
    if (sequence == null) return null;
    var low = 0;
    var high = _ascendingRecordIndexes.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final recordIndex = _ascendingRecordIndexes[middle];
      final candidate = _sequenceAt(recordIndex);
      if (candidate == sequence) {
        final item = itemAt(recordIndex);
        return item.id == id ? item : null;
      }
      if (candidate < sequence) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return null;
  }

  bool _matches(int recordIndex, PoetryQuery query) {
    final reader = _recordReader(recordIndex)..skipUint32(2);
    reader.readUint32(); // display author
    if (query.author.isNotEmpty &&
        !_shared(reader.readUint32()).contains(query.author)) {
      return false;
    }
    if (query.author.isEmpty) reader.skipUint32();
    if (!_matchesShared(reader, query.dynasty) ||
        !_matchesShared(reader, query.form) ||
        !_matchesShared(reader, query.style) ||
        !_matchesShared(reader, query.theme) ||
        !_matchesShared(reader, query.emotion)) {
      return false;
    }
    reader.skipUint32(); // source ID
    reader.skipString(); // ID
    reader.skipString(); // title
    final textMatches =
        query.text.isEmpty || reader.readString().contains(query.text);
    if (!textMatches) return false;
    if (!query.translatedOnly) return true;
    if (query.text.isEmpty) reader.skipString(); // search text
    reader.skipString(); // content
    reader.skipString(); // notes
    return reader.readString().isNotEmpty;
  }

  bool _matchesShared(_BinaryReader reader, String expected) {
    final value = _shared(reader.readUint32());
    return expected.isEmpty || value == expected;
  }

  int _sequenceAt(int recordIndex) => _data.getUint32(
        _recordsStart + _recordOffsets[recordIndex],
        Endian.little,
      );

  String _shared(int index) {
    if (index >= _sharedStrings.length) {
      throw const FormatException('诗词资源包含无效的共享字符串索引');
    }
    return _sharedStrings[index];
  }

  _BinaryReader _recordReader(int recordIndex) => _BinaryReader(
        _data,
        start: _recordsStart + _recordOffsets[recordIndex],
        end: _recordsStart + _recordOffsets[recordIndex + 1],
      );
}

/// Reader for version 2 of the Five-Flavor poetry binary format.
abstract final class PoetryBinaryCodec {
  static const signature = <int>[
    0x57,
    0x55,
    0x57,
    0x45,
    0x49,
    0x50,
    0x4f,
    0x32
  ];

  static PoetryCatalog open(ByteData data) {
    final reader = _BinaryReader(data);
    reader.expectBytes(signature);
    final itemCount = reader.readUint32();
    final sharedStrings = List<String>.generate(
      reader.readUint32(),
      (_) => reader.readString(),
      growable: false,
    );
    final offsets = Uint32List(itemCount + 1);
    for (var index = 0; index < offsets.length; index++) {
      offsets[index] = reader.readUint32();
      if (index > 0 && offsets[index] < offsets[index - 1]) {
        throw const FormatException('诗词资源记录偏移顺序无效');
      }
    }
    final ascendingCount = reader.readUint32();
    if (ascendingCount != itemCount) {
      throw const FormatException('诗词资源顺序索引数量不匹配');
    }
    final ascending = Uint32List(itemCount);
    final seen = Uint8List(itemCount);
    for (var index = 0; index < ascending.length; index++) {
      final recordIndex = reader.readUint32();
      if (recordIndex >= itemCount || seen[recordIndex] != 0) {
        throw const FormatException('诗词资源顺序索引无效');
      }
      ascending[index] = recordIndex;
      seen[recordIndex] = 1;
    }
    if (offsets.last != reader.remaining) {
      throw const FormatException('诗词资源记录区长度不匹配');
    }
    return PoetryCatalog._(
      data: data,
      sharedStrings: sharedStrings,
      recordOffsets: offsets,
      ascendingRecordIndexes: ascending,
      recordsStart: reader.offset,
    );
  }
}

final class _BinaryReader {
  _BinaryReader(this.data, {int start = 0, int? end})
      : _offset = start,
        _end = end ?? data.lengthInBytes;

  final ByteData data;
  final int _end;
  int _offset;

  int get offset => _offset;
  int get remaining => _end - _offset;

  void expectBytes(List<int> expected) {
    _ensureAvailable(expected.length);
    for (final value in expected) {
      if (data.getUint8(_offset++) != value) {
        throw const FormatException('不是有效的五味字典诗词资源');
      }
    }
  }

  int readUint32() {
    _ensureAvailable(4);
    final value = data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  void skipUint32([int count = 1]) {
    final length = count * 4;
    _ensureAvailable(length);
    _offset += length;
  }

  String readString() {
    final length = readUint32();
    _ensureAvailable(length);
    final bytes = data.buffer.asUint8List(data.offsetInBytes + _offset, length);
    _offset += length;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('诗词资源包含无效的 UTF-8 文本');
    }
  }

  void skipString() {
    final length = readUint32();
    _ensureAvailable(length);
    _offset += length;
  }

  void expectEnd() {
    if (_offset != _end) {
      throw const FormatException('诗词记录尾部包含未识别数据');
    }
  }

  void _ensureAvailable(int length) {
    if (length < 0 || _offset + length > _end) {
      throw const FormatException('诗词资源已截断');
    }
  }
}
