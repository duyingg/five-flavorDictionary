import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/learning/learning_pages.dart';

void main() {
  testWidgets('学习入口在手机宽度下变扁并保持完整列表可滚动', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: LearningPage())));
    await tester.pumpAndSettle();

    final firstCard = find.byType(Card).first;
    expect(tester.getSize(firstCard).height, lessThan(110));
    expect(find.text('今日汉字'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('多音字学习'), 250);
    expect(find.text('多音字学习'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
