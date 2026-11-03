import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../test_utils.dart';

RgbaImage rgba(int width, int height, List<int> Function(int x, int y) at) {
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      pixels.setAll((y * width + x) * 4, at(x, y));
    }
  }
  return RgbaImage(pixels: pixels, width: width, height: height);
}

RgbaImage noisy(int width, int height) {
  final decoded = img.decodePng(noisyPng(width, height))!;
  return rgba(width, height, (int x, int y) => decodedPixel(decoded, x, y));
}

void main() {
  const encoder = DartImageEncoder();

  test('PNG keeps straight alpha', () async {
    final image = rgba(
      4,
      2,
      (int x, int y) => x < 2 ? <int>[255, 0, 0, 255] : <int>[0, 0, 255, 64],
    );
    final bytes = await encoder.encode(image, format: ExportFormat.png);
    expect(bytes.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
    final decoded = img.decodePng(bytes)!;
    expect(decoded.width, 4);
    expect(decoded.height, 2);
    expect(decodedPixel(decoded, 0, 0), <int>[255, 0, 0, 255]);
    expect(decodedPixel(decoded, 3, 1), <int>[0, 0, 255, 64]);
  });

  test('opaque PNG round-trips exactly', () async {
    final image = noisy(16, 12);
    final bytes = await encoder.encode(image, format: ExportFormat.png);
    final decoded = img.decodePng(bytes)!;
    for (final p in const <List<int>>[
      <int>[0, 0],
      <int>[15, 11],
      <int>[7, 5],
    ]) {
      final i = (p[1] * 16 + p[0]) * 4;
      expect(decodedPixel(decoded, p[0], p[1]), image.pixels.sublist(i, i + 4));
    }
  });

  test('JPEG decodes to the same size and similar colors', () async {
    final image = rgba(16, 8, (int x, int y) => <int>[200, 40, 40, 255]);
    final bytes = await encoder.encode(
      image,
      format: ExportFormat.jpeg,
      quality: 95,
    );
    expect(bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    final decoded = img.decodeJpg(bytes)!;
    expect(decoded.width, 16);
    expect(decoded.height, 8);
    expect(decodedPixel(decoded, 8, 4), rgbaCloseTo(<int>[200, 40, 40, 255]));
  });

  test('lower JPEG quality gives smaller files', () async {
    final image = noisy(64, 64);
    final high = await encoder.encode(
      image,
      format: ExportFormat.jpeg,
      quality: 95,
    );
    final low = await encoder.encode(
      image,
      format: ExportFormat.jpeg,
      quality: 20,
    );
    expect(low.length, lessThan(high.length));
  });

  test('out-of-range quality is clamped', () async {
    final image = noisy(16, 16);
    final clamped = await encoder.encode(
      image,
      format: ExportFormat.jpeg,
      quality: 500,
    );
    final max = await encoder.encode(
      image,
      format: ExportFormat.jpeg,
      quality: 100,
    );
    expect(clamped, max);
  });

  test('rejects pixel buffers of the wrong length', () {
    expect(
      encoder.encode(
        RgbaImage(pixels: Uint8List(10), width: 2, height: 2),
        format: ExportFormat.png,
      ),
      throwsArgumentError,
    );
  });
}
