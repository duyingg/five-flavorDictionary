abstract final class ZhuyinUtils {
  static const _accented = <String, (String, int)>{
    'ā': ('a', 1),
    'á': ('a', 2),
    'ǎ': ('a', 3),
    'à': ('a', 4),
    'ē': ('e', 1),
    'é': ('e', 2),
    'ě': ('e', 3),
    'è': ('e', 4),
    'ī': ('i', 1),
    'í': ('i', 2),
    'ǐ': ('i', 3),
    'ì': ('i', 4),
    'ō': ('o', 1),
    'ó': ('o', 2),
    'ǒ': ('o', 3),
    'ò': ('o', 4),
    'ū': ('u', 1),
    'ú': ('u', 2),
    'ǔ': ('u', 3),
    'ù': ('u', 4),
    'ǖ': ('ü', 1),
    'ǘ': ('ü', 2),
    'ǚ': ('ü', 3),
    'ǜ': ('ü', 4),
    'ń': ('n', 2),
    'ň': ('n', 3),
    'ǹ': ('n', 4),
    'ḿ': ('m', 2),
  };

  static const _initials = <String, String>{
    'b': 'ㄅ',
    'p': 'ㄆ',
    'm': 'ㄇ',
    'f': 'ㄈ',
    'd': 'ㄉ',
    't': 'ㄊ',
    'n': 'ㄋ',
    'l': 'ㄌ',
    'g': 'ㄍ',
    'k': 'ㄎ',
    'h': 'ㄏ',
    'j': 'ㄐ',
    'q': 'ㄑ',
    'x': 'ㄒ',
    'zh': 'ㄓ',
    'ch': 'ㄔ',
    'sh': 'ㄕ',
    'r': 'ㄖ',
    'z': 'ㄗ',
    'c': 'ㄘ',
    's': 'ㄙ',
  };

  static const _finals = <String, String>{
    '': '',
    'a': 'ㄚ',
    'o': 'ㄛ',
    'e': 'ㄜ',
    'ê': 'ㄝ',
    'ai': 'ㄞ',
    'ei': 'ㄟ',
    'ao': 'ㄠ',
    'ou': 'ㄡ',
    'an': 'ㄢ',
    'en': 'ㄣ',
    'ang': 'ㄤ',
    'eng': 'ㄥ',
    'er': 'ㄦ',
    'ong': 'ㄨㄥ',
    'i': 'ㄧ',
    'ia': 'ㄧㄚ',
    'ie': 'ㄧㄝ',
    'iao': 'ㄧㄠ',
    'iu': 'ㄧㄡ',
    'ian': 'ㄧㄢ',
    'in': 'ㄧㄣ',
    'iang': 'ㄧㄤ',
    'ing': 'ㄧㄥ',
    'iong': 'ㄩㄥ',
    'u': 'ㄨ',
    'ua': 'ㄨㄚ',
    'uo': 'ㄨㄛ',
    'uai': 'ㄨㄞ',
    'ui': 'ㄨㄟ',
    'uan': 'ㄨㄢ',
    'un': 'ㄨㄣ',
    'uang': 'ㄨㄤ',
    'ueng': 'ㄨㄥ',
    'ü': 'ㄩ',
    'üe': 'ㄩㄝ',
    'üan': 'ㄩㄢ',
    'ün': 'ㄩㄣ',
  };

  static String fromPinyin(String input) => input
      .trim()
      .split(RegExp(r'\s+'))
      .where((syllable) => syllable.isNotEmpty)
      .map(_syllable)
      .join(' ');

  static String fromPinyinAlternatives(String input) =>
      input.split('/').map((value) => fromPinyin(value.trim())).join(' / ');

  static String _syllable(String input) {
    if (!RegExp(r'[a-zA-ZüÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]').hasMatch(input)) {
      return input;
    }
    var tone = 5;
    final buffer = StringBuffer();
    for (final character in input.toLowerCase().split('')) {
      final replacement = _accented[character];
      if (replacement == null) {
        buffer.write(character == 'v' ? 'ü' : character);
      } else {
        buffer.write(replacement.$1);
        tone = replacement.$2;
      }
    }
    var plain = buffer.toString().replaceAll(RegExp(r'[1-5]$'), '');
    final numericTone = int.tryParse(input.substring(input.length - 1));
    if (numericTone != null) tone = numericTone;

    String initial = '';
    for (final candidate in const ['zh', 'ch', 'sh']) {
      if (plain.startsWith(candidate)) initial = candidate;
    }
    if (initial.isEmpty &&
        plain.isNotEmpty &&
        _initials.containsKey(plain[0])) {
      initial = plain[0];
    }
    if (initial.isEmpty &&
        plain.isNotEmpty &&
        (plain[0] == 'y' || plain[0] == 'w')) {
      initial = plain[0];
    }
    var finalPart = plain.substring(initial.length);
    if (const {'zh', 'ch', 'sh', 'r', 'z', 'c', 's'}.contains(initial) &&
        finalPart == 'i') {
      finalPart = '';
    }
    if (initial == 'y') {
      initial = '';
      finalPart = _normalizeY(plain);
    } else if (initial == 'w') {
      initial = '';
      finalPart = _normalizeW(plain);
    } else if (const {'j', 'q', 'x'}.contains(initial)) {
      finalPart = finalPart.replaceFirst('u', 'ü');
    }
    final body =
        '${_initials[initial] ?? ''}${_finals[finalPart] ?? finalPart}';
    final mark = switch (tone) { 2 => 'ˊ', 3 => 'ˇ', 4 => 'ˋ', _ => '' };
    return tone == 5 ? '˙$body' : '$body$mark';
  }

  static String _normalizeY(String value) => switch (value) {
        'yi' => 'i',
        'ya' => 'ia',
        'ye' => 'ie',
        'yao' => 'iao',
        'you' => 'iu',
        'yan' => 'ian',
        'yin' => 'in',
        'yang' => 'iang',
        'ying' => 'ing',
        'yong' => 'iong',
        'yu' => 'ü',
        'yue' => 'üe',
        'yuan' => 'üan',
        'yun' => 'ün',
        _ => value.substring(1),
      };

  static String _normalizeW(String value) => switch (value) {
        'wu' => 'u',
        'wa' => 'ua',
        'wo' => 'uo',
        'wai' => 'uai',
        'wei' => 'ui',
        'wan' => 'uan',
        'wen' => 'un',
        'wang' => 'uang',
        'weng' => 'ueng',
        _ => value.substring(1),
      };
}
