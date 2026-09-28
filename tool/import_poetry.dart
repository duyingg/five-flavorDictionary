import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:wuwei_dictionary/features/data/poetry_binary_codec.dart';

const _root = 'Aatime/chinese-poetry-master';
const _translationRoot =
    'Aatime/chinese-ancient-poetry-translation-master/data/poetry';
const _quotaTang = 20000;
const _quotaSong = 20000;
const _dailyVerseClauses = <String>[
  '海内存知己',
  '会当凌绝顶',
  '大漠孤烟直',
  '江碧鸟逾白',
  '明月松间照',
  '潮平两岸阔',
  '春风又绿江南岸',
  '山重水复疑无路',
  '欲穷千里目',
  '采菊东篱下',
];
late final Map<int, String> _traditionalToSimplified;

Future<void> main(List<String> args) async {
  final root = Directory(_root);
  if (!root.existsSync()) {
    stderr.writeln('未找到 chinese-poetry-master。');
    exitCode = 1;
    return;
  }
  _traditionalToSimplified = _readOpenCc('assets/data/opencc/TSCharacters.txt');

  final tang = <_RawPoem>[];
  final song = <_RawPoem>[];
  final other = <_RawPoem>[];
  final seen = <String>{};
  var sequence = 0;

  void add(Map<String, dynamic> json, String dynasty, String baseForm,
      List<_RawPoem> target,
      {bool curated = false}) {
    final rawParagraphs = json['paragraphs'] ?? json['content'] ?? json['para'];
    final paragraphs = _poetryLines(rawParagraphs);
    if (paragraphs.length < 2) return;
    final title = (json['title'] ?? json['rhythmic'] ?? '无题').toString().trim();
    final author = (json['author'] ?? '佚名').toString().trim();
    final content = paragraphs.join('\n');
    final key = '$dynasty|$author|$title|$content';
    if (!seen.add(key)) return;
    final tags = List<String>.from(json['tags'] as List? ?? const []);
    final notes = _textOf(json['notes']);
    final translation = _firstText(json, const [
      'translation',
      'translations',
      'translated',
      'vernacular',
    ]);
    final appreciation = _firstText(json, const [
      'appreciation',
      'analysis',
      'prologue',
      'comment',
    ]);
    target.add(_RawPoem(
      title: title,
      author: author,
      dynasty: dynasty,
      form: _formOf(baseForm, paragraphs, tags),
      style: _styleOf(title, content, tags),
      theme: _themeOf(title, content, tags),
      emotion: _emotionOf(title, content, tags),
      content: content,
      notes: notes,
      translation: translation,
      appreciation: appreciation,
      sequence: sequence++,
      curated: curated,
      sourceId: 'chinese-poetry (MIT)',
    ));
  }

  void readFile(String path, String dynasty, String form, List<_RawPoem> target,
      {bool curated = false}) {
    final file = File(path);
    if (!file.existsSync()) return;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! List) return;
    for (final value in decoded) {
      if (value is Map) {
        add(Map<String, dynamic>.from(value), dynasty, form, target,
            curated: curated);
      }
    }
  }

  readFile('$_root/全唐诗/唐诗三百首.json', '唐', '诗', tang, curated: true);
  readFile('$_root/宋词/宋词三百首.json', '宋', '词', song, curated: true);

  final tangFiles = Directory('$_root/全唐诗')
      .listSync()
      .whereType<File>()
      .where((file) => RegExp(r'poet\.tang\.\d+\.json$').hasMatch(file.path))
      .toList()
    ..sort((a, b) => _fileNumber(a.path).compareTo(_fileNumber(b.path)));
  for (final file in tangFiles) {
    readFile(file.path, '唐', '诗', tang);
  }

  final songFiles = Directory('$_root/宋词')
      .listSync()
      .whereType<File>()
      .where((file) => RegExp(r'ci\.song\.\d+\.json$').hasMatch(file.path))
      .toList()
    ..sort((a, b) => _fileNumber(a.path).compareTo(_fileNumber(b.path)));
  for (final file in songFiles) {
    readFile(file.path, '宋', '词', song);
  }
  final songPoemFiles = Directory('$_root/全唐诗')
      .listSync()
      .whereType<File>()
      .where((file) => RegExp(r'poet\.song\.\d+\.json$').hasMatch(file.path))
      .toList()
    ..sort((a, b) => _fileNumber(a.path).compareTo(_fileNumber(b.path)));
  for (final file in songPoemFiles) {
    readFile(file.path, '宋', '诗', song);
  }

  readFile('$_root/元曲/yuanqu.json', '元', '曲', other);
  readFile('$_root/诗经/shijing.json', '先秦', '诗', other);
  readFile('$_root/楚辞/chuci.json', '先秦', '楚辞', other);
  readFile('$_root/曹操诗集/caocao.json', '汉', '诗', other);
  readFile('$_root/水墨唐诗/shuimotangshi.json', '唐', '诗', other);
  final otherDirectories = [
    ('$_root/五代诗词', '五代', '词'),
    ('$_root/纳兰性德', '清', '词'),
  ];
  for (final source in otherDirectories) {
    final files = Directory(source.$1)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'));
    for (final file in files) {
      readFile(file.path, source.$2, source.$3, other);
    }
  }

  // 上游《绝句二首·其二》仅保存了半首且会被完整性校验过滤，
  // 《泊船瓜洲》则未收录；补入公版原文，保证每日诗句可回到完整原诗。
  add(
    {
      'title': '绝句二首·其二',
      'author': '杜甫',
      'paragraphs': [
        '江碧鸟逾白，山青花欲燃。',
        '今春看又过，何日是归年。',
      ],
    },
    '唐',
    '诗',
    tang,
    curated: true,
  );
  add(
    {
      'title': '泊船瓜洲',
      'author': '王安石',
      'paragraphs': [
        '京口瓜洲一水间，钟山只隔数重山。',
        '春风又绿江南岸，明月何时照我还。',
      ],
    },
    '宋',
    '诗',
    song,
    curated: true,
  );

  final translationStats = _mergeTranslationCorpus(
    tang: tang,
    song: song,
    other: other,
    seen: seen,
    firstSequence: sequence,
  );

  final selected = <_RawPoem>[
    ..._takeStable(tang, _quotaTang),
    ..._takeStable(song, _quotaSong),
    ...other,
  ];
  final missingDailyVerses = _dailyVerseClauses
      .where((clause) => !selected.any(
            (poem) => _toSimplified(poem.content).contains(clause),
          ))
      .toList();
  if (missingDailyVerses.isNotEmpty) {
    throw StateError('默认诗词库缺少每日诗句：${missingDailyVerses.join('、')}');
  }
  final full = <_RawPoem>[...tang, ...song, ...other];
  final outFile = await _writeOutput('assets/data/poetry_items.wvp', selected);
  final fullFile =
      await _writeOutput('assets/data/poetry_items_full.wvp', full);
  if (!args.contains('--no-report')) {
    _writeReport(
      tang,
      song,
      other,
      selected,
      full,
      outFile,
      fullFile,
      translationStats,
    );
  }

  stdout.writeln(
    '诗词候选：唐 ${tang.length}，宋诗词 ${song.length}，其他 ${other.length}',
  );
  stdout.writeln(
    '默认 ${selected.length} 条（${outFile.lengthSync()} 字节），'
    '全量 ${full.length} 条（${fullFile.lengthSync()} 字节）。',
  );
  stdout.writeln(
    '翻译包：读取 ${translationStats.read}，匹配 ${translationStats.matched}，'
    '新增 ${translationStats.added}，有译文 ${translationStats.withTranslation}，'
    '有注释 ${translationStats.withNotes}。',
  );
}

