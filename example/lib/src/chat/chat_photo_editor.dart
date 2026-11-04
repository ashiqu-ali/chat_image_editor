import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';

/// Largest photo the chat sends. When the JPEG is bigger, the editor steps
/// its quality down until it fits.
const int chatPhotoMaxBytes = 1024 * 1024;

/// How the chat exports photos.
///
/// A phone photo is often 12 MP and several megabytes. Chat apps send a
/// downscaled JPEG instead: 1600 px on the long edge at quality 80 looks
/// sharp on a phone and is usually 150–400 KB. The editor decodes the
/// source only at the size it needs, and encodes off the UI thread.
const ChatImageEditorConfig chatPhotoEditorConfig = ChatImageEditorConfig(
  export: ExportOptions(
    maxLongEdge: 1600,
    quality: 80,
    maxBytes: chatPhotoMaxBytes,
  ),
);

/// Opens the editor for a photo the user is about to send to [recipient].
///
/// [draft] is whatever was typed in the chat's message field; it becomes
/// the caption, like in most chat apps. Completes with `null` if the user
/// closed the editor.
Future<ChatImageEditorResult?> editPhotoForChat(
  BuildContext context,
  Uint8List photo, {
  required String recipient,
  String draft = '',
}) async {
  final result = await ChatImageEditor.open(
    context,
    photo,
    config: chatPhotoEditorConfig,
    captionField: CaptionFieldConfig(
      initialValue: draft.isEmpty ? null : draft,
      header: Text('Sending to $recipient'),
      maxLines: 4,
    ),
  );
  final stats = result?.stats;
  if (stats != null) {
    // Shows up in DevTools' Logging view. Send it to your own analytics to
    // watch export times on real devices.
    developer.log('$stats', name: 'chat_image_editor');
  }
  return result;
}
