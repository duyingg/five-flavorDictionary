import 'dart:convert';
import 'dart:typed_data';

import '../../core/language/pinyin_utils.dart';
import '../domain/models.dart';

class WordCatalog {
  WordCatalog._(this._data, this._offsets, this._recordsStart);

  final ByteData _data;
  final Uint32List _offsets;
  final int _recordsStart;
  Map<String, Uint32List>? _firstReadingIndex;

  int get length => _offsets.length - 1;

  void installFirstReadingIndex(ByteData data) {
    const signature = [0x57, 0x55, 0x57, 0x45, 0x49, 0x50, 0x49, 0x31];
    if (data.lengthInBytes < 20) {
      throw const FormatException('不是有效的词语拼音索引');
    }
    for (var index = 0; index < signature.length; index++) {
      if (data.getUint8(index) != signature[index]) {
        throw const FormatException('不是有效的词语拼音索引');
      }
    }
    var cursor = 8;
    int readUint32() {
      if (cursor + 4 > data.lengthInBytes) {
        throw const FormatException('词语拼音索引已截断');
      }
      final value = data.getUint32(cursor, Endian.little);
      cursor += 4;
      return value;
    }

    int readVarint() {
      var value = 0;
      for (var shift = 0; shift <= 28; shift += 7) {
        if (cursor >= data.lengthInBytes) {
          throw const FormatException('词语拼音索引已截断');
        }
        final byte = data.getUint8(cursor++);
        value |= (byte & 0x7f) << shift;
        if (byte & 0x80 == 0) return value;
      }
      throw const FormatException('词语拼音索引位置无效');
    }

    final total = readUint32();
    final indexed = readUint32();
    final groupCount = readUint32();
    if (total != length || indexed > total || groupCount > indexed) {
      throw const FormatException('词语拼音索引与词语资源不匹配');
    }
    final groups = <String, Uint32List>{};
    var found = 0;
    for (var group = 0; group < groupCount; group++) {
      if (cursor >= data.lengthInBytes) {
        throw const FormatException('词语拼音索引已截断');
      }
      final keyLength = data.getUint8(cursor++);
      if (keyLength == 0 || cursor + keyLength > data.lengthInBytes) {
        throw const FormatException('词语拼音索引读音无效');
      }
      final key = utf8.decode(
        data.buffer.asUint8List(data.offsetInBytes + cursor, keyLength),
      );
      cursor += keyLength;
      final count = readUint32();
      if (count == 0 || found + count > indexed || groups.containsKey(key)) {
        throw const FormatException('词语拼音索引分组无效');
      }
      final positions = Uint32List(count);
      var previous = 0;
      for (var index = 0; index < count; index++) {
        final delta = readVarint();
        final position = previous + delta;
        if (position >= length || (index > 0 && delta == 0)) {
          throw const FormatException('词语拼音索引位置无效');
        }
        positions[index] = position;
        previous = position;
      }
      groups[key] = positions;
      found += count;
    }
    if (found != indexed || cursor != data.lengthInBytes) {
      throw const FormatException('词语拼音索引长度无效');
    }
    _firstReadingIndex = groups;
  }

  /// Positions of every imported idiom in the shared word catalog.
  Uint32List idiomPositions(ByteData index) {
    const signature = [0x57, 0x55, 0x57, 0x45, 0x49, 0x44, 0x49, 0x31];
    if (index.lengthInBytes < 16) {
      throw const FormatException('不是有效的成语索引');
    }
    for (var offset = 0; offset < signature.length; offset++) {
      if (index.getUint8(offset) != signature[offset]) {
        throw const FormatException('不是有效的成语索引');
      }
    }
    final total = index.getUint32(8, Endian.little);
    final selected = index.getUint32(12, Endian.little);
    if (total != length ||
        selected > total ||
        index.lengthInBytes != 16 + ((total + 7) >> 3)) {
      throw const FormatException('成语索引与词语资源不匹配');
    }
    final positions = Uint32List(selected);
    var found = 0;
    for (var position = 0; position < total; position++) {
      if (index.getUint8(16 + (position >> 3)) & (1 << (position & 7)) == 0) {
        continue;
      }
      if (found >= selected) throw const FormatException('成语索引数量无效');
      positions[found++] = position;
    }
    if (found != selected ||
        (total & 7 != 0 &&
            index.getUint8(index.lengthInBytes - 1) >> (total & 7) != 0)) {
      throw const FormatException('成语索引数量无效');
    }
    return positions;
  }

  WordEntry entryAt(int position) {
    RangeError.checkValidIndex(position, this, 'position', length);
    return _entryAt(position);
  }

