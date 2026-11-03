import 'package:flutter/widgets.dart';

import '../../models/stroke.dart';

/// Paints strokes. Shared by the live preview and the export so both look
/// identical.
abstract final class StrokeRenderer {
  /// Paints [strokes] in order.
  ///
  /// The canvas must already map original-image pixels to wherever the
  /// image is drawn (see `ImageGeometry.applyOriginalToOutput`).
  /// [originalSize] converts the normalized stroke data to pixels.
  static void paint(
    Canvas canvas,
    Size originalSize,
    Iterable<Stroke> strokes,
  ) {
    throw UnimplementedError();
  }

  /// Paints a single [stroke]. Freehand strokes are smoothed; arrows get an
  /// arrowhead scaled to the stroke width.
  static void paintStroke(Canvas canvas, Size originalSize, Stroke stroke) {
    throw UnimplementedError();
  }
}
