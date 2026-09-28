import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/app_routes.dart';
import '../../core/widgets/common_widgets.dart';
import '../data/han_script_converter.dart';
import '../data/poetry_binary_codec.dart';
import '../domain/models.dart';
import 'festival_section.dart';
import 'ancient_titles_section.dart';
import 'school_books.dart';

class CulturePage extends ConsumerStatefulWidget {
  const CulturePage({super.key});
  @override
  ConsumerState<CulturePage> createState() => _CulturePageState();
}

class _CulturePageState extends ConsumerState<CulturePage> {
  var selected = CultureCategory.schools;
  var _sidebarVisible = true;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    return SafeArea(
      child: Column(children: [
        _CultureHeading(
          sidebarVisible: _sidebarVisible,
          onToggleSidebar: () =>
              setState(() => _sidebarVisible = !_sidebarVisible),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_sidebarVisible) ...[
                      SizedBox(
                        width: settings.sidebarWidth,
                        child: ListView(children: [
                          for (final category in CultureCategory.values)
                            _CategoryButton(
                              category: category,
                              selected: selected == category,
                              onTap: () => setState(() => selected = category),
                            ),
                        ]),
                      ),
                      const VerticalDivider(width: 1),
                    ],
                    Expanded(
                      child: selected == CultureCategory.tangPoems
                          ? const PoetryBrowser()
                          : _CultureGrid(category: selected),
                    ),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CultureHeading extends StatelessWidget {
  const _CultureHeading({
    required this.sidebarVisible,
    required this.onToggleSidebar,
  });
  final bool sidebarVisible;
  final VoidCallback onToggleSidebar;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final title = Text('文化',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ));
          final toggle = HoverOnlyTooltipIconButton(
            message: sidebarVisible ? '隐藏侧边栏' : '显示侧边栏',
            icon: Icon(sidebarVisible
                ? Icons.keyboard_double_arrow_left
                : Icons.keyboard_double_arrow_right),
            onPressed: onToggleSidebar,
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: constraints.maxWidth < 520
                ? Row(
                    children: [
                      toggle,
                      Expanded(child: Center(child: title)),
                      const _CultureModeSelector(),
                    ],
                  )
                : Stack(alignment: Alignment.center, children: [
                    title,
                    Align(alignment: Alignment.centerLeft, child: toggle),
                    const Align(
                        alignment: Alignment.centerRight,
                        child: _CultureModeSelector()),
                  ]),
          );
        },
      );
}

class _CultureModeSelector extends ConsumerWidget {
  const _CultureModeSelector();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = ref.watch(cultureDisplayModeProvider);
    return SegmentedButton<CultureDisplayMode>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 7, vertical: 4)),
        textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
      ),
      showSelectedIcon: false,
      segments: [
        for (final value in CultureDisplayMode.values)
          ButtonSegment(value: value, label: Text(value.label)),
      ],
      multiSelectionEnabled: true,
      selected: modes,
      emptySelectionAllowed: true,
      onSelectionChanged: (value) {
        ref.read(cultureDisplayModeProvider.notifier).state = value;
      },
    );
  }
}

class _CultureGrid extends ConsumerWidget {
  const _CultureGrid({required this.category});
  final CultureCategory category;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cultureItemsProvider(category));
    return items.when(
      data: (values) {
        final visible = category == CultureCategory.schools
            ? values.where((item) => item.id.startsWith('school-')).toList()
            : values;
        return visible.isEmpty
            ? const EmptyState(title: '暂无内容', message: '该分类暂未收录')
            : GridView.builder(
                key: PageStorageKey(category),
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.sizeOf(context).width >= 840 ? 2 : 1,
                  mainAxisExtent:
                      category == CultureCategory.schools ? 136 : 118,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 12,
                ),
                itemCount: visible.length,
                itemBuilder: (_, index) => _CultureCard(item: visible[index]),
              );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const EmptyState(title: '加载失败', message: '请检查本地文化资源'),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton(
      {required this.category, required this.selected, required this.onTap});
  final CultureCategory category;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: .09)
              : Colors.transparent,
          border: Border(
              left: BorderSide(
            color: selected ? colors.primary : Colors.transparent,
            width: 3,
          )),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(category.label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? colors.primary : colors.onSurface,
              )),
        ),
      ),
    );
  }
}

class _CultureCard extends StatelessWidget {
  const _CultureCard({required this.item});
  final CultureItem item;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.cultureDetail(item.id)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (item.category == CultureCategory.schools) ...[
                Container(
                  width: 66,
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(item.title.substring(0, 1),
                      style: TextStyle(
                          fontSize: 30,
                          color: Theme.of(context).colorScheme.primary)),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 5),
                    Text(item.summary,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ]),
          ),
        ),
      );
}

