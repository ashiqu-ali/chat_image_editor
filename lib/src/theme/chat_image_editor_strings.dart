import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;

/// Formats a byte count for display, e.g. `1.4 MB`.
typedef ByteSizeFormatter = String Function(int bytes);

/// Names a palette color for screen readers. [index] is the color's
/// zero-based position in the palette and [count] the palette's length.
typedef ColorLabelFormatter =
    String Function(Color color, int index, int count);

/// Describes a JPEG quality (1–100) for display, e.g. `High · 90`.
typedef QualityFormatter = String Function(int quality);

/// Every user-facing string in the editor, with English defaults.
///
/// Pass a translated instance to localize the editor:
///
/// ```dart
/// ChatImageEditor(
///   image: bytes,
///   strings: const ChatImageEditorStrings(captionHint: 'Ajouter une légende…'),
/// );
/// ```
@immutable
class ChatImageEditorStrings {
  /// Creates strings. Every argument has an English default.
  const ChatImageEditorStrings({
    this.captionHint = 'Add a caption…',
    this.close = 'Close',
    this.undo = 'Undo',
    this.redo = 'Redo',
    this.draw = 'Draw',
    this.text = 'Text',
    this.crop = 'Crop and rotate',
    this.compress = 'Image quality',
    this.rotateLeft = 'Rotate left',
    this.rotateRight = 'Rotate right',
    this.flipHorizontal = 'Flip horizontally',
    this.flipVertical = 'Flip vertically',
    this.resetCrop = 'Reset',
    this.freeAspectRatio = 'Free',
    this.confirm = 'Done',
    this.cancel = 'Cancel',
    this.send = 'Send',
    this.done = 'Done',
    this.delete = 'Delete',
    this.textBackground = 'Text background',
    this.strokeWidth = 'Brush size',
    this.freehand = 'Pen',
    this.line = 'Line',
    this.rectangle = 'Rectangle',
    this.circle = 'Circle',
    this.arrow = 'Arrow',
    this.qualityLabel = 'Quality',
    this.originalSizeLabel = 'Original',
    this.estimatedSizeLabel = 'Estimated size',
    this.estimatingSize = 'Calculating…',
    this.discardTitle = 'Discard changes?',
    this.discardMessage = 'Your edits to this image will be lost.',
    this.discardConfirm = 'Discard',
    this.keepEditing = 'Keep editing',
    this.loadFailed = "Couldn't open this image.",
    this.exportFailed = "Couldn't prepare this image. Please try again.",
    this.color = 'Color',
    this.apply = 'Apply',
    this.formatBytes = defaultFormatBytes,
    this.colorLabel = defaultColorLabel,
    this.formatQuality = defaultFormatQuality,
  });

  /// Caption field hint.
  final String captionHint;

  /// Close button tooltip.
  final String close;

  /// Undo button tooltip.
  final String undo;

  /// Redo button tooltip.
  final String redo;

  /// Draw tool tooltip.
  final String draw;

  /// Text tool tooltip.
  final String text;

  /// Crop tool tooltip.
  final String crop;

  /// Compress tool tooltip and sheet title.
  final String compress;

  /// Rotate-left tooltip.
  final String rotateLeft;

  /// Rotate-right tooltip.
  final String rotateRight;

  /// Flip-horizontal tooltip.
  final String flipHorizontal;

  /// Flip-vertical tooltip.
  final String flipVertical;

  /// Reset-crop label.
  final String resetCrop;

  /// Label of the free (unconstrained) crop preset.
  final String freeAspectRatio;

  /// Crop confirm label.
  final String confirm;

  /// Crop cancel label.
  final String cancel;

  /// Send button tooltip.
  final String send;

  /// Label of the Done buttons that end drawing and text entry, and the
  /// send button's tooltip in done mode.
  final String done;

  /// Delete target semantics label.
  final String delete;

  /// Text background button tooltip.
  final String textBackground;

  /// Stroke width slider semantics label.
  final String strokeWidth;

  /// Freehand shape tooltip.
  final String freehand;

  /// Line shape tooltip.
  final String line;

  /// Rectangle shape tooltip.
  final String rectangle;

  /// Circle shape tooltip.
  final String circle;

  /// Arrow shape tooltip.
  final String arrow;

  /// Label of the compress sheet's quality row, and the quality slider's
  /// semantics label.
  final String qualityLabel;

  /// Label before the original file size.
  final String originalSizeLabel;

  /// Label before the estimated file size.
  final String estimatedSizeLabel;

  /// Semantics label of the spinner shown while the size estimate is
  /// computed.
  final String estimatingSize;

  /// Discard dialog title.
  final String discardTitle;

  /// Discard dialog message.
  final String discardMessage;

  /// Discard dialog confirm button.
  final String discardConfirm;

  /// Discard dialog cancel button.
  final String keepEditing;

  /// Shown when the source image can't be decoded.
  final String loadFailed;

  /// Shown when export fails.
  final String exportFailed;

  /// Semantics label of the color slider. Its value is [colorLabel].
  final String color;

  /// Compress sheet button that keeps the chosen quality.
  final String apply;

  /// Formats file sizes in the compress sheet.
  final ByteSizeFormatter formatBytes;

  /// Names the palette color closest to the color slider's position, for
  /// screen readers. [index] is that color's position in the palette.
  final ColorLabelFormatter colorLabel;

  /// Describes a quality in the compress sheet: shown next to
  /// [qualityLabel] and announced as the quality slider's value.
  final QualityFormatter formatQuality;

  /// Formats [bytes] as `B`, `KB` or `MB` with one decimal.
  static String defaultFormatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Labels a palette color by position, e.g. `Color 3 of 10`.
  static String defaultColorLabel(Color color, int index, int count) {
    return 'Color ${index + 1} of $count';
  }

  /// Names the quality's tier, then the quality: `Low` up to 40, `Medium`
  /// up to 75 and `High` above, e.g. `Low · 40`, `Medium · 70` or
  /// `High · 90`.
  static String defaultFormatQuality(int quality) {
    final String tier;
    if (quality <= 40) {
      tier = 'Low';
    } else if (quality <= 75) {
      tier = 'Medium';
    } else {
      tier = 'High';
    }
    return '$tier · $quality';
  }
}