void _writeReport(
  List<_RawPoem> tang,
  List<_RawPoem> song,
  List<_RawPoem> other,
  List<_RawPoem> selected,
  List<_RawPoem> full,
  File defaultFile,
  File fullFile,
  _TranslationImportStats translationStats,
) {
  int withNotes(Iterable<_RawPoem> values) =>
      values.where((item) => item.notes.isNotEmpty).length;
  int withTranslations(Iterable<_RawPoem> values) =>
      values.where((item) => item.translation.isNotEmpty).length;
  int withAppreciations(Iterable<_RawPoem> values) =>
      values.where((item) => item.appreciation.isNotEmpty).length;
  final buffer = StringBuffer()
    ..writeln('# 诗词资源导入报告')
    ..writeln()
    ..writeln('- 唐诗候选：${tang.length} 首')
    ..writeln('- 宋诗词候选：${song.length} 首')
    ..writeln('- 其他诗词：${other.length} 首（全部进入默认库）')
    ..writeln('- 默认库：${selected.length} 首，${defaultFile.lengthSync()} 字节')
    ..writeln('- 全量库：${full.length} 首，${fullFile.lengthSync()} 字节')
    ..writeln('- 翻译包读取：${translationStats.read} 首；匹配现有 '
        '${translationStats.matched} 首；新增 ${translationStats.added} 首')
    ..writeln('- 翻译包有效字段：译文 ${translationStats.withTranslation} 首；'
        '注释 ${translationStats.withNotes} 首；赏析/背景 '
        '${translationStats.withAppreciation} 首')
    ..writeln()
    ..writeln('| 范围 | 有注释 | 有翻译 | 有赏析/解说 |')
    ..writeln('|---|---:|---:|---:|')
    ..writeln('| 默认库 | ${withNotes(selected)} | '
        '${withTranslations(selected)} | ${withAppreciations(selected)} |')
    ..writeln('| 全量库 | ${withNotes(full)} | '
        '${withTranslations(full)} | ${withAppreciations(full)} |')
    ..writeln()
    ..writeln('扩展内容只读取源文件真实字段：`notes` 作为注释，翻译相关字段作为翻译，'
        '`appreciation`、`analysis`、`prologue`、`comment` 作为赏析或解说。');
  File('项目文档/诗词资源导入报告.md').writeAsStringSync('$buffer');
}

