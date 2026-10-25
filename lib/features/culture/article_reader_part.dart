part of 'culture_pages.dart';

/// Original text and reference material have separate viewports. Only the
/// notes and translation tabs are linked; appreciation always scrolls independently.
class _ArticleReader extends StatefulWidget {
  const _ArticleReader(
      {required this.header,
      required this.sourceCount,
      required this.sourceBuilder,
      required this.sourceTextFor,
      required this.open,
      required this.onClose,
      required this.revision,
      this.indentParagraphs = true,
      this.showParagraphNumbers = true,
      this.showAnnotationMarkers = true,
      this.translations,
      this.translationFor,
      this.translationHeadingFor,
      this.translation = '',
      this.notes = '',
      this.appreciation = '',
      super.key});
  final Widget header;
  final int sourceCount;
  final IndexedWidgetBuilder sourceBuilder;
  final String Function(int) sourceTextFor;
  final bool open;
  final bool indentParagraphs;
  final bool showParagraphNumbers;
  final bool showAnnotationMarkers;
  final VoidCallback onClose;
  final Object revision;
  final List<String>? translations;
  final String Function(int)? translationFor;
  final String Function(int)? translationHeadingFor;
  final String translation;
  final String notes;
  final String appreciation;
  @override
  State<_ArticleReader> createState() => _ArticleReaderState();
}

