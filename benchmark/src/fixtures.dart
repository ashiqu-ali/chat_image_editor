import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

/// Width of the synthesized source photo: a 12 MP, 4:3 phone photo.
const int photoWidth = 4032;

/// Height of the synthesized source photo.
const int photoHeight = 3024;

/// Straight RGBA pixels shaped like a photo: smooth gradients, soft
/// banding and fine noise, from a fixed seed so every run is identical.
///
/// Pure noise would make JPEGs unrealistically large, and flat colors
/// unrealistically small; this lands near a real photo's size.
Uint8List photoPixels(int width, int height, {int seed = 42}) {
  final random = math.Random(seed);
  final rgba = Uint8List(width * height * 4);
  var i = 0;
  for (var y = 0; y < height; y++) {
    final v = y / height;
    final band = (math.sin(v * 9) * 18).round();
    for (var x = 0; x < width; x++) {
      final u = x / width;
      final noise = random.nextInt(25) - 12;
      rgba[i++] = _channel(40 + 170 * u + band + noise);
      rgba[i++] = _channel(60 + 120 * v - band + noise);
      rgba[i++] = _channel(150 - 90 * u * v + noise);
      rgba[i++] = 255;
    }
  }
  return rgba;
}

int _channel(num value) => value.round().clamp(0, 255);

/// [photoPixels] at [photoWidth]×[photoHeight], encoded as a JPEG at
/// quality 90 like a phone camera would.
Uint8List synthesizePhotoJpeg() {
  final rgba = photoPixels(photoWidth, photoHeight);
  final image = img.Image.fromBytes(
    width: photoWidth,
    height: photoHeight,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 90);
}

/// [count] strokes of every shape in normalized original space: mostly
/// freehand scribbles of [points] points, plus lines, rectangles, circles
/// and arrows.
List<Stroke> syntheticStrokes(int count, {int points = 40, int seed = 7}) {
  final random = math.Random(seed);
  const colors = <Color>[
    Color(0xFFF44336),
    Color(0xFFFFEB3B),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFFFFFF),
  ];
  return List<Stroke>.unmodifiable(<Stroke>[
    for (var s = 0; s < count; s++)
      _stroke(random, s, colors[s % colors.length], points),
  ]);
}

Stroke _stroke(math.Random random, int index, Color color, int points) {
  final type = index % 5 == 4
      ? ShapeType.values[1 + random.nextInt(ShapeType.values.length - 1)]
      : ShapeType.freehand;
  var x = 0.1 + random.nextDouble() * 0.8;
  var y = 0.1 + random.nextDouble() * 0.8;
  var heading = random.nextDouble() * math.pi * 2;
  final path = <Offset>[Offset(x, y)];
  final count = type == ShapeType.freehand ? points : 2;
  for (var p = 1; p < count; p++) {
    heading += (random.nextDouble() - 0.5) * 0.6;
    final step = type == ShapeType.freehand ? 0.008 : 0.2;
    x = (x + math.cos(heading) * step).clamp(0.0, 1.0);
    y = (y + math.sin(heading) * step).clamp(0.0, 1.0);
    path.add(Offset(x, y));
  }
  return Stroke(
    id: 'stroke-$index',
    type: type,
    points: List<Offset>.unmodifiable(path),
    color: color,
    width: 0.004 + random.nextDouble() * 0.01,
  );
}

/// A few text layers with every background style.
List<TextLayer> syntheticTexts() {
  return List<TextLayer>.unmodifiable(<TextLayer>[
    const TextLayer(
      id: 'text-1',
      text: 'Weekend trip',
      position: Offset(0.5, 0.2),
      fontSize: 0.08,
      color: Color(0xFFFFFFFF),
    ),
    const TextLayer(
      id: 'text-2',
      text: 'Look at this view!',
      position: Offset(0.35, 0.55),
      fontSize: 0.05,
      color: Color(0xFF000000),
      rotation: -0.2,
      background: TextBackgroundStyle.solid,
    ),
    const TextLayer(
      id: 'text-3',
      text: 'Day 3\nSunset at the lake',
      position: Offset(0.7, 0.8),
      fontSize: 0.04,
      color: Color(0xFFFFEB3B),
      rotation: 0.1,
      background: TextBackgroundStyle.translucent,
    ),
  ]);
}
