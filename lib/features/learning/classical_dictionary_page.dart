import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';

typedef _IndexRow = List<String>;

List<_IndexRow> _decodeClassicalIndex(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(gzip.decode(bytes))) as List;
  return decoded
      .map((row) => (row as List).cast<String>())
      .toList(growable: false);
}

class ClassicalDictionaryPage extends ConsumerStatefulWidget {
  const ClassicalDictionaryPage({super.key});

  @override
  ConsumerState<ClassicalDictionaryPage> createState() =>
      _ClassicalDictionaryPageState();
}

class _ClassicalDictionaryPageState
    extends ConsumerState<ClassicalDictionaryPage> {
  final _controller = TextEditingController();
  late final Future<List<_IndexRow>> _indexFuture;
  String _query = '';
  ChineseEntry? _character;
  WordEntry? _word;
  List<_IndexRow> _matches = const [];
  bool _loading = false;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _indexFuture = _loadIndex();
  }

  Future<List<_IndexRow>> _loadIndex() async {
    final data =
        await rootBundle.load('assets/data/classical_lookup_index.json.gz');
    return compute(
        _decodeClassicalIndex,
        data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ));
  }

  Future<void> _search([String? value]) async {
    final query = (value ?? _controller.text).trim();
    if (query.isEmpty) return;
    final request = ++_request;
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    try {
      final indexFuture = _indexFuture;
      final characterFuture = query.runes.length == 1
          ? ref.read(dictionaryRepositoryProvider).findExactCharacter(query)
          : Future<ChineseEntry?>.value(null);
      final wordFuture = query.runes.length > 1
          ? ref.read(wordRepositoryProvider).findExact(query)
          : Future<WordEntry?>.value(null);
      final index = await indexFuture;
      final matches = <_IndexRow>[];
      final perBook = <String, int>{};
      for (final row in index) {
        if (!row[3].contains(query)) continue;
        final count = perBook[row[0]] ?? 0;
        if (count >= 3) continue;
        perBook[row[0]] = count + 1;
        matches.add(row);
        if (matches.length == 90) break;
      }
      final character = await characterFuture;
      final word = await wordFuture;
      if (!mounted || request != _request) return;
      setState(() {
        _character = character;
        _word = word;
        _matches = matches;
        _loading = false;
      });
    } catch (error) {
      assert(() {
        debugPrint('文言文字典查询失败：$error');
        return true;
      }());
      if (!mounted || request != _request) return;
      setState(() {
        _error = '查询资源读取失败，请重试。';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _excerpt(String source, String query, {int radius = 34}) {
    final hit = source.indexOf(query);
    if (hit < 0) {
      return source.length <= radius * 2
          ? source
          : '${source.substring(0, radius * 2)}…';
    }
    final start = (hit - radius).clamp(0, source.length);
    final end = (hit + query.length + radius).clamp(0, source.length);
    return '${start > 0 ? '…' : ''}${source.substring(start, end)}${end < source.length ? '…' : ''}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('文言文字典')),
        body: ResponsiveContent(
          maxWidth: 860,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text('查字词与典籍用例',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('输入文言文中的字或词，查看字词释义，以及本机典籍中的原句和对应译文。',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _search,
                    decoration: const InputDecoration(
                      labelText: '查询字词',
                      hintText: '如：之、无为、君子',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                    onPressed: _loading ? null : _search,
                    child: const Text('查询')),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final sample in const ['之', '而', '无为', '仁', '君子'])
                  ActionChip(
                      label: Text(sample), onPressed: () => _search(sample)),
              ]),
              if (_loading) ...[
                const SizedBox(height: 20),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (_query.isNotEmpty && !_loading && _error == null) ...[
                const SizedBox(height: 28),
                Text('“$_query”的释义',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (_character case final entry?) ...[
                  if (entry.pinyin.isNotEmpty)
                    Text(entry.pinyin.join(' · '),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary)),
                  for (final sense in entry.senses.take(16))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('• ${sense.definition}'),
                    ),
                  TextButton(
                    onPressed: () =>
                        context.push(AppRoutes.character(entry.character)),
                    child: const Text('查看完整字条'),
                  ),
                ] else if (_word case final word?) ...[
                  if (word.pinyin.isNotEmpty)
                    Text(word.pinyin,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 8),
                  Text(word.definition),
                ] else
                  const Text('现有字词库暂无整词释义，可参考下方典籍用例。'),
                const SizedBox(height: 24),
                Text('典籍用例', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text('从 30 部本机文献中按原文匹配；译文解释整段语意，具体字义须结合上下文判断。',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                if (_matches.isEmpty)
                  const Text('本机文献中未找到相同字词。')
                else
                  for (final row in _matches)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '《${row[1]}》${row[2].isEmpty ? '' : ' · ${row[2]}'}',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(_excerpt(row[3], _query)),
                            if (row[4].isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('译文：${_excerpt(row[4], _query, radius: 55)}',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ],
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: () => context
                                    .push(AppRoutes.cultureDetail(row[0])),
                                child: const Text('打开原文'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      );
}
