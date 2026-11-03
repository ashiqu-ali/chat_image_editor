import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_helpers.dart';

void drawLine(ChatImageEditorController c, double y) {
  c
    ..startStroke(Offset(0.1, y))
    ..updateStroke(Offset(0.9, y))
    ..endStroke();
}

String addLayer(ChatImageEditorController c, String text) {
  final id = c.addText();
  c
    ..updateEditingText(text)
    ..finishTextEditing();
  return id;
}

void main() {
  test('undo and redo step through every action type', () async {
    // A non-empty start makes clearEdits a visible change.
    final controller = await loadedController(
      initialValue: const ImageEditValue(quality: 99),
    );
    final snapshots = <ImageEditValue>[controller.value];
    void record() => snapshots.add(controller.value);

    // Stroke.
    drawLine(controller, 0.2);
    record();
    // Text edit session.
    final id = addLayer(controller, 'Hello');
    record();
    // Text gesture.
    controller
      ..startTextGesture(id)
      ..updateTextGesture(viewTranslation: const Offset(0.1, 0.1), scale: 1.5)
      ..endTextGesture();
    record();
    // Confirmed crop session.
    controller
      ..selectTool(EditorTool.crop)
      ..rotateRight()
      ..setCrop(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9))
      ..confirmCrop();
    record();
    // Committed quality change.
    controller
      ..selectTool(EditorTool.compress)
      ..setQuality(40)
      ..setQuality(35)
      ..closeTool();
    record();
    // Deleted layer (drag to delete).
    controller
      ..startTextGesture(id)
      ..setOverDeleteTarget(true)
      ..endTextGesture();
    record();
    // Another layer, deleted directly.
    final other = addLayer(controller, 'Other');
    record();
    controller.deleteText(other);
    record();
    // Clear everything.
    controller.clearEdits();
    record();

    for (var i = 1; i < snapshots.length; i++) {
      expect(snapshots[i], isNot(snapshots[i - 1]), reason: 'action $i');
    }
    for (var i = snapshots.length - 2; i >= 0; i--) {
      expect(controller.canUndo, isTrue, reason: 'before undo to $i');
      expect(notificationsDuring(controller, controller.undo), 1);
      expect(controller.value, snapshots[i], reason: 'undo to $i');
    }
    expect(controller.canUndo, isFalse);
    for (var i = 1; i < snapshots.length; i++) {
      expect(controller.canRedo, isTrue, reason: 'before redo to $i');
      expect(notificationsDuring(controller, controller.redo), 1);
      expect(controller.value, snapshots[i], reason: 'redo to $i');
    }
    expect(controller.canRedo, isFalse);
  });

  test('a new action drops the redo entries', () async {
    final controller = await loadedController();
    drawLine(controller, 0.2);
    drawLine(controller, 0.4);
    controller.undo();
    expect(controller.canRedo, isTrue);
    drawLine(controller, 0.6);
    expect(controller.canRedo, isFalse);
    expect(controller.value.strokes, hasLength(2));
  });

  test('undo and redo with nothing to do do not notify', () async {
    final controller = await loadedController();
    expect(notificationsDuring(controller, controller.undo), 0);
    expect(notificationsDuring(controller, controller.redo), 0);
  });

  test('undo finishes text entry first', () async {
    final controller = await loadedController();
    drawLine(controller, 0.2);
    controller
      ..selectTool(EditorTool.text)
      ..updateEditingText('typed');
    expect(controller.canUndo, isTrue);
    controller.undo();
    // The typed text became an entry and was undone; the stroke stays.
    expect(controller.editingTextId, isNull);
    expect(controller.activeTool, EditorTool.none);
    expect(controller.value.texts, isEmpty);
    expect(controller.value.strokes, hasLength(1));
    controller.redo();
    expect(controller.value.texts.single.text, 'typed');
  });

  test('canUndo counts a pending text entry', () async {
    final controller = await loadedController();
    controller.selectTool(EditorTool.text);
    expect(controller.canUndo, isFalse);
    controller.updateEditingText('x');
    expect(controller.canUndo, isTrue);
  });

  test('canRedo is false while pending changes would replace it', () async {
    final controller = await loadedController();
    drawLine(controller, 0.2);
    controller.undo();
    expect(controller.canRedo, isTrue);
    controller
      ..selectTool(EditorTool.text)
      ..updateEditingText('x');
    expect(controller.canRedo, isFalse);
  });

  test('clearEdits is one undoable entry', () async {
    final controller = await loadedController(
      initialValue: const ImageEditValue(quarterTurns: 1, quality: 50),
    );
    drawLine(controller, 0.3);
    final before = controller.value;
    expect(notificationsDuring(controller, controller.clearEdits), 1);
    expect(controller.value, ImageEditValue.empty);
    controller.undo();
    expect(controller.value, before);
    expect(
      notificationsDuring(controller, () {
        controller
          ..clearEdits()
          ..clearEdits();
      }),
      1,
    );
  });

  test('hasChanges compares against the starting value', () async {
    final controller = await loadedController();
    expect(controller.hasChanges, isFalse);
    controller.selectTool(EditorTool.text);
    expect(controller.hasChanges, isFalse, reason: 'empty layer');
    controller.updateEditingText('x');
    expect(controller.hasChanges, isTrue);
    controller
      ..finishTextEditing()
      ..undo();
    expect(controller.hasChanges, isFalse);
    controller.rotateRight();
    expect(controller.hasChanges, isTrue);
  });
}
