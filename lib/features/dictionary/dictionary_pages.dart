import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/language/zhuyin_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/global_han_lookup.dart';
import '../domain/models.dart';
import 'single_han_validator.dart';
import 'stroke_order_view.dart';

class CharacterDetailPage extends ConsumerStatefulWidget {
  const CharacterDetailPage({required this.value, super.key});
  final String value;

  @override
  ConsumerState<CharacterDetailPage> createState() =>
      _CharacterDetailPageState();
}

class _CharacterDetailPageState extends ConsumerState<CharacterDetailPage> {
  late final Future<ChineseEntry?> future;

  @override
  void initState() {
    super.initState();
    final valid = const SingleHanValidator().validate(widget.value) is ValidHan;
    future = valid
        ? ref
            .read(dictionaryRepositoryProvider)
            .findExactCharacter(widget.value)
        : Future.value(null);
    future.then((entry) {
      if (entry != null) {
        ref.read(searchHistoryControllerProvider.notifier).add(entry.character);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('汉字详情'),
        actions: [
          IconButton(
            tooltip: '返回首页',
            onPressed: () => context.go(AppRoutes.home),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: FutureBuilder<ChineseEntry?>(
        future: future,
        builder: (context, snapshot) {
          final entry = snapshot.data;
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (entry == null) {
            return const EmptyState(
                title: '未找到该字', message: '当前词库暂未收录，可以返回查询其他汉字。');
          }
          return CharacterDetailContent(entry: entry);
        },
      ),
    );
  }
}

class CharacterDetailContent extends ConsumerStatefulWidget {
  const CharacterDetailContent({
    required this.entry,
    this.embedded = false,
    super.key,
  });

  final ChineseEntry entry;
  final bool embedded;

  @override
  ConsumerState<CharacterDetailContent> createState() =>
      _CharacterDetailContentState();
}

class _CharacterDetailContentState
    extends ConsumerState<CharacterDetailContent> {
  ChineseEntry get entry => widget.entry;
  bool get embedded => widget.embedded;

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesControllerProvider).valueOrNull ?? {};
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    final scriptRelations = _scriptRelationLabels(entry);
    final showStrokeOrder =
        settings.showStrokeOrder && entry.strokeOrderAsset != null;
    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            key: const Key('character-primary-visual'),
            dimension: embedded ? 96 : 112,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GlobalHanLookupBlocker(
                child: _StaticCharacterGlyph(character: entry.character),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                if (settings.showPinyin)
                  Text(
                    entry.pinyin.join(' · '),
                    key: const Key('character-attribute-pinyin'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                if (settings.showZhuyin && entry.pinyin.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    entry.pinyin.map(ZhuyinUtils.fromPinyin).join(' · '),
                    key: const Key('character-attribute-zhuyin'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (settings.showRadical)
                      Text(
                        '部首 ${entry.radical}',
                        key: const Key('character-attribute-radical'),
                      ),
                    if (settings.showStrokeCount)
                      Text(
                        '${entry.strokeCount} 画',
                        key: const Key('character-attribute-strokes'),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (settings.showStructure)
                      Text(
                        entry.structure,
                        key: const Key('character-attribute-structure'),
                      ),
                    if (settings.showUnicode)
                      Text(
                        entry.unicode,
                        key: const Key('character-attribute-unicode'),
                      ),
                    if (settings.showWubi && entry.wubi.isNotEmpty)
                      Text(
                        '五笔 ${entry.wubi}',
                        key: const Key('character-attribute-wubi'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var index = 0; index < scriptRelations.length; index++)
                      Chip(
                        key: Key('character-attribute-script-$index'),
                        visualDensity: VisualDensity.compact,
                        label: Text(scriptRelations[index]),
                      ),
                    Chip(
                      key: const Key('character-attribute-level'),
                      visualDensity: VisualDensity.compact,
                      label: Text('${entry.characterLevel} 级字'),
                    ),
                    if (entry.pinyin.length > 1)
                      Chip(
                        key: const Key('character-attribute-reading-count'),
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.graphic_eq, size: 16),
                        label: Text('多音字（${entry.pinyin.length} 个读音）'),
                      ),
                    if (entry.variants.isNotEmpty)
                      Chip(
                        key: const Key('character-attribute-variants'),
                        visualDensity: VisualDensity.compact,
                        label: Text('异体字：${entry.variants.join('、')}'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: favorites.contains(entry.character) ? '取消收藏' : '收藏',
            onPressed: () => ref
                .read(favoritesControllerProvider.notifier)
                .toggle(entry.character),
            icon: Icon(
              favorites.contains(entry.character)
                  ? Icons.star
                  : Icons.star_border,
              color: Theme.of(context).colorScheme.secondary,
              size: 30,
            ),
          ),
        ],
      ),
      const Divider(height: 36),
      Row(
        children: [
          Text(
            showStrokeOrder ? '笔顺' : '字形展示',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Spacer(),
          if (showStrokeOrder)
            Text(
              '共 ${entry.strokeCount} 画',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Center(
        child: SizedBox.square(
          dimension: 260,
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: showStrokeOrder
                  ? StrokeOrderView(assetPath: entry.strokeOrderAsset!)
                  : GlobalHanLookupBlocker(
                      child: _StaticCharacterGlyph(
                        character: entry.character,
                        key: const Key('static-character-display'),
                      ),
                    ),
            ),
          ),
        ),
      ),
      const Divider(height: 36),
      Text('释义', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (entry.senses.isEmpty)
        Text(
          '暂无释义，待后续补充。',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        )
      else
        for (var i = 0; i < entry.senses.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (settings.showPinyin &&
                    entry.senses[i].pinyin.isNotEmpty &&
                    (i == 0 ||
                        entry.senses[i - 1].pinyin !=
                            entry.senses[i].pinyin)) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      entry.senses[i].pinyin,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                Text(
                  '${i + 1}. '
                  '${entry.senses[i].partOfSpeech.isEmpty ? '' : '【${entry.senses[i].partOfSpeech}】'}'
                  '${entry.senses[i].definition}'
                  '${entry.senses[i].examples.isEmpty ? '' : '\n例：${entry.senses[i].examples.join('；')}'}',
                ),
              ],
            ),
          ),
      if (entry.decomposition != null &&
          !entry.decomposition!.startsWith('？')) ...[
        const Divider(height: 36),
        Text('字形分解', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(entry.decomposition!),
      ],
      const SizedBox(height: 30),
      Text('数据来源：${entry.sourceId}',
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12)),
    ];
    if (embedded) {
      return SelectionArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    }
    return SelectionArea(
      child: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: children,
        ),
      ),
    );
  }
}

class _StaticCharacterGlyph extends StatelessWidget {
  const _StaticCharacterGlyph({required this.character, super.key});

  final String character;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: character,
      child: SizedBox.expand(
        key: const Key('static-character-glyph'),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: character == '𪚥'
              ? const _FourDragonsGlyph()
              : FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    character,
                    style: const TextStyle(
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FourDragonsGlyph extends StatelessWidget {
  const _FourDragonsGlyph();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 92,
      height: .82,
      fontWeight: FontWeight.w600,
    );
    return const FittedBox(
      key: Key('four-dragons-glyph'),
      fit: BoxFit.contain,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text('龍', style: style), Text('龍', style: style)],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text('龍', style: style), Text('龍', style: style)],
          ),
        ],
      ),
    );
  }
}

List<String> _scriptRelationLabels(ChineseEntry entry) {
  final simplified = entry.simplifiedForms
      .where((character) => character != entry.character)
      .toList();
  final traditional = entry.traditionalForms
      .where((character) => character != entry.character)
      .toList();
  if (simplified.isEmpty && traditional.isEmpty) return const ['简繁同形'];
  return [
    if (simplified.isNotEmpty) '简体字：${simplified.join('、')}',
    if (traditional.isNotEmpty) '繁体字：${traditional.join('、')}',
  ];
}