Future<File> _writeOutput(String path, List<_RawPoem> poems) async {
  final output = List<_RawPoem>.of(poems)
    ..sort((a, b) => a.shuffleKey.compareTo(b.shuffleKey));
  final shared = <String>{};
  for (final poem in output) {
    shared
      ..add(poem.author)
      ..add(poem.normalizedAuthor)
      ..add(poem.dynasty)
      ..add(poem.form)
      ..add(poem.style)
      ..add(poem.theme)
      ..add(poem.emotion);
    shared.add(poem.sourceId);
  }
  final sharedStrings = shared.toList()..sort();
  final sharedIndexes = <String, int>{
    for (final entry in sharedStrings.indexed) entry.$2: entry.$1,
  };
  final offsets = Uint32List(output.length + 1);
  for (var index = 0; index < output.length; index++) {
    offsets[index + 1] = offsets[index] + _recordLength(output[index]);
  }
  final ascendingIndexes = List<int>.generate(output.length, (index) => index)
    ..sort(
      (a, b) => output[a].sequence.compareTo(output[b].sequence),
    );

  final file = File(path);
  final sink = file.openWrite();
  sink.add(PoetryBinaryCodec.signature);
  sink.add(_uint32(output.length));
  sink.add(_uint32(sharedStrings.length));
  for (final value in sharedStrings) {
    sink.add(_encodedString(value));
  }
  for (final offset in offsets) {
    sink.add(_uint32(offset));
  }
  sink.add(_uint32(ascendingIndexes.length));
  for (final index in ascendingIndexes) {
    sink.add(_uint32(index));
  }
  for (final poem in output) {
    final record = BytesBuilder(copy: false)
      ..add(_uint32(poem.sequence))
      ..add(_uint32(poem.shuffleKey))
      ..add(_uint32(sharedIndexes[poem.author]!))
      ..add(_uint32(sharedIndexes[poem.normalizedAuthor]!))
      ..add(_uint32(sharedIndexes[poem.dynasty]!))
      ..add(_uint32(sharedIndexes[poem.form]!))
      ..add(_uint32(sharedIndexes[poem.style]!))
      ..add(_uint32(sharedIndexes[poem.theme]!))
      ..add(_uint32(sharedIndexes[poem.emotion]!))
      ..add(_uint32(sharedIndexes[poem.sourceId]!))
      ..add(_encodedString(poem.id))
      ..add(_encodedString(poem.title))
      ..add(_encodedString(poem.searchText))
      ..add(_encodedString(poem.content))
      ..add(_encodedString(poem.notes))
      ..add(_encodedString(poem.translation))
      ..add(_encodedString(poem.appreciation));
    sink.add(record.takeBytes());
  }
  await sink.close();
  return file;
}

int _recordLength(_RawPoem poem) =>
    40 +
    7 * 4 +
    _utf8Length(poem.id) +
    _utf8Length(poem.title) +
    _utf8Length(poem.searchText) +
    _utf8Length(poem.content) +
    _utf8Length(poem.notes) +
    _utf8Length(poem.translation) +
    _utf8Length(poem.appreciation);

int _utf8Length(String value) => utf8.encode(value).length;

Uint8List _uint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _encodedString(String value) {
  final text = utf8.encode(value);
  final result = Uint8List(4 + text.length);
  ByteData.sublistView(result).setUint32(0, text.length, Endian.little);
  result.setRange(4, result.length, text);
  return result;
}

