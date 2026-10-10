import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/data/poetry_binary_codec.dart';
import 'package:wuwei_dictionary/features/data/word_binary_codec.dart';
import 'package:wuwei_dictionary/features/culture/festival_section.dart';
import 'package:wuwei_dictionary/features/culture/ethnic_festivals.dart';
import 'package:wuwei_dictionary/features/culture/school_books.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('资源词库可解析并精确查询', () async {
    final repository = AssetDictionaryRepository();
    final entries = await repository.all();
    expect(entries.length, greaterThanOrEqualTo(20));
    final entry = await repository.findExactCharacter('澄');
    expect(entry?.pinyin, contains('chéng'));
    expect((await repository.findExactCharacter('汉'))?.wubi, 'ICY');
    expect(entries.where((entry) => entry.wubi.isNotEmpty),
        hasLength(entries.length));
  });

  test('词语二进制索引可精确查询词语级读音和释义', () async {
    final repository = AssetWordRepository();
    final entry = await repository.findExact('银行');

    expect(entry?.word, '银行');
    expect(entry?.pinyin, 'yín háng');
    expect(entry?.definition, contains('金融机构'));
    expect(await repository.findExact('不存在的生造词语'), isNull);
  });

  test('词语学习支持文字前缀和一个或多个逐字拼音', () async {
    final repository = AssetWordRepository();
    expect(
      (await repository.searchText('银行')).map((entry) => entry.word),
      contains('银行'),
    );
    expect(await repository.searchPinyin(['yin']), isNotEmpty);
    expect(
      (await repository.searchPinyin(['yin', 'hang'], limit: 100))
          .map((entry) => entry.word),
      contains('银行'),
    );
    expect(
      (await repository.searchPinyin(['yin', 'guo']))
          .map((entry) => entry.word),
      isNot(contains('银行')),
    );
  });

  test('预生成首字拼音索引与逐条扫描结果一致', () async {
    final catalog = WordBinaryCodec.open(
      await rootBundle.load('assets/data/word_entries.wvd'),
    );
    final queries = [
      ['zhong'],
      ['zhong', 'guo'],
      ['yin', 'hang'],
      ['ren', 'min'],
      ['lü'],
    ];
    final expected = [
      for (final query in queries)
        catalog
            .searchPinyin(query, limit: 100)
            .map((item) => item.word)
            .toList(),
    ];
    final index = await rootBundle.load('assets/data/word_pinyin_index.wpi');
    catalog.installFirstReadingIndex(index);
    for (var position = 0; position < queries.length; position++) {
      expect(
        catalog
            .searchPinyin(queries[position], limit: 100)
            .map((item) => item.word),
        orderedEquals(expected[position]),
        reason: queries[position].join(' '),
      );
    }
    expect(
      () =>
          catalog.installFirstReadingIndex(ByteData.sublistView(Uint8List(8))),
      throwsFormatException,
    );
  });

  test('繁体字等级继承对应简体字等级', () async {
    final repository = AssetDictionaryRepository();
    for (final (simplified, traditional) in [
      ('汉', '漢'),
      ('学', '學'),
      ('国', '國'),
      ('发', '發'),
      ('发', '髮'),
    ]) {
      final source = await repository.findExactCharacter(simplified);
      final target = await repository.findExactCharacter(traditional);
      expect(target?.characterLevel, source?.characterLevel,
          reason: '$simplified / $traditional');
    }
  });

  test('每日诗句均可在标准诗词库定位到原诗', () async {
    final verses =
        await AssetDailyContentRepository().getByType(DailyContentType.verse);
    final catalog = await AssetPoetryRepository().catalog();
    expect(verses, hasLength(4841));
    for (final verse in verses) {
      final poem = catalog.findById(verse.id);
      expect(poem, isNotNull, reason: verse.id);
      expect(poem!.content, contains(verse.title), reason: verse.id);
      expect(poem.content, contains(verse.summary), reason: verse.id);
      expect(poem.translation, isNotEmpty, reason: verse.id);
      expect(poem.author, verse.author, reason: verse.id);
      expect(poem.title, verse.sourceTitle, reason: verse.id);
    }
  });

  test('每日成语均来自词语索引并可打开详情', () async {
    final repository = AssetWordRepository();
    final catalog = await repository.dailyCatalog();
    expect(catalog.count(DailyContentType.idiom), 48089);
    final seen = <String>{};
    for (var position = 0;
        position < catalog.count(DailyContentType.idiom);
        position++) {
      final entry = catalog.entryAt(DailyContentType.idiom, position);
      expect(entry.definition, isNotEmpty);
      expect(entry.pinyin, isNotEmpty);
      seen.add(entry.word);
    }
    expect(seen.length, 48089);
    for (final position in [0, 24044, 48088]) {
      final entry = catalog.entryAt(DailyContentType.idiom, position);
      expect((await repository.findExact(entry.word))?.definition,
          entry.definition);
    }
  });

  test('多音字闯关资源包含100关并从主字典补入单', () async {
    final lessons = await PolyphonicLearningRepository().all();
    expect(lessons, hasLength(100));
    final single = lessons.singleWhere((lesson) => lesson.character == '单');
    expect(single.level, 58);
    expect(single.readings, orderedEquals(['dān', 'shàn', 'chán']));
    expect(single.phrases, orderedEquals(['单独', '单县', '单于']));
    expect(single.meanings.where((value) => value.isNotEmpty), hasLength(3));
  });

  test('文化资源包含完整节气、节日、诸子与百家姓读音', () async {
    final repository = AssetCultureRepository();
    final schools = await repository.getByCategory(CultureCategory.schools);
    final schoolEntries =
        schools.where((item) => item.id.startsWith('school-'));
    expect(schoolEntries, hasLength(12));
    expect(schoolEntries.every((item) => item.content.length > 100), isTrue);
    expect(schools, hasLength(12));
    final classics = await repository.getByCategory(CultureCategory.classics);
    final schoolBooks =
        classics.where((item) => schoolBookIdSet.contains(item.id));
    expect(schoolBooks.map((item) => item.id).toSet(), schoolBookIdSet);
    for (final entry in schoolBookIds.entries) {
      expect(schoolEntries.any((item) => item.id == entry.key), isTrue);
      expect(entry.value.every((id) => classics.any((item) => item.id == id)),
          isTrue);
    }
    final analects = await repository.getById('classic-lunyu');
    expect(analects?.content, contains('学而时习之'));
    expect(analects?.translation, contains('孔子说'));
    expect(analects?.passages, hasLength(1171));
    expect(
      analects?.passages.every((passage) =>
          passage.original.isNotEmpty && passage.translation.isNotEmpty),
      isTrue,
    );
    for (final id in [
      'classic-mengzi',
      'classic-daxue',
      'classic-zhongyong',
      'classic-sanzijing',
      'classic-shishuo-xinyu',
      'classic-liezi',
      'classic-qianziwen',
      'classic-zhouli',
      'classic-mozi',
      'classic-tiangong-kaiwu',
      'classic-sunzi-bingfa',
      'classic-sunbin-bingfa',
      'classic-shangshu',
      'classic-shanhaijing',
      'classic-zhuangzi',
      'classic-dizigui',
      'classic-xuxiake-youji',
      'classic-xinjing',
      'classic-baopuzi',
      'classic-wenxin-diaolong',
      'classic-mengxi-bitan',
      'classic-qijing-shisanpian',
      'classic-liji',
      'classic-yizhuan',
      'classic-laozi',
      'classic-xunzi',
      'classic-caigentan',
      'classic-hanfeizi',
      'classic-guiguzi',
    ]) {
      final classic = await repository.getById(id);
      expect(classic?.translation, isNotEmpty, reason: id);
      expect(classic?.passages, isNotEmpty, reason: id);
      expect(
        classic?.passages.every((passage) => passage.original.isNotEmpty),
        isTrue,
        reason: id,
      );
      expect(
        classic?.passages.any((passage) => passage.translation.isNotEmpty),
        isTrue,
        reason: id,
      );
    }

    final other = await repository.getByCategory(CultureCategory.other);
    expect(classics, hasLength(28));
    expect(classics.map((item) => item.id), contains('other-youmengying'));
    expect(classics.every((item) => !primerBookIds.contains(item.id)), isTrue);
    expect(other.where((item) => item.id.startsWith('classic-')), hasLength(3));
    expect(
        other.map((item) => item.id),
        containsAll([
          'classic-sanzijing',
          'classic-qianziwen',
          'classic-dizigui',
        ]));
    expect(
      other.map((e) => e.title),
      containsAll(['百家姓', '二十四节气', '传统节日', '古代称谓']),
    );
    expect(other.map((e) => e.sourceId), isNot(contains('placeholder')));
    final dream = await repository.getById('other-youmengying');
    expect(dream?.notes, isNotEmpty);
    final surnames = await repository.getById('other-surnames');
    final surname = surnames!;
    expect(surname.readingContent, contains('赵(zhào)'));
    expect(surname.readingContent, contains('归海(guī hǎi)'));
    expect(surname.readingContent, contains('万俟(mò qí) 司马(sī mǎ)'));
    final lines = surname.content.split('\n');
    expect(lines, everyElement(hasLength(4)));
    expect(lines.length.isEven, isTrue);
    for (var index = 0; index < lines.length; index += 2) {
      expect('${lines[index]}${lines[index + 1]}', hasLength(8));
    }
    expect(lines.sublist(lines.length - 2), ['第五言福', '百家姓终']);

    final solar = await repository.getById('other-solar');
    expect(solar!.content.split('\n').where((e) => e.contains('|')),
        hasLength(24));
    expect(solar.content, contains('春雨惊春清谷天'));
    final festivals = await repository.getById('other-festival');
    final festivalRows = festivals!.content
        .split('\n')
        .where((line) => line.contains('|'))
        .map((line) => line.split('|'))
        .toList();
    expect(festivalRows, hasLength(26));
    expect(festivalRows.map((row) => row.first).toSet(),
        festivalEntries.map((entry) => entry.name).toSet());
    expect(festivalRows, everyElement(hasLength(2)));
    expect(
        festivalEntries.every((entry) =>
            entry.history.isNotEmpty &&
            entry.customs.isNotEmpty &&
            entry.meaning.isNotEmpty &&
            entry.sourceTitle.isNotEmpty),
        isTrue);
    expect(ethnicFestivalEntries, hasLength(18));
    expect(ethnicFestivalEntries.map((entry) => entry.community).toSet().length,
        greaterThanOrEqualTo(10));
    expect(
        ethnicFestivalEntries.every((entry) =>
            entry.date.isNotEmpty &&
            entry.community.isNotEmpty &&
            entry.history.isNotEmpty &&
            entry.customs.isNotEmpty &&
            entry.sourceTitle.isNotEmpty),
        isTrue);
  });

  test('诗词索引包含唐宋各两万及真实注释赏析', () async {
    final repository = AssetPoetryRepository();
    final converter = await HanScriptConverter.load();
    final catalog = await repository.catalog();
    final selection = catalog.select(const PoetryQuery());
    final items = [
      for (var index = 0; index < selection.length; index++)
        selection.itemAt(index),
    ];
    expect(catalog.length, greaterThan(40000));
    expect(items.where((e) => e.dynasty == '唐').length,
        greaterThanOrEqualTo(20000));
    expect(items.where((e) => e.dynasty == '宋'), hasLength(20000));
    expect(items.any((e) => e.notes.isNotEmpty), isTrue);
    expect(items.any((e) => e.translation.isNotEmpty), isTrue);
    expect(items.any((e) => e.appreciation.isNotEmpty), isTrue);
    expect(
        items.map((e) => e.shuffleKey),
        orderedEquals(
          items.map((e) => e.shuffleKey).toList()..sort(),
        ));
    final sample = items.first;
    expect(
      sample.searchText,
      contains(converter
          .toSimplified(sample.title)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '')),
    );
    expect(sample.searchText,
        contains(converter.toSimplified(sample.author).toLowerCase()));
    expect(
      items.every((item) =>
          item.content
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .length >=
          2),
      isTrue,
    );
    final reloaded = await repository.getById(sample.id);
    expect(reloaded?.id, sample.id);
    expect(reloaded?.content, sample.content);

    final translated = catalog.select(
      const PoetryQuery(translatedOnly: true),
    );
    expect(translated.length, greaterThan(4000));
    expect(
      [
        for (var index = 0; index < translated.length; index++)
          translated.itemAt(index).translation,
      ],
      everyElement(isNotEmpty),
    );
    final untranslated = items.firstWhere((item) => item.translation.isEmpty);
    final searched = catalog.select(PoetryQuery(text: untranslated.searchText));
    expect(
      [
        for (var index = 0; index < searched.length; index++)
          searched.itemAt(index).id,
      ],
      contains(untranslated.id),
    );
    const query = PoetryQuery(text: '明月', translatedOnly: true);
    final optimized = catalog.select(query);
    final actual = {
      for (var index = 0; index < optimized.length; index++)
        optimized.itemAt(index).id,
    };
    final unfiltered = catalog.select(const PoetryQuery());
    final expected = {
      for (var index = 0; index < unfiltered.length; index++)
        if (unfiltered.itemAt(index).searchText.contains(query.text) &&
            unfiltered.itemAt(index).translation.isNotEmpty)
          unfiltered.itemAt(index).id,
    };
    expect(actual, expected);
  });

  test('全量诗词二进制资源可完整解码', () async {
    final repository = AssetPoetryRepository();
    final catalog = await repository.catalog(fullLibrary: true);
    final standard = await repository.catalog();
    final selection = catalog.select(const PoetryQuery());
    expect(catalog.length, 367905);
    expect(standard.length, 54659);
    expect(selection.itemAt(0).id, startsWith('poetry-'));
    expect(selection.itemAt(selection.length - 1).searchText, isNotEmpty);
    String? extraId;
    for (var index = 0; index < catalog.length; index++) {
      final id = catalog.itemAt(index).id;
      if (standard.findById(id) == null) {
        extraId = id;
        break;
      }
    }
    expect(extraId, isNotNull);
    expect(await repository.getById(extraId!), isNull);
    expect(await repository.getById(extraId, fullLibrary: true), isNotNull);
    final ascending = standard.select(
      const PoetryQuery(order: PoetryOrder.ascending),
    );
    expect(
        ascending.itemAt(0).sequence, lessThan(ascending.itemAt(1).sequence));
    expect(
      () => catalog.subset(ByteData.sublistView(Uint8List(16))),
      throwsFormatException,
    );
  });

  test('诗词二进制解码器拒绝错误签名与截断数据', () {
    expect(
      () => PoetryBinaryCodec.open(ByteData.sublistView(Uint8List(12))),
      throwsFormatException,
    );
    final validHeader = Uint8List.fromList([
      ...PoetryBinaryCodec.signature,
      1,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
    expect(
      () => PoetryBinaryCodec.open(ByteData.sublistView(validHeader)),
      throwsFormatException,
    );
  });
}
