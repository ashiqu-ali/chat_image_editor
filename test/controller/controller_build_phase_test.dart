import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// No image decoding happens here, so testWidgets needs no runAsync.
void main() {
  testWidgets('applyDefaultColors during build notifies after the frame', (
    WidgetTester tester,
  ) async {
    final controller = ChatImageEditorController();
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);

    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          controller.applyDefaultColors(
            drawColor: const Color(0xFF112233),
            textColor: const Color(0xFF445566),
          );
          return const SizedBox();
        },
      ),
    );

    expect(tester.takeException(), isNull);
    expect(notified, 1);
    expect(controller.drawColor, const Color(0xFF112233));
    expect(controller.textColor, const Color(0xFF445566));
  });

  testWidgets('setting config during build notifies after the frame', (
    WidgetTester tester,
  ) async {
    final controller = ChatImageEditorController();
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);

    await tester.pumpWidget(
      Builder(
        builder: (BuildContext context) {
          controller.config = const ChatImageEditorConfig(
            maxStrokeWidth: 0.004,
          );
          return const SizedBox();
        },
      ),
    );

    expect(tester.takeException(), isNull);
    expect(notified, 1);
    expect(controller.strokeWidth, 0.004);
  });

  testWidgets('outside a build it notifies right away', (
    WidgetTester tester,
  ) async {
    final controller = ChatImageEditorController();
    addTearDown(controller.dispose);
    var notified = 0;
    controller.addListener(() => notified++);
    controller.applyDefaultColors(
      drawColor: const Color(0xFF010101),
      textColor: const Color(0xFF020202),
    );
    expect(notified, 1);
  });
}
