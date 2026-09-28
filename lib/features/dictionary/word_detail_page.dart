import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/language/zhuyin_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';
import 'dictionary_pages.dart';
import 'single_han_validator.dart';

class WordDetailPage extends ConsumerStatefulWidget {
  const WordDetailPage({required this.value, super.key});

  final String value;

  @override
  ConsumerState<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends ConsumerState<WordDetailPage> {
  late final Future<_WordDetailData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WordDetailData?> _load() async {
    final characters = widget.value.characters.toList(growable: false);
    if (characters.length < 2 ||
        characters.any(
          (value) => const SingleHanValidator().validate(value) is! ValidHan,
        )) {
      return null;
    }
    final wordFuture = ref.read(wordRepositoryProvider).findExact(widget.value);
    final entriesFuture = Future.wait(
      characters.map(
        ref.read(dictionaryRepositoryProvider).findExactCharacter,
      ),
    );
    final data = _WordDetailData(
      value: widget.value,
      characters: characters,
      word: await wordFuture,
      entries: await entriesFuture,
    );
    unawaited(
      ref.read(searchHistoryControllerProvider.notifier).add(widget.value),
    );
    return data;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('词语详情'),
          actions: [
            IconButton(
              tooltip: '返回首页',
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(Icons.home_outlined),
            ),
          ],
        ),
        body: FutureBuilder<_WordDetailData?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data;
            if (data == null) {
              return const EmptyState(
                title: '无法查询',
                message: '请输入两个或更多连续汉字。',
              );
            }
            return ResponsiveContent(
              maxWidth: 900,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _WordHeading(data: data),
                  const SizedBox(height: 18),
                  _WordDefinitionCard(data: data),
                  const SizedBox(height: 28),
                  Text('逐字查询',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    '以下内容与单独查询每个汉字时一致。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var index = 0;
                      index < data.characters.length;
                      index++) ...[
                    if (data.entries[index] case final entry?)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: CharacterDetailContent(
                          entry: entry,
                          embedded: true,
                        ),
                      )
                    else
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(data.characters[index]),
                          ),
                          title: Text('${data.characters[index]}（未收录）'),
                          subtitle: const Text('当前单字词库暂无该字详情。'),
                        ),
                      ),
                    if (index != data.characters.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
            );
          },
        ),
      );
}

class _WordHeading extends ConsumerWidget {
  const _WordHeading({required this.data});

  final _WordDetailData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = data.readings;
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            runSpacing: 16,
            children: [
              for (var index = 0; index < data.characters.length; index++)
                SizedBox(
                  width: constraints.maxWidth / 4,
                  child: Column(
                    children: [
                      if (settings.showPinyin)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            readings[index],
                            maxLines: 1,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      if (settings.showZhuyin) ...[
                        if (settings.showPinyin) const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            ZhuyinUtils.fromPinyinAlternatives(readings[index]),
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                      if (settings.showPinyin || settings.showZhuyin)
                        const SizedBox(height: 5),
                      Text(
                        data.characters[index],
                        key: ValueKey('word-heading-character-$index'),
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordDefinitionCard extends StatelessWidget {
  const _WordDefinitionCard({required this.data});

  final _WordDetailData data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('词语释义', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (data.word == null)
                    const Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('未收录'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data.word?.definition ??
                    '当前词语库尚未收录“${data.value}”，下方提供各汉字的独立释义。',
                style: const TextStyle(height: 1.65),
              ),
            ],
          ),
        ),
      );
}

class _WordDetailData {
  const _WordDetailData({
    required this.value,
    required this.characters,
    required this.word,
    required this.entries,
  });

  final String value;
  final List<String> characters;
  final WordEntry? word;
  final List<ChineseEntry?> entries;

  List<String> get readings {
    final wordReadings = word?.pinyin
        .split(RegExp(r'\s+'))
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (wordReadings != null && wordReadings.length == characters.length) {
      return wordReadings;
    }
    return [
      for (final entry in entries)
        if (entry == null || entry.pinyin.isEmpty)
          '—'
        else
          entry.pinyin.take(word == null ? 2 : 1).join(' / '),
    ];
  }
}
