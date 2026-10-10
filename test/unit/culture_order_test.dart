import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

class _Culture implements CultureRepository {
  @override
  Future<List<CultureItem>> getByCategory(CultureCategory category) async => [
        for (final title in ['中庸', '八卦', '阿房宫'])
          CultureItem(
            id: title,
            category: category,
            title: title,
            subtitle: '',
            summary: '',
            content: '',
            sourceId: 'test',
          ),
      ];

  @override
  Future<CultureItem?> getById(String id) async => null;
}

class _Dictionary implements DictionaryRepository {
  @override
  Future<List<ChineseEntry>> all() async => [];

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async => null;

  @override
  Future<Map<String, String>> primaryPinyinFor(
          Iterable<String> characters) async =>
      {
        '中': 'zhōng',
        '八': 'bā',
        '阿': 'ā',
        '庸': 'yōng',
        '卦': 'guà',
        '房': 'fáng',
        '宫': 'gōng'
      };
}

void main() {
  test('典籍按照完整标题拼音排序', () async {
    final container = ProviderContainer(overrides: [
      cultureRepositoryProvider.overrideWithValue(_Culture()),
      dictionaryRepositoryProvider.overrideWithValue(_Dictionary()),
    ]);
    addTearDown(container.dispose);
    final items = await container.read(sortedClassicsProvider.future);
    expect(items.map((item) => item.title), ['阿房宫', '八卦', '中庸']);
  });
}
