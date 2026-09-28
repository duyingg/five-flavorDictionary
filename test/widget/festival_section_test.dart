import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/culture/festival_section.dart';

void main() {
  testWidgets('节日条目可展开阅读历史、习俗和来源', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FestivalSection(content: '春节|农历正月初一\n'),
        ),
      ),
    ));

    expect(find.text('传统节日 · 共 19 项'), findsOneWidget);
    expect(find.text('农历正月初一'), findsOneWidget);
    await tester.tap(find.text('春节'));
    await tester.pumpAndSettle();

    expect(find.textContaining('古称岁首'), findsOneWidget);
    expect(find.textContaining('团年、守岁'), findsWidgets);
    expect(find.textContaining('资料参考：'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
