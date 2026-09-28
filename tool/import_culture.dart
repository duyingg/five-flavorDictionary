import 'dart:convert';
import 'dart:io';

import 'package:wuwei_dictionary/features/culture/school_books.dart';

void main() {
  final passageDirectory = Directory('assets/data/culture_passages');
  if (passageDirectory.existsSync()) {
    passageDirectory.deleteSync(recursive: true);
  }
  passageDirectory.createSync(recursive: true);

  final surnameFile = File('Aatime/百家姓.txt');
  if (!surnameFile.existsSync()) {
    stderr.writeln('未找到 Aatime/百家姓.txt');
    exitCode = 1;
    return;
  }

  final normalizedSurnameReading = surnameFile
      .readAsLinesSync()
      .where((line) => line.trim().isNotEmpty && !line.contains('百家姓终'))
      .join('\n')
      // 原文件中的几处括号、空格录入错误会破坏姓氏与读音的配对。
      .replaceAll('郤(xì)) 璩(qú) 桑(sāng 桂(guì)', '郤(xì) 璩(qú) 桑(sāng) 桂(guì)')
      .replaceAll('汝(rǔ)鄢(yān)', '汝(rǔ) 鄢(yān)')
      .replaceAll('归(guī) 海 (hǎi)', '归海(guī hǎi)')
      .replaceAll('微(wēi) 生(shēng)', '微生(wēi shēng)');
  final surnameEntries = <(String, String)>[];
  for (final match in RegExp(r'([^\s()]+)\(([^)]+)\)')
      .allMatches(normalizedSurnameReading)) {
    surnameEntries.add((match.group(1)!, match.group(2)!.trim()));
  }
  // 结尾也是正文的一部分：第五言福｜百家姓终。
  surnameEntries.addAll(const [
    ('百', 'bǎi'),
    ('家', 'jiā'),
    ('姓', 'xìng'),
    ('终', 'zhōng'),
  ]);
  final surnameSentences = _surnameSentences(surnameEntries);
  final surnameContent = surnameSentences
      .map((sentence) => sentence.map((entry) => entry.$1).join())
      .join('\n');
  final surnameReading = surnameSentences
      .map((sentence) =>
          sentence.map((entry) => '${entry.$1}(${entry.$2})').join(' '))
      .join('\n');

  final items = <Map<String, dynamic>>[
    ..._schools,
    ..._classicalItems(passageDirectory),
    {
      'id': 'other-surnames',
      'category': 'other',
      'title': '百家姓',
      'subtitle': '单姓与复姓蒙学读本',
      'summary': '已导入姓氏原文和逐姓读音。',
      'content': surnameContent,
      'readingContent': surnameReading,
      'sourceId': 'user-provided-baijiaxing',
    },
    {
      'id': 'other-solar',
      'category': 'other',
      'title': '二十四节气',
      'subtitle': '四时流转与节气歌',
      'summary': '完整收录二十四节气及大致公历时间。',
      'content': _solarTerms,
      'sourceId': 'app-original',
    },
    {
      'id': 'other-festival',
      'category': 'other',
      'title': '传统节日',
      'subtitle': '岁时传统与民族节庆',
      'summary': '收录岁时节日和少数民族代表性节庆，了解日期、习俗与文化含义。',
      'content': _festivals,
      'sourceId': 'app-original',
    },
    {
      'id': 'other-allusion',
      'category': 'other',
      'title': '典故',
      'subtitle': '古籍故事与文化用语',
      'summary': '认识成语和诗文背后的故事。',
      'content': '典故是具有出处的故事或词句，常被后世文章引用。后续可按人物、时代和主题扩展。',
      'sourceId': 'app-original',
    },
    if (_youmengyingItem() case final item?) item,
    {
      'id': 'other-title',
      'category': 'other',
      'title': '古代称谓',
      'subtitle': '亲属关系、名号与谦敬用语',
      'summary': '从“我”出发辨认父系、母系和堂表亲属，并了解名、字、号及谦敬称呼。',
      'content':
          '古代称谓须结合说话者、亲属路径、身份及时代来理解。本页提供父系与母系关系图、常见亲属称谓表，以及名、字、号、官爵、谥号和谦敬用语说明。',
      'sourceId': 'app-original',
    },
  ];

  File('assets/data/culture_items_v2.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(items)}\n',
  );
  stdout.writeln('导入文化条目 ${items.length} 条。');
}

