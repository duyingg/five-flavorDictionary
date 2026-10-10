import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dictionary_repository.dart';
import 'han_script_converter.dart';

class ContextualPinyinRepository {
  ContextualPinyinRepository({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<_ContextualPinyinData>? _loading;

  Future<List<String>> resolve(
    String text,
    DictionaryRepository dictionary,
  ) async {
    final data = await (_loading ??= _load());
    final characters = text.characters.toList(growable: false);
    final exactMatchCharacters =
        data.converter.toSimplified(text).characters.toList(growable: false);
    final fallback = await dictionary.primaryPinyinFor(characters);
    return resolveContextualPinyin(
      characters,
      exactMatchCharacters: exactMatchCharacters,
      exactLinesByFirstCharacter: data.exactLinesByFirstCharacter,
      contextRulesByFirstCharacter: data.contextRulesByFirstCharacter,
      phrasesByFirstCharacter: data.phrasesByFirstCharacter,
      fallback: fallback,
    );
  }

  Future<_ContextualPinyinData> _load() async {
    final values = await Future.wait([
      _bundle.loadString('assets/data/online_annotated_pinyin.tsv'),
      _bundle.loadString('assets/data/verified_classic_pinyin_20260929.tsv'),
      _bundle.loadString('assets/data/tongjia_context_pinyin.tsv'),
      _bundle.loadString('assets/data/phrase_pinyin.txt'),
    ]);
    final converter = await HanScriptConverter.load();
    return compute(
      _decodeContextualPinyinData,
      (values[0], values[1], values[2], values[3], converter),
    );
  }
}

_ContextualPinyinData _decodeContextualPinyinData(
  (String, String, String, String, HanScriptConverter) source,
) =>
    _ContextualPinyinData.decode(
      [source.$1, source.$2],
      source.$3,
      source.$4,
      converter: source.$5,
    );

List<String> resolveContextualPinyin(
  List<String> characters, {
  List<String>? exactMatchCharacters,
  required Map<String, List<ExactPinyinLine>> exactLinesByFirstCharacter,
  Map<String, List<ContextualPinyinRule>> contextRulesByFirstCharacter =
      const {},
  required Map<String, List<PinyinPhrase>> phrasesByFirstCharacter,
  required Map<String, String> fallback,
}) {
  final matchCharacters = exactMatchCharacters ?? characters;
  assert(matchCharacters.length == characters.length);
  final readings = List<String>.filled(characters.length, '');
  final locked = List<bool>.filled(characters.length, false);
  final hanIndexes = <int>[];
  final hanCharacters = <String>[];
  final hanMatchCharacters = <String>[];
  final han = StringBuffer();
  for (var index = 0; index < characters.length; index++) {
    if (_isHan(characters[index])) {
      hanIndexes.add(index);
      hanCharacters.add(characters[index]);
      hanMatchCharacters.add(matchCharacters[index]);
      han.write(characters[index]);
    }
  }
  final hanText = han.toString();
  for (var start = 0; start < hanCharacters.length; start++) {
    if (locked[hanIndexes[start]]) continue;
    final candidates = exactLinesByFirstCharacter[hanMatchCharacters[start]];
    if (candidates == null) continue;
    for (final candidate in candidates) {
      if (start + candidate.characters.length > hanCharacters.length) {
        continue;
      }
      var matches = true;
      for (var offset = 0; offset < candidate.characters.length; offset++) {
        if (locked[hanIndexes[start + offset]] ||
            hanMatchCharacters[start + offset] !=
                candidate.characters[offset]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      for (var offset = 0; offset < candidate.pinyin.length; offset++) {
        final target = hanIndexes[start + offset];
        readings[target] = candidate.pinyin[offset];
        locked[target] = true;
      }
      break;
    }
  }

  for (var start = 0; start < hanText.length; start++) {
    final candidates = contextRulesByFirstCharacter[hanText[start]];
    if (candidates == null) continue;
    for (final rule in candidates) {
      if (!hanText.startsWith(rule.text, start)) continue;
      final target = start + rule.targetOffset;
      if (target < hanIndexes.length) {
        final characterIndex = hanIndexes[target];
        if (locked[characterIndex]) continue;
        readings[characterIndex] = rule.pinyin;
        locked[characterIndex] = true;
      }
    }
  }

  for (var index = 0; index < characters.length; index++) {
    if (!_isHan(characters[index]) || locked[index]) continue;
    final candidates = phrasesByFirstCharacter[matchCharacters[index]];
    if (candidates == null) continue;
    for (final candidate in candidates) {
      if (index + candidate.characters.length > characters.length) continue;
      var matches = true;
      for (var offset = 0; offset < candidate.characters.length; offset++) {
        if (matchCharacters[index + offset] != candidate.characters[offset] ||
            locked[index + offset]) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      for (var offset = 0; offset < candidate.characters.length; offset++) {
        readings[index + offset] = candidate.pinyin[offset];
      }
      index += candidate.characters.length - 1;
      break;
    }
  }

  for (var index = 0; index < characters.length; index++) {
    if (readings[index].isEmpty) {
      readings[index] = fallback[characters[index]] ?? '';
    }
  }
  return readings;
}

bool _isHan(String value) {
  if (value.runes.length != 1) return false;
  final rune = value.runes.single;
  return (rune >= 0x3400 && rune <= 0x9fff) ||
      (rune >= 0x20000 && rune <= 0x323af);
}

class _ContextualPinyinData {
  const _ContextualPinyinData({
    required this.exactLinesByFirstCharacter,
    required this.contextRulesByFirstCharacter,
    required this.phrasesByFirstCharacter,
    required this.converter,
  });

  final Map<String, List<ExactPinyinLine>> exactLinesByFirstCharacter;
  final Map<String, List<ContextualPinyinRule>> contextRulesByFirstCharacter;
  final Map<String, List<PinyinPhrase>> phrasesByFirstCharacter;
  final HanScriptConverter converter;

  factory _ContextualPinyinData.decode(
    List<String> exactRaws,
    String contextRaw,
    String phraseRaw, {
    HanScriptConverter converter = const HanScriptConverter.empty(),
  }) {
    final exact = <String, List<ExactPinyinLine>>{};
    final seenExact = <String>{};
    void addExact(String text, List<String> readings) {
      final characters = text.characters.toList(growable: false);
      if (characters.length != readings.length || characters.isEmpty) return;
      if (!seenExact.add(text)) return;
      final candidates = exact.putIfAbsent(characters.first, () => []);
      candidates.add(ExactPinyinLine(characters: characters, pinyin: readings));
    }

    for (final exactRaw in exactRaws) {
      for (final line in exactRaw.split('\n')) {
        final separator = line.indexOf('\t');
        if (separator <= 0) continue;
        final text = line.substring(0, separator);
        final readings = line.substring(separator + 1).trim().split(' ');
        addExact(converter.toSimplified(text), readings);
      }
    }
    for (final candidates in exact.values) {
      candidates.sort(
        (left, right) => right.characters.length.compareTo(
          left.characters.length,
        ),
      );
    }

    final contextRules = <String, List<ContextualPinyinRule>>{};
    for (final line in contextRaw.split('\n')) {
      final parts = line.trim().split('\t');
      if (parts.length != 3) continue;
      final offset = int.tryParse(parts[1]);
      if (parts[0].isEmpty || offset == null || offset >= parts[0].length) {
        continue;
      }
      contextRules.putIfAbsent(parts[0][0], () => []).add(
            ContextualPinyinRule(
              text: parts[0],
              targetOffset: offset,
              pinyin: parts[2],
            ),
          );
    }
    for (final rules in contextRules.values) {
      rules
          .sort((left, right) => right.text.length.compareTo(left.text.length));
    }

    final phrases = <String, List<PinyinPhrase>>{};
    for (final rawLine in phraseRaw.split('\n')) {
      final line = rawLine.split('#').first.trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf(': ');
      if (separator <= 0) continue;
      final text = line.substring(0, separator);
      final characters =
          converter.toSimplified(text).characters.toList(growable: false);
      final readings = line.substring(separator + 2).trim().split(' ');
      if (characters.length < 2 || characters.length != readings.length) {
        continue;
      }
      phrases.putIfAbsent(characters.first, () => []).add(
            PinyinPhrase(characters: characters, pinyin: readings),
          );
    }
    for (final candidates in phrases.values) {
      candidates.sort(
        (left, right) => right.characters.length.compareTo(
          left.characters.length,
        ),
      );
    }
    return _ContextualPinyinData(
      exactLinesByFirstCharacter: exact,
      contextRulesByFirstCharacter: contextRules,
      phrasesByFirstCharacter: phrases,
      converter: converter,
    );
  }
}

class ExactPinyinLine {
  const ExactPinyinLine({required this.characters, required this.pinyin});
  final List<String> characters;
  final List<String> pinyin;
}

class ContextualPinyinRule {
  const ContextualPinyinRule({
    required this.text,
    required this.targetOffset,
    required this.pinyin,
  });
  final String text;
  final int targetOffset;
  final String pinyin;
}

class PinyinPhrase {
  const PinyinPhrase({required this.characters, required this.pinyin});
  final List<String> characters;
  final List<String> pinyin;
}
