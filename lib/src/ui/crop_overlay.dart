import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../controller/chat_image_editor_controller.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import 'editor_layout.dart';

/// The part of the crop frame a drag grabbed.
enum CropHandle {
  /// Top-left corner.
  topLeft,

  /// Top-right corner.
  topRight,

  /// Bottom-left corner.
  bottomLeft,

  /// Bottom-right corner.
  bottomRight,

  /// Top edge.
  top,

  /// Bottom edge.
  bottom,

  /// Left edge.
  left,

  /// Right edge.
  right,

  /// Inside the frame: moves it.
  move,
}

/// The crop frame drawn over the whole rotated image while the crop tool is
/// open.
///
/// Corners and edges resize the frame and dragging inside moves it. The
/// frame lives in transformed space (`ImageEditValue.crop`); this widget
/// maps it to the displayed image and sends every change to
/// `ChatImageEditorController.setCrop`, which clamps it.
class CropOverlay extends StatefulWidget {
  /// Creates the overlay.
  const CropOverlay({super.key});

  /// Touch radius around corners, in logical pixels.
  static const double cornerSlop = 28;

  /// Touch distance from edges, in logical pixels.
  static const double edgeSlop = 20;

  /// Smallest frame side, in logical pixels.
  static const double minFrameSide = 56;

  /// Finds which part of [frame] a touch at [point] grabs, or `null`.
  static CropHandle? handleAt(Rect frame, Offset point) {
    final corners = <CropHandle, Offset>{
      CropHandle.topLeft: frame.topLeft,
      CropHandle.topRight: frame.topRight,
      CropHandle.bottomLeft: frame.bottomLeft,
      CropHandle.bottomRight: frame.bottomRight,
    };
    CropHandle? nearest;
    var nearestDistance = cornerSlop;
    corners.forEach((handle, corner) {
      final distance = (corner - point).distance;
      if (distance <= nearestDistance) {
        nearest = handle;
        nearestDistance = distance;
      }
    });
    if (nearest != null) return nearest;

    final withinX =
        point.dx >= frame.left - edgeSlop && point.dx <= frame.right + edgeSlop;
    final withinY =
        point.dy >= frame.top - edgeSlop && point.dy <= frame.bottom + edgeSlop;
    if (withinX && (point.dy - frame.top).abs() <= edgeSlop) {
      return CropHandle.top;
    }
    if (withinX && (point.dy - frame.bottom).abs() <= edgeSlop) {
      return CropHandle.bottom;
    }
    if (withinY && (point.dx - frame.left).abs() <= edgeSlop) {
      return CropHandle.left;
    }
    if (withinY && (point.dx - frame.right).abs() <= edgeSlop) {
      return CropHandle.right;
    }
    if (frame.contains(point)) return CropHandle.move;
    return null;
  }

