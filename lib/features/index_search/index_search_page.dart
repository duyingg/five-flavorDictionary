import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/app_routes.dart';
import '../../core/language/pinyin_utils.dart';
import '../../core/widgets/committed_slider.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';
import '../dictionary/stroke_order_view.dart';
import 'index_catalog.dart';

enum IndexSearchType { pinyin, radical, stroke, difficult, rhyme }

extension IndexSearchTypeText on IndexSearchType {
  String get title => switch (this) {
        IndexSearchType.pinyin => '拼音查询',
        IndexSearchType.radical => '部首查询',
        IndexSearchType.stroke => '笔画查询',
        IndexSearchType.difficult => '难检字索引',
        IndexSearchType.rhyme => '韵脚查询',
      };
}

void _jumpToLazySection<T>({
  required ScrollController controller,
  required List<T> sections,
  required Map<T, GlobalKey> keys,
  required T target,
}) {
  final targetIndex = sections.indexOf(target);
  if (targetIndex < 0) return;

  void seek(int attemptsLeft) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) return;
      final targetContext = keys[target]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
        return;
      }
      if (attemptsLeft <= 0) return;

      final position = controller.position;
      final mountedIndices = <int>[
        for (var index = 0; index < sections.length; index++)
          if (keys[sections[index]]?.currentContext != null) index,
      ];
      double destination;
      if (mountedIndices.isEmpty) {
        destination = position.maxScrollExtent *
            (sections.length <= 1 ? 0 : targetIndex / (sections.length - 1));
      } else if (targetIndex < mountedIndices.first) {
        destination = controller.offset - position.viewportDimension * .9;
      } else {
        destination = controller.offset + position.viewportDimension * .9;
      }
      controller.jumpTo(
        destination.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      seek(attemptsLeft - 1);
    });
  }

  seek(8);
}

class IndexSearchPage extends ConsumerStatefulWidget {
  const IndexSearchPage({required this.type, super.key});
  final IndexSearchType type;

  @override
  ConsumerState<IndexSearchPage> createState() => _IndexSearchPageState();
}

class _IndexSearchPageState extends ConsumerState<IndexSearchPage> {
  late final Future<List<ChineseEntry>> _entriesFuture;
  List<ChineseEntry>? _catalogSource;
  IndexCatalog? _catalog;
  ScriptDisplay? _catalogDisplay;
  int? _catalogMaxLevel;
  var _sidebarVisible = true;

  @override
  void initState() {
    super.initState();
    _entriesFuture = ref.read(dictionaryRepositoryProvider).all();
  }

