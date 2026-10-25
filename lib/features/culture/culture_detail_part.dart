part of 'culture_pages.dart';

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
                padding: EdgeInsetsDirectional.only(end: 12),
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

class _CultureDetailBody extends ConsumerWidget {
  const _CultureDetailBody({required this.item});
  final CultureItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = ref.watch(cultureDisplayModeProvider);
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    if (item.passages.isNotEmpty) {
      return ResponsiveContent(
          maxWidth: 800,
          child: _ParallelCulturePassageList(
              item: item,
              showPinyin: modes.contains(CultureDisplayMode.reading),
              showTranslation: modes.contains(CultureDisplayMode.translation)));
    }
    final converter = ref.watch(hanScriptConverterProvider).valueOrNull;
    if (converter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    String display(String text) =>
        converter.convert(text, settings.scriptDisplay);
    final special = {
      'other-surnames',
      'other-festival',
      'other-solar',
      'other-title'
    }.contains(item.id);
    final paragraphs = special
        ? [item.content]
        : item.content
            .split(RegExp(r'\n\s*\n'))
            .where((p) => p.trim().isNotEmpty)
            .toList();
    return ResponsiveContent(
        maxWidth: 800,
        child: _ArticleReader(
          key: ValueKey(item.id),
          indentParagraphs: item.category != CultureCategory.other,
          sourceCount: paragraphs.isEmpty ? 1 : paragraphs.length,
          sourceTextFor: (index) =>
              paragraphs.isEmpty ? '' : display(paragraphs[index]),
          revision: Object.hash(settings.scriptDisplay, settings.fontScale,
              modes.contains(CultureDisplayMode.reading)),
          open: modes.contains(CultureDisplayMode.translation),
          onClose: () => _closeArticleTranslation(ref),
          showParagraphNumbers: settings.showParagraphNumbers,
          showAnnotationMarkers: settings.showAnnotationMarkers,
          notes: display(item.notes),
          translation: display(item.translation),
          appreciation: display(item.appreciation),
          header:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(display(item.title),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(display(item.subtitle),
                style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            const Divider(height: 24),
          ]),
          sourceBuilder: (context, index) =>
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (item.content.trim().isEmpty)
              const SizedBox(
                  height: 180,
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
            else
              _ArticleOriginalText(
                  text: display(paragraphs[index]),
                  showPinyin: modes.contains(CultureDisplayMode.reading),
                  style: const TextStyle(height: 1.9, fontSize: 17)),
            if (item.id.startsWith('school-') &&
                index == math.max(0, paragraphs.length - 1))
              _SchoolBooksSection(schoolId: item.id),
          ]),
        ));
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

List<CulturePassage> _displayPassages(CultureItem item) {
  if (item.id != 'classic-qianziwen' && item.id != 'classic-sanzijing') {
    return item.passages;
  }
  final result = <CulturePassage>[];
  final pending = <CulturePassage>[];
  for (final passage in item.passages) {
    if (passage.heading.isNotEmpty && pending.isNotEmpty) {
      result.addAll(pending);
      pending.clear();
    }
    pending.add(passage);
    if (passage.translation.isNotEmpty) {
      result.add(CulturePassage(
        heading: pending.first.heading,
        original: pending.map((part) => part.original).join('\n'),
        translation: passage.translation,
      ));
      pending.clear();
    }
  }
  result.addAll(pending);
  return result;
}

class _ParallelCulturePassageList extends ConsumerStatefulWidget {
  const _ParallelCulturePassageList({
    required this.item,
    required this.showPinyin,
    required this.showTranslation,
  });

  final CultureItem item;
  final bool showPinyin;
  final bool showTranslation;

