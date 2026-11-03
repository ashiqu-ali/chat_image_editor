import 'dart:typed_data';

import '../../models/editor_enums.dart';
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
    throw UnimplementedError();
  }
}
