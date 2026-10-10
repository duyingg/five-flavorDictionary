import 'package:flutter/material.dart';

import '../../features/domain/models.dart';
import '../platform/platform_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFFAF8F3);
  static const surface = Color(0xFFFFFDFC);
  static const textPrimary = Color(0xFF24211E);
  static const textSecondary = Color(0xFF7D7770);
  static const accent = Color(0xFF9A633A);
  static const gold = Color(0xFFC79A4A);
  static const border = Color(0xFFE5DED5);
  static const error = Color(0xFFB5483A);
}

abstract final class AppTheme {
  static ThemeData build(
    AppSkin skin, [
    ImportedSkin? importedSkin,
  ]) {
    final spec = AppSkinRegistry.of(skin, importedSkin);
    final dark = spec.background.computeLuminance() < .35;
    final scheme =
        (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: spec.primary,
      secondary: spec.secondary,
      surface: spec.surface,
      error: spec.error,
      onPrimary: spec.onPrimary,
      onSurface: spec.text,
      onSurfaceVariant: spec.mutedText,
      outline: spec.border,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          spec.backgroundAsset == null ? spec.background : Colors.transparent,
      fontFamily:
          spec.fontFamily.isEmpty ? platformPrimaryFontFamily : spec.fontFamily,
      fontFamilyFallback: platformFontFallback,
    );
    final scaledTextTheme = base.textTheme.apply(
      bodyColor: spec.text,
      displayColor: spec.text,
    );
    return base.copyWith(
      textTheme: _normalizedTextTheme(scaledTextTheme),
      dividerColor: spec.border,
      iconTheme: IconThemeData(color: spec.text),
      appBarTheme: AppBarTheme(
        backgroundColor: spec.background,
        foregroundColor: spec.text,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: spec.surface,
        indicatorColor: spec.primary.withValues(alpha: .12),
      ),
      cardTheme: CardThemeData(
        color: spec.surface,
        elevation: spec.cardElevation,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spec.cardRadius),
          side: BorderSide(color: spec.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: spec.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spec.inputRadius),
          borderSide: BorderSide(color: spec.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spec.inputRadius),
          borderSide: BorderSide(color: spec.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(spec.inputRadius),
          borderSide: BorderSide(color: spec.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(spec.buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(spec.buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: spec.primary),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: spec.surface,
        selectedColor: spec.primary.withValues(alpha: .14),
        side: BorderSide(color: spec.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spec.buttonRadius),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: spec.primary,
        inactiveTrackColor: spec.border,
        thumbColor: spec.primary,
        overlayColor: spec.primary.withValues(alpha: .12),
        activeTickMarkColor: spec.surface,
        inactiveTickMarkColor: spec.mutedText,
        valueIndicatorColor: spec.primary,
        valueIndicatorTextStyle: TextStyle(color: spec.onPrimary),
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? spec.onPrimary
              : spec.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? spec.primary
              : spec.border,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: spec.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spec.cardRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: spec.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(spec.cardRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: spec.text,
        contentTextStyle: TextStyle(color: spec.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spec.buttonRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: spec.mutedText,
        textColor: spec.text,
      ),
      extensions: [SkinVisuals.fromSpec(spec)],
    );
  }

  static TextTheme _normalizedTextTheme(TextTheme theme) => theme.copyWith(
        displayLarge: _withLineHeight(theme.displayLarge, 1.12),
        displayMedium: _withLineHeight(theme.displayMedium, 1.12),
        displaySmall: _withLineHeight(theme.displaySmall, 1.12),
        headlineLarge: _withLineHeight(theme.headlineLarge, 1.2),
        headlineMedium: _withLineHeight(theme.headlineMedium, 1.2),
        headlineSmall: _withLineHeight(theme.headlineSmall, 1.2),
        titleLarge: _withLineHeight(theme.titleLarge, 1.25),
        titleMedium: _withLineHeight(theme.titleMedium, 1.25),
        titleSmall: _withLineHeight(theme.titleSmall, 1.25),
        bodyLarge: _withLineHeight(theme.bodyLarge, 1.45),
        bodyMedium: _withLineHeight(theme.bodyMedium, 1.45),
        bodySmall: _withLineHeight(theme.bodySmall, 1.4),
        labelLarge: _withLineHeight(theme.labelLarge, 1.25),
        labelMedium: _withLineHeight(theme.labelMedium, 1.25),
        labelSmall: _withLineHeight(theme.labelSmall, 1.25),
      );

  static TextStyle? _withLineHeight(TextStyle? style, double height) =>
      style?.copyWith(
        height: height,
        leadingDistribution: TextLeadingDistribution.even,
      );
}

@immutable
class SkinVisuals extends ThemeExtension<SkinVisuals> {
  const SkinVisuals({
    required this.background,
    required this.backgroundImage,
    required this.backgroundFit,
    required this.backgroundOpacity,
    required this.iconImages,
  });

  factory SkinVisuals.fromSpec(AppSkinSpec spec) => SkinVisuals(
        background: spec.background,
        backgroundImage: spec.backgroundAsset,
        backgroundFit: spec.backgroundFit,
        backgroundOpacity: spec.backgroundOpacity,
        iconImages: spec.iconAssets,
      );

  final Color background;
  final String? backgroundImage;
  final BoxFit backgroundFit;
  final double backgroundOpacity;
  final Map<String, String> iconImages;

  @override
  SkinVisuals copyWith({
    Color? background,
    String? backgroundImage,
    BoxFit? backgroundFit,
    double? backgroundOpacity,
    Map<String, String>? iconImages,
  }) =>
      SkinVisuals(
        background: background ?? this.background,
        backgroundImage: backgroundImage ?? this.backgroundImage,
        backgroundFit: backgroundFit ?? this.backgroundFit,
        backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
        iconImages: iconImages ?? this.iconImages,
      );

  @override
  SkinVisuals lerp(covariant SkinVisuals? other, double t) => other == null
      ? this
      : SkinVisuals(
          background: Color.lerp(background, other.background, t)!,
          backgroundImage: t < .5 ? backgroundImage : other.backgroundImage,
          backgroundFit: t < .5 ? backgroundFit : other.backgroundFit,
          backgroundOpacity: backgroundOpacity +
              (other.backgroundOpacity - backgroundOpacity) * t,
          iconImages: t < .5 ? iconImages : other.iconImages,
        );
}

class AppSkinSpec {
  const AppSkinSpec({
    required this.id,
    required this.description,
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.border,
    this.mutedText = AppColors.textSecondary,
    this.onPrimary = Colors.white,
    this.error = AppColors.error,
    this.success = const Color(0xFF32735E),
    this.backgroundAsset,
    this.backgroundFit = BoxFit.cover,
    this.backgroundOpacity = 1,
    this.cardRadius = 16,
    this.inputRadius = 14,
    this.buttonRadius = 12,
    this.cardElevation = 0,
    this.fontFamily = '',
    this.iconOverrides = const {},
    this.iconAssets = const {},
    this.sourceSkin,
  });
  final AppSkin id;
  final String description;
  final Color background;
  final Color surface;
  final Color primary;
  final Color secondary;
  final Color text;
  final Color border;
  final Color mutedText;
  final Color onPrimary;
  final Color error;
  final Color success;
  final String? backgroundAsset;
  final BoxFit backgroundFit;
  final double backgroundOpacity;
  final double cardRadius;
  final double inputRadius;
  final double buttonRadius;
  final double cardElevation;
  final String fontFamily;
  final Map<String, IconData> iconOverrides;
  final Map<String, String> iconAssets;
  final ImportedSkin? sourceSkin;

  bool hasIcon(String key) => iconOverrides.containsKey(key);
  IconData icon(String key, IconData fallback) =>
      iconOverrides[key] ?? fallback;
  String? iconAsset(String key) => iconAssets[key];
}

abstract final class AppSkinRegistry {
  static const _iconNames = <String, IconData>{
    'home': Icons.home,
    'home_outlined': Icons.home_outlined,
    'cottage_outlined': Icons.cottage_outlined,
    'menu_book': Icons.menu_book,
    'menu_book_outlined': Icons.menu_book_outlined,
    'account_balance': Icons.account_balance,
    'account_balance_outlined': Icons.account_balance_outlined,
    'temple_buddhist_outlined': Icons.temple_buddhist_outlined,
    'person': Icons.person,
    'person_outline': Icons.person_outline,
    'settings_outlined': Icons.settings_outlined,
    'text_fields': Icons.text_fields,
    'palette_outlined': Icons.palette_outlined,
    'eco_outlined': Icons.eco_outlined,
    'calendar_month_outlined': Icons.calendar_month_outlined,
    'history': Icons.history,
    'storage_outlined': Icons.storage_outlined,
    'info_outline': Icons.info_outline,
    'help_outline': Icons.help_outline,
    'mail_outline': Icons.mail_outline,
  };

  static const skins = <AppSkinSpec>[
    AppSkinSpec(
      id: AppSkin.parchment,
      description: '温暖宣纸底色与传统棕金点缀',
      background: AppColors.background,
      surface: AppColors.surface,
      primary: AppColors.accent,
      secondary: AppColors.gold,
      text: AppColors.textPrimary,
      border: AppColors.border,
    ),
    AppSkinSpec(
      id: AppSkin.jade,
      description: '浅青纸面与玉石绿色，含部分定制图标',
      background: Color(0xFFF3F8F5),
      surface: Color(0xFFFBFEFC),
      primary: Color(0xFF32735E),
      secondary: Color(0xFF80A98E),
      text: Color(0xFF1F302A),
      border: Color(0xFFD6E5DC),
      iconOverrides: {
        'nav.home': Icons.cottage_outlined,
        'nav.culture': Icons.temple_buddhist_outlined,
        'profile.skin': Icons.eco_outlined,
      },
    ),
    AppSkinSpec(
      id: AppSkin.night,
      description: '冷调雾蓝纸面，适合偏现代的视觉方案',
      background: Color(0xFFF1F4F8),
      surface: Color(0xFFFAFBFD),
      primary: Color(0xFF465E82),
      secondary: Color(0xFF8395B1),
      text: Color(0xFF202A3A),
      border: Color(0xFFD8DEE8),
    ),
  ];

  static List<AppSkinSpec> available(List<ImportedSkin> importedSkins) => [
        ...skins,
        for (final importedSkin in importedSkins) _fromImported(importedSkin),
      ];

  static AppSkinSpec of(AppSkin skin, [ImportedSkin? importedSkin]) {
    if (skin == AppSkin.imported && importedSkin != null) {
      return _fromImported(importedSkin);
    }
    return skins.firstWhere(
      (spec) => spec.id == skin,
      orElse: () => skins.first,
    );
  }

  static AppSkinSpec _fromImported(ImportedSkin skin) => AppSkinSpec(
        id: AppSkin.imported,
        sourceSkin: skin,
        description: '${skin.name} · ${skin.description}',
        background: Color(skin.background),
        surface: Color(skin.surface).withValues(alpha: skin.surfaceOpacity),
        primary: Color(skin.primary),
        secondary: Color(skin.secondary),
        text: Color(skin.text),
        border: Color(skin.border),
        mutedText: Color(skin.mutedText),
        onPrimary: Color(skin.onPrimary),
        error: Color(skin.error),
        success: Color(skin.success),
        backgroundAsset: skin.backgroundAsset == null
            ? null
            : skin.assets[skin.backgroundAsset],
        backgroundFit: switch (skin.backgroundFit) {
          'contain' => BoxFit.contain,
          'fill' => BoxFit.fill,
          'fitWidth' => BoxFit.fitWidth,
          'fitHeight' => BoxFit.fitHeight,
          'none' => BoxFit.none,
          _ => BoxFit.cover,
        },
        backgroundOpacity: skin.backgroundOpacity,
        cardRadius: skin.cardRadius,
        inputRadius: skin.inputRadius,
        buttonRadius: skin.buttonRadius,
        cardElevation: skin.cardElevation,
        fontFamily: skin.fontFamily,
        iconOverrides: {
          for (final entry in skin.icons.entries)
            if (_iconNames.containsKey(entry.value))
              entry.key: _iconNames[entry.value]!,
        },
        iconAssets: {
          for (final entry in skin.icons.entries)
            if (entry.value.startsWith('asset:') &&
                skin.assets.containsKey(entry.value.substring(6)))
              entry.key: skin.assets[entry.value.substring(6)]!,
        },
      );
}
