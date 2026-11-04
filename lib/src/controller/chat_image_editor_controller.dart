import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import '../config/chat_image_editor_config.dart';
import '../config/export_options.dart';
import '../core/encoding/dart_image_encoder.dart';
import '../core/encoding/image_encoder.dart';
import '../core/export/chat_image_editor_result.dart';
import '../core/export/image_exporter.dart';
import '../core/geometry/edit_geometry.dart';
import '../core/geometry/image_geometry.dart';
import '../core/history/edit_history.dart';
import '../core/loading/image_loader.dart';
import '../core/tracing/editor_timeline.dart';
import '../models/editor_enums.dart';
import '../models/image_edit_value.dart';
import '../models/stroke.dart';
import '../models/text_layer.dart';

/// Holds the editor state and every editing action.
///
/// `ChatImageEditor` creates one automatically. Create your own to drive the
/// editor from code, read its state, or build a fully custom UI:
///
/// ```dart
/// final controller = ChatImageEditorController();
/// ChatImageEditor(image: bytes, controller: controller);
/// // later
/// controller.rotateRight();
/// ```
///
/// ## Points
///
/// Methods taking a `viewPoint` or `viewPosition` expect a point normalized
/// over the visible, cropped image (view space, see `ImageEditValue`).
/// The controller converts it to original space through `ImageGeometry`.
///
/// ## History
///
/// Undo and redo step between `ImageEditValue` snapshots. One entry is
/// recorded per completed action: a finished stroke, a finished text edit
/// session, a finished text gesture, a deleted layer, a confirmed crop
/// session or a committed quality change. Undo and redo first close any
/// open crop session (cancelling it) or text entry (finishing it).
class ChatImageEditorController extends ChangeNotifier {
  /// Creates a controller, optionally starting from [initialValue].
  ChatImageEditorController({
    ChatImageEditorConfig config = const ChatImageEditorConfig(),
    ImageEditValue initialValue = ImageEditValue.empty,
  }) : _config = config,
       _value = initialValue,
       _baseValue = initialValue,
       _history = EditHistory(initialValue),
       _shapeType = _offeredShape(config.shapes, ShapeType.freehand),
       _strokeWidth = _clampDouble(
         config.defaultStrokeWidth,
         config.minStrokeWidth,
         config.maxStrokeWidth,
       );

  /// Draw color used until the theme (or the user) picks one.
  static const Color _fallbackDrawColor = Color(0xFFF44336);

  /// Text color used until the theme (or the user) picks one.
  static const Color _fallbackTextColor = Color(0xFFFFFFFF);

