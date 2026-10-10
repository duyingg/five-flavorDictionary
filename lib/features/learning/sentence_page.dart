import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';

class SentencePage extends ConsumerStatefulWidget {
  const SentencePage({super.key});
  @override
  ConsumerState<SentencePage> createState() => _SentencePageState();
}

class _SentencePageState extends ConsumerState<SentencePage> {
  final _controller = TextEditingController();
  final _selectedIds = <String>{};
  String? _character;
  bool _selecting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(sentenceNotesControllerProvider);
    final todayCharacters = ref.watch(todayCharactersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? '已选择 ${_selectedIds.length} 项' : '造句'),
        actions: _buildActions(notes.valueOrNull ?? const []),
      ),
      body: ResponsiveContent(
        maxWidth: 800,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: _SentenceComposer(
                  characters: todayCharacters.valueOrNull
                          ?.where((entry) => entry.characterLevel == 1)
                          .take(6)
                          .map((entry) => entry.character)
                          .toList(growable: false) ??
                      const [],
                  loading: todayCharacters.isLoading,
                  selectedCharacter: _character,
                  controller: _controller,
                  onCharacterSelected: (value) =>
                      setState(() => _character = value),
                  onSave: _save,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              sliver: notes.when(
                data: (items) => items.isEmpty
                    ? const SliverToBoxAdapter(
                        child: EmptyState(
                          title: '还没有造句',
                          message: '选择今日汉字，写下第一条造句。',
                        ),
                      )
                    : SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final note = items[index];
                          return _SentenceNoteCard(
                            note: note,
                            selecting: _selecting,
                            selected: _selectedIds.contains(note.id),
                            onTap: () => _toggleSelection(note.id),
                            onLongPress: () {
                              if (!_selecting) {
                                setState(() => _selecting = true);
                              }
                              _toggleSelection(note.id);
                            },
                          );
                        },
                      ),
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const SliverToBoxAdapter(
                  child: EmptyState(
                    title: '造句加载失败',
                    message: '请重新打开页面后再试。',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(List<SentenceNote> notes) {
    if (notes.isEmpty) return const [];
    if (!_selecting) {
      return [
        IconButton(
          tooltip: '批量管理',
          onPressed: () => setState(() => _selecting = true),
          icon: const Icon(Icons.checklist),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: _selectedIds.length == notes.length ? '取消全选' : '全选',
        onPressed: () => setState(() {
          if (_selectedIds.length == notes.length) {
            _selectedIds.clear();
          } else {
            _selectedIds
              ..clear()
              ..addAll(notes.map((note) => note.id));
          }
        }),
        icon: Icon(
          _selectedIds.length == notes.length
              ? Icons.deselect
              : Icons.select_all,
        ),
      ),
      IconButton(
        tooltip: '删除所选',
        onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
        icon: const Icon(Icons.delete_outline),
      ),
      IconButton(
        tooltip: '退出管理',
        onPressed: () => setState(() {
          _selecting = false;
          _selectedIds.clear();
        }),
        icon: const Icon(Icons.close),
      ),
    ];
  }

  Future<void> _save(String fallbackCharacter) async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    final character = _character ?? fallbackCharacter;
    await ref
        .read(sentenceNotesControllerProvider.notifier)
        .add(character, content);
    if (!mounted) return;
    _controller.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('造句已保存')),
    );
  }

  void _toggleSelection(String id) {
    if (!_selecting) return;
    setState(() {
      _selectedIds.contains(id)
          ? _selectedIds.remove(id)
          : _selectedIds.add(id);
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除造句？'),
        content: Text('将删除选中的 $count 条记录，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(sentenceNotesControllerProvider.notifier)
        .removeAll(Set.of(_selectedIds));
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _selecting = false;
    });
  }
}

class _SentenceComposer extends StatelessWidget {
  const _SentenceComposer({
    required this.characters,
    required this.loading,
    required this.selectedCharacter,
    required this.controller,
    required this.onCharacterSelected,
    required this.onSave,
  });

  final List<String> characters;
  final bool loading;
  final String? selectedCharacter;
  final TextEditingController controller;
  final ValueChanged<String> onCharacterSelected;
  final ValueChanged<String> onSave;

  @override
  Widget build(BuildContext context) {
    final active = characters.contains(selectedCharacter)
        ? selectedCharacter!
        : characters.firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新建造句', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '从今日 6 个汉字中选择一个来造句',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final character in characters)
                    ChoiceChip(
                      label: Text(character),
                      selected: active == character,
                      onSelected: (_) => onCharacterSelected(character),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('sentence-editor'),
              controller: controller,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: active == null ? '今日汉字加载中' : '用“$active”写一句话',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                onPressed: active == null ? null : () => onSave(active),
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存造句'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceNoteCard extends StatelessWidget {
  const _SentenceNoteCard({
    required this.note,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final SentenceNote note;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => Card(
        color: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: selecting ? onTap : null,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selecting) ...[
                  Checkbox(value: selected, onChanged: (_) => onTap()),
                  const SizedBox(width: 8),
                ] else ...[
                  CircleAvatar(child: Text(note.character)),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.content, style: const TextStyle(height: 1.55)),
                      const SizedBox(height: 10),
                      Text(
                        _formatSentenceTime(note.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

String _formatSentenceTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}年${two(value.month)}月${two(value.day)}日 '
      '${two(value.hour)}:${two(value.minute)}';
}