List<Map<String, dynamic>> _classicalItems(Directory outputDirectory) {
  const root = 'Aatime/Classical-Modern-data/双语数据';
  const books = [
    (
      directory: '论语',
      id: 'lunyu',
      title: '论语',
      subtitle: '孔子及其弟子言行录',
      summary: '收录《论语》原文与逐段白话翻译。',
    ),
    (
      directory: '孟子',
      id: 'mengzi',
      title: '孟子',
      subtitle: '仁政、民本与性善之论',
      summary: '按篇章收录《孟子》原文与白话翻译。',
    ),
    (
      directory: '大学章句集注',
      id: 'daxue',
      title: '大学',
      subtitle: '明明德，亲民，止于至善',
      summary: '收录《大学章句集注》原文与逐章白话翻译。',
    ),
    (
      directory: '中庸',
      id: 'zhongyong',
      title: '中庸',
      subtitle: '致中和，天地位焉',
      summary: '收录《中庸》原文与逐章白话翻译。',
    ),
    (
      directory: '三字经',
      id: 'sanzijing',
      title: '三字经',
      subtitle: '蒙学识字与伦理读本',
      summary: '收录《三字经》原文与逐段白话翻译。'
    ),
    (
      directory: '世说新语',
      id: 'shishuo-xinyu',
      title: '世说新语',
      subtitle: '魏晋人物言行与轶事',
      summary: '收录《世说新语》原文与逐段白话翻译。'
    ),
    (
      directory: '列子',
      id: 'liezi',
      title: '列子',
      subtitle: '道家寓言与思想',
      summary: '收录《列子》原文与逐段白话翻译。'
    ),
    (
      directory: '千字文',
      id: 'qianziwen',
      title: '千字文',
      subtitle: '四字韵文蒙学读本',
      summary: '收录《千字文》原文与逐段白话翻译。'
    ),
    (
      directory: '周礼',
      id: 'zhouli',
      title: '周礼',
      subtitle: '古代官制与礼制文献',
      summary: '收录《周礼》原文与逐段白话翻译。'
    ),
    (
      directory: '墨子',
      id: 'mozi',
      title: '墨子',
      subtitle: '兼爱、非攻与尚贤',
      summary: '收录《墨子》原文与逐段白话翻译。'
    ),
    (
      directory: '天工开物',
      id: 'tiangong-kaiwu',
      title: '天工开物',
      subtitle: '明代农工技术百科',
      summary: '收录《天工开物》原文与逐段白话翻译。'
    ),
    (
      directory: '孙子兵法',
      id: 'sunzi-bingfa',
      title: '孙子兵法',
      subtitle: '兵家战略经典',
      summary: '收录《孙子兵法》原文与逐段白话翻译。'
    ),
    (
      directory: '孙膑兵法',
      id: 'sunbin-bingfa',
      title: '孙膑兵法',
      subtitle: '战国兵家著作',
      summary: '收录《孙膑兵法》原文与逐段白话翻译。'
    ),
    (
      directory: '尚书',
      id: 'shangshu',
      title: '尚书',
      subtitle: '上古政事文献汇编',
      summary: '收录《尚书》原文与逐段白话翻译。'
    ),
    (
      directory: '山海经',
      id: 'shanhaijing',
      title: '山海经',
      subtitle: '山川物产与神话地理',
      summary: '收录《山海经》原文与逐段白话翻译。'
    ),
    (
      directory: '庄子',
      id: 'zhuangzi',
      title: '庄子',
      subtitle: '道家哲思与寓言',
      summary: '收录《庄子》原文与逐段白话翻译。'
    ),
    (
      directory: '弟子规',
      id: 'dizigui',
      title: '弟子规',
      subtitle: '蒙学伦理与日常规范',
      summary: '收录《弟子规》原文与逐段白话翻译。'
    ),
    (
      directory: '徐霞客游记',
      id: 'xuxiake-youji',
      title: '徐霞客游记',
      subtitle: '地理考察与旅行日记',
      summary: '收录《徐霞客游记》原文与逐段白话翻译。'
    ),
    (
      directory: '心经',
      id: 'xinjing',
      title: '心经',
      subtitle: '般若类佛教经典',
      summary: '收录《心经》原文与逐段白话翻译。'
    ),
    (
      directory: '抱朴子',
      id: 'baopuzi',
      title: '抱朴子',
      subtitle: '道教思想与魏晋论说',
      summary: '收录《抱朴子》原文与逐段白话翻译。'
    ),
    (
      directory: '文心雕龙',
      id: 'wenxin-diaolong',
      title: '文心雕龙',
      subtitle: '中国古代文学理论',
      summary: '收录《文心雕龙》原文与逐段白话翻译。'
    ),
    (
      directory: '梦溪笔谈',
      id: 'mengxi-bitan',
      title: '梦溪笔谈',
      subtitle: '北宋科学与见闻笔记',
      summary: '收录《梦溪笔谈》原文与逐段白话翻译。'
    ),
    (
      directory: '棋经十三篇',
      id: 'qijing-shisanpian',
      title: '棋经十三篇',
      subtitle: '古代围棋理论著作',
      summary: '收录《棋经十三篇》原文与逐段白话翻译。'
    ),
    (
      directory: '礼记',
      id: 'liji',
      title: '礼记',
      subtitle: '先秦至秦汉礼制文献',
      summary: '收录《礼记》原文与逐段白话翻译。'
    ),
    (
      directory: '易传',
      id: 'yizhuan',
      title: '易传',
      subtitle: '阐释《周易》经文的十翼',
      summary: '收录《易传》原文与逐段白话翻译。'
    ),
    (
      directory: '老子',
      id: 'laozi',
      title: '老子',
      subtitle: '又称《道德经》',
      summary: '收录《老子》原文与逐段白话翻译。'
    ),
    (
      directory: '荀子',
      id: 'xunzi',
      title: '荀子',
      subtitle: '先秦儒家论说著作',
      summary: '收录《荀子》原文与逐段白话翻译。'
    ),
    (
      directory: '菜根谭',
      id: 'caigentan',
      title: '菜根谭',
      subtitle: '处世修养格言集',
      summary: '收录《菜根谭》原文与逐段白话翻译。'
    ),
    (
      directory: '韩非子',
      id: 'hanfeizi',
      title: '韩非子',
      subtitle: '法家政治哲学著作',
      summary: '收录《韩非子》原文与逐段白话翻译。'
    ),
    (
      directory: '鬼谷子',
      id: 'guiguzi',
      title: '鬼谷子',
      subtitle: '纵横说辩与谋略著作',
      summary: '收录《鬼谷子》原文与逐段白话翻译。'
    ),
  ];
  final result = <Map<String, dynamic>>[];
  for (final book in books) {
    final passages = _bilingualPassages(
      Directory('$root/${book.directory}'),
      book: book.title,
      perLine: true,
    );
    if (passages.isEmpty) continue;
    final itemId = 'classic-${book.id}';
    final passageAsset = 'assets/data/culture_passages/$itemId.json';
    File('${outputDirectory.path}/$itemId.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(passages)}\n',
    );
    result.add({
      'id': itemId,
      'category': primerBookIds.contains(itemId) ? 'other' : 'classics',
      'title': book.title,
      'subtitle': book.subtitle,
      'summary': book.summary,
      // Passages are the canonical full text. Keeping only the first aligned
      // pair in these compatibility fields avoids duplicating very large
      // books such as Xu Xiake's Travels in the packaged JSON.
      'content': passages.first['original'],
      'translation': passages.first['translation'],
      'passagesAsset': passageAsset,
      'sourceId': 'NiuTrans/Classical-Modern (MIT)',
    });
  }
  return result;
}

