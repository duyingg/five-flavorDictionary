import 'dart:convert';
import 'dart:io';

import 'package:wuwei_dictionary/core/language/pinyin_utils.dart';

const _sourceDirectory = 'Aatime/chinese-dictionary-main/character';
const _outputPath = 'assets/data/chinese_entries_v3.json';
const _wubiSourcePath = 'Aatime/rime-wubi/wubi86.dict.yaml';
const _invalidPinyinReportPath = '项目文档/损坏拼音核对报告.md';
const _polyphonicLearningAssetPath = 'assets/data/polyphonic_lessons.json';
const _polyphonicWorkbookPath = '项目文档/多音字学习字库总表.md';
const _allPolyphonicReportPath = '项目文档/一二级全部多音字清单_剔除难检字.md';
const _commonPolyphonicReportPath = '项目文档/常用100个多音字候选.md';
const _coverageReportPath = '项目文档/字库覆盖统计.md';

final _invalidPinyin = <({String character, String location, String pinyin})>[];

Map<String, String> _readWubiCodes(File file) {
  if (!file.existsSync()) return const {};
  final candidates = <String, Set<String>>{};
  for (final line in file.readAsLinesSync()) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final columns = line.split('\t');
    if (columns.length < 2 || columns.first.runes.length != 1) continue;
    final code = columns[1].trim();
    if (!RegExp(r'^[a-z]{1,4}$').hasMatch(code)) continue;
    candidates.putIfAbsent(columns.first, () => {}).add(code.toUpperCase());
  }
  return {
    for (final item in candidates.entries)
      item.key: () {
        final longest = item.value.map((code) => code.length).reduce(
              (left, right) => left > right ? left : right,
            );
        final sorted =
            item.value.where((code) => code.length == longest).toList()..sort();
        return sorted.join(' / ');
      }(),
  };
}

const _correctedSourceReadings = <String, Map<String, String>>{
  '兙': {'shíkě': 'shí kè'},
  '兛': {'qiānkè': 'qiān kè'},
  '兡': {'bǎikè': 'bǎi kè'},
  '浔': {'hǎixún': 'hǎi xún'},
  '浬': {'hǎilǐ': 'hǎi lǐ'},
  '瓧': {'shíwǎ': 'shí wǎ'},
  '瓩': {'qiānwǎ': 'qiān wǎ'},
  '瓰': {'fēnwǎ': 'fēn wǎ'},
  '瓱': {'máowǎ': 'máo wǎ'},
  '瓲': {'túnwǎ': 'tún wǎ'},
  '瓸': {'bǎiwǎ': 'bǎi wǎ'},
  '瓼': {'lǐwǎ': 'lǐ wǎ'},
  '甅': {'líwǎ': 'lí wǎ'},
  '圕': {'tuān': 'tuǎn'},
  '砼': {'tónɡ': 'tóng'},
};

const _additionalReadings = <String, List<String>>{
  '圕': ['tú shū guǎn'],
  '砼': ['hùn níng tǔ'],
};

