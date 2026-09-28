import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/data/poetry_binary_codec.dart';
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

  test('每日诗句均可在标准诗词库定位到原诗', () async {
    final verses =
        await AssetDailyContentRepository().getByType(DailyContentType.verse);
    final catalog = await AssetPoetryRepository().catalog();
    final converter = await HanScriptConverter.load();

    for (final verse in verses) {
      final firstClause = verse.title.split(RegExp(r'[，。！？；,.!?;]')).first;
      final query = converter
          .toSimplified(firstClause)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      final selection = await catalog.selectAsync(
        PoetryQuery(
          text: query,
        ),
      );
      expect(selection, isNotNull, reason: verse.title);
      expect(selection!.length, greaterThan(0), reason: verse.title);
      final matchingPoems = [
        for (var index = 0; index < selection.length; index++)
          selection.itemAt(index),
      ].where((poem) => converter
          .toSimplified(poem.content)
          .contains(converter.toSimplified(firstClause)));
      expect(matchingPoems, isNotEmpty, reason: verse.title);
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
        classic?.passages.every((passage) =>
            passage.original.isNotEmpty && passage.translation.isNotEmpty),
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
  });

  test('全量诗词二进制资源可完整解码', () async {
    final catalog = await AssetPoetryRepository().catalog(fullLibrary: true);
    final selection = catalog.select(const PoetryQuery());
    expect(catalog.length, 367905);
    expect(selection.itemAt(0).id, startsWith('poetry-'));
    expect(selection.itemAt(selection.length - 1).searchText, isNotEmpty);
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
