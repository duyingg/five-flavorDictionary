import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_routes.dart';
import '../../core/app_version.dart';
import '../../core/privacy/privacy_policy.dart';
import '../../core/widgets/common_widgets.dart';

class InformationPage extends StatefulWidget {
  const InformationPage({required this.kind, super.key});
  final String kind;
  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  static const feedbackUrl = 'https://v.wjx.cn/vm/wk2BGhD.aspx#';
  static const feedbackGroup = '334843809';

  Future<void> _copyFeedbackUrl() async {
    await Clipboard.setData(const ClipboardData(text: feedbackUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('问卷链接已复制')),
      );
    }
  }

  Future<void> _copyFeedbackGroup() async {
    await Clipboard.setData(const ClipboardData(text: feedbackGroup));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('反馈交流群号已复制')),
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
              const Text('一款集汉字与词语查询、学习训练、诗词和传统文化阅读于一体的离线应用。',
                  textAlign: TextAlign.center, style: TextStyle(height: 1.7)),
              const SizedBox(height: 18),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(children: [
                    _AboutRow('主要功能', '汉字词语查询、学习训练、诗词与古籍阅读'),
                    Divider(),
                    _AboutRow('学习内容', '今日汉字、小学语文生字、多音字与造句'),
                    Divider(),
                    _AboutRow('使用方式', '核心功能离线可用，无需注册账号'),
                    Divider(),
                    _AboutRow('商业模式', '无广告、无内购、无会员'),
                    Divider(),
                    _AboutRow('当前版本', appVersion),
                  ]),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('隐私政策'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.informationPrivacy),
                ),
              ),
            ] else if (widget.kind == 'help') ...[
              const _HelpTile(
                  '如何查询汉字或词语？', '在首页搜索框输入一个或多个汉字。输入单字进入汉字详情，输入多字进入词语查询。'),
              const _HelpTile('如何按条件查字？', '使用首页的拼音、部首、笔画、难检字或韵脚入口。'),
              const _HelpTile(
                  '如何调整查询页内容？', '进入“我的 → 设置 → 汉字查询偏好”选择拼音、注音、五笔、笔画等需要显示的项目。'),
              const _HelpTile('简繁和字级为何会自动保持？',
                  '索引页顶部的简繁按钮与最高字级滑块属于全局偏好。修改后会应用到所有索引页和学习抽题，并在下次启动时恢复。'),
              const _HelpTile('查询历史在哪里？',
                  '首页会显示最近查询；“我的 → 查询历史”可查看最多 100 条记录，并可在页面顶部清空。设置中也可关闭记录。'),
              const _HelpTile(
                  '如何学习多音字？', '进入“学习 → 多音字学习”。闯关按词组判断指定读音，无尽模式会随机出题并逐步扩展题库。'),
              const _HelpTile(
                  '小学语文生字在哪里？', '进入“学习 → 小学语文生字”，可按一年级至六年级和上下册切换，并按汉字或拼音搜索。'),
              const _HelpTile(
                  '造句内容会保存吗？', '会。造句以便签形式保存在本机，记录创作时间，并支持进入批量管理后删除。'),
              const _HelpTile(
                  '如何阅读诗词？', '文化页选择“诗词”，可搜索作者、标题、正文并筛选。读音、注释和翻译有内容时即可开启。'),
              const _HelpTile(
                  '如何在文化内容中快捷查字？', '点击文化页和详情正文中的汉字即可打开单字详情；长按仍可选择和复制文字。'),
              const _HelpTile('如何切换或寻找皮肤？',
                  '进入“我的 → 皮肤设置”选择内置皮肤，或导入本地 JSON 皮肤；也可跳转 GitHub 搜索社区资源。第三方皮肤需先核对许可证。'),
              const _HelpTile(
                  '如何更改诗词库？', '进入“我的 → 更改诗词库”，查看当前诗词库并切换。全量库较大，首次加载会更久。'),
              const _HelpTile('每日内容怎么切换？',
                  '点击首页“每日内容”标题，或进入“我的 → 设置 → 每日内容偏好”，可选汉字、词语、成语或诗句。'),
              const _HelpTile('如何反馈问题？', '进入“我的 → 反馈与建议”，可填写反馈问卷或复制反馈交流群号。'),
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
              Icon(Icons.forum_outlined,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 14),
              Text('反馈与交流',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('反馈交流群'),
                  subtitle: const SelectableText(feedbackGroup),
                  trailing: const Icon(Icons.copy),
                  onTap: _copyFeedbackGroup,
                ),
              ),
              const SizedBox(height: 20),
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
            child: Align(
                alignment: AlignmentDirectional.centerStart, child: Text(body)))
      ]));
}
