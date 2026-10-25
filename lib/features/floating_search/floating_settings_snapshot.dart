import 'dart:convert';

import '../domain/models.dart';

/// Serializes resolved local and global display options, including the active skin.
/// The floating engine never opens the main engine's Hive skin box.
typedef FloatingWindowSnapshot = ({AppSettings display, bool showSearchBox});

abstract final class FloatingSettingsSnapshot {
  static ImportedSkin? _encodedSkin;
  static String _skinJson = 'null';

  static String encode(AppSettings s, {bool showSearchBox = true}) {
    var skinJson = 'null';
    if (s.importedSkin case final skin?) {
      if (!identical(_encodedSkin, skin)) {
        _encodedSkin = skin;
        _skinJson = jsonEncode(skin.toJson());
      }
      skinJson = _skinJson;
    }
    final fields = jsonEncode({
      'showSearchBox': showSearchBox,
      'dailyContentType': s.dailyContentType.name,
      'fontScale': s.fontScale.name,
      'keepSearchHistory': s.keepSearchHistory,
      'experimentalFeaturesEnabled': s.experimentalFeaturesEnabled,
      'clipboardSearchEnabled': s.clipboardSearchEnabled,
      'floatingSearchEnabled': s.floatingSearchEnabled,
      'leftHanded': s.leftHanded,
      'reduceDecoration': s.reduceDecoration,
      'fullPoetryLibrary': s.fullPoetryLibrary,
      'globalHanLookupEnabled': s.globalHanLookupEnabled,
      'scriptDisplay': s.scriptDisplay.name,
      'maxCharacterLevel': s.maxCharacterLevel,
      'skin': s.skin.name,
      'sidebarWidth': s.sidebarWidth,
      'showPinyin': s.showPinyin,
      'showZhuyin': s.showZhuyin,
      'showWubi': s.showWubi,
      'showRadical': s.showRadical,
      'showStrokeCount': s.showStrokeCount,
      'showStructure': s.showStructure,
      'showUnicode': s.showUnicode,
      'showScriptRelations': s.showScriptRelations,
      'showCharacterLevel': s.showCharacterLevel,
      'showFavorites': s.showFavorites,
      'showParagraphNumbers': s.showParagraphNumbers,
      'showAnnotationMarkers': s.showAnnotationMarkers,
      'showStrokeOrder': s.showStrokeOrder,
    });
    return '${fields.substring(0, fields.length - 1)},"importedSkin":$skinJson}';
  }

  static AppSettings decode(String source) =>
      _decodeSettings(jsonDecode(source) as Map<String, dynamic>);

  static FloatingWindowSnapshot decodeWindow(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return (
      display: _decodeSettings(json),
      showSearchBox: json['showSearchBox'] as bool? ?? true
    );
  }

  static AppSettings _decodeSettings(Map<String, dynamic> json) {
    T enumeration<T extends Enum>(String key, List<T> values, T fallback) =>
        values.where((v) => v.name == json[key]).firstOrNull ?? fallback;
    final skinJson = json['importedSkin'];
    final imported = skinJson is Map
        ? ImportedSkin.fromJson(Map<String, dynamic>.from(skinJson))
        : null;
    return AppSettings(
      dailyContentType: enumeration('dailyContentType', DailyContentType.values,
          DailyContentType.character),
      fontScale:
          enumeration('fontScale', AppFontScale.values, AppFontScale.standard),
      keepSearchHistory: json['keepSearchHistory'] as bool? ?? true,
      experimentalFeaturesEnabled:
          json['experimentalFeaturesEnabled'] as bool? ?? false,
      clipboardSearchEnabled: json['clipboardSearchEnabled'] as bool? ?? false,
      floatingSearchEnabled: json['floatingSearchEnabled'] as bool? ?? false,
      leftHanded: json['leftHanded'] as bool? ?? false,
      reduceDecoration: json['reduceDecoration'] as bool? ?? false,
      fullPoetryLibrary: json['fullPoetryLibrary'] as bool? ?? false,
      globalHanLookupEnabled: json['globalHanLookupEnabled'] as bool? ?? true,
      scriptDisplay: enumeration(
          'scriptDisplay', ScriptDisplay.values, ScriptDisplay.simplified),
      maxCharacterLevel: (json['maxCharacterLevel'] as int? ?? 3).clamp(1, 3),
      skin: enumeration('skin', AppSkin.values, AppSkin.parchment),
      importedSkin: imported,
      importedSkins: imported == null ? const [] : [imported],
      sidebarWidth: (json['sidebarWidth'] as num? ?? 68).toDouble(),
      showPinyin: json['showPinyin'] as bool? ?? true,
      showZhuyin: json['showZhuyin'] as bool? ?? true,
      showWubi: json['showWubi'] as bool? ?? true,
      showRadical: json['showRadical'] as bool? ?? true,
      showStrokeCount: json['showStrokeCount'] as bool? ?? true,
      showStructure: json['showStructure'] as bool? ?? true,
      showUnicode: json['showUnicode'] as bool? ?? true,
      showScriptRelations: json['showScriptRelations'] as bool? ?? true,
      showCharacterLevel: json['showCharacterLevel'] as bool? ?? true,
      showFavorites: json['showFavorites'] as bool? ?? true,
      showParagraphNumbers: json['showParagraphNumbers'] as bool? ?? true,
      showAnnotationMarkers: json['showAnnotationMarkers'] as bool? ?? true,
      showStrokeOrder: json['showStrokeOrder'] as bool? ?? true,
    );
  }
}
