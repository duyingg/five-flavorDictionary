import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/features/data/repositories.dart';
import 'package:wuwei_dictionary/features/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('诗词简繁展示和搜索使用同一转换规则', () async {
    final converter = await HanScriptConverter.load();
    const traditional = '黃鶴樓\n昔人已乘黃鶴去。';
    const simplified = '黄鹤楼\n昔人已乘黄鹤去。';

    expect(
        converter.convert(traditional, ScriptDisplay.simplified), simplified);
    expect(
        converter.convert(simplified, ScriptDisplay.traditional), traditional);

    final canonicalSearch =
        converter.toSimplified('黃鶴樓崔顥昔人已乘黃鶴去').replaceAll(RegExp(r'\s+'), '');
    for (final query in ['黄鹤楼', '黃鶴樓']) {
      expect(canonicalSearch, contains(converter.toSimplified(query)));
    }
  });
}
