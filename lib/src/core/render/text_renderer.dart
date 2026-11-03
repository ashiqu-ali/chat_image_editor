import 'package:flutter/widgets.dart';

import '../../models/text_layer.dart';
import '../geometry/edit_geometry.dart';
import 'text_layer_colors.dart';

/// Lays out and paints text layers. Shared by the live preview, gesture
/// hit testing and the export.
abstract final class TextRenderer {
  /// Horizontal padding around the text, as a fraction of the font size.
  static const double _horizontalPadding = 0.4;

  /// Vertical padding around the text, as a fraction of the font size.
  static const double _verticalPadding = 0.2;

  /// Background corner radius, as a fraction of the font size.
  static const double _cornerRadius = 0.3;

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
    for (final layer in layers) {
      if (hiddenIds.contains(layer.id)) continue;
      paintLayer(canvas, originalSize, layer, baseStyle: baseStyle);
    }
  }

  /// Paints one layer centered on its position, applying its rotation,
  /// mirroring and background.
  static void paintLayer(
    Canvas canvas,
    Size originalSize,
    TextLayer layer, {
    required TextStyle baseStyle,
  }) {
    if (layer.text.isEmpty) return;
    final fontPx = _fontPx(layer, originalSize);
    if (fontPx <= 0) return;

    final painter = _layout(layer, fontPx, baseStyle);
    try {
      final block = _blockSize(painter, fontPx);
      canvas.save();
      canvas.transform(
        EditGeometry.textLayerTransform(
          layer,
          originalSize,
        ).toMatrix4().storage,
      );
      final boxColor = TextLayerColors.boxColor(layer);
      if (boxColor != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: block.width,
              height: block.height,
            ),
            Radius.circular(fontPx * _cornerRadius),
          ),
          Paint()
            ..color = boxColor
            ..isAntiAlias = true,
        );
      }
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    } finally {
      painter.dispose();
    }
  }

  /// Size of the layer's block, background padding included, in
  /// original-image pixels and before rotation.
  static Size measure(
    TextLayer layer,
    Size originalSize, {
    required TextStyle baseStyle,
  }) {
    final fontPx = _fontPx(layer, originalSize);
    if (fontPx <= 0) return Size.zero;
    final painter = _layout(layer, fontPx, baseStyle);
    try {
      return _blockSize(painter, fontPx);
    } finally {
      painter.dispose();
    }
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
    final size = measure(layer, originalSize, baseStyle: baseStyle);
    if (size.isEmpty) return false;
    final local = EditGeometry.textLayerTransform(
      layer,
      originalSize,
    ).inverse().apply(point);
    return local.dx.abs() <= size.width / 2 + slop &&
        local.dy.abs() <= size.height / 2 + slop;
  }

  static double _fontPx(TextLayer layer, Size originalSize) {
    if (originalSize.width <= 0 || originalSize.height <= 0) return 0;
    final px = layer.fontSize * originalSize.shortestSide;
    return px.isFinite ? px : 0;
  }

  /// The padded block. Padding is the same for every background style, so
  /// cycling the background never changes the layer's footprint.
  static Size _blockSize(TextPainter painter, double fontPx) {
    return Size(
      painter.width + 2 * fontPx * _horizontalPadding,
      painter.height + 2 * fontPx * _verticalPadding,
    );
  }

  static TextPainter _layout(TextLayer layer, double fontPx, TextStyle base) {
    final textColor = TextLayerColors.textColor(layer);
    // A base style with a foreground paint can't also take a color.
    final style = base.foreground == null
        ? base.copyWith(color: textColor, fontSize: fontPx)
        : base.copyWith(fontSize: fontPx);
    return TextPainter(
      text: TextSpan(text: layer.text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
  }
}
