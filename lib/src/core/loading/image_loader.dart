import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../tracing/editor_timeline.dart';

/// A decoded image and the full pixel size of the source it came from.
@immutable
class LoadedImage {
  /// Wraps a decode result.
  const LoadedImage({required this.image, required this.originalSize});

  /// The decoded pixels, possibly smaller than [originalSize]. The caller
  /// owns it and must dispose it.
  final ui.Image image;

  /// Full size of the source image in pixels.
  final Size originalSize;
}

/// Decodes encoded image bytes without allocating more than needed.
///
/// Internal: not exported from the package.
abstract final class ImageLoader {
  /// Decodes [bytes] so the long side is at most [maxLongEdge] pixels
  /// (`null` decodes at full size). The source dimensions are read first,
  /// so a large photo is never fully decoded when a smaller size will do.
  ///
  /// Throws if the bytes aren't a supported image.
  static Future<LoadedImage> decode(Uint8List bytes, {int? maxLongEdge}) async {
    final task = EditorTimeline.task()
      ?..start(
        EditorTimeline.decode,
        arguments: <String, Object?>{
          'bytes': bytes.length,
          'maxLongEdge': maxLongEdge,
        },
      );
    Map<String, Object?>? decoded;
    try {
      // ImageDescriptor can't report dimensions of encoded images on the
      // web; the codec helper there hands them to the size callback instead.
      final loaded = await (kIsWeb
          ? _decodeWithSizeCallback(bytes, maxLongEdge)
          : _decodeWithDescriptor(bytes, maxLongEdge));
      if (task != null) {
        decoded = <String, Object?>{
          'width': loaded.image.width,
          'height': loaded.image.height,
          'originalWidth': loaded.originalSize.width.round(),
          'originalHeight': loaded.originalSize.height.round(),
        };
      }
      return loaded;
    } finally {
      task?.finish(arguments: decoded);
    }
  }

  /// The decode size for a [width]×[height] source: `null` keeps the full
  /// size, otherwise only the long side is given so the aspect ratio is
  /// preserved exactly by the codec.
  @visibleForTesting
  static ({int? width, int? height})? targetSize(
    int width,
    int height,
    int? maxLongEdge,
  ) {
    if (maxLongEdge == null || maxLongEdge <= 0) return null;
    if (math.max(width, height) <= maxLongEdge) return null;
    return width >= height
        ? (width: maxLongEdge, height: null)
        : (width: null, height: maxLongEdge);
  }

  static Future<LoadedImage> _decodeWithDescriptor(
    Uint8List bytes,
    int? maxLongEdge,
  ) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      final target = targetSize(width, height, maxLongEdge);
      codec = await descriptor.instantiateCodec(
        targetWidth: target?.width,
        targetHeight: target?.height,
      );
      final frame = await codec.getNextFrame();
      return LoadedImage(
        image: frame.image,
        originalSize: _orientedSize(width, height, frame.image),
      );
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  static Future<LoadedImage> _decodeWithSizeCallback(
    Uint8List bytes,
    int? maxLongEdge,
  ) async {
    int? sourceWidth;
    int? sourceHeight;
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    // instantiateImageCodecWithSize disposes the buffer.
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (int width, int height) {
        sourceWidth = width;
        sourceHeight = height;
        final target = targetSize(width, height, maxLongEdge);
        return ui.TargetImageSize(width: target?.width, height: target?.height);
      },
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      return LoadedImage(
        image: image,
        originalSize: _orientedSize(
          sourceWidth ?? image.width,
          sourceHeight ?? image.height,
          image,
        ),
      );
    } finally {
      codec.dispose();
    }
  }

  /// The source size in the orientation of the decoded frame. Guards
  /// against a decoder that reports pre-rotation (EXIF) dimensions.
  static Size _orientedSize(int width, int height, ui.Image decoded) {
    if (width == height || decoded.width == decoded.height) {
      return Size(width.toDouble(), height.toDouble());
    }
    final sourceLandscape = width > height;
    final decodedLandscape = decoded.width > decoded.height;
    return sourceLandscape == decodedLandscape
        ? Size(width.toDouble(), height.toDouble())
        : Size(height.toDouble(), width.toDouble());
  }
}