extension on PoetryOrder {
  String get label => switch (this) {
        PoetryOrder.ascending => '正序',
        PoetryOrder.descending => '倒序',
        PoetryOrder.random => '乱序',
      };
}

class _PoetryFilters {
  const _PoetryFilters(
      {this.author = '',
      this.dynasty = '',
      this.form = '',
      this.style = '',
      this.theme = '',
      this.emotion = ''});
  final String author;
  final String dynasty;
  final String form;
  final String style;
  final String theme;
  final String emotion;
  int get activeCount => [author, dynasty, form, style, theme, emotion]
      .where((e) => e.isNotEmpty)
      .length;
}

class PoetryBrowser extends ConsumerStatefulWidget {
  const PoetryBrowser({super.key});
  @override
  ConsumerState<PoetryBrowser> createState() => _PoetryBrowserState();
}

class _PoetryBrowserState extends ConsumerState<PoetryBrowser> {
  static const _pageSize = 100;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  PoetryCatalog? _catalog;
  PoetrySelection? _selection;
  HanScriptConverter? _scriptConverter;
  var _visibleCount = _pageSize;
  var _sort = PoetryOrder.random;
  var _filters = const _PoetryFilters();
  var _scriptDisplay = ScriptDisplay.simplified;
  var _query = '';
  var _queryRevision = 0;
  var _loadedFullLibrary = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreAtHalfway);
    _loadLibrary(
      ref.read(settingsControllerProvider).valueOrNull?.fullPoetryLibrary ??
          false,
    );
  }

  Future<void> _loadLibrary(bool fullLibrary) async {
    _loadedFullLibrary = fullLibrary;
    final values = await Future.wait<Object>([
      ref.read(poetryRepositoryProvider).catalog(fullLibrary: fullLibrary),
      ref.read(hanScriptConverterProvider.future),
    ]);
    if (!mounted || _loadedFullLibrary != fullLibrary) return;
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const AppSettings();
    _catalog = values[0] as PoetryCatalog;
    _scriptConverter = values[1] as HanScriptConverter;
    _scriptDisplay = settings.scriptDisplay;
    _query = _normalizedQuery(_searchController.text);
    _applyFilters();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_loadMoreAtHalfway)
      ..dispose();
    super.dispose();
  }

  void _loadMoreAtHalfway() {
    final resultCount = _selection?.length ?? 0;
    if (!_scrollController.hasClients || _visibleCount >= resultCount) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent > 0 &&
        position.pixels >= position.maxScrollExtent * .5) {
      setState(() =>
          _visibleCount = math.min(_visibleCount + _pageSize, resultCount));
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _query = _normalizedQuery(value);
      _applyFilters();
    });
  }

  String _normalizedQuery(String value) =>
      _scriptConverter
          ?.toSimplified(value)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '') ??
      '';

  Future<void> _applyFilters() async {
    final catalog = _catalog;
    final converter = _scriptConverter;
    if (!mounted || catalog == null || converter == null) {
      return;
    }
    final f = _filters;
    final revision = ++_queryRevision;
    final selection = await catalog.selectAsync(
      PoetryQuery(
        text: _query,
        author: converter.toSimplified(f.author),
        dynasty: f.dynasty,
        form: f.form,
        style: f.style,
        theme: f.theme,
        emotion: f.emotion,
        translatedOnly: _query.isEmpty,
        order: _sort,
      ),
      isCancelled: () => revision != _queryRevision || catalog != _catalog,
    );
    if (!mounted || selection == null) return;
    setState(() {
      _selection = selection;
      _visibleCount = math.min(_pageSize, selection.length);
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<_PoetryFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PoetryFilterSheet(initial: _filters),
    );
    if (result != null) {
      _filters = result;
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsControllerProvider, (_, next) {
      final settings = next.valueOrNull ?? const AppSettings();
      final fullLibrary = settings.fullPoetryLibrary;
      if (fullLibrary != _loadedFullLibrary) {
        setState(() {
          _catalog = null;
          _selection = null;
        });
        _loadLibrary(fullLibrary);
      } else if (settings.scriptDisplay != _scriptDisplay) {
        _scriptDisplay = settings.scriptDisplay;
        _query = _normalizedQuery(_searchController.text);
        _applyFilters();
      }
    });
    final converter = _scriptConverter;
    final selection = _selection;
    if (_catalog == null || selection == null || converter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final count = math.min(_visibleCount, selection.length);
    final showLibraryPrompt = !_loadedFullLibrary;
    final promptIsVisible = showLibraryPrompt && count == selection.length;
    final search = TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: const InputDecoration(
          isDense: true,
          prefixIcon: Icon(Icons.search),
          hintText: '搜索作者、标题或诗句'),
    );
    final filter = OutlinedButton.icon(
      onPressed: _showFilters,
      icon: const Icon(Icons.tune, size: 18),
      label:
          Text(_filters.activeCount == 0 ? '筛选' : '筛选 ${_filters.activeCount}'),
    );
    final sort = PopupMenuButton<PoetryOrder>(
      tooltip: '排序',
      onSelected: (value) {
        _sort = value;
        _applyFilters();
      },
      itemBuilder: (_) => [
        for (final value in PoetryOrder.values)
          PopupMenuItem(value: value, child: Text(value.label))
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.swap_vert, size: 19),
          const SizedBox(width: 3),
          Text(_sort.label),
        ]),
      ),
    );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 560) {
            return Column(children: [
              search,
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                filter,
                const SizedBox(width: 6),
                sort,
              ]),
            ]);
          }
          return Row(children: [
            Expanded(child: search),
            const SizedBox(width: 8),
            filter,
            const SizedBox(width: 6),
            sort,
          ]);
        }),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
              _query.isEmpty
                  ? '当前诗词库 ${_catalog!.length} 首'
                  : '当前库搜索结果 ${selection.length} 首',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ),
      Expanded(
        child: selection.length == 0 && !showLibraryPrompt
            ? const EmptyState(title: '没有找到诗词', message: '请减少筛选条件后再试')
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 5, 14, 20),
                itemCount: count + (promptIsVisible ? 1 : 0),
                itemExtent: 104,
                itemBuilder: (_, index) {
                  if (index == selection.length) {
                    return const _FullPoetryLibraryPromptCard();
                  }
                  return _PoetryCard(
                    item: selection.itemAt(index),
                    converter: converter,
                    display: _scriptDisplay,
                  );
                },
              ),
      ),
    ]);
  }
}

