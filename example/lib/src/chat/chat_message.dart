import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/foundation.dart';

/// One message in the conversation: text, or an edited photo with an
/// optional caption.
@immutable
class ChatMessage {
  /// Creates a message.
  const ChatMessage({
    required this.id,
    required this.fromMe,
    required this.sentAt,
    this.text = '',
    this.image,
  });

  /// Unique within the conversation. Also the photo's hero tag.
  final String id;

  /// `true` for messages the user sent, `false` for the contact's.
  final bool fromMe;

  /// When the message was sent.
  final DateTime sentAt;

  /// The message body, or the photo's caption. Empty for a photo without
  /// one.
  final String text;

  /// The edited photo, exactly as the editor returned it. `null` for a text
  /// message.
  ///
  /// A real app would upload `image.bytes` and keep the URL instead; the
  /// example keeps the bytes so it works offline.
  final ChatImageEditorResult? image;
}
