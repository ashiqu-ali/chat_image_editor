import 'package:flutter/widgets.dart';

import '../config/caption_field_config.dart';
import '../config/chat_image_editor_builders.dart';
import '../config/chat_image_editor_config.dart';
import '../controller/chat_image_editor_controller.dart';
import 'chat_image_editor_icons.dart';
import 'chat_image_editor_strings.dart';
import 'chat_image_editor_theme.dart';

/// Makes the editor's controller, resolved theme, icons, strings and
/// configuration available to every widget below `ChatImageEditor`.
///
/// Custom builders can read it with `ChatImageEditorScope.of(context)`.
class ChatImageEditorScope extends InheritedWidget {
  /// Creates the scope.
  const ChatImageEditorScope({
    super.key,
    required this.controller,
    required this.theme,
    required this.icons,
    required this.strings,
    required this.config,
    required this.captionField,
    required this.builders,
    required super.child,
  });

  /// The editor's controller.
  final ChatImageEditorController controller;

  /// Fully resolved colors, styles and sizes.
  final ChatImageEditorResolvedTheme theme;

  /// Icons in use.
  final ChatImageEditorIcons icons;

  /// Strings in use.
  final ChatImageEditorStrings strings;

  /// Behaviour configuration.
  final ChatImageEditorConfig config;

  /// Caption field configuration.
  final CaptionFieldConfig captionField;

  /// Builder overrides.
  final ChatImageEditorBuilders builders;

  /// The nearest scope, or `null` outside an editor.
  static ChatImageEditorScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChatImageEditorScope>();
  }

  /// The nearest scope. Throws outside an editor.
  static ChatImageEditorScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'No ChatImageEditorScope found in context.');
    return scope!;
  }

  @override
  bool updateShouldNotify(ChatImageEditorScope oldWidget) {
    return controller != oldWidget.controller ||
        theme != oldWidget.theme ||
        icons != oldWidget.icons ||
        strings != oldWidget.strings ||
        config != oldWidget.config ||
        captionField != oldWidget.captionField ||
        builders != oldWidget.builders;
  }
}
