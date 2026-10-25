import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';

class LearningPage extends StatelessWidget {
  const LearningPage({super.key});
  static const _items = [
    (
      '今日汉字',
      '每日随机学习十个汉字',
      Icons.calendar_month_outlined,
      AppRoutes.learningToday
    ),
    (
      '小学语文生字',
      '按年级和上下册学习统编版写字表',
      Icons.school_outlined,
      AppRoutes.learningPrimarySchoolCharacters
    ),
    (
      '文言文字典',
      '查询字词释义与典籍中的原句',
      Icons.menu_book_outlined,
      AppRoutes.learningClassicalDictionary
    ),
    (
      '词语成语学习',
      '输入词语或按逐字拼音查找',
      Icons.library_books_outlined,
      AppRoutes.learningWordStudy
    ),
    ('收藏', '查看收藏的汉字、词语、成语和诗词', Icons.star, AppRoutes.learningFavorites),
    ('猜汉字', '趣味猜字，增长知识', Icons.quiz_outlined, AppRoutes.learningGuess),
    ('造句', '用汉字造句练习', Icons.edit_outlined, AppRoutes.learningSentence),
    (
      '多音字学习',
      '闯关或无尽练习不同语境下的读音',
      Icons.route_outlined,
      AppRoutes.learningPolyphonic
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ResponsiveContent(
          maxWidth: 760,
          child: Column(children: [
            const PageHeading('学习'),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final theme = Theme.of(context);
                  final descriptionStyle = theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ) ??
                      TextStyle(color: theme.colorScheme.onSurfaceVariant);
                  // List padding, Card margins, inner padding and both icons.
                  final textWidth = constraints.maxWidth - 150;
                  final availableTextWidth = textWidth > 1 ? textWidth : 1.0;
                  double textHeight(String value, TextStyle? style) {
                    final painter = TextPainter(
                      text: TextSpan(text: value, style: style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(maxWidth: availableTextWidth);
                    final height = painter.height;
                    painter.dispose();
                    return height;
                  }

                  final contentHeight = _items.map((item) {
                    final labelHeight =
                        textHeight(item.$1, theme.textTheme.titleLarge) +
                            3 +
                            textHeight(item.$2, descriptionStyle);
                    return labelHeight > 34 ? labelHeight : 34.0;
                  }).reduce((a, b) => a > b ? a : b);
                  final cardHeight = contentHeight + 36;

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return SizedBox(
                        height: cardHeight,
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push(item.$4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              child: Row(children: [
                                Icon(item.$3,
                                    color: i.isEven
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                    size: 34),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(item.$1,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 3),
                                      Text(item.$2, style: descriptionStyle),
                                    ])),
                                Icon(Icons.chevron_right,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      );
}

class TodayCharacterPage extends ConsumerWidget {
  const TodayCharacterPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('今日汉字')),
        body: ref.watch(todayCharactersProvider).when(
              data: (items) => items.isEmpty
                  ? const EmptyState(title: '暂无内容', message: '本地资源为空')
                  : ResponsiveContent(
                      maxWidth: 900,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width >= 720 ? 5 : 2,
                          childAspectRatio: .88,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context
                                  .push(AppRoutes.character(item.character)),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item.pinyin.join(' · '),
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)),
                                    const SizedBox(height: 5),
                                    Text(item.character,
                                        style: const TextStyle(fontSize: 54)),
                                    const SizedBox(height: 5),
                                    Text(
                                        '${item.strokeCount} 画 · ${item.radical}部',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const EmptyState(title: '加载失败', message: '请稍后重试'),
            ),
      );
}
