import 'package:flutter/services.dart';

import '../domain/models.dart';

class HanScriptConverter {
  const HanScriptConverter._(
      this._simplifiedToTraditional, this._traditionalToSimplified);

  const HanScriptConverter.empty()
      : _simplifiedToTraditional = const {},
        _traditionalToSimplified = const {};

  final Map<int, String> _simplifiedToTraditional;
  final Map<int, String> _traditionalToSimplified;

  static Future<HanScriptConverter> load() async => HanScriptConverter._(
        await _loadMap('assets/data/opencc/STCharacters.txt'),
        await _loadMap('assets/data/opencc/TSCharacters.txt'),
      );

  String convert(String text, ScriptDisplay display) => switch (display) {
        ScriptDisplay.simplified => toSimplified(text),
        ScriptDisplay.traditional => toTraditional(text),
      };

  String toSimplified(String text) => _convert(text, _traditionalToSimplified);

  String toTraditional(String text) => _convert(text, _simplifiedToTraditional);

  String _convert(String text, Map<int, String> replacements) {
    if (text.isEmpty) return text;
    final result = StringBuffer();
    for (final rune in text.runes) {
      result.write(replacements[rune] ?? String.fromCharCode(rune));
    }
    return result.toString();
  }

  static Future<Map<int, String>> _loadMap(String asset) async {
    final raw = await rootBundle.loadString(asset);
    final result = <int, String>{};
    for (final rawLine in raw.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final columns = line.split('\t');
      if (columns.length < 2 || columns.first.runes.length != 1) continue;
      final replacement = columns[1].trim().split(RegExp(r'\s+')).first;
      if (replacement.isEmpty) continue;
      result[columns.first.runes.first] = replacement;
    }
    return Map.unmodifiable(result);
  }
}