  /// The frame after dragging [handle] of [start] by [delta], kept inside
  /// [bounds], at least [minSide] on each side and, when [aspectRatio] is
  /// set, at that width / height ratio.
  static Rect dragFrame({
    required Rect start,
    required CropHandle handle,
    required Offset delta,
    required Rect bounds,
    required double minSide,
    double? aspectRatio,
  }) {
    if (handle == CropHandle.move) {
      final dx = _within(
        delta.dx,
        bounds.left - start.left,
        bounds.right - start.right,
      );
      final dy = _within(
        delta.dy,
        bounds.top - start.top,
        bounds.bottom - start.bottom,
      );
      return start.shift(Offset(dx, dy));
    }

    final min = math.min(minSide, math.min(bounds.width, bounds.height));
    var left = start.left;
    var top = start.top;
    var right = start.right;
    var bottom = start.bottom;

    final movesLeft =
        handle == CropHandle.topLeft ||
        handle == CropHandle.bottomLeft ||
        handle == CropHandle.left;
    final movesRight =
        handle == CropHandle.topRight ||
        handle == CropHandle.bottomRight ||
        handle == CropHandle.right;
    final movesTop =
        handle == CropHandle.topLeft ||
        handle == CropHandle.topRight ||
        handle == CropHandle.top;
    final movesBottom =
        handle == CropHandle.bottomLeft ||
        handle == CropHandle.bottomRight ||
        handle == CropHandle.bottom;

    if (movesLeft) {
      left = math.max(
        bounds.left,
        math.min(start.left + delta.dx, right - min),
      );
    }
    if (movesRight) {
      right = math.min(
        bounds.right,
        math.max(start.right + delta.dx, left + min),
      );
    }
    if (movesTop) {
      top = math.max(bounds.top, math.min(start.top + delta.dy, bottom - min));
    }
    if (movesBottom) {
      bottom = math.min(
        bounds.bottom,
        math.max(start.bottom + delta.dy, top + min),
      );
    }

    final ratio = aspectRatio;
    if (ratio == null || ratio <= 0) {
      return Rect.fromLTRB(left, top, right, bottom);
    }

    final isCorner = (movesLeft || movesRight) && (movesTop || movesBottom);
    if (isCorner) {
      // Keep the opposite corner fixed.
      final anchor = Offset(
        movesLeft ? start.right : start.left,
        movesTop ? start.bottom : start.top,
      );
      var width = right - left;
      var height = bottom - top;
      if (width / height > ratio) {
        height = width / ratio;
      } else {
        width = height * ratio;
      }
      final maxWidth = movesLeft
          ? anchor.dx - bounds.left
          : bounds.right - anchor.dx;
      final maxHeight = movesTop
          ? anchor.dy - bounds.top
          : bounds.bottom - anchor.dy;
      if (width > maxWidth) {
        width = maxWidth;
        height = width / ratio;
      }
      if (height > maxHeight) {
        height = maxHeight;
        width = height * ratio;
      }
      final x = movesLeft ? anchor.dx - width : anchor.dx;
      final y = movesTop ? anchor.dy - height : anchor.dy;
      return Rect.fromLTWH(x, y, width, height);
    }

    // Edge drag: grow the other dimension around the frame's center.
    if (movesLeft || movesRight) {
      var width = right - left;
      var height = width / ratio;
      final maxHeight = bounds.height;
      if (height > maxHeight) {
        height = maxHeight;
        width = height * ratio;
      }
      final x = movesLeft ? right - width : left;
      final y = _within(
        start.center.dy - height / 2,
        bounds.top,
        bounds.bottom - height,
      );
      return Rect.fromLTWH(x, y, width, height);
    }
    var height = bottom - top;
    var width = height * ratio;
    final maxWidth = bounds.width;
    if (width > maxWidth) {
      width = maxWidth;
      height = width / ratio;
    }
    final y = movesTop ? bottom - height : top;
    final x = _within(
      start.center.dx - width / 2,
      bounds.left,
      bounds.right - width,
    );
    return Rect.fromLTWH(x, y, width, height);
  }

  /// [value] limited to [low]..[high]; [low] wins when they cross, so
  /// rounding never throws.
  static double _within(double value, double low, double high) {
    return math.max(low, math.min(value, high));
  }

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  CropHandle? _handle;
  Rect _startFrame = Rect.zero;
  Offset _startPoint = Offset.zero;
  bool _dragging = false;
  Size _size = Size.zero;

  ({Rect image, Rect frame})? _geometry(
    ChatImageEditorController controller,
    Size size,
  ) {
    if (controller.image == null) return null;
    final padding = EditorLayout.canvasPadding(context, EditorTool.crop);
    final output = EditorLayout.paintedOutputSize(controller);
    final image = EditorLayout.imageRect(size, padding, output);
    if (image.isEmpty) return null;
    final crop = controller.value.crop ?? const Rect.fromLTRB(0, 0, 1, 1);
    final frame = Rect.fromLTRB(
      image.left + crop.left * image.width,
      image.top + crop.top * image.height,
      image.left + crop.right * image.width,
      image.top + crop.bottom * image.height,
    );
    return (image: image, frame: frame);
  }