const _commonLearningReadings = <String, List<String>>{
  '行': ['xíng', 'háng'],
  '乐': ['lè', 'yuè'],
  '长': ['cháng', 'zhǎng'],
  '重': ['zhòng', 'chóng'],
  '还': ['hái', 'huán'],
  '只': ['zhī', 'zhǐ'],
  '觉': ['jué', 'jiào'],
  '处': ['chǔ', 'chù'],
  '种': ['zhǒng', 'zhòng'],
  '得': ['dé', 'děi', 'de'],
  '地': ['dì', 'de'],
  '的': ['de', 'dí', 'dì'],
  '着': ['zhe', 'zháo', 'zhuó', 'zhāo'],
  '都': ['dōu', 'dū'],
  '好': ['hǎo', 'hào'],
  '为': ['wéi', 'wèi'],
  '当': ['dāng', 'dàng'],
  '发': ['fā', 'fà'],
  '干': ['gān', 'gàn'],
  '空': ['kōng', 'kòng'],
  '看': ['kàn', 'kān'],
  '间': ['jiān', 'jiàn'],
  '少': ['shǎo', 'shào'],
  '数': ['shù', 'shǔ', 'shuò'],
  '转': ['zhuǎn', 'zhuàn'],
  '教': ['jiāo', 'jiào'],
  '背': ['bēi', 'bèi'],
  '便': ['biàn', 'pián'],
  '藏': ['cáng', 'zàng'],
  '差': ['chā', 'chà', 'chāi', 'cī'],
  '朝': ['cháo', 'zhāo'],
  '传': ['chuán', 'zhuàn'],
  '角': ['jiǎo', 'jué'],
  '假': ['jiǎ', 'jià'],
  '累': ['lèi', 'lěi', 'léi'],
  '量': ['liáng', 'liàng'],
  '难': ['nán', 'nàn'],
  '强': ['qiáng', 'qiǎng', 'jiàng'],
  '曲': ['qū', 'qǔ'],
  '散': ['sǎn', 'sàn'],
  '似': ['sì', 'shì'],
  '相': ['xiāng', 'xiàng'],
  '应': ['yīng', 'yìng'],
  '作': ['zuò', 'zuō'],
  '钻': ['zuān', 'zuàn'],
  '盛': ['shèng', 'chéng'],
  '倒': ['dǎo', 'dào'],
  '调': ['tiáo', 'diào'],
  '更': ['gēng', 'gèng'],
  '供': ['gōng', 'gòng'],
  '冠': ['guān', 'guàn'],
  '号': ['hào', 'háo'],
  '划': ['huá', 'huà'],
  '结': ['jié', 'jiē'],
  '解': ['jiě', 'jiè', 'xiè'],
  '禁': ['jīn', 'jìn'],
  '尽': ['jǐn', 'jìn'],
  '壳': ['ké', 'qiào'],
  '露': ['lù', 'lòu'],
  '落': ['luò', 'là', 'lào'],
  '闷': ['mēn', 'mèn'],
  '模': ['mó', 'mú'],
  '磨': ['mó', 'mò'],
  '宁': ['níng', 'nìng'],
  '铺': ['pū', 'pù'],
  '圈': ['quān', 'juàn'],
  '舍': ['shě', 'shè'],
  '熟': ['shú', 'shóu'],
  '说': ['shuō', 'shuì'],
  '提': ['tí', 'dī'],
  '挑': ['tiāo', 'tiǎo'],
  '系': ['xì', 'jì'],
  '鲜': ['xiān', 'xiǎn'],
  '兴': ['xīng', 'xìng'],
  '血': ['xuè', 'xiě'],
  '咽': ['yān', 'yàn', 'yè'],
  '要': ['yào', 'yāo'],
  '饮': ['yǐn', 'yìn'],
  '载': ['zǎi', 'zài'],
  '炸': ['zhà', 'zhá'],
  '占': ['zhàn', 'zhān'],
  '挣': ['zhèng', 'zhēng'],
  '正': ['zhèng', 'zhēng'],
  '中': ['zhōng', 'zhòng'],
  '冲': ['chōng', 'chòng'],
  '称': ['chēng', 'chèn'],
  '杆': ['gān', 'gǎn'],
  '降': ['jiàng', 'xiáng'],
  '扇': ['shàn', 'shān'],
  '弹': ['dàn', 'tán'],
  '泊': ['bó', 'pō'],
  '薄': ['báo', 'bó', 'bò'],
  '单': ['dān', 'shàn', 'chán'],
  '曾': ['céng', 'zēng'],
  '任': ['rèn', 'rén'],
  '华': ['huá', 'huà'],
  '区': ['qū', 'ōu'],
  '仇': ['chóu', 'qiú'],
  '校': ['xiào', 'jiào'],
  '塞': ['sāi', 'sài', 'sè'],
};

