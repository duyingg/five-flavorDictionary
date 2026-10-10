import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';

class SearchHistoryPage extends ConsumerWidget {
  const SearchHistoryPage({super.key});

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空全部查询历史？'),
        content: const Text('清空后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(searchHistoryControllerProvider.notifier).clear();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('查询历史已清空')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('清空失败，请重试')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('查询历史'),
        actions: [
          if (history.valueOrNull?.isNotEmpty ?? false)
            Tooltip(
              message: '清空全部查询历史',
              child: TextButton.icon(
                onPressed: () => _clearHistory(context, ref),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size(88, 48),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('清空'),
              ),
            ),
        ],
      ),
      body: history.when(
        data: (values) => values.isEmpty
            ? const EmptyState(
                title: '暂无查询历史',
                message: '从首页查询汉字或词语后会记录在这里',
              )
            : ResponsiveContent(
                maxWidth: 700,
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: values.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    leading: CircleAvatar(
                      child: Text(values[index].characters.first),
                    ),
                    title: Text(values[index]),
                    subtitle: index == 0 ? const Text('刚刚查询过') : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      values[index].characters.length == 1
                          ? AppRoutes.character(values[index])
                          : AppRoutes.word(values[index]),
                    ),
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(title: '读取失败', message: '无法读取查询历史'),
      ),
    );
  }
}
