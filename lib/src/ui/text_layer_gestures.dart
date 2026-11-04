import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/chat_image_editor_controller.dart';
import '../core/geometry/image_geometry.dart';
import '../core/render/text_renderer.dart';
import '../models/image_edit_value.dart';
import 'editor_haptics.dart';
import 'editor_layout.dart';

/// Which center guides show while a text layer is moved.
///
/// Guides only indicate alignment; they never move the layer.
@immutable
class CenterGuides {
  /// Creates a guide state.
  const CenterGuides({this.vertical = false, this.horizontal = false});

  /// No guides.
  static const CenterGuides none = CenterGuides();

  /// The layer's center is on the image's vertical center line.
  final bool vertical;

  /// The layer's center is on the image's horizontal center line.
  final bool horizontal;

  /// Whether any guide shows.
  bool get any => vertical || horizontal;

  @override
  bool operator ==(Object other) {
    return other is CenterGuides &&
        other.vertical == vertical &&
        other.horizontal == horizontal;
  }

  @override
  int get hashCode => Object.hash(vertical, horizontal);
}

/// Where the painted image sits on screen, for mapping gestures.
@immutable
class CanvasLayout {
  /// Creates a layout snapshot.
  const CanvasLayout({
    required this.imageRect,
    required this.outputSize,
    required this.originalSize,
    required this.value,
  });

  /// The displayed image in canvas pixels (zoom included).
  final Rect imageRect;

  /// Size of the painted output in output pixels.
  final Size outputSize;

  /// Full pixel size of the source image.
  final Size originalSize;

  /// The edits being painted.
  final ImageEditValue value;

  /// Canvas pixels per output (original-image) pixel.
  double get displayScale {
    if (outputSize.width <= 0) return 0;
    return imageRect.width / outputSize.width;
  }

  /// [local] normalized over the displayed image (view space).
  Offset toView(Offset local) => EditorLayout.toNormalized(local, imageRect);
}

/// Move, pinch and rotate handling for committed text layers.
///
/// Holds only transient gesture bookkeeping; every change is sent to the
/// controller (`startTextGesture`, `updateTextGesture`, `endTextGesture`).
/// The recognizer restarts its gesture whenever a finger is added or lifted,
/// so each phase is rebased onto the accumulated totals to keep the values
/// relative to the very first touch, as the controller expects.
class TextLayerGestures {
  /// Creates the handler.
  TextLayerGestures();

  /// Center guides to draw; updated while a layer moves.
  final ValueNotifier<CenterGuides> guides = ValueNotifier<CenterGuides>(
    CenterGuides.none,
  );

  /// Extra touch margin around text, in canvas pixels.
  static const double hitSlop = 12;

  /// Distance from a center line, in canvas pixels, within which a layer's
  /// center counts as aligned and the guide shows.
  static const double guideDistance = 8;

  String? _id;
  Offset _startView = Offset.zero;
  double _minScale = 0;
  double _maxScale = double.infinity;
  Offset _phaseFocal = Offset.zero;
  Offset _baseTranslation = Offset.zero;
  Offset _translation = Offset.zero;
  double _baseScale = 1;
  double _scale = 1;
  double _baseRotation = 0;
  double _rotation = 0;
  bool _overDelete = false;

  /// Whether a layer is being manipulated.
  bool get isActive => _id != null;

  /// The id of the topmost layer under [local] (canvas pixels), skipping the
  /// layer open in text entry, or `null`.
  static String? hitTest(
    ChatImageEditorController controller,
    Offset local,
    CanvasLayout layout,
    TextStyle baseStyle,
  ) {
    final texts = layout.value.texts;
    final scale = layout.displayScale;
    if (texts.isEmpty || scale <= 0) return null;
    final normalized = ImageGeometry.viewToOriginal(
      layout.toView(local),
      layout.originalSize,
      layout.value,
    );
    final point = Offset(
      normalized.dx * layout.originalSize.width,
      normalized.dy * layout.originalSize.height,
    );
    final slop = hitSlop / scale;
    final editingId = controller.editingTextId;
    for (var i = texts.length - 1; i >= 0; i--) {
      final layer = texts[i];
      if (layer.id == editingId) continue;
      final hit = TextRenderer.hitTest(
        layer,
        point,
        layout.originalSize,
        baseStyle: baseStyle,
        slop: slop,
      );
      if (hit) return layer.id;
    }
    return null;
  }

