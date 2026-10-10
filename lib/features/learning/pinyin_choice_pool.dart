import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/language/pinyin_utils.dart';

class PinyinChoicePool extends StatefulWidget {
  const PinyinChoicePool({
    super.key,
    required this.acceptedReadings,
    required this.onAnswer,
  });
  final List<String> acceptedReadings;
  final ValueChanged<String?> onAnswer;

  @override
  State<PinyinChoicePool> createState() => PinyinChoicePoolState();
}

class PinyinChoicePoolState extends State<PinyinChoicePool> {
  static const _finals = [
    'a',
    'o',
    'e',
    'ai',
    'ei',
    'ao',
    'ou',
    'an',
    'en',
    'ang',
    'eng',
    'ong',
    'i',
    'ia',
    'ie',
    'iao',
    'iu',
    'ian',
    'in',
    'iang',
    'ing',
    'iong',
    'u',
    'ua',
    'uo',
    'uai',
    'ui',
    'uan',
    'un',
    'uang',
    'ueng',
    'v',
    've',
    'van',
    'vn',
    'er'
  ];
  late final List<String> _initialPool;
  late final List<String> _finalPool;
  String? _initial;
  String? _final;
  int? _tone;

  @override
  void initState() {
    super.initState();
    final seed = widget.acceptedReadings.join('|').hashCode;
    final random = Random(seed);
    final correctInitials =
        widget.acceptedReadings.map(PinyinUtils.initialOf).toSet();
    final correctFinals =
        widget.acceptedReadings.map(PinyinUtils.finalOf).toSet();
    _initialPool = _buildPool(
      correctInitials,
      ['', ...PinyinUtils.initials],
      8,
      random,
    );
    _finalPool = _buildPool(correctFinals, _finals, 10, random);
  }

  static List<T> _buildPool<T>(
      Set<T> answers, List<T> source, int size, Random random) {
    final result = answers.toList();
    final candidates = source.where((item) => !answers.contains(item)).toList()
      ..shuffle(random);
    result.addAll(candidates.take(max(0, size - result.length)));
    return result..shuffle(random);
  }

  void _submit() {
    if (_initial == null || _final == null || _tone == null) return;
    String? matchedReading;
    for (final reading in widget.acceptedReadings) {
      if (PinyinUtils.initialOf(reading) == _initial &&
          PinyinUtils.finalOf(reading) == _final &&
          PinyinUtils.toneOf(reading) == _tone) {
        matchedReading = reading;
        break;
      }
    }
    widget.onAnswer(matchedReading);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('声母'),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final value in _initialPool)
            ChoiceChip(
              label: Text(value.isEmpty ? '零声母' : value),
              selected: _initial == value,
              onSelected: (_) => setState(() => _initial = value),
            ),
        ]),
        const SizedBox(height: 14),
        const Text('韵母'),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final value in _finalPool)
            ChoiceChip(
              label: Text(PinyinUtils.displayFinal(value)),
              selected: _final == value,
              onSelected: (_) => setState(() => _final = value),
            ),
        ]),
        const SizedBox(height: 14),
        const Text('声调'),
        const SizedBox(height: 6),
        Wrap(spacing: 7, children: [
          for (var tone = 1; tone <= 5; tone++)
            ChoiceChip(
              label: Text(tone == 5 ? '轻声' : '$tone 声'),
              selected: _tone == tone,
              onSelected: (_) => setState(() => _tone = tone),
            ),
        ]),
        const SizedBox(height: 18),
        FilledButton(onPressed: _submit, child: const Text('确认答案')),
      ]);
}
