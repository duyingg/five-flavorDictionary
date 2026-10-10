import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../core/language/pinyin_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/character_visibility.dart';
import '../domain/models.dart';
import 'pinyin_choice_pool.dart';

class GuessCharacterPage extends ConsumerStatefulWidget {
  const GuessCharacterPage({super.key});
  @override
  ConsumerState<GuessCharacterPage> createState() => _GuessCharacterPageState();
}

class _GuessCharacterPageState extends ConsumerState<GuessCharacterPage> {
  static const _guessedKey = 'learning.guessed-characters.v1';
  late final Future<List<ChineseEntry>> _entriesFuture;
  final _random = Random();
  final _guessed = <String>{};
  List<ChineseEntry>? _cachedPool;
  List<ChineseEntry> _remaining = const [];
  List<ChineseEntry>? _cachedSource;
  ScriptDisplay? _cachedDisplay;
  int? _cachedMaxLevel;
  ChineseEntry? _current;
  bool showHint = false;
  bool? correct;

  @override
  void initState() {
    super.initState();
    _entriesFuture = ref.read(dictionaryRepositoryProvider).all();
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    final preferences = await SharedPreferences.getInstance();
    _guessed.addAll(preferences.getStringList(_guessedKey) ?? const []);
    if (mounted) {
      setState(() {
        _cachedSource = null;
        _current = null;
      });
    }
  }

  List<ChineseEntry> _pool(List<ChineseEntry> entries, AppSettings settings) {
    if (identical(entries, _cachedSource) &&
        settings.scriptDisplay == _cachedDisplay &&
        settings.maxCharacterLevel == _cachedMaxLevel) {
      return _cachedPool!;
    }
    final seen = <String>{};
    final pool = entries
        .where((entry) =>
            entry.isVisibleFor(
              display: settings.scriptDisplay,
              maxLevel: min(settings.maxCharacterLevel, 2),
            ) &&
            entry.pinyin.isNotEmpty &&
            !entry.pinyin.any(PinyinUtils.isCompoundReading) &&
            seen.add(entry.character))
        .toList(growable: false);
    _cachedSource = entries;
    _cachedDisplay = settings.scriptDisplay;
    _cachedMaxLevel = settings.maxCharacterLevel;
    _cachedPool = pool;
    _remaining = [
      for (final entry in pool)
        if (!_guessed.contains(entry.character)) entry,
    ];
    if (_current != null && !_remaining.contains(_current)) _current = null;
    return pool;
  }

  void _pick({bool persistAnswer = false}) {
    if (persistAnswer && _current != null) {
      _guessed.add(_current!.character);
      _remaining.remove(_current);
      SharedPreferences.getInstance().then(
        (value) => value.setStringList(_guessedKey, _guessed.toList()),
      );
    }
    ChineseEntry? next;
    if (_remaining.isNotEmpty) {
      do {
        next = _remaining[_random.nextInt(_remaining.length)];
      } while (_remaining.length > 1 && next == _current);
    }
    setState(() {
      _current = next;
      showHint = false;
      correct = null;
    });
  }

  void _answer(bool isCorrect) {
    setState(() => correct = isCorrect);
    if (isCorrect) {
      Future<void>.delayed(const Duration(milliseconds: 550), () {
        if (mounted) _pick(persistAnswer: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('猜汉字'),
        ),
        body: FutureBuilder<List<ChineseEntry>>(
          future: _entriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const EmptyState(title: '加载失败', message: '无法读取本地字库');
            }
            final settings =
                ref.watch(settingsControllerProvider).valueOrNull ??
                    const AppSettings();
            final pool = _pool(snapshot.data ?? const [], settings);
            if (pool.isEmpty) {
              return const EmptyState(title: '暂无题目', message: '本地字库为空');
            }
            _current ??= _remaining.isEmpty
                ? null
                : _remaining[_random.nextInt(_remaining.length)];
            final entry = _current;
            if (entry == null) {
              return const EmptyState(
                title: '全部猜完了',
                message: '当前字库中的汉字已经全部猜出',
              );
            }
            return ResponsiveContent(
              maxWidth: 620,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(children: [
                        Row(children: [
                          Text('当前已猜出 ${_guessed.length} 字',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pick,
                            icon: const Icon(Icons.casino_outlined),
                            label: const Text('换一个'),
                          ),
                        ]),
                        Text('选择这个汉字的声母、韵母和声调',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                        Text(entry.character,
                            style: const TextStyle(fontSize: 100)),
                        PinyinChoicePool(
                          key: ValueKey(entry.character),
                          acceptedReadings: entry.pinyin,
                          onAnswer: (reading) => _answer(reading != null),
                        ),
                        const SizedBox(height: 20),
                        Row(children: [
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => showHint = !showHint),
                            icon: const Icon(Icons.lightbulb_outline),
                            label: Text(showHint ? '收起提示' : '提示'),
                          ),
                          const Spacer(),
                        ]),
                        if (showHint) ...[
                          const Divider(height: 30),
                          const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text('文字语义')),
                          if (entry.senses.isNotEmpty)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(entry.senses
                                  .map((sense) => sense.definition)
                                  .join('\n')),
                            )
                          else
                            const SizedBox(height: 48),
                        ],
                        if (correct != null) ...[
                          const SizedBox(height: 18),
                          Text(correct! ? '回答正确' : '读音或声调不正确',
                              style: TextStyle(
                                  color: correct!
                                      ? Colors.green
                                      : Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
