import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/language/pinyin_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/character_visibility.dart';
import '../domain/models.dart';
import 'pinyin_choice_pool.dart';

class PolyphonicLearningPage extends ConsumerWidget {
  const PolyphonicLearningPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('多音字学习')),
        body: ResponsiveContent(
          maxWidth: 680,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(
              '选择学习方式',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 20),
            _PolyphonicModeCard(
              icon: Icons.route_outlined,
              title: '闯关',
              progress:
                  '当前第 ${min(ref.watch(polyphonicChallengeLevelProvider) + 1, 100)} 关',
              description: '猜出多音字的全部读音',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const _PolyphonicChallengePage(),
              )),
            ),
            const SizedBox(height: 16),
            _PolyphonicModeCard(
              icon: Icons.refresh,
              title: '无尽模式',
              progress:
                  '当前第 ${ref.watch(polyphonicEndlessCorrectProvider) ~/ 10 + 1} 轮',
              description: '随机挑战，关卡会随着轮次增加难度',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const _PolyphonicEndlessPage(),
              )),
            ),
          ]),
        ),
      );
}

class _PolyphonicModeCard extends StatelessWidget {
  const _PolyphonicModeCard({
    required this.icon,
    required this.title,
    required this.progress,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String progress;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon,
                      color: Theme.of(context).colorScheme.primary, size: 29),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: Theme.of(context).textTheme.titleLarge),
                          const Spacer(),
                          Text(
                            progress,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        description,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      );
}

class _PolyphonicChallengePage extends ConsumerStatefulWidget {
  const _PolyphonicChallengePage();
  @override
  ConsumerState<_PolyphonicChallengePage> createState() =>
      _PolyphonicChallengePageState();
}

