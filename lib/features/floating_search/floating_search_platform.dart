import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import 'floating_preferences.dart';
import '../../core/design/app_theme.dart';
import 'floating_settings_snapshot.dart';
import 'floating_theme.dart';

abstract final class FloatingSearchPlatform {
  static const channel =
      MethodChannel('com.duyingg.fiveflavordictionary/floating_search');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> prepareEnable() async =>
      await channel.invokeMethod<bool>('prepareEnable') ?? false;

  static Future<Map<Object?, Object?>> sync(FloatingPreferences preferences,
      {required AppSettings globalSettings}) async {
    final enabled = preferences.enabled;
    final settings = preferences.display.copyWith(
        scriptDisplay: globalSettings.scriptDisplay,
        keepSearchHistory: globalSettings.keepSearchHistory,
        leftHanded: globalSettings.experimentalFeaturesEnabled &&
            globalSettings.leftHanded,
        reduceDecoration: globalSettings.reduceDecoration,
        skin: globalSettings.skin,
        importedSkin: globalSettings.importedSkin,
        clearImportedSkin: globalSettings.importedSkin == null,
        importedSkins: const []);
    final skin = AppSkinRegistry.of(settings.skin, settings.importedSkin);
    return await channel.invokeMapMethod<Object?, Object?>('sync', {
          'enabled': enabled,
          'configuration': enabled
              ? FloatingSettingsSnapshot.encode(settings,
                  showSearchBox: preferences.showSearchBox)
              : null,
          'appearance': {
            'opacity': preferences.opacity,
            'clipboardSearchEnabled': settings.clipboardSearchEnabled,
            'windowWidth': preferences.windowWidth,
            'windowHeight': preferences.windowHeight,
            'script': settings.scriptDisplay.name,
            'fontScale': settings.fontScale.factor,
            'showPinyin': settings.showPinyin,
            'leftHanded': settings.leftHanded,
            'background': FloatingTheme.shade(skin.background).toARGB32(),
            'primary': skin.primary.toARGB32(),
            'border': FloatingTheme.shade(skin.border).toARGB32(),
          },
        }) ??
        const {};
  }
}
