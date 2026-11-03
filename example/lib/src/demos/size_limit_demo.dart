import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/widgets.dart';

/// Largest file the size-limit demo accepts.
const int sizeLimitBytes = 300 * 1024;

/// Caps the output at 1600 px on the long edge and 300 KB. If the JPEG is
/// too big, the editor steps its quality down until it fits.
Future<ChatImageEditorResult?> openSizeLimitDemo(
  BuildContext context,
  Uint8List image,
) {
  return ChatImageEditor.open(context, image, config: _sizeLimitConfig);
}

const ChatImageEditorConfig _sizeLimitConfig = ChatImageEditorConfig(
  export: ExportOptions(maxBytes: sizeLimitBytes, maxLongEdge: 1600),
);
