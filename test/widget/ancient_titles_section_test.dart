import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/culture/ancient_titles_section.dart';

void main() {
  testWidgets('古代称谓图表区分父系、母系和堂表亲属', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AncientTitlesSection(),
        ),
      ),
    ));

    expect(find.text('父系亲属'), findsOneWidget);
    expect(find.text('母系亲属'), findsOneWidget);
    expect(find.text('堂兄弟姊妹'), findsOneWidget);
    expect(find.text('姑表兄弟姊妹'), findsOneWidget);
    expect(find.text('舅表兄弟姊妹'), findsOneWidget);
    expect(find.text('姨表兄弟姊妹'), findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
