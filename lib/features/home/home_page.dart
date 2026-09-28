import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/app_routes.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/global_han_lookup.dart';
import '../dictionary/single_han_validator.dart';
import '../domain/models.dart';
import '../index_search/index_search_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  Future<void> _openDailyContent(DailyContent item) async {
    if (item.type == DailyContentType.word ||
        item.type == DailyContentType.idiom) {
      context.push(AppRoutes.word(item.title));
      return;
    }
    if (item.type != DailyContentType.verse) return;
    final target = await ref.read(dailyPoetryTargetProvider(item).future);
    if (!mounted) return;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂未在诗词库中找到原诗')),
      );
      return;
    }
    context.push(AppRoutes.poetryDetail(target.id));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search() {
    final value = _controller.text.trim();
    final characters = value.characters.toList(growable: false);
    if (characters.length > 1) {
      if (characters.length > 16) {
        setState(() => _error = '一次最多查询 16 个汉字');
        _focus.requestFocus();
        return;
      }
      final valid = characters.every(
        (character) =>
            const SingleHanValidator().validate(character) is ValidHan,
      );
      if (valid) {
        setState(() => _error = null);
        context.push(AppRoutes.word(value));
      } else {
        setState(() => _error = '请输入连续的汉字或词语');
        _focus.requestFocus();
      }
      return;
    }
    final result = const SingleHanValidator().validate(value);
    switch (result) {
      case ValidHan(:final value):
        setState(() => _error = null);
        context.push(AppRoutes.character(value));
      case InvalidHan(:final error):
        setState(() => _error = switch (error) {
              HanInputError.empty => '请输入汉字或词语',
              HanInputError.multipleCharacters => '请输入连续的汉字或词语',
              HanInputError.nonHanCharacter => '请输入有效的汉字',
            });
        _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final daily = ref.watch(dailyContentProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    return SafeArea(
      child: LayoutBuilder(builder: (context, constraints) {
        final compact =
            constraints.maxHeight < 700 || constraints.maxWidth < 390;
        return ResponsiveContent(
          child: Column(
            children: [
              const PageHeading('五味字典'),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 20, 0, compact ? 14 : 20, 12),
                  child: Column(children: [
                    TextField(
                      key: const Key('home-search'),
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: '请输入要查询的汉字或词语',
                        prefixIcon: const Icon(Icons.search),
                        errorText: _error,
                      ),
                    ),
                    if (settings.keepSearchHistory)
                      ref.watch(searchHistoryControllerProvider).when(
                            data: (values) => values.isEmpty
                                ? const SizedBox.shrink()
                                : _RecentSearches(
                                    values: values,
                                    onSelected: (value) {
                                      _controller.text = value;
                                      _search();
                                    },
                                  ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                    Spacer(flex: compact ? 1 : 2),
                    _IndexButtons(
                        compact: compact,
                        onTap: (type) =>
                            context.push(AppRoutes.index(type.name))),
                    Spacer(flex: compact ? 1 : 2),
                    Expanded(
                      flex: compact ? 7 : 9,
                      child: Card(
                        child: Stack(
                          children: [
                            if (!settings.reduceDecoration)
                              const Positioned.fill(child: InkWashDecoration()),
                            daily.when(
                              data: (item) => item == null
                                  ? const EmptyState(
                                      title: '暂无每日内容', message: '请稍后再来看看')
                                  : item.type == DailyContentType.character
                                      ? _DailyCard(
                                          item: item,
                                          compact: compact,
                                          onOpen: null,
                                          onReroll: () => ref
                                              .read(
                                                  dailyRerollProvider.notifier)
                                              .state++,
                                        )
                                      : GlobalHanLookupBlocker(
                                          child: _DailyCard(
                                            item: item,
                                            compact: compact,
                                            onOpen: () =>
                                                _openDailyContent(item),
                                            onReroll: () => ref
                                                .read(dailyRerollProvider
                                                    .notifier)
                                                .state++,
                                          ),
                                        ),
                              loading: () => const Center(
                                  child: CircularProgressIndicator()),
                              error: (_, __) => const EmptyState(
                                  title: '内容加载失败', message: '请检查本地资源后重试'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.values, required this.onSelected});
  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: Row(children: [
          Text('最近查询',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: values.length.clamp(0, 8),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => Center(
                child: ActionChip(
                  label: Text(values[index]),
                  onPressed: () => onSelected(values[index]),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _IndexButtons extends StatelessWidget {
  const _IndexButtons({required this.onTap, required this.compact});
  final ValueChanged<IndexSearchType> onTap;
  final bool compact;
  static const _items = [
    (IndexSearchType.pinyin, 'ā', '拼音查询'),
    (IndexSearchType.radical, '亻', '部首查询'),
    (IndexSearchType.stroke, '1', '笔画查询'),
    (IndexSearchType.difficult, '龘', '难检字索引'),
    (IndexSearchType.rhyme, '韵', '韵脚查询'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final item in _items)
          Expanded(
            child: InkWell(
              onTap: () => onTap(item.$1),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(children: [
                  Container(
                    height: compact ? 50 : 62,
                    width: compact ? 50 : 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary
                          .withValues(alpha: .08 + _items.indexOf(item) * .018),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.outline),
                    ),
                    child: Transform.translate(
                      offset: item.$1 == IndexSearchType.radical
                          ? const Offset(2.5, 0)
                          : Offset.zero,
                      child: Text(item.$2,
                          textAlign: TextAlign.center,
                          strutStyle: StrutStyle(
                            fontSize: compact ? 23 : 27,
                            height: 1,
                            forceStrutHeight: true,
                          ),
                          style: TextStyle(
                            fontSize: compact ? 23 : 27,
                            height: 1,
                          )),
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 9),
                  FittedBox(
                      child:
                          Text(item.$3, style: const TextStyle(fontSize: 13))),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.item,
    required this.onReroll,
    required this.compact,
    required this.onOpen,
  });
  final DailyContent item;
  final VoidCallback onReroll;
  final bool compact;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.all(compact ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text('每日${item.type.label}',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                  onPressed: onReroll,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('换一个')),
            ]),
            Expanded(
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onOpen,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (item.pronunciation != null)
                        Text(item.pronunciation!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      SizedBox(height: compact ? 4 : 8),
                      if (item.type == DailyContentType.verse)
                        _VerseTitle(
                          value: item.title,
                          fontSize: compact ? 28 : 35,
                        )
                      else
                        Text(item.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize:
                                    item.type == DailyContentType.character
                                        ? (compact ? 52 : 72)
                                        : (compact ? 28 : 35),
                                fontWeight: FontWeight.w600)),
                      SizedBox(height: compact ? 8 : 18),
                      Text(item.summary,
                          textAlign: TextAlign.center,
                          maxLines: compact ? 2 : null,
                          overflow: compact ? TextOverflow.ellipsis : null),
                      if (item.author != null) ...[
                        const SizedBox(height: 8),
                        Text('${item.author} · ${item.sourceTitle ?? ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant))
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _VerseTitle extends StatelessWidget {
  const _VerseTitle({required this.value, required this.fontSize});

  final String value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final lines = _verseLines(value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < lines.length; index++)
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                lines[index],
                key: ValueKey('daily-verse-line-$index'),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

List<String> _verseLines(String value) {
  final lines = <String>[];
  final buffer = StringBuffer();
  for (final character in value.characters) {
    buffer.write(character);
    if ('，。！？；：,.!?;:'.contains(character)) {
      lines.add(buffer.toString());
      buffer.clear();
    }
  }
  if (buffer.isNotEmpty) lines.add(buffer.toString());
  return lines.isEmpty ? [value] : lines;
}
