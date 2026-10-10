import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/learning/primary_school_characters_page.dart';

class _TestDictionaryRepository implements DictionaryRepository {
  static const entries = [
    ChineseEntry(
      character: '学',
      pinyin: ['xué'],
      radical: '子',
      strokeCount: 8,
      structure: '上下',
      unicode: 'U+5B66',
      senses: [],
      sourceId: 'test',
      characterLevel: 1,
    ),
    ChineseEntry(
      character: '习',
      pinyin: ['xí'],
      radical: '乙',
      strokeCount: 3,
      structure: '独体',
      unicode: 'U+4E60',
      senses: [],
      sourceId: 'test',
      characterLevel: 1,
    ),
    ChineseEntry(
      character: '璧',
      pinyin: ['bì'],
      radical: '玉',
      strokeCount: 18,
      structure: '上下',
      unicode: 'U+74A7',
      senses: [],
      sourceId: 'test',
      characterLevel: 2,
    ),
  ];

  @override
  Future<List<ChineseEntry>> all() async => entries;

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async =>
      entries.where((entry) => entry.character == character).firstOrNull;

  @override
  Future<Map<String, String>> primaryPinyinFor(
    Iterable<String> characters,
  ) async =>
      {
        for (final character in characters)
          character: entries
                  .where((entry) => entry.character == character)
                  .firstOrNull
                  ?.pinyin
                  .firstOrNull ??
              '',
      };
}

void main() {
  testWidgets('小学语文写字表书册选择随生字一起滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dictionaryRepositoryProvider.overrideWithValue(
            _TestDictionaryRepository(),
          ),
        ],
        child: const MaterialApp(home: PrimarySchoolCharactersPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 年级上册 · 100 字'), findsOneWidget);
    expect(find.text('璧'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('primary-school-grade-1')), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('primary-school-grade-1')), findsOneWidget);

    await tester.tap(find.text('下册'));
    await tester.pumpAndSettle();

    expect(find.text('1 年级下册 · 200 字'), findsOneWidget);
    await tester.tap(find.byKey(const Key('primary-school-grade-2')));
    await tester.pumpAndSettle();
    expect(find.text('2 年级下册 · 250 字'), findsOneWidget);
  });
}
