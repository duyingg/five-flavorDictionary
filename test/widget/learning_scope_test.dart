import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/app/providers.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';
import 'package:wuwei_dictionary/features/learning/learning_pages.dart';

class _Dictionary implements DictionaryRepository {
  static const entries = [
    ChineseEntry(
      character: '行',
      pinyin: ['xíng', 'háng'],
      radical: '行',
      strokeCount: 6,
      structure: '左右',
      unicode: 'U+884C',
      senses: [],
      sourceId: 'test',
      characterLevel: 2,
    ),
    ChineseEntry(
      character: '龘',
      pinyin: ['dá'],
      radical: '龍',
      strokeCount: 48,
      structure: '品字',
      unicode: 'U+9F98',
      senses: [],
      sourceId: 'test',
      characterLevel: 3,
    ),
  ];

  @override
  Future<List<ChineseEntry>> all() async => entries;

  @override
  Future<ChineseEntry?> findExactCharacter(String character) async =>
      entries.where((entry) => entry.character == character).firstOrNull;

  @override
  Future<Map<String, String>> primaryPinyinFor(
          Iterable<String> characters) async =>
      {};
}

class _Lessons extends PolyphonicLearningRepository {
  @override
  Future<List<PolyphonicLesson>> all() async => const [
        PolyphonicLesson(
          level: 1,
          character: '行',
          readings: ['xíng', 'háng'],
          phrases: ['行走', '银行'],
          meanings: ['行走', '行业'],
        ),
      ];
}

void main() {
  testWidgets('多音字学习文案展示目标汉字', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dictionaryRepositoryProvider.overrideWithValue(_Dictionary()),
        polyphonicLearningRepositoryProvider.overrideWithValue(_Lessons()),
      ],
      child: const MaterialApp(home: PolyphonicLearningPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('猜出多音字的全部读音'), findsOneWidget);
    expect(find.text('随机挑战，关卡会随着轮次增加难度'), findsOneWidget);
    expect(find.textContaining('闯关使用已整理关卡'), findsNothing);
    await tester.tap(find.text('闯关'));
    await tester.pumpAndSettle();
    expect(find.text('请选择词组中“行”的读音'), findsOneWidget);
  });

  testWidgets('猜汉字仅从一级二级字抽题', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dictionaryRepositoryProvider.overrideWithValue(_Dictionary())
      ],
      child: const MaterialApp(home: GuessCharacterPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('行'), findsOneWidget);
    expect(find.text('龘'), findsNothing);
  });

  testWidgets('无尽模式答对全部读音后才计数并进入下一题', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dictionaryRepositoryProvider.overrideWithValue(_Dictionary()),
        polyphonicLearningRepositoryProvider.overrideWithValue(_Lessons()),
      ],
      child: const MaterialApp(home: PolyphonicLearningPage()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('无尽模式'));
    await tester.pumpAndSettle();
    expect(find.text('请答出这个字的全部读音'), findsOneWidget);
    for (final label in ['x', 'ing', '2 声']) {
      final choice = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
    }
    await tester.ensureVisible(find.text('确认答案'));
    await tester.tap(find.text('确认答案'));
    await tester.pump();
    expect(find.text('回答正确，继续回答其他读音'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('已答对 1/2 个读音'), findsOneWidget);
    expect(find.text('已猜中 0 个', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('确认答案'));
    await tester.pump();
    expect(find.text('这个读音已答对'), findsOneWidget);
    expect(find.text('已答对 1/2 个读音'), findsOneWidget);
    for (final label in ['h', 'ang']) {
      final choice = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
    }
    await tester.ensureVisible(find.text('确认答案'));
    await tester.tap(find.text('确认答案'));
    await tester.pump();
    expect(find.text('全部读音答对'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('已猜中 1 个', skipOffstage: false), findsOneWidget);
  });
}
