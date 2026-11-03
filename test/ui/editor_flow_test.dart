import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/ui/editor_canvas.dart';
import 'package:chat_image_editor/src/ui/editor_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'editor_test_utils.dart';

/// Fill color of the generated source image.
const int _fillR = 30;
const int _fillG = 90;
const int _fillB = 160;

void main() {
  testWidgets('draw, add text, rotate, then send with a caption', (
    tester,
  ) async {
    const sourceWidth = 64;
    const sourceHeight = 40;
    final source = img.Image(width: sourceWidth, height: sourceHeight);
    img.fill(source, color: img.ColorRgb8(_fillR, _fillG, _fillB));
    final bytes = img.encodePng(source);

    ChatImageEditorResult? result;
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatImageEditor(
          image: bytes,
          onComplete: (value) => result = value,
          onCancel: () => cancelled = true,
        ),
      ),
    );

    // The editor owns its controller and decodes the image itself.
    ChatImageEditorController controller() => tester
        .widget<ChatImageEditorScope>(find.byType(ChatImageEditorScope))
        .controller;
    await pumpUntil(
      tester,
      () => controller().loadStatus == ImageLoadStatus.ready,
    );
    await tester.pump();
    expect(controller().loadStatus, ImageLoadStatus.ready);
    expect(controller().originalSize, const Size(64, 40));

    // Draw a stroke across the middle of the image.
    await tester.tap(find.byTooltip('Draw'));
    await tester.pump();
    expect(controller().activeTool, EditorTool.draw);

    final canvas = find.byType(EditorCanvas);
    final imageRect = EditorLayout.imageRect(
      tester.getSize(canvas),
      EditorLayout.canvasPadding(tester.element(canvas), EditorTool.draw),
      EditorLayout.paintedOutputSize(controller()),
    ).shift(tester.getTopLeft(canvas));
    await tester.dragFrom(
      imageRect.center - Offset(imageRect.width / 4, 0),
      Offset(imageRect.width / 2, imageRect.height / 4),
    );
    await tester.pumpAndSettle();
    expect(controller().value.strokes, hasLength(1));

    // Leave the draw tool by tapping it again.
    await tester.tap(find.byTooltip('Draw'));
    await tester.pumpAndSettle();
    expect(controller().activeTool, EditorTool.none);

    // Add a text layer.
    await tester.tap(find.byTooltip('Text'));
    await tester.pump();
    expect(controller().editingTextId, isNotNull);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(controller().editingTextId, isNull);
    expect(controller().value.texts.single.text, 'Hello');

    // Rotate a quarter turn clockwise in the crop tool and confirm.
    await tester.tap(find.byTooltip('Crop and rotate'));
    await tester.pumpAndSettle();
    expect(controller().activeTool, EditorTool.crop);
    await tester.tap(find.byTooltip('Rotate right'));
    await tester.pump();
    await tester.tap(find.byTooltip('Done'));
    await tester.pumpAndSettle();
    expect(controller().activeTool, EditorTool.none);
    expect(controller().value.quarterTurns, 1);

    // Type a caption and send.
    await tester.enterText(find.byType(TextFormField), '  Evening walk  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await pumpUntil(tester, () => result != null);

    expect(cancelled, isFalse);
    final sent = result;
    expect(sent, isNotNull);
    sent!;
    expect(sent.caption, 'Evening walk');
    expect(sent.format, ExportFormat.jpeg);

    // A quarter turn swaps the source's width and height.
    expect(sent.width, sourceHeight);
    expect(sent.height, sourceWidth);

    expect(sent.edits.strokes, hasLength(1));
    expect(sent.edits.texts.single.text, 'Hello');
    expect(sent.edits.quarterTurns, 1);
    expect(sent.edits.crop, isNull);

    // The encoded bytes match the reported size and carry the drawn edits.
    final decoded = img.decodeImage(sent.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, sourceHeight);
    expect(decoded.height, sourceWidth);
    expect(_countEditedPixels(decoded), greaterThan(0));
  });
}

/// Number of pixels clearly different from the source fill color, which
/// can only come from the stroke or the text.
int _countEditedPixels(img.Image image) {
  var count = 0;
  for (final pixel in image) {
    final distance =
        (pixel.r - _fillR).abs() +
        (pixel.g - _fillG).abs() +
        (pixel.b - _fillB).abs();
    if (distance > 120) count++;
  }
  return count;
}
