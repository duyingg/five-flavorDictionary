import 'dart:async';

import 'package:characters/characters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/data/repositories.dart';
import '../features/data/poetry_binary_codec.dart';
import '../features/domain/models.dart';

final dictionaryRepositoryProvider =
    Provider<DictionaryRepository>((ref) => AssetDictionaryRepository());
final wordRepositoryProvider =
    Provider<WordRepository>((ref) => AssetWordRepository());
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
  var _revision = 0;

  @override
  Future<Set<String>> build() =>
      ref.read(preferencesStoreProvider).loadFavorites();

  Future<void> toggle(String value) async {
    final previous = state.valueOrNull ?? const <String>{};
    final next = {...?state.valueOrNull};
    next.contains(value) ? next.remove(value) : next.add(value);
    final revision = ++_revision;
    state = AsyncData(next);
    try {
      await _writes.add(
        () => ref.read(preferencesStoreProvider).saveFavorites(next),
      );
    } catch (error, stack) {
      if (revision == _revision) state = AsyncData(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> clear() async {
    final previous = state.valueOrNull ?? const <String>{};
    final revision = ++_revision;
    state = const AsyncData({});
    try {
      await _writes.add(
        () => ref.read(preferencesStoreProvider).saveFavorites({}),
      );
    } catch (error, stack) {
      if (revision == _revision) state = AsyncData(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }
}

final favoritesControllerProvider =
    AsyncNotifierProvider<FavoritesController, Set<String>>(
        FavoritesController.new);

class SearchHistoryController extends AsyncNotifier<List<String>> {
  final _writes = _WriteQueue();
  var _revision = 0;

  @override
  Future<List<String>> build() =>
      ref.read(preferencesStoreProvider).loadSearchHistory();

  Future<void> add(String character) async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (!settings.keepSearchHistory) return;
    final next = [
      character,
      for (final value in state.valueOrNull ?? const <String>[])
        if (value != character) value,
    ].take(100).toList(growable: false);
    final revision = ++_revision;
    final previous = state.valueOrNull ?? const <String>[];
    state = AsyncData(next);
    try {
      await _writes.add(
        () => ref.read(preferencesStoreProvider).saveSearchHistory(next),
      );
    } catch (error, stack) {
      if (revision == _revision) state = AsyncData(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> clear() async {
    final previous = state.valueOrNull ?? const <String>[];
    final revision = ++_revision;
    state = const AsyncData([]);
    try {
      await _writes.add(
        () => ref.read(preferencesStoreProvider).saveSearchHistory(const []),
      );
    } catch (error, stack) {
      if (revision == _revision) state = AsyncData(previous);
      Error.throwWithStackTrace(error, stack);
    }
  }
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
  final entries = await ref.read(dictionaryRepositoryProvider).all();
  return ref.read(dailyContentServiceProvider).selectCharacters(entries, day);
});

final dailyContentProvider = FutureProvider<DailyContent?>((ref) async {
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
  final day = ref.watch(currentDayProvider);
  final items = await ref
      .read(dailyContentRepositoryProvider)
      .getByType(settings.dailyContentType);
  return ref
      .read(dailyContentServiceProvider)
      .select(items, day, settings.dailyContentType, reroll);
});

final dailyPoetryTargetProvider =
    FutureProvider.autoDispose.family<PoetryItem?, DailyContent>(
  (ref, item) async {
    if (item.type != DailyContentType.verse) return null;
    final catalog = await ref.read(poetryRepositoryProvider).catalog();
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
