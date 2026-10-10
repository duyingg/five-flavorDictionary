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
      'subtitle': '名号、官爵、谦敬与交往称呼',
      'summary': '按语境查阅姓名别称、帝王官爵、敬称谦称、师友身份与常见亲属称呼。',
      'content':
          '古代称谓须结合说话者、对象、身份和时代来理解。本页提供称呼用法对照，以及名、字、号、官爵、帝王称号、谦敬用语、社会身份和常见亲属称呼的速查。',
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
    _applyVerifiedTextCorrections(book.id, passages);
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

void _applyVerifiedTextCorrections(
  String bookId,
  List<Map<String, String>> passages,
) {
  final manifest = File('tool/classic_text_corrections_20261002.json');
  if (!manifest.existsSync()) return;
  final corrections = jsonDecode(manifest.readAsStringSync()) as List<dynamic>;
  for (final raw in corrections) {
    final correction = raw as Map<String, dynamic>;
    if (correction['book'] != bookId) continue;
    if (correction['replace'] case final Map<String, dynamic> replacement) {
      final oldText = replacement['from'] as String;
      final newText = replacement['to'] as String;
      final expected = replacement['count'] as int;
      final actual = passages.fold<int>(
        0,
        (sum, row) => sum + (row['original'] ?? '').split(oldText).length - 1,
      );
      if (actual != expected) {
        throw FormatException('典籍校订字形数量不符：$bookId $oldText $actual/$expected');
      }
      for (final row in passages) {
        row['original'] = row['original']!.replaceAll(oldText, newText);
      }
      continue;
    }
    final anchor = correction['anchor'] as String;
    final matches = <int>[
      for (var i = 0; i < passages.length; i++)
        if (passages[i]['original'] == anchor) i,
    ];
    if (matches.length != 1) {
      throw FormatException('典籍校订锚点不唯一：$bookId $anchor');
    }
    final index = matches.single;
    final insert = (correction['insert'] as List<dynamic>).cast<String>();
    if (index + insert.length < passages.length &&
        List.generate(insert.length, (i) => passages[index + i + 1]['original'])
                .join('\n') ==
            insert.join('\n')) {
      continue;
    }
    final added = [
      for (final original in insert)
        {'heading': '', 'original': original, 'translation': ''},
    ];
    if (correction['moveHeadingFromNext'] == true) {
      final heading = passages[index + 1]['heading'] ?? '';
      if (heading.isEmpty) {
        throw FormatException('典籍校订章节标题缺失：$bookId $anchor');
      }
      added.first['heading'] = heading;
      passages[index + 1]['heading'] = '';
    }
    passages.insertAll(index + 1, added);
  }
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
    var relative = sourceFile.parent.path
        .substring(directory.path.length)
        .replaceAll(RegExp(r'^[\\/]'), '')
        .replaceAll('\\', ' · ')
        .replaceAll('/', ' · ');
    if (book == '天工开物' && relative == '中篇 · 杀青') {
      relative = '下篇 · 杀青';
    }
    final pairs = <(String, String)>[
      for (var index = 0; index < sources.length; index++)
        if (sources[index].isNotEmpty && targets[index].isNotEmpty)
          (sources[index], targets[index]),
    ];
    if (pairs.isEmpty) continue;
    if (perLine) {
      for (var index = 0; index < pairs.length; index++) {
        final verseWidth = switch (book) {
          '千字文' => 8,
          '三字经' => 6,
          _ => 0,
        };
        final units = verseWidth == 0
            ? [pairs[index].$1]
            : _splitFixedVerse(pairs[index].$1, verseWidth);
        for (var unit = 0; unit < units.length; unit++) {
          result.add({
            'heading': index == 0 && unit == 0 ? relative : '',
            'original': units[unit],
            // The source provides one translation for the entire source line.
            // Keep it after the last verse instead of assigning it to one verse.
            'translation': unit == units.length - 1 ? pairs[index].$2 : '',
          });
        }
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

List<String> _splitFixedVerse(String text, int width) {
  final runes = text.runes.toList(growable: false);
  final result = <String>[];
  var start = 0;
  var hanCount = 0;
  for (var index = 0; index < runes.length; index++) {
    final rune = runes[index];
    if ((rune >= 0x3400 && rune <= 0x9fff) ||
        (rune >= 0x20000 && rune <= 0x323af)) {
      hanCount++;
    }
    if (hanCount != width) continue;
    var end = index + 1;
    while (end < runes.length &&
        !((runes[end] >= 0x3400 && runes[end] <= 0x9fff) ||
            (runes[end] >= 0x20000 && runes[end] <= 0x323af))) {
      end++;
    }
    result.add(String.fromCharCodes(runes.sublist(start, end)));
    start = end;
    index = end - 1;
    hanCount = 0;
  }
  if (start < runes.length) {
    if (result.isEmpty) return [text];
    result[result.length - 1] += String.fromCharCodes(runes.sublist(start));
  }
  return result;
}

String _sectionSortKey(Directory root, String book, File file) {
  final relative = file.parent.path
      .substring(root.path.length)
      .replaceAll(RegExp(r'^[\\/]'), '');
  final parts = relative.split(RegExp(r'[\\/]'));
  if (book == '徐霞客游记') return _travelSectionSortKey(parts.first);
  if (book == '天工开物' && parts.length > 1 && parts[1] == '杀青') {
    parts[0] = '下篇';
  }
  final bookOrder = switch (book) {
    '老子' => const ['道经', '德经'],
    '易传' => const [
        '彖传上',
        '彖传下',
        '象传上',
        '象传下',
        '文言传',
        '系辞传上',
        '系辞传下',
        '说卦传',
        '序卦传',
        '杂卦传',
      ],
    '尚书' => const ['虞书', '夏书', '商书', '周书'],
    '周礼' => const [
        '天官冢宰',
        '地官司徒',
        '春官宗伯',
        '夏官司马',
        '秋官司寇',
        '冬官考工记',
      ],
    '山海经' => const ['山经', '海经'],
    '庄子' => const ['内篇', '外篇', '杂篇'],
    '天工开物' => const ['上篇', '中篇', '下篇'],
    '鬼谷子' => const ['鬼谷子', '本经阴符七术', '持枢', '中经'],
    '菜根谭' => const ['修身', '应酬', '评议', '闲适', '概论'],
    '孙子兵法' => const [
        '始计篇',
        '作战篇',
        '谋攻篇',
        '军形篇',
        '兵势篇',
        '虚实篇',
        '军争篇',
        '九变篇',
        '行军篇',
        '地形篇',
        '九地篇',
        '火攻篇',
        '用间篇',
      ],
    '列子' => const [
        '天瑞',
        '黄帝',
        '周穆王',
        '仲尼',
        '汤问',
        '力命',
        '杨朱',
        '说符',
      ],
    '弟子规' => const [
        '总叙',
        '入则孝',
        '出则悌',
        '谨',
        '信',
        '泛爱众',
        '亲仁',
        '余力学文',
      ],
    '礼记' => const [
        '曲礼上',
        '曲礼下',
        '檀弓上',
        '檀弓下',
        '王制',
        '月令',
        '曾子问',
        '文王世子',
        '礼运',
        '礼器',
        '郊特牲',
        '内则',
        '玉藻',
        '明堂位',
        '丧服小记',
        '大传',
        '少仪',
        '学记',
        '乐记',
        '杂记上',
        '杂记下',
        '丧大记',
        '祭法',
        '祭义',
        '祭统',
        '经解',
        '哀公问',
        '仲尼燕居',
        '孔子闲居',
        '坊记',
        '中庸',
        '表记',
        '缁衣',
        '奔丧',
        '问丧',
        '服问',
        '间传',
        '三年问',
        '深衣',
        '投壶',
        '儒行',
        '大学',
        '冠义',
        '昏义',
        '乡饮酒义',
        '射义',
        '燕义',
        '聘义',
        '丧服四制',
      ],
    '韩非子' => const [
        '初见秦',
        '存韩',
        '难言',
        '爱臣',
        '主道',
        '有度',
        '二柄',
        '扬权',
        '八奸',
        '十过',
        '孤愤',
        '说难',
        '和氏',
        '奸劫弑臣',
        '亡征',
        '三守',
        '备内',
        '南面',
        '饰邪',
        '解老',
        '喻老',
        '说林上',
        '说林下',
        '观行',
        '安危',
        '守道',
        '用人',
        '功名',
        '大体',
        '内储说上七术',
        '内储说下六微',
        '外储说左上',
        '外储说左下',
        '外储说右上',
        '外储说右下',
        '难一',
        '难二',
        '难三',
        '难四',
        '难势',
        '问辩',
        '问田',
        '定法',
        '说疑',
        '诡使',
        '六反',
        '八说',
        '八经',
        '五蠹',
        '显学',
        '忠孝',
        '人主',
        '饬令',
        '心度',
        '制分',
      ],
    '棋经十三篇' => const [
        '论局篇',
        '得算篇',
        '权舆篇',
        '合战篇',
        '虚实篇',
        '自知篇',
        '审局篇',
        '度情篇',
        '斜正篇',
        '洞微篇',
        '名数篇',
        '品格篇',
        '杂说篇',
      ],
    '世说新语' => const [
        '德行',
        '言语',
        '政事',
        '文学',
        '方正',
        '雅量',
        '识鉴',
        '赏誉',
        '品藻',
        '规箴',
        '捷悟',
        '夙惠',
        '豪爽',
        '容止',
        '自新',
        '企羡',
        '伤逝',
        '栖逸',
        '贤媛',
        '术解',
        '巧蓺',
        '宠礼',
        '任诞',
        '简傲',
        '排调',
        '轻诋',
        '假谲',
        '黜免',
        '俭啬',
        '汰侈',
        '忿狷',
        '谗险',
        '尤悔',
        '纰漏',
        '惑溺',
        '仇隙',
      ],
    '文心雕龙' => const [
        '原道',
        '征圣',
        '宗经',
        '正纬',
        '辨骚',
        '明诗',
        '乐府',
        '诠赋',
        '颂赞',
        '祝盟',
        '铭箴',
        '诔碑',
        '哀吊',
        '杂文',
        '谐讔',
        '史传',
        '诸子',
        '论说',
        '诏策',
        '檄移',
        '封禅',
        '章表',
        '奏启',
        '议对',
        '书记',
        '神思',
        '体性',
        '风骨',
        '通变',
        '定势',
        '情采',
        '熔裁',
        '声律',
        '章句',
        '丽辞',
        '比兴',
        '夸饰',
        '事类',
        '练字',
        '隐秀',
        '指瑕',
        '养气',
        '附会',
        '总术',
        '时序',
        '物色',
        '才略',
        '知音',
        '程器',
        '序志',
      ],
    '荀子' => const [
        '劝学',
        '修身',
        '不苟',
        '荣辱',
        '非相',
        '非十二子',
        '仲尼',
        '儒效',
        '王制',
        '富国',
        '王霸',
        '君道',
        '臣道',
        '致士',
        '议兵',
        '强国',
        '天论',
        '正论',
        '礼论',
        '乐论',
        '解蔽',
        '正名',
        '性恶',
        '君子',
        '成相',
        '赋',
        '大略',
        '宥坐',
        '子道',
        '法行',
        '哀公',
        '尧问',
      ],
    '孙膑兵法' => const [
        '擒庞涓',
        '见威王',
        '威王问',
        '陈忌问垒',
        '篡卒',
        '月战',
        '八阵',
        '地葆',
        '势备',
        '兵情',
        '行篡',
        '杀士',
        '延气',
        '官一',
        '强兵',
        '十阵',
        '十问',
        '略甲',
        '客主人分',
        '善者',
        '五名五恭',
        '兵失',
        '将义',
        '将德',
        '将败',
        '将失',
        '雄牝城',
        '五度九夺',
        '积疏',
        '奇正',
      ],
    '梦溪笔谈' => const [
        '故事一',
        '故事二',
        '辨证一',
        '辨证二',
        '乐律一',
        '乐律二',
        '象数一',
        '象数二',
        '人事一',
        '人事二',
        '官政一',
        '官政二',
        '权智',
        '艺文一',
        '艺文二',
        '艺文三',
        '书画',
        '技艺',
        '器用',
        '神奇',
        '异事异疾附',
        '谬误谲诈附',
        '讥谑',
        '杂志一',
        '杂志二',
        '药议',
        '补笔谈卷一',
        '补笔谈卷二',
        '补笔谈卷三',
        '续笔谈十一篇',
      ],
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
  if (bookOrder.isNotEmpty && first < 0 && firstOrder == 999) {
    throw FormatException('未校定章节顺序：$book / ${parts.first}');
  }
  final numberedSeries = book == '徐霞客游记' && parts.first.contains('日记')
      ? RegExp(r'^(.+?)[一二三四五六七八九十]+$').firstMatch(parts.first)?.group(1)
      : null;
  final firstKey = firstOrder == 999
      ? '999-${parts.first}'
      : first < 0 && numberedSeries != null
          ? '998-$numberedSeries-${firstOrder.toString().padLeft(3, '0')}'
          : firstOrder.toString().padLeft(3, '0');
  final rest = <String>[];
  for (var index = 1; index < parts.length; index++) {
    final part = parts[index];
    final chapterOrder = _nestedChapterOrder(book, parts.first);
    final chapterIndex = index == 1 ? chapterOrder.indexOf(part) : -1;
    final order = chapterIndex >= 0 ? chapterIndex + 1 : _chineseOrdinal(part);
    if (index == 1 &&
        chapterOrder.isNotEmpty &&
        chapterIndex < 0 &&
        order == 999) {
      throw FormatException('未校定章节顺序：$book / ${parts.join(' / ')}');
    }
    rest.add('${order.toString().padLeft(3, '0')}-$part');
  }
  return '$firstKey-${rest.join('-')}-$relative';
}

String _travelSectionSortKey(String title) {
  const early = [
    '游天台山日记',
    '游雁宕山日记',
    '游白岳山日记',
    '游黄山日记',
    '游武彝山日记',
    '游庐山日记',
    '游黄山日记后',
    '游九鲤湖日记',
    '游嵩山日记',
    '游太华山日记',
    '游太和山日记',
    '闽游日记前',
    '闽游日记后',
    '游天台山日记后',
    '游雁宕山日记后',
    '游五台山日记',
    '游恒山日记',
    '浙游日记上',
    '浙游日记下',
  ];
  final earlyIndex = early.indexOf(title);
  if (earlyIndex >= 0) {
    return '${(earlyIndex + 1).toString().padLeft(3, '0')}-$title';
  }
  const diaries = [
    '江右游日记',
    '楚游日记',
    '粤西游日记',
    '黔游日记',
    '滇游日记',
  ];
  for (var index = 0; index < diaries.length; index++) {
    final prefix = diaries[index];
    if (!title.startsWith(prefix)) continue;
    final number = _chineseOrdinal(title.substring(prefix.length));
    if (number == 999) break;
    return '${(index + 20).toString().padLeft(3, '0')}-${number.toString().padLeft(3, '0')}';
  }
  const appendix = [
    '游太华山记',
    '滇中花木记',
    '游颜洞记',
    '随笔二则',
    '盘江考',
    '永昌志略',
    '近腾诸彝说略',
    '鸡山志目',
    '鸡山志略一',
    '鸡山志略二',
    '丽江纪略',
    '法王缘起',
    '溯江纪源 & 江源考',
  ];
  final appendixIndex = appendix.indexOf(title);
  if (appendixIndex >= 0) {
    return '${(appendixIndex + 30).toString().padLeft(3, '0')}-$title';
  }
  throw FormatException('未校定章节顺序：徐霞客游记 / $title');
}

List<String> _nestedChapterOrder(String book, String section) {
  if (book == '易传' &&
      const ['彖传上', '彖传下', '象传上', '象传下', '文言传'].contains(section)) {
    return const [
      '乾',
      '乾文言',
      '坤',
      '坤文言',
      '屯',
      '蒙',
      '需',
      '讼',
      '师',
      '比',
      '小畜',
      '履',
      '泰',
      '否',
      '同人',
      '大有',
      '谦',
      '豫',
      '随',
      '蛊',
      '临',
      '观',
      '噬嗑',
      '贲',
      '剥',
      '复',
      '无妄',
      '大畜',
      '颐',
      '大过',
      '坎',
      '离',
      '咸',
      '恒',
      '遯',
      '大壮',
      '晋',
      '明夷',
      '家人',
      '睽',
      '蹇',
      '解',
      '损',
      '益',
      '夬',
      '姤',
      '萃',
      '升',
      '困',
      '井',
      '革',
      '鼎',
      '震',
      '艮',
      '渐',
      '归妹',
      '丰',
      '旅',
      '巽',
      '兑',
      '涣',
      '节',
      '中孚',
      '小过',
      '既济',
      '未济',
    ];
  }
  return switch ((book, section)) {
    ('鬼谷子', '鬼谷子') => const [
        '捭阖',
        '反应',
        '内楗',
        '抵巇',
        '飞箝',
        '忤合',
        '揣篇',
        '摩篇',
        '权篇',
        '谋篇',
        '决篇',
        '符言',
      ],
    ('鬼谷子', '本经阴符七术') => const [
        '盛神法五龙',
        '养志法灵龟',
        '实意法腾蛇',
        '分威法伏熊',
        '散势法鸷鸟',
        '转圆法猛兽',
        '损兑法灵蓍',
      ],
    ('天工开物', '上篇') => const [
        '乃粒',
        '乃服',
        '彰施',
        '粹精',
        '作咸',
        '甘嗜',
      ],
    ('天工开物', '中篇') => const [
        '陶埏',
        '冶铸',
        '舟车',
        '锤锻',
        '燔石',
        '膏液',
      ],
    ('天工开物', '下篇') => const [
        '杀青',
        '五金',
        '佳兵',
        '丹青',
        '曲蘖',
        '珠玉',
      ],
    ('周礼', '天官冢宰') => const [
        '叙官',
        '大宰',
        '小宰',
        '宰夫',
        '宫正&外饔',
        '亨人&兽医',
        '酒正&掌次',
        '大府&职币',
        '司裘&内树',
        '九嫔&女史',
        '典妇功&夏采',
      ],
    ('周礼', '地官司徒') => const [
        '叙官',
        '大司徒',
        '小司徒',
        '乡师&比长',
        '封人&均人',
        '师氏&媒氏',
        '司市&掌节',
        '遂人&土均',
        '草人&羽人',
        '掌葛&槁人',
      ],
    ('周礼', '春官宗伯') => const [
        '叙官',
        '大宗伯',
        '小宗伯',
        '肆师',
        '郁人&典瑞',
        '大司乐&小师',
        '瞽蒙&司干',
        '大卜&诅祝',
        '司巫&神仕',
        '典命&职丧',
      ],
    ('周礼', '夏官司马') => const [
        '叙官',
        '大司马',
        '小司马&司险',
        '候人&司右',
        '虎贲氏&道右',
        '大驭&形方式',
        '山师&都司马',
      ],
    ('周礼', '秋官司寇') => const [
        '叙官',
        '大司寇',
        '小司寇',
        '士师&朝士',
        '司隶&庭氏',
        '司民&掌戮',
        '衔枚氏&司仪',
        '行夫&朝大夫',
      ],
    ('周礼', '冬官考工记') => const [
        '总叙',
        '轮人&輈人',
        '筑氏&玉人',
        '磬氏&车人',
        '弓人',
      ],
    ('尚书', '虞书') => const ['尧典', '舜典', '大禹谟', '皋陶谟', '益稷'],
    ('尚书', '夏书') => const ['禹贡', '甘誓', '五子之歌', '胤征'],
    ('尚书', '商书') => const [
        '汤誓',
        '仲虺之诰',
        '汤诰',
        '伊训',
        '太甲上',
        '太甲中',
        '太甲下',
        '咸有一德',
        '盘庚上',
        '盘庚中',
        '盘庚下',
        '说命上',
        '说命中',
        '说命下',
        '高宗肜日',
        '西伯戡黎',
        '微子',
      ],
    ('尚书', '周书') => const [
        '泰誓',
        '牧誓',
        '武成',
        '洪范',
        '旅獒',
        '金縢',
        '大诰',
        '微子之命',
        '康诰',
        '酒诰',
        '梓材',
        '召诰',
        '洛诰',
        '多士',
        '无逸',
        '君奭',
        '蔡仲之命',
        '多方',
        '立政',
        '周官',
        '君陈',
        '顾命',
        '康王之诰',
        '毕命',
        '君牙',
        '冏命',
        '吕刑',
        '文侯之命',
        '费誓',
        '秦誓',
      ],
    ('庄子', '内篇') => const [
        '逍遥游',
        '齐物论',
        '养生主',
        '人间世',
        '德充符',
        '大宗师',
        '应帝王',
      ],
    ('庄子', '外篇') => const [
        '骈拇',
        '马蹄',
        '胠箧',
        '在宥',
        '天地',
        '天道',
        '天运',
        '刻意',
        '缮性',
        '秋水',
        '至乐',
        '达生',
        '山木',
        '田子方',
        '知北游',
      ],
    ('庄子', '杂篇') => const [
        '庚桑楚',
        '徐无鬼',
        '则阳',
        '外物',
        '寓言',
        '让王',
        '盗跖',
        '说剑',
        '渔父',
        '列御寇',
        '天下',
      ],
    ('山海经', '山经') => const [
        '南山经',
        '西山经',
        '北山经',
        '东山经',
        '中山经',
      ],
    ('山海经', '海经') => const [
        '海外南经',
        '海外西经',
        '海外北经',
        '海外东经',
        '海内南经',
        '海内西经',
        '海内北经',
        '海内东经',
        '大荒东经',
        '大荒南经',
        '大荒西经',
        '大荒北经',
        '海内经',
      ],
    _ => const [],
  };
}

int _chineseOrdinal(String value) {
  final arabic = RegExp(r'^\D*(\d+)').firstMatch(value);
  if (arabic != null) return int.parse(arabic.group(1)!);
  final numeral =
      RegExp(r'(?:第)?([一二三四五六七八九十]+)(?:[章节篇则])?$').firstMatch(value);
  if (numeral == null) return 999;
  final text = numeral.group(1)!;
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
