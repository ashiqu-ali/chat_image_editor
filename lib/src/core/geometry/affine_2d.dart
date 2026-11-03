import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A 2D affine transform: `x' = a·x + c·y + tx`, `y' = b·x + d·y + ty`.
///
/// Internal helper for `ImageGeometry`; it keeps the arithmetic exact for the
/// quarter-turn and flip transforms the editor uses, and converts to a
/// [Matrix4] for canvases.
@immutable
class Affine2D {
  /// Creates a transform from its six coefficients.
  const Affine2D(this.a, this.b, this.c, this.d, this.tx, this.ty);

  /// A translation by ([x], [y]).
  const Affine2D.translation(double x, double y) : this(1, 0, 0, 1, x, y);

  /// A clockwise rotation by [radians] around the origin (y axis down).
  factory Affine2D.rotation(double radians) {
    final cos = _cleanTrig(math.cos(radians));
    final sin = _cleanTrig(math.sin(radians));
    return Affine2D(cos, sin, -sin, cos, 0, 0);
  }

  /// A scale by ([x], [y]) around the origin.
  const Affine2D.scale(double x, double y) : this(x, 0, 0, y, 0, 0);

  /// Reads the 2D part of [matrix].
  factory Affine2D.fromMatrix4(Matrix4 matrix) {
    final s = matrix.storage;
    return Affine2D(s[0], s[1], s[4], s[5], s[12], s[13]);
  }

  /// The identity transform.
  static const Affine2D identity = Affine2D(1, 0, 0, 1, 0, 0);

  /// How x' depends on x.
  final double a;

  /// How y' depends on x.
  final double b;

  /// How x' depends on y.
  final double c;

  /// How y' depends on y.
  final double d;

  /// Translation along x.
  final double tx;

  /// Translation along y.
  final double ty;

  /// Determinant of the linear part. Negative when the transform mirrors.
  double get determinant => a * d - b * c;

  /// The linear part only, without translation.
  Affine2D get linear => Affine2D(a, b, c, d, 0, 0);

  /// `this ∘ other`: applies [other] first, then this transform.
  Affine2D operator *(Affine2D other) {
    return Affine2D(
      a * other.a + c * other.b,
      b * other.a + d * other.b,
      a * other.c + c * other.d,
      b * other.c + d * other.d,
      a * other.tx + c * other.ty + tx,
      b * other.tx + d * other.ty + ty,
    );
  }

  /// Maps a point.
  Offset apply(Offset point) {
    return Offset(
      a * point.dx + c * point.dy + tx,
      b * point.dx + d * point.dy + ty,
    );
  }

  /// Maps a direction (ignores translation).
  Offset applyVector(Offset vector) {
    return Offset(a * vector.dx + c * vector.dy, b * vector.dx + d * vector.dy);
  }

  /// The inverse transform. The editor's transforms are never singular;
  /// a singular transform returns [identity].
  Affine2D inverse() {
    final det = determinant;
    if (det == 0 || !det.isFinite) return identity;
    final ia = d / det;
    final ib = -b / det;
    final ic = -c / det;
    final id = a / det;
    return Affine2D(ia, ib, ic, id, -(ia * tx + ic * ty), -(ib * tx + id * ty));
  }

  /// The same transform as a column-major [Matrix4].
  Matrix4 toMatrix4() {
    return Matrix4(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  @override
  bool operator ==(Object other) {
    return other is Affine2D &&
        other.a == a &&
        other.b == b &&
        other.c == c &&
        other.d == d &&
        other.tx == tx &&
        other.ty == ty;
  }

  @override
  int get hashCode => Object.hash(a, b, c, d, tx, ty);

  @override
  String toString() => 'Affine2D($a, $b, $c, $d, $tx, $ty)';
}

/// Snaps values that are within rounding error of 0 or ±1 to the exact
/// value, so quarter-turn rotations stay exact.
double _cleanTrig(double value) {
  const epsilon = 1e-12;
  if (value.abs() < epsilon) return 0;
  if ((value - 1).abs() < epsilon) return 1;
  if ((value + 1).abs() < epsilon) return -1;
  return value;
}