void main() {
  final baseFile = File('$_sourceDirectory/char_base.json');
  final detailFile = File('$_sourceDirectory/char_detail.json');
  if (!baseFile.existsSync() || !detailFile.existsSync()) {
    stderr.writeln('chinese-dictionary-main character files were not found.');
    exitCode = 1;
    return;
  }

  final bases = _readObjectSequence(baseFile);
  final details = _readObjectSequence(detailFile);
  final wubiByCharacter = _readWubiCodes(File(_wubiSourcePath));
  final detailByCharacter = <String, Map<String, dynamic>>{
    for (final detail in details)
      if (detail['char'] case final String character) character: detail,
  };

  final traditionalBySimplified = <String, List<String>>{};
  final simplifiedByTraditional = <String, Set<String>>{};
  final indexByCharacter = <String, int>{};
  for (final base in bases) {
    final character = base['char'] as String? ?? '';
    indexByCharacter[character] = base['index'] as int? ?? 0;
    final traditional = _characters(base['traditional']);
    if (character.isEmpty || traditional.isEmpty) continue;
    traditionalBySimplified[character] = traditional;
    for (final form in traditional) {
      simplifiedByTraditional.putIfAbsent(form, () => {}).add(character);
    }
  }

  final output = <Map<String, dynamic>>[];
  var senseCount = 0;
  var strokeAssetCount = 0;
  for (final base in bases) {
    final character = base['char'] as String? ?? '';
    final strokeCount = base['strokes'] as int? ?? 0;
    if (character.isEmpty || strokeCount <= 0) continue;
    final codePoint = character.runes.first;
    final traditionalForms = traditionalBySimplified[character] ?? const [];
    final simplifiedForms = simplifiedByTraditional[character]?.toList() ?? [];
    final variants = _characters(base['variant'])..remove(character);
    final detail = detailByCharacter[character];
    final senses = <Map<String, dynamic>>[
      ..._senses(detail),
      ..._manualSenses(character),
    ];
    final pinyin = <String>[];
    for (final reading in _strings(base['pinyin'])) {
      final corrected = _correctedReading(character, reading);
      if (corrected != null) {
        _addReading(pinyin, corrected);
      } else if (PinyinUtils.isValidSyllable(reading)) {
        _addReading(pinyin, reading);
      } else {
        _recordInvalidPinyin(character, '基础字表', reading);
      }
    }
    for (final rawPronunciation in _list(detail?['pronunciations'])) {
      if (rawPronunciation is! Map) continue;
      final reading = (rawPronunciation['pinyin'] as String? ?? '').trim();
      if (reading.isEmpty) continue;
      final corrected = _correctedReading(character, reading);
      if (corrected != null) {
        _addReading(pinyin, corrected);
      } else if (PinyinUtils.isValidSyllable(reading)) {
        _addReading(pinyin, reading);
      } else {
        _recordInvalidPinyin(character, '逐音释义', reading);
      }
    }
    for (final reading in _additionalReadings[character] ?? const []) {
      _addReading(pinyin, reading);
    }
    senseCount += senses.length;
    final strokeAsset = 'Aatime/makemeahanzi-master/svgs/$codePoint.svg';
    final hasStrokeAsset = File(strokeAsset).existsSync();
    if (hasStrokeAsset) strokeAssetCount++;
    final radical = (base['radicals'] as String? ?? '').trim();
    final hasSimplifiedRelation = traditionalForms.isNotEmpty;
    final hasTraditionalRelation = simplifiedForms.isNotEmpty;

    output.add({
      'character': character,
      'sourceIndex': base['index'] as int? ?? 0,
      'pinyin': pinyin,
      'wubi': wubiByCharacter[character] ?? '',
      'radical': radical,
      'strokeCount': strokeCount,
      'structure': _structure(base['structure'] as String?),
      'unicode':
          'U+${codePoint.toRadixString(16).toUpperCase().padLeft(4, '0')}',
      'traditional': traditionalForms.firstOrNull,
      'variants': variants,
      'senses': senses,
      'difficult': radical.isEmpty ||
          radical == '？' ||
          !RadicalUtils.isStandard(radical),
      'strokeOrderAsset': hasStrokeAsset ? strokeAsset : null,
      'script': hasSimplifiedRelation && !hasTraditionalRelation
          ? 'simplified'
          : hasTraditionalRelation && !hasSimplifiedRelation
              ? 'traditional'
              : 'common',
      'simplifiedForms': simplifiedForms,
      'traditionalForms': traditionalForms,
      'characterLevel': _level(base['frequency'] as int?),
      'sourceId': hasStrokeAsset
          ? 'chinese-dictionary-main + Make Me a Hanzi（仅笔顺）'
          : 'chinese-dictionary-main',
    });
  }

  output.sort((a, b) => (indexByCharacter[a['character']] ?? 0)
      .compareTo(indexByCharacter[b['character']] ?? 0));
  File(_outputPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  _writeInvalidPinyinReport(output);
  final lessons = _readPolyphonicLessons(output);
  _writePolyphonicLearningAsset(lessons);
  _writePolyphonicWorkbook(output, lessons);
  _writeCoverageReport(output);

  final levels = <int, int>{};
  for (final entry in output) {
    final level = entry['characterLevel'] as int;
    levels[level] = (levels[level] ?? 0) + 1;
  }
  stdout.writeln('Imported ${output.length} unique character entries.');
  stdout.writeln('Levels: $levels');
  stdout.writeln('Senses: $senseCount');
  stdout.writeln(
      'Wubi codes: ${output.where((entry) => (entry['wubi'] as String).isNotEmpty).length}');
  stdout.writeln('Stroke SVG links: $strokeAssetCount');
  stdout.writeln(
    'Rejected pinyin records: ${_invalidPinyin.toSet().length} '
    '($_invalidPinyinReportPath)',
  );
  stdout.writeln(
    'Reports: $_polyphonicWorkbookPath, $_coverageReportPath',
  );
}

List<Map<String, dynamic>> _readObjectSequence(File file) {
  var raw = file.readAsStringSync().trim();
  if (raw.endsWith(',')) raw = raw.substring(0, raw.length - 1);
  final decoded = jsonDecode('[$raw]') as List;
  return decoded
      .map((value) => Map<String, dynamic>.from(value as Map))
      .toList(growable: false);
}

List<Map<String, dynamic>> _senses(Map<String, dynamic>? detail) {
  if (detail == null) return const [];
  final result = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final rawPronunciation in _list(detail['pronunciations'])) {
    if (rawPronunciation is! Map) continue;
    final pronunciation = Map<String, dynamic>.from(rawPronunciation);
    final sourcePinyin = (pronunciation['pinyin'] as String? ?? '').trim();
    final character = detail['char'] as String? ?? '';
    final corrected = _correctedReading(character, sourcePinyin);
    final pinyin = corrected ?? sourcePinyin;
    if (pinyin.isNotEmpty &&
        corrected == null &&
        !PinyinUtils.isValidSyllable(pinyin)) {
      _recordInvalidPinyin(
        character,
        '逐音释义',
        pinyin,
      );
      continue;
    }
    for (final rawExplanation in _list(pronunciation['explanations'])) {
      if (rawExplanation is! Map) continue;
      final explanation = Map<String, dynamic>.from(rawExplanation);
      final definition = _definition(explanation);
      if (definition.isEmpty || !seen.add('$pinyin\u0000$definition')) continue;
      final examples = <String>[];
      final example = explanation['example'];
      if (example is String && example.trim().isNotEmpty) {
        examples.add(example.trim());
      }
      for (final rawDetail in _list(explanation['detail']).take(2)) {
        if (rawDetail is! Map) continue;
        final item = Map<String, dynamic>.from(rawDetail);
        final text = (item['text'] as String? ?? '').trim();
        final book = (item['book'] as String? ?? '').trim();
        if (text.isNotEmpty) examples.add(book.isEmpty ? text : '$text（$book）');
      }
      result.add({
        'pinyin': pinyin,
        if ((explanation['speech'] as String? ?? '').trim().isNotEmpty)
          'partOfSpeech': (explanation['speech'] as String).trim(),
        'definition': definition,
        'examples': examples,
      });
    }
  }
  return result;
}