String _textOf(Object? value) {
  if (value is String) return _normalizeText(value);
  if (value is List) {
    return value
        .map((item) => _normalizeText(item.toString()))
        .where((item) => item.isNotEmpty)
        .join('\n');
  }
  return '';
}

List<String> _poetryLines(Object? value) {
  final rawValues = switch (value) {
    List values => values.map((item) => item.toString()),
    String text => [text],
    _ => const <String>[],
  };
  final result = <String>[];
  final sentencePattern = RegExp(r'[^。！？!?；;]+(?:[。！？!?；;]+|$)');
  for (final rawValue in rawValues) {
    final normalized = _normalizeBreaks(rawValue);
    for (final physicalLine in normalized.split('\n')) {
      final line = physicalLine.trim();
      if (line.isEmpty) continue;
      final sentences = sentencePattern
          .allMatches(line)
          .map((match) => match.group(0)!.trim())
          .where((sentence) => sentence.isNotEmpty)
          .toList();
      result.addAll(sentences.isEmpty ? [line] : sentences);
    }
  }
  return result;
}

String _normalizeText(String value) => _normalizeBreaks(value)
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .join('\n');

String _normalizeBreaks(String value) => value
    .replaceAll('\\r\\n', '\n')
    .replaceAll('\\n', '\n')
    .replaceAll('\\r', '\n')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n');

Map<int, String> _readOpenCc(String path) {
  final result = <int, String>{};
  for (final rawLine in File(path).readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final columns = line.split('\t');
    if (columns.length < 2 || columns.first.runes.length != 1) continue;
    final replacement = columns[1].trim().split(RegExp(r'\s+')).first;
    if (replacement.isNotEmpty) {
      result[columns.first.runes.first] = replacement;
    }
  }
  return result;
}

String _toSimplified(String value) {
  final result = StringBuffer();
  for (final rune in value.runes) {
    result.write(_traditionalToSimplified[rune] ?? String.fromCharCode(rune));
  }
  return result.toString();
}

String _firstText(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _textOf(json[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

_TranslationImportStats _mergeTranslationCorpus({
  required List<_RawPoem> tang,
  required List<_RawPoem> song,
  required List<_RawPoem> other,
  required Set<String> seen,
  required int firstSequence,
}) {
  final directory = Directory(_translationRoot);
  if (!directory.existsSync()) return const _TranslationImportStats();
  final byContent = <String, _RawPoem>{
    for (final poem in [...tang, ...song, ...other])
      _poemContentKey(poem.content): poem,
  };
  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.json'))
      .toList()
    ..sort((a, b) => _translationFileNumber(a.path)
        .compareTo(_translationFileNumber(b.path)));
  var sequence = firstSequence;
  var read = 0;
  var matched = 0;
  var added = 0;
  var withTranslation = 0;
  var withNotes = 0;
  var withAppreciation = 0;
  for (final file in files) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map) continue;
    final json = Map<String, dynamic>.from(decoded);
    final content = _normalizeText(json['content']?.toString() ?? '');
    final lines = _poetryLines(content);
    if (lines.length < 2) continue;
    read++;
    final supplement = _splitTranslationAndNotes(_textOf(json['fanyi']));
    final appreciation = [
      if (_textOf(json['about']).isNotEmpty) '创作背景\n${_textOf(json['about'])}',
      if (_textOf(json['shangxi']).isNotEmpty)
        '赏析\n${_textOf(json['shangxi'])}',
    ].join('\n\n');
    if (supplement.translation.isNotEmpty) withTranslation++;
    if (supplement.notes.isNotEmpty) withNotes++;
    if (appreciation.isNotEmpty) withAppreciation++;

    final key = _poemContentKey(content);
    final existing = byContent[key];
    if (existing != null) {
      matched++;
      existing
        ..translation = _mergeText(existing.translation, supplement.translation)
        ..notes = _mergeText(existing.notes, supplement.notes)
        ..appreciation = _mergeText(existing.appreciation, appreciation)
        ..sourceId = _mergeSource(
            existing.sourceId, 'chinese-ancient-poetry-translation (GPL-3.0)');
      continue;
    }

    final title = (json['name'] ?? '无题').toString().trim();
    final poet = json['poet'];
    final author =
        poet is Map ? (poet['name'] ?? '佚名').toString().trim() : '佚名';
    final dynasty = _normalizeDynasty(
      (json['dynasty'] ?? '').toString().trim(),
    );
    final tags = (json['tags'] as List? ?? const [])
        .map((item) => item.toString())
        .toList();
    final dedupeKey = '$dynasty|$author|$title|$content';
    if (!seen.add(dedupeKey)) continue;
    final poem = _RawPoem(
      title: title.isEmpty ? '无题' : title,
      author: author.isEmpty ? '佚名' : author,
      dynasty: dynasty.isEmpty ? '未详' : dynasty,
      form: _formOf('诗', lines, tags),
      style: _styleOf(title, content, tags),
      theme: _themeOf(title, content, tags),
      emotion: _emotionOf(title, content, tags),
      content: lines.join('\n'),
      notes: supplement.notes,
      translation: supplement.translation,
      appreciation: appreciation,
      sequence: sequence++,
      curated: supplement.translation.isNotEmpty || supplement.notes.isNotEmpty,
      sourceId: 'chinese-ancient-poetry-translation (GPL-3.0)',
    );
    byContent[key] = poem;
    if (dynasty.contains('唐')) {
      tang.add(poem);
    } else if (dynasty.contains('宋')) {
      song.add(poem);
    } else {
      other.add(poem);
    }
    added++;
  }
  return _TranslationImportStats(
    read: read,
    matched: matched,
    added: added,
    withTranslation: withTranslation,
    withNotes: withNotes,
    withAppreciation: withAppreciation,
  );
}

({String translation, String notes}) _splitTranslationAndNotes(String value) {
  if (value.isEmpty) return (translation: '', notes: '');
  final lines = value.split('\n');
  final translation = <String>[];
  final notes = <String>[];
  var section = lines.first.trim().startsWith('注释') ? 'notes' : 'translation';
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (RegExp(r'^译文(?:[一二三四五六七八九十\d]*)?$').hasMatch(line)) {
      section = 'translation';
      continue;
    }
    if (RegExp(r'^(注释|译注)(?:[一二三四五六七八九十\d]*)?$').hasMatch(line)) {
      section = 'notes';
      continue;
    }
    if (line.isEmpty) continue;
    (section == 'notes' ? notes : translation).add(line);
  }
  return (
    translation: translation.join('\n'),
    notes: notes.join('\n'),
  );
}

