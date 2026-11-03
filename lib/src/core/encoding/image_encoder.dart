import 'package:flutter/foundation.dart';

import '../../models/editor_enums.dart';

/// Uncompressed pixels handed to an [ImageEncoder].
@immutable
class RgbaImage {
  /// Wraps raw pixels.
  const RgbaImage({
    required this.pixels,
    required this.width,
    required this.height,
  });

  /// Straight (non-premultiplied) RGBA, 8 bits per channel, row-major,
  /// `width * height * 4` bytes long.
  final Uint8List pixels;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;
}

/// Turns raw pixels into encoded image bytes.
///
/// The default is `DartImageEncoder`, which is pure Dart and works on every
/// platform. Implement this to plug in a faster native encoder.
abstract interface class ImageEncoder {
  /// Encodes [image] as [format]. [quality] (1–100) applies to JPEG only.
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  });
}
