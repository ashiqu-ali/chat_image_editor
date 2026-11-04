import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/chat_image_editor_controller.dart';
import '../core/render/text_layer_colors.dart';
import '../models/editor_enums.dart';
import '../models/text_layer.dart';
import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_theme.dart';
import 'color_strip.dart';
import 'controller_selector.dart';
import 'editor_icon_button.dart';
import 'editor_layout.dart';
import 'editor_pill_button.dart';

/// Full-screen, dimmed text entry for the layer in
/// `ChatImageEditorController.editingText`.
///
/// Shows the text in its live style (color, background, size as it will
/// appear on the image), a "Done" pill, a background toggle and the color
/// slider. Tapping the dimmed area or "Done" finishes editing.
class TextEntryOverlay extends StatefulWidget {
  /// Creates the overlay. Key it by the edited layer's id.
  const TextEntryOverlay({super.key});

  /// Smallest on-screen font size while typing.
  static const double minFontSize = 18;

  /// Largest on-screen font size while typing.
  static const double maxFontSize = 64;

  /// The style used to preview [layer] while typing, at [fontSize] logical
  /// pixels. Text and box colors follow the same rule as the renderer.
  static TextStyle previewStyle(
    TextLayer layer,
    ChatImageEditorResolvedTheme theme,
    double fontSize,
  ) {
    final style = theme.textLayerStyle.copyWith(
      fontSize: fontSize,
      color: TextLayerColors.textColor(layer),
    );
    final box = TextLayerColors.boxColor(layer);
    return box == null ? style : style.copyWith(backgroundColor: box);
  }

  @override
  State<TextEntryOverlay> createState() => _TextEntryOverlayState();
}

class _TextEntryOverlayState extends State<TextEntryOverlay> {
  late final TextEditingController _text;
  final FocusNode _focus = FocusNode();
  ChatImageEditorController? _controller;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ChatImageEditorScope.of(context).controller;
    if (!identical(controller, _controller)) {
      _controller = controller;
      _text.text = controller.editingText?.text ?? '';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _done() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.editingTextId != null) controller.finishTextEditing();
    if (controller.activeTool == EditorTool.text) controller.closeTool();
  }

  double _fontSize(
    ChatImageEditorController controller,
    TextLayer layer,
    Size layerSize,
  ) {
    final output = EditorLayout.paintedOutputSize(controller);
    final padding = EditorLayout.canvasPadding(context, EditorTool.text);
    final rect = EditorLayout.imageRect(layerSize, padding, output);
    final original = controller.originalSize;
    if (rect.isEmpty || output.width <= 0) {
      return TextEntryOverlay.minFontSize;
    }
    final displayScale = rect.width / output.width;
    final pixels = layer.fontSize * original.shortestSide * displayScale;
    return pixels
        .clamp(TextEntryOverlay.minFontSize, TextEntryOverlay.maxFontSize)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final controller = scope.controller;
    final safe = MediaQuery.viewPaddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layerSize = constraints.biggest;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _done,
                child: ColoredBox(color: theme.scrimColor),
              ),
            ),
            ControllerSelector<
              ({TextLayer? layer, Color color, TextBackgroundStyle background})
            >(
              selector: (c) => (
                layer: c.editingText,
                color: c.textColor,
                background: c.textBackground,
              ),
              builder: (context, state, _) {
                final layer = state.layer;
                final color = layer?.color ?? state.color;
                final background = layer?.background ?? state.background;
                return Stack(
                  children: <Widget>[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        bottom: false,
                        child: SizedBox(
                          height: EditorLayout.topBarHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: <Widget>[
                                EditorPillButton(
                                  label: scope.strings.done,
                                  onPressed: _done,
                                ),
                                const Spacer(),
                                EditorIconButton(
                                  icon: scope.icons.textBackgroundIcon,
                                  tooltip: scope.strings.textBackground,
                                  active:
                                      background != TextBackgroundStyle.none,
                                  onPressed: controller.cycleTextBackground,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16 + safe.left,
                      right: ColorStrip.width + 8 + safe.right,
                      top: safe.top + EditorLayout.topBarHeight,
                      bottom: math.max(keyboard, safe.bottom),
                      child: Center(
                        child: SingleChildScrollView(
                          child: TextField(
                            controller: _text,
                            focusNode: _focus,
                            autofocus: true,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            textAlign: TextAlign.center,
                            cursorColor: theme.primaryColor,
                            decoration: const InputDecoration.collapsed(
                              hintText: null,
                            ),
                            style: layer == null
                                ? theme.textLayerStyle
                                : TextEntryOverlay.previewStyle(
                                    layer,
                                    theme,
                                    _fontSize(controller, layer, layerSize),
                                  ),
                            onChanged: controller.updateEditingText,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: safe.top + EditorLayout.topBarHeight + 8,
                      right: safe.right + 4,
                      bottom: math.max(keyboard, safe.bottom) + 16,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: ColorStrip(
                          selected: color,
                          onSelected: controller.setTextColor,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
