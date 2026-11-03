import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/widgets.dart';

/// No caption, a single done button and lossless PNG output, e.g. for
/// editing a profile picture or an attachment before it's sent elsewhere.
Future<ChatImageEditorResult?> openDoneModeDemo(
  BuildContext context,
  Uint8List image,
) {
  return ChatImageEditor.open(context, image, config: _doneConfig);
}

const ChatImageEditorConfig _doneConfig = ChatImageEditorConfig(
  mode: ChatImageEditorMode.done,
  // PNG is lossless, so the quality tool would have nothing to do.
  tools: <EditorTool>[EditorTool.crop, EditorTool.text, EditorTool.draw],
  export: ExportOptions(format: ExportFormat.png),
);
