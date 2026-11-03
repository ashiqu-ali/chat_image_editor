import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../models/editor_enums.dart';
import '../tracing/editor_timeline.dart';
import 'image_encoder.dart';

/// Pure-Dart [ImageEncoder] built on `package:image`.
///
/// Encoding runs in a background isolate through `compute` on platforms
/// that support isolates; on the web it runs on the main thread.
class DartImageEncoder implements ImageEncoder {
  /// Creates the encoder.
  const DartImageEncoder();

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) {
    if (image.width <= 0 ||
        image.height <= 0 ||
        image.pixels.length != image.width * image.height * 4) {
      return Future<Uint8List>.error(
        ArgumentError(
          'Expected ${image.width}x${image.height} RGBA pixels '
          '(${image.width * image.height * 4} bytes), '
          'got ${image.pixels.length} bytes.',
        ),
      );
    }
    final job = _EncodeJob(
      pixels: image.pixels,
      width: image.width,
      height: image.height,
      format: format,
      quality: quality.clamp(1, 100),
    );
    return compute(_encode, job, debugLabel: 'chat_image_editor.encode');
  }
}

/// Everything the background isolate needs; all fields are sendable.
@immutable
class _EncodeJob {
  const _EncodeJob({
    required this.pixels,
    required this.width,
    required this.height,
    required this.format,
    required this.quality,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final ExportFormat format;
  final int quality;
}

Uint8List _encode(_EncodeJob job) {
  return EditorTimeline.timeSync<Uint8List>(
    EditorTimeline.encodePixels,
    () => _encodePixels(job),
    arguments: () => <String, Object?>{
      'format': job.format.name,
      'quality': job.format == ExportFormat.jpeg ? job.quality : null,
      'width': job.width,
      'height': job.height,
    },
  );
}

Uint8List _encodePixels(_EncodeJob job) {
  final pixels = job.pixels;
  // JPEG has no alpha, and an opaque PNG is smaller without it.
  if (job.format == ExportFormat.jpeg || _isOpaque(pixels)) {
    final rgb = img.Image.fromBytes(
      width: job.width,
      height: job.height,
      bytes: _dropAlpha(pixels).buffer,
      numChannels: 3,
    );
    return job.format == ExportFormat.jpeg
        ? img.encodeJpg(rgb, quality: job.quality)
        : img.encodePng(rgb);
  }
  final rgba = img.Image.fromBytes(
    width: job.width,
    height: job.height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodePng(rgba);
}

bool _isOpaque(Uint8List rgba) {
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] != 0xFF) return false;
  }
  return true;
}

Uint8List _dropAlpha(Uint8List rgba) {
  final pixelCount = rgba.length ~/ 4;
  final rgb = Uint8List(pixelCount * 3);
  for (var i = 0, j = 0; i < rgba.length; i += 4, j += 3) {
    rgb[j] = rgba[i];
    rgb[j + 1] = rgba[i + 1];
    rgb[j + 2] = rgba[i + 2];
  }
  return rgb;
}
