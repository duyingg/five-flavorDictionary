import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../data/han_script_converter.dart';
import '../data/poetry_binary_codec.dart';
import '../domain/models.dart';
import 'poetry_author_profiles.dart';

class PoetryAuthorPage extends ConsumerStatefulWidget {
  const PoetryAuthorPage({
    required this.author,
    required this.dynasty,
    super.key,
  });

  final String author;
  final String dynasty;

  @override
  ConsumerState<PoetryAuthorPage> createState() => _PoetryAuthorPageState();
}

class _PoetryAuthorPageState extends ConsumerState<PoetryAuthorPage> {
  Future<_AuthorWorks>? _worksFuture;
  bool? _loadedFullLibrary;
  var _visibleCount = 20;

  Future<_AuthorWorks> _load(bool fullLibrary) async {
    final results = await Future.wait<Object>([
      ref.read(poetryRepositoryProvider).catalog(fullLibrary: fullLibrary),
      ref.read(hanScriptConverterProvider.future),
    ]);
    final catalog = results[0] as PoetryCatalog;
    final converter = results[1] as HanScriptConverter;
    final author = converter.toSimplified(widget.author);
    final dynasty = converter.toSimplified(widget.dynasty);
    final candidates = await catalog.selectAsync(PoetryQuery(
      author: author,
      order: PoetryOrder.ascending,
    ));
    final works = <PoetryItem>[];
    if (candidates != null) {
      for (var index = 0; index < candidates.length; index++) {
        final item = candidates.itemAt(index);
        if (converter.toSimplified(item.author) == author &&
            converter.toSimplified(item.dynasty) == dynasty) {
          works.add(item);
        }
      }
    }
    return _AuthorWorks(converter: converter, items: works);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    if (_worksFuture == null ||
        _loadedFullLibrary != settings.fullPoetryLibrary) {
      _loadedFullLibrary = settings.fullPoetryLibrary;
      _visibleCount = 20;
      _worksFuture = _load(settings.fullPoetryLibrary);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('作者介绍')),
      body: FutureBuilder<_AuthorWorks>(
        future: _worksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const EmptyState(title: '作者资料加载失败', message: '请稍后重试');
          }
          return _body(context, snapshot.data!, settings.scriptDisplay);
        },
      ),
    );
  }

  Widget _body(
      BuildContext context, _AuthorWorks data, ScriptDisplay scriptDisplay) {
    String display(String value) =>
        data.converter.convert(value, scriptDisplay);
    final profile =
        poetryAuthorProfiles[data.converter.toSimplified(widget.author)];
    final isAnonymous = {'佚名', '无名氏', '不详'}
        .contains(data.converter.toSimplified(widget.author));
    final visible = data.items.take(_visibleCount).toList(growable: false);
    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(display(widget.author),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(display(widget.dynasty),
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const Divider(height: 30),
          Text('人物简介', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (profile != null) ...[
            Text(display(profile.life),
                style: const TextStyle(fontSize: 16, height: 1.8)),
            const SizedBox(height: 14),
            Text('创作与作品', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(display(profile.writing),
                style: const TextStyle(fontSize: 16, height: 1.8)),
          ] else
            Text(
              isAnonymous
                  ? '“佚名”表示作品未能确定个人作者。同一署名下可能有不同时期、不同来源的作品，不能视为一人的生平与创作。'
                  : '本应用暂未收录经过核实的生平简介。下方列出本地诗词库中署名和朝代相符的作品。',
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
          const Divider(height: 40),
          Text('本库作品 · ${data.items.length} 首',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('仅统计当前诗词库中朝代与作者署名相符的条目。',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (data.items.isEmpty)
            const Text('当前诗词库暂无匹配作品。')
          else ...[
            for (final item in visible)
              Card(
                child: ListTile(
                  title: Text(display(item.title)),
                  subtitle: Text(display(item.form)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.poetryDetail(item.id)),
                ),
              ),
            if (visible.length < data.items.length)
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: () => setState(() => _visibleCount += 20),
                  child:
                      Text('继续查看（还剩 ${data.items.length - visible.length} 首）'),
                ),
              ),
          ],
          const SizedBox(height: 24),
          Text('人物简介由本应用编写；作品列表来自本地诗词库。',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AuthorWorks {
  const _AuthorWorks({required this.converter, required this.items});

  final HanScriptConverter converter;
  final List<PoetryItem> items;
}
