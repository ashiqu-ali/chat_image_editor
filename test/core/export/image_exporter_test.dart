import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/export/image_exporter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../test_utils.dart';

const TextStyle textStyle = TextStyle(height: 1);
const Size original = Size(80, 60);

void main() {
  final source = quadrantPng(80, 60);

  Future<ChatImageEditorResult> export(
    ImageEditValue value, {
    ExportOptions options = const ExportOptions(maxLongEdge: null),
    Uint8List? bytes,
    Size originalSize = original,
    int quality = 90,
    String caption = '',
  }) {
    return ImageExporter.export(
      bytes: bytes ?? source,
      originalSize: originalSize,
      value: value,
      options: options,
      textStyle: textStyle,
      quality: quality,
      caption: caption,
    );
  }

  group('exportSize', () {
    test('keeps the size under the limit', () {
      expect(ImageExporter.exportSize(const Size(80, 60), 100), (
        width: 80,
        height: 60,
      ));
      expect(ImageExporter.exportSize(const Size(80, 60), null), (
        width: 80,
        height: 60,
      ));
    });

    test('scales the long side down to the limit', () {
      expect(ImageExporter.exportSize(const Size(4000, 3000), 1000), (
        width: 1000,
        height: 750,
      ));
      expect(ImageExporter.exportSize(const Size(3000, 4000), 1000), (
        width: 750,
        height: 1000,
      ));
    });

    test('rounds fractional output sizes and never returns zero', () {
      expect(ImageExporter.exportSize(const Size(20.5, 0.2), null), (
        width: 21,
        height: 1,
      ));
    });
  });

  group('qualityLadder', () {
    test('steps down by ten and ends at the minimum', () {
      expect(ImageExporter.qualityLadder(90, 30), <int>[
        80,
        70,
        60,
        50,
        40,
        30,
      ]);
      expect(ImageExporter.qualityLadder(35, 30), <int>[30]);
      expect(ImageExporter.qualityLadder(85, 50), <int>[75, 65, 55, 50]);
    });

    test('is empty at or below the minimum', () {
      expect(ImageExporter.qualityLadder(30, 30), isEmpty);
      expect(ImageExporter.qualityLadder(20, 30), isEmpty);
    });
  });

  group('dimensions', () {
    test('match the original without edits', () async {
      final result = await export(ImageEditValue.empty);
      expect(result.width, 80);
      expect(result.height, 60);
      final decoded = img.decodeJpg(result.bytes)!;
      expect(decoded.width, 80);
      expect(decoded.height, 60);
    });

    test('swap for odd quarter turns', () async {
      for (final turns in <int>[1, 3]) {
        final result = await export(ImageEditValue(quarterTurns: turns));
        expect(result.width, 60, reason: 'turns $turns');
        expect(result.height, 80, reason: 'turns $turns');
      }
      final half = await export(const ImageEditValue(quarterTurns: 2));
      expect(half.width, 80);
      expect(half.height, 60);
    });

    test('follow the crop', () async {
      final result = await export(
        const ImageEditValue(crop: Rect.fromLTRB(0.25, 0, 0.75, 0.5)),
      );
      expect(result.width, 40);
      expect(result.height, 30);
    });

    test('follow the crop after a rotation', () async {
      // Turned: 60×80; the crop takes half the width and a quarter height.
      final result = await export(
        const ImageEditValue(
          quarterTurns: 1,
          crop: Rect.fromLTRB(0, 0, 0.5, 0.25),
        ),
      );
      expect(result.width, 30);
      expect(result.height, 20);
    });

    test('honour maxLongEdge', () async {
      final result = await export(
        ImageEditValue.empty,
        options: const ExportOptions(maxLongEdge: 40),
      );
      expect(result.width, 40);
      expect(result.height, 30);

      final turned = await export(
        const ImageEditValue(quarterTurns: 1),
        options: const ExportOptions(maxLongEdge: 40),
      );
      expect(turned.width, 30);
      expect(turned.height, 40);
    });

    test('apply maxLongEdge to the cropped output', () async {
      final result = await export(
        const ImageEditValue(crop: Rect.fromLTRB(0, 0, 0.5, 1)),
        options: const ExportOptions(maxLongEdge: 30),
      );
      // Crop: 40×60 → long edge 60 scaled to 30.
      expect(result.width, 20);
      expect(result.height, 30);
    });
  });

  group('content', () {
    test('renders rotation, flips and crop', () async {
      final result = await export(
        const ImageEditValue(quarterTurns: 1),
        options: const ExportOptions(
          format: ExportFormat.png,
          maxLongEdge: null,
        ),
      );
      final decoded = img.decodePng(result.bytes)!;
      // Clockwise: the original bottom-left (blue) is now top-left.
      expect(decodedPixel(decoded, 10, 10), rgbaCloseTo(blue));
      expect(decodedPixel(decoded, 50, 10), rgbaCloseTo(red));
      expect(decodedPixel(decoded, 10, 70), rgbaCloseTo(yellow));
      expect(decodedPixel(decoded, 50, 70), rgbaCloseTo(green));

      final cropped = await export(
        const ImageEditValue(flipX: true, crop: Rect.fromLTRB(0, 0.5, 0.5, 1)),
        options: const ExportOptions(
          format: ExportFormat.png,
          maxLongEdge: null,
        ),
      );
      // Flipped, the bottom-left quarter shows the original bottom-right.
      final c = img.decodePng(cropped.bytes)!;
      expect(decodedPixel(c, 20, 15), rgbaCloseTo(yellow));
    });

    test('renders strokes', () async {
      const stroke = Stroke(
        id: 's',
        type: ShapeType.line,
        points: <Offset>[Offset(0, 0.25), Offset(1, 0.25)],
        color: Color(0xFF000000),
        width: 0.1,
      );
      final result = await export(
        const ImageEditValue(strokes: <Stroke>[stroke]),
        options: const ExportOptions(format: ExportFormat.png, maxLongEdge: 40),
      );
      final decoded = img.decodePng(result.bytes)!;
      expect(decodedPixel(decoded, 10, 7), rgbaCloseTo(black, tolerance: 30));
      expect(decodedPixel(decoded, 10, 2), rgbaCloseTo(red));
    });
  });

  group('formats', () {
    test('JPEG output', () async {
      final result = await export(ImageEditValue.empty);
      expect(result.format, ExportFormat.jpeg);
      expect(result.mimeType, 'image/jpeg');
      expect(result.fileExtension, 'jpg');
      expect(result.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    });

    test('PNG output', () async {
      final result = await export(
        ImageEditValue.empty,
        options: const ExportOptions(
          format: ExportFormat.png,
          maxLongEdge: null,
        ),
      );
      expect(result.format, ExportFormat.png);
      expect(result.mimeType, 'image/png');
      expect(result.fileExtension, 'png');
      expect(result.bytes.sublist(0, 4), <int>[137, 80, 78, 71]);
    });

    test('PNG keeps transparency', () async {
      final clear = solidPng(10, 10, const <int>[0, 0, 255, 0]);
      final result = await export(
        ImageEditValue.empty,
        bytes: clear,
        originalSize: const Size(10, 10),
        options: const ExportOptions(
          format: ExportFormat.png,
          maxLongEdge: null,
        ),
      );
      final decoded = img.decodePng(result.bytes)!;
      expect(decodedPixel(decoded, 5, 5)[3], 0);
    });

    test('JPEG fills transparency with the background color', () async {
      final clear = solidPng(10, 10, const <int>[0, 0, 255, 0]);
      final result = await export(
        ImageEditValue.empty,
        bytes: clear,
        originalSize: const Size(10, 10),
        options: const ExportOptions(
          maxLongEdge: null,
          backgroundColor: Color(0xFF00FF00),
        ),
      );
      final decoded = img.decodeJpg(result.bytes)!;
      expect(decodedPixel(decoded, 5, 5), rgbaCloseTo(green, tolerance: 20));
    });
  });

  group('maxBytes', () {
    test('first attempt that fits wins', () async {
      final encoder = FakeEncoder();
      final result = await export(
        ImageEditValue.empty,
        options: ExportOptions(
          maxLongEdge: null,
          maxBytes: 5000,
          encoder: encoder,
        ),
      );
      expect(encoder.qualities, <int>[90, 80, 70, 60, 50]);
      expect(result.bytes.length, 5000);
      expect(result.exceedsMaxBytes, isFalse);
    });

    test('no retries when the first attempt fits', () async {
      final encoder = FakeEncoder();
      final result = await export(
        ImageEditValue.empty,
        options: ExportOptions(
          maxLongEdge: null,
          maxBytes: 9000,
          encoder: encoder,
        ),
      );
      expect(encoder.qualities, <int>[90]);
      expect(result.exceedsMaxBytes, isFalse);
    });

    test('stops at minQuality and returns the smallest attempt', () async {
      final encoder = FakeEncoder();
      final result = await export(
        ImageEditValue.empty,
        options: ExportOptions(
          maxLongEdge: null,
          maxBytes: 100,
          minQuality: 45,
          encoder: encoder,
        ),
        quality: 75,
      );
      expect(encoder.qualities, <int>[75, 65, 55, 45]);
      expect(encoder.qualities.every((int q) => q >= 45), isTrue);
      expect(result.bytes.length, 4500);
      expect(result.exceedsMaxBytes, isTrue);
    });

    test('PNG only flags the overrun', () async {
      final encoder = FakeEncoder();
      final result = await export(
        ImageEditValue.empty,
        options: ExportOptions(
          format: ExportFormat.png,
          maxLongEdge: null,
          maxBytes: 100,
          encoder: encoder,
        ),
      );
      expect(encoder.qualities, hasLength(1));
      expect(encoder.formats, <ExportFormat>[ExportFormat.png]);
      expect(result.exceedsMaxBytes, isTrue);
    });

    test('works with the real encoder', () async {
      final noisy = noisyPng(64, 64);
      final unlimited = await export(
        ImageEditValue.empty,
        bytes: noisy,
        originalSize: const Size(64, 64),
      );
      final limited = await export(
        ImageEditValue.empty,
        bytes: noisy,
        originalSize: const Size(64, 64),
        options: ExportOptions(
          maxLongEdge: null,
          maxBytes: unlimited.bytes.length - 1,
        ),
      );
      expect(limited.bytes.length, lessThan(unlimited.bytes.length));
      expect(limited.exceedsMaxBytes, isFalse);

      final impossible = await export(
        ImageEditValue.empty,
        bytes: noisy,
        originalSize: const Size(64, 64),
        options: const ExportOptions(maxLongEdge: null, maxBytes: 10),
      );
      expect(impossible.exceedsMaxBytes, isTrue);
      expect(impossible.bytes.length, lessThan(unlimited.bytes.length));
    });
  });

  test('uses the given quality and trims the caption', () async {
    final encoder = FakeEncoder();
    final result = await export(
      const ImageEditValue(quality: 42),
      options: ExportOptions(maxLongEdge: null, encoder: encoder),
      quality: 42,
      caption: '  hello \n',
    );
    expect(encoder.qualities, <int>[42]);
    expect(result.caption, 'hello');
    expect(result.edits, const ImageEditValue(quality: 42));
  });

  test('render reads straight RGBA at the export size', () async {
    final pixels = await ImageExporter.render(
      bytes: source,
      originalSize: original,
      value: const ImageEditValue(quarterTurns: 3),
      options: const ExportOptions(maxLongEdge: 40),
      textStyle: textStyle,
    );
    expect(pixels.width, 30);
    expect(pixels.height, 40);
    expect(pixels.pixels.length, 30 * 40 * 4);
  });
}
