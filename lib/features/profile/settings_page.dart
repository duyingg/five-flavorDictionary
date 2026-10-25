import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/bundled_skin_loader.dart';
import '../../core/design/skin_package_loader.dart';
import '../../core/widgets/committed_slider.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';
import '../floating_search/floating_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({required this.kind, super.key});
  final String kind;

  String get title => switch (kind) {
        'daily' => '每日内容偏好',
        'data' => '更改诗词库',
        'skin' => '皮肤设置',
        _ => '设置'
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kind == 'floating') return const FloatingSettingsPage();
    final asyncSettings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: asyncSettings.when(
        data: (settings) => ResponsiveContent(
            maxWidth: 700,
            child: ListView(
                padding: const EdgeInsets.all(20),
                children: _buildContent(context, ref, settings))),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(title: '设置读取失败', message: '请重新打开页面'),
      ),
    );
  }

  List<Widget> _buildContent(
      BuildContext context, WidgetRef ref, AppSettings settings) {
    final controller = ref.read(settingsControllerProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (kind == 'skin') {
      return [const _SkinSettingsPanel()];
    }
    if (kind == 'daily') {
      return [
        Text('首页每日内容展示类型', style: TextStyle(color: muted)),
        const SizedBox(height: 12),
        Card(
            child: RadioGroup<DailyContentType>(
                groupValue: settings.dailyContentType,
                onChanged: (value) {
                  if (value != null) {
                    controller.setSettings(
                        (s) => s.copyWith(dailyContentType: value));
                  }
                },
                child: Column(children: [
                  for (final type in DailyContentType.values)
                    RadioListTile<DailyContentType>(
                        title: Text(type.label), value: type)
                ]))),
      ];
    }
    final displayContent = <Widget>[
      Text('汉字查询偏好', style: TextStyle(color: muted)),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            SegmentedButton<ScriptDisplay>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(88, 40)),
              ),
              segments: const [
                ButtonSegment(
                    value: ScriptDisplay.simplified, label: Text('简体')),
                ButtonSegment(
                    value: ScriptDisplay.traditional, label: Text('繁体')),
              ],
              selected: {settings.scriptDisplay},
              onSelectionChanged: (values) => controller.setSettings(
                (value) => value.copyWith(scriptDisplay: values.first),
              ),
            ),
            const SizedBox(height: 12),
            Text('最高显示 ${settings.maxCharacterLevel} 级字'),
            CommittedSlider(
              value: settings.maxCharacterLevel.toDouble(),
              min: 1,
              max: 3,
              divisions: 2,
              labelBuilder: (value) => '${value.round()} 级',
              tickLabels: const ['一级', '二级', '三级'],
              onCommitted: (value) => controller.setSettings(
                (current) => current.copyWith(
                  maxCharacterLevel: value.round(),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Text('词条显示设置', style: TextStyle(color: muted)),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            SwitchListTile(
                title: const Text('简繁关系（含简繁同形）'),
                value: settings.showScriptRelations,
                onChanged: (value) => controller.setSettings(
                    (s) => s.copyWith(showScriptRelations: value))),
            SwitchListTile(
                title: const Text('字等级（一级字、二级字、三级字）'),
                value: settings.showCharacterLevel,
                onChanged: (value) => controller
                    .setSettings((s) => s.copyWith(showCharacterLevel: value))),
            SwitchListTile(
                title: const Text('收藏按钮'),
                value: settings.showFavorites,
                onChanged: (value) => controller
                    .setSettings((s) => s.copyWith(showFavorites: value))),
            SwitchListTile(
              title: const Text('拼音'),
              value: settings.showPinyin,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showPinyin: value),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('注音符号'),
              subtitle: const Text('例如：汉 ㄏㄢˋ'),
              value: settings.showZhuyin,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showZhuyin: value),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('五笔 86'),
              subtitle: const Text('显示单字全码'),
              value: settings.showWubi,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showWubi: value),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('部首'),
              value: settings.showRadical,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showRadical: value),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('笔画数'),
              value: settings.showStrokeCount,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showStrokeCount: value),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('字形结构'),
              value: settings.showStructure,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showStructure: value),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Unicode 编码'),
              value: settings.showUnicode,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showUnicode: value),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('字形与笔顺'),
              value: settings.showStrokeOrder,
              onChanged: (value) => controller.setSettings(
                (current) => current.copyWith(showStrokeOrder: value),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Text('阅读与界面', style: TextStyle(color: muted)),
      const SizedBox(height: 10),
      Card(
        child: Column(children: [
          SwitchListTile(
              title: const Text('显示段号'),
              subtitle: const Text('开启翻译-译文时，为原文段落和译文显示1、2、3等段号'),
              value: settings.showParagraphNumbers,
              onChanged: (v) => controller
                  .setSettings((s) => s.copyWith(showParagraphNumbers: v))),
          SwitchListTile(
              title: const Text('显示注释角标'),
              subtitle: const Text('开启翻译-注释时, 在原文词目和注释处显示①②等对应角标'),
              value: settings.showAnnotationMarkers,
              onChanged: (v) => controller
                  .setSettings((s) => s.copyWith(showAnnotationMarkers: v))),
          RadioGroup<AppFontScale>(
            groupValue: settings.fontScale,
            onChanged: (value) {
              if (value != null) {
                controller.setSettings((s) => s.copyWith(fontScale: value));
              }
            },
            child: Column(children: [
              for (final scale in AppFontScale.values)
                RadioListTile<AppFontScale>(
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(
                      '字号 · ${scale.label} · ${(scale.factor * 100).round()}%'),
                  value: scale,
                ),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              Text('字号预览 · ${(settings.fontScale.factor * 100).round()}%',
                  style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 10),
              const Text(
                '汉字之美，在形、音、义。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              const Text('春风又绿江南岸',
                  style: TextStyle(fontSize: 15, height: 1.5)),
            ]),
          ),
        ]),
      ),
    ];
    if (kind == 'data') {
      return [
        Text('当前诗词库', style: TextStyle(color: muted)),
        const SizedBox(height: 8),
        Card(
            child: ListTile(
          leading: const Icon(Icons.check_circle_outline),
          title: Text(settings.fullPoetryLibrary ? '全部唐诗宋词' : '标准诗词库'),
        )),
        const SizedBox(height: 16),
        Text('可切换诗词库', style: TextStyle(color: muted)),
        const SizedBox(height: 8),
        Card(
            child: RadioGroup<bool>(
          groupValue: settings.fullPoetryLibrary,
          onChanged: (value) {
            if (value != null) {
              controller
                  .setSettings((s) => s.copyWith(fullPoetryLibrary: value));
            }
          },
          child: const Column(children: [
            RadioListTile<bool>(
              value: false,
              title: Text('标准诗词库'),
              subtitle: Text('唐诗 2 万、宋诗词 2 万，其他作品全部收录'),
            ),
            RadioListTile<bool>(
              value: true,
              title: Text('全部唐诗宋词'),
              subtitle: Text('收录仓库内全部唐诗、宋诗与宋词'),
            ),
          ]),
        )),
      ];
    }
    return [
      Text('每日内容偏好', style: TextStyle(color: muted)),
      const SizedBox(height: 10),
      Card(
          child: RadioGroup<DailyContentType>(
        groupValue: settings.dailyContentType,
        onChanged: (value) {
          if (value != null) {
            controller.setSettings((s) => s.copyWith(dailyContentType: value));
          }
        },
        child: Column(children: [
          for (final type in DailyContentType.values)
            RadioListTile<DailyContentType>(
                title: Text(type.label), value: type),
        ]),
      )),
      const SizedBox(height: 18),
      ...displayContent,
      const SizedBox(height: 16),
      _SidebarWidthSetting(
        value: settings.sidebarWidth,
        muted: muted,
        onCommitted: (value) => controller.setSettings(
          (current) => current.copyWith(sidebarWidth: value),
        ),
      ),
      const SizedBox(height: 16),
      Card(
          child: Column(children: [
        SwitchListTile(
          title: const Text('剪切板自动搜索'),
          subtitle: const Text(
            '启动或返回应用时读取剪切板并查询；仅识别 1—16 个连续汉字',
          ),
          value: settings.clipboardSearchEnabled,
          onChanged: (value) => controller.setSettings(
            (s) => s.copyWith(clipboardSearchEnabled: value),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
            title: const Text('全局点击查字'),
            subtitle: const Text('开启后可点击正文汉字快速查询；设置页默认加入白名单，在此页点击汉字不会触发查询'),
            value: settings.globalHanLookupEnabled,
            onChanged: (value) => controller
                .setSettings((s) => s.copyWith(globalHanLookupEnabled: value))),
        const Divider(height: 1),
        SwitchListTile(
            title: const Text('减少装饰'),
            subtitle: const Text('隐藏非必要的山水与竹叶装饰'),
            value: settings.reduceDecoration,
            onChanged: (value) => controller
                .setSettings((s) => s.copyWith(reduceDecoration: value))),
        const Divider(height: 1),
        SwitchListTile(
            title: const Text('保留查询历史'),
            value: settings.keepSearchHistory,
            onChanged: (value) => controller
                .setSettings((s) => s.copyWith(keepSearchHistory: value))),
      ])),
      const SizedBox(height: 16),
      Card(
          child: Column(children: [
        ListTile(
          title: const Text('清除收藏'),
          onTap: () => _clearFavorites(context, ref),
        ),
        if (settings.keepSearchHistory) ...[
          const Divider(height: 1),
          ListTile(
            title: const Text('清除查询历史'),
            onTap: () => _clearHistory(context, ref),
          ),
        ],
      ])),
      const SizedBox(height: 20),
      OutlinedButton(
          onPressed: () => _reset(context, ref), child: const Text('恢复默认设置')),
      const SizedBox(height: 24),
      Card(
        child: Column(children: [
          SwitchListTile(
            title: const Text('实验性功能'),
            subtitle: const Text('开启后可以启用实验性功能'),
            value: settings.experimentalFeaturesEnabled,
            onChanged: (value) => controller.setSettings(
              (s) => s.copyWith(experimentalFeaturesEnabled: value),
            ),
          ),
          if (settings.experimentalFeaturesEnabled) ...[
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('左手模式'),
              value: settings.leftHanded,
              onChanged: (value) => controller.setSettings(
                (s) => s.copyWith(leftHanded: value),
              ),
            ),
          ],
        ]),
      ),
    ];
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('恢复默认设置？'),
                content: const Text('收藏不会被删除。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('恢复'))
                ]));
    if (yes == true) {
      await ref.read(settingsControllerProvider.notifier).reset();
    }
  }

  Future<void> _clearFavorites(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('清除全部收藏？'),
                content: const Text('清除后无法撤销。'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('清除'))
                ]));
    if (yes == true) {
      await ref.read(favoritesControllerProvider.notifier).clear();
    }
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    await ref.read(searchHistoryControllerProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('查询历史已清空')));
    }
  }
}

