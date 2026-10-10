import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

Future<void> toggleFavoriteWithFeedback(
    BuildContext context, WidgetRef ref, String key) async {
  final wasFavorite =
      ref.read(favoritesControllerProvider).valueOrNull?.contains(key) ?? false;
  try {
    await ref.read(favoritesControllerProvider.notifier).toggle(key);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(wasFavorite ? '已取消收藏' : '收藏成功'),
      duration: const Duration(seconds: 2),
    ));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('收藏操作失败，请重试')),
    );
  }
}
