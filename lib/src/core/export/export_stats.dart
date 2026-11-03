import 'package:flutter/foundation.dart';

/// How long an export took and what it produced.
///
/// Read it from `ChatImageEditorResult.stats` to log export performance to
/// your own analytics or logs. The package itself never sends it anywhere.
///
/// The phases run one after another, so [totalTime] is at least
/// [decodeTime] + [renderTime] + [encodeTime]; the rest is bookkeeping
/// between the phases.
@immutable
class ExportStats {
  /// Creates export stats.
  const ExportStats({
    required this.decodeTime,
    required this.renderTime,
    required this.encodeTime,
    required this.totalTime,
    required this.encodeAttempts,
    this.finalQuality,
    required this.sourceByteLength,
    required this.outputByteLength,
    required this.outputWidth,
    required this.outputHeight,
  });

  /// Time spent decoding the source bytes at the size the output needs.
  final Duration decodeTime;

  /// Time spent painting the edits over the decoded source and reading the
  /// result back as raw pixels.
  final Duration renderTime;

  /// Time spent encoding, summed over every attempt.
  final Duration encodeTime;

  /// Wall-clock time of the whole export.
  final Duration totalTime;

  /// How many times the encoder ran. `1` unless `ExportOptions.maxBytes`
  /// made the export step JPEG quality down.
  final int encodeAttempts;

  /// JPEG quality of the returned bytes, or `null` for PNG.
  final int? finalQuality;

  /// Length in bytes of the source image passed to the editor.
  final int sourceByteLength;

  /// Length in bytes of the encoded result.
  final int outputByteLength;

  /// Width of the encoded result in pixels.
  final int outputWidth;

  /// Height of the encoded result in pixels.
  final int outputHeight;

  @override
  bool operator ==(Object other) {
    return other is ExportStats &&
        other.decodeTime == decodeTime &&
        other.renderTime == renderTime &&
        other.encodeTime == encodeTime &&
        other.totalTime == totalTime &&
        other.encodeAttempts == encodeAttempts &&
        other.finalQuality == finalQuality &&
        other.sourceByteLength == sourceByteLength &&
        other.outputByteLength == outputByteLength &&
        other.outputWidth == outputWidth &&
        other.outputHeight == outputHeight;
  }

  @override
  int get hashCode => Object.hash(
    decodeTime,
    renderTime,
    encodeTime,
    totalTime,
    encodeAttempts,
    finalQuality,
    sourceByteLength,
    outputByteLength,
    outputWidth,
    outputHeight,
  );

  @override
  String toString() {
    return 'ExportStats('
        'decode: ${decodeTime.inMicroseconds / 1000} ms, '
        'render: ${renderTime.inMicroseconds / 1000} ms, '
        'encode: ${encodeTime.inMicroseconds / 1000} ms, '
        'total: ${totalTime.inMicroseconds / 1000} ms, '
        'attempts: $encodeAttempts, '
        'quality: ${finalQuality ?? 'n/a'}, '
        'bytes: $sourceByteLength -> $outputByteLength, '
        'size: ${outputWidth}x$outputHeight)';
  }
}
