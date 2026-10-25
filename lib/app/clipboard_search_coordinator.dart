import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/dictionary/single_han_validator.dart';
import 'app_routes.dart';
import 'router.dart';

/// Reads only while opted in and in the foreground. Android sends change
/// notifications without exposing clipboard contents through the event stream.
class ClipboardSearchCoordinator extends StatefulWidget {
  const ClipboardSearchCoordinator({
    required this.enabled,
    required this.child,
    this.router,
    this.readAnyPageOnChange = false,
    this.onQuery,
    super.key,
  });

  final bool enabled;
  final Widget child;
  final GoRouter? router;
  final bool readAnyPageOnChange;
  final ValueChanged<String>? onQuery;

  @override
  State<ClipboardSearchCoordinator> createState() =>
      _ClipboardSearchCoordinatorState();
}

class _ClipboardSearchCoordinatorState extends State<ClipboardSearchCoordinator>
    with WidgetsBindingObserver {
  static const _events =
      EventChannel('com.duyingg.fiveflavordictionary/clipboard');
  StreamSubscription<dynamic>? _subscription;
  Timer? _poll;
  String? _lastClipboard;
  bool _foreground = true;
  bool _windowFocused = true;
  bool _reading = false;
  bool _readAgain = false;
  bool _allowAnyPending = false;
  bool _resumeCheckPending = false;
  int _session = 0;

  bool get _active =>
      mounted && widget.enabled && _foreground && _windowFocused;
  GoRouter get _router => widget.router ?? appRouter;
  String get _path => _router.routerDelegate.currentConfiguration.uri.path;
  bool _isResult(String path) =>
      path.startsWith('/character/') || path.startsWith('/word/');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(covariant ClipboardSearchCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted && widget.enabled && _foreground) {
      _start(fromResume: true);
    } else {
      _stop();
    }
  }

  void _start({bool fromResume = false}) {
    if (!mounted || !widget.enabled || !_foreground) return;
    // Enabling the switch must not immediately navigate away from settings.
    _resumeCheckPending = fromResume || !AppRoutes.isSettingsPath(_path);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _subscription ??= _events.receiveBroadcastStream().listen(
        (event) {
          if (event == 'blur') {
            _windowFocused = false;
            _session++;
            _readAgain = false;
            _allowAnyPending = false;
            return;
          }
          // Android emits focus/change only for the window that has focus.
          _windowFocused = true;
          _requestRead(
              allowAnyPage: widget.readAnyPageOnChange ||
                  (event == 'focus' && _resumeCheckPending));
        },
        onError: (Object _) {
          _startPolling();
          _requestRead(allowAnyPage: _resumeCheckPending);
        },
      );
      // The native stream sends an initial focus event if the window is
      // already focused, otherwise onWindowFocusChanged will trigger the read.
      return;
    }
    _startPolling();
    final session = _session;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active && session == _session) {
        _requestRead(allowAnyPage: _resumeCheckPending);
      }
    });
  }

  void _startPolling() {
    if (!_active) return;
    // Fallback platforms have no native notification channel. The route guard
    // below limits periodic clipboard reads to dictionary result pages.
    _poll ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _requestRead(),
    );
  }

  void _stop() {
    _session++;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _poll?.cancel();
    _poll = null;
    _readAgain = false;
    _allowAnyPending = false;
    _resumeCheckPending = false;
  }

  void _requestRead({bool allowAnyPage = false}) {
    if (!_active || (!allowAnyPage && !_isResult(_path))) return;
    if (_reading) {
      _readAgain = true;
      _allowAnyPending |= allowAnyPage;
      return;
    }
    unawaited(_readClipboard(allowAnyPage: allowAnyPage));
  }

  Future<void> _readClipboard({required bool allowAnyPage}) async {
    _reading = true;
    final session = _session;
    final origin = _path;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!_active || session != _session) return;
      if (origin != _path) {
        _resumeCheckPending = false;
        return;
      }
      // Android may resume before the window has focus. Leave the pending
      // check armed when no data is accessible and retry on the focus event.
      if (data == null) {
        _lastClipboard = null;
        return;
      }
      _resumeCheckPending = false;
      final text = data.text?.trim() ?? '';
      if (text == _lastClipboard) return;
      _lastClipboard = text;
      final characters = text.characters.take(17).toList(growable: false);
      if (characters.isEmpty || characters.length > 16) return;
      if (characters.any(
        (value) => const SingleHanValidator().validate(value) is! ValidHan,
      )) {
        return;
      }
      if (!allowAnyPage && !_isResult(_path)) return;
      final destination = characters.length == 1
          ? AppRoutes.character(text)
          : AppRoutes.word(text);
      if (_router.routerDelegate.currentConfiguration.uri.toString() ==
          destination) {
        return;
      }
      widget.onQuery?.call(text);
      FocusManager.instance.primaryFocus?.unfocus();
      if (_isResult(_path)) {
        // A fresh page key also reloads stateful word details for the new word.
        unawaited(_router.pushReplacement<void>(destination));
      } else {
        unawaited(_router.push<void>(destination));
      }
    } on PlatformException {
      // Clipboard access can be denied by the OS; retry on a later event.
    } on MissingPluginException {
      // Unsupported platforms can continue to use manual search.
    } finally {
      _reading = false;
      if (_readAgain) {
        final allowAny = _allowAnyPending;
        _readAgain = false;
        _allowAnyPending = false;
        _requestRead(allowAnyPage: allowAny);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
