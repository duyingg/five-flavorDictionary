import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// Root visual layer for imported texture/pattern backgrounds.
class SkinBackdrop extends StatelessWidget {
  const SkinBackdrop({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visuals = Theme.of(context).extension<SkinVisuals>();
    final bytes = SkinAssetDecoder.bytes(visuals?.backgroundImage);
    return ColoredBox(
      color: visuals?.background ?? Theme.of(context).scaffoldBackgroundColor,
      child: Stack(fit: StackFit.expand, children: [
        if (bytes != null)
          Opacity(
            opacity: visuals!.backgroundOpacity,
            child: LayoutBuilder(
              builder: (context, constraints) => Image.memory(
                bytes,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        child,
      ]),
    );
  }
}

/// One semantic icon slot with asset override and Material fallback.
class SkinIcon extends StatelessWidget {
  const SkinIcon(
    this.keyName, {
    required this.fallback,
    super.key,
    this.size,
    this.color,
  });

  final String keyName;
  final IconData fallback;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final source =
        Theme.of(context).extension<SkinVisuals>()?.iconImages[keyName];
    final bytes = SkinAssetDecoder.bytes(source);
    if (bytes == null) return Icon(fallback, size: size, color: color);
    final dimension = size ?? IconTheme.of(context).size ?? 24;
    return Image.memory(
      bytes,
      width: dimension,
      height: dimension,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Icon(fallback, size: size, color: color),
    );
  }
}

abstract final class SkinAssetDecoder {
  static final _cache = <String, Uint8List>{};

  static Uint8List? bytes(String? dataUri) {
    if (dataUri == null || !dataUri.startsWith('data:image/')) return null;
    return _cache.putIfAbsent(dataUri, () {
      final comma = dataUri.indexOf(',');
      if (comma < 0 || !dataUri.substring(0, comma).contains(';base64')) {
        return Uint8List(0);
      }
      try {
        return base64Decode(dataUri.substring(comma + 1));
      } on FormatException {
        return Uint8List(0);
      }
    }).isEmpty
        ? null
        : _cache[dataUri];
  }
}
