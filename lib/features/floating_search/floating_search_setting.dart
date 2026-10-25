import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'floating_preferences.dart';
import 'floating_search_platform.dart';

class FloatingSearchSetting extends ConsumerStatefulWidget {
  const FloatingSearchSetting({super.key});

  @override
  ConsumerState<FloatingSearchSetting> createState() =>
      _FloatingSearchSettingState();
}

class _FloatingSearchSettingState extends ConsumerState<FloatingSearchSetting> {
  bool _busy = false;

  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    try {
      if (value && !await FloatingSearchPlatform.prepareEnable()) {
        _message('未获得悬浮窗权限，功能尚未开启');
        return;
      }
      if (!mounted) return;
      await ref.read(floatingPreferencesProvider.notifier).setPreferences(
            (s) => s.copyWith(enabled: value),
          );
    } on PlatformException catch (error) {
      _message(error.message ?? '无法开启悬浮查询，请稍后重试');
    } on MissingPluginException {
      _message('当前安装包未包含悬浮查询组件');
    } catch (_) {
      _message('设置保存失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(floatingPreferencesProvider
        .select((value) => value.valueOrNull?.enabled ?? false));
    return SwitchListTile(
      title: const Text('悬浮球查询'),
      subtitle: Text(!FloatingSearchPlatform.supported
          ? '目前仅支持 Android'
          : _busy
              ? '正在处理悬浮窗授权……'
              : '悬浮球闲置 5 秒后贴边隐藏，点击唤醒，再次点击展开独立查询窗口；'),
      value: enabled,
      onChanged: _busy || !FloatingSearchPlatform.supported ? null : _change,
    );
  }
}
