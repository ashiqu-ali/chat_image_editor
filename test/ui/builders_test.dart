import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('builders', () {
    testWidgets('topBar replaces the top bar and sees the scope', (
      tester,
    ) async {
      ChatImageEditorController? received;
      ChatImageEditorScope? scope;
      final controller = await pumpReadyEditor(
        tester,
        builders: ChatImageEditorBuilders(
          topBar: (context, controller) {
            received = controller;
            scope = ChatImageEditorScope.maybeOf(context);
            return const Text('custom top bar');
          },
        ),
      );

      expect(find.text('custom top bar'), findsOneWidget);
      expect(find.byTooltip('Close'), findsNothing);
      expect(find.byTooltip('Draw'), findsNothing);
      expect(received, same(controller));
      expect(scope, isNotNull);
    });

    testWidgets('bottomBar replaces the caption and send button', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        captionField: const CaptionFieldConfig(header: Text('Sending to Sam')),
        builders: ChatImageEditorBuilders(
          bottomBar: (context, controller) => const Text('custom bottom bar'),
        ),
      );

      expect(find.text('custom bottom bar'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Sending to Sam'), findsNothing);
      expect(find.byTooltip('Send'), findsNothing);
    });

    testWidgets('sendButton replaces only the button, beside the header', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        captionField: const CaptionFieldConfig(header: Text('Sending to Sam')),
        builders: ChatImageEditorBuilders(
          sendButton: (context, details) => const SizedBox.square(
            key: ValueKey<String>('custom send'),
            dimension: 44,
          ),
        ),
      );

      final field = tester.getRect(find.byType(TextFormField));
      final header = tester.getRect(find.text('Sending to Sam'));
      final send = tester.getRect(find.byKey(const ValueKey('custom send')));
      expect(send.top, greaterThanOrEqualTo(field.bottom));
      expect(header.top, greaterThanOrEqualTo(field.bottom));
      expect(header.right, lessThan(send.left));
      expect(header.center.dy, moreOrLessEquals(send.center.dy));
      expect(send.right, moreOrLessEquals(field.right));
    });

    testWidgets('sendButton gets live details', (tester) async {
      final enabled = ValueNotifier<bool>(false);
      addTearDown(enabled.dispose);
      final details = <SendButtonDetails>[];
      await pumpReadyEditor(
        tester,
        sendEnabled: enabled,
        onSendLongPress: (context, export) async => false,
        builders: ChatImageEditorBuilders(
          sendButton: (context, value) {
            details.add(value);
            return const Text('custom send');
          },
        ),
      );

      expect(find.text('custom send'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
      expect(details.last.enabled, isFalse);
      expect(details.last.busy, isFalse);
      expect(details.last.onPressed, isNull);
      expect(details.last.onLongPress, isNull);

      enabled.value = true;
      await tester.pump();
      expect(details.last.enabled, isTrue);
      expect(details.last.onPressed, isNotNull);
      expect(details.last.onLongPress, isNotNull);
    });

    testWidgets('doneButton is used in done mode', (tester) async {
      await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(mode: ChatImageEditorMode.done),
        builders: ChatImageEditorBuilders(
          sendButton: (context, details) => const Text('custom send'),
          doneButton: (context, details) {
            expect(details.onLongPress, isNull);
            return const Text('custom done');
          },
        ),
      );

      expect(find.text('custom done'), findsOneWidget);
      expect(find.text('custom send'), findsNothing);
    });

    testWidgets('loading shows while the image decodes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageEditor(
            image: testPng(),
            builders: ChatImageEditorBuilders(
              loading: (context) => const Text('custom loading'),
            ),
          ),
        ),
      );

      expect(find.text('custom loading'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });

    testWidgets('the default loading view uses the themed indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageEditor(
            image: testPng(),
            theme: const ChatImageEditorThemeData(
              loadingIndicatorColor: Color(0xFF00FF00),
            ),
          ),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, const Color(0xFF00FF00));
    });

    testWidgets('error shows when the image can\'t be decoded', (tester) async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final controller = ChatImageEditorController();
      addTearDown(controller.dispose);
      await tester.runAsync(() => controller.load(bytes));
      expect(controller.loadStatus, ImageLoadStatus.failed);

      Object? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageEditor(
            image: bytes,
            controller: controller,
            builders: ChatImageEditorBuilders(
              error: (context, error) {
                reported = error;
                return const Text('custom error');
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('custom error'), findsOneWidget);
      expect(reported, isNotNull);
    });

    testWidgets('the default error view shows the loadFailed string', (
      tester,
    ) async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5]);
      final controller = ChatImageEditorController();
      addTearDown(controller.dispose);
      await tester.runAsync(() => controller.load(bytes));

      await tester.pumpWidget(
        MaterialApp(
          home: ChatImageEditor(
            image: bytes,
            controller: controller,
            strings: const ChatImageEditorStrings(loadFailed: 'Bad image'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Bad image'), findsOneWidget);
    });
  });
}
