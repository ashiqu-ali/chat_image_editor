import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A small, valid PNG.
Uint8List testPng({int width = 40, int height = 30}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 120, 40));
  return img.encodePng(image);
}

/// Pumps an editor whose image is already decoded, so the editing UI shows
/// right away. Returns the controller.
Future<ChatImageEditorController> pumpReadyEditor(
  WidgetTester tester, {
  ThemeData? appTheme,
  ChatImageEditorConfig config = const ChatImageEditorConfig(),
  ChatImageEditorThemeData? theme,
  ChatImageEditorIcons icons = const ChatImageEditorIcons(),
  ChatImageEditorStrings strings = const ChatImageEditorStrings(),
  CaptionFieldConfig captionField = const CaptionFieldConfig(),
  ChatImageEditorBuilders builders = const ChatImageEditorBuilders(),
  ValueListenable<bool>? sendEnabled,
  SendLongPressCallback? onSendLongPress,
  ValueChanged<ChatImageEditorResult>? onComplete,
  VoidCallback? onCancel,
}) async {
  final bytes = testPng();
  final controller = ChatImageEditorController(config: config);
  addTearDown(controller.dispose);
  await tester.runAsync(() => controller.load(bytes));
  expect(controller.loadStatus, ImageLoadStatus.ready);

  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: ChatImageEditor(
        image: bytes,
        controller: controller,
        config: config,
        theme: theme,
        icons: icons,
        strings: strings,
        captionField: captionField,
        builders: builders,
        sendEnabled: sendEnabled,
        onSendLongPress: onSendLongPress,
        onComplete: onComplete ?? (_) {},
        onCancel: onCancel ?? () {},
      ),
    ),
  );
  await tester.pump();
  return controller;
}

/// Lets real asynchronous work (decoding, encoding) run, pumping frames in
/// between, until [done] returns `true` or the attempts run out.
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() done, {
  int attempts = 200,
}) async {
  for (var i = 0; i < attempts && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// Background color of the default send (or done) button with [tooltip].
Color? buttonColor(WidgetTester tester, String tooltip) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byTooltip(tooltip),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.color;
}

/// The editor scope seen by the widget [finder] points at.
ChatImageEditorScope scopeOf(WidgetTester tester, Finder finder) {
  return ChatImageEditorScope.of(tester.element(finder));
}