  IndexCatalog _catalogFor(
    List<ChineseEntry> source,
    AppSettings settings,
  ) {
    if (identical(source, _catalogSource) &&
        settings.scriptDisplay == _catalogDisplay &&
        settings.maxCharacterLevel == _catalogMaxLevel) {
      return _catalog!;
    }
    _catalogSource = source;
    _catalogDisplay = settings.scriptDisplay;
    _catalogMaxLevel = settings.maxCharacterLevel;
    return _catalog = IndexCatalog(
      source,
      display: settings.scriptDisplay,
      maxLevel: settings.maxCharacterLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    final controller = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 96,
        leading: Row(children: [
          const BackButton(),
          HoverOnlyTooltipIconButton(
            message: _sidebarVisible ? '隐藏侧边栏' : '显示侧边栏',
            icon: Icon(_sidebarVisible
                ? Icons.keyboard_double_arrow_left
                : Icons.keyboard_double_arrow_right),
            onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
          ),
        ]),
        title: Text(widget.type.title),
      ),
      body: FutureBuilder<List<ChineseEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const EmptyState(
              title: '索引加载失败',
              message: '请检查本地汉字数据后重试',
            );
          }
          final catalog = _catalogFor(snapshot.data ?? const [], settings);
          return Column(
            children: [
              _IndexFilters(
                script: settings.scriptDisplay,
                maxLevel: settings.maxCharacterLevel,
                onScriptChanged: (value) => controller.setSettings(
                  (current) => current.copyWith(scriptDisplay: value),
                ),
                onLevelChanged: (value) => controller.setSettings(
                  (current) => current.copyWith(maxCharacterLevel: value),
                ),
              ),
              Expanded(
                child: ResponsiveContent(
                  maxWidth: 1100,
                  child: switch (widget.type) {
                    IndexSearchType.pinyin => _PronunciationIndex(
                        catalog: catalog,
                        byRhyme: false,
                        showSidebar: _sidebarVisible,
                        sidebarWidth: settings.sidebarWidth),
                    IndexSearchType.radical => _RadicalIndex(
                        catalog: catalog,
                        showSidebar: _sidebarVisible,
                        sidebarWidth: settings.sidebarWidth),
                    IndexSearchType.stroke => _StrokeIndex(
                        catalog: catalog,
                        showSidebar: _sidebarVisible,
                        sidebarWidth: settings.sidebarWidth),
                    IndexSearchType.difficult => _DifficultIndex(
                        catalog: catalog,
                        showSidebar: _sidebarVisible,
                        sidebarWidth: settings.sidebarWidth),
                    IndexSearchType.rhyme => _PronunciationIndex(
                        catalog: catalog,
                        byRhyme: true,
                        showSidebar: _sidebarVisible,
                        sidebarWidth: settings.sidebarWidth),
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IndexFilters extends StatelessWidget {
  const _IndexFilters({
    required this.script,
    required this.maxLevel,
    required this.onScriptChanged,
    required this.onLevelChanged,
  });
  final ScriptDisplay script;
  final int maxLevel;
  final ValueChanged<ScriptDisplay> onScriptChanged;
  final ValueChanged<int> onLevelChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<ScriptDisplay>(
                segments: const [
                  ButtonSegment(
                    value: ScriptDisplay.simplified,
                    label: Text('简'),
                  ),
                  ButtonSegment(
                    value: ScriptDisplay.traditional,
                    label: Text('繁'),
                  ),
                ],
                selected: {script},
                onSelectionChanged: (values) => onScriptChanged(values.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: WidgetStatePropertyAll(Size(44, 30)),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '最高 $maxLevel 级',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(
                    width: 142,
                    child: CommittedSlider(
                      value: maxLevel.toDouble(),
                      min: 1,
                      max: 3,
                      divisions: 2,
                      compact: true,
                      labelBuilder: (value) => '${value.round()} 级字',
                      onCommitted: (value) => onLevelChanged(value.round()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _PronunciationIndex extends StatefulWidget {
  const _PronunciationIndex(
      {required this.catalog,
      required this.byRhyme,
      required this.showSidebar,
      required this.sidebarWidth});
  final IndexCatalog catalog;
  final bool byRhyme;
  final bool showSidebar;
  final double sidebarWidth;

  @override
  State<_PronunciationIndex> createState() => _PronunciationIndexState();
}

class _PronunciationIndexState extends State<_PronunciationIndex> {
  final _scrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};
  String? _selectedSection;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PronunciationIndex oldWidget) {
    super.didUpdateWidget(oldWidget);
    restoreScrollProgress(
      _scrollController,
      scrollProgress(_scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.byRhyme
        ? widget.catalog.pronunciationsByFinal
        : widget.catalog.pronunciationsByInitial;
    final sections = groups.keys.toList();
    if (!sections.contains(_selectedSection)) {
      _selectedSection = sections.firstOrNull;
    }

    return Column(
      children: [
        _IndexHint(
          text: widget.byRhyme
              ? '左侧选择韵母，右侧显示不带声调的读音；选中后按声调查字。'
              : '左侧按 A–Z 排列，读音只按首个英文字母归部。',
        ),
        Expanded(
          child: Row(
            children: [
              if (widget.showSidebar) ...[
                _SideRail<String>(
                  values: sections,
                  selected: _selectedSection,
                  width: widget.sidebarWidth,
                  label: (value) => widget.byRhyme
                      ? PinyinUtils.displayFinal(value)
                      : value.toUpperCase(),
                  onSelected: _jumpTo,
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: Listener(
                    onPointerSignal: _boostPointerScroll,
                    child: ListView(
                      controller: _scrollController,
                      physics: const _FastScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                      children: [
                        for (final section in sections)
                          _ReadingSection(
                            key: _sectionKeys.putIfAbsent(
                                section, GlobalKey.new),
                            title: widget.byRhyme
                                ? '${PinyinUtils.displayFinal(section)} 韵'
                                : '${section.toUpperCase()} 部',
                            readings: groups[section]!,
                            onSelected: (reading) => _openReading(reading),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<String>> _pronunciationGroups(_PronunciationIndex value) =>
      value.byRhyme
          ? value.catalog.pronunciationsByFinal
          : value.catalog.pronunciationsByInitial;

  void _jumpTo(String section) {
    setState(() => _selectedSection = section);
    _jumpToLazySection(
      controller: _scrollController,
      sections: _pronunciationGroups(widget).keys.toList(),
      keys: _sectionKeys,
      target: section,
    );
  }

  void _boostPointerScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final position = _scrollController.position;
      unawaited(_scrollController.animateTo(
        (_scrollController.offset + event.scrollDelta.dy * .8)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
      ));
    }
  }

  void _openReading(String reading) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SyllableResultPage(
          syllable: reading,
          catalog: widget.catalog,
        ),
      ),
    );
  }
}

class _ReadingSection extends StatelessWidget {
  const _ReadingSection({
    required this.title,
    required this.readings,
    required this.onSelected,
    super.key,
  });
  final String title;
  final List<String> readings;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final reading in readings)
                  ActionChip(
                    label: Text(reading),
                    onPressed: () => onSelected(reading),
                  ),
              ],
            ),
          ],
        ),
      );
}

class _RadicalIndex extends StatefulWidget {
  const _RadicalIndex(
      {required this.catalog,
      required this.showSidebar,
      required this.sidebarWidth});
  final IndexCatalog catalog;
  final bool showSidebar;
  final double sidebarWidth;

  @override
  State<_RadicalIndex> createState() => _RadicalIndexState();
}

class _RadicalIndexState extends State<_RadicalIndex> {
  final _scrollController = ScrollController();
  final _sectionKeys = <int, GlobalKey>{};
  int? _selectedStroke;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RadicalIndex oldWidget) {
    super.didUpdateWidget(oldWidget);
    restoreScrollProgress(
      _scrollController,
      scrollProgress(_scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.catalog.radicalsByStroke;
    final strokes = groups.keys.toList();
    if (!strokes.contains(_selectedStroke)) {
      _selectedStroke = strokes.firstOrNull;
    }

    return Column(
      children: [
        const _IndexHint(text: '先按左侧笔画数选择部首，再选择剩余笔画查看对应汉字。'),
        Expanded(
          child: Row(
            children: [
              if (widget.showSidebar) ...[
                _SideRail<int>(
                  values: strokes,
                  selected: _selectedStroke,
                  width: widget.sidebarWidth,
                  label: (value) => '$value画',
                  onSelected: _jumpTo,
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: Listener(
                    onPointerSignal: _boostPointerScroll,
                    child: ListView(
                      controller: _scrollController,
                      physics: const _FastScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                      children: [
                        for (final stroke in strokes)
                          Padding(
                            key:
                                _sectionKeys.putIfAbsent(stroke, GlobalKey.new),
                            padding: const EdgeInsets.only(bottom: 26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$stroke 画部首',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final radical in groups[stroke]!)
                                      ActionChip(
                                        label: SizedBox.square(
                                          dimension: 28,
                                          child: widget.catalog
                                                      .strokeAssetForCharacter(
                                                          radical) ==
                                                  null
                                              ? Center(
                                                  child: Text(
                                                    radical,
                                                    style: const TextStyle(
                                                        fontSize: 23),
                                                  ),
                                                )
                                              : HanziGlyph(
                                                  character: radical,
                                                  assetPath: widget.catalog
                                                      .strokeAssetForCharacter(
                                                          radical)!,
                                                ),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => _RadicalResultPage(
                                              catalog: widget.catalog,
                                              radical: radical,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _jumpTo(int stroke) {
    setState(() => _selectedStroke = stroke);
    _jumpToLazySection(
      controller: _scrollController,
      sections: widget.catalog.radicalsByStroke.keys.toList(),
      keys: _sectionKeys,
      target: stroke,
    );
  }

  void _boostPointerScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final position = _scrollController.position;
      unawaited(_scrollController.animateTo(
        (_scrollController.offset + event.scrollDelta.dy * .8)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
      ));
    }
  }
}

class _RadicalResultPage extends StatelessWidget {
  const _RadicalResultPage({required this.catalog, required this.radical});
  final IndexCatalog catalog;
  final String radical;

  @override
  Widget build(BuildContext context) {
    final groups = catalog.entriesForRadical(radical);
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
      ),
      body: ResponsiveContent(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
          children: [
            Text(
              '$radical 部',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '部首 ${catalog.radicalStrokeCount(radical)} 画 · 按剩余笔画列出',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            for (final group in groups.entries) ...[
              Text(
                '剩余 ${group.key} 画 · ${group.value.length} 字',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              _CharacterWrap(entries: group.value),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _StrokeIndex extends StatefulWidget {
  const _StrokeIndex(
      {required this.catalog,
      required this.showSidebar,
      required this.sidebarWidth});
  final IndexCatalog catalog;
  final bool showSidebar;
  final double sidebarWidth;

  @override
  State<_StrokeIndex> createState() => _StrokeIndexState();
}

class _StrokeIndexState extends State<_StrokeIndex> {
  final _scrollController = ScrollController();
  int? selectedStroke;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StrokeIndex oldWidget) {
    super.didUpdateWidget(oldWidget);
    restoreScrollProgress(
      _scrollController,
      scrollProgress(_scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strokes = widget.catalog.strokeCounts;
    if (!strokes.contains(selectedStroke)) {
      selectedStroke = strokes.firstOrNull;
    }
    final entries = selectedStroke == null
        ? const <ChineseEntry>[]
        : widget.catalog.entriesForStrokeCount(selectedStroke!);
    final radicalGroups = <String, List<ChineseEntry>>{};
    for (final entry in entries) {
      radicalGroups.putIfAbsent(entry.radical, () => []).add(entry);
    }

    return Column(
      children: [
        const _IndexHint(text: '选择总笔画数，汉字按传统部首顺序排列。'),
        Expanded(
          child: Row(
            children: [
              if (widget.showSidebar) ...[
                _SideRail<int>(
                  values: strokes,
                  selected: selectedStroke,
                  width: widget.sidebarWidth,
                  label: (value) => '$value画',
                  onSelected: (value) => setState(() => selectedStroke = value),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                  children: [
                    Text(
                      '$selectedStroke 画 · ${entries.length} 字',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(height: 14),
                    for (final group in radicalGroups.entries) ...[
                      Row(
                        children: [
                          if (widget.catalog
                                  .strokeAssetForCharacter(group.key) !=
                              null)
                            SizedBox.square(
                              dimension: 24,
                              child: HanziGlyph(
                                character: group.key,
                                assetPath: widget.catalog
                                    .strokeAssetForCharacter(group.key)!,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            )
                          else
                            Text(group.key),
                          const SizedBox(width: 5),
                          Text(
                            '部',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _CharacterWrap(entries: group.value),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultIndex extends StatefulWidget {
  const _DifficultIndex(
      {required this.catalog,
      required this.showSidebar,
      required this.sidebarWidth});
  final IndexCatalog catalog;
  final bool showSidebar;
  final double sidebarWidth;

  @override
  State<_DifficultIndex> createState() => _DifficultIndexState();
}

class _DifficultIndexState extends State<_DifficultIndex> {
  final _scrollController = ScrollController();
  final _sectionKeys = <int, GlobalKey>{};
  int? selectedStroke;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DifficultIndex oldWidget) {
    super.didUpdateWidget(oldWidget);
    restoreScrollProgress(
      _scrollController,
      scrollProgress(_scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.catalog.difficultByStroke;
    final strokes = groups.keys.toList();
    if (!strokes.contains(selectedStroke)) {
      selectedStroke = strokes.firstOrNull;
    }
    return Column(
      children: [
        const _IndexHint(
          text: '复读音字单独置顶；其余收录无部首或使用非常规部首的汉字，再按总笔画数排列。',
        ),
        Expanded(
          child: Row(
            children: [
              if (widget.showSidebar) ...[
                _SideRail<int>(
                  values: strokes,
                  selected: selectedStroke,
                  width: widget.sidebarWidth,
                  label: (value) => value == 0 ? '复读音' : '$value画',
                  onSelected: _jumpTo,
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: Listener(
                    onPointerSignal: _boostPointerScroll,
                    child: ListView(
                      controller: _scrollController,
                      physics: const _FastScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                      children: [
                        for (final stroke in strokes)
                          Padding(
                            key:
                                _sectionKeys.putIfAbsent(stroke, GlobalKey.new),
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stroke == 0
                                      ? '复读音 · ${groups[stroke]!.length} 字'
                                      : '$stroke 画 · ${groups[stroke]!.length} 字',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary),
                                ),
                                const SizedBox(height: 12),
                                _CharacterWrap(entries: groups[stroke]!),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _jumpTo(int stroke) {
    setState(() => selectedStroke = stroke);
    _jumpToLazySection(
      controller: _scrollController,
      sections: widget.catalog.difficultByStroke.keys.toList(),
      keys: _sectionKeys,
      target: stroke,
    );
  }

  void _boostPointerScroll(PointerSignalEvent event) {
    if (event is PointerScrollEvent && _scrollController.hasClients) {
      final position = _scrollController.position;
      unawaited(_scrollController.animateTo(
        (_scrollController.offset + event.scrollDelta.dy * .8)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
      ));
    }
  }
}

class _FastScrollPhysics extends ClampingScrollPhysics {
  const _FastScrollPhysics({super.parent});

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 1.35;

  @override
  _FastScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _FastScrollPhysics(parent: buildParent(ancestor));
}

class _SyllableResultPage extends StatelessWidget {
  const _SyllableResultPage({required this.syllable, required this.catalog});
  final String syllable;
  final IndexCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final groups = catalog.entriesForSyllable(syllable);
    final readings = catalog.readingsForSyllable(syllable);
    final total =
        groups.values.fold<int>(0, (sum, values) => sum + values.length);
    const toneLabels = {1: '一声', 2: '二声', 3: '三声', 4: '四声', 5: '轻声'};
    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
      ),
      body: ResponsiveContent(
        maxWidth: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
          children: [
            Text(
              syllable,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text('$total 字 · 按声调排列',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 22),
            for (final group in groups.entries) ...[
              Text(
                '${toneLabels[group.key]}  ${readings[group.key]?.join(' / ') ?? ''}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              _CharacterWrap(entries: group.value),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _CharacterWrap extends StatelessWidget {
  const _CharacterWrap({required this.entries});
  final List<ChineseEntry> entries;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 9,
        runSpacing: 9,
        children: [
          for (final entry in entries)
            SizedBox(
              width: 58,
              height: 58,
              child: _CharacterTile(entry: entry),
            ),
        ],
      );
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.entry});
  final ChineseEntry entry;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(AppRoutes.character(entry.character)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: entry.strokeOrderAsset == null
                ? Center(
                    child: Text(
                      entry.character,
                      style: const TextStyle(fontSize: 29),
                    ),
                  )
                : HanziGlyph(
                    character: entry.character,
                    assetPath: entry.strokeOrderAsset!,
                  ),
          ),
        ),
      );
}

class _SideRail<T> extends StatelessWidget {
  const _SideRail({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.width,
  });
  final List<T> values;
  final T? selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width.clamp(48, 120),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: values.length,
        itemBuilder: (context, index) {
          final value = values[index];
          final isSelected = value == selected;
          return InkWell(
            onTap: () => onSelected(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withValues(alpha: .1)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? colors.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Text(
                label(value),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IndexHint extends StatelessWidget {
  const _IndexHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
        child: Text(
          text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13),
        ),
      );
}