class _ArticleReaderState extends State<_ArticleReader>
    with SingleTickerProviderStateMixin {
  final _source = GlobalKey<_ReadingPaneState>();
  final _references = List.generate(3, (_) => GlobalKey<_ReadingPaneState>());
  late final TabController _tabs;
  late List<_ReadingNote> _notes;
  late List<String> _translationParagraphs;
  late String _appreciation;
  final _noteSourceIndices = <int, int>{};
  final _noteMarkerKeys = <int, GlobalKey>{};
  final _sourceNoteNumbers = <int, Set<int>>{};
  final _noteAnchors = <({int source, int note, int offset})>[];
  int _syncGeneration = 0;
  int _activePane = 0;
  int _selectedTab = 1;
  int _pendingFrom = 0;
  bool _scheduled = false;
  _ReadingPosition? _pending;
  _ReadingPosition _sourcePosition = const _ReadingPosition(0, 0, 0);

  bool get _hasAlignedTranslation =>
      widget.translationFor != null ||
      widget.translations?.length == widget.sourceCount;
  @override
  void initState() {
    super.initState();
    _appreciation = _cleanReadingAppreciation(widget.appreciation);
    _notes = _readingNotes(widget.notes);
    _indexNoteSources();
    _translationParagraphs = _splitTranslation(widget.translation);
    _tabs = TabController(
        length: 3,
        vsync: this,
        initialIndex: widget.notes.trim().isNotEmpty ? 0 : 1);
    _selectedTab = _tabs.index;
    _tabs.addListener(_tabChanged);
  }

  void _tabChanged() {
    if (_selectedTab == _tabs.index) return;
    setState(() => _selectedTab = _tabs.index);
    _syncGeneration++;
    _pending = null;
    _activePane = 0;
    _source.currentState?.cancelPendingSeek();
    for (final reference in _references) {
      reference.currentState?.cancelPendingSeek();
    }
    if (_selectedTab != 2) _queueSync(_sourcePosition);
  }

  // Locate explicit note headwords once per content revision. The note number
  // stays global even when only a subset belongs to a given source paragraph.
  void _indexNoteSources() {
    _noteSourceIndices.clear();
    _sourceNoteNumbers.clear();
    _noteAnchors.clear();
    final remaining = {
      for (var note = 0; note < _notes.length; note++)
        if (_notes[note].term.isNotEmpty) note,
    };
    for (var source = 0;
        source < widget.sourceCount && remaining.isNotEmpty;
        source++) {
      final text = widget.sourceTextFor(source);
      final found = <int>[];
      for (final note in remaining) {
        final offset = text.indexOf(_notes[note].term);
        if (offset < 0) continue;
        _noteSourceIndices[note] = source + 1; // Source pane includes a header.
        (_sourceNoteNumbers[source] ??= {}).add(note + 1);
        _noteAnchors.add((source: source + 1, note: note, offset: offset));
        found.add(note);
      }
      remaining.removeAll(found);
    }
    _noteAnchors.sort((a, b) {
      final paragraph = a.source.compareTo(b.source);
      return paragraph != 0 ? paragraph : a.offset.compareTo(b.offset);
    });
  }

  @override
  void didUpdateWidget(covariant _ArticleReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.appreciation != oldWidget.appreciation) {
      _appreciation = _cleanReadingAppreciation(widget.appreciation);
    }
    if (oldWidget.notes != widget.notes) _notes = _readingNotes(widget.notes);
    if (oldWidget.notes != widget.notes ||
        oldWidget.revision != widget.revision ||
        oldWidget.sourceCount != widget.sourceCount) {
      _indexNoteSources();
    }
    if (oldWidget.open != widget.open) {
      _syncGeneration++;
      _pending = null;
    }
    if (oldWidget.translation != widget.translation) {
      _translationParagraphs = _splitTranslation(widget.translation);
    }
    if (!oldWidget.open && widget.open) {
      _activePane = 0;
      _queueSync(_sourcePosition);
    }
  }

  void _changed(int pane, _ReadingPosition position) {
    if (pane == 0) _sourcePosition = position;
    if (widget.open && _selectedTab != 2 && pane == _activePane) {
      _queueSync(position);
    }
  }

  void _queueSync(_ReadingPosition position) {
    if (_selectedTab == 2) return;
    _pending = position;
    _pendingFrom = _activePane;
    if (_scheduled) return;
    _scheduled = true;
    final generation = _syncGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.open || _selectedTab == 2) return;
      if (generation != _syncGeneration) {
        if (_pending != null) _queueSync(_pending!);
        return;
      }
      if (_pendingFrom != _activePane) return;
      final mark = _pending;
      if (mark == null) return;
      final target = _activePane == 0
          ? _references[_tabs.index].currentState
          : _source.currentState;
      if (_selectedTab == 0) {
        if (_activePane == 0) {
          if (_noteAnchors.isEmpty) return;
          final visible =
              _source.currentState?.firstVisibleAnchor(_noteMarkerKeys);
          final note = visible == null
              ? _noteAnchors
                  .firstWhere((anchor) => anchor.source >= mark.index,
                      orElse: () => _noteAnchors.last)
                  .note
              : visible - 1;
          target?.showPosition(_ReadingPosition(note, 0, 0));
        } else {
          final source = _noteSourceIndices[mark.index];
          if (source != null) {
            target?.showPosition(_ReadingPosition(source, 0, 0));
            // A distant paragraph must first be laid out before its inline
            // marker has a screen position. Then align the actual headword.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted ||
                  !widget.open ||
                  generation != _syncGeneration ||
                  _selectedTab != 0 ||
                  _activePane != 1) {
                return;
              }
              final key = _noteMarkerKeys[mark.index + 1];
              if (key != null) target?.showAnchor(key);
            });
          }
        }
      } else if (_hasAlignedTranslation) {
        target?.showPosition(mark);
      } else {
        target?.showProgress(mark.progress);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  List<String> _splitTranslation(String text) => text
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);

  Widget _reference(int tab) {
    final aligned = tab == 1 && _hasAlignedTranslation;
    final content = [widget.notes, widget.translation, _appreciation][tab];
    const labels = ['注释', '译文', '赏析'];
    final numberedNotes = tab == 0 && _notes.isNotEmpty;
    final separateTranslation =
        tab == 1 && !aligned && _translationParagraphs.isNotEmpty;
    return ColoredBox(
        color: _referenceColor(context, .12),
        child: _ReadingPane(
            key: _references[tab],
            count: aligned
                ? widget.sourceCount + 1
                : numberedNotes
                    ? _notes.length
                    : separateTranslation
                        ? _translationParagraphs.length
                        : 1,
            revision: Object.hash(widget.revision, tab, content,
                widget.showParagraphNumbers, widget.showAnnotationMarkers),
            onUserScroll: () => _activePane = tab + 1,
            onPosition: (mark) => _changed(tab + 1, mark),
            builder: (context, index) {
              if (aligned && index == 0) {
                return Text('译文',
                    style: Theme.of(context).textTheme.titleMedium);
              }
              final text = aligned
                  ? (widget.translationFor?.call(index - 1) ??
                      widget.translations![index - 1])
                  : numberedNotes
                      ? _notes[index].text
                      : separateTranslation
                          ? _translationParagraphs[index]
                          : content;
              final paragraph = text.trim().isEmpty
                  ? (aligned ? '本段暂无译文' : '当前内容暂无${labels[tab]}')
                  : text;
              final number = tab == 1 &&
                      widget.showParagraphNumbers &&
                      (aligned || separateTranslation)
                  ? (aligned ? index : index + 1)
                  : numberedNotes && widget.showAnnotationMarkers
                      ? index + 1
                      : null;
              final body = _readingReferenceParagraph(context, paragraph,
                  indent: widget.indentParagraphs,
                  number: number,
                  paragraph: tab == 1);
              final heading = aligned
                  ? widget.translationHeadingFor?.call(index - 1)
                  : null;
              if (heading != null && heading.trim().isNotEmpty) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(heading,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      body,
                    ]);
              }
              return body;
            }));
  }

  Color _referenceColor(BuildContext context, double shade) => Color.alphaBlend(
      Colors.black.withValues(alpha: shade),
      Theme.of(context).scaffoldBackgroundColor);

  Widget _sourceBlock(BuildContext context, int index) {
    final child = widget.sourceBuilder(context, index);
    return _InlineReadingNotes(
        notes: widget.open && _selectedTab == 0 && widget.showAnnotationMarkers
            ? _notes
            : const [],
        visibleNumbers: _sourceNoteNumbers[index] ?? const {},
        markerKeys: _noteMarkerKeys,
        indentParagraphs: widget.indentParagraphs,
        paragraphNumber:
            widget.open && _selectedTab == 1 && widget.showParagraphNumbers
                ? index + 1
                : null,
        child: child);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(
            flex: widget.open ? 55 : 1,
            child: _ReadingPane(
                key: _source,
                count: widget.sourceCount + 1,
                revision: Object.hash(
                    widget.revision,
                    widget.open,
                    widget.indentParagraphs,
                    _selectedTab,
                    widget.showParagraphNumbers,
                    widget.showAnnotationMarkers),
                onUserScroll: () => _activePane = 0,
                onPosition: (mark) => _changed(0, mark),
                builder: (context, index) => index == 0
                    ? widget.header
                    : _sourceBlock(context, index - 1))),
        if (widget.open) ...[
          const Divider(height: 1),
          Material(
              color: _referenceColor(context, .20),
              child: Row(children: [
                Expanded(
                    child: TabBar(controller: _tabs, tabs: const [
                  Tab(text: '注释'),
                  Tab(text: '译文'),
                  Tab(text: '赏析')
                ])),
                IconButton(
                    tooltip: '收起翻译',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.expand_more)),
              ])),
          Expanded(
              flex: 45,
              child: TabBarView(controller: _tabs, children: [
                for (var tab = 0; tab < 3; tab++) _reference(tab)
              ])),
        ],
      ]);

  @override
  void dispose() {
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }
}

