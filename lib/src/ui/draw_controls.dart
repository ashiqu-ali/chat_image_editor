import 'package:flutter/widgets.dart';

import '../models/editor_enums.dart';
import '../theme/chat_image_editor_icons.dart';
import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import 'color_strip.dart';
import 'controller_selector.dart';
import 'editor_icon_button.dart';
import 'editor_layout.dart';
import 'editor_slider.dart';

/// Icons and labels of the draw tool's shapes.
abstract final class DrawControls {
  /// The icon for [shape].
  static Widget iconFor(ShapeType shape, ChatImageEditorIcons icons) {
    switch (shape) {
      case ShapeType.freehand:
        return icons.freehandIcon;
      case ShapeType.line:
        return icons.lineIcon;
      case ShapeType.rectangle:
        return icons.rectangleIcon;
      case ShapeType.circle:
        return icons.circleIcon;
      case ShapeType.arrow:
        return icons.arrowIcon;
    }
  }

  /// The tooltip for [shape].
  static String labelFor(ShapeType shape, ChatImageEditorStrings strings) {
    switch (shape) {
      case ShapeType.freehand:
        return strings.freehand;
      case ShapeType.line:
        return strings.line;
      case ShapeType.rectangle:
        return strings.rectangle;
      case ShapeType.circle:
        return strings.circle;
      case ShapeType.arrow:
        return strings.arrow;
    }
  }
}

/// The draw tool's color slider, on the right below the top bar.
///
/// Fills the editor; everywhere else lets touches through to the canvas.
class DrawColorPicker extends StatelessWidget {
  /// Creates the color picker.
  const DrawColorPicker({super.key});

  /// Space kept for the draw toolbar when sizing the slider.
  static const double toolbarAllowance = 140;

  @override
  Widget build(BuildContext context) {
    final controller = ChatImageEditorScope.of(context).controller;
    final safe = MediaQuery.viewPaddingOf(context);
    return Stack(
      children: <Widget>[
        Positioned(
          top: safe.top + EditorLayout.topBarHeight + 8,
          right: safe.right + 4,
          bottom: safe.bottom + toolbarAllowance,
          child: Align(
            alignment: Alignment.topRight,
            child: ControllerSelector<Color>(
              selector: (c) => c.drawColor,
              builder: (context, color, _) => ColorStrip(
                selected: color,
                onSelected: controller.setDrawColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The draw tool's bottom controls: the shape picker and the brush size.
class DrawToolbar extends StatelessWidget {
  /// Creates the toolbar.
  const DrawToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final controller = scope.controller;
    final config = scope.config;
    final safe = MediaQuery.viewPaddingOf(context);
    final showSlider = config.minStrokeWidth < config.maxStrokeWidth;

    return ControllerSelector<({ShapeType shape, double width})>(
      selector: (c) => (shape: c.shapeType, width: c.strokeWidth),
      builder: (context, state, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            safe.left + 12,
            8,
            safe.right + 12,
            safe.bottom + 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (config.shapes.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (final shape in config.shapes)
                      EditorIconButton(
                        icon: DrawControls.iconFor(shape, scope.icons),
                        tooltip: DrawControls.labelFor(shape, scope.strings),
                        active: state.shape == shape,
                        onPressed: () => controller.setShapeType(shape),
                      ),
                  ],
                ),
              if (showSlider)
                EditorSlider(
                  value: state.width,
                  min: config.minStrokeWidth,
                  max: config.maxStrokeWidth,
                  semanticsLabel: scope.strings.strokeWidth,
                  onChanged: controller.setStrokeWidth,
                ),
            ],
          ),
        );
      },
    );
  }
}
