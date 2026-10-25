import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/language/pinyin_utils.dart';
import '../features/data/repositories.dart';
import '../features/data/poetry_binary_codec.dart';
import '../features/domain/models.dart';
import '../features/domain/character_visibility.dart';

final dictionaryRepositoryProvider =
    Provider<DictionaryRepository>((ref) => AssetDictionaryRepository());
final contextualPinyinRepositoryProvider =
    Provider((ref) => ContextualPinyinRepository());
final assetWordRepositoryProvider = Provider((ref) => AssetWordRepository());
final wordRepositoryProvider =
    Provider<WordRepository>((ref) => ref.read(assetWordRepositoryProvider));
final dailyWordRepositoryProvider = Provider<DailyWordRepository>(
    (ref) => ref.read(assetWordRepositoryProvider));
final dailyContentRepositoryProvider =
    Provider<DailyContentRepository>((ref) => AssetDailyContentRepository());
final cultureRepositoryProvider =
    Provider<CultureRepository>((ref) => AssetCultureRepository());
final poetryRepositoryProvider =
    Provider<PoetryRepository>((ref) => AssetPoetryRepository());
final hanScriptConverterProvider =
    FutureProvider<HanScriptConverter>((ref) => HanScriptConverter.load());
final polyphonicLearningRepositoryProvider =
    Provider((ref) => PolyphonicLearningRepository());
final polyphonicLessonsProvider = FutureProvider<List<PolyphonicLesson>>(
  (ref) => ref.read(polyphonicLearningRepositoryProvider).all(),
);
final primaryPinyinProvider =
    FutureProvider.autoDispose.family<Map<String, String>, String>(
  (ref, text) =>
      ref.read(dictionaryRepositoryProvider).primaryPinyinFor(text.characters),
);
final contextualPinyinProvider =
    FutureProvider.autoDispose.family<List<String>, String>(
  (ref, text) => ref.read(contextualPinyinRepositoryProvider).resolve(
        text,
        ref.read(dictionaryRepositoryProvider),
      ),
);
final polyphonicChallengeLevelProvider = StateProvider<int>((ref) => 0);
final polyphonicEndlessCorrectProvider = StateProvider<int>((ref) => 0);
final preferencesStoreProvider = Provider((ref) => PreferencesStore());
final dailyContentServiceProvider =
    Provider((ref) => const DailyContentService());
final dailyRerollProvider = StateProvider<int>((ref) => 0);
final cultureDisplayModeProvider =
    StateProvider<Set<CultureDisplayMode>>((ref) => <CultureDisplayMode>{});

final currentDayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(tomorrow.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return day;
});

class _WriteQueue {
  Future<void> _tail = Future<void>.value();

  Future<void> add(Future<void> Function() write) {
    final operation = _tail.then((_) => write());
    _tail = operation.catchError((Object _, StackTrace __) {});
    return operation;
  }
}

class SettingsController extends AsyncNotifier<AppSettings> {
  final _writes = _WriteQueue();
  var _revision = 0;

  @override
  Future<AppSettings> build() =>
      ref.read(preferencesStoreProvider).loadSettings();

  Future<void> setSettings(AppSettings Function(AppSettings) change) async {
    final previous = state.valueOrNull ?? const AppSettings();
    final next = change(previous);
    if (identical(next, previous)) return;
    final revision = ++_revision;
    state = AsyncData(next);
    try {
      await _writes.add(
        () => ref.read(preferencesStoreProvider).saveSettings(next),
      );
      ref.read(dailyRerollProvider.notifier).state = 0;
    } catch (error, stack) {
      if (revision == _revision) {
        state = AsyncError(error, stack);
        state = AsyncData(previous);
      }
      rethrow;
    }
  }

  Future<void> reset() => setSettings(
        (current) => AppSettings(importedSkins: current.importedSkins),
      );
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

class FavoritesController extends AsyncNotifier<Set<String>> {
  final _writes = _WriteQueue();

  @override
  Future<Set<String>> build() =>
      ref.read(preferencesStoreProvider).loadFavorites();

