import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/core/language/pinyin_utils.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/index_search/index_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('拼音声母与韵母归类正确', () {
    expect(PinyinUtils.initialOf('chéng'), 'ch');
    expect(PinyinUtils.finalOf('chéng'), 'eng');
    expect(PinyinUtils.initialOf('ān'), isEmpty);
    expect(PinyinUtils.sectionOf('ān'), 'a');
    expect(PinyinUtils.sectionOf('wú'), 'w');
    expect(PinyinUtils.sectionOf('chéng'), 'c');
    expect(PinyinUtils.sectionOf('shī'), 's');
    expect(PinyinUtils.sectionOf('zhōng'), 'z');
    expect(PinyinUtils.finalOf('yuè'), 've');
    expect(PinyinUtils.displayFinal('ve'), 'üe');
    expect(PinyinUtils.displaySyllable('chéng'), 'cheng');
    expect(PinyinUtils.toneOf('chéng'), 2);
    expect(PinyinUtils.isValidSyllable('chéng'), isTrue);
    expect(PinyinUtils.normalize('chénɡ'), 'cheng');
    expect(PinyinUtils.isValidSyllable('chénɡ'), isTrue);
    expect(PinyinUtils.isValidSyllable('cī'), isTrue);
    expect(PinyinUtils.isValidSyllable('baike'), isFalse);
    expect(PinyinUtils.isValidSyllable('bbpi'), isFalse);
    expect(PinyinUtils.isValidSyllable('ceok'), isFalse);
    expect(PinyinUtils.isValidSyllable('du n'), isFalse);
    expect(PinyinUtils.firstSyllable('tú shū guǎn'), 'tú');
    expect(PinyinUtils.isCompoundReading('tú shū guǎn'), isTrue);
  });

  test('索引目录包含全部导入数据并按层级查询', () async {
    final entries = await AssetDictionaryRepository().all();
    final catalog = IndexCatalog(entries);
    expect(entries.length, 21056);
    expect(catalog.pronunciationsByInitial.values, everyElement(isNotEmpty));
    expect(
        catalog.pronunciationsByInitial.keys,
        orderedEquals(PinyinUtils.pinyinSections.where(
          catalog.pronunciationsByInitial.containsKey,
        )));
    expect(catalog.pronunciationsByInitial['c'], contains('cheng'));
    expect(catalog.pronunciationsByFinal['eng'], contains('cheng'));
    expect(catalog.radicalsByStroke[3], contains('氵'));
    expect(
      catalog.entriesForRadical('氵')[12]?.map((entry) => entry.character),
      contains('澄'),
    );
    expect(
      catalog.entriesForSyllable('cheng')[2]?.map((entry) => entry.character),
      contains('澄'),
    );
  });

  test('多音字只保存一份详情并进入每个读音索引', () async {
    final entries = await AssetDictionaryRepository().all();
    final differences = entries.where((entry) => entry.character == '差');
    expect(differences, hasLength(1));
    final difference = differences.single;
    expect(difference.pinyin, containsAll(['chā', 'cī']));

    final catalog = IndexCatalog(entries);
    final cha = catalog
        .entriesForSyllable('cha')
        .values
        .expand((values) => values)
        .where((entry) => entry.character == '差');
    final ci = catalog
        .entriesForSyllable('ci')
        .values
        .expand((values) => values)
        .where((entry) => entry.character == '差');
    expect(cha, isNotEmpty);
    expect(cha.every((entry) => identical(entry, difference)), isTrue);
    expect(ci.single, same(difference));
  });

  test('释义按读音绑定且来源不再混入旧字典', () async {
    final entries = await AssetDictionaryRepository().all();
    final difference = entries.singleWhere((entry) => entry.character == '差');
    expect(difference.senses, isNotEmpty);
    expect(difference.senses.map((sense) => sense.pinyin).toSet().length,
        greaterThan(1));
    expect(difference.sourceId, contains('chinese-dictionary-main'));
    expect(difference.sourceId, isNot(contains('app-original')));
    expect(difference.sourceId, isNot(contains('pypinyin')));

    final ca = entries.singleWhere((entry) => entry.character == '嚓');
    expect(ca.pinyin, containsAll(['cā', 'chā']));
    expect(ca.senses.map((sense) => sense.pinyin), containsAll(['cā', 'chā']));
  });

  test('一二三级字可按最高级别过滤', () async {
    final entries = await AssetDictionaryRepository().all();
    final level1 = IndexCatalog(entries, maxLevel: 1).entries;
    final level3 = IndexCatalog(entries, maxLevel: 3).entries;
    expect(level1.map((e) => e.character), contains('的'));
    expect(level1.map((e) => e.character), isNot(contains('龘')));
    expect(level3.map((e) => e.character), contains('龘'));
    expect(level1.every((entry) => entry.characterLevel == 1), isTrue);
  });

  test('简繁索引不同时展示对应字形', () async {
    final entries = await AssetDictionaryRepository().all();
    final simplified = IndexCatalog(entries).entries.map((e) => e.character);
    final traditional =
        IndexCatalog(entries, display: ScriptDisplay.traditional)
            .entries
            .map((e) => e.character);
    expect(simplified, contains('汉'));
    expect(simplified, isNot(contains('漢')));
    expect(traditional, contains('漢'));
    expect(traditional, isNot(contains('汉')));
  });

  test('难检字索引严格按笔画数递增', () async {
    final catalog = IndexCatalog(await AssetDictionaryRepository().all());
    final strokes = catalog.difficultByStroke.keys.toList();
    expect(strokes, orderedEquals([...strokes]..sort()));
    final difficult = catalog.difficultByStroke.values
        .expand((entries) => entries)
        .map((entry) => entry.character);
    expect(difficult, contains('了'));
    expect(difficult, isNot(contains('龘')));
  });

  test('复读音置顶且拼音索引只使用首音', () async {
    final entries = await AssetDictionaryRepository().all();
    final catalog = IndexCatalog(entries);
    expect(catalog.difficultByStroke.keys.first, 0);
    final compound =
        catalog.difficultByStroke[0]!.map((entry) => entry.character);
    expect(compound, containsAll(['兙', '浔', '瓧', '圕', '砼']));
    expect(
      catalog.entriesForSyllable('shi').values.expand((values) => values).map(
            (entry) => entry.character,
          ),
      contains('兙'),
    );
    expect(
      catalog.entriesForSyllable('ke').values.expand((values) => values).map(
            (entry) => entry.character,
          ),
      isNot(contains('兙')),
    );

    final library = entries.singleWhere((entry) => entry.character == '圕');
    expect(library.pinyin, containsAll(['tuǎn', 'tú shū guǎn']));
    final concrete = entries.singleWhere((entry) => entry.character == '砼');
    expect(concrete.pinyin, containsAll(['tóng', 'hùn níng tǔ']));
    expect(concrete.senses.map((sense) => sense.definition).join(),
        contains('混凝土'));
  });
}
