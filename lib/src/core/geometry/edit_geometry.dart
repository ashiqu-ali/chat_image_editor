import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/image_edit_value.dart';
import '../../models/text_layer.dart';
import 'affine_2d.dart';
import 'image_geometry.dart';

/// Geometry used by the controller and renderers on top of [ImageGeometry]:
/// text layer placement, crop rect transforms and crop constraints.
///
/// Internal: not exported from the package.
abstract final class EditGeometry {
  /// The full normalized crop rect.
  static const Rect fullCrop = Rect.fromLTRB(0, 0, 1, 1);

  /// Linear part (rotation and mirroring only) of the original-to-output
  /// transform for [value]. Independent of image size and crop.
  static Affine2D orientation(ImageEditValue value) {
    return Affine2D.fromMatrix4(
      ImageGeometry.originalToOutput(
        const Size(1, 1),
        value.copyWith(clearCrop: true),
      ),
    ).linear;
  }

  /// Whether [value] shows the image mirrored (exactly one effective flip).
  static bool isMirrored(ImageEditValue value) =>
      orientation(value).determinant < 0;

  /// `1` when a clockwise turn on screen is a clockwise turn in original
  /// space, `-1` when the image is shown mirrored.
  static double screenRotationSign(ImageEditValue value) =>
      isMirrored(value) ? -1 : 1;

  /// Rotation and mirroring that make a new text layer read upright on
  /// screen for [value]'s quarter turns and flips.
  static ({double rotation, bool mirrored}) uprightText(ImageEditValue value) {
    // The layer's local frame is R(rotation)·M with M = mirror-x when
    // mirrored. Upright on screen means orientation·R·M == identity, so
    // R·M must equal the inverse orientation.
    final inverse = orientation(value).inverse();
    if (inverse.determinant > 0) {
      return (
        rotation: _normalizeAngle(math.atan2(inverse.b, inverse.a)),
        mirrored: false,
      );
    }
    return (
      rotation: _normalizeAngle(math.atan2(-inverse.b, -inverse.a)),
      mirrored: true,
    );
  }

  /// Maps a text layer's local pixels (origin at the block's center, before
  /// rotation) to original-image pixels: mirror, then rotate, then move to
  /// the layer's position.
  static Affine2D textLayerTransform(TextLayer layer, Size originalSize) {
    final center = Offset(
      layer.position.dx * originalSize.width,
      layer.position.dy * originalSize.height,
    );
    var transform =
        Affine2D.translation(center.dx, center.dy) *
        Affine2D.rotation(layer.rotation);
    if (layer.mirrored) {
      transform = transform * const Affine2D.scale(-1, 1);
    }
    return transform;
  }

  /// [crop] after the image turns a quarter clockwise.
  static Rect rotateCropClockwise(Rect crop) {
    return _snapRect(
      Rect.fromLTRB(1 - crop.bottom, crop.left, 1 - crop.top, crop.right),
    );
  }

  /// [crop] after the image turns a quarter counter-clockwise.
  static Rect rotateCropCounterClockwise(Rect crop) {
    return _snapRect(
      Rect.fromLTRB(crop.top, 1 - crop.right, crop.bottom, 1 - crop.left),
    );
  }

  /// [crop] mirrored left-right in transformed space.
  static Rect mirrorCropHorizontally(Rect crop) {
    return _snapRect(
      Rect.fromLTRB(1 - crop.right, crop.top, 1 - crop.left, crop.bottom),
    );
  }

  /// [crop] mirrored top-bottom in transformed space.
  static Rect mirrorCropVertically(Rect crop) {
    return _snapRect(
      Rect.fromLTRB(crop.left, 1 - crop.bottom, crop.right, 1 - crop.top),
    );
  }

  /// Converts an on-screen aspect [ratio] (width / height) into the ratio
  /// of normalized crop width to normalized crop height over a transformed
  /// image of size [transformed].
  static double normalizedAspect(double ratio, Size transformed) {
    if (transformed.width <= 0 || transformed.height <= 0) return ratio;
    return ratio * transformed.height / transformed.width;
  }

