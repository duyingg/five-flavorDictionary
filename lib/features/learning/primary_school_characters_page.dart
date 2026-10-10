import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../domain/models.dart';

class PrimarySchoolCharactersPage extends ConsumerStatefulWidget {
  const PrimarySchoolCharactersPage({super.key});

  @override
  ConsumerState<PrimarySchoolCharactersPage> createState() =>
      _PrimarySchoolCharactersPageState();
}

class _PrimarySchoolCharactersPageState
    extends ConsumerState<PrimarySchoolCharactersPage> {
  late final Future<_PrimarySchoolPageData> _dataFuture;
  var _grade = 1;
  var _semester = '上';

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_PrimarySchoolPageData> _load() async {
    final entriesFuture = ref.read(dictionaryRepositoryProvider).all();
    final assetFuture = rootBundle.loadString(
      'assets/data/primary_school_characters.json',
    );
    final entries = await entriesFuture;
    final raw = await assetFuture;
    return _PrimarySchoolPageData(
      catalog: _PrimarySchoolCatalog.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      ),
      entriesByCharacter: {
        for (final entry in entries) entry.character: entry,
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('小学语文生字')),
        body: FutureBuilder<_PrimarySchoolPageData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const EmptyState(
                title: '加载失败',
                message: '无法读取小学语文写字表，请重新打开页面后再试。',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final pageData = snapshot.data!;
            final book = pageData.catalog.books.firstWhere(
              (item) => item.grade == _grade && item.semester == _semester,
            );
            return ResponsiveContent(
              maxWidth: 960,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var grade = 1; grade <= 6; grade++)
                                ChoiceChip(
                                  key: Key('primary-school-grade-$grade'),
                                  label: Text('$grade 年级'),
                                  selected: _grade == grade,
                                  onSelected: (_) =>
                                      setState(() => _grade = grade),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: '上', label: Text('上册')),
                              ButtonSegment(value: '下', label: Text('下册')),
                            ],
                            selected: {_semester},
                            onSelectionChanged: (value) =>
                                setState(() => _semester = value.single),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '$_grade 年级$_semester册 · ${book.characters.length} 字',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    sliver: SliverGrid.builder(
                      itemCount: book.characters.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.sizeOf(context).width >= 720 ? 6 : 3,
                        childAspectRatio: .9,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final character = book.characters[index];
                        return _CharacterCard(
                          character: character,
                          entry: pageData.entriesByCharacter[character],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character, required this.entry});

  final String character;
  final ChineseEntry? entry;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(AppRoutes.character(character)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry?.pinyin.firstOrNull ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(character, style: const TextStyle(fontSize: 38)),
                const SizedBox(height: 3),
                Text(
                  entry == null ? '' : '${entry!.strokeCount} 画',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _PrimarySchoolPageData {
  const _PrimarySchoolPageData({
    required this.catalog,
    required this.entriesByCharacter,
  });

  final _PrimarySchoolCatalog catalog;
  final Map<String, ChineseEntry> entriesByCharacter;
}

class _PrimarySchoolCatalog {
  const _PrimarySchoolCatalog({required this.books});

  final List<_PrimarySchoolBook> books;

  factory _PrimarySchoolCatalog.fromJson(Map<String, dynamic> json) =>
      _PrimarySchoolCatalog(
        books: (json['books'] as List)
            .map(
              (item) => _PrimarySchoolBook.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList(growable: false),
      );
}

class _PrimarySchoolBook {
  const _PrimarySchoolBook({
    required this.grade,
    required this.semester,
    required this.characters,
  });

  final int grade;
  final String semester;
  final List<String> characters;

  factory _PrimarySchoolBook.fromJson(Map<String, dynamic> json) =>
      _PrimarySchoolBook(
        grade: json['grade'] as int,
        semester: json['semester'] as String,
        characters:
            (json['characters'] as String).characters.toList(growable: false),
      );
}
