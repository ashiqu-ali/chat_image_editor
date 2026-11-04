import 'package:flutter/foundation.dart';

import '../models/editor_enums.dart';
import 'export_options.dart';

/// Behaviour switches for the editor. Colors, icons and text live in
/// `ChatImageEditorThemeData`, `ChatImageEditorIcons` and
/// `ChatImageEditorStrings`.
@immutable
class ChatImageEditorConfig {
  /// Creates a configuration. Every argument has a sensible default.
  const ChatImageEditorConfig({
    this.mode = ChatImageEditorMode.send,
    this.tools = const <EditorTool>[
      EditorTool.crop,
      EditorTool.compress,
      EditorTool.text,
      EditorTool.draw,
    ],
    this.shapes = ShapeType.values,
    this.cropAspectRatios = const <double>[1, 4 / 3, 3 / 4, 16 / 9, 9 / 16],
    this.export = const ExportOptions(),
    this.previewMaxLongEdge = 2048,
    this.defaultStrokeWidth = 0.008,
    this.minStrokeWidth = 0.002,
    this.maxStrokeWidth = 0.03,
    this.defaultFontSize = 0.06,
    this.minFontSize = 0.02,
    this.maxFontSize = 0.25,
    this.confirmDiscard = true,
    this.enableZoom = true,
    this.enableHaptics = true,
    this.showUndoRedo = true,
    this.hideSystemBarsWhileDrawing = false,
  }) : assert(previewMaxLongEdge > 0),
       assert(minStrokeWidth > 0 && minStrokeWidth <= maxStrokeWidth),
       assert(minFontSize > 0 && minFontSize <= maxFontSize);

  /// Caption plus send button, or a plain done button.
  final ChatImageEditorMode mode;

  /// Tools shown in the top bar, in this order. Tools left out are hidden.
  final List<EditorTool> tools;

  /// Shapes offered by the draw tool, in this order.
  final List<ShapeType> shapes;

  /// Aspect ratios (width / height) offered as crop presets, in addition to
  /// free cropping. Empty hides the presets.
  final List<double> cropAspectRatios;

  /// How the result is encoded.
  final ExportOptions export;

  /// Longest side, in pixels, of the image decoded for on-screen editing.
  /// Export always re-renders from the source bytes, so this only affects
  /// preview sharpness and memory.
  final int previewMaxLongEdge;

  /// Initial stroke width, as a fraction of the image's shortest side.
  final double defaultStrokeWidth;

  /// Smallest stroke width the slider allows.
  final double minStrokeWidth;

  /// Largest stroke width the slider allows.
  final double maxStrokeWidth;

  /// Initial text size, as a fraction of the image's shortest side.
  final double defaultFontSize;

  /// Smallest text size pinching allows.
  final double minFontSize;

  /// Largest text size pinching allows.
  final double maxFontSize;

  /// Ask before discarding unsaved edits when the user closes the editor.
  final bool confirmDiscard;

  /// Allow pinch-to-zoom while no tool is open.
  final bool enableZoom;

  /// Play light haptic feedback when an alignment guide appears, a color is
  /// picked and a layer is over the delete target.
  final bool enableHaptics;

  /// Show undo and redo buttons in the top bar.
  final bool showUndoRedo;

  /// Hide the status and navigation bars while the draw tool is open, so
  /// the photo gets the whole screen.
  ///
  /// Both bars come back when drawing ends or the editor closes. Off by
  /// default, because system UI is app-wide state. Uses
  /// `SystemUiMode.manual`, which Android ignores for apps that target API 36
  /// or later.
  final bool hideSystemBarsWhileDrawing;

  /// Returns a copy with the given fields replaced.
  ChatImageEditorConfig copyWith({
    ChatImageEditorMode? mode,
    List<EditorTool>? tools,
    List<ShapeType>? shapes,
    List<double>? cropAspectRatios,
    ExportOptions? export,
    int? previewMaxLongEdge,
    double? defaultStrokeWidth,
    double? minStrokeWidth,
    double? maxStrokeWidth,
    double? defaultFontSize,
    double? minFontSize,
    double? maxFontSize,
    bool? confirmDiscard,
    bool? enableZoom,
    bool? enableHaptics,
    bool? showUndoRedo,
    bool? hideSystemBarsWhileDrawing,
  }) {
    return ChatImageEditorConfig(
      mode: mode ?? this.mode,
      tools: tools ?? this.tools,
      shapes: shapes ?? this.shapes,
      cropAspectRatios: cropAspectRatios ?? this.cropAspectRatios,
      export: export ?? this.export,
      previewMaxLongEdge: previewMaxLongEdge ?? this.previewMaxLongEdge,
      defaultStrokeWidth: defaultStrokeWidth ?? this.defaultStrokeWidth,
      minStrokeWidth: minStrokeWidth ?? this.minStrokeWidth,
      maxStrokeWidth: maxStrokeWidth ?? this.maxStrokeWidth,
      defaultFontSize: defaultFontSize ?? this.defaultFontSize,
      minFontSize: minFontSize ?? this.minFontSize,
      maxFontSize: maxFontSize ?? this.maxFontSize,
      confirmDiscard: confirmDiscard ?? this.confirmDiscard,
      enableZoom: enableZoom ?? this.enableZoom,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      showUndoRedo: showUndoRedo ?? this.showUndoRedo,
      hideSystemBarsWhileDrawing:
          hideSystemBarsWhileDrawing ?? this.hideSystemBarsWhileDrawing,
    );
  }
}
