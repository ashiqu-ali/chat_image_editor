import 'package:flutter/widgets.dart';

import '../../models/text_layer.dart';

/// Lays out and paints text layers. Shared by the live preview, gesture
/// hit testing and the export.
abstract final class TextRenderer {
  /// Paints [layers] in order, skipping ids in [hiddenIds] (for example the
  /// layer currently open in the text entry overlay).
  ///
  /// The canvas must already map original-image pixels to wherever the
  /// image is drawn. [baseStyle] supplies font family, weight and shadows;
  /// color and size come from each layer.
  static void paint(
    Canvas canvas,
    Size originalSize,
    Iterable<TextLayer> layers, {
    required TextStyle baseStyle,
    Set<String> hiddenIds = const <String>{},
  }) {
    throw UnimplementedError();
  }

  /// Paints one layer centered on its position, applying its rotation,
  /// mirroring and background.
  static void paintLayer(
    Canvas canvas,
    Size originalSize,
    TextLayer layer, {
    required TextStyle baseStyle,
  }) {
    throw UnimplementedError();
  }

  /// Size of the layer's block, background padding included, in
  /// original-image pixels and before rotation.
  static Size measure(
    TextLayer layer,
    Size originalSize, {
    required TextStyle baseStyle,
  }) {
    throw UnimplementedError();
  }

  /// Whether [point], in original-image pixels, falls inside the layer's
  /// rotated block grown by [slop] pixels on each side.
  static bool hitTest(
    TextLayer layer,
    Offset point,
    Size originalSize, {
    required TextStyle baseStyle,
    double slop = 0,
  }) {
    throw UnimplementedError();
  }
}
