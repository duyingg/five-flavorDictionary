import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/design/app_theme.dart';
import '../../core/design/bundled_skin_loader.dart';
import '../../core/design/skin_package_loader.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/widgets/committed_slider.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/skin_widgets.dart';
import '../domain/models.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  static const items = [
    (
      '设置',
      Icons.settings_outlined,
      AppRoutes.settingsGeneral,
      'profile.settings'
    ),
    ('皮肤设置', Icons.palette_outlined, AppRoutes.settingsSkin, 'profile.skin'),
    (
      '每日内容偏好',
      Icons.calendar_month_outlined,
      AppRoutes.settingsDaily,
      'profile.daily'
    ),
    ('查询历史', Icons.history, AppRoutes.history, 'profile.history'),
    ('数据管理', Icons.storage_outlined, AppRoutes.settingsData, 'profile.data'),
    ('关于我们', Icons.info_outline, AppRoutes.informationAbout, 'profile.about'),
    (
      '隐私政策',
      Icons.privacy_tip_outlined,
      AppRoutes.informationPrivacy,
      'profile.privacy'
    ),
    ('使用帮助', Icons.help_outline, AppRoutes.informationHelp, 'profile.help'),
    (
      '反馈与建议',
      Icons.mail_outline,
      AppRoutes.informationFeedback,
      'profile.feedback'
    ),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    final spec = AppSkinRegistry.of(settings.skin, settings.importedSkin);
    return SafeArea(
      child: ResponsiveContent(
        maxWidth: 760,
        child: Column(children: [
          const PageHeading('我的'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              children: [
                Card(
                  child: Column(children: [
                    for (var index = 0; index < items.length; index++) ...[
                      ListTile(
                        leading: SkinIcon(
                          items[index].$4,
                          fallback: spec.icon(items[index].$4, items[index].$2),
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        title: Text(items[index].$1),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(items[index].$3),
                      ),
                      if (index != items.length - 1)
                        const Divider(height: 1, indent: 56),
                    ],
                  ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Column(children: [
              Text(
                '本产品无内购、无会员',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                '版本 1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({required this.kind, super.key});
  final String kind;

  String get title => switch (kind) {
        'daily' => '每日内容偏好',
        'data' => '数据管理',
        'skin' => '皮肤设置',
        _ => '设置'
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Text('此偏好会应用到所有索引页和学习模块',
                style: TextStyle(fontSize: 12, color: muted)),
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
              title: const Text('笔顺'),
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
                  title: Text('字号 · ${scale.label}'),
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
              Text(
                '汉字之美，在形、音、义。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20 * settings.fontScale.factor,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text('春风又绿江南岸',
                  style: TextStyle(
                      fontSize: 15 * settings.fontScale.factor, height: 1.5)),
            ]),
          ),
        ]),
      ),
    ];
    if (kind == 'data') {
      return [
        Card(
            child: Column(children: [
          ListTile(
              title: const Text('清除收藏'),
              subtitle: const Text('不会影响其他设置'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _clearFavorites(context, ref)),
          const Divider(height: 1),
          ListTile(
              title: const Text('清除查询历史'),
              subtitle: const Text('最多保留最近 100 条'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _clearHistory(context, ref)),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.library_books_outlined),
            title: const Text('导入诗词数据'),
            subtitle: Text(settings.fullPoetryLibrary
                ? '当前：全部唐诗、宋诗词及其他作品'
                : '当前：唐诗 2 万、宋诗词 2 万及其他全部作品'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectPoetryLibrary(context, ref, settings),
          ),
        ])),
      ];
    }
    return [
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
        const Divider(height: 1),
        SwitchListTile(
            title: const Text('清空后自动聚焦'),
            value: settings.autofocusAfterClear,
            onChanged: (value) => controller
                .setSettings((s) => s.copyWith(autofocusAfterClear: value))),
      ])),
      const SizedBox(height: 20),
      OutlinedButton(
          onPressed: () => _reset(context, ref), child: const Text('恢复默认设置')),
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

  Future<void> _selectPoetryLibrary(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final selected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('选择诗词导入范围'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.library_books_outlined),
              title: Text('标准诗词库'),
              subtitle: Text('唐诗 2 万、宋诗词 2 万，其他作品全部导入'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.all_inbox_outlined),
              title: Text('全部唐诗宋词'),
              subtitle: Text('导入仓库内全部唐诗、宋诗与宋词；首次打开需要更多时间'),
            ),
          ),
        ],
      ),
    );
    if (selected == null || selected == settings.fullPoetryLibrary) return;
    await ref.read(settingsControllerProvider.notifier).setSettings(
          (value) => value.copyWith(fullPoetryLibrary: selected),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(selected ? '已切换为全部唐诗宋词' : '已切换为标准诗词库'),
        ),
      );
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
            Text('应用于拼音、部首、笔画、难检字、韵脚和文化页面；页面内可临时隐藏。',
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
            subtitle: Text(
              '${spec.description}\n${spec.iconOverrides.isEmpty && spec.iconAssets.isEmpty ? '沿用默认图标' : '检测到 ${spec.iconOverrides.length + spec.iconAssets.length} 项图标覆盖'}',
            ),
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
          alignment: Alignment.centerRight,
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
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
      );
}

class SearchHistoryPage extends ConsumerWidget {
  const SearchHistoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('查询历史')),
        body: ref.watch(searchHistoryControllerProvider).when(
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
                          subtitle: Text('第 ${index + 1} 条 · 最近优先'),
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
              error: (_, __) =>
                  const EmptyState(title: '读取失败', message: '无法读取查询历史'),
            ),
      );
}

