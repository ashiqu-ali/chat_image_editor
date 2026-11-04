import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor_example/src/app.dart';
import 'package:chat_image_editor_example/src/app_settings.dart';
import 'package:chat_image_editor_example/src/chat/chat_message.dart';
import 'package:chat_image_editor_example/src/chat/chat_screen.dart';
import 'package:chat_image_editor_example/src/chat/conversation.dart';
import 'package:chat_image_editor_example/src/chat/photo_viewer_screen.dart';
import 'package:chat_image_editor_example/src/sample_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the app opens on the chat and sends text messages', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(
      find.text('Hey! Did you find a place for Saturday?'),
      findsOneWidget,
    );

    // With an empty field the round button attaches a photo.
    expect(find.byTooltip('Send a photo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  On my way  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(find.text('On my way'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byType(ChatImageEditor), findsNothing);
  });

  testWidgets('attaching offers the gallery and the sample photo', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Attach a photo'));
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Sample photo'), findsOneWidget);
  });

  testWidgets('a photo shows its size and export time, and opens the '
      'viewer with the export details', (tester) async {
    final bytes = (await tester.runAsync(
      () => generateSampleImage(size: const Size(64, 48)),
    ))!;
    final result = ChatImageEditorResult(
      bytes: bytes,
      width: 64,
      height: 48,
      format: ExportFormat.jpeg,
      edits: const ImageEditValue(quarterTurns: 1),
      caption: 'Meet here',
      stats: ExportStats(
        decodeTime: const Duration(milliseconds: 20),
        renderTime: const Duration(milliseconds: 35),
        encodeTime: const Duration(milliseconds: 120),
        totalTime: const Duration(milliseconds: 182),
        encodeAttempts: 2,
        finalQuality: 72,
        sourceByteLength: bytes.lengthInBytes * 4,
        outputByteLength: bytes.lengthInBytes,
        outputWidth: 64,
        outputHeight: 48,
      ),
    );
    final settings = AppSettings();
    addTearDown(settings.dispose);
    final conversation = Conversation(
      contactName: 'Alex',
      messages: <ChatMessage>[
        ChatMessage(
          id: 'photo',
          fromMe: true,
          sentAt: DateTime(2026, 11, 4, 9, 41),
          text: result.caption,
          image: result,
        ),
      ],
    );
    addTearDown(conversation.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(settings: settings, conversation: conversation),
      ),
    );

    expect(find.text('Meet here'), findsOneWidget);
    expect(find.textContaining('182 ms'), findsOneWidget);

    final semantics = tester.ensureSemantics();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Photo'));
    await tester.pumpAndSettle();
    semantics.dispose();

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.text('64 × 48 · JPEG · quality 72'), findsOneWidget);
    expect(find.textContaining('75% smaller'), findsOneWidget);
    expect(
      find.text(
        '182 ms total · decode 20 ms · render 35 ms · encode 120 ms · '
        '2 passes',
      ),
      findsOneWidget,
    );
    expect(find.text('rotated 90°'), findsOneWidget);
  });
}
