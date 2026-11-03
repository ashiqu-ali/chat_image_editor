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

/// Draw tool chrome: the color strip on the right, and the shape picker and
/// brush size slider at the bottom.
///
/// Fills the editor; empty areas let touches through to the canvas.
class DrawControls extends StatelessWidget {
  /// Creates the draw controls.
  const DrawControls({super.key});

  /// Space kept for the bottom controls when sizing the color strip.
  static const double bottomControlsHeight = 128;

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

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final controller = scope.controller;
    final config = scope.config;
    final safe = MediaQuery.viewPaddingOf(context);
    final showSlider = config.minStrokeWidth < config.maxStrokeWidth;

    return ControllerSelector<({ShapeType shape, Color color, double width})>(
      selector: (c) =>
          (shape: c.shapeType, color: c.drawColor, width: c.strokeWidth),
      builder: (context, state, _) {
        return Stack(
          children: <Widget>[
            Positioned(
              top: safe.top + EditorLayout.topBarHeight + 8,
              right: safe.right + 4,
              bottom: safe.bottom + bottomControlsHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: ColorStrip(
                  selected: state.color,
                  onSelected: controller.setDrawColor,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (config.shapes.length > 1)
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: <Widget>[
                            for (final shape in config.shapes)
                              EditorIconButton(
                                icon: iconFor(shape, scope.icons),
                                tooltip: labelFor(shape, scope.strings),
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