  Future<void> toggle(String value) => _writes.add(() async {
        await ref.read(favoritesControllerProvider.future);
        final next =
            await ref.read(preferencesStoreProvider).toggleFavorite(value);
        state = AsyncData(next);
      });

  Future<void> clear() => _writes.add(() async {
        await ref.read(favoritesControllerProvider.future);
        await ref.read(preferencesStoreProvider).saveFavorites({});
        state = const AsyncData({});
      });

  Future<void> refreshFromStorage() => _writes.add(() async {
        await ref.read(favoritesControllerProvider.future);
        state =
            AsyncData(await ref.read(preferencesStoreProvider).loadFavorites());
      });
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, Set<String>>(
        FavoritesController.new);

class SearchHistoryController extends AsyncNotifier<List<String>> {
  final _writes = _WriteQueue();

  @override
  Future<List<String>> build() =>
      ref.read(preferencesStoreProvider).loadSearchHistory();

  Future<void> add(String character) => _writes.add(() async {
        await ref.read(searchHistoryControllerProvider.future);
        final settings = await ref.read(settingsControllerProvider.future);
        if (!settings.keepSearchHistory) return;
        state = AsyncData(await ref
            .read(preferencesStoreProvider)
            .addSearchHistory(character));
      });

  Future<void> clear() => _writes.add(() async {
        await ref.read(searchHistoryControllerProvider.future);
        await ref.read(preferencesStoreProvider).saveSearchHistory(const []);
        state = const AsyncData([]);
      });

  Future<void> refreshFromStorage() => _writes.add(() async {
        await ref.read(searchHistoryControllerProvider.future);
        state = AsyncData(
            await ref.read(preferencesStoreProvider).loadSearchHistory());
      });
}

final searchHistoryControllerProvider =
    AsyncNotifierProvider<SearchHistoryController, List<String>>(
  SearchHistoryController.new,
);

class SentenceNotesController extends AsyncNotifier<List<SentenceNote>> {
  final _writes = _WriteQueue();
  var _revision = 0;

  @override
  Future<List<SentenceNote>> build() =>
      ref.read(preferencesStoreProvider).loadSentenceNotes();

  Future<void> add(String character, String content) async {
    final now = DateTime.now();
    final previous = state.valueOrNull ?? const <SentenceNote>[];
    final next = [
      SentenceNote(
        id: now.microsecondsSinceEpoch.toString(),
        character: character,
        content: content,
        createdAt: now,
      ),
      ...previous,
    ];
    await _save(previous, next);
  }

  Future<void> removeAll(Set<String> ids) async {
    if (ids.isEmpty) return;
    final previous = state.valueOrNull ?? const <SentenceNote>[];
    final next = [
      for (final note in previous)
        if (!ids.contains(note.id)) note,
    ];
    await _save(previous, next);
  }