  /// The on-screen aspect ratio of normalized [crop] over [transformed].
  static double screenAspect(Rect crop, Size transformed) {
    if (transformed.width <= 0 || transformed.height <= 0 || crop.height <= 0) {
      return crop.height <= 0 ? double.infinity : crop.width / crop.height;
    }
    return (crop.width * transformed.width) /
        (crop.height * transformed.height);
  }

  /// The largest rect with normalized width / height [ratio], centered
  /// inside [bounds].
  static Rect fitAspect(Rect bounds, double ratio) {
    var width = bounds.width;
    var height = ratio > 0 ? width / ratio : bounds.height;
    if (height > bounds.height) {
      height = bounds.height;
      width = height * ratio;
    }
    return _snapRect(
      Rect.fromCenter(center: bounds.center, width: width, height: height),
    );
  }

  /// Clamps [rect] inside the unit square, fits it to [ratio] (normalized
  /// width / height) when given, and grows it to at least [minSize] on each
  /// side.
  static Rect constrainCrop(
    Rect rect, {
    required double minSize,
    double? ratio,
  }) {
    final min = minSize.clamp(0.0, 1.0);
    var left = math.min(rect.left, rect.right).clamp(0.0, 1.0);
    var top = math.min(rect.top, rect.bottom).clamp(0.0, 1.0);
    var right = math.max(rect.left, rect.right).clamp(0.0, 1.0);
    var bottom = math.max(rect.top, rect.bottom).clamp(0.0, 1.0);
    var result = Rect.fromLTRB(left, top, right, bottom);

    if (ratio != null && ratio > 0 && ratio.isFinite) {
      result = fitAspect(result, ratio);
    }

    var width = result.width;
    var height = result.height;
    if (width < min || height < min) {
      if (ratio != null && ratio > 0 && ratio.isFinite) {
        height = math.max(height, math.max(min, min / ratio));
        width = height * ratio;
        if (width > 1 || height > 1) {
          final fitted = fitAspect(fullCrop, ratio);
          width = fitted.width;
          height = fitted.height;
        }
      } else {
        width = math.max(width, min);
        height = math.max(height, min);
      }
    }
    width = math.min(width, 1.0);
    height = math.min(height, 1.0);

    final cx = result.center.dx.clamp(width / 2, 1 - width / 2);
    final cy = result.center.dy.clamp(height / 2, 1 - height / 2);
    left = cx - width / 2;
    top = cy - height / 2;
    right = cx + width / 2;
    bottom = cy + height / 2;
    return _snapRect(Rect.fromLTRB(left, top, right, bottom));
  }

  /// Whether [crop] covers the whole image (within rounding error).
  static bool isFullCrop(Rect crop) {
    const epsilon = 1e-6;
    return crop.left.abs() < epsilon &&
        crop.top.abs() < epsilon &&
        (crop.right - 1).abs() < epsilon &&
        (crop.bottom - 1).abs() < epsilon;
  }

  /// Snaps every edge to a 1e-9 grid so repeated rotations and mirrors
  /// don't accumulate floating-point drift.
  static Rect _snapRect(Rect rect) {
    return Rect.fromLTRB(
      _snap(rect.left),
      _snap(rect.top),
      _snap(rect.right),
      _snap(rect.bottom),
    );
  }

  static double _snap(double value) {
    if (!value.isFinite) return value;
    final snapped = (value * 1e9).roundToDouble() / 1e9;
    // Avoid negative zero, which compares equal but prints oddly.
    return snapped == 0 ? 0 : snapped;
  }

  static double _normalizeAngle(double radians) {
    var result = radians;
    while (result <= -math.pi) {
      result += 2 * math.pi;
    }
    while (result > math.pi) {
      result -= 2 * math.pi;
    }
    return result == 0 ? 0 : result;
  }
}