  /// Text layer style used until the editor applies the theme's. Matches
  /// the default `ChatImageEditorThemeData.textLayerStyle`.
  static const TextStyle _defaultTextLayerStyle = TextStyle(
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// Smallest crop side, normalized over transformed space.
  static const double _minCropSize = 0.05;

  /// Freehand samples closer than this (fraction of the image's shortest
  /// side) to the previous one are skipped.
  static const double _minPointSpacing = 0.0015;

  /// Non-freehand shapes shorter than this (fraction of the shortest side),
  /// or than their own stroke width, are dropped as taps.
  static const double _minShapeLength = 0.01;

  ChatImageEditorConfig _config;
  TextStyle _textLayerStyle = _defaultTextLayerStyle;
  ImageEditValue _value;

  /// What [hasChanges] compares against: the starting value of the current
  /// image.
  ImageEditValue _baseValue;
  final EditHistory _history;

  bool _disposed = false;
  int _idCounter = 0;

  // Source image.
  ImageLoadStatus _loadStatus = ImageLoadStatus.idle;
  Object? _loadError;
  ui.Image? _image;
  Size _originalSize = Size.zero;
  Uint8List? _sourceBytes;
  int _loadGeneration = 0;
  Future<void>? _pendingLoad;

  // Tools.
  EditorTool _activeTool = EditorTool.none;

  // Draw.
  ShapeType _shapeType;
  Color _drawColor = _fallbackDrawColor;
  bool _drawColorChosen = false;
  double _strokeWidth;
  Stroke? _draftStroke;

  // Text.
  Color _textColor = _fallbackTextColor;
  bool _textColorChosen = false;
  TextBackgroundStyle _textBackground = TextBackgroundStyle.none;
  String? _editingTextId;
  String? _activeTextId;
  TextLayer? _gestureStart;
  bool _overDeleteTarget = false;

  // Crop.
  double? _cropAspectRatio;
  ImageEditValue? _cropSessionStart;
  double? _cropAspectBeforeSession;

  // Export.
  bool _isExporting = false;
  _EstimateCache? _estimates;

  /// Completes when the last queued size-estimate encode settles. Estimate
  /// encodes run one at a time: each holds copies of the full-resolution
  /// pixels, so running several at once could exhaust memory.
  Future<void> _estimateQueue = Future<void>.value();

  // ───────────────────────── Configuration ─────────────────────────

  /// Current configuration.
  ChatImageEditorConfig get config => _config;

  /// Replaces the configuration, clamping the current stroke width and
  /// sizes to the new limits, and switching [shapeType] to the first of
  /// `config.shapes` when the new list doesn't offer it.
  set config(ChatImageEditorConfig value) {
    if (identical(value, _config)) return;
    _config = value;
    _strokeWidth = _clampDouble(
      _strokeWidth,
      value.minStrokeWidth,
      value.maxStrokeWidth,
    );
    _shapeType = _offeredShape(value.shapes, _shapeType);
    _notifyOutsideBuild();
  }

  /// Sets the first draw and text colors from the resolved theme. Ignored
  /// for any color the user (or code) has already chosen.
  void applyDefaultColors({
    required Color drawColor,
    required Color textColor,
  }) {
    var changed = false;
    if (!_drawColorChosen && _drawColor != drawColor) {
      _drawColor = drawColor;
      changed = true;
    }
    if (!_textColorChosen && _textColor != textColor) {
      _textColor = textColor;
      changed = true;
    }
    if (changed) _notifyOutsideBuild();
  }

  /// Base style of text layers in [export] and [estimateSize]: font
  /// family, weight, shadows. Color and size always come from each layer.
  ///
  /// `ChatImageEditor` sets this from the resolved
  /// `ChatImageEditorThemeData.textLayerStyle`, so the export matches the
  /// preview. Set it yourself only when exporting without the widget.
  TextStyle get textLayerStyle => _textLayerStyle;

  /// Sets [textLayerStyle].
  set textLayerStyle(TextStyle value) {
    if (value == _textLayerStyle) return;
    _textLayerStyle = value;
    _notifyOutsideBuild();
  }

  // ───────────────────────── Source image ─────────────────────────

  /// Progress of [load].
  ImageLoadStatus get loadStatus => _loadStatus;

  /// Error from the last failed [load], if any.
  Object? get loadError => _loadError;

  /// The decoded preview image, at most
  /// `ChatImageEditorConfig.previewMaxLongEdge` on its long side. `null`
  /// until [loadStatus] is [ImageLoadStatus.ready].
  ui.Image? get image => _loadStatus == ImageLoadStatus.ready ? _image : null;

  /// Full pixel size of the source image (not the preview), or
  /// [Size.zero] before loading.
  Size get originalSize => _originalSize;

  /// The source bytes passed to [load].
  Uint8List? get sourceBytes => _sourceBytes;

  /// Decodes [bytes] for editing. Safe to call again with a new image;
  /// edits and history are cleared.
  Future<void> load(Uint8List bytes) {
    if (_disposed) return Future<void>.value();
    final sameBytes = identical(bytes, _sourceBytes);
    if (sameBytes) {
      if (_loadStatus == ImageLoadStatus.ready) return Future<void>.value();
      final pending = _pendingLoad;
      if (_loadStatus == ImageLoadStatus.loading && pending != null) {
        return pending;
      }
    } else if (_sourceBytes != null) {
      // A different image: the previous edits don't apply to it.
      _resetEditingState();
      _value = ImageEditValue.empty;
      _baseValue = ImageEditValue.empty;
      _history.reset(ImageEditValue.empty);
    }

    final generation = ++_loadGeneration;
    _sourceBytes = bytes;
    _image?.dispose();
    _image = null;
    if (!sameBytes) _originalSize = Size.zero;
    _loadStatus = ImageLoadStatus.loading;
    _loadError = null;
    _estimates = null;
    _notifyOutsideBuild();

    final future = _decode(bytes, generation);
    _pendingLoad = future;
    return future;
  }

  Future<void> _decode(Uint8List bytes, int generation) async {
    final previewMaxLongEdge = _config.previewMaxLongEdge;
    final task = EditorTimeline.task()
      ?..start(
        EditorTimeline.load,
        arguments: <String, Object?>{
          'bytes': bytes.length,
          'previewMaxLongEdge': previewMaxLongEdge,
        },
      );
    var outcome = 'superseded';
    try {
      final loaded = await ImageLoader.decode(
        bytes,
        maxLongEdge: previewMaxLongEdge,
      );
      if (_disposed || generation != _loadGeneration) {
        loaded.image.dispose();
        return;
      }
      _image = loaded.image;
      _originalSize = loaded.originalSize;
      _loadStatus = ImageLoadStatus.ready;
      outcome = 'ready';
    } catch (error) {
      if (_disposed || generation != _loadGeneration) return;
      _originalSize = Size.zero;
      _loadStatus = ImageLoadStatus.failed;
      _loadError = error;
      outcome = 'failed';
    } finally {
      if (generation == _loadGeneration) _pendingLoad = null;
      final image = outcome == 'ready' ? _image : null;
      task?.finish(
        arguments: <String, Object?>{
          'outcome': outcome,
          if (image != null) 'width': image.width,
          if (image != null) 'height': image.height,
          if (image != null) 'originalWidth': _originalSize.width.round(),
          if (image != null) 'originalHeight': _originalSize.height.round(),
        },
      );
    }
    _notify();
  }

  // ───────────────────────── Document & history ─────────────────────────

  /// The current edits. While the crop tool is open this includes the
  /// in-progress crop, rotation and flips.
  ImageEditValue get value => _value;

  /// Whether there is anything to lose on close (edits or caption are
  /// tracked separately by the widget).
  bool get hasChanges => _withoutEmptyEditingLayer(_value) != _baseValue;

  /// Whether [undo] would do something.
  bool get canUndo =>
      _history.canUndo || _valueAfterClosingSessions() != _history.current;

  /// Whether [redo] would do something.
  bool get canRedo =>
      _history.canRedo && _valueAfterClosingSessions() == _history.current;

  /// Steps back one history entry.
  void undo() {
    var changed = _closeSessionsForHistory();
    final previous = _history.undo();
    if (previous != null) {
      _value = previous;
      changed = true;
    }
    if (changed) _notify();
  }

  /// Steps forward one history entry.
  void redo() {
    var changed = _closeSessionsForHistory();
    final next = _history.redo();
    if (next != null) {
      _value = next;
      changed = true;
    }
    if (changed) _notify();
  }

  /// Removes every edit, as one undoable entry.
  void clearEdits() {
    var changed = _closeSessionsForHistory();
    if (_cropAspectRatio != null) {
      _cropAspectRatio = null;
      changed = true;
    }
    if (_value != ImageEditValue.empty) {
      _value = ImageEditValue.empty;
      _commit();
      changed = true;
    }
    if (changed) _notify();
  }

  // ───────────────────────── Tools ─────────────────────────

  /// The open tool.
  EditorTool get activeTool => _activeTool;

  /// Opens [tool], or closes it if it's already open.
  ///
  /// Opening crop starts a crop session. Leaving crop any way other than
  /// [confirmCrop] cancels it. Opening text immediately adds a layer at the
  /// center and opens text entry (see [addText]).
  void selectTool(EditorTool tool) {
    if (tool == _activeTool || tool == EditorTool.none) {
      closeTool();
      return;
    }
    _endTextGesture();
    _leaveActiveTool();
    _cancelDraft();
    switch (tool) {
      case EditorTool.crop:
        _activeTool = EditorTool.crop;
        _startCropSession();
      case EditorTool.text:
        _addTextLayer(null);
      case EditorTool.draw:
      case EditorTool.compress:
      case EditorTool.none:
        _activeTool = tool;
    }
    _notify();
  }

  /// Closes the open tool (cancelling a crop session, finishing text entry
  /// and committing a quality change).
  void closeTool() {
    final changed = _leaveActiveTool();
    if (changed) _notify();
  }

  // ───────────────────────── Draw ─────────────────────────

  /// Shape used by the next stroke. Always one of `config.shapes` when that
  /// list isn't empty; starts on the first of them unless it offers
  /// [ShapeType.freehand].
  ShapeType get shapeType => _shapeType;

  /// Sets [shapeType]. Ignored for a shape that a non-empty
  /// `config.shapes` doesn't offer.
  void setShapeType(ShapeType type) {
    if (type == _shapeType) return;
    if (_offeredShape(_config.shapes, type) != type) return;
    _shapeType = type;
    _notify();
  }

  /// Color of the next stroke.
  Color get drawColor => _drawColor;

  /// Sets [drawColor].
  void setDrawColor(Color color) {
    _drawColorChosen = true;
    if (color == _drawColor) return;
    _drawColor = color;
    _notify();
  }

  /// Width of the next stroke as a fraction of the image's shortest side,
  /// within the config's min and max.
  double get strokeWidth => _strokeWidth;

  /// Sets [strokeWidth], clamped to the config's limits.
  void setStrokeWidth(double width) {
    if (width.isNaN) return;
    final clamped = _clampDouble(
      width,
      _config.minStrokeWidth,
      _config.maxStrokeWidth,
    );
    if (clamped == _strokeWidth) return;
    _strokeWidth = clamped;
    _notify();
  }

  /// The stroke being drawn right now, if any.
  Stroke? get draftStroke => _draftStroke;

  /// Starts a stroke at [viewPoint]. An open crop session is cancelled
  /// first, as leaving crop any way other than [confirmCrop] does.
  void startStroke(Offset viewPoint) {
    _cancelCropSession();
    _draftStroke = Stroke(
      id: _newId('stroke'),
      type: _shapeType,
      points: <Offset>[_toOriginal(viewPoint)],
      color: _drawColor,
      width: _strokeWidth,
    );
    _notify();
  }

  /// Extends the draft stroke to [viewPoint]. Freehand appends a point
  /// (skipping near-duplicates); other shapes move their end point.
  void updateStroke(Offset viewPoint) {
    final draft = _draftStroke;
    if (draft == null) return;
    final point = _toOriginal(viewPoint);
    final List<Offset> points;
    if (draft.type == ShapeType.freehand) {
      if (_relativeDistance(draft.points.last, point) < _minPointSpacing) {
        return;
      }
      points = <Offset>[...draft.points, point];
    } else {
      if (draft.points.length > 1 && draft.points.last == point) return;
      points = <Offset>[draft.points.first, point];
    }
    _draftStroke = draft.copyWith(points: points);
    _notify();
  }

  /// Commits the draft stroke as one history entry. Strokes too small to
  /// see (a tap) still commit as a dot for freehand, and are dropped for
  /// other shapes.
  void endStroke() {
    final draft = _draftStroke;
    if (draft == null) return;
    _draftStroke = null;

    final first = draft.points.first;
    var extent = 0.0;
    for (final p in draft.points) {
      final d = _relativeDistance(first, p);
      if (d > extent) extent = d;
    }

    Stroke? committed;
    if (draft.type == ShapeType.freehand) {
      committed = extent < draft.width / 2
          ? draft.copyWith(points: <Offset>[first])
          : draft;
    } else {
      final minLength = draft.width > _minShapeLength
          ? draft.width
          : _minShapeLength;
      committed = extent < minLength ? null : draft;
    }

    if (committed != null) {
      _value = _value.copyWith(
        strokes: List<Stroke>.unmodifiable(<Stroke>[
          ..._value.strokes,
          committed,
        ]),
      );
      _commit();
    }
    _notify();
  }

  /// Drops the draft stroke without recording anything.
  void cancelStroke() {
    if (_cancelDraft()) _notify();
  }

  // ───────────────────────── Text ─────────────────────────

  /// Color for new text, also applied live to the layer being edited.
  Color get textColor => _textColor;

  /// Sets [textColor] and recolors the layer in text entry, if any.
  void setTextColor(Color color) {
    _textColorChosen = true;
    var changed = false;
    if (color != _textColor) {
      _textColor = color;
      changed = true;
    }
    final editing = editingText;
    if (editing != null && editing.color != color) {
      _replaceLayer(editing.copyWith(color: color));
      changed = true;
    }
    if (changed) _notify();
  }

  /// Background style for new text, also applied live to the layer being
  /// edited.
  TextBackgroundStyle get textBackground => _textBackground;

  /// Sets [textBackground] and applies it to the layer in text entry.
  void setTextBackground(TextBackgroundStyle style) {
    var changed = false;
    if (style != _textBackground) {
      _textBackground = style;
      changed = true;
    }
    final editing = editingText;
    if (editing != null && editing.background != style) {
      _replaceLayer(editing.copyWith(background: style));
      changed = true;
    }
    if (changed) _notify();
  }

  /// Advances [textBackground] to the next style, wrapping around.
  void cycleTextBackground() {
    const styles = TextBackgroundStyle.values;
    setTextBackground(styles[(_textBackground.index + 1) % styles.length]);
  }

  /// Id of the layer open in text entry, if any.
  String? get editingTextId => _editingTextId;

  /// The layer open in text entry, if any.
  TextLayer? get editingText {
    final id = _editingTextId;
    return id == null ? null : textById(id);
  }

  /// Looks up a layer by id.
  TextLayer? textById(String id) {
    for (final layer in _value.texts) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  /// Adds an empty layer at [viewPosition] (default: the center) with the
  /// current text color, background and the config's default size, sets it
  /// upright for the current rotation and flips, opens text entry for it
  /// and returns its id.
  String addText({Offset? viewPosition}) {
    _endTextGesture();
    _leaveActiveTool();
    _cancelDraft();
    final id = _addTextLayer(viewPosition);
    _notify();
    return id;
  }

  /// Opens text entry for an existing layer.
  void editText(String id) {
    if (_editingTextId == id) return;
    if (textById(id) == null) return;
    _endTextGesture();
    _leaveActiveTool();
    _cancelDraft();
    // Look the layer up again: ending a gesture over the delete target may
    // have removed it.
    final layer = textById(id);
    if (layer != null) {
      _editingTextId = id;
      _activeTool = EditorTool.text;
      // The color strip and background button show the edited layer's
      // style, and new text continues with it.
      _textColor = layer.color;
      _textColorChosen = true;
      _textBackground = layer.background;
    }
    _notify();
  }

  /// Replaces the text of the layer in text entry.
  void updateEditingText(String text) {
    final editing = editingText;
    if (editing == null || editing.text == text) return;
    _replaceLayer(editing.copyWith(text: text));
    _notify();
  }

  /// Closes text entry. Empty layers are removed; otherwise one history
  /// entry is recorded if anything changed during the session.
  void finishTextEditing() {
    if (_finishTextEntry()) _notify();
  }

  /// Id of the layer being moved, scaled or rotated, if any.
  String? get activeTextId => _activeTextId;

  /// Whether the active layer is over the drag-to-delete target.
  bool get isOverDeleteTarget => _overDeleteTarget;

  /// Starts a move/scale/rotate gesture on a layer and brings it to the
  /// top. An open crop session is cancelled first.
  void startTextGesture(String id) {
    if (textById(id) == null) return;
    _cancelCropSession();
    _endTextGesture();
    if (_editingTextId != null) _finishTextEntry();
    final layer = textById(id);
    if (layer != null) {
      _value = _withLayerOnTop(_value, id);
      _activeTextId = id;
      _gestureStart = layer;
      _overDeleteTarget = false;
    }
    _notify();
  }

  /// Updates the active gesture. All values are relative to the gesture
  /// start: [viewTranslation] is normalized over view space, [scale]
  /// multiplies the start font size (clamped to the config's limits) and
  /// [rotation] (radians, clockwise on screen) adds to the start rotation.
  void updateTextGesture({
    Offset viewTranslation = Offset.zero,
    double scale = 1,
    double rotation = 0,
  }) {
    final id = _activeTextId;
    final start = _gestureStart;
    if (id == null || start == null) return;
    final current = textById(id);
    if (current == null) return;

    final startView = ImageGeometry.originalToView(
      start.position,
      _originalSize,
      _value,
    );
    final translation = viewTranslation.isFinite
        ? viewTranslation
        : Offset.zero;
    final position = ImageGeometry.viewToOriginal(
      startView + translation,
      _originalSize,
      _value,
    );
    final safeScale = scale.isFinite && scale > 0 ? scale : 1.0;
    final fontSize = _clampDouble(
      start.fontSize * safeScale,
      _config.minFontSize,
      _config.maxFontSize,
    );
    final turn = rotation.isFinite ? rotation : 0.0;
    final layerRotation =
        start.rotation + EditGeometry.screenRotationSign(_value) * turn;

    final updated = current.copyWith(
      position: position,
      fontSize: fontSize,
      rotation: layerRotation,
    );
    if (updated == current) return;
    _replaceLayer(updated);
    _notify();
  }

  /// Marks whether the active layer hovers the delete target.
  void setOverDeleteTarget(bool over) {
    if (_activeTextId == null || _overDeleteTarget == over) return;
    _overDeleteTarget = over;
    _notify();
  }

  /// Ends the gesture: deletes the layer if it's over the delete target,
  /// otherwise records one history entry if it changed.
  void endTextGesture() {
    if (_endTextGesture()) _notify();
  }

  /// Deletes a layer as one history entry. An open crop session is
  /// cancelled first.
  void deleteText(String id) {
    if (textById(id) == null) return;
    final cancelledCrop = _cancelCropSession();
    if (textById(id) == null) {
      if (cancelledCrop) _notify();
      return;
    }
    if (_activeTextId == id) {
      _activeTextId = null;
      _gestureStart = null;
      _overDeleteTarget = false;
    }
    if (_editingTextId == id) {
      _editingTextId = null;
      if (_activeTool == EditorTool.text) _activeTool = EditorTool.none;
    }
    _value = _value.copyWith(texts: _textsWithout(id));
    _commit();
    _notify();
  }

  // ───────────────────────── Crop, rotate, flip ─────────────────────────

  /// Locked aspect ratio (width / height on screen), or `null` for free
  /// cropping.
  double? get cropAspectRatio => _cropAspectRatio;

  /// Sets the crop rectangle, normalized over transformed space. The rect
  /// is clamped inside the image, kept above a minimum size, and adjusted
  /// to [cropAspectRatio] when locked. `null` selects the whole image.
  void setCrop(Rect? crop) {
    if (crop != null && !_isFiniteRect(crop)) return;
    _applyCropEdit((ImageEditValue v) {
      final ratio = _normalizedLock(v);
      Rect? next;
      if (crop != null) {
        next = EditGeometry.constrainCrop(
          crop,
          minSize: _minCropSize,
          ratio: ratio,
        );
      } else if (ratio != null) {
        next = EditGeometry.fitAspect(EditGeometry.fullCrop, ratio);
      }
      return _withCrop(v, next);
    });
  }

  /// Locks the crop to [ratio] (width / height on screen) and fits the
  /// largest centered rect with that ratio inside the current crop, or
  /// unlocks it with `null`.
  void setCropAspectRatio(double? ratio) {
    if (ratio != null && !(ratio > 0 && ratio.isFinite)) return;
    _applyCropEdit(
      (ImageEditValue v) {
        if (ratio == null) return v;
        final normalized = EditGeometry.normalizedAspect(
          ratio,
          ImageGeometry.transformedSize(_geometrySize, v.quarterTurns),
        );
        final fitted = EditGeometry.constrainCrop(
          EditGeometry.fitAspect(v.crop ?? EditGeometry.fullCrop, normalized),
          minSize: _minCropSize,
          ratio: normalized,
        );
        return _withCrop(v, fitted);
      },
      aspectRatio: ratio,
      setsAspectRatio: true,
    );
  }

  /// Rotates a quarter turn counter-clockwise; the crop turns with it.
  void rotateLeft() {
    final lock = _cropAspectRatio;
    _applyCropEdit(
      (ImageEditValue v) {
        final crop = v.crop;
        return v.copyWith(
          quarterTurns: (v.quarterTurns + 3) % 4,
          crop: crop == null
              ? null
              : EditGeometry.rotateCropCounterClockwise(crop),
        );
      },
      aspectRatio: lock == null ? null : 1 / lock,
      setsAspectRatio: true,
    );
  }

  /// Rotates a quarter turn clockwise; the crop turns with it.
  void rotateRight() {
    final lock = _cropAspectRatio;
    _applyCropEdit(
      (ImageEditValue v) {
        final crop = v.crop;
        return v.copyWith(
          quarterTurns: (v.quarterTurns + 1) % 4,
          crop: crop == null ? null : EditGeometry.rotateCropClockwise(crop),
        );
      },
      aspectRatio: lock == null ? null : 1 / lock,
      setsAspectRatio: true,
    );
  }

  /// Mirrors what the user sees left-right; the crop mirrors with it.
  void flipHorizontal() {
    _applyCropEdit((ImageEditValue v) {
      // A screen mirror conjugated by an odd quarter turn is a mirror of
      // the other original axis.
      final odd = v.quarterTurns.isOdd;
      final crop = v.crop;
      return v.copyWith(
        flipX: odd ? v.flipX : !v.flipX,
        flipY: odd ? !v.flipY : v.flipY,
        crop: crop == null ? null : EditGeometry.mirrorCropHorizontally(crop),
      );
    });
  }

  /// Mirrors what the user sees top-bottom; the crop mirrors with it.
  void flipVertical() {
    _applyCropEdit((ImageEditValue v) {
      final odd = v.quarterTurns.isOdd;
      final crop = v.crop;
      return v.copyWith(
        flipX: odd ? !v.flipX : v.flipX,
        flipY: odd ? v.flipY : !v.flipY,
        crop: crop == null ? null : EditGeometry.mirrorCropVertically(crop),
      );
    });
  }

  /// Resets crop, rotation, flips and the aspect lock in the crop session.
  void resetCrop() {
    _applyCropEdit(
      (ImageEditValue v) => v.copyWith(
        clearCrop: true,
        quarterTurns: 0,
        flipX: false,
        flipY: false,
      ),
      aspectRatio: null,
      setsAspectRatio: true,
    );
  }

  /// Ends the crop session, keeping the changes as one history entry.
  void confirmCrop() {
    if (_cropSessionStart == null) return;
    _cropSessionStart = null;
    _cropAspectBeforeSession = null;
    _commit();
    if (_activeTool == EditorTool.crop) _activeTool = EditorTool.none;
    _notify();
  }

  /// Ends the crop session, restoring the state from before it started.
  void cancelCrop() {
    if (_cancelCropSession()) _notify();
  }

  // ───────────────────────── Compress ─────────────────────────

  /// Effective quality: the user's pick, or `ExportOptions.quality`.
  int get quality => _value.quality ?? _config.export.quality;

  /// Sets the quality live (for example while a slider moves) without
  /// recording history.
  void setQuality(int quality) {
    final clamped = quality.clamp(1, 100);
    if (_value.quality == clamped) return;
    _value = _value.copyWith(quality: clamped);
    _notify();
  }

  /// Records one history entry if the quality changed since the last
  /// entry. The compress sheet calls it, after [setQuality], when the user
  /// taps Apply. Closing the compress tool with [closeTool] also commits a
  /// pending quality change.
  ///
  /// Does nothing while a crop session is open: a quality set during the
  /// session is kept by [confirmCrop] or dropped by [cancelCrop] along with
  /// the rest of the session.
  void commitQuality() {
    if (_cropSessionStart != null) return;
    if (_commit()) _notify();
  }

  /// Size in bytes the current edits would export to at [quality], or
  /// `null` if it can't be computed. Results are cached per edit state and
  /// quality, so calling this on every slider tick is cheap after the
  /// first render. Estimates for different qualities encode one at a time,
  /// in the order they were requested.
  Future<int?> estimateSize(int quality) {
    final bytes = _sourceBytes;
    if (_disposed || bytes == null || _loadStatus != ImageLoadStatus.ready) {
      return Future<int?>.value();
    }
    final options = _config.export;
    final key = _EstimateKey(
      bytes: bytes,
      originalSize: _originalSize,
      value: _value.copyWith(clearQuality: true),
      options: options,
      textStyle: _textLayerStyle,
    );
    var cache = _estimates;
    if (cache == null || cache.key != key) {
      cache = _estimates = _EstimateCache(key);
    }
    // PNG ignores quality, so every quality shares one estimate.
    final q = options.format == ExportFormat.png ? 0 : quality.clamp(1, 100);
    final existing = cache.sizes[q];
    if (existing != null) return existing;
    final future = _runEstimate(cache, q);
    cache.sizes[q] = future;
    return future;
  }

  Future<int?> _runEstimate(_EstimateCache cache, int quality) async {
    final key = cache.key;
    final task = EditorTimeline.task()
      ?..start(
        EditorTimeline.estimateSize,
        arguments: <String, Object?>{
          'format': key.options.format.name,
          'quality': quality == 0 ? null : quality,
          'renderCached': cache.render != null,
        },
      );
    int? size;
    try {
      size = await _estimate(cache, quality);
      return size;
    } finally {
      task?.finish(arguments: <String, Object?>{'bytes': size});
    }
  }

  Future<int?> _estimate(_EstimateCache cache, int quality) async {
    final key = cache.key;
    try {
      final render = cache.render ??= ImageExporter.render(
        bytes: key.bytes,
        originalSize: key.originalSize,
        value: key.value,
        options: key.options,
        textStyle: key.textStyle,
      );
      final RgbaImage pixels;
      try {
        pixels = await render;
      } catch (_) {
        if (identical(cache.render, render)) cache.render = null;
        rethrow;
      }
      final encoder = key.options.encoder ?? const DartImageEncoder();
      final encoded = await _queueEstimateEncode(
        () => encoder.encode(
          pixels,
          format: key.options.format,
          quality: quality == 0 ? key.options.quality : quality,
        ),
      );
      if (encoded == null) {
        // Disposed before the encode started.
        unawaited(cache.sizes.remove(quality));
        return null;
      }
      return encoded.length;
    } catch (_) {
      // Forget the failure so a later call can retry.
      unawaited(cache.sizes.remove(quality));
      return null;
    }
  }

  /// Runs [encode] after every previously queued estimate encode has
  /// settled, so at most one runs at a time. Completes with `null`, without
  /// encoding, if the controller is disposed before its turn.
  Future<Uint8List?> _queueEstimateEncode(Future<Uint8List> Function() encode) {
    final result = _estimateQueue.then<Uint8List?>(
      (void _) => _disposed ? null : encode(),
    );
    _estimateQueue = result.then<void>(
      (Uint8List? _) {},
      onError: (Object _) {},
    );
    return result;
  }

  // ───────────────────────── Export ─────────────────────────

  /// Whether [export] is running.
  bool get isExporting => _isExporting;

  /// Renders the current edits from the source bytes at full resolution
  /// (capped by `ExportOptions.maxLongEdge`), encodes them per
  /// `config.export` and returns the result with [caption] trimmed.
  /// Returns `null` on failure or if an export is already running.
  Future<ChatImageEditorResult?> export({String caption = ''}) async {
    final bytes = _sourceBytes;
    if (_disposed ||
        _isExporting ||
        bytes == null ||
        _loadStatus != ImageLoadStatus.ready) {
      return null;
    }
    _isExporting = true;
    _notify();
    try {
      return await ImageExporter.export(
        bytes: bytes,
        originalSize: _originalSize,
        value: _value,
        options: _config.export,
        textStyle: _textLayerStyle,
        quality: quality,
        caption: caption,
      );
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'chat_image_editor',
          context: ErrorDescription('while exporting the edited image'),
        ),
      );
      return null;
    } finally {
      _isExporting = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _image?.dispose();
    _image = null;
    _estimates = null;
    super.dispose();
  }

  // ───────────────────────── Internals ─────────────────────────

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Notifies now, or after the current frame when called while widgets
  /// build (for example from `didChangeDependencies`), so listeners are
  /// never marked dirty mid-build.
  void _notifyOutsideBuild() {
    if (_disposed) return;
    SchedulerBinding? binding;
    try {
      binding = SchedulerBinding.instance;
    } catch (_) {
      binding = null;
    }
    if (binding != null &&
        binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((Duration _) => _notify());
      return;
    }
    notifyListeners();
  }

  /// Records [_value] as a history entry if it differs from the current
  /// one.
  bool _commit() => _history.push(_value);

  Size get _geometrySize =>
      _originalSize.isEmpty ? const Size(1, 1) : _originalSize;

  Offset _toOriginal(Offset viewPoint) {
    return ImageGeometry.viewToOriginal(viewPoint, _originalSize, _value);
  }

  /// Distance between two normalized original points, as a fraction of the
  /// image's shortest side.
  double _relativeDistance(Offset a, Offset b) {
    final size = _geometrySize;
    final delta = Offset(
      (a.dx - b.dx) * size.width,
      (a.dy - b.dy) * size.height,
    );
    return delta.distance / size.shortestSide;
  }

  String _newId(String prefix) {
    String id;
    do {
      _idCounter++;
      id = '$prefix-$_idCounter';
    } while (_idInUse(id));
    return id;
  }

  bool _idInUse(String id) {
    bool inValue(ImageEditValue v) =>
        v.strokes.any((Stroke s) => s.id == id) ||
        v.texts.any((TextLayer t) => t.id == id);
    return inValue(_value) || inValue(_baseValue);
  }

  List<TextLayer> _textsWithout(String id) {
    return List<TextLayer>.unmodifiable(<TextLayer>[
      for (final t in _value.texts)
        if (t.id != id) t,
    ]);
  }

  void _replaceLayer(TextLayer layer) {
    _value = _value.copyWith(
      texts: List<TextLayer>.unmodifiable(<TextLayer>[
        for (final t in _value.texts) t.id == layer.id ? layer : t,
      ]),
    );
  }

  /// Adds the empty, upright layer for a new text entry. No notification.
  String _addTextLayer(Offset? viewPosition) {
    final upright = EditGeometry.uprightText(_value);
    final layer = TextLayer(
      id: _newId('text'),
      text: '',
      position: _toOriginal(viewPosition ?? const Offset(0.5, 0.5)),
      fontSize: _clampDouble(
        _config.defaultFontSize,
        _config.minFontSize,
        _config.maxFontSize,
      ),
      color: _textColor,
      rotation: upright.rotation,
      mirrored: upright.mirrored,
      background: _textBackground,
    );
    _value = _value.copyWith(
      texts: List<TextLayer>.unmodifiable(<TextLayer>[..._value.texts, layer]),
    );
    _editingTextId = layer.id;
    _activeTool = EditorTool.text;
    return layer.id;
  }

  /// Closes text entry: drops an empty layer and records the session.
  /// No notification.
  bool _finishTextEntry() {
    final id = _editingTextId;
    if (id == null) return false;
    _editingTextId = null;
    final layer = textById(id);
    if (layer != null && layer.text.trim().isEmpty) {
      _value = _value.copyWith(texts: _textsWithout(id));
    }
    if (_activeTool == EditorTool.text) _activeTool = EditorTool.none;
    _commit();
    return true;
  }

  /// Ends the active text gesture. No notification.
  bool _endTextGesture() {
    final id = _activeTextId;
    final start = _gestureStart;
    if (id == null || start == null) return false;
    final over = _overDeleteTarget;
    _activeTextId = null;
    _gestureStart = null;
    _overDeleteTarget = false;

    final layer = textById(id);
    if (layer == null) return true;
    if (over) {
      if (_editingTextId == id) _editingTextId = null;
      _value = _value.copyWith(texts: _textsWithout(id));
      _commit();
      return true;
    }

    // Keep the layer's center on the visible image so it can't get lost.
    final view = ImageGeometry.originalToView(
      layer.position,
      _originalSize,
      _value,
    );
    final clamped = Offset(
      _clampDouble(view.dx, 0, 1),
      _clampDouble(view.dy, 0, 1),
    );
    var settled = layer;
    if (clamped != view) {
      settled = layer.copyWith(
        position: ImageGeometry.viewToOriginal(clamped, _originalSize, _value),
      );
      _replaceLayer(settled);
    }

    final changed =
        settled.position != start.position ||
        settled.fontSize != start.fontSize ||
        settled.rotation != start.rotation;
    if (changed) {
      _commit();
    } else {
      // Only the paint order changed (the layer came to the top). Apply
      // just that to the recorded entry: no undo step for a tap, and no
      // other uncommitted state (a live quality, say) baked into history.
      final recorded = _history.current;
      final reordered = _withLayerOnTop(recorded, id);
      if (!identical(reordered, recorded)) _history.replaceCurrent(reordered);
    }
    return true;
  }

  /// [value] with layer [id] moved to the top of the paint order, or
  /// [value] itself if the layer is missing or already on top.
  static ImageEditValue _withLayerOnTop(ImageEditValue value, String id) {
    final texts = value.texts;
    final index = texts.indexWhere((TextLayer t) => t.id == id);
    if (index < 0 || index == texts.length - 1) return value;
    final layer = texts[index];
    return value.copyWith(
      texts: List<TextLayer>.unmodifiable(<TextLayer>[
        for (final t in texts)
          if (t.id != id) t,
        layer,
      ]),
    );
  }

  bool _cancelDraft() {
    if (_draftStroke == null) return false;
    _draftStroke = null;
    return true;
  }

  void _startCropSession() {
    final lock = _cropAspectRatio;
    if (lock != null) {
      final transformed = ImageGeometry.transformedSize(
        _geometrySize,
        _value.quarterTurns,
      );
      final current = EditGeometry.screenAspect(
        _value.crop ?? EditGeometry.fullCrop,
        transformed,
      );
      // A lock that no longer matches the crop (after undo, say) is stale.
      if ((current - lock).abs() > lock * 0.01) _cropAspectRatio = null;
    }
    _cropSessionStart = _value;
    _cropAspectBeforeSession = _cropAspectRatio;
  }

  /// Restores the state from before the crop session. No notification.
  bool _cancelCropSession() {
    final start = _cropSessionStart;
    if (start == null) return false;
    _value = start;
    _cropAspectRatio = _cropAspectBeforeSession;
    _cropSessionStart = null;
    _cropAspectBeforeSession = null;
    if (_activeTool == EditorTool.crop) _activeTool = EditorTool.none;
    return true;
  }

  /// Leaves the open tool the way [closeTool] documents. No notification.
  bool _leaveActiveTool() {
    var changed = false;
    switch (_activeTool) {
      case EditorTool.crop:
        changed = _cancelCropSession();
      case EditorTool.text:
        changed = _finishTextEntry();
      case EditorTool.compress:
        _commit();
        // The rendered pixels behind the size estimates can be large.
        _estimates?.render = null;
      case EditorTool.draw:
        changed = _cancelDraft();
      case EditorTool.none:
        break;
    }
    // Text entry can't outlive its tool.
    if (_editingTextId != null) changed = _finishTextEntry() || changed;
    if (_activeTool != EditorTool.none) {
      _activeTool = EditorTool.none;
      changed = true;
    }
    return changed;
  }

  /// Closes what undo, redo and clear must not interleave with: the draft
  /// stroke and text gesture, the crop session (cancelled), text entry
  /// (finished) and a pending quality change (committed). No notification.
  bool _closeSessionsForHistory() {
    var changed = _cancelDraft();
    changed = _endTextGesture() || changed;
    changed = _cancelCropSession() || changed;
    changed = _finishTextEntry() || changed;
    _commit();
    return changed;
  }

  /// What [_value] becomes once open sessions close, without closing them.
  ImageEditValue _valueAfterClosingSessions() {
    final cropStart = _cropSessionStart;
    if (cropStart != null) return cropStart;
    return _withoutEmptyEditingLayer(_value);
  }

  ImageEditValue _withoutEmptyEditingLayer(ImageEditValue value) {
    final id = _editingTextId;
    if (id == null) return value;
    final layer = textById(id);
    if (layer == null || layer.text.trim().isNotEmpty) return value;
    return value.copyWith(texts: _textsWithout(id));
  }

  /// Applies a crop, rotation or flip change. Inside a crop session it's
  /// live; otherwise any open session closes first and the change is
  /// recorded as its own history entry.
  void _applyCropEdit(
    ImageEditValue Function(ImageEditValue value) change, {
    double? aspectRatio,
    bool setsAspectRatio = false,
  }) {
    final inSession = _cropSessionStart != null;
    var changed = false;
    if (!inSession) {
      changed = _cancelDraft();
      changed = _endTextGesture() || changed;
      changed = _finishTextEntry() || changed;
    }
    if (setsAspectRatio && aspectRatio != _cropAspectRatio) {
      _cropAspectRatio = aspectRatio;
      changed = true;
    }
    final next = change(_value);
    if (next != _value) {
      _value = next;
      if (!inSession) _commit();
      changed = true;
    }
    if (changed) _notify();
  }

  /// The aspect lock as a normalized width / height ratio for [value].
  double? _normalizedLock(ImageEditValue value) {
    final lock = _cropAspectRatio;
    if (lock == null) return null;
    return EditGeometry.normalizedAspect(
      lock,
      ImageGeometry.transformedSize(_geometrySize, value.quarterTurns),
    );
  }

  static ImageEditValue _withCrop(ImageEditValue value, Rect? crop) {
    if (crop == null || EditGeometry.isFullCrop(crop)) {
      return value.copyWith(clearCrop: true);
    }
    return value.copyWith(crop: crop);
  }

  void _resetEditingState() {
    _draftStroke = null;
    _editingTextId = null;
    _activeTextId = null;
    _gestureStart = null;
    _overDeleteTarget = false;
    _cropSessionStart = null;
    _cropAspectBeforeSession = null;
    _cropAspectRatio = null;
    _activeTool = EditorTool.none;
  }

  /// [preferred] if [shapes] offers it (or offers nothing), otherwise the
  /// first offered shape.
  static ShapeType _offeredShape(List<ShapeType> shapes, ShapeType preferred) {
    if (shapes.isEmpty || shapes.contains(preferred)) return preferred;
    return shapes.first;
  }

  static bool _isFiniteRect(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;

  static double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}

/// Everything an export size estimate depends on except quality.
@immutable
class _EstimateKey {
  const _EstimateKey({
    required this.bytes,
    required this.originalSize,
    required this.value,
    required this.options,
    required this.textStyle,
  });

  final Uint8List bytes;
  final Size originalSize;
  final ImageEditValue value;
  final ExportOptions options;
  final TextStyle textStyle;

  @override
  bool operator ==(Object other) {
    return other is _EstimateKey &&
        identical(other.bytes, bytes) &&
        other.originalSize == originalSize &&
        other.value == value &&
        other.options.format == options.format &&
        other.options.maxLongEdge == options.maxLongEdge &&
        other.options.backgroundColor == options.backgroundColor &&
        other.options.quality == options.quality &&
        identical(other.options.encoder, options.encoder) &&
        other.textStyle == textStyle;
  }

  @override
  int get hashCode => Object.hash(
    identityHashCode(bytes),
    originalSize,
    value,
    options.format,
    options.maxLongEdge,
    options.backgroundColor,
    options.quality,
    identityHashCode(options.encoder),
    textStyle,
  );
}

/// Cached render and per-quality sizes for one [_EstimateKey].
class _EstimateCache {
  _EstimateCache(this.key);

  final _EstimateKey key;
  Future<RgbaImage>? render;
  final Map<int, Future<int?>> sizes = <int, Future<int?>>{};
}