class _FullPoetryLibraryPromptCard extends StatelessWidget {
  const _FullPoetryLibraryPromptCard();

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.settingsData),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '没有找到目标诗?',
                      softWrap: true,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '试试导入全部诗词库',
                      softWrap: true,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ]),
          ),
        ),
      );
}

class _PoetryCard extends StatelessWidget {
  const _PoetryCard({
    required this.item,
    required this.converter,
    required this.display,
  });
  final PoetryItem item;
  final HanScriptConverter converter;
  final ScriptDisplay display;
  @override
  Widget build(BuildContext context) {
    final preview = converter
        .convert(readablePoetrySource(item.content), display)
        .replaceAll('\n', '　');
    final title = converter.convert(item.title, display);
    final author = converter.convert(item.author, display);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.poetryDetail(item.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium)),
                      Text(converter.convert(item.dynasty, display),
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 4),
                      if (item.author.trim().isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: TextButton(
                            onPressed: () => context.push(
                                AppRoutes.poetryAuthor(
                                    item.dynasty, item.author)),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(author,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 5),
                    Text(preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]),
            ),
            Icon(Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 10)),
      );
}

class _PoetryFilterSheet extends StatefulWidget {
  const _PoetryFilterSheet({required this.initial});
  final _PoetryFilters initial;
  @override
  State<_PoetryFilterSheet> createState() => _PoetryFilterSheetState();
}

class _PoetryFilterSheetState extends State<_PoetryFilterSheet> {
  late final TextEditingController author;
  late String dynasty;
  late String form;
  late String style;
  late String theme;
  late String emotion;

  @override
  void initState() {
    super.initState();
    author = TextEditingController(text: widget.initial.author);
    dynasty = widget.initial.dynasty;
    form = widget.initial.form;
    style = widget.initial.style;
    theme = widget.initial.theme;
    emotion = widget.initial.emotion;
  }

