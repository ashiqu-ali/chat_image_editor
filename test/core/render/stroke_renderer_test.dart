import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

const Size canvasSize = Size(100, 100);
const Color strokeRed = Color(0xFFFF0000);

Stroke stroke(
  ShapeType type,
  List<Offset> points, {
  double width = 0.06,
  Color color = strokeRed,
}) {
  return Stroke(
    id: 's',
    type: type,
    points: points,
    color: color,
    width: width,
  );
}

Future<Pixels> paintStroke(Stroke s, {Size size = canvasSize}) {
  return paintToPixels(
    size.width.toInt(),
    size.height.toInt(),
    (Canvas canvas) => StrokeRenderer.paintStroke(canvas, size, s),
  );
}

void main() {
  test(
    'a line covers its path with the stroke width and nothing else',
    () async {
      final pixels = await paintStroke(
        stroke(ShapeType.line, const <Offset>[
          Offset(0.1, 0.5),
          Offset(0.9, 0.5),
        ]),
      );
      expect(pixels.at(50, 50), rgbaCloseTo(red));
      expect(pixels.at(50, 48), rgbaCloseTo(red));
      expect(pixels.alphaAt(50, 40), 0);
      expect(pixels.alphaAt(3, 50), 0);
    },
  );

  test('a single freehand point paints a round dot', () async {
    final pixels = await paintStroke(
      stroke(ShapeType.freehand, const <Offset>[Offset(0.5, 0.5)], width: 0.1),
    );
    expect(pixels.at(50, 50), rgbaCloseTo(red));
    expect(pixels.at(52, 52), rgbaCloseTo(red));
    expect(pixels.alphaAt(50, 58), 0);
    // Round, not square: the box corner stays empty.
    expect(pixels.alphaAt(54, 54), 0);
  });

  test('freehand strokes are smoothed through the midpoints', () async {
    final pixels = await paintStroke(
      stroke(ShapeType.freehand, const <Offset>[
        Offset(0.1, 0.1),
        Offset(0.5, 0.5),
        Offset(0.9, 0.1),
      ]),
    );
    // Starts and ends on the first and last sample.
    expect(pixels.at(10, 10), rgbaCloseTo(red));
    expect(pixels.at(90, 10), rgbaCloseTo(red));
    // The curve passes (45, 35) instead of the sharp corner at (50, 50).
    expect(pixels.at(45, 35), rgbaCloseTo(red));
    expect(pixels.alphaAt(50, 50), 0);
  });

  test('a rectangle is outlined, not filled', () async {
    final pixels = await paintStroke(
      stroke(ShapeType.rectangle, const <Offset>[
        Offset(0.2, 0.2),
        Offset(0.8, 0.8),
      ], width: 0.04),
    );
    expect(pixels.at(20, 50), rgbaCloseTo(red));
    expect(pixels.at(50, 79), rgbaCloseTo(red));
    expect(pixels.alphaAt(50, 50), 0);
  });

  test('a circle is the ellipse inscribed in the dragged rect', () async {
    final pixels = await paintStroke(
      stroke(ShapeType.circle, const <Offset>[
        Offset(0.2, 0.2),
        Offset(0.8, 0.8),
      ], width: 0.04),
    );
    expect(pixels.at(50, 20), rgbaCloseTo(red));
    expect(pixels.at(20, 50), rgbaCloseTo(red));
    expect(pixels.alphaAt(50, 50), 0);
    expect(pixels.alphaAt(21, 21), 0);
  });

  test('an arrow gets a head at the last point, scaled to the width', () async {
    const points = <Offset>[Offset(0.1, 0.5), Offset(0.9, 0.5)];
    final arrow = await paintStroke(
      stroke(ShapeType.arrow, points, width: 0.04),
    );
    final line = await paintStroke(stroke(ShapeType.line, points, width: 0.04));
    // Head sides run from about (76, 42) and (76, 58) to the tip (90, 50).
    expect(arrow.at(80, 44), rgbaCloseTo(red, tolerance: 40));
    expect(arrow.at(80, 56), rgbaCloseTo(red, tolerance: 40));
    expect(line.alphaAt(80, 44), 0);
    // No head at the tail.
    expect(arrow.alphaAt(14, 44), 0);

    final thick = await paintStroke(
      stroke(ShapeType.arrow, points, width: 0.06),
    );
    // A thicker stroke has a longer head: about 24 px instead of 16.
    expect(thick.at(70, 40), rgbaCloseTo(red, tolerance: 40));
    expect(arrow.alphaAt(70, 40), 0);
  });

  test('shapes with no extent paint a dot', () async {
    for (final type in ShapeType.values) {
      final pixels = await paintStroke(
        stroke(type, const <Offset>[Offset(0.5, 0.5), Offset(0.5, 0.5)]),
      );
      expect(pixels.at(50, 50), rgbaCloseTo(red), reason: '$type');
    }
  });

  test('stroke width is relative to the shortest side', () async {
    final pixels = await paintStroke(
      stroke(ShapeType.line, const <Offset>[
        Offset(0.1, 0.5),
        Offset(0.9, 0.5),
      ], width: 0.1),
      size: const Size(200, 50),
    );
    // 0.1 × 50 = 5 px wide, centered on y = 25.
    expect(pixels.at(100, 23), rgbaCloseTo(red));
    expect(pixels.alphaAt(100, 20), 0);
  });

  test('paint draws strokes in order', () async {
    const blueColor = Color(0xFF0000FF);
    final pixels = await paintToPixels(100, 100, (Canvas canvas) {
      StrokeRenderer.paint(canvas, canvasSize, <Stroke>[
        stroke(ShapeType.line, const <Offset>[
          Offset(0.1, 0.5),
          Offset(0.9, 0.5),
        ]),
        stroke(ShapeType.line, const <Offset>[
          Offset(0.5, 0.1),
          Offset(0.5, 0.9),
        ], color: blueColor),
      ]);
    });
    expect(pixels.at(50, 50), rgbaCloseTo(blue));
    expect(pixels.at(20, 50), rgbaCloseTo(red));
  });

  test('empty strokes and an empty size paint nothing', () async {
    final empty = await paintStroke(
      stroke(ShapeType.freehand, const <Offset>[]),
    );
    expect(empty.bytes.every((int b) => b == 0), isTrue);

    final noSize = await paintToPixels(
      10,
      10,
      (Canvas canvas) => StrokeRenderer.paintStroke(
        canvas,
        Size.zero,
        stroke(ShapeType.line, const <Offset>[Offset.zero, Offset(1, 1)]),
      ),
    );
    expect(noSize.bytes.every((int b) => b == 0), isTrue);
  });
}