String _definition(Map<String, dynamic> value) {
  final content = value['content'];
  if (content is String && content.trim().isNotEmpty) return content.trim();
  for (final candidate in const [
    ('simplified', '简体字为“%s”。'),
    ('variant', '“%s”的异体字。'),
    ('same', '同“%s”。'),
    ('modern', '今作“%s”。'),
    ('refer', '参见“%s”。'),
    ('typo', '“%s”的讹字。'),
  ]) {
    final replacement = value[candidate.$1];
    if (replacement is String && replacement.trim().isNotEmpty) {
      return candidate.$2.replaceFirst('%s', replacement.trim());
    }
  }
  return '';
}

String? _correctedReading(String character, String sourceReading) {
  final corrections = _correctedSourceReadings[character];
  if (corrections == null) return null;
  return corrections[sourceReading] ??
      (corrections.values.contains(sourceReading) ? sourceReading : null);
}

List<Map<String, dynamic>> _manualSenses(String character) =>
    switch (character) {
      '圕' => [
          {
            'pinyin': 'tuǎn',
            'definition': '拼音读音，多用于现代拼音输入法输入。',
            'examples': <String>[],
          },
          {
            'pinyin': 'tú shū guǎn',
            'definition': '传统复读音，读作“图书馆”。',
            'examples': <String>[],
          },
        ],
      '砼' => [
          {
            'pinyin': 'tóng',
            'definition': '“混凝土”的单字替代字，读音同“同”。',
            'examples': <String>[],
          },
          {
            'pinyin': 'hùn níng tǔ',
            'definition': '传统复读音，读作“混凝土”。',
            'examples': <String>[],
          },
        ],
      _ => const [],
    };