class _SidebarWidthSetting extends StatefulWidget {
  const _SidebarWidthSetting({
    required this.value,
    required this.muted,
    required this.onCommitted,
  });

  final double value;
  final Color muted;
  final ValueChanged<double> onCommitted;

  @override
  State<_SidebarWidthSetting> createState() => _SidebarWidthSettingState();
}

class _SidebarWidthSettingState extends State<_SidebarWidthSetting> {
  late double _previewWidth = widget.value;

  @override
  void didUpdateWidget(covariant _SidebarWidthSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _previewWidth = widget.value;
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Expanded(child: Text('侧边栏宽度')),
              Text('${_previewWidth.round()} px'),
            ]),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('sidebar-width-preview'),
              height: 104,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: _previewWidth,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: .1),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [Text('A'), Text('B'), Text('C')],
                  ),
                ),
                const VerticalDivider(width: 1),
                const Expanded(
                  child: Center(
                    child: Text('内容区', textAlign: TextAlign.center),
                  ),
                ),
              ]),
            ),
            CommittedSlider(
              value: widget.value,
              min: 48,
              max: 120,
              divisions: 18,
              labelBuilder: (value) => '${value.round()} px',
              tickLabels: const ['48 px', '120 px'],
              onChanged: (value) => setState(() => _previewWidth = value),
              onCommitted: widget.onCommitted,
            ),
            Text('页面内可临时隐藏。',
                style: TextStyle(fontSize: 12, color: widget.muted)),
          ]),
        ),
      );
}

