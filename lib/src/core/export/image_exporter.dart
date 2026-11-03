import 'dart:developer' show TimelineTask;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../config/export_options.dart';
import '../../models/editor_enums.dart';
import '../../models/image_edit_value.dart';
import '../encoding/dart_image_encoder.dart';
import '../encoding/image_encoder.dart';
import '../geometry/image_geometry.dart';
import '../loading/image_loader.dart';
import '../render/composition_renderer.dart';
import '../tracing/editor_timeline.dart';
import 'chat_image_editor_result.dart';
import 'export_stats.dart';

/// Encoded bytes plus how the size target went.
typedef EncodedOutput = ({Uint8List bytes, int quality, bool exceedsMaxBytes});

/// Rendered pixels plus how long decoding and rendering took.
typedef _Rendered = ({
  RgbaImage pixels,
  Duration decodeTime,
  Duration renderTime,
});

/// An [EncodedOutput] plus how many times the encoder ran for it.
typedef _Encoded = ({EncodedOutput output, int attempts});

/// Turns an [ImageEditValue] into encoded bytes:
///
/// ```
/// source bytes → decode at the needed size → render with
/// CompositionRenderer (JPEG: on the background color) → raw RGBA →
/// ImageEncoder → step JPEG quality down for maxBytes
/// ```
///
/// Internal: not exported from the package.
abstract final class ImageExporter {
  /// JPEG quality step used by the `maxBytes` search.
  static const int qualityStep = 10;

  /// Pixel size of the export for an output of [output] output pixels,
  /// scaled down so the long side is at most [maxLongEdge].
  static ({int width, int height}) exportSize(Size output, int? maxLongEdge) {
    final scale = _scale(output, maxLongEdge);
    return (
      width: math.max(1, (output.width * scale).round()),
      height: math.max(1, (output.height * scale).round()),
    );
  }

  /// Qualities tried after [start] when the file is too big: steps of
  /// [qualityStep] down to [minQuality], which is always the last attempt.
  /// Empty when [start] is already at or below [minQuality].
  static List<int> qualityLadder(int start, int minQuality) {
    final ladder = <int>[];
    if (start <= minQuality) return ladder;
    for (var q = start - qualityStep; q > minQuality; q -= qualityStep) {
      ladder.add(q);
    }
    ladder.add(minQuality);
    return ladder;
  }

  /// Renders [value] over the source [bytes] into straight RGBA pixels at
  /// the export size. Disposes every intermediate image and picture.
  static Future<RgbaImage> render({
    required Uint8List bytes,
    required Size originalSize,
    required ImageEditValue value,
    required ExportOptions options,
    required TextStyle textStyle,
  }) async {
    final rendered = await _render(
      bytes: bytes,
      originalSize: originalSize,
      value: value,
      options: options,
      textStyle: textStyle,
    );
    return rendered.pixels;
  }

