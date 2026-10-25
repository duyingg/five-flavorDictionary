import 'package:characters/characters.dart';

import 'single_han_validator.dart';

class HanQuery {
  const HanQuery._(this.value, this.isCharacter);

  final String value;
  final bool isCharacter;

  static HanQuery? parse(String input) {
    final value = input.trim();
    final characters = value.characters.take(17).toList(growable: false);
    if (characters.isEmpty || characters.length > 16) return null;
    if (characters.any(
      (character) =>
          const SingleHanValidator().validate(character) is! ValidHan,
    )) {
      return null;
    }
    return HanQuery._(value, characters.length == 1);
  }
}