class _PolyphonicChallengePageState
    extends ConsumerState<_PolyphonicChallengePage> {
  late int _level;
  var _reading = 0;
  final _guessed = <String>[];
  bool? _correct;

  @override
  void initState() {
    super.initState();
    _level = ref.read(polyphonicChallengeLevelProvider);
  }

  Future<void> _answer(bool value, List<PolyphonicLesson> lessons) async {
    setState(() => _correct = value);
    if (!value) return;
    final lesson = lessons[_level];
    final currentReading = lesson.readings[_reading];
    final currentPhrase = lesson.phrases[_reading];
    final meaning =
        _reading < lesson.meanings.length ? lesson.meanings[_reading] : '';
    _guessed.add(lesson.readings[_reading]);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 42),
        title: const Text('本音达成'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(currentPhrase,
              style:
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${lesson.character} · $currentReading',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const Divider(height: 28),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              meaning.isEmpty ? '当前字典尚未收录该读音的释义。' : meaning,
              style: const TextStyle(height: 1.6),
            ),
          ),
        ]),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                Text(_reading + 1 < lesson.readings.length ? '下一个读音' : '下一关'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _correct = null;
      if (_reading + 1 < lesson.readings.length) {
        _reading++;
      } else {
        _level++;
        ref.read(polyphonicChallengeLevelProvider.notifier).state = _level;
        _reading = 0;
        _guessed.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('多音字闯关')),
        body: ref.watch(polyphonicLessonsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const EmptyState(title: '关卡加载失败', message: '无法读取多音字关卡文件'),
              data: (lessons) {
                if (_level >= lessons.length) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.emoji_events,
                          size: 72,
                          color: Theme.of(context).colorScheme.secondary),
                      const SizedBox(height: 16),
                      const Text('已通关', style: TextStyle(fontSize: 30)),
                    ]),
                  );
                }
                final lesson = lessons[_level];
                return ResponsiveContent(
                  maxWidth: 620,
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    Row(children: [
                      Text('本关汉字：${lesson.character}',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text('第 ${_level + 1} 关',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary)),
                      Text('  ·  共 ${lessons.length} 关',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ]),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(children: [
                          Text('请选择词组中“${lesson.character}”的读音'),
                          const SizedBox(height: 18),
                          Text(lesson.phrases[_reading],
                              style: const TextStyle(
                                  fontSize: 48, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 22),
                          Wrap(spacing: 10, runSpacing: 10, children: [
                            for (var index = 0;
                                index < lesson.readings.length;
                                index++)
                              Container(
                                width: 88,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(index < _guessed.length
                                    ? _guessed[index]
                                    : ''),
                              ),
                          ]),
                          const SizedBox(height: 24),
                          PinyinChoicePool(
                            key: ValueKey('${lesson.level}-$_reading'),
                            acceptedReadings: [lesson.readings[_reading]],
                            onAnswer: (reading) =>
                                _answer(reading != null, lessons),
                          ),
                          if (_correct != null) ...[
                            const SizedBox(height: 14),
                            Text(_correct! ? '回答正确' : '当前词组的读音不正确',
                                style: TextStyle(
                                    color: _correct!
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.error)),
                          ],
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            ),
      );
}

class _EndlessData {
  const _EndlessData(this.lessons, this.expanded);
  final List<PolyphonicLesson> lessons;
  final List<ChineseEntry> expanded;
}

class _PolyphonicEndlessPage extends ConsumerStatefulWidget {
  const _PolyphonicEndlessPage();
  @override
  ConsumerState<_PolyphonicEndlessPage> createState() =>
      _PolyphonicEndlessPageState();
}

class _PolyphonicEndlessPageState
    extends ConsumerState<_PolyphonicEndlessPage> {
  late final Future<_EndlessData> _dataFuture;
  final _random = Random();
  ChineseEntry? _current;
  var _correctCount = 0;
  final _guessedReadings = <String>{};
  String? _feedback;
  bool _advancing = false;

  String _readingKey(String reading) =>
      '${PinyinUtils.initialOf(reading)}|${PinyinUtils.finalOf(reading)}|${PinyinUtils.toneOf(reading)}';

  @override
  void initState() {
    super.initState();
    _correctCount = ref.read(polyphonicEndlessCorrectProvider);
    _dataFuture = _load();
  }

  Future<_EndlessData> _load() async {
    final settings = await ref.read(settingsControllerProvider.future);
    final lessons = await ref.read(polyphonicLearningRepositoryProvider).all();
    final entries = await ref.read(dictionaryRepositoryProvider).all();
    final seen = <String>{};
    final expanded = entries
        .where((entry) =>
            entry.isVisibleFor(
              display: settings.scriptDisplay,
              maxLevel: settings.maxCharacterLevel,
            ) &&
            !entry.difficult &&
            entry.pinyin.length > 1 &&
            !entry.pinyin.any(PinyinUtils.isCompoundReading) &&
            seen.add(entry.character))
        .toList(growable: false);
    return _EndlessData(lessons, expanded);
  }

  ChineseEntry _pick(_EndlessData data) {
    final pool = _correctCount < 10
        ? data.lessons
            .map((lesson) => ChineseEntry(
                  character: lesson.character,
                  pinyin: lesson.readings,
                  radical: '',
                  strokeCount: 0,
                  structure: '',
                  unicode: '',
                  senses: const [],
                  sourceId: '多音字闯关题库',
                ))
            .toList(growable: false)
        : data.expanded;
    if (pool.length == 1) return pool.first;
    ChineseEntry next;
    do {
      next = pool[_random.nextInt(pool.length)];
    } while (next.character == _current?.character);
    return next;
  }

  void _answer(String? reading, _EndlessData data) {
    if (_advancing) return;
    if (reading == null) {
      setState(() => _feedback = '读音不正确');
      return;
    }
    final key = _readingKey(reading);
    if (_guessedReadings.contains(key)) {
      setState(() => _feedback = '这个读音已答对');
      return;
    }
    final required = _current!.pinyin.map(_readingKey).toSet();
    setState(() {
      _guessedReadings.add(key);
      _feedback = _guessedReadings.length == required.length
          ? '全部读音答对'
          : '回答正确，继续回答其他读音';
      _advancing = _guessedReadings.length == required.length;
    });
    if (!_advancing) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _correctCount++;
        ref.read(polyphonicEndlessCorrectProvider.notifier).state =
            _correctCount;
        _current = _pick(data);
        _guessedReadings.clear();
        _feedback = null;
        _advancing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('多音字无尽模式')),
        body: FutureBuilder<_EndlessData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return snapshot.hasError
                  ? const EmptyState(title: '加载失败', message: '无法读取多音字题库')
                  : const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            _current ??= _pick(data);
            final entry = _current!;
            return ResponsiveContent(
              maxWidth: 620,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                Row(children: [
                  Text('第 ${_correctCount ~/ 10 + 1} 轮',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text('已猜中 $_correctCount 个'),
                ]),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(children: [
                      const Text('请答出这个字的全部读音'),
                      Text(entry.character,
                          style: const TextStyle(fontSize: 100)),
                      Text(
                          '已答对 ${_guessedReadings.length}/${entry.pinyin.map(_readingKey).toSet().length} 个读音'),
                      PinyinChoicePool(
                        key: ValueKey(
                            '$entry-${entry.character}-$_correctCount'),
                        acceptedReadings: entry.pinyin,
                        onAnswer: (reading) => _answer(reading, data),
                      ),
                      if (_feedback != null) ...[
                        const SizedBox(height: 14),
                        Text(_feedback!,
                            style: TextStyle(
                                color: _feedback == '读音不正确'
                                    ? Theme.of(context).colorScheme.error
                                    : Colors.green)),
                      ],
                    ]),
                  ),
                ),
              ]),
            );
          },
        ),
      );
}
