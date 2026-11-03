import 'package:flutter/widgets.dart';

import '../../models/image_edit_value.dart';

/// The single source of geometric truth for the editor.
///
/// The live preview, gesture mapping and export all go through these
/// functions, which is what guarantees the export matches the preview.
/// See `ImageEditValue` for the coordinate spaces.
///
/// Transform order from original space to output space:
/// 1. flip ([ImageEditValue.flipX], [ImageEditValue.flipY]) in original
///    space,
/// 2. rotate clockwise by [ImageEditValue.quarterTurns],
/// 3. crop to [ImageEditValue.crop] (normalized over the rotated result).
///
/// "Output pixels" have their origin at the crop's top-left corner and one
/// unit per original-image pixel; callers scale further for display or for
/// `ExportOptions.maxLongEdge`.
abstract final class ImageGeometry {
  /// Size of [original] after [quarterTurns] clockwise quarter turns.
  static Size transformedSize(Size original, int quarterTurns) {
    throw UnimplementedError();
  }

  /// [crop] (normalized, or `null` for everything) in pixels of
  /// [transformed] space.
  static Rect cropRectPx(Size transformed, Rect? crop) {
    throw UnimplementedError();
  }

  /// Size of the final output in output pixels.
  static Size outputSize(Size original, ImageEditValue value) {
    throw UnimplementedError();
  }

  /// Matrix mapping original-image pixels to output pixels.
  static Matrix4 originalToOutput(Size original, ImageEditValue value) {
    throw UnimplementedError();
  }

  /// Applies [originalToOutput] to [canvas], so subsequent drawing in
  /// original-image pixels lands in output space.
  static void applyOriginalToOutput(
    Canvas canvas,
    Size original,
    ImageEditValue value,
  ) {
    throw UnimplementedError();
  }

  /// Maps a point normalized over original space to one normalized over
  /// the output (view space).
  static Offset originalToView(
    Offset point,
    Size original,
    ImageEditValue value,
  ) {
    throw UnimplementedError();
  }

  /// Maps a point normalized over the output (view space) back to
  /// normalized original space. Inverse of [originalToView].
  static Offset viewToOriginal(
    Offset point,
    Size original,
    ImageEditValue value,
  ) {
    throw UnimplementedError();
  }

  /// The rect where content of size [content] is shown centered inside
  /// [bounds] with `BoxFit.contain`.
  static Rect fitRect(Size content, Rect bounds) {
    throw UnimplementedError();
  }
}
