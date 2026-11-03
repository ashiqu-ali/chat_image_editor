import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

const Size canvasSize = Size(100, 100);
const TextStyle baseStyle = TextStyle(height: 1);

TextLayer layer({
  String text = 'A',
  Offset position = const Offset(0.5, 0.5),
  double fontSize = 0.3,
  Color color = const Color(0xFFFF0000),
  double rotation = 0,
  bool mirrored = false,
  TextBackgroundStyle background = TextBackgroundStyle.none,
  String id = 't',
}) {
  return TextLayer(
    id: id,
    text: text,
    position: position,
    fontSize: fontSize,
    color: color,
    rotation: rotation,
    mirrored: mirrored,
    background: background,
  );
}

Future<Pixels> paintLayer(TextLayer l) {
  return paintToPixels(
    100,
    100,
    (Canvas canvas) =>
        TextRenderer.paintLayer(canvas, canvasSize, l, baseStyle: baseStyle),
  );
}

void main() {
  group('measure', () {
    test('includes padding around the text', () {
      final l = layer(text: 'AB');
      final painter = TextPainter(
        text: TextSpan(text: 'AB', style: baseStyle.copyWith(fontSize: 30)),
        textDirection: TextDirection.ltr,
      )..layout();
      final size = TextRenderer.measure(l, canvasSize, baseStyle: baseStyle);
      expect(size.width, greaterThan(painter.width));
      expect(size.height, greaterThan(painter.height));
      painter.dispose();
    });

    test('scales with the font size and the image', () {
      final small = TextRenderer.measure(
        layer(fontSize: 0.1),
        canvasSize,
        baseStyle: baseStyle,
      );
      final big = TextRenderer.measure(
        layer(fontSize: 0.2),
        canvasSize,
        baseStyle: baseStyle,
      );
      final bigImage = TextRenderer.measure(
        layer(fontSize: 0.1),
        const Size(200, 400),
        baseStyle: baseStyle,
      );
      expect(big.width, closeTo(small.width * 2, 1));
      expect(big.height, closeTo(small.height * 2, 1));
      expect(bigImage.width, closeTo(small.width * 2, 1));
    });

    test('is the same for every background style', () {
      final sizes = <Size>{
        for (final style in TextBackgroundStyle.values)
          TextRenderer.measure(
            layer(background: style),
            canvasSize,
            baseStyle: baseStyle,
          ),
      };
      expect(sizes, hasLength(1));
    });

    test('grows with more text and more lines', () {
      final one = TextRenderer.measure(
        layer(text: 'A'),
        canvasSize,
        baseStyle: baseStyle,
      );
      final three = TextRenderer.measure(
        layer(text: 'AAA'),
        canvasSize,
        baseStyle: baseStyle,
      );
      final twoLines = TextRenderer.measure(
        layer(text: 'A\nA'),
        canvasSize,
        baseStyle: baseStyle,
      );
      expect(three.width, greaterThan(one.width));
      expect(twoLines.height, greaterThan(one.height));
    });
  });

  group('hitTest', () {
    final wide = layer(text: 'ABCDEFGH', fontSize: 0.05);

    test('hits the center and misses far away', () {
      expect(
        TextRenderer.hitTest(
          wide,
          const Offset(50, 50),
          canvasSize,
          baseStyle: baseStyle,
        ),
        isTrue,
      );
      expect(
        TextRenderer.hitTest(
          wide,
          const Offset(50, 90),
          canvasSize,
          baseStyle: baseStyle,
        ),
        isFalse,
      );
    });

    test('slop grows the hit area', () {
      final size = TextRenderer.measure(wide, canvasSize, baseStyle: baseStyle);
      final justOutside = Offset(50, 50 + size.height / 2 + 3);
      expect(
        TextRenderer.hitTest(
          wide,
          justOutside,
          canvasSize,
          baseStyle: baseStyle,
        ),
        isFalse,
      );
      expect(
        TextRenderer.hitTest(
          wide,
          justOutside,
          canvasSize,
          baseStyle: baseStyle,
          slop: 4,
        ),
        isTrue,
      );
    });

    test('follows the rotation', () {
      final size = TextRenderer.measure(wide, canvasSize, baseStyle: baseStyle);
      final along = size.width / 2 - 2;
      final turned = wide.copyWith(rotation: math.pi / 2);
      expect(
        TextRenderer.hitTest(
          wide,
          Offset(50 + along, 50),
          canvasSize,
          baseStyle: baseStyle,
        ),
        isTrue,
      );
      expect(
        TextRenderer.hitTest(
          turned,
          Offset(50 + along, 50),
          canvasSize,
          baseStyle: baseStyle,
        ),
        isFalse,
      );
      expect(
        TextRenderer.hitTest(
          turned,
          Offset(50, 50 + along),
          canvasSize,
          baseStyle: baseStyle,
        ),
        isTrue,
      );
    });
  });

  group('paintLayer', () {
    test('draws text only, in the layer color, without a background', () async {
      final pixels = await paintLayer(layer());
      expect(pixels.at(50, 50), rgbaCloseTo(red));
      final block = TextRenderer.measure(
        layer(),
        canvasSize,
        baseStyle: baseStyle,
      );
      // Inside the padding but outside the glyph.
      expect(pixels.alphaAt(50, (50 - block.height / 2 + 1).round()), 0);
    });

    test(
      'solid draws a box in the layer color with contrasting text',
      () async {
        final whiteLayer = layer(
          color: const Color(0xFFFFFFFF),
          background: TextBackgroundStyle.solid,
        );
        final pixels = await paintLayer(whiteLayer);
        final block = TextRenderer.measure(
          whiteLayer,
          canvasSize,
          baseStyle: baseStyle,
        );
        expect(pixels.at(50, 50), rgbaCloseTo(black));
        expect(
          pixels.at(50, (50 - block.height / 2 + 2).round()),
          rgbaCloseTo(white),
        );

        final darkLayer = layer(
          color: const Color(0xFF000080),
          background: TextBackgroundStyle.solid,
        );
        final dark = await paintLayer(darkLayer);
        expect(dark.at(50, 50), rgbaCloseTo(white));
        expect(
          dark.at(50, (50 - block.height / 2 + 2).round()),
          rgbaCloseTo(const <int>[0, 0, 128, 255]),
        );
      },
    );

    test('translucent draws a half-transparent black box', () async {
      final l = layer(background: TextBackgroundStyle.translucent);
      final pixels = await paintLayer(l);
      final block = TextRenderer.measure(l, canvasSize, baseStyle: baseStyle);
      expect(pixels.at(50, 50), rgbaCloseTo(red));
      expect(
        pixels.at(50, (50 - block.height / 2 + 2).round()),
        rgbaCloseTo(const <int>[0, 0, 0, 128], tolerance: 4),
      );
    });

    test('mirrors the glyphs', () async {
      // A leading space puts the glyph on the right half of the block.
      final plain = await paintLayer(layer(text: ' A'));
      final mirrored = await paintLayer(layer(text: ' A', mirrored: true));
      expect(plain.alphaAt(35, 50), 0);
      expect(plain.at(65, 50), rgbaCloseTo(red));
      expect(mirrored.at(35, 50), rgbaCloseTo(red));
      expect(mirrored.alphaAt(65, 50), 0);
    });

    test('rotates clockwise', () async {
      final turned = await paintLayer(layer(text: ' A', rotation: math.pi / 2));
      // The glyph's local +x side now points down.
      expect(turned.at(50, 65), rgbaCloseTo(red));
      expect(turned.alphaAt(50, 35), 0);
    });

    test('centers the block on the position', () async {
      final pixels = await paintLayer(
        layer(position: const Offset(0.2, 0.8), fontSize: 0.1),
      );
      expect(pixels.at(20, 80), rgbaCloseTo(red));
      expect(pixels.alphaAt(50, 50), 0);
    });

    test('skips empty text', () async {
      final pixels = await paintLayer(
        layer(text: '', background: TextBackgroundStyle.solid),
      );
      expect(pixels.bytes.every((int b) => b == 0), isTrue);
    });
  });

  test('paint draws layers in order and skips hidden ids', () async {
    const blueText = Color(0xFF0000FF);
    final layers = <TextLayer>[layer(id: 'a'), layer(id: 'b', color: blueText)];
    final both = await paintToPixels(
      100,
      100,
      (Canvas canvas) =>
          TextRenderer.paint(canvas, canvasSize, layers, baseStyle: baseStyle),
    );
    expect(both.at(50, 50), rgbaCloseTo(blue));

    final hidden = await paintToPixels(
      100,
      100,
      (Canvas canvas) => TextRenderer.paint(
        canvas,
        canvasSize,
        layers,
        baseStyle: baseStyle,
        hiddenIds: const <String>{'b'},
      ),
    );
    expect(hidden.at(50, 50), rgbaCloseTo(red));
  });
}