List<Map<String, String>> _bilingualPassages(
  Directory directory, {
  required String book,
  required bool perLine,
}) {
  if (!directory.existsSync()) return const [];
  final sourceFiles = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.uri.pathSegments.last == 'source.txt')
      .toList()
    ..sort((a, b) => _sectionSortKey(directory, book, a)
        .compareTo(_sectionSortKey(directory, book, b)));
  final result = <Map<String, String>>[];
  for (final sourceFile in sourceFiles) {
    final targetFile = File('${sourceFile.parent.path}/target.txt');
    if (!targetFile.existsSync()) continue;
    final sources =
        sourceFile.readAsLinesSync().map((line) => line.trim()).toList();
    final targets =
        targetFile.readAsLinesSync().map((line) => line.trim()).toList();
    if (sources.length != targets.length) {
      throw FormatException('古籍双语行数不匹配：${sourceFile.path}');
    }
    final relative = sourceFile.parent.path
        .substring(directory.path.length)
        .replaceAll(RegExp(r'^[\\/]'), '')
        .replaceAll('\\', ' · ')
        .replaceAll('/', ' · ');
    final pairs = <(String, String)>[
      for (var index = 0; index < sources.length; index++)
        if (sources[index].isNotEmpty && targets[index].isNotEmpty)
          (sources[index], targets[index]),
    ];
    if (pairs.isEmpty) continue;
    if (perLine) {
      for (var index = 0; index < pairs.length; index++) {
        result.add({
          'heading': index == 0 ? relative : '',
          'original': pairs[index].$1,
          'translation': pairs[index].$2,
        });
      }
    } else {
      result.add({
        'heading': relative,
        'original': pairs.map((pair) => pair.$1).join(),
        'translation': pairs.map((pair) => pair.$2).join(),
      });
    }
  }
  return result;
}

