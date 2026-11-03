import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/editor_enums.dart';
import '../../models/stroke.dart';

/// Paints strokes. Shared by the live preview and the export so both look
/// identical.
abstract final class StrokeRenderer {
  /// Arrowhead length as a multiple of the stroke width.
  static const double _arrowHeadLengthFactor = 4;

  /// Angle between the arrow shaft and each side of the head.
  static const double _arrowHeadAngle = math.pi / 6;

  /// Longest arrowhead relative to the arrow's length, so short arrows keep
  /// a visible shaft.
  static const double _maxArrowHeadFraction = 0.6;

  /// Shapes shorter than this (in original pixels) paint as a dot.
  static const double _degenerateLength = 0.5;

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
    for (final stroke in strokes) {
      paintStroke(canvas, originalSize, stroke);
    }
  }

  /// Paints a single [stroke]. Freehand strokes are smoothed; arrows get an
  /// arrowhead scaled to the stroke width.
  static void paintStroke(Canvas canvas, Size originalSize, Stroke stroke) {
    if (stroke.points.isEmpty ||
        originalSize.width <= 0 ||
        originalSize.height <= 0) {
      return;
    }
    final width = stroke.width * originalSize.shortestSide;
    if (width <= 0 || !width.isFinite) return;

    final points = <Offset>[
      for (final p in stroke.points)
        Offset(p.dx * originalSize.width, p.dy * originalSize.height),
    ];
    final paint = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final first = points.first;
    final last = points.last;
    final isDegenerate = (last - first).distance < _degenerateLength;

    switch (stroke.type) {
      case ShapeType.freehand:
        if (_isDot(points)) {
          _paintDot(canvas, first, width, stroke.color);
        } else {
          canvas.drawPath(_smoothPath(points), paint);
        }
      case ShapeType.line:
        if (isDegenerate) {
          _paintDot(canvas, first, width, stroke.color);
        } else {
          canvas.drawLine(first, last, paint);
        }
      case ShapeType.rectangle:
        if (isDegenerate) {
          _paintDot(canvas, first, width, stroke.color);
        } else {
          canvas.drawRect(Rect.fromPoints(first, last), paint);
        }
      case ShapeType.circle:
        if (isDegenerate) {
          _paintDot(canvas, first, width, stroke.color);
        } else {
          canvas.drawOval(Rect.fromPoints(first, last), paint);
        }
      case ShapeType.arrow:
        if (isDegenerate) {
          _paintDot(canvas, first, width, stroke.color);
        } else {
          canvas.drawPath(_arrowPath(first, last, width), paint);
        }
    }
  }

  static bool _isDot(List<Offset> points) {
    final first = points.first;
    for (final p in points) {
      if ((p - first).distance >= _degenerateLength) return false;
    }
    return true;
  }

  static void _paintDot(Canvas canvas, Offset center, double width, Color c) {
    canvas.drawCircle(
      center,
      width / 2,
      Paint()
        ..color = c
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  /// Quadratic curves through the midpoints of consecutive samples, using
  /// each sample as the control point. Smooth, and it passes through the
  /// first and last sample.
  static Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 2) {
      path.lineTo(points.last.dx, points.last.dy);
      return path;
    }
    for (var i = 1; i < points.length - 1; i++) {
      final control = points[i];
      final next = points[i + 1];
      final mid = Offset(
        (control.dx + next.dx) / 2,
        (control.dy + next.dy) / 2,
      );
      path.quadraticBezierTo(control.dx, control.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  /// Shaft plus an open arrowhead at [tip], in one path so translucent
  /// colors don't double up where they overlap.
  static Path _arrowPath(Offset tail, Offset tip, double width) {
    final shaft = tip - tail;
    final length = shaft.distance;
    final headLength = math.min(
      width * _arrowHeadLengthFactor,
      length * _maxArrowHeadFraction,
    );
    final back = Offset(-shaft.dx / length, -shaft.dy / length);
    final left = tip + _rotate(back, _arrowHeadAngle) * headLength;
    final right = tip + _rotate(back, -_arrowHeadAngle) * headLength;
    return Path()
      ..moveTo(tail.dx, tail.dy)
      ..lineTo(tip.dx, tip.dy)
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy);
  }

  static Offset _rotate(Offset v, double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(v.dx * cos - v.dy * sin, v.dx * sin + v.dy * cos);
  }
}
