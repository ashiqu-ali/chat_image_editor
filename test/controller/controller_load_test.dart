import 'dart:typed_data';

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/test_utils.dart';
import 'controller_helpers.dart';

void main() {
  test('starts idle with the initial value', () {
    const initial = ImageEditValue(quarterTurns: 1);
    final controller = ChatImageEditorController(initialValue: initial);
    addTearDown(controller.dispose);
    expect(controller.loadStatus, ImageLoadStatus.idle);
    expect(controller.image, isNull);
    expect(controller.originalSize, Size.zero);
    expect(controller.sourceBytes, isNull);
    expect(controller.value, initial);
    expect(controller.hasChanges, isFalse);
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
    expect(controller.activeTool, EditorTool.none);
  });

  test('load decodes the preview and reports progress', () async {
    final controller = ChatImageEditorController(
      config: const ChatImageEditorConfig(previewMaxLongEdge: 40),
    );
    addTearDown(controller.dispose);
    final statuses = <ImageLoadStatus>[];
    controller.addListener(() => statuses.add(controller.loadStatus));

    final future = controller.load(sourcePng);
    expect(controller.loadStatus, ImageLoadStatus.loading);
    expect(controller.sourceBytes, same(sourcePng));
    await future;

    expect(statuses, <ImageLoadStatus>[
      ImageLoadStatus.loading,
      ImageLoadStatus.ready,
    ]);
    expect(controller.originalSize, sourceSize);
    expect(controller.image!.width, 40);
    expect(controller.image!.height, 30);
    expect(controller.loadError, isNull);
  });

  test('load reports failure for bytes that are not an image', () async {
    final controller = ChatImageEditorController();
    addTearDown(controller.dispose);
    await controller.load(Uint8List.fromList(<int>[0, 1, 2, 3]));
    expect(controller.loadStatus, ImageLoadStatus.failed);
    expect(controller.loadError, isNotNull);
    expect(controller.image, isNull);
    expect(controller.originalSize, Size.zero);
  });

  test('keeps the initial value on the first load', () async {
    const initial = ImageEditValue(quarterTurns: 2, quality: 50);
    final controller = await loadedController(initialValue: initial);
    expect(controller.value, initial);
    expect(controller.hasChanges, isFalse);
  });

  test('loading a new image clears edits and history', () async {
    final controller = await loadedController();
    controller
      ..rotateRight()
      ..startStroke(const Offset(0.1, 0.1))
      ..updateStroke(const Offset(0.5, 0.5))
      ..endStroke();
    expect(controller.canUndo, isTrue);

    await controller.load(solidPng(30, 20, red));
    expect(controller.value, ImageEditValue.empty);
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);
    expect(controller.hasChanges, isFalse);
    expect(controller.originalSize, const Size(30, 20));
  });

  test('loading the same bytes again does nothing', () async {
    final controller = await loadedController();
    controller.rotateRight();
    final count = notificationsDuring(
      controller,
      () => controller.load(sourcePng),
    );
    expect(count, 0);
    expect(controller.value.quarterTurns, 1);
  });

  test('a newer load wins over an older one', () async {
    final controller = ChatImageEditorController();
    addTearDown(controller.dispose);
    final first = controller.load(sourcePng);
    final second = controller.load(solidPng(10, 10, blue));
    await Future.wait(<Future<void>>[first, second]);
    expect(controller.originalSize, const Size(10, 10));
    expect(controller.loadStatus, ImageLoadStatus.ready);
  });

  test('disposing during a load is safe', () async {
    final controller = ChatImageEditorController();
    final future = controller.load(sourcePng);
    controller.dispose();
    await future;
  });

  test('config setter clamps the stroke width and notifies once', () async {
    final controller = await loadedController();
    controller.setStrokeWidth(0.03);
    final count = notificationsDuring(controller, () {
      controller.config = const ChatImageEditorConfig(
        minStrokeWidth: 0.001,
        maxStrokeWidth: 0.01,
      );
    });
    expect(count, 1);
    expect(controller.strokeWidth, 0.01);
  });

  test('applyDefaultColors only fills colors nobody chose', () async {
    final controller = await loadedController();
    const themeDraw = Color(0xFF123456);
    const themeText = Color(0xFF654321);
    final count = notificationsDuring(
      controller,
      () => controller.applyDefaultColors(
        drawColor: themeDraw,
        textColor: themeText,
      ),
    );
    expect(count, 1);
    expect(controller.drawColor, themeDraw);
    expect(controller.textColor, themeText);

    controller.setDrawColor(const Color(0xFFFF0000));
    controller.applyDefaultColors(
      drawColor: const Color(0xFF00FF00),
      textColor: const Color(0xFF0000FF),
    );
    expect(controller.drawColor, const Color(0xFFFF0000));
    expect(controller.textColor, const Color(0xFF0000FF));
  });
}