  Future<void> _save(
    List<SentenceNote> previous,
    List<SentenceNote> next,
  ) async {
    final revision = ++_revision;
    state = AsyncData(next);
    try {
      await _writes.add(
        () => ref.read(preferencesStoreProvider).saveSentenceNotes(next),
      );
    } catch (error, stack) {
      if (revision == _revision) state = AsyncData(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }
}

final sentenceNotesControllerProvider =
    AsyncNotifierProvider<SentenceNotesController, List<SentenceNote>>(
  SentenceNotesController.new,
);

final todayCharactersProvider = FutureProvider<List<ChineseEntry>>((ref) async {
  final day = ref.watch(currentDayProvider);
  final settings = await ref.watch(settingsControllerProvider.future);
  final entries = await ref.read(dictionaryRepositoryProvider).all();
  return ref.read(dailyContentServiceProvider).selectCharacters(
        entries
            .where((entry) => entry.isVisibleFor(
                  display: settings.scriptDisplay,
                  maxLevel: 3,
                ))
            .toList(growable: false),
        day,
      );
});

final dailyContentProvider = FutureProvider<DailyContent?>((ref) async {
  final day = ref.watch(currentDayProvider);
  final settings = await ref.watch(settingsControllerProvider.future);
  final reroll = ref.watch(dailyRerollProvider);
  if (settings.dailyContentType == DailyContentType.character) {
    final characters = await ref.watch(todayCharactersProvider.future);
    if (characters.isEmpty) return null;
    final entry = characters[reroll % characters.length];
    return DailyContent(
      id: 'daily-character-${entry.character}',
      type: DailyContentType.character,
      title: entry.character,
      summary: entry.senses.isEmpty
          ? '${entry.strokeCount} 画 · ${entry.radical}部'
          : entry.senses.first.definition,
      pronunciation: entry.pinyin.join(' · '),
      sourceId: entry.sourceId,
    );
  }
  if (settings.dailyContentType == DailyContentType.word ||
      settings.dailyContentType == DailyContentType.idiom) {
    final type = settings.dailyContentType;
    final catalog = await ref.read(dailyWordRepositoryProvider).dailyCatalog();
    final count = catalog.count(type);
    if (count == 0) return null;
    final position = ref
        .read(dailyContentServiceProvider)
        .selectIndex(count, day, type, reroll);
    final entry = catalog.entryAt(type, position);
    return DailyContent(
      id: '${type.name}:${entry.word}',
      type: type,
      title: entry.word,
      summary: entry.definition,
      pronunciation: entry.pinyin,
      sourceId: 'chinese-dictionary',
    );
  }
  final items = await ref
      .read(dailyContentRepositoryProvider)
      .getByType(settings.dailyContentType);
  if (items.isEmpty) return null;
  final position = ref.read(dailyContentServiceProvider).selectIndex(
        items.length,
        day,
        settings.dailyContentType,
        reroll,
      );
  return items[position];
});

final dailyPoetryTargetProvider =
    FutureProvider.autoDispose.family<PoetryItem?, DailyContent>(
  (ref, item) async {
    if (item.type != DailyContentType.verse) return null;
    final catalog = await ref.read(poetryRepositoryProvider).catalog();
    // Generated daily cards retain the exact catalog ID. Legacy curated cards
    // still use the text/author lookup below.
    if (item.id.startsWith('poetry-')) {
      return catalog.findById(item.id);
    }
    final converter = await ref.read(hanScriptConverterProvider.future);
    final firstClause = item.title.split(RegExp(r'[，。！？；,.!?;]')).first;
    final query = converter
        .toSimplified(firstClause)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '');
    final selection = await catalog.selectAsync(
      PoetryQuery(
        text: query,
        order: PoetryOrder.ascending,
      ),
    );
    if (selection == null || selection.length == 0) return null;
    PoetryItem? authorMatch;
    for (var index = 0; index < selection.length; index++) {
      final candidate = selection.itemAt(index);
      final sameAuthor = converter.toSimplified(candidate.author) ==
          converter.toSimplified(item.author ?? '');
      if (sameAuthor) authorMatch ??= candidate;
      if (sameAuthor &&
          converter.toSimplified(candidate.title) ==
              converter.toSimplified(item.sourceTitle ?? '')) {
        return candidate;
      }
    }
    return authorMatch ?? selection.itemAt(0);
  },
);

final cultureItemsProvider =
    FutureProvider.family<List<CultureItem>, CultureCategory>(
  (ref, category) =>
      ref.read(cultureRepositoryProvider).getByCategory(category),
);

final sortedClassicsProvider = FutureProvider<List<CultureItem>>((ref) async {
  final items =
      await ref.watch(cultureItemsProvider(CultureCategory.classics).future);
  final titles = items.map((item) => item.title).toList();
  final readings =
      await ref.read(dictionaryRepositoryProvider).primaryPinyinFor(
            titles.expand((title) => title.characters),
          );
  String key(String title) => title.characters
      .map((character) =>
          PinyinUtils.normalize(readings[character] ?? character))
      .join(' ');
  return [...items]..sort((left, right) {
      final order = key(left.title).compareTo(key(right.title));
      return order != 0 ? order : left.title.compareTo(right.title);
    });
});
