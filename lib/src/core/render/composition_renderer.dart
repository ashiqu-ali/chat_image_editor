import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../models/image_edit_value.dart';
import '../../models/stroke.dart';

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
    throw UnimplementedError();
  }
}
