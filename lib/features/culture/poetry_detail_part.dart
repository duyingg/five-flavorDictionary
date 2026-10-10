part of 'culture_pages.dart';

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
      _itemFuture = _loadItem(fullLibrary);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('诗词'),
        actions: const [
          Padding(
              padding: EdgeInsetsDirectional.only(end: 12),
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

  Future<PoetryItem?> _loadItem(bool fullLibrary) async {
    final repository = ref.read(poetryRepositoryProvider);
    return await repository.getById(widget.id, fullLibrary: fullLibrary) ??
        await repository.getById(widget.id, fullLibrary: !fullLibrary);
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
    final favoriteKey = FavoriteItem(FavoriteKind.poetry, item.id).storageKey;
    final isFavorite = ref
            .watch(favoritesControllerProvider)
            .valueOrNull
            ?.contains(favoriteKey) ??
        false;
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
    List<String> lines(String value) => value
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    final sourceLines = lines(displayContent);
    final noteLines = lines(display(item.notes));
    final translationLines = lines(display(item.translation));
    final inlineNotes = modes.contains(CultureDisplayMode.notes) &&
        sourceLines.length > 1 &&
        noteLines.length == sourceLines.length;
    final inlineTranslation = modes.contains(CultureDisplayMode.translation) &&
        sourceLines.length > 1 &&
        translationLines.length == sourceLines.length;
    return ResponsiveContent(
      maxWidth: 760,
      child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    display(item.title),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  tooltip: isFavorite ? '取消收藏诗词' : '收藏诗词',
                  onPressed: () =>
                      toggleFavoriteWithFeedback(context, ref, favoriteKey),
                  icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                ),
              ],
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
            if (inlineNotes || inlineTranslation)
              for (var index = 0; index < sourceLines.length; index++) ...[
                if (modes.contains(CultureDisplayMode.reading))
                  _PinyinText(text: sourceLines[index])
                else
                  Text(_protectLineInitialPunctuation(sourceLines[index]),
                      style: const TextStyle(fontSize: 18, height: 2)),
                if (inlineNotes) ...[
                  const SizedBox(height: 8),
                  _PoetrySupplement(
                      title: '注释', content: noteLines[index], missing: ''),
                ],
                if (inlineTranslation) ...[
                  const SizedBox(height: 8),
                  _PoetrySupplement(
                      title: '翻译',
                      content: translationLines[index],
                      missing: ''),
                ],
                const SizedBox(height: 16),
              ]
            else if (modes.contains(CultureDisplayMode.reading))
              _PinyinText(text: displayContent)
            else
              Text(_protectLineInitialPunctuation(displayContent),
                  style: const TextStyle(fontSize: 18, height: 2)),
            if (modes.contains(CultureDisplayMode.notes) &&
                item.notes.isNotEmpty &&
                !inlineNotes) ...[
              const SizedBox(height: 24),
              _PoetrySupplement(
                  title: '注释', content: display(item.notes), missing: ''),
            ],
            if (modes.contains(CultureDisplayMode.translation) &&
                item.translation.isNotEmpty &&
                !inlineTranslation) ...[
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
          ]),
    );
  }
}

String readablePoetrySource(String content) {
  final lines = content.replaceAll(RegExp('□+'), '〔原文缺字〕').split('\n');
  final result = <String>[];
  for (final line in lines) {
    var leading = 0;
    while (leading < line.length &&
        _lineInitialPunctuation.contains(line[leading])) {
      leading++;
    }
    if (leading == 0) {
      result.add(line);
      continue;
    }
    final punctuation = line.substring(0, leading);
    final remaining = line.substring(leading);
    var previous = result.length - 1;
    while (previous >= 0 && result[previous].isEmpty) {
      previous--;
    }
    if (previous >= 0) {
      result[previous] += punctuation;
      if (remaining.isNotEmpty) result.add(remaining);
    } else {
      result.add('〔原文残缺〕$punctuation$remaining');
    }
  }
  return result.join('\n');
}

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
            Text(
                _protectLineInitialPunctuation(
                    content.isEmpty ? missing : content),
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