String _sectionSortKey(Directory root, String book, File file) {
  final relative = file.parent.path
      .substring(root.path.length)
      .replaceAll(RegExp(r'^[\\/]'), '');
  final parts = relative.split(RegExp(r'[\\/]'));
  final bookOrder = switch (book) {
    '论语' => const [
        '学而篇',
        '为政篇',
        '八佾篇',
        '里仁篇',
        '公冶长篇',
        '雍也篇',
        '述而篇',
        '泰伯篇',
        '子罕篇',
        '乡党篇',
        '先进篇',
        '颜渊篇',
        '子路篇',
        '宪问篇',
        '卫灵公篇',
        '季氏篇',
        '阳货篇',
        '微子篇',
        '子张篇',
        '尧曰篇',
      ],
    '孟子' => const [
        '梁惠王章句上',
        '梁惠王章句下',
        '公孙丑章句上',
        '公孙丑章句下',
        '滕文公章句上',
        '滕文公章句下',
        '离娄章句上',
        '离娄章句下',
        '万章章句上',
        '万章章句下',
        '告子章句上',
        '告子章句下',
        '尽心章句上',
        '尽心章句下',
      ],
    _ => const <String>[],
  };
  final first = bookOrder.indexOf(parts.first);
  final firstOrder = first < 0 ? _chineseOrdinal(parts.first) : first + 1;
  final rest = parts.skip(1).map(_chineseOrdinal).join('-');
  return '${firstOrder.toString().padLeft(3, '0')}-$rest-$relative';
}

int _chineseOrdinal(String value) {
  final text = value.replaceAll(RegExp(r'[第章节篇]'), '');
  const digits = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  final ten = text.indexOf('十');
  if (ten < 0) return digits[text] ?? 999;
  final tens = ten == 0 ? 1 : (digits[text.substring(0, ten)] ?? 0);
  final units =
      ten == text.length - 1 ? 0 : (digits[text.substring(ten + 1)] ?? 0);
  return tens * 10 + units;
}

