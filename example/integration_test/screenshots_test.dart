// Captures the README and pub.dev screenshots into doc/screenshots/.
//
//   fvm flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart -d <device>
//
// Then shrink them with `sips -Z 1080 ../doc/screenshots/*.png` (macOS), or
// do both with `tool/record_gifs.sh --screenshots` from the package root.
import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor_example/src/sample_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const Color _yellow = Color(0xFFFFEB3B);
const Color _red = Color(0xFFF44336);

/// A few annotations, in normalized original-image space.
const List<Stroke> _strokes = <Stroke>[
  Stroke(
    id: 's1',
    type: ShapeType.circle,
    points: <Offset>[Offset(0.58, 0.18), Offset(0.86, 0.42)],
    color: _yellow,
    width: 0.012,
  ),
  Stroke(
    id: 's2',
    type: ShapeType.arrow,
    points: <Offset>[Offset(0.30, 0.62), Offset(0.58, 0.40)],
    color: _yellow,
    width: 0.012,
  ),
  Stroke(
    id: 's3',
    type: ShapeType.freehand,
    points: <Offset>[
      Offset(0.10, 0.84),
      Offset(0.18, 0.80),
      Offset(0.26, 0.86),
      Offset(0.34, 0.80),
      Offset(0.42, 0.86),
      Offset(0.50, 0.81),
    ],
    color: _red,
    width: 0.01,
  ),
];

const List<TextLayer> _texts = <TextLayer>[
  TextLayer(
    id: 't1',
    text: 'Sunset spot 🌄',
    position: Offset(0.5, 0.12),
    fontSize: 0.07,
    color: Color(0xFFFFFFFF),
    background: TextBackgroundStyle.translucent,
  ),
  TextLayer(
    id: 't2',
    text: 'Meet here',
    position: Offset(0.3, 0.7),
    fontSize: 0.06,
    color: _yellow,
    background: TextBackgroundStyle.solid,
  ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List sampleImage;

  setUpAll(() async {
    sampleImage = await generateSampleImage();
  });

  testWidgets('draw tool', (tester) async {
    final controller = await _openEditor(
      tester,
      sampleImage,
      initialValue: const ImageEditValue(strokes: _strokes),
    );
    controller
      ..selectTool(EditorTool.draw)
      ..setShapeType(ShapeType.arrow)
      ..setDrawColor(_yellow);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('draw');
  });

  testWidgets('text layers and caption', (tester) async {
    await _openEditor(
      tester,
      sampleImage,
      initialValue: const ImageEditValue(
        strokes: <Stroke>[_arrowToText],
        texts: _texts,
      ),
      captionField: const CaptionFieldConfig(
        initialValue: 'Found the perfect place for Saturday',
        header: Text('Sending to Alex'),
      ),
    );
    await binding.takeScreenshot('text');
  });

  testWidgets('crop tool', (tester) async {
    final controller = await _openEditor(tester, sampleImage);
    controller
      ..selectTool(EditorTool.crop)
      ..setCrop(const Rect.fromLTWH(0.08, 0.1, 0.8, 0.75));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('crop');
  });

  testWidgets('compress sheet', (tester) async {
    final controller = await _openEditor(tester, sampleImage);
    controller
      ..selectTool(EditorTool.compress)
      ..setQuality(70);
    await tester.pump();
    // The sheet shows a small progress indicator until the debounced size
    // estimate is ready. It spins, so settle only once it's gone.
    final sheet = find
        .ancestor(
          of: find.text(const ChatImageEditorStrings().estimatedSizeLabel),
          matching: find.byType(Material),
        )
        .first;
    final estimating = find.descendant(
      of: sheet,
      matching: find.byWidgetPredicate((widget) => widget is ProgressIndicator),
    );
    for (var i = 0; i < 160 && estimating.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    }
    expect(estimating, findsNothing);
    await tester.pumpAndSettle();
    await binding.takeScreenshot('compress');
  });

  testWidgets('done mode with a custom theme', (tester) async {
    await _openEditor(
      tester,
      sampleImage,
      mode: ChatImageEditorMode.done,
      appTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      theme: const ChatImageEditorThemeData(
        sendButtonColor: Color(0xFF26A69A),
        toolbarBackgroundColor: Color(0x8026A69A),
      ),
      initialValue: const ImageEditValue(strokes: _strokes),
    );
    await binding.takeScreenshot('done_mode');
  });
}

const Stroke _arrowToText = Stroke(
  id: 'a1',
  type: ShapeType.arrow,
  points: <Offset>[Offset(0.42, 0.66), Offset(0.66, 0.42)],
  color: _yellow,
  width: 0.012,
);

/// Shows the editor and waits until the image has loaded.
Future<ChatImageEditorController> _openEditor(
  WidgetTester tester,
  Uint8List image, {
  ImageEditValue initialValue = ImageEditValue.empty,
  ChatImageEditorMode mode = ChatImageEditorMode.send,
  CaptionFieldConfig captionField = const CaptionFieldConfig(),
  ChatImageEditorThemeData? theme,
  ThemeData? appTheme,
}) async {
  final controller = ChatImageEditorController(
    config: ChatImageEditorConfig(mode: mode, enableHaptics: false),
    initialValue: initialValue,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme ?? ThemeData(colorSchemeSeed: Colors.indigo),
      home: ChatImageEditor(
        image: image,
        controller: controller,
        theme: theme,
        captionField: captionField,
        onComplete: (_) {},
        onCancel: () {},
      ),
    ),
  );
  for (var i = 0; i < 200; i++) {
    if (controller.loadStatus == ImageLoadStatus.ready) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  expect(controller.loadStatus, ImageLoadStatus.ready);
  await tester.pumpAndSettle();
  return controller;
}
