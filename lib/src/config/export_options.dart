import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/encoding/image_encoder.dart';
import '../models/editor_enums.dart';

/// How the edited image is turned into bytes.
@immutable
class ExportOptions {
  /// Creates export options. The defaults suit chat attachments.
  const ExportOptions({
    this.format = ExportFormat.jpeg,
    this.quality = 90,
    this.maxLongEdge = 4096,
    this.maxBytes,
    this.minQuality = 30,
    this.encoder,
    this.backgroundColor = const Color(0xFFFFFFFF),
  }) : assert(quality > 0 && quality <= 100),
       assert(minQuality > 0 && minQuality <= 100),
       assert(maxLongEdge == null || maxLongEdge > 0),
       assert(maxBytes == null || maxBytes > 0);

  /// Output format.
  final ExportFormat format;

  /// JPEG quality (1–100) used when the user didn't pick one in the
  /// compress tool.
  final int quality;

  /// Longest side of the output in pixels. Larger results are scaled down
  /// proportionally. `null` keeps the full resolution.
  ///
  /// Capping protects low-memory devices and GPU texture limits; 4096 keeps
  /// photos sharp on any screen.
  final int? maxLongEdge;

  /// Target maximum file size in bytes, or `null` for no limit.
  ///
  /// For JPEG, quality steps down (never below [minQuality]) until the file
  /// fits. If it still doesn't fit, the smallest attempt is returned and
  /// `ChatImageEditorResult.exceedsMaxBytes` is `true`.
  final int? maxBytes;

  /// Lowest JPEG quality the [maxBytes] search may use.
  final int minQuality;

  /// Encoder to use, or `null` for the built-in pure-Dart encoder.
  final ImageEncoder? encoder;

  /// Fills transparent pixels for JPEG output, which has no alpha channel.
  final Color backgroundColor;

  /// Returns a copy with the given fields replaced.
  ExportOptions copyWith({
    ExportFormat? format,
    int? quality,
    int? maxLongEdge,
    int? maxBytes,
    int? minQuality,
    ImageEncoder? encoder,
    Color? backgroundColor,
  }) {
    return ExportOptions(
      format: format ?? this.format,
      quality: quality ?? this.quality,
      maxLongEdge: maxLongEdge ?? this.maxLongEdge,
      maxBytes: maxBytes ?? this.maxBytes,
      minQuality: minQuality ?? this.minQuality,
      encoder: encoder ?? this.encoder,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}
