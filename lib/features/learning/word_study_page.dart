import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/language/pinyin_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../data/word_repository.dart';
import '../dictionary/single_han_validator.dart';
import '../domain/models.dart';
import 'favorite_item.dart';
import 'favorite_feedback.dart';

class WordStudyPage extends ConsumerStatefulWidget {
  const WordStudyPage({super.key});

  @override
  ConsumerState<WordStudyPage> createState() => _WordStudyPageState();
}

class _WordStudyPageState extends ConsumerState<WordStudyPage> {
  final _text = TextEditingController();
  final _pinyin = TextEditingController();
  final _readings = <String>[];
  Future<List<WordEntry>>? _results;
  String? _error;
  String? _searchedText;
  List<String>? _searchedPinyin;
  var _limit = 50;
  late final Future<List<String>> _pinyinOptions;

  @override
  void initState() {
    super.initState();
    _pinyinOptions = _loadPinyinOptions();
  }

  Future<List<String>> _loadPinyinOptions() async {
    final entries = await ref.read(dictionaryRepositoryProvider).all();
    final options = <String>{};
    for (final entry in entries) {
      for (final reading in entry.pinyin) {
        if (PinyinUtils.isValidSyllable(reading)) {
          options.add(PinyinUtils.normalize(reading));
        }
      }
    }
    return options.toList()..sort();
  }

  @override
  void dispose() {
    _text.dispose();
    _pinyin.dispose();
    super.dispose();
  }

  WordSearchRepository? get _repository {
    final repository = ref.read(wordRepositoryProvider);
    return repository is WordSearchRepository ? repository : null;
  }

  void _searchText() {
    final query = _text.text.trim();
    final characters = query.characters.toList(growable: false);
    if (characters.length < 2 ||
        characters.length > 16 ||
        !characters.every((value) =>
            const SingleHanValidator().validate(value) is ValidHan)) {
      setState(() => _error = '请输入 2—16 个连续汉字');
      return;
    }
    setState(() {
      _error = null;
      _searchedText = query;
      _searchedPinyin = null;
      _limit = 50;
      _results = _repository?.searchText(query, limit: _limit) ??
          Future.value(const []);
    });
  }

  bool _addReadings() {
    final values = _pinyin.text.trim().split(RegExp(r'\s+'));
    if (values.isEmpty ||
        values.any((value) => !PinyinUtils.isValidSyllable(value))) {
      setState(() => _error = '请输入有效拼音，多个拼音用空格分隔');
      return false;
    }
    setState(() {
      _error = null;
      _readings.addAll(values);
      _pinyin.clear();
    });
    return true;
  }

  void _searchPinyin() {
    if (_pinyin.text.trim().isNotEmpty && !_addReadings()) return;
    if (_readings.isEmpty) {
      setState(() => _error = '请先添加至少一个拼音');
      return;
    }
    setState(() {
      _error = null;
      _searchedText = null;
      _searchedPinyin = [..._readings];
      _limit = 50;
      _results = _repository?.searchPinyin(_searchedPinyin!, limit: _limit) ??
          Future.value(const []);
    });
  }

  void _loadMore() {
    setState(() {
      _limit += 50;
      if (_searchedText case final query?) {
        _results = _repository?.searchText(query, limit: _limit);
      } else if (_searchedPinyin case final readings?) {
        _results = _repository?.searchPinyin(readings, limit: _limit);
      }
    });
  }

  void _selectReading(String reading) {
    final input = _pinyin.text.trim();
    final words = input.split(RegExp(r'\s+'));
    words[words.length - 1] = reading;
    _pinyin.text = words.join(' ');
    _addReadings();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesControllerProvider).valueOrNull ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('词语成语学习')),
      body: ResponsiveContent(
        maxWidth: 800,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              key: const Key('word-study-text'),
              controller: _text,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchText(),
              decoration: InputDecoration(
                labelText: '输入词语或成语',
                hintText: '支持查询未收录的自定义词语',
                suffixIcon: IconButton(
                  tooltip: '文字查找',
                  onPressed: _searchText,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('逐字拼音查找', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('按字的顺序添加拼音。可只选一个，也可继续添加多个；无需输入声调。'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('word-study-pinyin'),
              controller: _pinyin,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _addReadings(),
              decoration: InputDecoration(
                labelText: '拼音',
                hintText: '例如 zhong guo',
                suffixIcon: IconButton(
                  tooltip: '添加拼音',
                  onPressed: _addReadings,
                  icon: const Icon(Icons.add),
                ),
              ),
            ),
            if (_pinyin.text.trim().isNotEmpty)
              FutureBuilder<List<String>>(
                future: _pinyinOptions,
                builder: (context, snapshot) {
                  final prefix = PinyinUtils.normalize(
                      _pinyin.text.trim().split(RegExp(r'\s+')).last);
                  final matches = snapshot.data
                          ?.where((value) => value.startsWith(prefix))
                          .take(8)
                          .toList() ??
                      const <String>[];
                  if (matches.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final option in matches)
                        ActionChip(
                          label: Text(option),
                          onPressed: () => _selectReading(option),
                        ),
                    ]),
                  );
                },
              ),
            if (_readings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 4, children: [
                for (var index = 0; index < _readings.length; index++)
                  InputChip(
                    label: Text('第 ${index + 1} 字：${_readings[index]}'),
                    onDeleted: () => setState(() => _readings.removeAt(index)),
                  ),
              ]),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: _searchPinyin,
                icon: const Icon(Icons.search),
                label: const Text('按拼音查找'),
              ),
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Text(error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 18),
            if (_results case final results?)
              FutureBuilder<List<WordEntry>>(
                future: results,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const EmptyState(
                        title: '查找失败', message: '请检查本地词语资源');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!;
                  return Column(
                    children: [
                      if (_searchedText case final query?)
                        if (!items.any((entry) => entry.word == query))
                          Card(
                            child: ListTile(
                              title: Text('查询“$query”'),
                              subtitle: const Text('词库未收录时仍可查看逐字释义并收藏'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(AppRoutes.word(query)),
                            ),
                          ),
                      if (items.isEmpty && _searchedText == null)
                        const EmptyState(title: '没有匹配的词语', message: '试试其他逐字拼音'),
                      for (final item in items)
                        Card(
                          child: ListTile(
                            title: Text(item.word),
                            subtitle: Text('${item.pinyin}\n${item.definition}',
                                maxLines: 3, overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                            onTap: () =>
                                context.push(AppRoutes.word(item.word)),
                            trailing: (ref
                                        .watch(settingsControllerProvider)
                                        .valueOrNull
                                        ?.showFavorites ??
                                    true)
                                ? IconButton(
                                    tooltip: favorites.contains(FavoriteItem(
                                                FavoriteKind.word, item.word)
                                            .storageKey)
                                        ? '取消收藏词语'
                                        : '收藏词语',
                                    onPressed: () => toggleFavoriteWithFeedback(
                                        context,
                                        ref,
                                        FavoriteItem(
                                                FavoriteKind.word, item.word)
                                            .storageKey),
                                    icon: Icon(favorites.contains(FavoriteItem(
                                                FavoriteKind.word, item.word)
                                            .storageKey)
                                        ? Icons.star
                                        : Icons.star_border),
                                  )
                                : null,
                          ),
                        ),
                      if (items.length == _limit)
                        TextButton(
                          onPressed: _loadMore,
                          child: const Text('加载更多'),
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
