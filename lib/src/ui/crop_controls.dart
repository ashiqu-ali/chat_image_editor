import 'package:flutter/material.dart';

import '../controller/chat_image_editor_controller.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import 'controller_selector.dart';
import 'editor_icon_button.dart';

/// Crop tool chrome along the bottom: aspect-ratio chips, then one row with
/// cancel, rotate, flip, reset and confirm.
///
/// Fills the editor; empty areas let touches through to the crop frame.
/// The controls are at most [height] tall above the safe area, which
/// `EditorLayout.cropBottomInset` keeps clear of the frame's handles.
class CropControls extends StatelessWidget {
  /// Creates the crop controls.
  const CropControls({super.key});

  /// Height of the controls above the safe area: the chips row, the button
  /// row and the bottom margin.
  static const double height = 2 * EditorIconButton.hitSize + _bottomMargin;

  static const double _bottomMargin = 8;

  /// A compact `w:h` label for [ratio], such as `16:9`.
  static String ratioLabel(double ratio) {
    for (var denominator = 1; denominator <= 32; denominator++) {
      final numerator = (ratio * denominator).round();
      if (numerator > 0 && (numerator / denominator - ratio).abs() < 0.001) {
        return '$numerator:$denominator';
      }
    }
    return ratio.toStringAsFixed(2);
  }

  static void _cancel(ChatImageEditorController controller) {
    controller.cancelCrop();
    if (controller.activeTool == EditorTool.crop) controller.closeTool();
  }

  static void _confirm(ChatImageEditorController controller) {
    controller.confirmCrop();
    if (controller.activeTool == EditorTool.crop) controller.closeTool();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final controller = scope.controller;
    final icons = scope.icons;
    final strings = scope.strings;
    final ratios = scope.config.cropAspectRatios;
    // The view padding, like `EditorLayout.canvasPadding`, so the controls
    // keep their distance from the frame while the keyboard hides.
    final safe = MediaQuery.viewPaddingOf(context);

    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              safe.left + 4,
              0,
              safe.right + 4,
              safe.bottom + _bottomMargin,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (ratios.isNotEmpty) const _AspectRatioChips(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      EditorIconButton(
                        icon: icons.cancelIcon,
                        tooltip: strings.cancel,
                        onPressed: () => _cancel(controller),
                      ),
                      const SizedBox(width: 4),
                      EditorIconButton(
                        icon: icons.rotateLeftIcon,
                        tooltip: strings.rotateLeft,
                        onPressed: controller.rotateLeft,
                      ),
                      EditorIconButton(
                        icon: icons.rotateRightIcon,
                        tooltip: strings.rotateRight,
                        onPressed: controller.rotateRight,
                      ),
                      EditorIconButton(
                        icon: icons.flipHorizontalIcon,
                        tooltip: strings.flipHorizontal,
                        onPressed: controller.flipHorizontal,
                      ),
                      EditorIconButton(
                        icon: icons.flipVerticalIcon,
                        tooltip: strings.flipVertical,
                        onPressed: controller.flipVertical,
                      ),
                      EditorIconButton(
                        icon: icons.resetCropIcon,
                        tooltip: strings.resetCrop,
                        onPressed: controller.resetCrop,
                      ),
                      const SizedBox(width: 4),
                      EditorIconButton(
                        icon: icons.confirmIcon,
                        tooltip: strings.confirm,
                        active: true,
                        onPressed: () => _confirm(controller),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AspectRatioChips extends StatelessWidget {
  const _AspectRatioChips();

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final controller = scope.controller;
    final ratios = scope.config.cropAspectRatios;

    return ControllerSelector<double?>(
      selector: (c) => c.cropAspectRatio,
      builder: (context, current, _) {
        bool matches(double? ratio) {
          if (ratio == null || current == null) return ratio == current;
          return (ratio - current).abs() < 0.0001;
        }

        return SizedBox(
          height: EditorIconButton.hitSize,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Chip(
                    label: scope.strings.freeAspectRatio,
                    selected: matches(null),
                    onTap: () => controller.setCropAspectRatio(null),
                  ),
                  for (final ratio in ratios)
                    _Chip(
                      label: CropControls.ratioLabel(ratio),
                      selected: matches(ratio),
                      onTap: () => controller.setCropAspectRatio(ratio),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    final background = selected
        ? theme.activeToolColor
        : theme.toolbarBackgroundColor;
    final foreground = selected ? theme.onPrimaryColor : theme.foregroundColor;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: SizedBox(
          height: EditorIconButton.hitSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: background,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: Text(
                label,
                style: theme.labelStyle.copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
