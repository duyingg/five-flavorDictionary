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

class _PoetryDetailBody extends ConsumerWidget {
  const _PoetryDetailBody({required this.item});
  final PoetryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const AppSettings();
    final showFavorites = settings.showFavorites;
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
    String display(String text) =>
        converter.convert(text, settings.scriptDisplay);
    List<String> lines(String text) => text
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    final sourceLines = lines(display(readablePoetrySource(item.content)));
    final translated = lines(display(item.translation));
    final modes = ref.watch(cultureDisplayModeProvider);
    return ResponsiveContent(
        maxWidth: 800,
        child: _ArticleReader(
          key: ValueKey(item.id),
          revision: Object.hash(settings.scriptDisplay, settings.fontScale,
              modes.contains(CultureDisplayMode.reading)),
          open: modes.contains(CultureDisplayMode.translation),
          onClose: () => _closeArticleTranslation(ref),
          showParagraphNumbers: settings.showParagraphNumbers,
          showAnnotationMarkers: settings.showAnnotationMarkers,
          sourceCount: sourceLines.length,
          sourceTextFor: (index) => sourceLines[index],
          sourceBuilder: (context, index) => _ArticleOriginalText(
              text: sourceLines[index],
              showPinyin: modes.contains(CultureDisplayMode.reading)),
          translations:
              translated.length == sourceLines.length && translated.isNotEmpty
                  ? translated
                  : null,
          translation: display(item.translation),
          notes: display(item.notes),
          appreciation: display(item.appreciation),
          header: Column(children: [
            Row(
              children: [
                if (showFavorites) const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    display(item.title),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (showFavorites)
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
          ]),
        ));
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
