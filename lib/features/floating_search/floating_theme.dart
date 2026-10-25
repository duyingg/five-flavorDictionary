import 'package:flutter/material.dart';

import '../../core/design/app_theme.dart';
import '../../core/widgets/skin_widgets.dart';
import '../domain/models.dart';

/// Reuses the global skin's resources and typography, with deeper surfaces.
abstract final class FloatingTheme {
  static Color shade(Color color, [double amount = .10]) =>
      Color.alphaBlend(Colors.black.withValues(alpha: amount), color);

  static ThemeData build(AppSettings settings) {
    final theme = AppTheme.build(settings.skin, settings.importedSkin);
    final spec = AppSkinRegistry.of(settings.skin, settings.importedSkin);
    final surface = shade(spec.surface);
    return theme.copyWith(
      scaffoldBackgroundColor: spec.backgroundAsset == null
          ? shade(spec.background)
          : Colors.transparent,
      colorScheme: theme.colorScheme.copyWith(surface: surface),
      cardTheme: theme.cardTheme.copyWith(color: surface),
      inputDecorationTheme:
          theme.inputDecorationTheme.copyWith(fillColor: surface),
      appBarTheme:
          theme.appBarTheme.copyWith(backgroundColor: shade(spec.background)),
    );
  }
}

class FloatingSkinBackdrop extends StatelessWidget {
  const FloatingSkinBackdrop({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => SkinBackdrop(
          child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black.withValues(alpha: .10)),
          child,
        ],
      ));
}
