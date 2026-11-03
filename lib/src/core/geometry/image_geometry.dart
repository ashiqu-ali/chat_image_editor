import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/image_edit_value.dart';
import 'affine_2d.dart';

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
    return (quarterTurns % 4).isOdd
        ? Size(original.height, original.width)
        : original;
  }

  /// [crop] (normalized, or `null` for everything) in pixels of
  /// [transformed] space.
  static Rect cropRectPx(Size transformed, Rect? crop) {
    if (crop == null) return Offset.zero & transformed;
    return Rect.fromLTRB(
      crop.left * transformed.width,
      crop.top * transformed.height,
      crop.right * transformed.width,
      crop.bottom * transformed.height,
    );
  }

  /// Size of the final output in output pixels.
  static Size outputSize(Size original, ImageEditValue value) {
    final transformed = transformedSize(original, value.quarterTurns);
    return cropRectPx(transformed, value.crop).size;
  }

  /// Matrix mapping original-image pixels to output pixels.
  static Matrix4 originalToOutput(Size original, ImageEditValue value) {
    return _originalToOutput(original, value).toMatrix4();
  }

  /// Applies [originalToOutput] to [canvas], so subsequent drawing in
  /// original-image pixels lands in output space.
  static void applyOriginalToOutput(
    Canvas canvas,
    Size original,
    ImageEditValue value,
  ) {
    canvas.transform(originalToOutput(original, value).storage);
  }

  /// Maps a point normalized over original space to one normalized over
  /// the output (view space).
  static Offset originalToView(
    Offset point,
    Size original,
    ImageEditValue value,
  ) {
    final size = _usableSize(original);
    final output = outputSize(size, value);
    if (!_isUsable(output)) return point;
    final px = _originalToOutput(
      size,
      value,
    ).apply(Offset(point.dx * size.width, point.dy * size.height));
    return Offset(px.dx / output.width, px.dy / output.height);
  }

  /// Maps a point normalized over the output (view space) back to
  /// normalized original space. Inverse of [originalToView].
  static Offset viewToOriginal(
    Offset point,
    Size original,
    ImageEditValue value,
  ) {
    final size = _usableSize(original);
    final output = outputSize(size, value);
    if (!_isUsable(output)) return point;
    final px = _originalToOutput(size, value).inverse().apply(
      Offset(point.dx * output.width, point.dy * output.height),
    );
    return Offset(px.dx / size.width, px.dy / size.height);
  }

  /// The rect where content of size [content] is shown centered inside
  /// [bounds] with `BoxFit.contain`.
  static Rect fitRect(Size content, Rect bounds) {
    if (!_isUsable(content) || bounds.width <= 0 || bounds.height <= 0) {
      return Rect.fromCenter(center: bounds.center, width: 0, height: 0);
    }
    final scale = math.min(
      bounds.width / content.width,
      bounds.height / content.height,
    );
    return Rect.fromCenter(
      center: bounds.center,
      width: content.width * scale,
      height: content.height * scale,
    );
  }

  /// Builds the original-to-output transform as flip, then rotation, then
  /// crop translation. Every coefficient is exactly 0 or ±1, so mappings
  /// stay exact for quarter turns.
  static Affine2D _originalToOutput(Size original, ImageEditValue value) {
    final w = original.width;
    final h = original.height;

    final flip = Affine2D(
      value.flipX ? -1 : 1,
      0,
      0,
      value.flipY ? -1 : 1,
      value.flipX ? w : 0,
      value.flipY ? h : 0,
    );

    final Affine2D rotate;
    switch (value.quarterTurns % 4) {
      case 1:
        // (x, y) -> (h - y, x)
        rotate = Affine2D(0, 1, -1, 0, h, 0);
      case 2:
        // (x, y) -> (w - x, h - y)
        rotate = Affine2D(-1, 0, 0, -1, w, h);
      case 3:
        // (x, y) -> (y, w - x)
        rotate = Affine2D(0, -1, 1, 0, 0, w);
      default:
        rotate = Affine2D.identity;
    }

    final crop = cropRectPx(
      transformedSize(original, value.quarterTurns),
      value.crop,
    );
    final translate = Affine2D.translation(-crop.left, -crop.top);

    return translate * rotate * flip;
  }

  static bool _isUsable(Size size) =>
      size.width > 0 &&
      size.height > 0 &&
      size.width.isFinite &&
      size.height.isFinite;

  /// Normalized mappings don't depend on the pixel size, so an unknown
  /// (empty) size falls back to a unit square.
  static Size _usableSize(Size original) =>
      _isUsable(original) ? original : const Size(1, 1);
}