class InformationPage extends StatefulWidget {
  const InformationPage({required this.kind, super.key});
  final String kind;
  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  static const feedbackUrl = 'https://v.wjx.cn/vm/wk2BGhD.aspx#';

  Future<void> _copyFeedbackUrl() async {
    await Clipboard.setData(const ClipboardData(text: feedbackUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('问卷链接已复制')),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await launchUrl(
      Uri.parse(PrivacyPolicy.url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      await Clipboard.setData(const ClipboardData(text: PrivacyPolicy.url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开浏览器，隐私政策链接已复制')),
        );
      }
    }
  }

  Future<void> _copyPrivacyUrl() async {
    await Clipboard.setData(const ClipboardData(text: PrivacyPolicy.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('隐私政策链接已复制')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      'help' => '使用帮助',
      'feedback' => '反馈与建议',
      'privacy' => '隐私政策',
      _ => '关于我们'
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ResponsiveContent(
          maxWidth: 700,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            if (widget.kind == 'about') ...[
              Icon(Icons.menu_book,
                  size: 68, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text('五味字典',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              const Text('一款专注于汉字查询、学习与传统文化阅读的离线应用。无账号、无广告、无内购、无会员。',
                  textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
              const SizedBox(height: 18),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(children: [
                    _AboutRow('产品定位', '汉字工具、学习训练与传统文化阅读'),
                    Divider(),
                    _AboutRow('当前规模', '21,056 个汉字；默认 51,394 首完整诗词'),
                    Divider(),
                    _AboutRow('隐私', '查询、收藏、历史与偏好仅保存在本机'),
                    Divider(),
                    _AboutRow('商业模式', '无广告、无内购、无会员'),
                    Divider(),
                    _AboutRow('版本', '1.0.0'),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '字典释义来自 chinese-dictionary，笔顺图形来自 Make Me a Hanzi，诗词来自 chinese-poetry。各资源遵循其原始许可证，完整许可文件随项目保留。应用采用 Flutter 构建，可运行于 Web、Android 与 iOS。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ] else if (widget.kind == 'help') ...[
              const _HelpTile('如何查询汉字？', '在首页搜索框输入且仅输入一个汉字，然后点击搜索。'),
              const _HelpTile('如何按条件查字？', '使用首页的拼音、部首、笔画、难检字或韵脚入口。'),
              const _HelpTile('简繁和字级为何会自动保持？',
                  '索引页顶部的简繁按钮与最高字级滑块属于全局偏好。修改后会应用到所有索引页和学习抽题，并在下次启动时恢复。'),
              const _HelpTile('查询历史在哪里？',
                  '首页会显示最近查询；“我的 → 查询历史”可查看最多 100 条记录。“数据管理”可清空，设置中也可关闭记录。'),
              const _HelpTile(
                  '如何学习多音字？', '进入“学习 → 多音字学习”。闯关按词组判断指定读音，无尽模式会随机出题并逐步扩展题库。'),
              const _HelpTile('如何阅读诗词？',
                  '文化页选择“诗词”，可搜索作者、标题、正文并筛选。读音、注释和翻译按钮只展示源数据真实提供的内容。'),
              const _HelpTile('如何切换或寻找皮肤？',
                  '进入“我的 → 皮肤设置”选择内置皮肤，或导入本地 JSON 皮肤；也可跳转 GitHub 搜索社区资源。第三方皮肤需先核对许可证。'),
              const _HelpTile('如何导入全部唐诗宋词？',
                  '进入“我的 → 数据管理 → 导入诗词数据”，选择全部唐诗宋词。全量库较大，首次加载会更久。'),
              const _HelpTile('每日内容怎么切换？', '进入“我的 → 每日内容偏好”，可选文字、词语、成语或诗句。'),
            ] else if (widget.kind == 'privacy') ...[
              Icon(Icons.privacy_tip_outlined,
                  size: 68, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              Text('五味字典隐私政策',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              const Text(
                '核心功能可离线使用，无需注册账号，不含广告或统计分析 SDK。搜索历史、收藏、设置及您主动导入的内容默认只保存在本机。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.7),
              ),
              const SizedBox(height: 20),
              Card(
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.open_in_browser),
                    title: const Text('查看完整隐私政策'),
                    subtitle: const Text('将在系统浏览器中打开'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _openPrivacyPolicy,
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.copy),
                    title: const SelectableText(PrivacyPolicy.url),
                    subtitle: const Text('点击复制链接'),
                    onTap: _copyPrivacyUrl,
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              const Text(
                '政策版本：2026年9月17日',
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Text(
                '扫描二维码填写《五味字典》使用反馈问卷，或复制下方链接在浏览器中打开。',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
              const SizedBox(height: 20),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        'assets/images/feedback_qr.png',
                        semanticLabel: '五味字典使用反馈问卷二维码',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.link),
                  title: const SelectableText(feedbackUrl),
                  subtitle: const Text('点击复制问卷链接'),
                  trailing: const Icon(Icons.copy),
                  onTap: _copyFeedbackUrl,
                ),
              ),
            ],
          ])),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]);
}

class _HelpTile extends StatelessWidget {
  const _HelpTile(this.title, this.body);
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(title: Text(title), children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Align(alignment: Alignment.centerLeft, child: Text(body)))
      ]));
}
