import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'stroke.dart';
import 'text_layer.dart';

/// The complete, immutable set of edits applied to an image.
///
/// This is the "document" of the editor: undo and redo step between
/// `ImageEditValue` snapshots, and export renders exactly one of them.
///
/// ## Coordinate spaces
///
/// * **Original space**: normalized `0..1` over the source photo, before any
///   transform. [strokes] and [texts] live here.
/// * **Transformed space**: the source photo after [flipX]/[flipY] and then
///   [quarterTurns] clockwise quarter turns. [crop] is normalized `0..1`
///   over this space.
/// * **View space**: normalized `0..1` over the final, cropped output, which
///   is what the user sees while drawing or placing text.
@immutable
class ImageEditValue {
  /// Creates an edit value. The defaults describe an untouched image.
  const ImageEditValue({
    this.strokes = const <Stroke>[],
    this.texts = const <TextLayer>[],
    this.crop,
    this.quarterTurns = 0,
    this.flipX = false,
    this.flipY = false,
    this.quality,
  }) : assert(quarterTurns >= 0 && quarterTurns < 4);

  /// An untouched image.
  static const ImageEditValue empty = ImageEditValue();

  /// Committed strokes in drawing order.
  final List<Stroke> strokes;

  /// Text layers in paint order (last is on top).
  final List<TextLayer> texts;

  /// Crop rectangle, normalized over transformed space, or `null` for the
  /// full image.
  final Rect? crop;

  /// Clockwise quarter turns, `0` to `3`, applied after the flips.
  final int quarterTurns;

  /// Mirror left-right in original space, applied before [quarterTurns].
  final bool flipX;

  /// Mirror top-bottom in original space, applied before [quarterTurns].
  final bool flipY;

  /// Quality (1–100) picked in the compress tool, or `null` if the user
  /// didn't pick one.
  final int? quality;

  /// Whether anything differs from an untouched image.
  bool get hasChanges => this != empty;

  /// Returns a copy with the given fields replaced. Pass [clearCrop] or
  /// [clearQuality] to reset those nullable fields to `null`.
  ImageEditValue copyWith({
    List<Stroke>? strokes,
    List<TextLayer>? texts,
    Rect? crop,
    bool clearCrop = false,
    int? quarterTurns,
    bool? flipX,
    bool? flipY,
    int? quality,
    bool clearQuality = false,
  }) {
    return ImageEditValue(
      strokes: strokes ?? this.strokes,
      texts: texts ?? this.texts,
      crop: clearCrop ? null : (crop ?? this.crop),
      quarterTurns: quarterTurns ?? this.quarterTurns,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      quality: clearQuality ? null : (quality ?? this.quality),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImageEditValue &&
        listEquals(other.strokes, strokes) &&
        listEquals(other.texts, texts) &&
        other.crop == crop &&
        other.quarterTurns == quarterTurns &&
        other.flipX == flipX &&
        other.flipY == flipY &&
        other.quality == quality;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(strokes),
    Object.hashAll(texts),
    crop,
    quarterTurns,
    flipX,
    flipY,
    quality,
  );
}
