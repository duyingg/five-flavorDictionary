import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';
import 'favorite_feedback.dart';
import 'favorite_item.dart';

enum _FavoriteFilter { all, character, word, idiom, poetry }

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  _FavoriteFilter _filter = _FavoriteFilter.all;

  bool _matches(FavoriteItem item) => switch (_filter) {
        _FavoriteFilter.all => true,
        _FavoriteFilter.character => item.kind == FavoriteKind.character,
        _FavoriteFilter.word =>
          item.kind == FavoriteKind.word && item.value.characters.length != 4,
        _FavoriteFilter.idiom =>
          item.kind == FavoriteKind.word && item.value.characters.length == 4,
        _FavoriteFilter.poetry => item.kind == FavoriteKind.poetry,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          if (state.valueOrNull?.isNotEmpty ?? false)
            IconButton(
                tooltip: '清空收藏',
                onPressed: () => _confirmClear(context, ref),
                icon: const Icon(Icons.delete_outline))
        ],
      ),
      body: state.when(
        data: (items) => items.isEmpty
            ? const EmptyState(
                title: '还没有收藏',
                message: '在汉字、词语或诗词详情页点击星标即可收藏',
                icon: Icons.star_border)
            : Builder(builder: (context) {
                final visible = items
                    .map(FavoriteItem.parse)
                    .whereType<FavoriteItem>()
                    .where(_matches)
                    .toList()
                  ..sort((a, b) => a.value.compareTo(b.value));
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (filter, label) in const [
                        (_FavoriteFilter.all, '全部'),
                        (_FavoriteFilter.character, '汉字'),
                        (_FavoriteFilter.word, '词语'),
                        (_FavoriteFilter.idiom, '成语'),
                        (_FavoriteFilter.poetry, '古诗'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      const EmptyState(
                        title: '此类暂无收藏',
                        message: '可以切换其他分类查看',
                      ),
                    for (final favorite in visible)
                      _favoriteTile(context, ref, favorite),
                  ],
                );
              }),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(title: '读取失败', message: '无法读取本地收藏'),
      ),
    );
  }

  Widget _favoriteTile(BuildContext context, WidgetRef ref, FavoriteItem item) {
    final route = switch (item.kind) {
      FavoriteKind.character => AppRoutes.character(item.value),
      FavoriteKind.word => AppRoutes.word(item.value),
      FavoriteKind.poetry => AppRoutes.poetryDetail(item.value),
    };
    return Card(
      child: ListTile(
        onTap: () => context.push(route),
        leading: item.kind == FavoriteKind.character
            ? Text(item.value, style: const TextStyle(fontSize: 36))
            : Icon(item.kind == FavoriteKind.poetry
                ? Icons.auto_stories_outlined
                : Icons.menu_book_outlined),
        title: item.kind == FavoriteKind.poetry
            ? FutureBuilder<PoetryItem?>(
                future: _poem(ref, item.value),
                builder: (_, snapshot) =>
                    Text(snapshot.data?.title ?? '诗词（${item.value}）'),
              )
            : Text(item.value),
        subtitle: Text(switch (item.kind) {
          FavoriteKind.character => '汉字',
          FavoriteKind.word => item.value.characters.length == 4 ? '成语' : '词语',
          FavoriteKind.poetry => '古诗',
        }),
        trailing: IconButton(
          tooltip: '取消收藏',
          onPressed: () =>
              toggleFavoriteWithFeedback(context, ref, item.storageKey),
          icon:
              Icon(Icons.star, color: Theme.of(context).colorScheme.secondary),
        ),
      ),
    );
  }

  Future<PoetryItem?> _poem(WidgetRef ref, String id) async {
    final repository = ref.read(poetryRepositoryProvider);
    return await repository.getById(id) ??
        await repository.getById(id, fullLibrary: true);
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('清空收藏？'),
                content: const Text('此操作会移除全部收藏内容。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('清空'))
                ]));
    if (yes == true) {
      await ref.read(favoritesControllerProvider.notifier).clear();
    }
  }
}
