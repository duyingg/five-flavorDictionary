import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/committed_slider.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';
import 'floating_preferences.dart';
import 'floating_search_setting.dart';

class FloatingSettingsPage extends ConsumerWidget {
  const FloatingSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(floatingPreferencesProvider);
    final controller = ref.read(floatingPreferencesProvider.notifier);
    void save(Future<void> operation) {
      operation.catchError((Object _) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('悬浮球设置保存失败，请重试')));
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('悬浮球设置')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: TextButton(
                onPressed: () => ref.invalidate(floatingPreferencesProvider),
                child: const Text('读取失败，点击重试'))),
        data: (preferences) {
          final s = preferences.display;
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          Widget section(String title, List<Widget> children) => Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: TextStyle(color: muted)),
                      const SizedBox(height: 10),
                      Card(child: Column(children: children)),
                    ]),
              );
          List<Widget> switches(
                  List<(String, bool, AppSettings Function(AppSettings, bool))>
                      options) =>
              [
                for (var index = 0; index < options.length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  SwitchListTile(
                    title: Text(options[index].$1),
                    subtitle: switch (options[index].$1) {
                      '剪切板自动搜索' => const Text('单击悬浮窗后自动查询剪切板内容'),
                      _ => null,
                    },
                    value: options[index].$2,
                    onChanged: (v) => save(controller.setDisplay(
                        (current) => options[index].$3(current, v))),
                  ),
                ],
              ];
          return ResponsiveContent(
              maxWidth: 700,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                section('悬浮球', [
                  const FloatingSearchSetting(),
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        Text('悬浮球不透明度 ${(preferences.opacity * 100).round()}%'),
                        CommittedSlider(
                            value: preferences.opacity,
                            min: .2,
                            max: 1,
                            divisions: 16,
                            labelBuilder: (v) => '${(v * 100).round()}%',
                            onCommitted: (v) => save(controller.setPreferences(
                                (current) => current.copyWith(opacity: v)))),
                      ])),
                ]),
                section('悬浮窗大小', [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        Text(
                            '悬浮窗宽度 ${(preferences.windowWidth * 100).round()}%'),
                        CommittedSlider(
                            value: preferences.windowWidth,
                            min: .6,
                            max: 1,
                            divisions: 8,
                            labelBuilder: (v) => '${(v * 100).round()}%',
                            onCommitted: (v) => save(controller.setPreferences(
                                (current) =>
                                    current.copyWith(windowWidth: v)))),
                        Text(
                            '悬浮窗高度 ${(preferences.windowHeight * 100).round()}%'),
                        CommittedSlider(
                            value: preferences.windowHeight,
                            min: .35,
                            max: .95,
                            divisions: 12,
                            labelBuilder: (v) => '${(v * 100).round()}%',
                            onCommitted: (v) => save(controller.setPreferences(
                                (current) =>
                                    current.copyWith(windowHeight: v)))),
                      ])),
                ]),
                section('悬浮窗字号', [
                  RadioGroup<AppFontScale>(
                      groupValue: s.fontScale,
                      onChanged: (v) {
                        if (v != null) {
                          save(controller.setDisplay(
                              (current) => current.copyWith(fontScale: v)));
                        }
                      },
                      child: Column(children: [
                        for (final scale in AppFontScale.values)
                          RadioListTile<AppFontScale>(
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: scale,
                              title: Text(scale.label))
                      ])),
                ]),
                section('词条显示设置', [
                  ...switches([
                    (
                      '拼音',
                      s.showPinyin,
                      (current, v) => current.copyWith(showPinyin: v)
                    ),
                    (
                      '注音符号',
                      s.showZhuyin,
                      (current, v) => current.copyWith(showZhuyin: v)
                    ),
                    (
                      '五笔 86',
                      s.showWubi,
                      (current, v) => current.copyWith(showWubi: v)
                    ),
                    (
                      '部首',
                      s.showRadical,
                      (current, v) => current.copyWith(showRadical: v)
                    ),
                    (
                      '笔画数',
                      s.showStrokeCount,
                      (current, v) => current.copyWith(showStrokeCount: v)
                    ),
                    (
                      '字形结构',
                      s.showStructure,
                      (current, v) => current.copyWith(showStructure: v)
                    ),
                    (
                      'Unicode 编码',
                      s.showUnicode,
                      (current, v) => current.copyWith(showUnicode: v)
                    ),
                    (
                      '字形与笔顺',
                      s.showStrokeOrder,
                      (current, v) => current.copyWith(showStrokeOrder: v)
                    ),
                    (
                      '简繁关系（含简繁同形）',
                      s.showScriptRelations,
                      (current, v) => current.copyWith(showScriptRelations: v)
                    ),
                    (
                      '字等级',
                      s.showCharacterLevel,
                      (current, v) => current.copyWith(showCharacterLevel: v)
                    ),
                  ]),
                ]),
                section('查询与操作', [
                  SwitchListTile(
                      title: const Text('显示搜索框'),
                      value: preferences.showSearchBox,
                      onChanged: (v) => save(controller.setPreferences(
                          (current) => current.copyWith(showSearchBox: v)))),
                  const Divider(height: 1),
                  ...switches([
                    (
                      '剪切板自动搜索',
                      s.clipboardSearchEnabled,
                      (current, v) =>
                          current.copyWith(clipboardSearchEnabled: v)
                    ),
                    (
                      '长按汉字查询',
                      s.globalHanLookupEnabled,
                      (current, v) =>
                          current.copyWith(globalHanLookupEnabled: v)
                    )
                  ]),
                ]),
              ]));
        },
      ),
    );
  }
}
