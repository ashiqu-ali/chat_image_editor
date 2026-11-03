import 'package:flutter/material.dart';

/// Icons used by the editor.
///
/// Each field takes any widget, so you can pass an `Icon`, an SVG or an
/// image. Leave a field `null` to use the Material default. Icons without
/// an explicit color pick up the editor's themed color through `IconTheme`.
///
/// ```dart
/// ChatImageEditor(
///   image: bytes,
///   icons: const ChatImageEditorIcons(send: Icon(Icons.arrow_upward)),
/// );
/// ```
@immutable
class ChatImageEditorIcons {
  /// Creates icon overrides.
  const ChatImageEditorIcons({
    this.close,
    this.undo,
    this.redo,
    this.draw,
    this.text,
    this.crop,
    this.compress,
    this.rotateLeft,
    this.rotateRight,
    this.flipHorizontal,
    this.flipVertical,
    this.resetCrop,
    this.confirm,
    this.cancel,
    this.send,
    this.done,
    this.delete,
    this.textBackground,
    this.freehand,
    this.line,
    this.rectangle,
    this.circle,
    this.arrow,
  });

  /// Closes the editor.
  final Widget? close;

  /// Undoes the last edit.
  final Widget? undo;

  /// Redoes the last undone edit.
  final Widget? redo;

  /// Opens the draw tool.
  final Widget? draw;

  /// Opens the text tool.
  final Widget? text;

  /// Opens the crop tool.
  final Widget? crop;

  /// Opens the compress tool.
  final Widget? compress;

  /// Rotates a quarter turn counter-clockwise.
  final Widget? rotateLeft;

  /// Rotates a quarter turn clockwise.
  final Widget? rotateRight;

  /// Mirrors left-right.
  final Widget? flipHorizontal;

  /// Mirrors top-bottom.
  final Widget? flipVertical;

  /// Resets crop, rotation and flips.
  final Widget? resetCrop;

  /// Confirms the crop.
  final Widget? confirm;

  /// Cancels the crop.
  final Widget? cancel;

  /// Send button.
  final Widget? send;

  /// Done button (done mode).
  final Widget? done;

  /// Drag-to-delete target.
  final Widget? delete;

  /// Cycles the text background style.
  final Widget? textBackground;

  /// Freehand shape.
  final Widget? freehand;

  /// Line shape.
  final Widget? line;

  /// Rectangle shape.
  final Widget? rectangle;

  /// Circle shape.
  final Widget? circle;

  /// Arrow shape.
  final Widget? arrow;

  /// [close] or the default.
  Widget get closeIcon => close ?? const Icon(Icons.close);

  /// [undo] or the default.
  Widget get undoIcon => undo ?? const Icon(Icons.undo);

  /// [redo] or the default.
  Widget get redoIcon => redo ?? const Icon(Icons.redo);

  /// [draw] or the default.
  Widget get drawIcon => draw ?? const Icon(Icons.edit_outlined);

  /// [text] or the default.
  Widget get textIcon => text ?? const Icon(Icons.title);

  /// [crop] or the default.
  Widget get cropIcon => crop ?? const Icon(Icons.crop_rotate);

  /// [compress] or the default.
  Widget get compressIcon => compress ?? const Icon(Icons.hd_outlined);

  /// [rotateLeft] or the default.
  Widget get rotateLeftIcon => rotateLeft ?? const Icon(Icons.rotate_left);

  /// [rotateRight] or the default.
  Widget get rotateRightIcon => rotateRight ?? const Icon(Icons.rotate_right);

  /// [flipHorizontal] or the default.
  Widget get flipHorizontalIcon => flipHorizontal ?? const Icon(Icons.flip);

  /// [flipVertical] or the default.
  Widget get flipVerticalIcon =>
      flipVertical ??
      const RotatedBox(quarterTurns: 1, child: Icon(Icons.flip));

  /// [resetCrop] or the default.
  Widget get resetCropIcon => resetCrop ?? const Icon(Icons.restart_alt);

  /// [confirm] or the default.
  Widget get confirmIcon => confirm ?? const Icon(Icons.check);

  /// [cancel] or the default.
  Widget get cancelIcon => cancel ?? const Icon(Icons.close);

  /// [send] or the default.
  Widget get sendIcon => send ?? const Icon(Icons.send);

  /// [done] or the default.
  Widget get doneIcon => done ?? const Icon(Icons.check);

  /// [delete] or the default.
  Widget get deleteIcon => delete ?? const Icon(Icons.delete_outline);

  /// [textBackground] or the default.
  Widget get textBackgroundIcon =>
      textBackground ?? const Icon(Icons.format_color_fill);

  /// [freehand] or the default.
  Widget get freehandIcon => freehand ?? const Icon(Icons.gesture);

  /// [line] or the default.
  Widget get lineIcon => line ?? const Icon(Icons.horizontal_rule);

  /// [rectangle] or the default.
  Widget get rectangleIcon => rectangle ?? const Icon(Icons.crop_square);

  /// [circle] or the default.
  Widget get circleIcon => circle ?? const Icon(Icons.circle_outlined);

  /// [arrow] or the default.
  Widget get arrowIcon => arrow ?? const Icon(Icons.north_east);
}