Map<String, dynamic>? _youmengyingItem() {
  final file = File('Aatime/chinese-poetry-master/幽梦影/youmengying.json');
  if (!file.existsSync()) return null;
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! List) return null;
  final content = <String>[];
  final notes = <String>[];
  var index = 0;
  for (final value in decoded.whereType<Map>()) {
    final text = value['content']?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    index++;
    content.add('第$index则\n$text');
    final rawComments = value['comment'];
    final comments = switch (rawComments) {
      List values => values.map((item) => item.toString().trim()),
      String text => [text.trim()],
      _ => const <String>[],
    }
        .where((item) => item.isNotEmpty)
        .toList();
    if (comments.isNotEmpty) {
      notes.add('第$index则\n${comments.join('\n')}');
    }
  }
  if (content.isEmpty) return null;
  return {
    'id': 'other-youmengying',
    'category': 'classics',
    'title': '幽梦影',
    'subtitle': '清代随笔与原书评语',
    'summary': '收录原文，并可在“注释”模式查看原书评语。',
    'content': content.join('\n\n'),
    'notes': notes.join('\n\n'),
    'sourceId': 'chinese-poetry (MIT)',
  };
}

List<List<(String, String)>> _surnameSentences(List<(String, String)> entries) {
  final lines = <List<(String, String)>>[];
  var current = <(String, String)>[];
  var characterCount = 0;
  for (final entry in entries) {
    final length = entry.$1.runes.length;
    if (characterCount + length > 4) {
      throw FormatException(
          '无法在不拆分复姓的情况下组成四字句：${current.map((e) => e.$1).join()}');
    }
    current.add(entry);
    characterCount += length;
    if (characterCount == 4) {
      lines.add(current);
      current = [];
      characterCount = 0;
    }
  }
  if (current.isNotEmpty) throw const FormatException('百家姓末句不足四字');
  return lines;
}

List<Map<String, dynamic>> get _schools =>
    (jsonDecode(File('tool/culture_schools.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

const _solarTerms = '''
立春|2月3–5日
雨水|2月18–20日
惊蛰|3月5–7日
春分|3月20–22日
清明|4月4–6日
谷雨|4月19–21日
立夏|5月5–7日
小满|5月20–22日
芒种|6月5–7日
夏至|6月21–22日
小暑|7月6–8日
大暑|7月22–24日
立秋|8月7–9日
处暑|8月22–24日
白露|9月7–9日
秋分|9月22–24日
寒露|10月8–9日
霜降|10月23–24日
立冬|11月7–8日
小雪|11月22–23日
大雪|12月6–8日
冬至|12月21–23日
小寒|1月5–7日
大寒|1月20–21日

节气歌
春雨惊春清谷天，夏满芒夏暑相连。
秋处露秋寒霜降，冬雪雪冬小大寒。
每月两节不变更，最多相差一两天。
上半年来六廿一，下半年是八廿三。
''';

const _festivals = '''
春节|农历正月初一
破五|农历正月初五
人日|农历正月初七
元宵节|农历正月十五
填仓节|农历正月廿五
中和节|农历二月初一
龙抬头|农历二月初二
花朝节|农历二月初二、十二、十五或廿五
春社日|立春后第五个戊日
上巳节|农历三月初三
寒食节|清明前一或二日
清明节|公历4月4–6日
佛诞节|农历四月初八（汉传佛教）
端午节|农历五月初五
六月六|农历六月初六
七夕节|农历七月初七
中元节|农历七月十五
中秋节|农历八月十五
秋社日|立秋后第五个戊日
重阳节|农历九月初九
寒衣节|农历十月初一
下元节|农历十月十五
冬至节|公历12月21–23日
腊八节|农历腊月初八
小年|农历腊月廿三、廿四等
除夕|农历腊月最后一日
''';
