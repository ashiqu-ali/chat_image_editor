import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Width of the generated sample image in pixels.
const double sampleImageWidth = 1600;

/// Height of the generated sample image in pixels.
const double sampleImageHeight = 1200;

/// Pixel size of the generated sample image (4:3).
const Size sampleImageSize = Size(sampleImageWidth, sampleImageHeight);

/// Renders the sample scene with `dart:ui` and encodes it as PNG.
///
/// Nothing is bundled or downloaded, so the demos work with zero setup.
Future<Uint8List> generateSampleImage({Size size = sampleImageSize}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  paintSampleScene(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('The sample image could not be encoded.');
    }
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}

/// Paints the sample scene into a widget, for previews.
class SampleScenePainter extends CustomPainter {
  /// Creates the painter.
  const SampleScenePainter();

  @override
  void paint(Canvas canvas, Size size) => paintSampleScene(canvas, size);

  @override
  bool shouldRepaint(SampleScenePainter oldDelegate) => false;
}

/// Paints a dusk landscape filling [size].
///
/// The scene is deliberately lopsided (sun on the right, trees on the left,
/// birds at the top) so rotations and flips are easy to see.
void paintSampleScene(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;
  final unit = h / 1200;
  final horizon = h * 0.68;

  // Sky.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, horizon),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, horizon),
        const <Color>[
          Color(0xFF141C48),
          Color(0xFF5B3A78),
          Color(0xFFE5735F),
          Color(0xFFFFC98B),
        ],
        const <double>[0, 0.45, 0.82, 1],
      ),
  );

  // Stars, from a fixed seed so every run looks the same.
  final random = math.Random(7);
  final starPaint = Paint()..color = const Color(0xBFFFFFFF);
  for (var i = 0; i < 70; i++) {
    final star = Offset(
      random.nextDouble() * w,
      random.nextDouble() * horizon * 0.38,
    );
    canvas.drawCircle(
      star,
      (0.8 + random.nextDouble() * 1.6) * unit,
      starPaint,
    );
  }

  // Sun with a soft glow.
  final sun = Offset(w * 0.68, horizon - h * 0.09);
  final sunRadius = h * 0.085;
  canvas.drawCircle(
    sun,
    sunRadius * 3.2,
    Paint()
      ..shader = ui.Gradient.radial(sun, sunRadius * 3.2, const <Color>[
        Color(0x80FFD9A0),
        Color(0x00FFD9A0),
      ]),
  );
  canvas.drawCircle(sun, sunRadius, Paint()..color = const Color(0xFFFFEBC4));

  // Mountain ridges, back to front.
  _paintRidge(canvas, size, horizon, const Color(0xFF8C5C8C), const <Offset>[
    Offset(0, 0.50),
    Offset(0.10, 0.41),
    Offset(0.22, 0.49),
    Offset(0.36, 0.33),
    Offset(0.50, 0.47),
    Offset(0.62, 0.40),
    Offset(0.78, 0.52),
    Offset(0.90, 0.43),
    Offset(1, 0.48),
  ]);
  _paintRidge(canvas, size, horizon, const Color(0xFF4E3667), const <Offset>[
    Offset(0, 0.58),
    Offset(0.14, 0.50),
    Offset(0.30, 0.60),
    Offset(0.46, 0.52),
    Offset(0.60, 0.62),
    Offset(0.82, 0.55),
    Offset(1, 0.61),
  ]);

  // Lake.
  canvas.drawRect(
    Rect.fromLTWH(0, horizon, w, h - horizon),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, horizon),
        Offset(0, h),
        const <Color>[Color(0xFF3B2D5C), Color(0xFF110E22)],
      ),
  );

  // The sun's reflection on the water.
  for (var i = 0; i < 7; i++) {
    final halfWidth = sunRadius * (1.5 - i * 0.18);
    final y = horizon + h * 0.025 + i * h * 0.032;
    final alpha = 0.6 - i * 0.07;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(sun.dx, y),
          width: halfWidth * 2,
          height: 9 * unit,
        ),
        Radius.circular(5 * unit),
      ),
      Paint()..color = const Color(0xFFFFE2B5).withValues(alpha: alpha),
    );
  }

  // Dark shore with pine trees on the left.
  final shore = Path()
    ..moveTo(0, h * 0.74)
    ..quadraticBezierTo(w * 0.20, h * 0.69, w * 0.42, h * 0.90)
    ..lineTo(w * 0.42, h)
    ..lineTo(0, h)
    ..close();
  final shorePaint = Paint()..color = const Color(0xFF0C0A18);
  canvas.drawPath(shore, shorePaint);
  _paintPine(canvas, Offset(w * 0.07, h * 0.75), h * 0.26, shorePaint);
  _paintPine(canvas, Offset(w * 0.15, h * 0.74), h * 0.19, shorePaint);
  _paintPine(canvas, Offset(w * 0.23, h * 0.76), h * 0.14, shorePaint);

  // Birds.
  final birdPaint = Paint()
    ..color = const Color(0xFF1C1532)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4 * unit
    ..strokeCap = StrokeCap.round;
  _paintBird(canvas, Offset(w * 0.28, h * 0.22), 26 * unit, birdPaint);
  _paintBird(canvas, Offset(w * 0.34, h * 0.27), 20 * unit, birdPaint);
  _paintBird(canvas, Offset(w * 0.24, h * 0.29), 16 * unit, birdPaint);
}

void _paintRidge(
  Canvas canvas,
  Size size,
  double baseline,
  Color color,
  List<Offset> peaks,
) {
  final path = Path()..moveTo(0, baseline);
  for (final peak in peaks) {
    path.lineTo(peak.dx * size.width, peak.dy * size.height);
  }
  path
    ..lineTo(size.width, baseline)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void _paintPine(Canvas canvas, Offset base, double height, Paint paint) {
  final trunkWidth = height * 0.06;
  canvas.drawRect(
    Rect.fromLTWH(
      base.dx - trunkWidth / 2,
      base.dy - height * 0.2,
      trunkWidth,
      height * 0.2,
    ),
    paint,
  );
  for (var tier = 0; tier < 3; tier++) {
    final bottom = base.dy - height * (0.12 + tier * 0.24);
    final halfWidth = height * (0.24 - tier * 0.06);
    final top = bottom - height * 0.42;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - halfWidth, bottom)
        ..lineTo(base.dx, top)
        ..lineTo(base.dx + halfWidth, bottom)
        ..close(),
      paint,
    );
  }
}

void _paintBird(Canvas canvas, Offset center, double span, Paint paint) {
  canvas.drawPath(
    Path()
      ..moveTo(center.dx - span, center.dy)
      ..quadraticBezierTo(
        center.dx - span / 2,
        center.dy - span * 0.6,
        center.dx,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + span / 2,
        center.dy - span * 0.6,
        center.dx + span,
        center.dy,
      ),
    paint,
  );
}