  @override
  void dispose() {
    author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('筛选诗词', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                  controller: author,
                  decoration: const InputDecoration(
                      labelText: '作者', hintText: '输入作者名')),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _FilterDropdown(
                    '朝代',
                    dynasty,
                    const ['先秦', '汉', '唐', '五代', '宋', '元', '清'],
                    (v) => setState(() => dynasty = v)),
                _FilterDropdown(
                    '文体',
                    form,
                    const [
                      '词',
                      '曲',
                      '楚辞',
                      '五言绝句',
                      '七言绝句',
                      '五言律诗',
                      '七言律诗',
                      '乐府',
                      '古体诗'
                    ],
                    (v) => setState(() => form = v)),
                _FilterDropdown(
                    '风格',
                    style,
                    const ['豪放', '婉约', '雄浑', '清新', '冲淡', '其他'],
                    (v) => setState(() => style = v)),
                _FilterDropdown(
                    '主题',
                    theme,
                    const [
                      '山水田园',
                      '边塞',
                      '咏物',
                      '送别',
                      '怀古',
                      '思乡',
                      '节令',
                      '爱情闺怨',
                      '其他'
                    ],
                    (v) => setState(() => theme = v)),
                _FilterDropdown(
                    '感情',
                    emotion,
                    const ['思乡', '惜别', '忧国', '悲愁', '豪情', '闲适', '其他'],
                    (v) => setState(() => emotion = v)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                TextButton(
                    onPressed: () =>
                        Navigator.pop(context, const _PoetryFilters()),
                    child: const Text('清空')),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(
                      context,
                      _PoetryFilters(
                        author: author.text.trim(),
                        dynasty: dynasty,
                        form: form,
                        style: style,
                        theme: theme,
                        emotion: emotion,
                      )),
                  child: const Text('应用筛选'),
                ),
              ]),
            ]),
          ),
        ),
      );
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown(this.label, this.value, this.values, this.onChanged);
  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 160,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: [
            const DropdownMenuItem(value: '', child: Text('全部')),
            for (final item in values)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: (value) => onChanged(value ?? ''),
        ),
      );
}

class CultureDetailPage extends ConsumerStatefulWidget {
  const CultureDetailPage({required this.id, super.key});
  final String id;

  @override
  ConsumerState<CultureDetailPage> createState() => _CultureDetailPageState();
}

class _CultureDetailPageState extends ConsumerState<CultureDetailPage> {
  late final Future<CultureItem?> _itemFuture;

  @override
  void initState() {
    super.initState();
    _itemFuture = ref.read(cultureRepositoryProvider).getById(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('文化详情'),
          actions: const [
            Padding(
                padding: EdgeInsets.only(right: 12),
                child: _CultureModeSelector())
          ],
        ),
        body: FutureBuilder<CultureItem?>(
          future: _itemFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final item = snapshot.data;
            if (item == null) {
              return const EmptyState(title: '内容不存在', message: '请返回文化页重新选择');
            }
            return _CultureDetailBody(item: item);
          },
        ),
      );
}

class _CultureDetailBody extends ConsumerStatefulWidget {
  const _CultureDetailBody({required this.item});
  final CultureItem item;

  @override
  ConsumerState<_CultureDetailBody> createState() => _CultureDetailBodyState();
}

class _CultureDetailBodyState extends ConsumerState<_CultureDetailBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cultureDisplayModeProvider, (_, __) {
      restoreScrollProgress(
        _scrollController,
        scrollProgress(_scrollController),
      );
    });
    final modes = ref.watch(cultureDisplayModeProvider);
    final item = widget.item;
    if (item.passages.isNotEmpty) {
      return ResponsiveContent(
        maxWidth: 800,
        child: _ParallelCulturePassageList(
          item: item,
          controller: _scrollController,
          showPinyin: modes.contains(CultureDisplayMode.reading),
          showTranslation: modes.contains(CultureDisplayMode.translation),
          showNotes: modes.contains(CultureDisplayMode.notes),
        ),
      );
    }
    return ResponsiveContent(
      maxWidth: 800,
      child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(item.subtitle,
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            const Divider(height: 36),
            if (item.content.trim().isEmpty)
              const SizedBox(
                  height: 300,
                  child: EmptyState(title: '暂未实装', message: '内容入口已预留，后续补充原文'))
            else if (item.id == 'other-surnames' && item.readingContent != null)
              _SurnameReading(
                  content: item.readingContent!,
                  showPinyin: modes.contains(CultureDisplayMode.reading))
            else if (item.id == 'other-festival')
              FestivalSection(content: item.content)
            else if (item.id == 'other-solar')
              _SolarTerms(content: item.content)
            else if (item.id == 'other-title')
              const AncientTitlesSection()
            else if (modes.contains(CultureDisplayMode.reading))
              _PinyinText(text: item.content)
            else
              Text(item.content,
                  style: const TextStyle(height: 1.9, fontSize: 17)),
            if (item.id.startsWith('school-'))
              _SchoolBooksSection(schoolId: item.id),
            if (modes.contains(CultureDisplayMode.notes) &&
                item.notes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PoetrySupplement(
                title: '注释',
                content: item.notes,
                missing: '',
              ),
            ],
            if (modes.contains(CultureDisplayMode.translation) &&
                item.passages.isEmpty &&
                item.translation.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PoetrySupplement(
                title: '翻译',
                content: item.translation,
                missing: '',
              ),
            ],
            if (item.appreciation.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PoetrySupplement(
                title: '赏析',
                content: item.appreciation,
                missing: '',
              ),
            ],
            const SizedBox(height: 30),
            if (item.id != 'other-festival')
              Text('数据来源：${item.sourceId}',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12)),
          ]),
    );
  }
}