class _ReadingPosition {
  const _ReadingPosition(this.index, this.fraction, this.progress);
  final int index;
  final double fraction;
  final double progress;
}

/// Two lazy slivers around an index let the partner viewport seek directly to
/// a distant paragraph without laying out an entire ancient book first.
class _ReadingPane extends StatefulWidget {
  const _ReadingPane(
      {required this.count,
      required this.builder,
      required this.onPosition,
      required this.onUserScroll,
      required this.revision,
      super.key});
  final int count;
  final IndexedWidgetBuilder builder;
  final ValueChanged<_ReadingPosition> onPosition;
  final VoidCallback onUserScroll;
  final Object revision;
  @override
  State<_ReadingPane> createState() => _ReadingPaneState();
}

class _ReadingPaneState extends State<_ReadingPane>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _center = GlobalKey();
  final _blocks = <int, GlobalKey>{};
  int _origin = 0;
  int _seekVersion = 0;
  bool _positionScheduled = false;
  _ReadingPosition _last = const _ReadingPosition(0, 0, 0);
  @override
  bool get wantKeepAlive => true;

  @override
  void didUpdateWidget(covariant _ReadingPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      final mark = _last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showPosition(mark);
      });
    }
  }

  Rect? _rect(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  _ReadingPosition _position() {
    final viewport = _rect(_viewport);
    if (viewport == null || !_scroll.hasClients) return _last;
    int index = _origin;
    double fraction = 0;
    double closest = double.infinity;
    if (_blocks.length > 128) {
      _blocks.removeWhere((_, key) => key.currentContext == null);
    }
    for (final entry in _blocks.entries) {
      final rect = _rect(entry.value);
      if (rect == null ||
          rect.bottom <= viewport.top ||
          rect.top >= viewport.bottom) {
        continue;
      }
      final distance = (rect.top - viewport.top).abs();
      if (rect.top <= viewport.top || distance < closest) {
        index = entry.key;
        fraction = ((viewport.top - rect.top) / rect.height).clamp(0.0, 1.0);
        closest = distance;
        if (rect.top <= viewport.top) break;
      }
    }
    final position = _scroll.position;
    final extent = position.maxScrollExtent - position.minScrollExtent;
    final progress = extent <= 0
        ? 0.0
        : ((position.pixels - position.minScrollExtent) / extent)
            .clamp(0.0, 1.0);
    return _ReadingPosition(index, fraction, progress);
  }

  void _jump(double offset) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final next =
        offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((position.pixels - next).abs() > .5) _scroll.jumpTo(next);
  }

  int? firstVisibleAnchor(Map<int, GlobalKey> anchors) {
    final viewport = _rect(_viewport);
    if (viewport == null) return null;
    int? first;
    var top = double.infinity;
    for (final entry in anchors.entries) {
      final rect = _rect(entry.value);
      if (rect != null &&
          rect.bottom >= viewport.top &&
          rect.top < viewport.bottom &&
          rect.top < top) {
        first = entry.key;
        top = rect.top;
      }
    }
    return first;
  }

  void showAnchor(GlobalKey key) {
    final rect = _rect(key);
    final viewport = _rect(_viewport);
    if (rect == null || viewport == null || !_scroll.hasClients) return;
    ++_seekVersion;
    _jump(_scroll.offset + rect.top - viewport.top);
  }

  void cancelPendingSeek() => ++_seekVersion;

  void showProgress(double progress) {
    if (!mounted || !_scroll.hasClients) return;
    ++_seekVersion;
    final position = _scroll.position;
    _jump(position.minScrollExtent +
        progress * (position.maxScrollExtent - position.minScrollExtent));
  }

  void showPosition(_ReadingPosition mark) {
    if (!mounted || !_scroll.hasClients || widget.count == 0) return;
    final index = mark.index.clamp(0, widget.count - 1);
    final version = ++_seekVersion;
    bool align() {
      final key = _blocks[index];
      final rect = key == null ? null : _rect(key);
      final viewport = _rect(_viewport);
      if (rect == null || viewport == null) return false;
      _jump(_scroll.offset +
          rect.top -
          viewport.top +
          mark.fraction * rect.height);
      return true;
    }

    if (align()) return;
    setState(() => _origin = index);
    _scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && version == _seekVersion) align();
    });
  }

  void _reportPositionAfterLayout() {
    if (_positionScheduled) return;
    _positionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionScheduled = false;
      if (!mounted) return;
      _last = _position();
      widget.onPosition(_last);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _block(BuildContext context, int index) => Padding(
      key: _blocks.putIfAbsent(index, GlobalKey.new),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: widget.builder(context, index));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth != 0) return false;
        if ((notification is ScrollStartNotification &&
                notification.dragDetails != null) ||
            (notification is UserScrollNotification &&
                notification.direction != ScrollDirection.idle)) {
          widget.onUserScroll();
        }
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          _reportPositionAfterLayout();
        }
        return false;
      },
      child: SizedBox.expand(
          key: _viewport,
          child: SelectionArea(
              child: CustomScrollView(
                  controller: _scroll,
                  center: _center,
                  slivers: [
                SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _block(context, _origin - index - 1),
                        childCount: _origin)),
                SliverList(
                    key: _center,
                    delegate: SliverChildBuilderDelegate(
                        (context, index) => _block(context, _origin + index),
                        childCount: widget.count - _origin)),
              ]))),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

void _closeArticleTranslation(WidgetRef ref) {
  ref.read(cultureDisplayModeProvider.notifier).state = {
    for (final mode in ref.read(cultureDisplayModeProvider))
      if (mode == CultureDisplayMode.reading) mode,
  };
}
