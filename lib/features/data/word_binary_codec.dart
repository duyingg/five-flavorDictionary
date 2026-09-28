import 'dart:convert';
import 'dart:typed_data';

import '../domain/models.dart';

class WordCatalog {
  WordCatalog._(this._data, this._offsets, this._recordsStart);

  final ByteData _data;
  final Uint32List _offsets;
  final int _recordsStart;

  int get length => _offsets.length - 1;

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
