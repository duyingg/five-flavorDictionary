import 'package:characters/characters.dart';

enum HanInputError { empty, multipleCharacters, nonHanCharacter }

sealed class HanValidationResult {
  const HanValidationResult();
}

class ValidHan extends HanValidationResult {
  const ValidHan(this.value);
  final String value;
}

class InvalidHan extends HanValidationResult {
  const InvalidHan(this.error);
  final HanInputError error;
}

class SingleHanValidator {
  const SingleHanValidator();

  HanValidationResult validate(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return const InvalidHan(HanInputError.empty);
    }
    final graphemes = value.characters.iterator;
    graphemes.moveNext();
    final firstGrapheme = graphemes.current;
    if (graphemes.moveNext()) {
      final firstRune = firstGrapheme.runes.firstOrNull;
      if (firstRune == null || !_isHan(firstRune)) {
        return const InvalidHan(HanInputError.nonHanCharacter);
      }
      return const InvalidHan(HanInputError.multipleCharacters);
    }
    final runes = firstGrapheme.runes.iterator;
    if (!runes.moveNext() || !_isHan(runes.current)) {
      return const InvalidHan(HanInputError.nonHanCharacter);
    }
    while (runes.moveNext()) {
      if (!_isVariationSelector(runes.current)) {
        return const InvalidHan(HanInputError.nonHanCharacter);
      }
    }
    return ValidHan(value);
  }

  // Unicode 17.0 CJK Unified Ideographs 与兼容区、扩展区 A-J。
  bool _isHan(int value) =>
      (value >= 0x3400 && value <= 0x4DBF) ||
      (value >= 0x4E00 && value <= 0x9FFF) ||
      (value >= 0xF900 && value <= 0xFAFF) ||
      (value >= 0x20000 && value <= 0x2EE5F) ||
      (value >= 0x2F800 && value <= 0x2FA1F) ||
      (value >= 0x30000 && value <= 0x323AF);

  bool _isVariationSelector(int value) =>
      (value >= 0xFE00 && value <= 0xFE0F) ||
      (value >= 0xE0100 && value <= 0xE01EF);
}