void _recordInvalidPinyin(String character, String location, String pinyin) {
  _invalidPinyin.add((
    character: character,
    location: location,
    pinyin: pinyin,
  ));
}

void _addReading(List<String> target, String reading) {
  final normalized = PinyinUtils.normalize(reading);
  final tone = PinyinUtils.toneOf(reading);
  if (target.any((value) =>
      PinyinUtils.normalize(value) == normalized &&
      PinyinUtils.toneOf(value) == tone)) {
    return;
  }
  target.add(reading);
}

void _writeInvalidPinyinReport(List<Map<String, dynamic>> output) {
  final records = _invalidPinyin.toSet().toList()
    ..sort((a, b) {
      final character = a.character.compareTo(b.character);
      if (character != 0) return character;
      final location = a.location.compareTo(b.location);
      return location != 0 ? location : a.pinyin.compareTo(b.pinyin);
    });
  final uniqueValues = records.map((record) => record.pinyin).toSet().toList()
    ..sort();
  final charactersWithoutReading = output
      .where((entry) => (entry['pinyin'] as List).isEmpty)
      .map((entry) => entry['character'] as String)
      .toList();
  final buffer = StringBuffer()
    ..writeln('# chinese-dictionary-main 损坏拼音核对报告')
    ..writeln()
    ..writeln('本报告由 `dart run tool/import_chinese_dictionary.dart` 自动生成。')
    ..writeln('以下值未通过“单个普通话音节”形态校验，因此未进入应用拼音索引。')
    ..writeln('这只代表格式可疑，不直接断言原字的正确读音；请结合权威字典人工核对。')
    ..writeln()
    ..writeln('- 涉及记录：${records.length} 条')
    ..writeln('- 不同可疑值：${uniqueValues.length} 个')
    ..writeln('- 基础字表：${records.where((r) => r.location == '基础字表').length} 条')
    ..writeln('- 逐音释义：${records.where((r) => r.location == '逐音释义').length} 条')
    ..writeln('- 清洗后无可用读音字头：${charactersWithoutReading.length} 个')
    ..writeln()
    ..writeln('## 清洗后无可用读音的字头')
    ..writeln()
    ..writeln(charactersWithoutReading.join('、'))
    ..writeln()
    ..writeln('## 可疑值汇总')
    ..writeln();
  for (var start = 0; start < uniqueValues.length; start += 12) {
    final end = (start + 12).clamp(0, uniqueValues.length);
    buffer.writeln(
      '- ${uniqueValues.sublist(start, end).map((value) => '`$value`').join('、')}',
    );
  }
  buffer
    ..writeln()
    ..writeln('## 逐条核对')
    ..writeln()
    ..writeln('| 汉字 | 出现位置 | 原始拼音 |')
    ..writeln('|---|---|---|');
  for (final record in records) {
    buffer.writeln(
      '| ${_markdownCell(record.character)} | ${record.location} | '
      '`${_markdownCell(record.pinyin)}` |',
    );
  }
  File(_invalidPinyinReportPath).writeAsStringSync('$buffer');
}

bool _isLearningPolyphonicCandidate(Map<String, dynamic> entry) {
  final readings = List<String>.from(entry['pinyin'] as List);
  final inDifficultIndex =
      entry['difficult'] == true || readings.any(PinyinUtils.isCompoundReading);
  return readings.length > 1 &&
      !inDifficultIndex &&
      (entry['characterLevel'] == 1 || entry['characterLevel'] == 2);
}

// ignore: unused_element
void _writeAllPolyphonicReport(List<Map<String, dynamic>> output) {
  final selected = output.where(_isLearningPolyphonicCandidate).toList()
    ..sort(
        (a, b) => (a['sourceIndex'] as int).compareTo(b['sourceIndex'] as int));
  final level1Count =
      selected.where((entry) => entry['characterLevel'] == 1).length;
  final level2Count =
      selected.where((entry) => entry['characterLevel'] == 2).length;
  final buffer = StringBuffer()
    ..writeln('# 一、二级全部多音字清单（剔除难检字）')
    ..writeln()
    ..writeln('本报告由 `dart run tool/import_chinese_dictionary.dart` 自动生成。')
    ..writeln('收录一级、二级全部多音字，剔除难检字索引中的全部字头及复读音，按源字表序号正序排列。')
    ..writeln()
    ..writeln('- 合计：${selected.length} 个')
    ..writeln('- 一级字：$level1Count 个')
    ..writeln('- 二级字：$level2Count 个')
    ..writeln()
    ..writeln('| 序号 | 汉字 | 字级 | 全部读音 | 源字表序号 |')
    ..writeln('|---:|:---:|:---:|---|---:|');
  for (var index = 0; index < selected.length; index++) {
    final entry = selected[index];
    buffer.writeln(
      '| ${index + 1} | ${entry['character']} | '
      '${entry['characterLevel']} | ${(entry['pinyin'] as List).join('、')} | '
      '${entry['sourceIndex']} |',
    );
  }
  File(_allPolyphonicReportPath).writeAsStringSync('$buffer');
}

