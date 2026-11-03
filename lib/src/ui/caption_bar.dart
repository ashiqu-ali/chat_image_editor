import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/caption_field_config.dart';
import '../models/editor_enums.dart';
import '../theme/chat_image_editor_scope.dart';
import '../theme/chat_image_editor_strings.dart';
import '../theme/chat_image_editor_theme.dart';
import 'editor_host.dart';
import 'send_button.dart';

/// The bottom area of the editor.
///
/// Uses `ChatImageEditorBuilders.bottomBar` when set; otherwise shows the
/// caption field and send button (send mode) or a done button (done mode).
/// Rides above the keyboard without resizing the image.
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
        padding: EdgeInsets.fromLTRB(8, 8, 12, 8),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SendButtonSlot(),
        ),
      );
    } else {
      content = const _CaptionRow();
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

class _CaptionRow extends StatelessWidget {
  const _CaptionRow();

  @override
  Widget build(BuildContext context) {
    final scope = ChatImageEditorScope.of(context);
    final host = EditorHost.of(context);
    final caption = scope.captionField;

    return Form(
      key: host.formKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (caption.enabled && caption.header != null)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: DefaultTextStyle.merge(
                  style: scope.theme.labelStyle,
                  child: caption.header!,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (caption.enabled)
                  const Expanded(child: CaptionField())
                else
                  const Spacer(),
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

/// The caption `TextFormField`, configured from `CaptionFieldConfig`.
///
/// `CaptionFieldConfig.autofocus` applies only the first time the field
/// appears: it's rebuilt from scratch whenever a tool closes, and must not
/// pop the keyboard up again then.
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _autofocus ??= EditorHost.of(context).takeCaptionAutofocus();
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
