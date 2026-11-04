import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor_example/src/chat/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sentAt = DateTime(2026, 11, 4, 9, 41);

  test('sendText trims, ignores blanks and adds the newest first', () {
    final conversation = Conversation(contactName: 'Alex', clock: () => sentAt);
    addTearDown(conversation.dispose);
    var notifications = 0;
    conversation.addListener(() => notifications++);

    conversation
      ..sendText('   ')
      ..sendText(' first ')
      ..sendText('second');

    expect(notifications, 2);
    expect(conversation.messages.map((message) => message.text), <String>[
      'second',
      'first',
    ]);
    expect(conversation.messages.every((message) => message.fromMe), isTrue);
    expect(conversation.messages.first.sentAt, sentAt);
  });

  test('sendImage keeps the result and uses its caption as the text', () {
    final conversation = Conversation(contactName: 'Alex', clock: () => sentAt);
    addTearDown(conversation.dispose);
    final result = ChatImageEditorResult(
      bytes: Uint8List(8),
      width: 4,
      height: 2,
      format: ExportFormat.jpeg,
      edits: ImageEditValue.empty,
      caption: 'Meet here',
    );

    conversation.sendImage(result);

    final message = conversation.messages.single;
    expect(message.image, same(result));
    expect(message.text, 'Meet here');
    expect(message.fromMe, isTrue);
  });

  test('the demo starts with the contact asking for a photo', () {
    final conversation = Conversation.demo(clock: () => sentAt);
    addTearDown(conversation.dispose);

    expect(conversation.contactName, 'Alex');
    expect(conversation.messages, hasLength(2));
    expect(conversation.messages.any((message) => message.fromMe), isFalse);
    // Newest first.
    expect(
      conversation.messages.first.sentAt.isAfter(
        conversation.messages.last.sentAt,
      ),
      isTrue,
    );
    expect(() => conversation.messages.clear(), throwsUnsupportedError);
  });
}
