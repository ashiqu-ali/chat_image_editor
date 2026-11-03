import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../models/image_edit_value.dart';
import '../../models/stroke.dart';
import '../geometry/image_geometry.dart';
import '../tracing/editor_timeline.dart';
import 'stroke_renderer.dart';
import 'text_renderer.dart';

/// Paints the full composition: base image, strokes, then text.
///
/// The live canvas and the export both call [paint], so what the user sees
/// is exactly what gets encoded.
abstract final class CompositionRenderer {
  /// Paints into **output space**: the canvas origin is the crop's top-left
  /// and one unit is one original-image pixel. Scale the canvas first to
  /// fit a widget or to honour `ExportOptions.maxLongEdge`.
  ///
  /// [image] may be smaller than [originalSize] (a preview decode); it's
  /// stretched to cover the original pixel area.
  ///
  /// In crop mode, pass `value.copyWith(clearCrop: true)` to paint the
  /// whole rotated image under the crop frame.
  static void paint(
    Canvas canvas, {
    required ui.Image image,
    required Size originalSize,
    required ImageEditValue value,
    required TextStyle textStyle,
    Stroke? draftStroke,
    Set<String> hiddenTextIds = const <String>{},
    bool paintStrokes = true,
    bool paintTexts = true,
  }) {
    EditorTimeline.timeSync<void>(
      EditorTimeline.paint,
      () => _paint(
        canvas,
        image: image,
        originalSize: originalSize,
        value: value,
        textStyle: textStyle,
        draftStroke: draftStroke,
        hiddenTextIds: hiddenTextIds,
        paintStrokes: paintStrokes,
        paintTexts: paintTexts,
      ),
      arguments: () => <String, Object?>{
        'strokes': paintStrokes ? value.strokes.length : 0,
        'texts': paintTexts ? value.texts.length : 0,
        'draft': draftStroke != null,
        'imageWidth': image.width,
        'imageHeight': image.height,
      },
    );
  }

  static void _paint(
    Canvas canvas, {
    required ui.Image image,
    required Size originalSize,
    required ImageEditValue value,
    required TextStyle textStyle,
    required Stroke? draftStroke,
    required Set<String> hiddenTextIds,
    required bool paintStrokes,
    required bool paintTexts,
  }) {
    if (originalSize.width <= 0 || originalSize.height <= 0) return;
    final output = ImageGeometry.outputSize(originalSize, value);
    if (output.width <= 0 || output.height <= 0) return;

    canvas.save();
    // Everything outside the output is cut off, exactly as in the export.
    canvas.clipRect(Offset.zero & output);
    ImageGeometry.applyOriginalToOutput(canvas, originalSize, value);

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & originalSize,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );

    if (paintStrokes) {
      StrokeRenderer.paint(canvas, originalSize, value.strokes);
      if (draftStroke != null) {
        StrokeRenderer.paintStroke(canvas, originalSize, draftStroke);
      }
    }
    if (paintTexts) {
      TextRenderer.paint(
        canvas,
        originalSize,
        value.texts,
        baseStyle: textStyle,
        hiddenIds: hiddenTextIds,
      );
    }
    canvas.restore();
  }
}
