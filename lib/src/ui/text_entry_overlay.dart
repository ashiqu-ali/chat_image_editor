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
/// Shows the text centered in its live style (color, background box, size
/// as it will appear on the image), a "Done" pill at the top left, the
/// background toggle at the top right and the color slider on the right.
/// Tapping the dimmed area or "Done" finishes editing; finishing with no
/// text drops the layer.
class TextEntryOverlay extends StatefulWidget {
  /// Creates the overlay. Key it by the edited layer's id.
  const TextEntryOverlay({super.key});

  /// Smallest on-screen font size while typing.
  static const double minFontSize = 18;

  /// Largest on-screen font size while typing.
  static const double maxFontSize = 64;

  // Box padding and corner radius as fractions of the font size; the same
  // as `TextRenderer` uses, so the box looks like the result.
  static const double _boxHorizontalPadding = 0.4;
  static const double _boxVerticalPadding = 0.2;
  static const double _boxCornerRadius = 0.3;

  /// The style used to preview [layer] while typing, at [fontSize] logical
  /// pixels. Built from the same base style and color rule as the renderer,
  /// and it doesn't inherit the surrounding text style, so the glyphs match
  /// the result.
  static TextStyle previewStyle(
    TextLayer layer,
    ChatImageEditorResolvedTheme theme,
    double fontSize,
  ) {
    final base = theme.textLayerStyle;
    // A base style with a foreground paint keeps it; copyWith then drops
    // the color, as the renderer does.
    return base.copyWith(
      inherit: false,
      fontSize: fontSize,
      textBaseline: base.textBaseline ?? TextBaseline.alphabetic,
      color: TextLayerColors.textColor(layer),
    );
  }

  /// The rounded box behind [layer]'s text while typing, at [fontSize]
  /// logical pixels. It has no color when the layer has no background.
  static BoxDecoration previewBox(TextLayer layer, double fontSize) {
    return BoxDecoration(
      color: TextLayerColors.boxColor(layer),
      borderRadius: BorderRadius.all(
        Radius.circular(fontSize * _boxCornerRadius),
      ),
    );
  }

  /// The padding between the box and the text at [fontSize] logical pixels.
  /// It's kept for every background style, so cycling the background
  /// never moves the text.
  static EdgeInsets previewPadding(double fontSize) {
    return EdgeInsets.symmetric(
      horizontal: fontSize * _boxHorizontalPadding,
      vertical: fontSize * _boxVerticalPadding,
    );
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

  /// The text field in [layer]'s style, inside its background box. The box
  /// hugs the text, and tapping it (padding included) focuses the field
  /// rather than finishing.
  Widget _field(
    ChatImageEditorController controller,
    ChatImageEditorResolvedTheme theme,
    TextLayer? layer,
    Size layerSize,
  ) {
    final fontSize = layer == null
        ? TextEntryOverlay.minFontSize
        : _fontSize(controller, layer, layerSize);
    final field = TextField(
      controller: _text,
      focusNode: _focus,
      autofocus: true,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      textAlign: TextAlign.center,
      cursorColor: theme.primaryColor,
      decoration: const InputDecoration.collapsed(hintText: null),
      style: layer == null
          ? theme.textLayerStyle.copyWith(fontSize: fontSize)
          : TextEntryOverlay.previewStyle(layer, theme, fontSize),
      onChanged: controller.updateEditingText,
    );
    // The image's text doesn't follow the system text size, so neither
    // does the preview.
    return MediaQuery.withNoTextScaling(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _focus.requestFocus,
        child: DecoratedBox(
          decoration: layer == null
              ? const BoxDecoration()
              : TextEntryOverlay.previewBox(layer, fontSize),
          child: Padding(
            padding: TextEntryOverlay.previewPadding(fontSize),
            child: IntrinsicWidth(child: field),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final theme = scope.theme;
    final controller = scope.controller;
    final safe = MediaQuery.viewPaddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = math.max(keyboard, safe.bottom);
    // Equal side margins, clear of the color slider, keep the text
    // centered on screen.
    final side = ColorStrip.width + 8 + math.max(safe.left, safe.right);

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
                // The chrome shares the field's tap region, so using it
                // keeps the field focused (and the keyboard up) on every
                // platform. Only the dimmed area counts as outside.
                return TextFieldTapRegion(
                  child: Stack(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
                        left: side,
                        right: side,
                        top: safe.top + EditorLayout.topBarHeight,
                        bottom: bottom,
                        child: Center(
                          child: SingleChildScrollView(
                            child: _field(controller, theme, layer, layerSize),
                          ),
                        ),
                      ),
                      Positioned(
                        top: safe.top + EditorLayout.topBarHeight + 8,
                        right: safe.right + 4,
                        bottom: bottom + 16,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: ColorStrip(
                            selected: color,
                            onSelected: controller.setTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
