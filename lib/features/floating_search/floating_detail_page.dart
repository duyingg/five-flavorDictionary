import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/language/zhuyin_utils.dart';
import '../../core/widgets/global_han_lookup.dart';
import '../dictionary/han_query.dart';
import '../dictionary/stroke_order_view.dart';
import '../domain/models.dart';
import '../learning/favorite_feedback.dart';
import '../learning/favorite_item.dart';
import 'floating_preferences.dart';

typedef _Result = ({WordEntry? word, List<ChineseEntry?> entries});

/// A compact overlay-specific detail page. It has no dependency on the main
/// application's character/word pages or their layout and navigation.
class FloatingDetailPage extends ConsumerStatefulWidget {
  const FloatingDetailPage({required this.value, super.key});
  final String value;
  @override
  ConsumerState<FloatingDetailPage> createState() => _FloatingDetailPageState();
}

class _FloatingDetailPageState extends ConsumerState<FloatingDetailPage> {
  late Future<_Result?> _future = _load();

  Future<_Result?> _load() async {
    final query = HanQuery.parse(widget.value);
    if (query == null) return null;
    if (!mounted) return null;
    final characters = query.value.characters.toSet();
    final word = query.isCharacter
        ? Future<WordEntry?>.value(null)
        : ref.read(wordRepositoryProvider).findExact(query.value);
    final entries = Future.wait(characters
        .map(ref.read(dictionaryRepositoryProvider).findExactCharacter));
    final (foundWord, foundEntries) = await (word, entries).wait;
    final result = (word: foundWord, entries: foundEntries);
    if (mounted &&
        ref.read(settingsControllerProvider).valueOrNull?.keepSearchHistory ==
            true) {
      // Recheck the global preference in the storage transaction as well: it
      // may have changed while this query or its snapshot was in flight.
      unawaited(ref
          .read(preferencesStoreProvider)
          .addSearchHistory(query.value)
          .catchError((Object _) => <String>[]));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        FloatingPreferences.defaultDisplay;
    final converter = ref.watch(hanScriptConverterProvider).valueOrNull;
    String display(String text) =>
        converter?.convert(text, settings.scriptDisplay) ?? text;
    final single = widget.value.characters.length == 1;
    return Material(
        color: Colors.transparent,
        child: FutureBuilder<_Result?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: TextButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('读取失败，点击重试')));
            }
            final result = snapshot.data;
            if (result == null) return const Center(child: Text('请输入连续汉字'));
            return SelectionArea(
                child: ListView(
                    primary: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(12),
                    children: [
                  if (!single)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(widget.value,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineSmall)),
                                    if (settings.showFavorites)
                                      _FavoriteButton(
                                          value: FavoriteItem(FavoriteKind.word,
                                                  widget.value)
                                              .storageKey)
                                  ]),
                                  if (settings.showPinyin &&
                                      result.word != null)
                                    Text(result.word!.pinyin),
                                  if (settings.showZhuyin &&
                                      result.word != null)
                                    Text(ZhuyinUtils.fromPinyinAlternatives(
                                        result.word!.pinyin)),
                                  const SizedBox(height: 8),
                                  Text(display(result.word?.definition ??
                                      (settings.showFavorites
                                          ? '词库暂未收录，下方可查看逐字释义并收藏自定义词语。'
                                          : '词库暂未收录，下方可查看逐字释义。'))),
                                ]))),
                  for (var i = 0; i < result.entries.length; i++)
                    if (result.entries[i] case final entry?)
                      _FloatingCharacterCard(
                          entry: entry, display: display, compact: !single)
                    else
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                              '${widget.value.characters.toSet().elementAt(i)}：暂未收录')),
                ]));
          },
        ));
  }
}

class _FloatingCharacterCard extends ConsumerWidget {
  const _FloatingCharacterCard(
      {required this.entry, required this.display, required this.compact});
  final ChineseEntry entry;
  final String Function(String) display;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider).valueOrNull ??
        FloatingPreferences.defaultDisplay;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GlobalHanLookupBlocker(
                    child: Text(entry.character,
                        style: const TextStyle(fontSize: 44, height: 1.2))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (s.showPinyin) Text(entry.pinyin.join(' · ')),
                      if (s.showZhuyin)
                        Text(entry.pinyin
                            .map(ZhuyinUtils.fromPinyin)
                            .join(' · ')),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        if (s.showRadical) Text('部首 ${entry.radical}'),
                        if (s.showStrokeCount) Text('${entry.strokeCount} 画'),
                        if (s.showStructure) Text(entry.structure),
                        if (s.showUnicode) Text(entry.unicode),
                        if (s.showWubi && entry.wubi.isNotEmpty)
                          Text('五笔 ${entry.wubi}'),
                      ]),
                    ])),
                if (s.showFavorites) _FavoriteButton(value: entry.character),
              ]),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (s.showScriptRelations) ...[
                  Chip(label: Text(entry.script.label)),
                  for (final form in {
                    ...entry.simplifiedForms,
                    ...entry.traditionalForms
                  }.where((v) => v != entry.character))
                    ActionChip(
                        label: Text(form),
                        onPressed: () =>
                            context.push(AppRoutes.character(form))),
                ],
                if (s.showCharacterLevel)
                  Chip(label: Text('${entry.characterLevel} 级字')),
              ]),
              if (s.showStrokeOrder) ...[
                const Divider(),
                Center(
                    child: SizedBox.square(
                        dimension: compact ? 140 : 180,
                        child: entry.strokeOrderAsset == null
                            ? GlobalHanLookupBlocker(
                                child: FittedBox(child: Text(entry.character)))
                            : StrokeOrderView(
                                assetPath: entry.strokeOrderAsset!))),
              ],
              const Divider(),
              Text('释义', style: Theme.of(context).textTheme.titleMedium),
              if (entry.senses.isEmpty) const Text('暂无释义'),
              for (var i = 0; i < entry.senses.length; i++)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s.showPinyin && entry.senses[i].pinyin.isNotEmpty)
                            Text(entry.senses[i].pinyin),
                          Text(display(
                              '${i + 1}. ${entry.senses[i].partOfSpeech.isEmpty ? '' : '【${entry.senses[i].partOfSpeech}】'}${entry.senses[i].definition}')),
                          if (entry.senses[i].examples.isNotEmpty)
                            Text(display(
                                '例：${entry.senses[i].examples.join('；')}')),
                        ])),
              if (s.showStrokeOrder &&
                  entry.decomposition != null &&
                  !entry.decomposition!.startsWith('？'))
                Text(display('字形分解：${entry.decomposition}')),
              if (s.showScriptRelations && entry.variants.isNotEmpty)
                Text('异体字：${entry.variants.join('、')}'),
            ])));
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.value});
  final String value;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(favoritesControllerProvider).valueOrNull?.contains(value) ??
            false;
    return IconButton(
        tooltip: selected ? '取消收藏' : '收藏',
        onPressed: () => toggleFavoriteWithFeedback(context, ref, value),
        icon: Icon(selected ? Icons.star : Icons.star_border));
  }
}
