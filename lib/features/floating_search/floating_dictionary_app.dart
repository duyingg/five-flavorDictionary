import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/clipboard_search_coordinator.dart';
import '../../app/preference_sync_region.dart';
import '../../app/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/global_han_lookup.dart';
import 'floating_theme.dart';
import 'floating_detail_page.dart';
import '../dictionary/han_query.dart';
import '../domain/models.dart';
import 'floating_settings_snapshot.dart';

const _window = MethodChannel('com.duyingg.fiveflavordictionary/floating_view');

void runFloatingDictionary() {
  WidgetsFlutterBinding.ensureInitialized();
  final snapshot = ValueNotifier<FloatingWindowSnapshot?>(null);
  var newestVersion = -1;
  Future<void> configure(Map<Object?, Object?> payload) async {
    final version = (payload['version'] as num?)?.toInt() ?? 0;
    if (version <= newestVersion) return;
    newestVersion = version;
    final settings = await compute(
      FloatingSettingsSnapshot.decodeWindow,
      payload['configuration'] as String,
    );
    if (version == newestVersion) snapshot.value = settings;
  }

  _window.setMethodCallHandler((call) async {
    if (call.method == 'configure') {
      await configure(Map<Object?, Object?>.from(call.arguments as Map));
    }
  });
  runApp(ProviderScope(
    overrides: [
      settingsControllerProvider
          .overrideWith(() => _FloatingSettings(snapshot)),
    ],
    child: _FloatingDictionaryApp(snapshot: snapshot),
  ));
  unawaited(() async {
    try {
      final payload = await _window.invokeMapMethod<Object?, Object?>('ready');
      if (payload != null) await configure(payload);
    } catch (_) {
      await _window.invokeMethod<void>('failed');
    }
  }());
}

class _FloatingSettings extends SettingsController {
  _FloatingSettings(this.snapshot);
  final ValueNotifier<FloatingWindowSnapshot?> snapshot;

  // The display adapter cannot write to the main application's preference keys.
  @override
  Future<void> setSettings(AppSettings Function(AppSettings) change) =>
      Future.error(UnsupportedError('请在悬浮球设置页修改配置'));

  @override
  Future<AppSettings> build() async {
    void changed() {
      if (snapshot.value case final settings?) {
        state = AsyncData(settings.display);
      }
    }

    snapshot.addListener(changed);
    ref.onDispose(() => snapshot.removeListener(changed));
    return snapshot.value!.display;
  }
}

class _FloatingDictionaryApp extends StatefulWidget {
  const _FloatingDictionaryApp({required this.snapshot});
  final ValueNotifier<FloatingWindowSnapshot?> snapshot;

  @override
  State<_FloatingDictionaryApp> createState() => _FloatingDictionaryAppState();
}

class _FloatingDictionaryAppState extends State<_FloatingDictionaryApp> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _reportedFrame = false;
  late final _router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => ListView(
                primary: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: const [
                  SizedBox(
                      height: 180,
                      child: EmptyState(
                          title: '查询汉字或词语', message: '可在悬浮球设置中开启搜索框或剪切板自动搜索。'))
                ],
              )),
      GoRoute(
          path: AppRoutes.characterPattern,
          pageBuilder: (_, state) => MaterialPage<void>(
                key: ValueKey('character:${state.pathParameters['value']}'),
                child:
                    FloatingDetailPage(value: state.pathParameters['value']!),
              )),
      GoRoute(
          path: AppRoutes.wordPattern,
          pageBuilder: (_, state) => MaterialPage<void>(
                key: ValueKey('word:${state.pathParameters['value']}'),
                child:
                    FloatingDetailPage(value: state.pathParameters['value']!),
              )),
    ],
  );

  void _command(String name, [Object? args]) {
    unawaited(_window.invokeMethod<void>(name, args).catchError((Object _) {}));
  }

  void _search() {
    final value = HanQuery.parse(_query.text);
    if (value == null) {
      setState(() => _error = '请输入 1—16 个连续汉字');
      _focus.requestFocus();
      return;
    }
    setState(() => _error = null);
    _focus.unfocus();
    _router.go(value.isCharacter
        ? AppRoutes.character(value.value)
        : AppRoutes.word(value.value));
  }

  void _openInApp() {
    final route = _router.routerDelegate.currentConfiguration.uri;
    final segments = route.pathSegments;
    if (segments.length == 2 &&
        (segments.first == 'character' || segments.first == 'word')) {
      _command('openApp', segments.last);
    } else if (HanQuery.parse(_query.text) case final value?) {
      _command('openApp', value.value);
    }
  }

  Widget _buildSearchField() => Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: TextField(
          controller: _query,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '汉字或词语',
            errorText: _error,
            prefixIcon: IconButton(
                tooltip: '查询',
                onPressed: _search,
                icon: const Icon(Icons.search)),
            suffixIcon: _query.text.isEmpty
                ? null
                : IconButton(
                    tooltip: '清空',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _query.clear();
                      setState(() => _error = null);
                    },
                  ),
          ),
        ),
      ));

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<FloatingWindowSnapshot?>(
        valueListenable: widget.snapshot,
        builder: (_, configuration, __) {
          if (configuration == null) return const SizedBox.shrink();
          final settings = configuration.display;
          if (!_reportedFrame) {
            _reportedFrame = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _command('rendered'));
          }
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: FloatingTheme.build(settings),
            routerConfig: _router,
            builder: (context, child) => Directionality(
              textDirection:
                  settings.leftHanded ? TextDirection.rtl : TextDirection.ltr,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.fontScale.factor),
                ),
                child: PreferenceSyncRegion(
                  child: FloatingSkinBackdrop(
                      child: Column(children: [
                    Material(
                      color: Theme.of(context).appBarTheme.backgroundColor,
                      child: Row(children: [
                        Expanded(
                            child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (_) => _command('startMoveWindow'),
                          onPanEnd: (_) => _command('endMoveWindow'),
                          onPanCancel: () => _command('endMoveWindow'),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                                start: 14, top: 14, bottom: 14),
                            child: Row(children: [
                              const Icon(Icons.drag_indicator, size: 20),
                              const SizedBox(width: 4),
                              Flexible(
                                  child: Text('悬浮查询',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                            ]),
                          ),
                        )),
                        IconButton(
                            tooltip: '在应用中查看',
                            onPressed: _openInApp,
                            icon: const Icon(Icons.open_in_new)),
                        IconButton(
                            tooltip: '收起',
                            onPressed: () => _command('collapse'),
                            icon: const Icon(Icons.expand_more)),
                      ]),
                    ),
                    Expanded(
                        child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                        if (configuration.showSearchBox)
                          SliverToBoxAdapter(child: _buildSearchField()),
                      ],
                      body: ClipRect(
                          child: GlobalHanLookupRegion(
                        enabled: settings.globalHanLookupEnabled,
                        onCharacter: (value) =>
                            _router.push(AppRoutes.character(value)),
                        child: ClipboardSearchCoordinator(
                          enabled: settings.clipboardSearchEnabled,
                          router: _router,
                          readAnyPageOnChange: true,
                          onQuery: (text) {
                            _command('clipboardQueried', text);
                            _query.text = text;
                            setState(() => _error = null);
                          },
                          child: child!,
                        ),
                      )),
                    )),
                  ])),
                ),
              ),
            ),
          );
        },
      );

  @override
  void dispose() {
    _router.dispose();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }
}