class _SchoolBooksSection extends ConsumerWidget {
  const _SchoolBooksSection({required this.schoolId});

  final String schoolId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = schoolBookIds[schoolId];
    if (ids == null || ids.isEmpty) return const SizedBox.shrink();
    return ref.watch(cultureItemsProvider(CultureCategory.classics)).when(
          data: (items) {
            final byId = {for (final item in items) item.id: item};
            final books = [
              for (final id in ids)
                if (byId[id] != null) byId[id]!
            ];
            if (books.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Text('相关典籍', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final book in books)
                  Card(
                    child: ListTile(
                      title: Text('《${book.title}》'),
                      subtitle: Text(book.subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push(AppRoutes.cultureDetail(book.id)),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}

class _ParallelCulturePassageList extends StatelessWidget {
  const _ParallelCulturePassageList({
    required this.item,
    required this.controller,
    required this.showPinyin,
    required this.showTranslation,
    required this.showNotes,
  });

  final CultureItem item;
  final ScrollController controller;
  final bool showPinyin;
  final bool showTranslation;
  final bool showNotes;

  @override
  Widget build(BuildContext context) => ListView.builder(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
        itemCount: item.passages.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
                const Divider(height: 36),
              ],
            );
          }
          if (index == item.passages.length + 1) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showNotes && item.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PoetrySupplement(
                    title: '注释',
                    content: item.notes,
                    missing: '',
                  ),
                ],
                if (item.appreciation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PoetrySupplement(
                    title: '赏析',
                    content: item.appreciation,
                    missing: '',
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  '数据来源：${item.sourceId}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          }
          return _ParallelCulturePassage(
            passage: item.passages[index - 1],
            showPinyin: showPinyin,
            showTranslation: showTranslation,
          );
        },
      );
}

class _ParallelCulturePassage extends StatelessWidget {
  const _ParallelCulturePassage({
    required this.passage,
    required this.showPinyin,
    required this.showTranslation,
  });

  final CulturePassage passage;
  final bool showPinyin;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: passage.heading.isEmpty ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (passage.heading.isNotEmpty) ...[
            Text(
              passage.heading,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
          ],
          if (showPinyin)
            _PinyinText(text: passage.original)
          else
            Text(
              passage.original,
              style: const TextStyle(height: 1.9, fontSize: 17),
            ),
          if (showTranslation && passage.translation.isNotEmpty) ...[
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.secondaryContainer.withValues(alpha: .42),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: colors.secondary, width: 3),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                child: Text(
                  passage.translation,
                  style: TextStyle(
                    height: 1.75,
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SolarTerms extends StatelessWidget {
  const _SolarTerms({required this.content});
  final String content;
  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final rows = lines
        .where((line) => line.contains('|'))
        .map((e) => e.split('|'))
        .toList();
    final songStart = lines.indexWhere((e) => e.trim() == '节气歌');
    final song =
        songStart < 0 ? '' : lines.skip(songStart + 1).join('\n').trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: constraints.maxWidth >= 600 ? 2.25 : 1.15,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
          ),
          itemBuilder: (context, index) {
            final row = rows[index];
            return OutlinedButton(
              key: ValueKey('solar-term-${row.first}'),
              onPressed: () => context.push(AppRoutes.solarTerm(row.first)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(row.first,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(row.last,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ]),
            );
          },
        );
      }),
      if (song.isNotEmpty) ...[
        const Divider(height: 36),
        Text('节气歌', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(song, style: const TextStyle(fontSize: 18, height: 2)),
      ],
    ]);
  }
}

class SolarTermDetailPage extends StatelessWidget {
  const SolarTermDetailPage({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final info = _solarTermInfo[name];
    return Scaffold(
      appBar: AppBar(
        title: Text(info == null ? '节气详情' : name),
        actions: [
          IconButton(
            tooltip: '返回首页',
            onPressed: () => context.go(AppRoutes.home),
            icon: const Icon(Icons.home_outlined),
          ),
        ],
      ),
      body: info == null
          ? const EmptyState(title: '未找到该节气', message: '请返回二十四节气页面重新选择')
          : ResponsiveContent(
              maxWidth: 720,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 8),
                  Text(info.period,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 22),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('代表含义',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(info.meaning,
                              style: const TextStyle(height: 1.7)),
                          const Divider(height: 34),
                          Text('节气作用',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(info.function,
                              style: const TextStyle(height: 1.7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

typedef _SolarTermInfo = ({
  String period,
  String meaning,
  String function,
});

const _solarTermInfo = <String, _SolarTermInfo>{
  '立春': (
    period: '2月3–5日',
    meaning: '春季开始，阳气渐升，万物由冬藏转向生发。',
    function: '提示安排春耕准备，并留意乍暖还寒的天气变化。'
  ),
  '雨水': (
    period: '2月18–20日',
    meaning: '降水逐渐增多，冰雪开始融化。',
    function: '提示关注土壤墒情、春灌与防湿防寒。'
  ),
  '惊蛰': (
    period: '3月5–7日',
    meaning: '春雷渐起，蛰伏生物开始活动。',
    function: '标志春耕加快，并进入病虫害早期防治阶段。'
  ),
  '春分': (
    period: '3月20–22日',
    meaning: '昼夜大致等长，春季过半。',
    function: '提示作物进入旺盛生长期，需加强水肥管理。'
  ),
  '清明': (
    period: '4月4–6日',
    meaning: '天气清朗、草木繁茂，也是慎终追远的重要时节。',
    function: '适宜春播、植树和踏青，同时承载祭扫纪念功能。'
  ),
  '谷雨': (
    period: '4月19–21日',
    meaning: '春雨滋养谷物，春季接近尾声。',
    function: '提示抓住降水条件播种移栽，并防范倒春寒。'
  ),
  '立夏': (
    period: '5月5–7日',
    meaning: '夏季开始，气温明显升高。',
    function: '提示进入作物快速生长和田间管理的重要阶段。'
  ),
  '小满': (
    period: '5月20–22日',
    meaning: '夏熟作物籽粒渐满，但尚未完全成熟。',
    function: '提示防旱防涝并关注籽粒灌浆。'
  ),
  '芒种': (
    period: '6月5–7日',
    meaning: '有芒作物成熟，夏播进入繁忙期。',
    function: '代表抢收抢种的农事节点，讲求适时完成夏收夏种。'
  ),
  '夏至': (
    period: '6月21–22日',
    meaning: '北半球白昼接近全年最长，盛夏将至。',
    function: '提示防暑、防强对流，并加强作物水分管理。'
  ),
  '小暑': (
    period: '7月6–8日',
    meaning: '暑热开始增强，但尚未达到最盛。',
    function: '提示防暑降温，并防范高温、雷雨对生产生活的影响。'
  ),
  '大暑': (
    period: '7月22–24日',
    meaning: '一年中最炎热的时段之一，高温湿热突出。',
    function: '提示重点防暑、防涝、防台风并保障作物灌溉。'
  ),
  '立秋': (
    period: '8月7–9日',
    meaning: '秋季开始，暑热尚未立即消退。',
    function: '提示作物由生长转向成熟，并关注伏旱与早晚温差。'
  ),
  '处暑': (
    period: '8月22–24日',
    meaning: '暑气逐渐结束，天气由热转凉。',
    function: '提示做好秋收准备并防范阶段性高温和秋雨。'
  ),
  '白露': (
    period: '9月7–9日',
    meaning: '昼夜温差增大，清晨水汽易凝成露。',
    function: '提示及时添衣，并关注晚熟作物的成熟与防寒。'
  ),
  '秋分': (
    period: '9月22–24日',
    meaning: '昼夜再次大致等长，秋季过半。',
    function: '代表秋收、秋耕、秋种集中展开的时段。'
  ),
  '寒露': (
    period: '10月8–9日',
    meaning: '露水更冷，气温继续下降。',
    function: '提示防寒防霜，并推进晚稻等作物收获。'
  ),
  '霜降': (
    period: '10月23–24日',
    meaning: '秋季最后一个节气，部分地区开始出现霜冻。',
    function: '提示收储越冬作物并做好防霜冻措施。'
  ),
  '立冬': (
    period: '11月7–8日',
    meaning: '冬季开始，万物趋于收藏。',
    function: '提示农事转入收尾和越冬管理，生活上注意保暖。'
  ),
  '小雪': (
    period: '11月22–23日',
    meaning: '气温下降，部分地区开始出现初雪。',
    function: '提示防寒保墒，并做好设施农业的保温管理。'
  ),
  '大雪': (
    period: '12月6–8日',
    meaning: '降雪可能增多，寒冷程度进一步加深。',
    function: '提示防冻、防积雪灾害并保护越冬作物。'
  ),
  '冬至': (
    period: '12月21–23日',
    meaning: '北半球白昼接近全年最短，此后白昼渐长。',
    function: '既是重要时令节点，也提示进入严寒阶段并加强冬季养护。'
  ),
  '小寒': (
    period: '1月5–7日',
    meaning: '天气进入严寒期，但通常尚未冷到极点。',
    function: '提示防寒防冻，并检查人畜与设施越冬安全。'
  ),
  '大寒': (
    period: '1月20–21日',
    meaning: '一年中最寒冷的时段之一，二十四节气至此轮回将尽。',
    function: '提示完成冬季防护，并为新一轮春耕生产做准备。'
  ),
};

class _SurnameReading extends StatelessWidget {
  const _SurnameReading({required this.content, required this.showPinyin});
  final String content;
  final bool showPinyin;
  @override
  Widget build(BuildContext context) {
    final sentences = _parseSurnameSentences(content);
    return Column(children: [
      for (var start = 0; start < sentences.length; start += 2)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Expanded(
                child: _SurnameHalf(
                    entries: sentences[start], showPinyin: showPinyin)),
            Container(
                width: 1,
                height: showPinyin ? 46 : 30,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: Theme.of(context).dividerColor),
            Expanded(
                child: _SurnameHalf(
                    entries: start + 1 < sentences.length
                        ? sentences[start + 1]
                        : const [],
                    showPinyin: showPinyin)),
          ]),
        ),
    ]);
  }
}

List<List<(String, String)>> _parseSurnameSentences(String content) {
  const terminalText = '百家姓终';
  const terminal = [
    ('百', 'bǎi'),
    ('家', 'jiā'),
    ('姓', 'xìng'),
    ('终', 'zhōng'),
  ];
  final entries = <(String, String)>[];
  final pattern = RegExp(r'([^\s()]+)\(([^)]+)\)');
  for (final line in content.split('\n')) {
    final lineEntries = pattern
        .allMatches(line)
        .map((match) => (match.group(1)!, match.group(2)!))
        .toList();
    if (lineEntries.map((entry) => entry.$1).join() == terminalText) {
      continue;
    }
    entries.addAll(lineEntries);
  }

  final sentences = <List<(String, String)>>[];
  var sentence = <(String, String)>[];
  var characterCount = 0;
  for (final entry in entries) {
    final entryLength = entry.$1.runes.length;
    if (characterCount + entryLength > 4) {
      throw const FormatException('百家姓分句超过四字');
    }
    sentence.add(entry);
    characterCount += entryLength;
    if (characterCount == 4) {
      sentences.add(sentence);
      sentence = <(String, String)>[];
      characterCount = 0;
    }
  }
  if (sentence.isNotEmpty) {
    throw const FormatException('百家姓分句不足四字');
  }
  sentences.add(terminal);
  if (sentences.length.isOdd) {
    throw const FormatException('百家姓必须每行两句、共八字');
  }
  return sentences;
}

class _SurnameHalf extends StatelessWidget {
  const _SurnameHalf({required this.entries, required this.showPinyin});
  final List<(String, String)> entries;
  final bool showPinyin;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var index = 0; index < entries.length; index++)
          Expanded(
            flex: entries[index].$1.runes.length,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (showPinyin)
                SizedBox(
                  height: 15,
                  child: FittedBox(
                    child: Text(entries[index].$2,
                        style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                ),
              FittedBox(
                child: Text(entries[index].$1,
                    style: const TextStyle(fontSize: 21, letterSpacing: 0)),
              ),
            ]),
          ),
      ]);
}

class _PinyinText extends ConsumerWidget {
  const _PinyinText({required this.text});
  final String text;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(primaryPinyinProvider(text)).when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text(text),
            data: (pinyin) => Wrap(
              spacing: 1,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                for (final character in text.characters)
                  if (character == '\n')
                    const SizedBox(width: double.infinity, height: 4)
                  else if (pinyin[character]?.isNotEmpty ?? false)
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        pinyin[character]!,
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(character, style: const TextStyle(fontSize: 18)),
                    ])
                  else
                    Text(
                      character,
                      style: const TextStyle(fontSize: 18, height: 1.8),
                    ),
              ],
            ),
          );
}

