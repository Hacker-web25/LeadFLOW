import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays either a local file path (mobile/desktop) or a network URL.
/// On the web, `Image.file` isn't supported, so any `path` value that isn't
/// obviously a URL falls back to `Image.network`. `image_picker` on the web
/// returns a blob:/... URL, which works with `Image.network`.
class PlatformImage extends StatelessWidget {
  const PlatformImage({super.key, required this.path, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  bool get _isRemote =>
      path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('blob:');

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _isRemote) {
      return Image.network(path, fit: fit,
          errorBuilder: (_, __, ___) => const _Fallback());
    }
    return Image.file(File(path), fit: fit,
        errorBuilder: (_, __, ___) => const _Fallback());
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xFF1C1C22),
        child: Center(
          child: Icon(Icons.badge_outlined, size: 40, color: Colors.white38),
        ),
      );
}
