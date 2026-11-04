import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/caption_field_config.dart';
import '../controller/chat_image_editor_controller.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import '../theme/chat_image_editor_theme.dart';
import 'editor_host.dart';
import 'send_button.dart';

/// Space around the default bottom bar's content.
const EdgeInsets _barPadding = EdgeInsets.fromLTRB(12, 8, 12, 8);

/// The bottom area of the editor.
///
/// Uses `ChatImageEditorBuilders.bottomBar` when set. Otherwise, in send
/// mode, the caption field spans the full width with one row below it: the
/// `CaptionFieldConfig.header` chip at the start and the send button at the
/// end. In done mode only the done button shows, at the end. Rides above the
/// keyboard without resizing the image.
class EditorBottomBar extends StatelessWidget {
  /// Creates the bottom bar.
  const EditorBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.viewPaddingOf(context);
    final custom = scope.builders.bottomBar;

    final Widget content;
    if (custom != null) {
      content = custom(context, scope.controller);
    } else if (scope.config.mode == ChatImageEditorMode.done) {
      content = const Padding(
        padding: _barPadding,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SendButtonSlot(),
        ),
      );
    } else {
      content = const _CaptionBar();
    }

    return Padding(
      padding: EdgeInsets.only(
        left: safe.left,
        right: safe.right,
        bottom: math.max(keyboard, safe.bottom),
      ),
      child: content,
    );
  }
}

/// Send mode: the full-width caption field, then the header chip and the
/// send button on one row. With the caption turned off only the send button
/// shows.
class _CaptionBar extends StatelessWidget {
  const _CaptionBar();

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final host = EditorHost.of(context);
    final caption = scope.captionField;
    final header = caption.enabled ? caption.header : null;

    return Form(
      key: host.formKey,
      child: Padding(
        padding: _barPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (caption.enabled) ...<Widget>[
              const CaptionField(),
              const SizedBox(height: 8),
            ],
            Row(
              children: <Widget>[
                // Takes the room the send button leaves, so a long header
                // is ellipsized instead of pushing the button off screen.
                Expanded(
                  child: header == null
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _HeaderChip(child: header),
                        ),
                ),
                const SizedBox(width: 8),
                const SendButtonSlot(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `CaptionFieldConfig.header` in a translucent pill on a single line,
/// ellipsized when too long: typically who the image goes to.
class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ChatImageEditorScope.of(context).theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.toolbarBackgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: DefaultTextStyle.merge(
          style: theme.labelStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          child: child,
        ),
      ),
    );
  }
}

/// The caption `TextFormField`, configured from `CaptionFieldConfig`.
///
/// The field stays mounted while a tool is open: the editor hides it and
/// takes its focus away, and when the tool closes it comes back with its
/// text but without focus or the keyboard. `CaptionFieldConfig.autofocus`
/// applies only the first time the field appears in an editor, so a field
/// built again (for example after the image changes) doesn't take focus
/// either.
class CaptionField extends StatefulWidget {
  /// Creates the caption field.
  const CaptionField({super.key});

  /// The default rounded pill decoration.
  static InputDecoration defaultDecoration(
    ChatImageEditorResolvedTheme theme,
    ChatImageEditorStrings strings,
  ) {
    final border = OutlineInputBorder(
      borderRadius: theme.captionBorderRadius,
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      hintText: strings.captionHint,
      hintStyle: theme.captionStyle.copyWith(color: theme.captionHintColor),
      counterStyle: theme.captionStyle.copyWith(
        color: theme.captionHintColor,
        fontSize: 12,
      ),
      filled: true,
      fillColor: theme.captionFillColor,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
      errorBorder: border,
      focusedErrorBorder: border,
    );
  }

  /// The decoration to use for [config]: the default pill, or the user's
  /// decoration with the localized hint filled in when it has none.
  static InputDecoration decorationFor(
    CaptionFieldConfig config,
    ChatImageEditorResolvedTheme theme,
    ChatImageEditorStrings strings,
  ) {
    final custom = config.decoration;
    if (custom == null) return defaultDecoration(theme, strings);
    if (custom.hintText == null && custom.hint == null) {
      return custom.copyWith(hintText: strings.captionHint);
    }
    return custom;
  }

  @override
  State<CaptionField> createState() => _CaptionFieldState();
}

class _CaptionFieldState extends State<CaptionField> {
  bool? _autofocus;
  ChatImageEditorController? _controller;
  bool _toolOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs again whenever the field moves in the tree (the form keeps its
    // state through its global key); only the first call may take the
    // editor's one-time autofocus.
    _autofocus ??= EditorHost.of(context).takeCaptionAutofocus();
    final controller = ChatImageEditorScope.of(context).controller;
    if (!identical(controller, _controller)) {
      _controller?.removeListener(_handleControllerChange);
      _controller = controller;
      controller.addListener(_handleControllerChange);
      _toolOpen = _isToolOpen(controller);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChange);
    super.dispose();
  }

  static bool _isToolOpen(ChatImageEditorController controller) {
    return controller.activeTool != EditorTool.none ||
        controller.editingTextId != null;
  }

  /// Takes focus, and with it the keyboard, away from the caption when a
  /// tool opens or text entry starts, however they were started. The caption
  /// is hidden then and must not keep receiving typed text, and text entry
  /// can only take focus once the caption has let go of it.
  void _handleControllerChange() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final open = _isToolOpen(controller);
    if (open == _toolOpen) return;
    _toolOpen = open;
    if (!open) return;
    final focus = FocusManager.instance.primaryFocus;
    final owner = focus?.context?.findAncestorStateOfType<_CaptionFieldState>();
    if (identical(owner, this)) focus!.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final host = EditorHost.of(context);
    final config = scope.captionField;
    final theme = scope.theme;

    return TextFormField(
      controller: host.captionController,
      focusNode: config.focusNode,
      decoration: CaptionField.decorationFor(config, theme, scope.strings),
      // The user's style overrides only what it sets; the themed caption
      // style (and its color) stays the base.
      style: theme.captionStyle.merge(config.style),
      cursorColor: config.cursorColor ?? theme.primaryColor,
      minLines: config.minLines,
      maxLines: config.maxLines,
      maxLength: config.maxLength,
      keyboardType: config.keyboardType,
      textInputAction: config.textInputAction,
      textCapitalization: config.textCapitalization,
      inputFormatters: config.inputFormatters,
      validator: config.validator,
      autovalidateMode: config.autovalidateMode,
      onChanged: config.onChanged,
      autofocus: _autofocus ?? false,
      onFieldSubmitted: config.textInputAction == TextInputAction.send
          ? (_) => unawaited(host.send(context))
          : null,
    );
  }
}
