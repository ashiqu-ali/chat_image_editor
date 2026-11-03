import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/widgets.dart';

/// The editor with no customization at all.
///
/// No theme is passed, so every color is derived from the app's
/// `ColorScheme`: pick another seed color on the home screen and the accent
/// (send button, sliders, active tool, default pen color) follows.
Future<ChatImageEditorResult?> openDefaultDemo(
  BuildContext context,
  Uint8List image,
) {
  return ChatImageEditor.open(context, image);
}
