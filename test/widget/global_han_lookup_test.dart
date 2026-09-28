import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/core/widgets/global_han_lookup.dart';

void main() {
  testWidgets('普通正文汉字可以触发全局查询', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: GlobalHanLookupRegion(
        enabled: true,
        onCharacter: (value) => selected = value,
        child: const Scaffold(body: Center(child: Text('春风'))),
      ),
    ));

    final box = tester.getRect(find.text('春风'));
    await tester.tapAt(Offset(box.left + 3, box.center.dy));
    await tester.pump();

    expect(selected, '春');
  });

  testWidgets('扩展区汉字代理对可以触发全局查询', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: GlobalHanLookupRegion(
        enabled: true,
        onCharacter: (value) => selected = value,
        child: const Scaffold(body: Center(child: Text('𠮷祥'))),
      ),
    ));

    final box = tester.getRect(find.text('𠮷祥'));
    await tester.tapAt(Offset(box.left + 3, box.center.dy));
    await tester.pump();

    expect(selected, '𠮷');
  });

  testWidgets('滚动正文中的汉字可以触发全局查询', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: GlobalHanLookupRegion(
        enabled: true,
        onCharacter: (value) => selected = value,
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: const [
              Text('文'),
              SizedBox(height: 1000),
            ],
          ),
        ),
      ),
    ));

    final box = tester.getRect(find.text('文'));
    await tester.tapAt(Offset(box.left + 3, box.center.dy));
    await tester.pump();

    expect(selected, '文');
  });

  testWidgets('长按文字留给系统选择复制且不触发查字', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: GlobalHanLookupRegion(
        enabled: true,
        onCharacter: (value) => selected = value,
        child: const Scaffold(
          body: SelectionArea(child: Center(child: Text('可复制文字'))),
        ),
      ),
    ));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('可复制文字')));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump();

    expect(selected, isNull);
  });

  testWidgets('关闭开关后普通正文不触发查询', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: GlobalHanLookupRegion(
        enabled: false,
        onCharacter: (value) => selected = value,
        child: const Scaffold(body: Center(child: Text('春风'))),
      ),
    ));

    await tester.tap(find.text('春风'));
    await tester.pump();

    expect(selected, isNull);
  });

  testWidgets('白名单区域不触发全局查询', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: GlobalHanLookupRegion(
        enabled: true,
        onCharacter: (value) => selected = value,
        child: const Scaffold(
          body: GlobalHanLookupBlocker(child: Center(child: Text('设置'))),
        ),
      ),
    ));

    await tester.tap(find.text('设置'));
    await tester.pump();

    expect(selected, isNull);
  });

  testWidgets('按钮文字保留原操作且不触发全局查询', (tester) async {
    String? selected;
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: GlobalHanLookupRegion(
        enabled: true,
        onCharacter: (value) => selected = value,
        child: Scaffold(
          body: TextButton(
            onPressed: () => pressed = true,
            child: const Text('确定'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('确定'));
    await tester.pump();

    expect(pressed, isTrue);
    expect(selected, isNull);
  });
}