  static Future<_Rendered> _render({
    required Uint8List bytes,
    required Size originalSize,
    required ImageEditValue value,
    required ExportOptions options,
    required TextStyle textStyle,
    TimelineTask? parent,
  }) async {
    final output = ImageGeometry.outputSize(originalSize, value);
    if (!(output.width > 0 && output.height > 0)) {
      throw StateError('Nothing to export: the output size is $output.');
    }
    final target = exportSize(output, options.maxLongEdge);
    final scaleX = target.width / output.width;
    final scaleY = target.height / output.height;

    // Decode only as many source pixels as the output needs.
    final sourceScale = math.max(scaleX, scaleY);
    final longSide = math.max(originalSize.width, originalSize.height);
    final decodeLongEdge = sourceScale < 1
        ? math.max(1, (longSide * sourceScale).ceil())
        : null;

    final task = EditorTimeline.task(parent: parent)
      ?..start(
        EditorTimeline.render,
        arguments: <String, Object?>{
          'width': target.width,
          'height': target.height,
          'decodeLongEdge': decodeLongEdge,
          'strokes': value.strokes.length,
          'texts': value.texts.length,
        },
      );
    try {
      final clock = Stopwatch()..start();
      final source = await ImageLoader.decode(
        bytes,
        maxLongEdge: decodeLongEdge,
      );
      final decodeTime = clock.elapsed;

      ui.Picture? picture;
      ui.Image? rendered;
      try {
        final bounds = Rect.fromLTWH(
          0,
          0,
          target.width.toDouble(),
          target.height.toDouble(),
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, bounds);
        if (options.format == ExportFormat.jpeg) {
          canvas.drawRect(
            bounds,
            Paint()..color = options.backgroundColor.withAlpha(0xFF),
          );
        }
        canvas.scale(scaleX, scaleY);
        CompositionRenderer.paint(
          canvas,
          image: source.image,
          originalSize: originalSize,
          value: value,
          textStyle: textStyle,
        );
        picture = recorder.endRecording();

        final raster = EditorTimeline.task(parent: task)
          ?..start(
            EditorTimeline.rasterize,
            arguments: <String, Object?>{
              'width': target.width,
              'height': target.height,
            },
          );
        final ByteData? data;
        try {
          rendered = await picture.toImage(target.width, target.height);
          data = await rendered.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          );
        } finally {
          raster?.finish();
        }
        if (data == null) {
          throw StateError('Could not read the rendered pixels.');
        }
        final pixels = RgbaImage(
          pixels: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          width: target.width,
          height: target.height,
        );
        return (
          pixels: pixels,
          decodeTime: decodeTime,
          renderTime: clock.elapsed - decodeTime,
        );
      } finally {
        rendered?.dispose();
        picture?.dispose();
        source.image.dispose();
      }
    } finally {
      task?.finish();
    }
  }

  /// Encodes [pixels] per [options] starting at [quality]. With
  /// `options.maxBytes` set and JPEG output, quality steps down (never below
  /// `options.minQuality`) until the file fits; if nothing fits, the
  /// smallest attempt is returned with `exceedsMaxBytes: true`.
  static Future<EncodedOutput> encode(
    RgbaImage pixels, {
    required ExportOptions options,
    required int quality,
  }) async {
    final encoded = await _encode(pixels, options: options, quality: quality);
    return encoded.output;
  }

  static Future<_Encoded> _encode(
    RgbaImage pixels, {
    required ExportOptions options,
    required int quality,
    TimelineTask? parent,
  }) async {
    final encoder = options.encoder ?? const DartImageEncoder();
    final format = options.format;
    var attempts = 0;
    Future<Uint8List> attempt(int q, TimelineTask? span) {
      attempts++;
      return _encodeOnce(
        encoder,
        pixels,
        format: format,
        quality: q,
        attempt: attempts,
        parent: span,
      );
    }

    final start = quality.clamp(1, 100);
    final first = await attempt(start, parent);
    final maxBytes = options.maxBytes;
    if (maxBytes == null || first.length <= maxBytes) {
      return (
        output: (bytes: first, quality: start, exceedsMaxBytes: false),
        attempts: attempts,
      );
    }
    if (format != ExportFormat.jpeg) {
      return (
        output: (bytes: first, quality: start, exceedsMaxBytes: true),
        attempts: attempts,
      );
    }

    final minQuality = options.minQuality.clamp(1, 100);
    final fit = EditorTimeline.task(parent: parent)
      ?..start(
        EditorTimeline.fitMaxBytes,
        arguments: <String, Object?>{
          'maxBytes': maxBytes,
          'firstBytes': first.length,
          'startQuality': start,
          'minQuality': minQuality,
        },
      );
    EncodedOutput? result;
    try {
      var smallest = first;
      var smallestQuality = start;
      for (final q in qualityLadder(start, minQuality)) {
        final bytes = await attempt(q, fit);
        if (bytes.length <= maxBytes) {
          result = (bytes: bytes, quality: q, exceedsMaxBytes: false);
          return (output: result, attempts: attempts);
        }
        if (bytes.length < smallest.length) {
          smallest = bytes;
          smallestQuality = q;
        }
      }
      result = (
        bytes: smallest,
        quality: smallestQuality,
        exceedsMaxBytes: true,
      );
      return (output: result, attempts: attempts);
    } finally {
      fit?.finish(
        arguments: <String, Object?>{
          'attempts': attempts,
          'finalQuality': result?.quality,
          'bytes': result?.bytes.length,
          'exceedsMaxBytes': result?.exceedsMaxBytes,
        },
      );
    }
  }

  /// One encoder call, inside its own timeline span.
  static Future<Uint8List> _encodeOnce(
    ImageEncoder encoder,
    RgbaImage pixels, {
    required ExportFormat format,
    required int quality,
    required int attempt,
    required TimelineTask? parent,
  }) async {
    final task = EditorTimeline.task(parent: parent)
      ?..start(
        EditorTimeline.encode,
        arguments: <String, Object?>{
          'format': format.name,
          'quality': format == ExportFormat.jpeg ? quality : null,
          'attempt': attempt,
          'width': pixels.width,
          'height': pixels.height,
        },
      );
    Uint8List? bytes;
    try {
      bytes = await encoder.encode(pixels, format: format, quality: quality);
      return bytes;
    } finally {
      task?.finish(arguments: <String, Object?>{'bytes': bytes?.length});
    }
  }

  /// Renders and encodes [value] into a [ChatImageEditorResult], with
  /// [ChatImageEditorResult.stats] describing how long each phase took.
  static Future<ChatImageEditorResult> export({
    required Uint8List bytes,
    required Size originalSize,
    required ImageEditValue value,
    required ExportOptions options,
    required TextStyle textStyle,
    required int quality,
    String caption = '',
  }) async {
    final clock = Stopwatch()..start();
    final task = EditorTimeline.task()
      ?..start(
        EditorTimeline.export,
        arguments: <String, Object?>{
          'sourceBytes': bytes.length,
          'format': options.format.name,
          'quality': quality,
          'maxLongEdge': options.maxLongEdge,
          'maxBytes': options.maxBytes,
          'strokes': value.strokes.length,
          'texts': value.texts.length,
        },
      );
    ExportStats? stats;
    try {
      final rendered = await _render(
        bytes: bytes,
        originalSize: originalSize,
        value: value,
        options: options,
        textStyle: textStyle,
        parent: task,
      );
      final pixels = rendered.pixels;
      final encodeStart = clock.elapsed;
      final encoded = await _encode(
        pixels,
        options: options,
        quality: quality,
        parent: task,
      );
      final encodeTime = clock.elapsed - encodeStart;
      final output = encoded.output;
      stats = ExportStats(
        decodeTime: rendered.decodeTime,
        renderTime: rendered.renderTime,
        encodeTime: encodeTime,
        totalTime: clock.elapsed,
        encodeAttempts: encoded.attempts,
        finalQuality: options.format == ExportFormat.jpeg
            ? output.quality
            : null,
        sourceByteLength: bytes.length,
        outputByteLength: output.bytes.length,
        outputWidth: pixels.width,
        outputHeight: pixels.height,
      );
      return ChatImageEditorResult(
        bytes: output.bytes,
        width: pixels.width,
        height: pixels.height,
        format: options.format,
        edits: value,
        caption: caption.trim(),
        exceedsMaxBytes: output.exceedsMaxBytes,
        stats: stats,
      );
    } finally {
      final done = stats;
      task?.finish(
        arguments: done == null
            ? null
            : <String, Object?>{
                'decodeMs': _millis(done.decodeTime),
                'renderMs': _millis(done.renderTime),
                'encodeMs': _millis(done.encodeTime),
                'totalMs': _millis(done.totalTime),
                'attempts': done.encodeAttempts,
                'finalQuality': done.finalQuality,
                'bytes': done.outputByteLength,
                'width': done.outputWidth,
                'height': done.outputHeight,
              },
      );
    }
  }

  static double _millis(Duration duration) => duration.inMicroseconds / 1000;

  static double _scale(Size output, int? maxLongEdge) {
    final longest = math.max(output.width, output.height);
    if (maxLongEdge == null || longest <= maxLongEdge) return 1;
    return maxLongEdge / longest;
  }
}