String _poemContentKey(String value) {
  final simplified = _toSimplified(value);
  return String.fromCharCodes(
    simplified.runes.where(
      (rune) =>
          (rune >= 0x3400 && rune <= 0x9fff) ||
          (rune >= 0x20000 && rune <= 0x2fa1f),
    ),
  );
}

String _mergeText(String current, String incoming) {
  if (incoming.isEmpty || current.contains(incoming)) return current;
  if (current.isEmpty) return incoming;
  return '$current\n\n$incoming';
}

String _mergeSource(String current, String incoming) =>
    current.contains(incoming) ? current : '$current + $incoming';

int _translationFileNumber(String path) =>
    int.tryParse(
      RegExp(r'poetry_(\d+)\.json$').firstMatch(path)?.group(1) ?? '',
    ) ??
    0;

String _normalizeDynasty(String value) {
  final normalized = value.replaceAll('代', '').trim();
  if (normalized.contains('先秦')) return '先秦';
  for (final dynasty in const [
    '汉',
    '魏晋',
    '南北朝',
    '隋',
    '唐',
    '五代',
    '宋',
    '辽',
    '金',
    '元',
    '明',
    '清',
    '近现代',
  ]) {
    if (normalized.contains(dynasty)) return dynasty;
  }
  return normalized;
}

List<_RawPoem> _takeStable(List<_RawPoem> source, int quota) {
  bool isDailyVerse(_RawPoem poem) => _dailyVerseClauses.any(
        (clause) => _toSimplified(poem.content).contains(clause),
      );
  bool isPriority(_RawPoem poem) =>
      poem.curated ||
      poem.notes.isNotEmpty ||
      poem.translation.isNotEmpty ||
      poem.appreciation.isNotEmpty;
  final daily = source.where(isDailyVerse).toList();
  final curated =
      source.where((poem) => !isDailyVerse(poem) && isPriority(poem)).toList();
  final rest = source
      .where((poem) => !isDailyVerse(poem) && !isPriority(poem))
      .toList()
    ..sort((a, b) => a.shuffleKey.compareTo(b.shuffleKey));
  return [...daily, ...curated, ...rest].take(quota).toList();
}

int _fileNumber(String path) =>
    int.tryParse(RegExp(r'\.(\d+)\.json$').firstMatch(path)?.group(1) ?? '') ??
    0;

