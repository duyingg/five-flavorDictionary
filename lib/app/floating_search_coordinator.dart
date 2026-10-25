import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/dictionary/han_query.dart';
import '../features/floating_search/floating_preferences.dart';
import '../features/floating_search/floating_search_platform.dart';
import '../features/domain/models.dart';
import 'providers.dart';
import 'app_routes.dart';
import 'router.dart';

class FloatingSearchCoordinator extends ConsumerStatefulWidget {
  const FloatingSearchCoordinator({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<FloatingSearchCoordinator> createState() =>
      _FloatingSearchCoordinatorState();
}

class _FloatingSearchCoordinatorState
    extends ConsumerState<FloatingSearchCoordinator>
    with WidgetsBindingObserver {
  ProviderSubscription<AsyncValue<FloatingPreferences>>? _settings;
  ProviderSubscription<AsyncValue<AppSettings>>? _globalSettings;
  bool _foreground = false;
  bool _syncing = false;
  bool _pending = false;

  bool get _active => mounted && _foreground;

  @override
  void initState() {
    super.initState();
    if (!FloatingSearchPlatform.supported) return;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    FloatingSearchPlatform.channel.setMethodCallHandler((call) async {
      if (call.method == 'stopped') {
        final arguments = call.arguments;
        final message = arguments is Map ? arguments['message'] : null;
        await _disable();
        if (message is String && message.isNotEmpty) _message(message);
      } else if (call.method == 'launchAvailable') {
        _scheduleSync();
      }
    });
    _globalSettings =
        ref.listenManual(settingsControllerProvider, (previous, next) {
      if (_sharedDisplayKey(previous?.valueOrNull) !=
          _sharedDisplayKey(next.valueOrNull)) {
        _scheduleSync();
      }
    }, fireImmediately: true);
    _settings = ref.listenManual(floatingPreferencesProvider, (_, next) {
      if (next.hasValue) _scheduleSync();
    }, fireImmediately: true);
  }

  // Only shared options trigger synchronization; local display options remain
  // independent. Effective left-handed mode follows the global master switch.
  Object? _sharedDisplayKey(AppSettings? settings) => settings == null
      ? null
      : (
          settings.skin,
          settings.importedSkin,
          settings.scriptDisplay,
          settings.keepSearchHistory,
          settings.experimentalFeaturesEnabled && settings.leftHanded,
          settings.reduceDecoration,
        );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _scheduleSync();
  }

  void _scheduleSync() {
    if (!_active) return;
    _pending = true;
    if (_syncing) return;
    _syncing = true;
    // Start after the current build/frame. Changes while a platform request is
    // outstanding are coalesced and the newest settings are sent next.
    unawaited(Future<void>(_sync));
  }

  Future<void> _sync() async {
    try {
      while (_active && _pending) {
        _pending = false;
        final settings = ref.read(floatingPreferencesProvider).valueOrNull;
        final globalSettings = ref.read(settingsControllerProvider).valueOrNull;
        if (settings == null || globalSettings == null) return;
        final state = await FloatingSearchPlatform.sync(settings,
            globalSettings: globalSettings);
        if (!_active) return;
        if (!identical(
            settings, ref.read(floatingPreferencesProvider).valueOrNull)) {
          _pending = true;
          continue;
        }
        if (settings.enabled &&
            (state['permissionGranted'] != true ||
                state['dismissed'] == true)) {
          await _disable();
          final message = state['message'];
          if (message is String && message.isNotEmpty) _message(message);
        }
        await _consumeLaunch();
      }
    } on PlatformException catch (error) {
      if (mounted) {
        await _disable();
        _message(error.message ?? '悬浮查询暂不可用，请重新开启');
      }
    } on MissingPluginException {
      if (mounted) await _disable();
    } catch (_) {
      if (mounted) _message('悬浮查询设置同步失败，请重新开启');
    } finally {
      _syncing = false;
      if (_active && _pending) _scheduleSync();
    }
  }

  Future<void> _disable() async {
    if (!mounted ||
        ref.read(floatingPreferencesProvider).valueOrNull?.enabled != true) {
      return;
    }
    await ref.read(floatingPreferencesProvider.notifier).setPreferences(
          (s) => s.copyWith(enabled: false),
        );
  }

  Future<void> _consumeLaunch() async {
    final launch = await FloatingSearchPlatform.channel
        .invokeMapMethod<Object?, Object?>('getLaunch');
    if (!_active || launch == null) return;
    if (launch['settings'] == true) {
      if (appRouter.routerDelegate.currentConfiguration.uri.path !=
          AppRoutes.settingsFloating) {
        unawaited(appRouter.push<void>(AppRoutes.settingsFloating));
      }
      await _ackLaunch(launch);
      return;
    }
    if (launch['query'] == null) return;
    final settings = ref.read(floatingPreferencesProvider).valueOrNull;
    if (settings?.enabled != true) {
      await _ackLaunch(launch);
      return;
    }
    final query = HanQuery.parse(launch['query'] as String? ?? '');
    if (query == null) {
      await _ackLaunch(launch);
      return;
    }
    final destination = query.isCharacter
        ? AppRoutes.character(query.value)
        : AppRoutes.word(query.value);
    final current = appRouter.routerDelegate.currentConfiguration.uri;
    if (current.toString() == destination) {
      await _ackLaunch(launch);
      return;
    }
    if (current.path.startsWith('/character/') ||
        current.path.startsWith('/word/')) {
      unawaited(appRouter.pushReplacement<void>(destination));
    } else {
      unawaited(appRouter.push<void>(destination));
    }
    await _ackLaunch(launch);
  }

  Future<void> _ackLaunch(Map<Object?, Object?> launch) =>
      FloatingSearchPlatform.channel.invokeMethod<void>('ackLaunch', {
        'id': launch['id'],
      });

  void _message(String text) {
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  void dispose() {
    _settings?.close();
    _globalSettings?.close();
    if (FloatingSearchPlatform.supported) {
      WidgetsBinding.instance.removeObserver(this);
      FloatingSearchPlatform.channel.setMethodCallHandler(null);
    }
    // The explicitly enabled native service remains available over other apps.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