class PoetryDetailPage extends ConsumerStatefulWidget {
  const PoetryDetailPage({required this.id, super.key});
  final String id;

  @override
  ConsumerState<PoetryDetailPage> createState() => _PoetryDetailPageState();
}

class _PoetryDetailPageState extends ConsumerState<PoetryDetailPage> {
  Future<PoetryItem?>? _itemFuture;
  bool? _loadedFullLibrary;

  @override
  Widget build(BuildContext context) {
    final fullLibrary =
        ref.watch(settingsControllerProvider).valueOrNull?.fullPoetryLibrary ??
            false;
    if (_itemFuture == null || _loadedFullLibrary != fullLibrary) {
      _loadedFullLibrary = fullLibrary;
      _itemFuture = ref.read(poetryRepositoryProvider).getById(
            widget.id,
            fullLibrary: fullLibrary,
          );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('诗词'),
        actions: const [
          Padding(
              padding: EdgeInsets.only(right: 12),
              child: _CultureModeSelector())
        ],
      ),
      body: FutureBuilder<PoetryItem?>(
        future: _itemFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = snapshot.data;
          if (item == null) {
            return const EmptyState(title: '作品不存在', message: '请返回诗词列表重新选择');
          }
          return _PoetryDetailBody(item: item);
        },
      ),
    );
  }
}