  @override
  ConsumerState<_ParallelCulturePassageList> createState() =>
      _ParallelCulturePassageListState();
}

class _ParallelCulturePassageListState
    extends ConsumerState<_ParallelCulturePassageList> {
  static const _batchSize = 8;
  static const _maxCachedPassages = 48;
  final _readings = <int, Future<List<String>>>{};
  late List<CulturePassage> _passages;

  @override
  void initState() {
    super.initState();
    _passages = _displayPassages(widget.item);
  }

  @override
  void didUpdateWidget(covariant _ParallelCulturePassageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.item, widget.item)) {
      _passages = _displayPassages(widget.item);
      _readings.clear();
    }
    if (oldWidget.item.id != widget.item.id ||
        (oldWidget.showPinyin && !widget.showPinyin)) {
      _readings.clear();
    }
  }

  Future<List<String>> _readingFor(int index) {
    final cached = _readings[index];
    if (cached != null) return cached;
    final reading = ref.read(contextualPinyinRepositoryProvider).resolve(
          _passages[index].original,
          ref.read(dictionaryRepositoryProvider),
        );
    _readings[index] = reading;
    return reading;
  }

  void _prefetch(int start, int end) {
    final limit = math.min(end, _passages.length);
    for (var index = math.max(0, start); index < limit; index++) {
      _readingFor(index);
    }
  }

  void _prepareReadings(int index) {
    final batchStart = index ~/ _batchSize * _batchSize;
    _prefetch(batchStart, batchStart + _batchSize);
    if (index - batchStart >= _batchSize ~/ 2) {
      _prefetch(batchStart + _batchSize, batchStart + _batchSize * 2);
    } else {
      _prefetch(batchStart - _batchSize, batchStart);
    }

    // Retain readings closest to the current passage in both directions.
    // Evicting insertion order discarded earlier passages during a downward
    // scroll, forcing them to resolve again as soon as the reader went back.
    while (_readings.length > _maxCachedPassages) {
      int? farthest;
      var distance = -1;
      for (final cachedIndex in _readings.keys) {
        final candidateDistance = (cachedIndex - index).abs();
        if (candidateDistance > distance) {
          farthest = cachedIndex;
          distance = candidateDistance;
        }
      }
      _readings.remove(farthest);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showPinyin && _readings.isEmpty) _prefetch(0, _batchSize);
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    final converter = ref.watch(hanScriptConverterProvider).valueOrNull;
    if (converter == null) {
      return const Center(child: CircularProgressIndicator());
    }
    String display(String text) =>
        converter.convert(text, settings.scriptDisplay);
    return _ArticleReader(
        key: ValueKey(widget.item.id),
        indentParagraphs: widget.item.category != CultureCategory.other,
        revision: Object.hash(
            settings.scriptDisplay, settings.fontScale, widget.showPinyin),
        open: widget.showTranslation,
        onClose: () => _closeArticleTranslation(ref),
        showParagraphNumbers: settings.showParagraphNumbers,
        showAnnotationMarkers: settings.showAnnotationMarkers,
        sourceCount: _passages.length,
        sourceTextFor: (index) => display(_passages[index].original),
        translationFor: (index) => display(_passages[index].translation),
        translationHeadingFor: (index) => display(_passages[index].heading),
        notes: display(widget.item.notes),
        appreciation: display(widget.item.appreciation),
        header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(display(widget.item.title),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(display(widget.item.subtitle),
              style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const Divider(height: 24),
        ]),
        sourceBuilder: (context, index) {
          if (widget.showPinyin) _prepareReadings(index);
          final passage = _passages[index];
          final original = display(passage.original);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (passage.heading.isNotEmpty)
                  Text(display(passage.heading),
                      style: Theme.of(context).textTheme.titleMedium),
                _ArticleOriginalText(
                    text: original,
                    showPinyin: widget.showPinyin,
                    readings: widget.showPinyin ? _readingFor(index) : null,
                    style: const TextStyle(height: 1.9, fontSize: 17)),
              ]);
        });
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
  const _PinyinText(
      {required this.text,
      this.readings,
      this.markers = const [],
      this.indent = true});
  final List<_ReadingNoteMarker> markers;
  final bool indent;
  final String text;
  final Future<List<String>>? readings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = readings;
    if (future != null) {
      return FutureBuilder<List<String>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text.rich(TextSpan(
                children: _annotatedReadingSpans(context, text, markers,
                    indent: indent)));
          }
          if (!snapshot.hasData) return _buildReadingPlaceholder(context);
          return _buildReadingText(context, snapshot.data!);
        },
      );
    }
    return ref.watch(contextualPinyinProvider(text)).when(
          loading: () => _buildReadingPlaceholder(context),
          error: (_, __) => Text.rich(TextSpan(
              children: _annotatedReadingSpans(context, text, markers,
                  indent: indent))),
          data: (pinyin) => _buildReadingText(context, pinyin),
        );
  }

  Widget _buildReadingPlaceholder(BuildContext context) {
    final placeholder = [
      for (final character in text.characters)
        if (_isReadingCharacter(character)) 'zhōng' else '',
    ];
    return _buildReadingText(context, placeholder, pending: true);
  }

  Widget _buildReadingText(BuildContext context, List<String> pinyin,
      {bool pending = false}) {
    final cellWidth = MediaQuery.textScalerOf(context).scale(18) * 1.1;
    final paragraphNumber = context
        .dependOnInheritedWidgetOfExactType<_InlineReadingNotes>()
        ?.paragraphNumber;
    return Wrap(
      spacing: 0,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        if (indent) SizedBox(width: cellWidth * 2),
        if (paragraphNumber != null)
          Text('$paragraphNumber ',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary)),
        for (final (run, attached) in _markedPinyinRuns(text, pinyin, markers))
          if (run.isLineBreak) ...[
            const SizedBox(width: double.infinity, height: 4),
            if (indent) SizedBox(width: cellWidth * 2),
          ] else
            Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                      height: 15,
                      width: cellWidth,
                      child: ExcludeSemantics(
                          excluding: pending,
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(run.pinyin,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: pending
                                          ? Colors.transparent
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary))))),
                  Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        for (final (character, numbers)
                            in _markedPinyinCharacters(run.text, attached)) ...[
                          SizedBox(
                              width: cellWidth,
                              child: Text(character,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 18))),
                          for (final number in numbers)
                            Transform.translate(
                                offset: Offset(
                                    0,
                                    -MediaQuery.textScalerOf(context)
                                            .scale(18) *
                                        .4),
                                child: _ReadingInlineMarker(number: number)),
                        ],
                      ]),
                ]),
      ],
    );
  }
}

