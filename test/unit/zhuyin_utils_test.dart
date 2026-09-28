import 'package:flutter_test/flutter_test.dart';
import 'package:wuwei_dictionary/core/language/zhuyin_utils.dart';

void main() {
  test('带调拼音转换为注音符号', () {
    expect(ZhuyinUtils.fromPinyin('hàn'), 'ㄏㄢˋ');
    expect(ZhuyinUtils.fromPinyin('yín háng'), 'ㄧㄣˊ ㄏㄤˊ');
    expect(ZhuyinUtils.fromPinyin('zhōng'), 'ㄓㄨㄥ');
    expect(ZhuyinUtils.fromPinyin('yuè'), 'ㄩㄝˋ');
    expect(ZhuyinUtils.fromPinyin('de'), '˙ㄉㄜ');
  });

  test('多音显示逐项转换并保留分隔符', () {
    expect(
      ZhuyinUtils.fromPinyinAlternatives('xíng / háng'),
      'ㄒㄧㄥˊ / ㄏㄤˊ',
    );
    expect(ZhuyinUtils.fromPinyinAlternatives('—'), '—');
  });
}