  /// Starts manipulating layer [id] with the first focal point [focal].
  void begin(
    ChatImageEditorController controller,
    String id,
    Offset focal,
    CanvasLayout layout,
  ) {
    final layer = controller.textById(id);
    controller.startTextGesture(id);
    _id = id;
    _startView = layer == null
        ? const Offset(0.5, 0.5)
        : ImageGeometry.originalToView(
            layer.position,
            layout.originalSize,
            layout.value,
          );
    final startSize = layer?.fontSize ?? 0;
    final config = controller.config;
    if (startSize > 0) {
      _minScale = config.minFontSize / startSize;
      _maxScale = config.maxFontSize / startSize;
    } else {
      _minScale = 0;
      _maxScale = double.infinity;
    }
    _phaseFocal = focal;
    _baseTranslation = Offset.zero;
    _translation = Offset.zero;
    _baseScale = 1;
    _scale = 1;
    _baseRotation = 0;
    _rotation = 0;
    _overDelete = false;
    guides.value = CenterGuides.none;
  }

  /// Starts a new recognizer phase (a finger was added or lifted) at
  /// [focal], keeping the totals so far.
  void rebase(Offset focal) {
    _phaseFocal = focal;
    _baseTranslation = _translation;
    _baseScale = _scale;
    _baseRotation = _rotation;
  }

  /// Applies a recognizer update. [scale] and [rotation] are relative to the
  /// current phase. [deleteTarget] is the delete target in global
  /// coordinates, when it's on screen.
  ///
  /// The layer follows the fingers exactly. Center guides show while its
  /// center is within [guideDistance] of the image's center lines, with a
  /// light haptic when one first appears; they're hidden while the layer
  /// hovers the delete target.
  void update(
    ChatImageEditorController controller, {
    required Offset localFocal,
    required Offset globalFocal,
    required double scale,
    required double rotation,
    required CanvasLayout layout,
    required bool haptics,
    Rect? deleteTarget,
  }) {
    if (_id == null) return;
    final rect = layout.imageRect;
    if (rect.isEmpty) return;

    _translation =
        _baseTranslation +
        Offset(
          (localFocal.dx - _phaseFocal.dx) / rect.width,
          (localFocal.dy - _phaseFocal.dy) / rect.height,
        );
    _scale = (_baseScale * scale).clamp(_minScale, _maxScale).toDouble();
    _rotation = _baseRotation + rotation;

    controller.updateTextGesture(
      viewTranslation: _translation,
      scale: _scale,
      rotation: _rotation,
    );

    final over = deleteTarget != null && deleteTarget.contains(globalFocal);
    if (over != _overDelete) {
      _overDelete = over;
      controller.setOverDeleteTarget(over);
      if (over) editorHaptic(enabled: haptics);
    }

    final center = _startView + _translation;
    final next = over
        ? CenterGuides.none
        : CenterGuides(
            vertical: (center.dx - 0.5).abs() * rect.width <= guideDistance,
            horizontal: (center.dy - 0.5).abs() * rect.height <= guideDistance,
          );
    final previous = guides.value;
    if ((next.vertical && !previous.vertical) ||
        (next.horizontal && !previous.horizontal)) {
      editorHaptic(enabled: haptics);
    }
    guides.value = next;
  }

  /// Ends the gesture. The controller deletes the layer if it was dropped on
  /// the delete target.
  void end(ChatImageEditorController controller) {
    if (_id == null) return;
    _id = null;
    _overDelete = false;
    guides.value = CenterGuides.none;
    controller.endTextGesture();
  }

  /// Releases the guide notifier.
  void dispose() => guides.dispose();
}

/// Paints the center guide lines while a moved text layer is aligned.
class GuideLinesPainter extends CustomPainter {
  /// Creates the painter. Repaints when [guides] changes.
  GuideLinesPainter({
    required this.guides,
    required this.imageRect,
    required this.color,
  }) : super(repaint: guides);

  /// Which guides to draw.
  final ValueListenable<CenterGuides> guides;

  /// The displayed image, in canvas pixels.
  final Rect imageRect;

  /// Line color.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final state = guides.value;
    if (!state.any || imageRect.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final center = imageRect.center;
    if (state.vertical) {
      canvas.drawLine(
        Offset(center.dx, imageRect.top),
        Offset(center.dx, imageRect.bottom),
        paint,
      );
    }
    if (state.horizontal) {
      canvas.drawLine(
        Offset(imageRect.left, center.dy),
        Offset(imageRect.right, center.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GuideLinesPainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.color != color ||
        oldDelegate.guides != guides;
  }
}