class _SkinSettingsPanel extends ConsumerStatefulWidget {
  const _SkinSettingsPanel();
  @override
  ConsumerState<_SkinSettingsPanel> createState() => _SkinSettingsPanelState();
}

class _SkinSettingsPanelState extends ConsumerState<_SkinSettingsPanel> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('UI 皮肤',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 10),
      for (final spec in AppSkinRegistry.available(settings.importedSkins))
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(
              _isSelected(settings, spec)
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
            ),
            title: Text(spec.sourceSkin?.name ?? spec.id.label),
            subtitle: _skinSubtitle(spec),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              _ColorDot(spec.background),
              _ColorDot(spec.primary),
              _ColorDot(spec.secondary),
            ]),
            onTap: () {
              ref.read(settingsControllerProvider.notifier).setSettings(
                    (value) => value.copyWith(
                      skin: spec.id,
                      importedSkin: spec.sourceSkin,
                    ),
                  );
            },
          ),
        ),
      Row(children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _importSkin,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('导入皮肤文件'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _showSkinTemplate,
          icon: const Icon(Icons.code_outlined, size: 18),
          label: const Text('格式示例'),
        ),
      ]),
      if (settings.importedSkin != null &&
          !BundledSkinLoader.names.contains(settings.importedSkin!.name))
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: _removeImportedSkin,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('移除已导入皮肤'),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        '支持 JSON、ZIP 和 .hanzi-skin 数据皮肤包，包体最大 20 MB、单项资源最大 12 MB；可替换背景、配色、圆角、字体和 PNG/JPEG/WebP/GIF 图标，缺失项自动回退。',
        style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ]);
  }

  Widget? _skinSubtitle(AppSkinSpec spec) {
    final description = switch (spec.sourceSkin?.name) {
      '松月夜读' => '深墨青夜间护眼皮肤，采用低亮度表面、暖灰文字与柔和玉绿选中态',
      '鎏金墨玉·锦纹' => '暖宣纸纤维叠加淡墨玉云纹与稀疏金箔。',
      _ => spec.sourceSkin?.description ?? spec.description,
    };
    // Skin metadata stays intact; hide only icon-related clauses in this list.
    final text = RegExp(r'[^，,；;。\n]+[，,；;。\n]?')
        .allMatches(description)
        .map((match) => match.group(0)!)
        .where((clause) => !clause.contains('图标'))
        .join()
        .trim()
        .replaceFirst(RegExp(r'[，,；;]+$'), '');
    return text.isEmpty ? null : Text(text);
  }

  bool _isSelected(AppSettings settings, AppSkinSpec spec) =>
      settings.skin == spec.id &&
      (spec.id != AppSkin.imported ||
          settings.importedSkin?.name == spec.sourceSkin?.name);

  Future<void> _importSkin() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json', 'zip', 'hanzi-skin'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final skin = SkinPackageLoader.parse(bytes, picked.name);
      await ref.read(settingsControllerProvider.notifier).setSettings(
        (value) {
          final skins = [
            for (final existing in value.importedSkins)
              if (existing.name != skin.name) existing,
            skin,
          ];
          return value.copyWith(
            skin: AppSkin.imported,
            importedSkin: skin,
            importedSkins: skins,
          );
        },
      );
      if (!mounted) return;
      final applied = AppSkinRegistry.of(AppSkin.imported, skin);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '已导入“${skin.name}”：${skin.assets.length} 项资源，'
          '${applied.iconOverrides.length + applied.iconAssets.length} 项图标覆盖',
        ),
      ));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('皮肤导入失败：$error')),
      );
    }
  }

  Future<void> _removeImportedSkin() async {
    await ref.read(settingsControllerProvider.notifier).setSettings(
      (value) {
        final activeName = value.importedSkin?.name;
        return value.copyWith(
          skin: AppSkin.parchment,
          clearImportedSkin: true,
          importedSkins: [
            for (final skin in value.importedSkins)
              if (skin.name != activeName) skin,
          ],
        );
      },
    );
  }

  Future<void> _showSkinTemplate() async {
    const example = '''{
  "name": "青瓷",
  "description": "自定义数据皮肤",
  "colors": {
    "background": "#F4F7F3",
    "surface": "#FFFFFF",
    "primary": "#315C4D",
    "secondary": "#9A6A45",
    "text": "#202723",
    "border": "#D3DDD7",
    "mutedText": "#64716A",
    "onPrimary": "#FFFFFF",
    "error": "#B5483A",
    "success": "#32735E"
  },
  "appearance": {
    "backgroundAsset": "background",
    "backgroundFit": "cover",
    "backgroundOpacity": 0.85,
    "surfaceOpacity": 0.94,
    "cardRadius": 16,
    "inputRadius": 14,
    "buttonRadius": 12,
    "cardElevation": 0
  },
  "assets": {
    "background": "assets/background.webp",
    "homeIcon": "icons/home.png"
  },
  "icons": {
    "nav.home": "asset:homeIcon",
    "profile.skin": "eco_outlined"
  }
}''';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('皮肤包格式示例'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
          child: const SingleChildScrollView(
            child: SelectableText(
              example,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        margin: const EdgeInsetsDirectional.only(start: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      );
}
