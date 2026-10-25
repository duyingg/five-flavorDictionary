import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../domain/models.dart';
import 'floating_settings_snapshot.dart';

/// Stores overlay-specific choices; shared display options are resolved at sync.
class FloatingPreferences {
  static const defaultsRevision = 2;
  static const defaultDisplay = AppSettings(
    showPinyin: true,
    showRadical: true,
    showZhuyin: false,
    showWubi: false,
    showStrokeCount: false,
    showStructure: false,
    showUnicode: false,
    showStrokeOrder: false,
    showScriptRelations: false,
    showCharacterLevel: false,
    showFavorites: false,
  );

  static AppSettings compactDisplay(AppSettings display) => display.copyWith(
        showPinyin: true,
        showRadical: true,
        showZhuyin: false,
        showWubi: false,
        showStrokeCount: false,
        showStructure: false,
        showUnicode: false,
        showStrokeOrder: false,
        showScriptRelations: false,
        showCharacterLevel: false,
        showFavorites: false,
      );

  const FloatingPreferences(
      {this.enabled = false,
      this.showSearchBox = true,
      this.opacity = 1,
      this.windowWidth = 1,
      this.windowHeight = .4,
      this.display = defaultDisplay});
  final bool enabled;
  final bool showSearchBox;
  final double opacity;
  final double windowWidth;
  final double windowHeight;
  final AppSettings display;

  FloatingPreferences copyWith(
          {bool? enabled,
          bool? showSearchBox,
          double? opacity,
          double? windowWidth,
          double? windowHeight,
          AppSettings? display}) =>
      FloatingPreferences(
          enabled: enabled ?? this.enabled,
          showSearchBox: showSearchBox ?? this.showSearchBox,
          opacity: (opacity ?? this.opacity).clamp(.2, 1),
          windowWidth: (windowWidth ?? this.windowWidth).clamp(.6, 1),
          windowHeight: (windowHeight ?? this.windowHeight).clamp(.35, .95),
          display: display ?? this.display);

  String encode() => jsonEncode({
        'defaultsRevision': defaultsRevision,
        'enabled': enabled,
        'showSearchBox': showSearchBox,
        'opacity': opacity,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'display': FloatingSettingsSnapshot.encode(display.copyWith(
            skin: AppSkin.parchment,
            clearImportedSkin: true,
            importedSkins: const []))
      });
  factory FloatingPreferences.decode(String text) =>
      FloatingPreferences.fromJson(jsonDecode(text) as Map<String, dynamic>);

  factory FloatingPreferences.fromJson(Map<String, dynamic> json) {
    final legacy = (json['defaultsRevision'] as int? ?? 1) < defaultsRevision;
    var display = FloatingSettingsSnapshot.decode(json['display'] as String);
    final oldFullDisplay = display.showPinyin &&
        display.showRadical &&
        display.showZhuyin &&
        display.showWubi &&
        display.showStrokeCount &&
        display.showStructure &&
        display.showUnicode &&
        display.showStrokeOrder &&
        display.showScriptRelations &&
        display.showCharacterLevel &&
        display.showFavorites;
    if (legacy && oldFullDisplay) display = compactDisplay(display);
    var width = (json['windowWidth'] as num?)?.toDouble() ?? 1;
    var height = (json['windowHeight'] as num?)?.toDouble() ?? .4;
    if (legacy && (width - .95).abs() < .0001) width = 1;
    if (legacy && (height - .78).abs() < .0001) height = .4;
    return FloatingPreferences(
        enabled: json['enabled'] as bool? ?? false,
        showSearchBox: json['showSearchBox'] as bool? ?? true,
        opacity: ((json['opacity'] as num?)?.toDouble() ?? 1).clamp(.2, 1),
        windowWidth: width.clamp(.6, 1),
        windowHeight: height.clamp(.35, .95),
        display: display);
  }
}

final floatingPreferencesProvider =
    AsyncNotifierProvider<FloatingPreferencesController, FloatingPreferences>(
        FloatingPreferencesController.new);

class FloatingPreferencesController extends AsyncNotifier<FloatingPreferences> {
  static const storageKey = 'v3.floating.preferences';
  Future<void> _tail = Future.value();

  @override
  Future<FloatingPreferences> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(storageKey);
    if (stored != null) {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      final decoded = FloatingPreferences.fromJson(json);
      final revision = json['defaultsRevision'] as int? ?? 1;
      if (revision < FloatingPreferences.defaultsRevision &&
          !await prefs.setString(storageKey, decoded.encode())) {
        throw StateError('无法更新悬浮窗默认设置');
      }
      return decoded;
    }
    // One-time migration preserves the user's existing overlay appearance.
    // No dependency is watched, so global changes cannot modify this value.
    final previous = await ref.read(settingsControllerProvider.future);
    final migrated = FloatingPreferences(
        enabled: previous.experimentalFeaturesEnabled &&
            previous.floatingSearchEnabled,
        display: FloatingPreferences.compactDisplay(previous).copyWith(
            experimentalFeaturesEnabled: false,
            leftHanded:
                previous.experimentalFeaturesEnabled && previous.leftHanded,
            clipboardSearchEnabled: false,
            floatingSearchEnabled: false));
    if (!await prefs.setString(storageKey, migrated.encode())) {
      throw StateError('无法保存悬浮球设置');
    }
    return migrated;
  }

  Future<void> setPreferences(
      FloatingPreferences Function(FloatingPreferences) change) {
    final operation = _tail.then((_) async {
      final previous = await future;
      final next = change(previous);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(storageKey, next.encode())) {
        throw StateError('无法保存悬浮球设置');
      }
      state = AsyncData(next);
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> setDisplay(AppSettings Function(AppSettings) change) =>
      setPreferences((s) => s.copyWith(display: change(s.display)));
}