class _PoetryDetailBody extends ConsumerStatefulWidget {
  const _PoetryDetailBody({required this.item});
  final PoetryItem item;

  @override
  ConsumerState<_PoetryDetailBody> createState() => _PoetryDetailBodyState();
}

class _PoetryDetailBodyState extends ConsumerState<_PoetryDetailBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cultureDisplayModeProvider, (_, __) {
      restoreScrollProgress(
        _scrollController,
        scrollProgress(_scrollController),
      );
    });
    ref.listen(settingsControllerProvider, (previous, next) {
      if (previous?.valueOrNull?.scriptDisplay ==
          next.valueOrNull?.scriptDisplay) {
        return;
      }
      restoreScrollProgress(
        _scrollController,
        scrollProgress(_scrollController),
      );
    });
    final item = widget.item;
    final converter = ref.watch(hanScriptConverterProvider).valueOrNull;
    if (converter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final scriptDisplay =
        ref.watch(settingsControllerProvider).valueOrNull?.scriptDisplay ??
            ScriptDisplay.simplified;
    String display(String value) => converter.convert(value, scriptDisplay);
    final displayContent = display(readablePoetrySource(item.content));
    final modes = ref.watch(cultureDisplayModeProvider);
    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              display(item.title),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  Text(display(item.dynasty)),
                  if (item.author.trim().isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                          AppRoutes.poetryAuthor(item.dynasty, item.author)),
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: Text(display(item.author)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
                child: Wrap(spacing: 6, children: [
              _TinyTag(display(item.form)),
              _TinyTag(display(item.style)),
              _TinyTag(display(item.theme)),
              _TinyTag(display(item.emotion))
            ])),
            const Divider(height: 38),
            if (modes.contains(CultureDisplayMode.reading))
              _PinyinText(text: displayContent)
            else
              Text(displayContent,
                  style: const TextStyle(fontSize: 18, height: 2)),
            if (modes.contains(CultureDisplayMode.notes) &&
                item.notes.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PoetrySupplement(
                  title: '注释', content: display(item.notes), missing: ''),
            ],
            if (modes.contains(CultureDisplayMode.translation) &&
                item.translation.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PoetrySupplement(
                  title: '翻译', content: display(item.translation), missing: ''),
            ],
            if (item.appreciation.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PoetrySupplement(
                title: '赏析',
                content: display(item.appreciation),
                missing: '',
              ),
            ],
            const SizedBox(height: 30),
            Text('数据来源：${item.sourceId}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12)),
          ]),
    );
  }
}

String readablePoetrySource(String content) =>
    content.replaceAll(RegExp('□+'), '〔原文缺字〕');

class _PoetrySupplement extends StatelessWidget {
  const _PoetrySupplement({
    required this.title,
    required this.content,
    required this.missing,
  });
  final String title;
  final String content;
  final String missing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(content.isEmpty ? missing : content,
                style: TextStyle(
                  height: 1.7,
                  color: content.isEmpty
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                )),
          ]),
        ),
      );
}
