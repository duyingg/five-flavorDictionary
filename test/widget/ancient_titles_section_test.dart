import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/culture/ancient_titles_section.dart';

void main() {
  testWidgets('古代称谓涵盖多类用法，并可按称谓搜索', (tester) async {
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

    expect(find.text('称呼用法对照'), findsOneWidget);
    expect(find.text('姓名与别称'), findsWidgets);
    expect(find.text('帝王与官爵'), findsWidgets);
    expect(find.text('敬称与对称'), findsWidgets);
    expect(find.text('自称与谦称'), findsWidgets);
    expect(find.text('师友与社会身份'), findsWidgets);
    expect(find.text('亲属称呼'), findsWidgets);
    expect(find.byType(DataTable), findsOneWidget);
    await tester.enterText(find.byType(TextField), '谥号');
    await tester.pump();
    expect(find.text('谥号'), findsWidgets);
    expect(find.text('朕、寡人、孤'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
