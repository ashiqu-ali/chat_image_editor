import 'package:flutter/foundation.dart';

import '../../models/editor_enums.dart';
import '../../models/image_edit_value.dart';
import 'export_stats.dart';

/// What the editor returns when the user sends or finishes.
@immutable
class ChatImageEditorResult {
  /// Creates a result.
  const ChatImageEditorResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
    required this.edits,
    this.caption = '',
    this.exceedsMaxBytes = false,
    this.stats,
  });

  /// The encoded image.
  final Uint8List bytes;

  /// Width of the encoded image in pixels.
  final int width;

  /// Height of the encoded image in pixels.
  final int height;

  /// Encoding of [bytes].
  final ExportFormat format;

  /// The edits that produced this image.
  final ImageEditValue edits;

  /// Caption typed by the user, trimmed. Empty in done mode.
  final String caption;

  /// `true` when `ExportOptions.maxBytes` was set and even the lowest
  /// allowed quality didn't fit. [bytes] then holds the smallest attempt.
  final bool exceedsMaxBytes;

  /// How long the export took and what it produced, for your own
  /// performance logging. Filled in by the editor's export; `null` for a
  /// result created without one. The package never sends it anywhere.
  final ExportStats? stats;

  /// MIME type of [bytes].
  String get mimeType => format.mimeType;

  /// File extension for [bytes], without the dot.
  String get fileExtension => format.fileExtension;
}
