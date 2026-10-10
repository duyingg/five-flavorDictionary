import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('本轮三字经补缺与繁体词组读音在程序中生效', () async {
    final repository = ContextualPinyinRepository();
    final dictionary = AssetDictionaryRepository();
    const text = '作中庸，乃孔伋。披蒲编，削竹简。由康雍，历乾嘉。';
    final readings = await repository.resolve(text, dictionary);
    expect(readings[text.indexOf('中')], 'zhōng');
    expect(readings[text.indexOf('伋')], 'jí');
    expect(readings[text.indexOf('削')], 'xiāo');
    expect(readings[text.indexOf('乾')], 'qián');
    final bank = await repository.resolve('銀行', dictionary);
    expect(bank, ['yín', 'háng']);
  });

  test('繁体正文能命中简体词组并保留原字位置', () {
    final result = resolveContextualPinyin(
      '江陵一日還。'.split(''),
      exactMatchCharacters: '江陵一日还。'.split(''),
      exactLinesByFirstCharacter: const {},
      phrasesByFirstCharacter: const {
        '一': [
          PinyinPhrase(
            characters: ['一', '日', '还'],
            pinyin: ['yí', 'rì', 'huán'],
          ),
        ],
      },
      fallback: const {'還': 'hái'},
    );
    expect(result[4], 'huán');
    expect(result[5], '');
  });

  test('整句人工注音优先于词组与单字首音', () {
    final result = resolveContextualPinyin(
      '不亦说乎'.split(''),
      exactLinesByFirstCharacter: const {
        '不': [
          ExactPinyinLine(
            characters: ['不', '亦', '说', '乎'],
            pinyin: ['bù', 'yì', 'yuè', 'hū'],
          ),
        ],
      },
      phrasesByFirstCharacter: const {
        '说': [
          PinyinPhrase(
            characters: ['说', '乎'],
            pinyin: ['shuō', 'hū'],
          ),
        ],
      },
      fallback: const {'说': 'shuō'},
    );

    expect(result, ['bù', 'yì', 'yuè', 'hū']);
  });

  test('无整句数据时按最长词组判定多音字', () {
    final result = resolveContextualPinyin(
      '千里江陵一日还'.split(''),
      exactLinesByFirstCharacter: const {},
      contextRulesByFirstCharacter: const {},
      phrasesByFirstCharacter: const {
        '一': [
          PinyinPhrase(
            characters: ['一', '日', '还'],
            pinyin: ['yí', 'rì', 'huán'],
          ),
        ],
      },
      fallback: const {'还': 'hái'},
    );

    expect(result.last, 'huán');
  });

  test('长整句的读音不会被短句或通假规则覆盖', () {
    final result = resolveContextualPinyin(
      '天地玄黄宇宙洪荒'.split(''),
      exactLinesByFirstCharacter: const {
        '天': [
          ExactPinyinLine(
            characters: ['天', '地', '玄', '黄', '宇', '宙', '洪', '荒'],
            pinyin: [
              'tiān',
              'dì',
              'xuán',
              'huáng',
              'yǔ',
              'zhòu',
              'hóng',
              'huāng'
            ],
          ),
          ExactPinyinLine(
            characters: ['天', '地', '玄', '黄'],
            pinyin: ['tiān', 'dì', 'xuán', 'huǎng'],
          ),
        ],
      },
      contextRulesByFirstCharacter: const {
        '天': [
          ContextualPinyinRule(
            text: '天地玄黄',
            targetOffset: 3,
            pinyin: 'huǎng',
          ),
        ],
      },
      phrasesByFirstCharacter: const {},
      fallback: const {},
    );
    expect(result[3], 'huáng');
  });

  test('古文通假字语境覆盖现代词组读音', () {
    final result = resolveContextualPinyin(
      '学而时习之不亦说乎'.split(''),
      exactLinesByFirstCharacter: const {},
      contextRulesByFirstCharacter: const {
        '学': [
          ContextualPinyinRule(
            text: '学而时习之不亦说乎',
            targetOffset: 7,
            pinyin: 'yuè',
          ),
        ],
      },
      phrasesByFirstCharacter: const {},
      fallback: const {'说': 'shuō'},
    );

    expect(result[7], 'yuè');
  });

  test('来源整句注音同时匹配简体与繁体正文', () async {
    final repository = ContextualPinyinRepository();
    final dictionary = AssetDictionaryRepository();

    final simplified = await repository.resolve(
      '明月松间照，清泉石上流。',
      dictionary,
    );
    final traditional = await repository.resolve(
      '明月松間照，清泉石上流。',
      dictionary,
    );

    expect(simplified.where((value) => value.isNotEmpty), [
      'míng',
      'yuè',
      'sōng',
      'jiān',
      'zhào',
      'qīng',
      'quán',
      'shí',
      'shàng',
      'liú'
    ]);
    expect(traditional, simplified);

    final mixedScript = await repository.resolve(
      '欲窮千里目，更上一層樓。',
      dictionary,
    );
    expect(mixedScript.where((value) => value.isNotEmpty), [
      'yù',
      'qióng',
      'qiān',
      'lǐ',
      'mù',
      'gèng',
      'shàng',
      'yì',
      'céng',
      'lóu',
    ]);
  });

  test('千字文新增校对读音在程序中生效', () async {
    final repository = ContextualPinyinRepository();
    final dictionary = AssetDictionaryRepository();
    final result = await repository.resolve(
      '日月盈昃，辰宿列张。临深履薄，夙兴温凊。',
      dictionary,
    );
    expect(result.where((value) => value.isNotEmpty), [
      'rì',
      'yuè',
      'yíng',
      'zè',
      'chén',
      'xiù',
      'liè',
      'zhāng',
      'lín',
      'shēn',
      'lǚ',
      'bó',
      'sù',
      'xīng',
      'wēn',
      'qìng',
    ]);
  });

  test('后段古籍与弟子规多音字使用已核定读音', () async {
    final repository = ContextualPinyinRepository();
    final dictionary = AssetDictionaryRepository();

    final qianziwen = await repository.resolve(
      '乐殊贵贱，礼别尊卑。稽颡再拜，悚惧恐惶。',
      dictionary,
    );
    expect(qianziwen[0], 'yuè');
    expect(qianziwen[10], 'qǐ');

    const text = '见未真，勿轻言。知未的，勿轻传。';
    final dizigui = await repository.resolve(text, dictionary);
    expect(dizigui[text.indexOf('的')], 'dì');

    const skill = '人所能，勿轻訾。';
    final skillReadings = await repository.resolve(skill, dictionary);
    expect(skillReadings[skill.indexOf('訾')], 'zī');

    const study = '勿自暴，勿自弃。圣与贤，可驯致。';
    final studyReadings = await repository.resolve(study, dictionary);
    expect(studyReadings[study.indexOf('驯')], 'xún');

    const conduct = '行高者，名自高。';
    final conductReadings = await repository.resolve(conduct, dictionary);
    expect(conductReadings[conduct.indexOf('行')], 'xìng');

    const riding = '骑下马，乘下车。过犹待，百步余。';
    final ridingReadings = await repository.resolve(riding, dictionary);
    expect(ridingReadings[riding.indexOf('车')], 'jū');
  });

  test('心经摘录与老子第一章的核定读音生效', () async {
    final repository = ContextualPinyinRepository();
    final dictionary = AssetDictionaryRepository();
    final sutra = await repository.resolve('观自在菩萨，行深般若波罗蜜多时。', dictionary);
    expect(sutra.where((value) => value.isNotEmpty), [
      'guān',
      'zì',
      'zài',
      'pú',
      'sà',
      'xíng',
      'shēn',
      'bō',
      'rě',
      'bō',
      'luó',
      'mì',
      'duō',
      'shí',
    ]);
    final laozi = await repository.resolve('故常无，欲以观其妙；常有，欲以观其徼。', dictionary);
    expect(laozi.lastWhere((value) => value.isNotEmpty), 'jiào');
  });

  test('百度汉语与古文之家核定段落纠正多音字', () async {
    final repository = ContextualPinyinRepository();
    final dictionary = AssetDictionaryRepository();
    const third = '不尚贤，使民不争；不贵难得之货，使民不为盗；不见可欲，使民心不乱。';
    final thirdReadings = await repository.resolve(third, dictionary);
    expect(thirdReadings[third.indexOf('得')], 'dé');
    expect(thirdReadings[third.indexOf('见')], 'xiàn');

    const eighth = '处众人之所恶，故几于道。';
    final eighthReadings = await repository.resolve(eighth, dictionary);
    expect(eighthReadings[eighth.indexOf('恶')], 'wù');
    expect(eighthReadings[eighth.indexOf('几')], 'jī');

    const iron = '凡治铁成器，取已炒熟铁为之。先铸铁成砧，以为受锤之地。';
    final ironReadings = await repository.resolve(iron, dictionary);
    expect(ironReadings[iron.indexOf('砧')], 'zhēn');

    const forging = '凡铁性逐节粘合，涂上黄泥于接口之上，入火挥槌，泥滓成枵而去，取其神气为媒合。';
    final forgingReadings = await repository.resolve(forging, dictionary);
    expect(forgingReadings[forging.indexOf('枵')], 'xiāo');

    const quenching = '乘其出火时，入清水淬之，名曰健钢、健铁。';
    final quenchingReadings = await repository.resolve(quenching, dictionary);
    expect(quenchingReadings[quenching.indexOf('淬')], 'cuì');
  });

  test('百度汉语诗词逐行注音在应用正文中生效', () async {
    final repository = ContextualPinyinRepository();
    final dictionary = AssetDictionaryRepository();
    const wine = '岑夫子，丹丘生，将进酒，杯莫停。';
    final wineReadings = await repository.resolve(wine, dictionary);
    expect(wineReadings[wine.indexOf('将')], 'qiāng');

    const awake = '钟鼓馔玉不足贵，但愿长醉不复醒。';
    final awakeReadings = await repository.resolve(awake, dictionary);
    expect(awakeReadings[awake.indexOf('复')], 'fù');

    const river = '京口瓜洲一水间，钟山只隔数重山。';
    final riverReadings = await repository.resolve(river, dictionary);
    expect(riverReadings[river.indexOf('重')], 'chóng');

    const village = '最喜小儿亡赖，溪头卧剥莲蓬。';
    final villageReadings = await repository.resolve(village, dictionary);
    expect(villageReadings[village.indexOf('亡')], 'wú');
    expect(villageReadings[village.indexOf('剥')], 'bāo');
  });
}