// ignore: unused_element
void _writeCommonPolyphonicReport(List<Map<String, dynamic>> output) {
  final candidates = <({
    Map<String, dynamic> entry,
    List<String> kept,
    List<String> omitted,
  })>[];
  final entriesByCharacter = {
    for (final entry in output.where(_isLearningPolyphonicCandidate))
      entry['character'] as String: entry,
  };
  for (final configured in _commonLearningReadings.entries) {
    final entry = entriesByCharacter[configured.key];
    if (entry == null) continue;
    final requestedKeys = configured.value.map(_readingKey).toSet();
    final sourceReadings = List<String>.from(entry['pinyin'] as List);
    final kept = sourceReadings
        .where((reading) => requestedKeys.contains(_readingKey(reading)))
        .toList();
    final omitted = sourceReadings
        .where((reading) => !requestedKeys.contains(_readingKey(reading)))
        .toList();
    if (kept.length >= 2) {
      candidates.add((
        entry: entry,
        kept: kept,
        omitted: omitted,
      ));
    }
  }
  final selected = candidates
    ..sort((a, b) => (a.entry['sourceIndex'] as int)
        .compareTo(b.entry['sourceIndex'] as int));
  final buffer = StringBuffer()
    ..writeln('# 常用 100 个多音字候选')
    ..writeln()
    ..writeln('> 状态：待人工核对；核对完成前不直接作为学习题库。')
    ..writeln()
    ..writeln('筛选口径：人工预选现代生活中常用的字与读音；保留常见姓氏音；')
    ..writeln('古音、方言音和仅见于生僻古语的读音列入“暂不采用”；姓氏标记依据源释义生成。')
    ..writeln()
    ..writeln('| 序号 | 核对 | 汉字 | 字级 | 拟采用的常用音 | 暂不采用的生僻音 |')
    ..writeln('|---:|:---:|:---:|:---:|---|---|');
  for (var index = 0; index < selected.length; index++) {
    final candidate = selected[index];
    final entry = candidate.entry;
    final character = entry['character'] as String;
    final readings = candidate.kept
        .map((reading) =>
            _isSurnameReading(entry, reading) ? '$reading（含姓氏用法）' : reading)
        .join('、');
    buffer.writeln(
      '| ${index + 1} | ☐ | $character | ${entry['characterLevel']} | '
      '$readings | ${candidate.omitted.isEmpty ? '—' : candidate.omitted.join('、')} |',
    );
  }
  File(_commonPolyphonicReportPath).writeAsStringSync('$buffer');
}

String _readingKey(String reading) =>
    '${PinyinUtils.normalize(reading)}#${PinyinUtils.toneOf(reading)}';

bool _isSurnameReading(Map<String, dynamic> entry, String reading) {
  final key = _readingKey(reading);
  for (final rawSense in entry['senses'] as List) {
    final sense = rawSense as Map<String, dynamic>;
    if (_readingKey(sense['pinyin'] as String? ?? '') == key &&
        (sense['definition'] as String? ?? '').contains('姓')) {
      return true;
    }
  }
  return false;
}

