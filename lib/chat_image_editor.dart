/// A lightweight, WhatsApp-style image editor for chat apps.
///
/// Open it with [ChatImageEditor.open] and await a [ChatImageEditorResult]:
///
/// ```dart
/// final result = await ChatImageEditor.open(context, bytes);
/// if (result != null) send(result.bytes, result.caption);
/// ```
library;

export 'src/config/caption_field_config.dart';
export 'src/config/chat_image_editor_builders.dart';
export 'src/config/chat_image_editor_config.dart';
export 'src/config/export_options.dart';
export 'src/controller/chat_image_editor_controller.dart';
export 'src/core/encoding/dart_image_encoder.dart';
export 'src/core/encoding/image_encoder.dart';
export 'src/core/export/chat_image_editor_result.dart';
export 'src/core/geometry/image_geometry.dart';
export 'src/core/render/composition_renderer.dart';
export 'src/core/render/stroke_renderer.dart';
export 'src/core/render/text_renderer.dart';
export 'src/models/editor_enums.dart';
export 'src/models/image_edit_value.dart';
export 'src/models/stroke.dart';
export 'src/models/text_layer.dart';
export 'src/theme/chat_image_editor_icons.dart';
export 'src/theme/chat_image_editor_scope.dart';
export 'src/theme/chat_image_editor_strings.dart';
export 'src/theme/chat_image_editor_theme.dart';
export 'src/ui/chat_image_editor.dart';
