import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'editor_enums.dart';

/// One drawn stroke or shape.
///
/// Coordinates live in **normalized original-image space**: `(0, 0)` is the
/// top-left and `(1, 1)` the bottom-right of the source photo, before any
/// crop, rotation or flip. That keeps strokes glued to the picture through
/// every transform and lets them export at full resolution.
@immutable
class Stroke {
  /// Creates a stroke.
  const Stroke({
    required this.id,
    required this.type,
    required this.points,
    required this.color,
    required this.width,
  });

  /// Unique id within the editor session.
  final String id;

  /// What kind of shape this is.
  final ShapeType type;

  /// Sampled points. Freehand keeps every sample; the other shapes use the
  /// first and last point only.
  final List<Offset> points;

  /// Stroke color.
  final Color color;

  /// Stroke width as a fraction of the original image's shortest side.
  final double width;

  /// Returns a copy with the given fields replaced.
  Stroke copyWith({
    String? id,
    ShapeType? type,
    List<Offset>? points,
    Color? color,
    double? width,
  }) {
    return Stroke(
      id: id ?? this.id,
      type: type ?? this.type,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Stroke &&
        other.id == id &&
        other.type == type &&
        other.color == color &&
        other.width == width &&
        listEquals(other.points, points);
  }

  @override
  int get hashCode =>
      Object.hash(id, type, color, width, Object.hashAll(points));
}