List<_LessonRow> _readPolyphonicLessons(List<Map<String, dynamic>> dictionary) {
  final file = File('Aatime/多音字.txt');
  if (!file.existsSync()) return const [];
  final result = <_LessonRow>[];
  final seen = <String>{};
  final pattern = RegExp(
    r'^\|\s*(\d+)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|$',
  );
  for (final line in file.readAsLinesSync()) {
    if (RegExp(r'^\|\s*58\s*\|\s*单\s*\|\s*\|$').hasMatch(line.trim())) {
      final entry = dictionary.firstWhere(
        (item) => item['character'] == '单',
        orElse: () => const <String, dynamic>{},
      );
      final readings = List<String>.from(entry['pinyin'] as List? ?? const []);
      const phraseByReading = <String, String>{
        'dān': '单独',
        'shàn': '单县',
        'chán': '单于',
      };
      if (readings.length >= 2 && readings.every(PinyinUtils.isValidSyllable)) {
        seen.add('单');
        result.add(_LessonRow(
          level: result.length + 1,
          sourceRow: 58,
          character: '单',
          readings: readings,
          phrases: [
            for (final reading in readings) phraseByReading[reading] ?? '单'
          ],
          meanings: _lessonMeanings(dictionary, '单', readings),
        ));
      }
      continue;
    }
    final match = pattern.firstMatch(line.trim());
    if (match == null) continue;
    final sourceRow = int.tryParse(match.group(1)!) ?? 0;
    final character = match.group(2)!.trim();
    var readings = match
        .group(3)!
        .split('/')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    var phrases = match
        .group(4)!
        .split('/')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (character == '单' && (readings.isEmpty || phrases.isEmpty)) {
      final entry = dictionary.firstWhere(
        (item) => item['character'] == character,
        orElse: () => const <String, dynamic>{},
      );
      readings = List<String>.from(entry['pinyin'] as List? ?? const []);
      const phraseByReading = <String, String>{
        'dān': '单独',
        'shàn': '单县',
        'chán': '单于',
      };
      phrases = [
        for (final reading in readings) phraseByReading[reading] ?? '单'
      ];
    }
    if (sourceRow <= 0 ||
        character.runes.length != 1 ||
        readings.length < 2 ||
        phrases.length < readings.length ||
        !readings.every(PinyinUtils.isValidSyllable) ||
        !seen.add(character)) {
      continue;
    }
    result.add(_LessonRow(
      level: result.length + 1,
      sourceRow: sourceRow,
      character: character,
      readings: readings,
      phrases: phrases.take(readings.length).toList(),
      meanings: _lessonMeanings(dictionary, character, readings),
    ));
  }
  return result;
}

void _writePolyphonicLearningAsset(List<_LessonRow> lessons) {
  final data = [
    for (final lesson in lessons)
      {
        'level': lesson.level,
        'sourceRow': lesson.sourceRow,
        'character': lesson.character,
        'readings': lesson.readings,
        'phrases': lesson.phrases,
        'meanings': lesson.meanings,
      },
  ];
  File(_polyphonicLearningAssetPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(data)}\n',
  );
}

