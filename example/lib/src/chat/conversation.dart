import 'dart:collection';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/foundation.dart';

import 'chat_message.dart';

/// The messages of a one-to-one chat, newest first.
///
/// Stands in for whatever an app keeps its chat state in. The editor
/// doesn't know about it: the chat screen opens the editor and hands the
/// result to [sendImage].
class Conversation extends ChangeNotifier {
  /// Creates a conversation with [contactName], starting with [messages]
  /// (newest first).
  Conversation({
    required this.contactName,
    List<ChatMessage> messages = const <ChatMessage>[],
    DateTime Function()? clock,
  }) : _messages = List<ChatMessage>.of(messages),
       _clock = clock ?? DateTime.now;

  /// The example's starting chat: a friend asking for a photo.
  factory Conversation.demo({DateTime Function()? clock}) {
    final now = (clock ?? DateTime.now)();
    return Conversation(
      contactName: 'Alex',
      clock: clock,
      messages: <ChatMessage>[
        ChatMessage(
          id: 'welcome-2',
          fromMe: false,
          sentAt: now.subtract(const Duration(minutes: 2)),
          text: 'Send me a photo and mark where we should meet 📍',
        ),
        ChatMessage(
          id: 'welcome-1',
          fromMe: false,
          sentAt: now.subtract(const Duration(minutes: 3)),
          text: 'Hey! Did you find a place for Saturday?',
        ),
      ],
    );
  }

  /// Name shown in the app bar and the editor's caption header.
  final String contactName;

  final List<ChatMessage> _messages;
  final DateTime Function() _clock;
  int _nextId = 0;

  /// Every message, newest first, ready for a reversed list.
  late final List<ChatMessage> messages = UnmodifiableListView<ChatMessage>(
    _messages,
  );

  /// Adds a text message from the user. Blank text is ignored.
  void sendText(String text) {
    final body = text.trim();
    if (body.isEmpty) return;
    _add(ChatMessage(id: _newId(), fromMe: true, sentAt: _clock(), text: body));
  }

  /// Adds a photo message from the user, with the caption typed in the
  /// editor.
  void sendImage(ChatImageEditorResult result) {
    _add(
      ChatMessage(
        id: _newId(),
        fromMe: true,
        sentAt: _clock(),
        text: result.caption,
        image: result,
      ),
    );
  }

  void _add(ChatMessage message) {
    _messages.insert(0, message);
    notifyListeners();
  }

  String _newId() => 'sent-${_nextId++}';
}