  void _handlePanStart(DragStartDetails details) {
    final controller = ChatImageEditorScope.of(context).controller;
    final geometry = _geometry(controller, _size);
    if (geometry == null) return;
    final handle = CropOverlay.handleAt(geometry.frame, details.localPosition);
    if (handle == null) return;
    setState(() {
      _handle = handle;
      _startFrame = geometry.frame;
      _startPoint = details.localPosition;
      _dragging = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final handle = _handle;
    if (handle == null) return;
    final controller = ChatImageEditorScope.of(context).controller;
    final geometry = _geometry(controller, _size);
    if (geometry == null) return;
    final image = geometry.image;
    final frame = CropOverlay.dragFrame(
      start: _startFrame,
      handle: handle,
      delta: details.localPosition - _startPoint,
      bounds: image,
      minSide: CropOverlay.minFrameSide,
      aspectRatio: controller.cropAspectRatio,
    );
    controller.setCrop(
      Rect.fromLTRB(
        ((frame.left - image.left) / image.width).clamp(0.0, 1.0),
        ((frame.top - image.top) / image.height).clamp(0.0, 1.0),
        ((frame.right - image.left) / image.width).clamp(0.0, 1.0),
        ((frame.bottom - image.top) / image.height).clamp(0.0, 1.0),
      ),
    );
  }

  void _handlePanEnd([Object? _]) {
    if (!_dragging && _handle == null) return;
    setState(() {
      _handle = null;
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final controller = scope.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: _handlePanStart,
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onPanCancel: _handlePanEnd,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final geometry = _geometry(controller, _size);
              if (geometry == null) return const SizedBox.expand();
              return CustomPaint(
                size: Size.infinite,
                painter: CropFramePainter(
                  imageRect: geometry.image,
                  frame: geometry.frame,
                  showGrid: _dragging,
                  overlayColor: theme.cropOverlayColor,
                  frameColor: theme.cropFrameColor,
                  handleColor: theme.cropHandleColor,
                  gridColor: theme.cropGridColor,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Paints the shade outside the crop frame, the frame, its corner handles
/// and, while dragging, a rule-of-thirds grid.
class CropFramePainter extends CustomPainter {
  /// Creates the painter.
  CropFramePainter({
    required this.imageRect,
    required this.frame,
    required this.showGrid,
    required this.overlayColor,
    required this.frameColor,
    required this.handleColor,
    required this.gridColor,
  });

  /// The whole rotated image, in canvas pixels.
  final Rect imageRect;

  /// The crop frame, in canvas pixels.
  final Rect frame;

  /// Draw the rule-of-thirds grid.
  final bool showGrid;

  /// Shade outside the frame.
  final Color overlayColor;

  /// Frame border.
  final Color frameColor;

  /// Corner handles.
  final Color handleColor;

  /// Grid lines.
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(imageRect)
      ..addRect(frame);
    canvas.drawPath(shade, Paint()..color = overlayColor);

    if (showGrid) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (var i = 1; i < 3; i++) {
        final x = frame.left + frame.width * i / 3;
        final y = frame.top + frame.height * i / 3;
        canvas
          ..drawLine(Offset(x, frame.top), Offset(x, frame.bottom), grid)
          ..drawLine(Offset(frame.left, y), Offset(frame.right, y), grid);
      }
    }

    canvas.drawRect(
      frame,
      Paint()
        ..color = frameColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final length = math.min(22.0, frame.shortestSide / 3);
    final handle = Paint()
      ..color = handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    final inset = frame.deflate(1);
    void corner(Offset point, double dx, double dy) {
      canvas
        ..drawLine(point, point + Offset(dx * length, 0), handle)
        ..drawLine(point, point + Offset(0, dy * length), handle);
    }

    corner(inset.topLeft, 1, 1);
    corner(inset.topRight, -1, 1);
    corner(inset.bottomLeft, 1, -1);
    corner(inset.bottomRight, -1, -1);

    final edge = math.min(18.0, frame.shortestSide / 4);
    canvas
      ..drawLine(
        inset.topCenter - Offset(edge / 2, 0),
        inset.topCenter + Offset(edge / 2, 0),
        handle,
      )
      ..drawLine(
        inset.bottomCenter - Offset(edge / 2, 0),
        inset.bottomCenter + Offset(edge / 2, 0),
        handle,
      )
      ..drawLine(
        inset.centerLeft - Offset(0, edge / 2),
        inset.centerLeft + Offset(0, edge / 2),
        handle,
      )
      ..drawLine(
        inset.centerRight - Offset(0, edge / 2),
        inset.centerRight + Offset(0, edge / 2),
        handle,
      );
  }

  @override
  bool shouldRepaint(CropFramePainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.frame != frame ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.frameColor != frameColor ||
        oldDelegate.handleColor != handleColor ||
        oldDelegate.gridColor != gridColor;
  }
}
