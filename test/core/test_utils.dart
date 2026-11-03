import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// Image decoding, Picture.toImage and compute all complete inside plain
// `test()` bodies in this Flutter version (inside `testWidgets` they need
// `tester.runAsync`), so every engine test uses plain `test()`.

/// Opaque red.
const List<int> red = <int>[255, 0, 0, 255];

/// Opaque green.
const List<int> green = <int>[0, 255, 0, 255];

/// Opaque blue.
const List<int> blue = <int>[0, 0, 255, 255];

/// Opaque yellow.
const List<int> yellow = <int>[255, 255, 0, 255];

/// Opaque white.
const List<int> white = <int>[255, 255, 255, 255];

/// Opaque black.
const List<int> black = <int>[0, 0, 0, 255];

/// A PNG filled with one color.
Uint8List solidPng(int width, int height, List<int> rgba) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  image.clear(img.ColorRgba8(rgba[0], rgba[1], rgba[2], rgba[3]));
  return img.encodePng(image);
}

/// A PNG split into four quadrants: red top-left, green top-right, blue
/// bottom-left, yellow bottom-right. Any rotation or flip is identifiable
/// from the corners.
Uint8List quadrantPng(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final right = x >= width ~/ 2;
      final bottom = y >= height ~/ 2;
      final c = bottom ? (right ? yellow : blue) : (right ? green : red);
      image.setPixelRgb(x, y, c[0], c[1], c[2]);
    }
  }
  return img.encodePng(image);
}

/// A PNG with smooth gradients plus deterministic noise, so JPEG size
/// depends clearly on quality.
Uint8List noisyPng(int width, int height) {
  final random = math.Random(7);
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 255 ~/ width + random.nextInt(60)) % 256,
        (y * 255 ~/ height + random.nextInt(60)) % 256,
        random.nextInt(256),
      );
    }
  }
  return img.encodePng(image);
}

/// Straight RGBA pixels read back from the engine.
class Pixels {
  /// Wraps raw pixels.
  Pixels(this.width, this.height, this.bytes);

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Straight RGBA bytes.
  final Uint8List bytes;

  /// The RGBA values at ([x], [y]).
  List<int> at(int x, int y) {
    final i = (y * width + x) * 4;
    return <int>[bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]];
  }

  /// Alpha at ([x], [y]).
  int alphaAt(int x, int y) => at(x, y)[3];
}

/// Matches an RGBA list within [tolerance] per channel.
Matcher rgbaCloseTo(List<int> expected, {int tolerance = 12}) {
  return predicate<List<int>>((List<int> actual) {
    for (var i = 0; i < 4; i++) {
      if ((actual[i] - expected[i]).abs() > tolerance) return false;
    }
    return true;
  }, 'RGBA within $tolerance of $expected');
}

/// Matches an [Offset] within [epsilon] of [expected].
Matcher offsetCloseTo(Offset expected, [double epsilon = 1e-9]) {
  return predicate<Offset>(
    (Offset actual) => (actual - expected).distance <= epsilon,
    'Offset within $epsilon of $expected',
  );
}

/// Matches a [Rect] whose edges are within [epsilon] of [expected].
Matcher rectCloseTo(Rect expected, [double epsilon = 1e-9]) {
  return predicate<Rect>(
    (Rect actual) =>
        (actual.left - expected.left).abs() <= epsilon &&
        (actual.top - expected.top).abs() <= epsilon &&
        (actual.right - expected.right).abs() <= epsilon &&
        (actual.bottom - expected.bottom).abs() <= epsilon,
    'Rect within $epsilon of $expected',
  );
}

/// Records [paint] into a [width]×[height] picture and reads the pixels.
Future<Pixels> paintToPixels(
  int width,
  int height,
  void Function(Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  paint(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    return await imageToPixels(image);
  } finally {
    image.dispose();
  }
}

/// Reads an engine image's pixels.
Future<Pixels> imageToPixels(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return Pixels(image.width, image.height, data!.buffer.asUint8List());
}

/// Decodes [bytes] with `package:image` and returns the RGBA at ([x], [y]).
List<int> decodedPixel(img.Image image, int x, int y) {
  final p = image.getPixel(x, y);
  return <int>[p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt()];
}

/// Every quarter-turn and flip combination (16 values covering the eight
/// distinct orientations), optionally with [crop].
Iterable<ImageEditValue> allOrientations({Rect? crop}) sync* {
  for (var turns = 0; turns < 4; turns++) {
    for (final flipX in <bool>[false, true]) {
      for (final flipY in <bool>[false, true]) {
        yield ImageEditValue(
          quarterTurns: turns,
          flipX: flipX,
          flipY: flipY,
          crop: crop,
        );
      }
    }
  }
}

/// Short description of a value's transform for test reasons.
String describeTransform(ImageEditValue value) =>
    'turns=${value.quarterTurns} flipX=${value.flipX} '
    'flipY=${value.flipY} crop=${value.crop}';

/// Records the quality and format of every encode and returns
/// `quality * bytesPerQuality` bytes, so size targets are predictable.
class FakeEncoder implements ImageEncoder {
  /// Creates a fake encoder.
  FakeEncoder({this.bytesPerQuality = 100});

  /// Bytes returned per quality point.
  final int bytesPerQuality;

  /// Qualities passed to [encode], in order.
  final List<int> qualities = <int>[];

  /// Formats passed to [encode], in order.
  final List<ExportFormat> formats = <ExportFormat>[];

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) async {
    qualities.add(quality);
    formats.add(format);
    return Uint8List(quality * bytesPerQuality);
  }
}

/// Wraps an encoder and counts calls.
class CountingEncoder implements ImageEncoder {
  /// Wraps [inner].
  CountingEncoder([this.inner = const DartImageEncoder()]);

  /// The encoder doing the work.
  final ImageEncoder inner;

  /// Number of [encode] calls.
  int calls = 0;

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) {
    calls++;
    return inner.encode(image, format: format, quality: quality);
  }
}

/// An encoder that always fails.
class FailingEncoder implements ImageEncoder {
  /// Creates the encoder.
  const FailingEncoder();

  @override
  Future<Uint8List> encode(
    RgbaImage image, {
    required ExportFormat format,
    int quality = 90,
  }) {
    return Future<Uint8List>.error(StateError('encoder failure'));
  }
}