String _formOf(String base, List<String> lines, List<String> tags) {
  for (final value in const [
    '五言绝句',
    '七言绝句',
    '五言律诗',
    '七言律诗',
    '乐府',
  ]) {
    if (tags.any((tag) => tag.contains(value))) return value;
  }
  if (base != '诗') return base;
  final lengths = lines.map(_hanLength).toSet();
  if (lengths.length == 1) {
    final length = lengths.first;
    if (lines.length == 4 && length == 5) return '五言绝句';
    if (lines.length == 4 && length == 7) return '七言绝句';
    if (lines.length == 8 && length == 5) return '五言律诗';
    if (lines.length == 8 && length == 7) return '七言律诗';
  }
  return '古体诗';
}

int _hanLength(String value) =>
    value.runes.where((rune) => rune >= 0x3400 && rune <= 0x9fff).length;

String _styleOf(String title, String content, List<String> tags) {
  final text = '$title$content${tags.join()}';
  if (_has(text, ['豪放', '铁马', '沙场', '壮志', '长风'])) return '豪放';
  if (_has(text, ['婉约', '闺', '红楼', '柔情'])) return '婉约';
  if (_has(text, ['边塞', '羌笛', '烽火', '戍边'])) return '雄浑';
  if (_has(text, ['田园', '桑麻', '柴门', '归隐'])) return '清新';
  if (_has(text, ['幽', '空山', '禅', '孤云'])) return '冲淡';
  return '其他';
}

String _themeOf(String title, String content, List<String> tags) {
  final text = '$title$content${tags.join()}';
  if (_has(text, ['送', '别', '留别', '赠'])) return '送别';
  if (_has(text, ['思乡', '归乡', '故乡', '客愁'])) return '思乡';
  if (_has(text, ['边塞', '出塞', '从军', '戍', '胡马'])) return '边塞';
  if (_has(text, ['怀古', '古迹', '赤壁', '金陵'])) return '怀古';
  if (_has(text, ['咏物', '咏梅', '咏竹', '咏蝉'])) return '咏物';
  if (_has(text, ['田园', '田家', '山水', '溪', '山居'])) return '山水田园';
  if (_has(text, ['七夕', '中秋', '重阳', '清明', '元宵'])) return '节令';
  if (_has(text, ['闺', '相思', '鸳鸯', '红豆'])) return '爱情闺怨';
  return '其他';
}

String _emotionOf(String title, String content, List<String> tags) {
  final text = '$title$content${tags.join()}';
  if (_has(text, ['思乡', '故乡', '归心', '独客'])) return '思乡';
  if (_has(text, ['送别', '离别', '别君', '柳色'])) return '惜别';
  if (_has(text, ['忧国', '国破', '黎民', '征夫'])) return '忧国';
  if (_has(text, ['相思', '愁', '泪', '断肠', '寂寞'])) return '悲愁';
  if (_has(text, ['壮志', '豪情', '仗剑', '长风'])) return '豪情';
  if (_has(text, ['闲', '醉', '归隐', '山居'])) return '闲适';
  return '其他';
}

bool _has(String text, List<String> values) => values.any(text.contains);

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

class _RawPoem {
  _RawPoem({
    required this.title,
    required this.author,
    required this.dynasty,
    required this.form,
    required this.style,
    required this.theme,
    required this.emotion,
    required this.content,
    required this.notes,
    required this.translation,
    required this.appreciation,
    required this.sequence,
    required this.curated,
    required this.sourceId,
  });

  final String title;
  final String author;
  final String dynasty;
  final String form;
  final String style;
  final String theme;
  final String emotion;
  final String content;
  String notes;
  String translation;
  String appreciation;
  String sourceId;
  final int sequence;
  final bool curated;

  late final int shuffleKey = _stableHash('$dynasty|$author|$title|$content');

  late final String id = 'poetry-${shuffleKey.toRadixString(16)}-$sequence';

  late final String normalizedAuthor = _toSimplified(author);

  late final String searchText =
      _toSimplified('$title$author$content').toLowerCase().replaceAll(
            RegExp(r'\s+'),
            '',
          );
}

class _TranslationImportStats {
  const _TranslationImportStats({
    this.read = 0,
    this.matched = 0,
    this.added = 0,
    this.withTranslation = 0,
    this.withNotes = 0,
    this.withAppreciation = 0,
  });

  final int read;
  final int matched;
  final int added;
  final int withTranslation;
  final int withNotes;
  final int withAppreciation;
}
