import 'dart:typed_data';

import 'package:chat_image_editor/src/core/loading/image_loader.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';

void main() {
  test('decodes at full size without a limit', () async {
    final loaded = await ImageLoader.decode(quadrantPng(60, 40));
    addTearDown(loaded.image.dispose);
    expect(loaded.originalSize, const Size(60, 40));
    expect(loaded.image.width, 60);
    expect(loaded.image.height, 40);
  });

  test('decodes landscape images down to the long-edge limit', () async {
    final loaded = await ImageLoader.decode(
      quadrantPng(60, 40),
      maxLongEdge: 30,
    );
    addTearDown(loaded.image.dispose);
    expect(loaded.originalSize, const Size(60, 40));
    expect(loaded.image.width, 30);
    expect(loaded.image.height, 20);
  });

  test('decodes portrait images down to the long-edge limit', () async {
    final loaded = await ImageLoader.decode(
      quadrantPng(40, 80),
      maxLongEdge: 20,
    );
    addTearDown(loaded.image.dispose);
    expect(loaded.originalSize, const Size(40, 80));
    expect(loaded.image.width, 10);
    expect(loaded.image.height, 20);
  });

  test('never scales up', () async {
    final loaded = await ImageLoader.decode(
      quadrantPng(20, 10),
      maxLongEdge: 100,
    );
    addTearDown(loaded.image.dispose);
    expect(loaded.image.width, 20);
    expect(loaded.image.height, 10);
  });

  test('keeps the pixels', () async {
    final loaded = await ImageLoader.decode(quadrantPng(20, 20));
    addTearDown(loaded.image.dispose);
    final pixels = await imageToPixels(loaded.image);
    expect(pixels.at(2, 2), rgbaCloseTo(red));
    expect(pixels.at(17, 17), rgbaCloseTo(yellow));
  });

  test('throws for bytes that are not an image', () {
    expect(
      ImageLoader.decode(Uint8List.fromList(<int>[1, 2, 3, 4, 5])),
      throwsA(anything),
    );
  });

  group('targetSize', () {
    test('is null when no reduction is needed', () {
      expect(ImageLoader.targetSize(100, 50, null), isNull);
      expect(ImageLoader.targetSize(100, 50, 100), isNull);
      expect(ImageLoader.targetSize(100, 50, 0), isNull);
    });

    test('limits only the long side', () {
      expect(ImageLoader.targetSize(100, 50, 40), (width: 40, height: null));
      expect(ImageLoader.targetSize(50, 100, 40), (width: null, height: 40));
    });
  });
}
