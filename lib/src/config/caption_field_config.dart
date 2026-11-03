import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuration for the caption `TextFormField` shown in send mode.
///
/// Every field maps onto the matching `TextFormField` parameter. Leave a
/// field `null` to get the editor's themed default.
@immutable
class CaptionFieldConfig {
  /// Creates a caption field configuration.
  const CaptionFieldConfig({
    this.enabled = true,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.decoration,
    this.style,
    this.cursorColor,
    this.minLines = 1,
    this.maxLines = 5,
    this.maxLength,
    this.keyboardType = TextInputType.multiline,
    this.textInputAction = TextInputAction.newline,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.autofocus = false,
    this.header,
  }) : assert(
         controller == null || initialValue == null,
         'Pass either a controller or an initialValue, not both.',
       );

  /// Show the caption field at all. When `false` only the send button shows.
  final bool enabled;

  /// Controls the caption text. When `null` the editor owns a controller.
  final TextEditingController? controller;

  /// Focus node for the field.
  final FocusNode? focusNode;

  /// Starting caption, when no [controller] is given.
  final String? initialValue;

  /// Replaces the default pill decoration. If its `hintText` is `null`, the
  /// hint from `ChatImageEditorStrings.captionHint` is used.
  final InputDecoration? decoration;

  /// Style of the typed text, merged onto the theme's caption style: it
  /// overrides only the properties it sets.
  final TextStyle? style;

  /// Cursor color. Defaults to the theme's primary color.
  final Color? cursorColor;

  /// Minimum visible lines.
  final int? minLines;

  /// Maximum visible lines before the field scrolls.
  final int? maxLines;

  /// Maximum number of characters, or `null` for no limit.
  final int? maxLength;

  /// Keyboard type.
  final TextInputType keyboardType;

  /// Action button on the keyboard.
  final TextInputAction textInputAction;

  /// Automatic capitalization.
  final TextCapitalization textCapitalization;

  /// Input formatters applied while typing.
  final List<TextInputFormatter>? inputFormatters;

  /// Validates the caption before sending. Sending is blocked while it
  /// returns a non-null error.
  final FormFieldValidator<String>? validator;

  /// When to run [validator].
  final AutovalidateMode? autovalidateMode;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Focus the field when the editor opens. Applies once: the field
  /// doesn't take focus again when it reappears after a tool closes.
  final bool autofocus;

  /// Optional widget above the field, e.g. "Sending to Alex".
  final Widget? header;
}
