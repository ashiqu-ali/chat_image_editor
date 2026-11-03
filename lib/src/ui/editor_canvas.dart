import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/chat_image_editor_controller.dart';
import '../core/geometry/image_geometry.dart';
import '../core/render/composition_renderer.dart';
import '../models/editor_enums.dart';
import '../models/image_edit_value.dart';
import '../models/stroke.dart';
import '../theme/chat_image_editor_scope.dart';
import 'editor_host.dart';
import 'editor_layout.dart';
import 'text_layer_gestures.dart';

enum _Interaction { none, draw, text, zoom, ignored }

/// The image surface: paints the composition and turns touches into draw,
/// text and zoom actions.
///
/// In crop mode it only paints; the crop overlay above it takes the
/// gestures. Zoom is view state (not an edit), so it lives here and resets
/// whenever a tool opens.
class EditorCanvas extends StatefulWidget {
  /// Creates the canvas.
  const EditorCanvas({super.key});

  /// Largest pinch-to-zoom factor.
  static const double maxZoom = 5;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  final TextLayerGestures _textGestures = TextLayerGestures();

  ChatImageEditorScope? _scope;
  EditorHost? _host;

  Size _size = Size.zero;
  EdgeInsets _padding = EdgeInsets.zero;

  _Interaction _interaction = _Interaction.none;
  int _pointers = 0;
  Offset? _firstDown;

  double _zoom = 1;
  Offset _zoomOffset = Offset.zero;
  double _phaseZoom = 1;
  Rect _phaseRect = Rect.zero;
  Offset _phaseFocal = Offset.zero;
  EditorTool? _zoomTool;
  String? _zoomEditingId;

