import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/culture/culture_pages.dart';
import '../features/culture/poetry_author_page.dart';
import '../features/dictionary/dictionary_pages.dart';
import '../features/dictionary/word_detail_page.dart';
import '../features/home/home_page.dart';
import '../features/index_search/index_search_page.dart';
import '../features/learning/learning_pages.dart';
import '../features/profile/profile_pages.dart';
import '../core/widgets/global_han_lookup.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: AppRoutes.home, builder: (_, __) => const HomePage())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: AppRoutes.learning,
              builder: (_, __) => const LearningPage())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: AppRoutes.culture, builder: (_, __) => const CulturePage())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: AppRoutes.profile, builder: (_, __) => const ProfilePage())
        ]),
      ],
    ),
    GoRoute(
        path: AppRoutes.characterPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            CharacterDetailPage(value: state.pathParameters['value']!)),
    GoRoute(
        path: AppRoutes.wordPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            WordDetailPage(value: state.pathParameters['value']!)),
    GoRoute(
        path: AppRoutes.indexPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => IndexSearchPage(
            type:
                IndexSearchType.values.byName(state.pathParameters['type']!))),
    GoRoute(
        path: AppRoutes.learningToday,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const TodayCharacterPage()),
    GoRoute(
        path: AppRoutes.learningFavorites,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const FavoritesPage()),
    GoRoute(
        path: AppRoutes.learningGuess,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const GuessCharacterPage()),
    GoRoute(
        path: AppRoutes.learningSentence,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SentencePage()),
    GoRoute(
        path: AppRoutes.learningPolyphonic,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const PolyphonicLearningPage()),
    GoRoute(
        path: AppRoutes.cultureDetailPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            CultureDetailPage(id: state.pathParameters['id']!)),
    GoRoute(
        path: AppRoutes.poetryDetailPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            PoetryDetailPage(id: state.pathParameters['id']!)),
    GoRoute(
        path: AppRoutes.poetryAuthorPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => PoetryAuthorPage(
              dynasty: state.pathParameters['dynasty']!,
              author: state.pathParameters['author']!,
            )),
    GoRoute(
        path: AppRoutes.solarTermPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            SolarTermDetailPage(name: state.pathParameters['name']!)),
    GoRoute(
        path: AppRoutes.settingsPattern,
        parentNavigatorKey: rootNavigatorKey,
        redirect: (_, state) => state.pathParameters['kind'] == 'display'
            ? AppRoutes.settingsGeneral
            : null,
        builder: (_, state) => GlobalHanLookupBlocker(
              child: SettingsPage(kind: state.pathParameters['kind']!),
            )),
    GoRoute(
        path: AppRoutes.informationPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) =>
            InformationPage(kind: state.pathParameters['kind']!)),
    GoRoute(
        path: AppRoutes.history,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, __) => const SearchHistoryPage()),
  ],
  errorBuilder: (_, __) => const Scaffold(body: Center(child: Text('页面不存在'))),
);
