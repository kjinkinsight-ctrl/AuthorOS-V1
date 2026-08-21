import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Rendering for images the author picked off their own machine.
///
/// Portraits and avatars are chosen with `file_selector`, which hands back a
/// different kind of location on each platform: a filesystem path on Windows,
/// macOS, and Linux, and an object URL (`blob:`) in the browser. `Image.file`
/// understands only the first kind — it asserts against the web in debug and
/// throws out of `dart:io` in release — so every surface that shows a picked
/// image goes through here instead of constructing one directly.
///
/// This is presentation only. Nothing above it needs to know which platform it
/// is running on: callers pass the same stored path they always did, and get
/// their own placeholder back when the image cannot be shown.
ImageProvider? localImageProvider(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (kIsWeb) {
    // In the browser the only paths that resolve to something are URLs: the
    // object URL `file_selector` returns for a freshly picked file, or a
    // data/http URL. A bare filesystem path — including one saved by the
    // desktop app and synced here — has nothing behind it.
    return _isUrl(trimmed) ? NetworkImage(trimmed) : null;
  }
  if (_isUrl(trimmed)) {
    return NetworkImage(trimmed);
  }
  return FileImage(io.File(trimmed));
}

bool _isUrl(String path) {
  final uri = Uri.tryParse(path);
  if (uri == null || !uri.hasScheme) {
    return false;
  }
  return const {'blob', 'data', 'http', 'https'}.contains(uri.scheme);
}

/// An image picked from the author's machine, with [fallback] shown whenever it
/// is missing, unreadable, or — on the web — a path that no longer resolves.
///
/// Object URLs live only as long as the tab that created them, so a portrait
/// picked in the browser is shown for the rest of the session and falls back to
/// [fallback] after a reload. That is a browser constraint, not a failure: the
/// fallback is the same placeholder the surface shows before a picture is set.
class LocalImage extends StatelessWidget {
  const LocalImage({
    super.key,
    required this.path,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String path;
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final provider = localImageProvider(path);
    if (provider == null) {
      return fallback;
    }
    return Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