  ChatImageEditorController get _controller => _scope!.controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = ChatImageEditorScope.of(context);
    _host = EditorHost.of(context);
  }

  @override
  void dispose() {
    _textGestures.dispose();
    super.dispose();
  }

  // ───────────────────────── Layout ─────────────────────────

  CanvasLayout? _layout() {
    final controller = _controller;
    if (controller.image == null) return null;
    final value = EditorLayout.paintedValue(controller);
    final output = ImageGeometry.outputSize(controller.originalSize, value);
    if (output.isEmpty) return null;
    final fit = EditorLayout.imageRect(_size, _padding, output);
    if (fit.isEmpty) return null;
    return CanvasLayout(
      imageRect: _applyZoom(fit),
      outputSize: output,
      originalSize: controller.originalSize,
      value: value,
    );
  }

  Rect _applyZoom(Rect fit) {
    if (_zoom <= 1) return fit;
    return _clampZoomed(
      Rect.fromCenter(
        center: fit.center + _zoomOffset,
        width: fit.width * _zoom,
        height: fit.height * _zoom,
      ),
    );
  }

  /// Keeps a zoomed image covering the canvas, or centered when it's still
  /// smaller than the canvas along an axis.
  Rect _clampZoomed(Rect rect) {
    final full = Offset.zero & _size;
    final padded = _padding.deflateRect(full);
    double axis(
      double start,
      double extent,
      double min,
      double max,
      double paddedMin,
      double paddedMax,
    ) {
      if (extent <= paddedMax - paddedMin) {
        return (paddedMin + paddedMax - extent) / 2;
      }
      final low = math.min(min, max - extent);
      final high = math.max(min, max - extent);
      return start.clamp(low, high).toDouble();
    }

    final left = axis(
      rect.left,
      rect.width,
      full.left,
      full.right,
      padded.left,
      padded.right,
    );
    final top = axis(
      rect.top,
      rect.height,
      full.top,
      full.bottom,
      padded.top,
      padded.bottom,
    );
    return Rect.fromLTWH(left, top, rect.width, rect.height);
  }

  /// Resets view state when a tool opens or text entry starts. In crop mode
  /// the pointer listener is removed, so pointer tracking starts over too.
  void _resetForModeChange(ChatImageEditorController controller) {
    final tool = controller.activeTool;
    final editingId = controller.editingTextId;
    if (tool == _zoomTool && editingId == _zoomEditingId) return;
    if (tool != _zoomTool) {
      _pointers = 0;
      _interaction = _Interaction.none;
      _firstDown = null;
    }
    _zoomTool = tool;
    _zoomEditingId = editingId;
    if (tool != EditorTool.none || editingId != null) {
      _zoom = 1;
      _zoomOffset = Offset.zero;
    }
  }

  Rect? _deleteTargetRect() {
    final context = _host?.deleteTargetKey.currentContext;
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    final origin = box.localToGlobal(Offset.zero);
    return (origin & box.size).inflate(16);
  }

  // ───────────────────────── Pointers ─────────────────────────

  void _handlePointerDown(PointerDownEvent event) {
    _pointers++;
    if (_pointers == 1) {
      _firstDown = event.localPosition;
      if (_controller.activeTool == EditorTool.none) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers == 0) _finishInteraction();
  }

  void _finishInteraction() {
    final controller = _controller;
    switch (_interaction) {
      case _Interaction.draw:
        controller.endStroke();
      case _Interaction.text:
        _textGestures.end(controller);
      case _Interaction.zoom:
        if (_zoom <= 1.01 && (_zoom != 1 || _zoomOffset != Offset.zero)) {
          setState(() {
            _zoom = 1;
            _zoomOffset = Offset.zero;
          });
        }
      case _Interaction.none:
      case _Interaction.ignored:
        break;
    }
    _interaction = _Interaction.none;
    _firstDown = null;
  }

  // ───────────────────────── Gestures ─────────────────────────

  void _handleTapUp(TapUpDetails details) {
    final layout = _layout();
    if (layout == null) return;
    final controller = _controller;
    final local = details.localPosition;
    switch (controller.activeTool) {
      case EditorTool.draw:
        controller.startStroke(layout.toView(local));
        controller.endStroke();
      case EditorTool.none:
      case EditorTool.text:
        final id = TextLayerGestures.hitTest(
          controller,
          local,
          layout,
          _scope!.theme.textLayerStyle,
        );
        if (id != null) {
          controller.editText(id);
        } else if (controller.activeTool == EditorTool.text &&
            layout.imageRect.contains(local)) {
          controller.addText(viewPosition: layout.toView(local));
        }
      case EditorTool.crop:
      case EditorTool.compress:
        break;
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    final layout = _layout();
    if (layout == null) {
      _interaction = _Interaction.ignored;
      return;
    }
    final controller = _controller;
    final focal = details.localFocalPoint;

    switch (_interaction) {
      case _Interaction.text:
        _textGestures.rebase(focal);
        return;
      case _Interaction.zoom:
        _beginZoomPhase(focal, layout);
        return;
      case _Interaction.draw:
        if (details.pointerCount > 1) {
          controller.cancelStroke();
          _interaction = _Interaction.ignored;
        }
        return;
      case _Interaction.ignored:
        return;
      case _Interaction.none:
        break;
    }

    final origin = _firstDown ?? focal;
    final tool = controller.activeTool;

    if (tool == EditorTool.draw) {
      if (details.pointerCount > 1) {
        _interaction = _Interaction.ignored;
        return;
      }
      controller.startStroke(layout.toView(origin));
      controller.updateStroke(layout.toView(focal));
      _interaction = _Interaction.draw;
      return;
    }

    if (tool == EditorTool.none || tool == EditorTool.text) {
      final id = TextLayerGestures.hitTest(
        controller,
        origin,
        layout,
        _scope!.theme.textLayerStyle,
      );
      if (id != null) {
        // Measure a one-finger drag from the touch-down point so the drag
        // slop isn't lost; a pinch starts from its focal point.
        final baseline = details.pointerCount > 1 ? focal : origin;
        _textGestures.begin(controller, id, baseline, layout);
        _interaction = _Interaction.text;
        return;
      }
    }

    if (tool == EditorTool.none && _scope!.config.enableZoom) {
      _beginZoomPhase(focal, layout);
      _interaction = _Interaction.zoom;
      return;
    }

    _interaction = _Interaction.ignored;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final controller = _controller;
    switch (_interaction) {
      case _Interaction.draw:
        if (details.pointerCount > 1) {
          controller.cancelStroke();
          _interaction = _Interaction.ignored;
          return;
        }
        final layout = _layout();
        if (layout == null) return;
        controller.updateStroke(layout.toView(details.localFocalPoint));
      case _Interaction.text:
        final layout = _layout();
        if (layout == null) return;
        _textGestures.update(
          controller,
          localFocal: details.localFocalPoint,
          globalFocal: details.focalPoint,
          scale: details.scale,
          rotation: details.rotation,
          layout: layout,
          haptics: _scope!.config.enableHaptics,
          deleteTarget: _deleteTargetRect(),
        );
      case _Interaction.zoom:
        _updateZoom(details);
      case _Interaction.none:
      case _Interaction.ignored:
        break;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (details.pointerCount == 0) {
      _finishInteraction();
      return;
    }
    // A finger was added or lifted mid-gesture; the recognizer restarts.
    if (_interaction == _Interaction.draw) {
      _controller.cancelStroke();
      _interaction = _Interaction.ignored;
    }
  }

  void _beginZoomPhase(Offset focal, CanvasLayout layout) {
    _phaseZoom = _zoom;
    _phaseRect = layout.imageRect;
    _phaseFocal = focal;
  }

  void _updateZoom(ScaleUpdateDetails details) {
    final output = EditorLayout.paintedOutputSize(_controller);
    if (output.isEmpty || _phaseRect.isEmpty) return;
    final fit = EditorLayout.imageRect(_size, _padding, output);
    if (fit.isEmpty) return;
    final zoom = (_phaseZoom * details.scale)
        .clamp(1.0, EditorCanvas.maxZoom)
        .toDouble();
    final anchor = EditorLayout.toNormalized(_phaseFocal, _phaseRect);
    final width = fit.width * zoom;
    final height = fit.height * zoom;
    final topLeft =
        details.localFocalPoint - Offset(anchor.dx * width, anchor.dy * height);
    final rect = _clampZoomed(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, width, height),
    );
    setState(() {
      _zoom = zoom;
      _zoomOffset = rect.center - fit.center;
    });
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final controller = scope.controller;
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            _size = constraints.biggest;
            _resetForModeChange(controller);
            final tool = controller.activeTool;
            _padding = EditorLayout.canvasPadding(context, tool);

            final image = controller.image;
            final layout = _layout();
            if (image == null || layout == null) {
              return const SizedBox.expand();
            }
            final editingId = controller.editingTextId;
            final painting = RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: CompositionPainter(
                  image: image,
                  originalSize: controller.originalSize,
                  value: layout.value,
                  outputSize: layout.outputSize,
                  imageRect: layout.imageRect,
                  textStyle: scope.theme.textLayerStyle,
                  draftStroke: controller.draftStroke,
                  hiddenTextIds: editingId == null
                      ? const <String>{}
                      : <String>{editingId},
                ),
              ),
            );
            if (tool == EditorTool.crop) return painting;

            return Listener(
              onPointerDown: _handlePointerDown,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerUp,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _handleTapUp,
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    painting,
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: GuideLinesPainter(
                          guides: _textGestures.guides,
                          imageRect: layout.imageRect,
                          color: scope.theme.guideLineColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Paints the composition into a rect of the canvas through
/// `CompositionRenderer.paint`, the same call the export uses.
class CompositionPainter extends CustomPainter {
  /// Creates the painter.
  CompositionPainter({
    required this.image,
    required this.originalSize,
    required this.value,
    required this.outputSize,
    required this.imageRect,
    required this.textStyle,
    this.draftStroke,
    this.hiddenTextIds = const <String>{},
  });

  /// The decoded preview image.
  final ui.Image image;

  /// Full pixel size of the source image.
  final Size originalSize;

  /// The edits to paint.
  final ImageEditValue value;

  /// Size of [value]'s output in output pixels.
  final Size outputSize;

  /// Where the output is drawn, in canvas pixels.
  final Rect imageRect;

  /// Base style for text layers.
  final TextStyle textStyle;

  /// The stroke being drawn, if any.
  final Stroke? draftStroke;

  /// Text layers not to paint (the one open in text entry).
  final Set<String> hiddenTextIds;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageRect.isEmpty || outputSize.isEmpty) return;
    canvas
      ..save()
      ..clipRect(imageRect)
      ..translate(imageRect.left, imageRect.top)
      ..scale(
        imageRect.width / outputSize.width,
        imageRect.height / outputSize.height,
      );
    CompositionRenderer.paint(
      canvas,
      image: image,
      originalSize: originalSize,
      value: value,
      textStyle: textStyle,
      draftStroke: draftStroke,
      hiddenTextIds: hiddenTextIds,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CompositionPainter oldDelegate) {
    return !identical(oldDelegate.image, image) ||
        oldDelegate.originalSize != originalSize ||
        !identical(oldDelegate.value, value) ||
        oldDelegate.outputSize != outputSize ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.textStyle != textStyle ||
        !identical(oldDelegate.draftStroke, draftStroke) ||
        !setEquals(oldDelegate.hiddenTextIds, hiddenTextIds);
  }
}
