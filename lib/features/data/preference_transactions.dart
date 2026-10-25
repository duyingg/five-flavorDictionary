import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates read/modify/write operations between the app and floating view.
/// Stored values continue to use the existing SharedPreferences plugin format.
abstract final class PreferenceTransactions {
  static const _channel =
      MethodChannel('com.duyingg.fiveflavordictionary/preference_transactions');
  static final _changes = StreamController<String>.broadcast();
  static bool _listening = false;
  static Future<void> _localTail = Future<void>.value();

  static Stream<String> get changes {
    if (!_listening &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'changed' && call.arguments is String) {
          _changes.add(call.arguments as String);
        }
      });
    }
    return _changes.stream;
  }

  static Future<T> write<T>(String group,
      Future<T> Function(SharedPreferences preferences) operation) async {
    int? token;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        token = await _channel.invokeMethod<int>('acquire', group);
      } on MissingPluginException {
        // Non-Android hosts and existing mock preference backends use a local
        // queue. Android production engines always install the native bridge.
      }
    }
    Future<T> perform() async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.reload();
      return operation(preferences);
    }

    if (token == null) {
      final next = _localTail.then((_) => perform());
      _localTail =
          next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
      return next;
    }
    try {
      return await perform();
    } finally {
      await _channel.invokeMethod<void>('release', {'token': token});
    }
  }

  static Future<SharedPreferences> fresh() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return preferences;
  }
}
