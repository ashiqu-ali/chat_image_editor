import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('send mode', () {
    testWidgets('shows a caption field and a send button', (tester) async {
      await pumpReadyEditor(tester);

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.byTooltip('Send'), findsOneWidget);
      expect(find.byTooltip('Done'), findsNothing);
    });

    testWidgets('send exports and completes with the trimmed caption', (
      tester,
    ) async {
      ChatImageEditorResult? result;
      await pumpReadyEditor(tester, onComplete: (value) => result = value);

      await tester.enterText(find.byType(TextFormField), '  Look at this  ');
      await tester.tap(find.byTooltip('Send'));
      await pumpUntil(tester, () => result != null);

      expect(result, isNotNull);
      expect(result!.caption, 'Look at this');
      expect(result!.bytes, isNotEmpty);
    });

    testWidgets('a disabled send button does nothing', (tester) async {
      final enabled = ValueNotifier<bool>(false);
      addTearDown(enabled.dispose);
      var completed = false;
      final controller = await pumpReadyEditor(
        tester,
        sendEnabled: enabled,
        onComplete: (_) => completed = true,
      );

      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      expect(controller.isExporting, isFalse);
      expect(completed, isFalse);
    });

    testWidgets('long press hands the host an export callback', (tester) async {
      ExportCallback? received;
      var cancelled = false;
      await pumpReadyEditor(
        tester,
        onSendLongPress: (context, export) async {
          received = export;
          return true;
        },
        onCancel: () => cancelled = true,
      );

      await tester.longPress(find.byTooltip('Send'));
      await tester.pump();

      expect(received, isNotNull);
      expect(cancelled, isTrue);
    });

    testWidgets('long press returning false keeps the editor open', (
      tester,
    ) async {
      var calls = 0;
      var cancelled = false;
      await pumpReadyEditor(
        tester,
        onSendLongPress: (context, export) async {
          calls++;
          return false;
        },
        onCancel: () => cancelled = true,
      );

      await tester.longPress(find.byTooltip('Send'));
      await tester.pump();

      expect(calls, 1);
      expect(cancelled, isFalse);
      expect(find.byTooltip('Send'), findsOneWidget);
    });
  });

  group('done mode', () {
    const doneConfig = ChatImageEditorConfig(mode: ChatImageEditorMode.done);

    testWidgets('shows only a done button', (tester) async {
      await pumpReadyEditor(tester, config: doneConfig);

      expect(find.byType(TextFormField), findsNothing);
      expect(find.byTooltip('Done'), findsOneWidget);
      expect(find.byTooltip('Send'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('the done button sits alone at the end of the bar', (
      tester,
    ) async {
      await pumpReadyEditor(
        tester,
        config: doneConfig,
        captionField: const CaptionFieldConfig(header: Text('Sending to Sam')),
      );

      // The header belongs to the caption, which done mode doesn't show.
      expect(find.text('Sending to Sam'), findsNothing);
      final screen = tester.getSize(find.byType(Scaffold));
      final done = tester.getRect(find.byTooltip('Done'));
      expect(done.left, greaterThan(screen.width / 2));
      expect(done.right, greaterThanOrEqualTo(screen.width - 16));
      expect(done.bottom, greaterThanOrEqualTo(screen.height - 80));
    });

    testWidgets('done completes without a caption', (tester) async {
      ChatImageEditorResult? result;
      await pumpReadyEditor(
        tester,
        config: doneConfig,
        captionField: const CaptionFieldConfig(initialValue: 'ignored'),
        onComplete: (value) => result = value,
      );

      await tester.tap(find.byTooltip('Done'));
      await pumpUntil(tester, () => result != null);

      expect(result, isNotNull);
      expect(result!.caption, isEmpty);
    });
  });

  group('open', () {
    testWidgets('pushes a route that completes with null on close', (
      tester,
    ) async {
      final bytes = testPng();
      final controller = ChatImageEditorController();
      addTearDown(controller.dispose);
      await tester.runAsync(() => controller.load(bytes));

      late BuildContext appContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              appContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      var finished = false;
      ChatImageEditorResult? result;
      final future = ChatImageEditor.open(
        appContext,
        bytes,
        controller: controller,
      );
      future.then((value) {
        finished = true;
        result = value;
      }).ignore();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Send'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(result, isNull);
      expect(find.byTooltip('Send'), findsNothing);
    });
  });
}
