import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/caption_field_config.dart';
import '../config/chat_image_editor_builders.dart';
import '../config/chat_image_editor_config.dart';
import '../controller/chat_image_editor_controller.dart';
import '../core/export/chat_image_editor_result.dart';
import '../theme/chat_image_editor_icons.dart';
import '../theme/chat_image_editor_strings.dart';
import '../theme/chat_image_editor_theme.dart';

/// Runs an export and returns its result, or `null` on failure.
typedef ExportCallback = Future<ChatImageEditorResult?> Function();

/// Called on a long press of the send button with a way to export on
/// demand (for example after the user picks a time in a schedule sheet).
/// Return `true` to close the editor, `false` to stay.
typedef SendLongPressCallback =
    Future<bool> Function(BuildContext context, ExportCallback export);

/// A full-screen, WhatsApp-style image editor.
///
/// Use [ChatImageEditor.open] to push it as a route and await the result,
/// or embed the widget yourself and handle [onComplete] and [onCancel].
class ChatImageEditor extends StatefulWidget {
  /// Creates an editor for [image] (encoded bytes: JPEG, PNG, WebP, …).
  const ChatImageEditor({
    super.key,
    required this.image,
    this.controller,
    this.config = const ChatImageEditorConfig(),
    this.theme,
    this.icons = const ChatImageEditorIcons(),
    this.strings = const ChatImageEditorStrings(),
    this.captionField = const CaptionFieldConfig(),
    this.builders = const ChatImageEditorBuilders(),
    this.sendEnabled,
    this.onSendLongPress,
    this.onComplete,
    this.onCancel,
  });

  /// Encoded source image.
  final Uint8List image;

  /// Optional external controller. When `null` the editor creates and
  /// disposes its own.
  final ChatImageEditorController? controller;

  /// Behaviour configuration.
  final ChatImageEditorConfig config;

  /// Color and style overrides; see [ChatImageEditorThemeData].
  final ChatImageEditorThemeData? theme;

  /// Icon overrides.
  final ChatImageEditorIcons icons;

  /// Text overrides, for localization.
  final ChatImageEditorStrings strings;

  /// Caption `TextFormField` configuration (send mode).
  final CaptionFieldConfig captionField;

  /// Builders that replace parts of the UI.
  final ChatImageEditorBuilders builders;

  /// Disables the send button while `false`. `null` means always enabled.
  final ValueListenable<bool>? sendEnabled;

  /// Long-press action for the send button. `null` disables long press.
  final SendLongPressCallback? onSendLongPress;

  /// Called with the result after a successful send or done. When `null`,
  /// the editor pops its route with the result.
  final ValueChanged<ChatImageEditorResult>? onComplete;

  /// Called when the user closes the editor (after any discard
  /// confirmation). When `null`, the editor pops its route with `null`.
  final VoidCallback? onCancel;

  /// Pushes the editor as a full-screen route and completes with the
  /// result, or `null` if the user closed it.
  static Future<ChatImageEditorResult?> open(
    BuildContext context,
    Uint8List image, {
    ChatImageEditorController? controller,
    ChatImageEditorConfig config = const ChatImageEditorConfig(),
    ChatImageEditorThemeData? theme,
    ChatImageEditorIcons icons = const ChatImageEditorIcons(),
    ChatImageEditorStrings strings = const ChatImageEditorStrings(),
    CaptionFieldConfig captionField = const CaptionFieldConfig(),
    ChatImageEditorBuilders builders = const ChatImageEditorBuilders(),
    ValueListenable<bool>? sendEnabled,
    SendLongPressCallback? onSendLongPress,
    bool useRootNavigator = true,
  }) {
    throw UnimplementedError();
  }

  @override
  State<ChatImageEditor> createState() => _ChatImageEditorState();
}

class _ChatImageEditorState extends State<ChatImageEditor> {
  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
