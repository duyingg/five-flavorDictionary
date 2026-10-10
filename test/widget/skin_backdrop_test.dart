import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/core/design/app_theme.dart';
import 'package:wuwei_dictionary/core/widgets/skin_widgets.dart';

void main() {
  testWidgets('皮肤背景按设备尺寸等比缩放', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const image = 'data:image/png;base64,'
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9bLZsAAAAASUVORK5CYII=';
    final theme = ThemeData(extensions: const [
      SkinVisuals(
        background: Colors.white,
        backgroundImage: image,
        backgroundFit: BoxFit.fill,
        backgroundOpacity: 1,
        iconImages: {},
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: const SkinBackdrop(child: SizedBox.expand()),
    ));
    var background = tester.widget<Image>(find.byType(Image));
    expect(background.fit, BoxFit.contain);
    expect(background.width, 320);
    expect(background.height, 560);

    await tester.binding.setSurfaceSize(const Size(900, 600));
    await tester.pump();
    background = tester.widget<Image>(find.byType(Image));
    expect(background.width, 900);
    expect(background.height, 600);
  });
}
