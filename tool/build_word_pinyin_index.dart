import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:wuwei_dictionary/core/language/pinyin_utils.dart';
import 'package:wuwei_dictionary/features/data/word_binary_codec.dart';

void main() {
  const source = 'assets/data/word_entries.wvd';
  const target = 'assets/data/word_pinyin_index.wpi';
  final catalog = WordBinaryCodec.open(
    ByteData.sublistView(File(source).readAsBytesSync()),
  );
  final groups = <String, List<int>>{};
  for (var position = 0; position < catalog.length; position++) {
    final reading = PinyinUtils.normalize(
      PinyinUtils.firstSyllable(catalog.entryAt(position).pinyin),
    );
    if (reading.isNotEmpty) {
      groups.putIfAbsent(reading, () => <int>[]).add(position);
    }
  }

  final bytes = BytesBuilder(copy: false)
    ..add(utf8.encode('WUWEIPI1'))
    ..add(_uint32(catalog.length))
    ..add(_uint32(groups.values.fold<int>(0, (sum, list) => sum + list.length)))
    ..add(_uint32(groups.length));
  for (final key in groups.keys.toList()..sort()) {
    final keyBytes = utf8.encode(key);
    if (keyBytes.isEmpty || keyBytes.length > 255) {
      throw FormatException('无效的拼音索引分组：$key');
    }
    final positions = groups[key]!;
    bytes
      ..addByte(keyBytes.length)
      ..add(keyBytes)
      ..add(_uint32(positions.length));
    var previous = 0;
    for (final position in positions) {
      _addVarint(bytes, position - previous);
      previous = position;
    }
  }
  final output = bytes.takeBytes();
  File(target).writeAsBytesSync(output, flush: true);
  stdout.writeln(
    '已生成 ${groups.length} 个拼音分组、${catalog.length} 条词语，'
    '$target（${output.length} 字节）。',
  );
}

Uint8List _uint32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

void _addVarint(BytesBuilder bytes, int value) {
  while (value >= 0x80) {
    bytes.addByte((value & 0x7f) | 0x80);
    value >>= 7;
  }
  bytes.addByte(value);
}
