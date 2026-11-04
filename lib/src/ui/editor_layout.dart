import 'package:flutter/widgets.dart';

import '../controller/chat_image_editor_controller.dart';
import '../core/geometry/image_geometry.dart';
import '../models/editor_enums.dart';
import '../models/image_edit_value.dart';
import 'crop_controls.dart';

/// Shared layout rules for the editor's stacked layers.
///
/// The canvas, the crop overlay and the text entry overlay all fill the same
/// area, so they agree on where the image sits by calling these helpers with
/// the same size.
abstract final class EditorLayout {
  /// Height reserved for the top bar, below the safe area.
  static const double topBarHeight = 64;

  /// Room kept around the crop frame so a handle's whole touch area
  /// (`CropOverlay.cornerSlop`) stays reachable and off other controls.
  static const double cropHandleClearance = 32;

  /// Space kept clear above the image in crop mode, below the safe area.
  /// Crop mode has no top bar, so this is only room for the top handles.
  static const double cropTopInset = cropHandleClearance;

  /// Space kept clear below the image in crop mode, above the safe area:
  /// the crop controls plus room for the bottom handles.
  static const double cropBottomInset =
      CropControls.height + cropHandleClearance;

  /// Horizontal margin around the image in crop mode, so the frame's
  /// handles stay reachable.
  static const double cropSideInset = 24;

  /// Padding between the editor edges and the image for [tool].
  ///
  /// Uses the view padding (not the padding), so the image doesn't move when
  /// the keyboard opens.
  static EdgeInsets canvasPadding(BuildContext context, EditorTool tool) {
    final safe = MediaQuery.viewPaddingOf(context);
    if (tool == EditorTool.crop) {
      return EdgeInsets.fromLTRB(
        safe.left + cropSideInset,
        safe.top + cropTopInset,
        safe.right + cropSideInset,
        safe.bottom + cropBottomInset,
      );
    }
    return EdgeInsets.fromLTRB(safe.left, safe.top, safe.right, safe.bottom);
  }

  /// The edits as they are painted right now: in crop mode the crop is
  /// cleared so the whole rotated image shows under the crop frame.
  static ImageEditValue paintedValue(ChatImageEditorController controller) {
    final value = controller.value;
    if (controller.activeTool == EditorTool.crop) {
      return value.copyWith(clearCrop: true);
    }
    return value;
  }

  /// Size, in output pixels, of what [paintedValue] paints.
  static Size paintedOutputSize(ChatImageEditorController controller) {
    return ImageGeometry.outputSize(
      controller.originalSize,
      paintedValue(controller),
    );
  }

  /// Where content of [outputSize] is shown inside a layer of [layerSize]
  /// once [padding] is removed. Falls back to the whole layer when the
  /// padding leaves no room.
  static Rect imageRect(Size layerSize, EdgeInsets padding, Size outputSize) {
    if (outputSize.isEmpty || layerSize.isEmpty) return Rect.zero;
    var bounds = padding.deflateRect(Offset.zero & layerSize);
    if (bounds.isEmpty) bounds = Offset.zero & layerSize;
    return ImageGeometry.fitRect(outputSize, bounds);
  }

  /// Converts [local] (in layer pixels) to a point normalized over [rect].
  static Offset toNormalized(Offset local, Rect rect) {
    if (rect.isEmpty) return Offset.zero;
    return Offset(
      (local.dx - rect.left) / rect.width,
      (local.dy - rect.top) / rect.height,
    );
  }
}