bool _isReadingCharacter(String character) {
  if (character.runes.length != 1) return false;
  final rune = character.runes.single;
  return (rune >= 0x3400 && rune <= 0x9fff) ||
      (rune >= 0x20000 && rune <= 0x323af);
}

const _lineInitialPunctuation = '，。！？；：、,.!?;:)]}）］｝】〕〉》」』”’…—';

String _protectLineInitialPunctuation(String text) {
  final output = StringBuffer();
  for (final character in text.characters) {
    if (_lineInitialPunctuation.contains(character) && output.isNotEmpty) {
      output.write('\u2060');
    }
    output.write(character);
  }
  return output.toString();
}

List<_PinyinRun> _pinyinRuns(String text, List<String> readings) {
  final characters = text.characters.toList(growable: false);
  final runs = <_PinyinRun>[];
  var pending = '';
  for (var index = 0; index < characters.length; index++) {
    final character = characters[index];
    if (character == '\n') {
      if (pending.isNotEmpty) {
        runs.add(_PinyinRun(text: pending));
        pending = '';
      }
      runs.add(const _PinyinRun.lineBreak());
      continue;
    }
    if (_lineInitialPunctuation.contains(character)) {
      if (runs.isNotEmpty && !runs.last.isLineBreak) {
        final previous = runs.removeLast();
        runs.add(previous.copyWith(text: previous.text + character));
      } else {
        pending += character;
      }
      continue;
    }
    runs.add(
      _PinyinRun(
        text: pending + character,
        pinyin: index < readings.length ? readings[index] : '',
      ),
    );
    pending = '';
  }
  if (pending.isNotEmpty) runs.add(_PinyinRun(text: pending));
  return runs;
}

class _PinyinRun {
  const _PinyinRun({required this.text, this.pinyin = ''})
      : isLineBreak = false;
  const _PinyinRun.lineBreak()
      : text = '',
        pinyin = '',
        isLineBreak = true;

  final String text;
  final String pinyin;
  final bool isLineBreak;

  _PinyinRun copyWith({String? text}) =>
      _PinyinRun(text: text ?? this.text, pinyin: pinyin);
}
