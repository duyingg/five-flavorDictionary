import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wuwei_dictionary/features/data/preferences_store.dart';
import 'package:wuwei_dictionary/features/dictionary/dictionary_pages.dart';
import 'package:wuwei_dictionary/features/dictionary/stroke_order_view.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

ChineseEntry _entry({
  String character = '龘',
  int strokes = 48,
  String? strokeOrderAsset,
}) =>
    ChineseEntry(
      character: character,
      pinyin: const ['dá'],
      wubi: 'UEGD',
      radical: '龍',
      strokeCount: strokes,
      structure: '品字结构',
      unicode: character == '𪚥' ? 'U+2A6A5' : 'U+9F98',
      senses: const [],
      sourceId: 'test',
      strokeOrderAsset: strokeOrderAsset,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        PreferencesKeys.bundledSkinsSeeded: true,
      }));

  testWidgets('有笔顺的字保留普通大字和笔顺但不再提供超大图切换', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CharacterDetailContent(
              entry: _entry(
                character: '砼',
                strokes: 10,
                strokeOrderAsset: 'Aatime/makemeahanzi-master/svgs/30780.svg',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StrokeOrderView), findsOneWidget);
    expect(find.byKey(const Key('static-character-glyph')), findsOneWidget);
    expect(find.byKey(const Key('ultra-large-character')), findsNothing);
    expect(find.text('共 10 画'), findsOneWidget);
  });

  testWidgets('无笔顺资源时只显示静态放大字形且文字可选择', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: CharacterDetailContent(entry: _entry())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StrokeOrderView), findsNothing);
    expect(find.byKey(const Key('static-character-glyph')), findsNWidgets(2));
    expect(find.byKey(const Key('static-character-display')), findsOneWidget);
    expect(find.text('字形展示'), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);
  });

  testWidgets('四个龙组成的𪚥使用稳定组合字形显示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CharacterDetailContent(
              entry: _entry(character: '𪚥', strokes: 64),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final display = find.byKey(const Key('static-character-display'));
    final composite = find.descendant(
      of: display,
      matching: find.byKey(const Key('four-dragons-glyph')),
    );
    expect(composite, findsOneWidget);
    expect(
      find.descendant(of: composite, matching: find.text('龍')),
      findsNWidgets(4),
    );
    expect(find.byKey(const Key('character-primary-visual')), findsOneWidget);
  });

  testWidgets('词条设置可隐藏拼音注音五笔部首笔画等信息', (tester) async {
    SharedPreferences.setMockInitialValues({
      PreferencesKeys.bundledSkinsSeeded: true,
      PreferencesKeys.showPinyin: false,
      PreferencesKeys.showZhuyin: false,
      PreferencesKeys.showWubi: false,
      PreferencesKeys.showRadical: false,
      PreferencesKeys.showStrokeCount: false,
      PreferencesKeys.showStructure: false,
      PreferencesKeys.showUnicode: false,
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: CharacterDetailContent(entry: _entry())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final id in [
      'pinyin',
      'zhuyin',
      'wubi',
      'radical',
      'strokes',
      'structure',
      'unicode',
    ]) {
      expect(find.byKey(Key('character-attribute-$id')), findsNothing);
    }
  });
}