void _writePolyphonicWorkbook(
  List<Map<String, dynamic>> output,
  List<_LessonRow> lessons,
) {
  final all = output.where(_isLearningPolyphonicCandidate).toList()
    ..sort(
        (a, b) => (a['sourceIndex'] as int).compareTo(b['sourceIndex'] as int));
  final level1Count = all.where((entry) => entry['characterLevel'] == 1).length;
  final level2Count = all.where((entry) => entry['characterLevel'] == 2).length;
  final buffer = StringBuffer()
    ..writeln('# 多音字学习字库总表')
    ..writeln()
    ..writeln('## 一、闯关模式关卡表')
    ..writeln()
    ..writeln('来源：`Aatime/多音字.txt`。有效且不重复关卡 ${lessons.length} 关。')
    ..writeln('原表第 58 行“单”的读音由主字典资源补入，例词按对应释义补为“单独、单县、单于”。')
    ..writeln()
    ..writeln('| 关卡 | 原序号 | 汉字 | 读音与词组 |')
    ..writeln('|---:|---:|:---:|---|');
  for (final lesson in lessons) {
    final pairs = <String>[];
    for (var index = 0; index < lesson.readings.length; index++) {
      pairs.add('${lesson.readings[index]}—${lesson.phrases[index]}');
    }
    buffer.writeln(
      '| ${lesson.level} | ${lesson.sourceRow} | ${lesson.character} | '
      '${pairs.join('；')} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## 二、一、二级全部多音字（剔除难检字）')
    ..writeln()
    ..writeln('- 合计：${all.length} 个')
    ..writeln('- 一级字：$level1Count 个')
    ..writeln('- 二级字：$level2Count 个')
    ..writeln()
    ..writeln('| 序号 | 汉字 | 字级 | 全部读音 | 源字表序号 |')
    ..writeln('|---:|:---:|:---:|---|---:|');
  for (var index = 0; index < all.length; index++) {
    final entry = all[index];
    buffer.writeln(
      '| ${index + 1} | ${entry['character']} | ${entry['characterLevel']} | '
      '${(entry['pinyin'] as List).join('、')} | ${entry['sourceIndex']} |',
    );
  }
  File(_polyphonicWorkbookPath).writeAsStringSync('$buffer');
}

class _LessonRow {
  const _LessonRow({
    required this.level,
    required this.sourceRow,
    required this.character,
    required this.readings,
    required this.phrases,
    required this.meanings,
  });

  final int level;
  final int sourceRow;
  final String character;
  final List<String> readings;
  final List<String> phrases;
  final List<String> meanings;
}

List<String> _lessonMeanings(
  List<Map<String, dynamic>> dictionary,
  String character,
  List<String> readings,
) {
  final entry = dictionary.firstWhere(
    (item) => item['character'] == character,
    orElse: () => const <String, dynamic>{},
  );
  final senses = entry['senses'] as List? ?? const [];
  return [
    for (final reading in readings)
      senses
          .whereType<Map>()
          .where((sense) =>
              _readingKey(sense['pinyin']?.toString() ?? '') ==
              _readingKey(reading))
          .map((sense) => sense['definition']?.toString().trim() ?? '')
          .where((definition) => definition.isNotEmpty)
          .take(3)
          .join('；')
  ];
}

void _writeCoverageReport(List<Map<String, dynamic>> output) {
  final linkedStrokeAssets = output
      .map((entry) => entry['strokeOrderAsset'])
      .whereType<String>()
      .toSet();
  final svgDirectory = Directory('Aatime/makemeahanzi-master/svgs');
  final svgFiles = svgDirectory.existsSync()
      ? svgDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.svg'))
          .toList()
      : <File>[];
  final extraFiles = svgFiles.where((file) {
    final name = file.uri.pathSegments.last;
    return !linkedStrokeAssets
        .contains('Aatime/makemeahanzi-master/svgs/$name');
  }).toList();
  final extraCharacters = <String>[];
  for (final file in extraFiles) {
    final name = file.uri.pathSegments.last.replaceFirst('.svg', '');
    final codePoint = int.tryParse(name);
    extraCharacters
        .add(codePoint == null ? name : String.fromCharCode(codePoint));
  }
  final withSenses =
      output.where((entry) => (entry['senses'] as List).isNotEmpty).length;
  final buffer = StringBuffer()
    ..writeln('# 字库覆盖统计')
    ..writeln()
    ..writeln('本报告由 `dart run tool/import_chinese_dictionary.dart` 自动生成。')
    ..writeln()
    ..writeln('| 统计项 | 数量 | 口径 |')
    ..writeln('|---|---:|---|')
    ..writeln('| 当前总收录字数 | ${output.length} | 有效且唯一的字头 |')
    ..writeln('| 有释义字数 | $withSenses | 至少保留一条清洗后释义 |')
    ..writeln('| 有笔顺字数 | ${linkedStrokeAssets.length} | 新字库成功关联的 SVG |')
    ..writeln('| 笔顺资源总数 | ${svgFiles.length} | Make Me a Hanzi SVG 文件 |')
    ..writeln('| 笔顺多余字数 | ${extraFiles.length} | 有 SVG、但当前新字库未关联 |')
    ..writeln()
    ..writeln('## 未被当前字库使用的笔顺字头')
    ..writeln()
    ..writeln(extraCharacters.join('、'));
  File(_coverageReportPath).writeAsStringSync('$buffer');
}

String _markdownCell(String value) =>
    value.replaceAll('|', r'\|').replaceAll('\n', ' ').replaceAll('`', r'\`');

List<dynamic> _list(dynamic value) => value is List ? value : const [];

List<String> _strings(dynamic value) => _list(value)
    .whereType<String>()
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toSet()
    .toList();

List<String> _characters(dynamic value) {
  if (value is! String) return [];
  return value.runes.map(String.fromCharCode).toSet().toList();
}

int _level(int? frequency) => switch (frequency) {
      0 || 1 || 2 => 1,
      3 => 2,
      _ => 3,
    };

String _structure(String? code) => switch (code) {
      'A0' => '品字形结构',
      'D1' => '镶嵌结构',
      'B0' || 'B1' || 'B2' || 'B3' => '上下结构',
      'B4' => '田字结构',
      'E0' || 'E1' || 'E2' => '上中下结构',
      'H0' || 'H1' || 'H2' || 'H3' => '左右结构',
      'M0' || 'M1' || 'M2' => '左中右结构',
      'Q0' => '全包围结构',
      'R0' || 'R1' || 'R2' || 'R3' || 'R4' || 'R5' || 'R6' => '半包围结构',
      _ => '独体结构',
    };
