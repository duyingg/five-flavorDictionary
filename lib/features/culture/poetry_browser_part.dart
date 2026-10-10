part of 'culture_pages.dart';

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
          alignment: AlignmentDirectional.centerStart,
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
