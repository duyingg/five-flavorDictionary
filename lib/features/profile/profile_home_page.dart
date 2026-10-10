import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/app_version.dart';
import '../../core/design/app_theme.dart';
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
    ('查询历史', Icons.history, AppRoutes.history, 'profile.history'),
    ('更改诗词库', Icons.storage_outlined, AppRoutes.settingsData, 'profile.data'),
    ('使用帮助', Icons.help_outline, AppRoutes.informationHelp, 'profile.help'),
    (
      '反馈与建议',
      Icons.mail_outline,
      AppRoutes.informationFeedback,
      'profile.feedback'
    ),
    ('关于我们', Icons.info_outline, AppRoutes.informationAbout, 'profile.about'),
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
                      if (items[index].$3 != AppRoutes.history ||
                          settings.keepSearchHistory)
                        ListTile(
                          leading: SkinIcon(
                            items[index].$4,
                            fallback:
                                spec.icon(items[index].$4, items[index].$2),
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          title: Text(items[index].$1),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(items[index].$3),
                        ),
                      if (index != items.length - 1 &&
                          (items[index].$3 != AppRoutes.history ||
                              settings.keepSearchHistory))
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
                '版本 $appVersion',
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
