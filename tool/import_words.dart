import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:wuwei_dictionary/features/data/word_binary_codec.dart';

const _sources = [
  'Aatime/chinese-dictionary-main/word/word.json',
  'Aatime/chinese-dictionary-main/idiom/idiom.json',
];
const _output = 'assets/data/word_entries.wvd';

void main() {
  final entries = <String, _RawWord>{};
  for (final path in _sources) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('缺少词语源数据：$path');
      exitCode = 1;
      return;
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! List) {
      stderr.writeln('词语源数据不是列表：$path');
      exitCode = 1;
      return;
    }
    for (final value in decoded) {
      if (value is! Map) continue;
      final json = Map<String, dynamic>.from(value);
      final word = json['word']?.toString().trim() ?? '';
      final pinyin = json['pinyin']?.toString().trim() ?? '';
      final definition = json['explanation']?.toString().trim() ?? '';
      if (!_isHanWord(word) || pinyin.isEmpty || definition.isEmpty) continue;
      entries[word] = _RawWord(
        word,
        pinyin.replaceAll(RegExp(r'\s+'), ' '),
        definition,
      );
    }
  }

  final sorted = entries.values.toList(growable: false)
    ..sort((left, right) => left.word.compareTo(right.word));
  final records = BytesBuilder(copy: false);
  final offsets = <int>[0];
  for (final entry in sorted) {
    records
      ..add(_string(entry.word))
      ..add(_string(entry.pinyin))
      ..add(_string(entry.definition));
    offsets.add(records.length);
  }

  final output = BytesBuilder(copy: false)
    ..add(WordBinaryCodec.signature)
    ..add(_uint32(sorted.length));
  for (final offset in offsets) {
    output.add(_uint32(offset));
  }
  output.add(records.takeBytes());
  final bytes = output.takeBytes();
  File(_output).writeAsBytesSync(bytes, flush: true);
  stdout.writeln('已导入 ${sorted.length} 个词语，输出 $_output（${bytes.length} 字节）。');
}

Uint8List _string(String value) {
  final bytes = utf8.encode(value);
  return Uint8List.fromList([..._uint32(bytes.length), ...bytes]);
}

Uint8List _uint32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

bool _isHanWord(String value) {
  final runes = value.runes.toList(growable: false);
  return runes.length >= 2 && runes.every(_isHan);
}

bool _isHan(int value) =>
    (value >= 0x3400 && value <= 0x4DBF) ||
    (value >= 0x4E00 && value <= 0x9FFF) ||
    (value >= 0xF900 && value <= 0xFAFF) ||
    (value >= 0x20000 && value <= 0x2EE5F) ||
    (value >= 0x2F800 && value <= 0x2FA1F) ||
    (value >= 0x30000 && value <= 0x323AF);

class _RawWord {
  const _RawWord(this.word, this.pinyin, this.definition);

  final String word;
  final String pinyin;
  final String definition;
}
