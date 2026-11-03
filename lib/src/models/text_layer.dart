import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'editor_enums.dart';

/// One text overlay.
///
/// Like `Stroke`, a text layer is stored in **normalized original-image
/// space** so it stays attached to the picture through crop, rotation and
/// flips and renders identically in the preview and the export.
@immutable
class TextLayer {
  /// Creates a text layer.
  const TextLayer({
    required this.id,
    required this.text,
    required this.position,
    required this.fontSize,
    required this.color,
    this.rotation = 0,
    this.mirrored = false,
    this.background = TextBackgroundStyle.none,
  });

  /// Unique id within the editor session.
  final String id;

  /// The text content. May contain line breaks and emoji.
  final String text;

  /// Center of the text block in normalized original-image space.
  final Offset position;

  /// Font size as a fraction of the original image's shortest side.
  final double fontSize;

  /// Text color.
  final Color color;

  /// Clockwise rotation in radians, applied in original-image space.
  ///
  /// When a layer is created on a rotated or flipped image the controller
  /// sets this (and [mirrored]) so the text reads upright on screen.
  final double rotation;

  /// Whether the glyphs are mirrored horizontally in original-image space.
  ///
  /// Used to keep text readable when it's created while the image is
  /// flipped.
  final bool mirrored;

  /// Background drawn behind the text.
  final TextBackgroundStyle background;

  /// Returns a copy with the given fields replaced.
  TextLayer copyWith({
    String? id,
    String? text,
    Offset? position,
    double? fontSize,
    Color? color,
    double? rotation,
    bool? mirrored,
    TextBackgroundStyle? background,
  }) {
    return TextLayer(
      id: id ?? this.id,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      rotation: rotation ?? this.rotation,
      mirrored: mirrored ?? this.mirrored,
      background: background ?? this.background,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TextLayer &&
        other.id == id &&
        other.text == text &&
        other.position == position &&
        other.fontSize == fontSize &&
        other.color == color &&
        other.rotation == rotation &&
        other.mirrored == mirrored &&
        other.background == background;
  }

  @override
  int get hashCode => Object.hash(
    id,
    text,
    position,
    fontSize,
    color,
    rotation,
    mirrored,
    background,
  );
}
