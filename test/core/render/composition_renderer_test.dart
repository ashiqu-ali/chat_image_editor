import 'dart:ui' as ui;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/loading/image_loader.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

const Size original = Size(40, 40);
const TextStyle textStyle = TextStyle(height: 1);

void main() {
  late ui.Image quadrants;

  setUpAll(() async {
    quadrants = (await ImageLoader.decode(quadrantPng(40, 40))).image;
  });

  tearDownAll(() => quadrants.dispose());

  Future<Pixels> render(
    ImageEditValue value, {
    ui.Image? image,
    Size originalSize = original,
    Stroke? draftStroke,
    Set<String> hiddenTextIds = const <String>{},
    bool paintStrokes = true,
    bool paintTexts = true,
    Size? canvas,
  }) {
    final output = canvas ?? ImageGeometry.outputSize(originalSize, value);
    return paintToPixels(
      output.width.round(),
      output.height.round(),
      (Canvas c) => CompositionRenderer.paint(
        c,
        image: image ?? quadrants,
        originalSize: originalSize,
        value: value,
        textStyle: textStyle,
        draftStroke: draftStroke,
        hiddenTextIds: hiddenTextIds,
        paintStrokes: paintStrokes,
        paintTexts: paintTexts,
      ),
    );
  }

  /// Colors at the centers of the output's four quadrants: top-left,
  /// top-right, bottom-left, bottom-right.
  List<List<int>> corners(Pixels p) {
    final w = p.width;
    final h = p.height;
    return <List<int>>[
      p.at(w ~/ 4, h ~/ 4),
      p.at(w * 3 ~/ 4, h ~/ 4),
      p.at(w ~/ 4, h * 3 ~/ 4),
      p.at(w * 3 ~/ 4, h * 3 ~/ 4),
    ];
  }

  void expectCorners(Pixels p, List<List<int>> expected, String reason) {
    final actual = corners(p);
    for (var i = 0; i < 4; i++) {
      expect(actual[i], rgbaCloseTo(expected[i]), reason: '$reason #$i');
    }
  }

  test('paints the image unchanged without edits', () async {
    expectCorners(await render(ImageEditValue.empty), <List<int>>[
      red,
      green,
      blue,
      yellow,
    ], 'identity');
  });

  test('rotates and flips the image', () async {
    expectCorners(
      await render(const ImageEditValue(quarterTurns: 1)),
      <List<int>>[blue, red, yellow, green],
      'clockwise',
    );
    expectCorners(
      await render(const ImageEditValue(quarterTurns: 2)),
      <List<int>>[yellow, blue, green, red],
      'half turn',
    );
    expectCorners(
      await render(const ImageEditValue(quarterTurns: 3)),
      <List<int>>[green, yellow, red, blue],
      'counter-clockwise',
    );
    expectCorners(await render(const ImageEditValue(flipX: true)), <List<int>>[
      green,
      red,
      yellow,
      blue,
    ], 'flipX');
    expectCorners(await render(const ImageEditValue(flipY: true)), <List<int>>[
      blue,
      yellow,
      red,
      green,
    ], 'flipY');
    expectCorners(
      await render(const ImageEditValue(quarterTurns: 1, flipX: true)),
      <List<int>>[yellow, green, blue, red],
      'flipX then clockwise',
    );
  });

  test('crops after rotating', () async {
    final topRight = await render(
      const ImageEditValue(crop: Rect.fromLTRB(0.5, 0, 1, 0.5)),
    );
    expect(topRight.width, 20);
    expectCorners(topRight, <List<int>>[green, green, green, green], 'crop');

    // Turned clockwise, the original bottom-left (blue) is top-left.
    final turned = await render(
      const ImageEditValue(
        quarterTurns: 1,
        crop: Rect.fromLTRB(0, 0, 0.5, 0.5),
      ),
    );
    expectCorners(turned, <List<int>>[blue, blue, blue, blue], 'turned crop');
  });

  test('stretches a smaller preview image over the original size', () async {
    final preview = (await ImageLoader.decode(
      quadrantPng(40, 40),
      maxLongEdge: 10,
    )).image;
    addTearDown(preview.dispose);
    expect(preview.width, 10);
    expectCorners(
      await render(ImageEditValue.empty, image: preview),
      <List<int>>[red, green, blue, yellow],
      'preview',
    );
  });

  test('handles non-square originals', () async {
    final wide = (await ImageLoader.decode(quadrantPng(40, 20))).image;
    addTearDown(wide.dispose);
    final pixels = await render(
      const ImageEditValue(quarterTurns: 1),
      image: wide,
      originalSize: const Size(40, 20),
    );
    expect(pixels.width, 20);
    expect(pixels.height, 40);
    expectCorners(pixels, <List<int>>[blue, red, yellow, green], 'wide');
  });

  const line = Stroke(
    id: 's',
    type: ShapeType.line,
    points: <Offset>[Offset(0, 0.25), Offset(1.5, 0.25)],
    color: Color(0xFF000000),
    width: 0.1,
  );

  test('paints strokes in original space and clips to the output', () async {
    final pixels = await render(
      const ImageEditValue(strokes: <Stroke>[line]),
      canvas: const Size(60, 60),
    );
    expect(pixels.at(30, 10), rgbaCloseTo(black));
    expect(pixels.at(10, 10), rgbaCloseTo(black));
    // The stroke runs past the image, but the output is only 40 px wide.
    expect(pixels.alphaAt(50, 10), 0);

    final turned = await render(
      const ImageEditValue(quarterTurns: 1, strokes: <Stroke>[line]),
    );
    // A horizontal line at y = 10 becomes a vertical one at x = 40 - 10.
    expect(turned.at(30, 10), rgbaCloseTo(black));
    expect(turned.at(30, 35), rgbaCloseTo(black));
    expect(turned.at(10, 30), isNot(rgbaCloseTo(black)));
  });

  test('paintStrokes false skips strokes and the draft', () async {
    final pixels = await render(
      const ImageEditValue(strokes: <Stroke>[line]),
      draftStroke: line,
      paintStrokes: false,
    );
    expect(pixels.at(10, 10), rgbaCloseTo(red));
  });

  test('paints the draft stroke on top', () async {
    final pixels = await render(ImageEditValue.empty, draftStroke: line);
    expect(pixels.at(10, 10), rgbaCloseTo(black));
  });

  const label = TextLayer(
    id: 't',
    text: 'A',
    position: Offset(0.25, 0.25),
    fontSize: 0.25,
    color: Color(0xFFFFFFFF),
  );

  test('paints text unless hidden or disabled', () async {
    const value = ImageEditValue(texts: <TextLayer>[label]);
    expect((await render(value)).at(10, 10), rgbaCloseTo(white));
    expect(
      (await render(value, hiddenTextIds: const <String>{'t'})).at(10, 10),
      rgbaCloseTo(red),
    );
    expect(
      (await render(value, paintTexts: false)).at(10, 10),
      rgbaCloseTo(red),
    );
  });
}