  WordEntry? findExact(String word) {
    var low = 0;
    var high = length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      final reader = _readerAt(middle);
      final candidate = reader.readString();
      final comparison = candidate.compareTo(word);
      if (comparison == 0) {
        final item = WordEntry(
          word: candidate,
          pinyin: reader.readString(),
          definition: reader.readString(),
        );
        reader.expectEnd();
        return item;
      }
      if (comparison < 0) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return null;
  }

  List<WordEntry> searchText(String query, {int limit = 50}) {
    if (query.isEmpty || limit <= 0) return const [];
    var low = 0;
    var high = length;
    while (low < high) {
      final middle = (low + high) >> 1;
      final word = _readerAt(middle).readString();
      if (word.compareTo(query) < 0) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    final result = <WordEntry>[];
    for (var index = low; index < length && result.length < limit; index++) {
      final item = _entryAt(index);
      if (!item.word.startsWith(query)) break;
      result.add(item);
    }
    return result;
  }

  List<WordEntry> searchPinyin(List<String> readings, {int limit = 50}) {
    final query = readings.map(PinyinUtils.normalize).toList();
    if (query.isEmpty || query.any((value) => value.isEmpty) || limit <= 0) {
      return const [];
    }
    final index = _firstReadingIndex ??= _buildFirstReadingIndex();
    final result = <WordEntry>[];
    for (final position in index[query.first] ?? const <int>[]) {
      final reader = _readerAt(position);
      reader.skipString();
      final pinyin = reader.readString().split(RegExp(r'\s+'));
      if (pinyin.length < query.length) continue;
      var matches = true;
      for (var part = 1; part < query.length; part++) {
        if (PinyinUtils.normalize(pinyin[part]) != query[part]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      result.add(_entryAt(position));
      if (result.length == limit) break;
    }
    return result;
  }

  Map<String, Uint32List> _buildFirstReadingIndex() {
    final result = <String, List<int>>{};
    for (var position = 0; position < length; position++) {
      final reader = _readerAt(position);
      reader.skipString();
      final pinyin = reader.readString();
      final boundary = pinyin.indexOf(' ');
      final first = boundary < 0 ? pinyin : pinyin.substring(0, boundary);
      final normalized = PinyinUtils.normalize(first);
      if (normalized.isNotEmpty) {
        result.putIfAbsent(normalized, () => []).add(position);
      }
    }
    return result
        .map((key, value) => MapEntry(key, Uint32List.fromList(value)));
  }

  WordEntry _entryAt(int position) {
    final reader = _readerAt(position);
    final entry = WordEntry(
      word: reader.readString(),
      pinyin: reader.readString(),
      definition: reader.readString(),
    );
    reader.expectEnd();
    return entry;
  }

  _WordBinaryReader _readerAt(int index) => _WordBinaryReader(
        _data,
        start: _recordsStart + _offsets[index],
        end: _recordsStart + _offsets[index + 1],
      );
}

abstract final class WordBinaryCodec {
  static const signature = <int>[
    0x57,
    0x55,
    0x57,
    0x45,
    0x49,
    0x57,
    0x44,
    0x31
  ];

  static WordCatalog open(ByteData data) {
    final reader = _WordBinaryReader(data)..expectBytes(signature);
    final count = reader.readUint32();
    final offsets = Uint32List(count + 1);
    for (var index = 0; index < offsets.length; index++) {
      offsets[index] = reader.readUint32();
      if (index > 0 && offsets[index] < offsets[index - 1]) {
        throw const FormatException('词语资源记录偏移顺序无效');
      }
    }
    if (offsets.last != reader.remaining) {
      throw const FormatException('词语资源记录区长度不匹配');
    }
    return WordCatalog._(data, offsets, reader.offset);
  }
}

final class _WordBinaryReader {
  _WordBinaryReader(this.data, {int start = 0, int? end})
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
        throw const FormatException('不是有效的五味字典词语资源');
      }
    }
  }

  int readUint32() {
    _ensureAvailable(4);
    final value = data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  String readString() {
    final length = readUint32();
    _ensureAvailable(length);
    final bytes = data.buffer.asUint8List(data.offsetInBytes + _offset, length);
    _offset += length;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('词语资源包含无效的 UTF-8 文本');
    }
  }

  void skipString() {
    final length = readUint32();
    _ensureAvailable(length);
    _offset += length;
  }

  void expectEnd() {
    if (_offset != _end) {
      throw const FormatException('词语记录尾部包含未识别数据');
    }
  }

  void _ensureAvailable(int length) {
    if (length < 0 || _offset + length > _end) {
      throw const FormatException('词语资源已截断');
    }
  }
}
