import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_helpers.dart';

void main() {
  test('selectTool opens and toggles tools, notifying once', () async {
    final controller = await loadedController();
    for (final tool in <EditorTool>[
      EditorTool.draw,
      EditorTool.compress,
      EditorTool.crop,
      EditorTool.text,
    ]) {
      expect(
        notificationsDuring(controller, () => controller.selectTool(tool)),
        1,
        reason: 'open $tool',
      );
      expect(controller.activeTool, tool);
    }
    expect(
      notificationsDuring(
        controller,
        () => controller.selectTool(EditorTool.text),
      ),
      1,
    );
    expect(controller.activeTool, EditorTool.none);
  });

  test('closeTool and selectTool(none) close; no-ops stay quiet', () async {
    final controller = await loadedController();
    controller.selectTool(EditorTool.draw);
    expect(notificationsDuring(controller, controller.closeTool), 1);
    expect(controller.activeTool, EditorTool.none);
    expect(notificationsDuring(controller, controller.closeTool), 0);

    controller.selectTool(EditorTool.compress);
    controller.selectTool(EditorTool.none);
    expect(controller.activeTool, EditorTool.none);
    expect(
      notificationsDuring(
        controller,
        () => controller.selectTool(EditorTool.none),
      ),
      0,
    );
  });

  test('switching tools finishes text entry', () async {
    final controller = await loadedController();
    controller
      ..selectTool(EditorTool.text)
      ..updateEditingText('kept')
      ..selectTool(EditorTool.draw);
    expect(controller.activeTool, EditorTool.draw);
    expect(controller.editingTextId, isNull);
    expect(controller.value.texts.single.text, 'kept');

    controller
      ..selectTool(EditorTool.text)
      ..selectTool(EditorTool.crop);
    expect(controller.value.texts, hasLength(1), reason: 'empty dropped');
  });

  test('switching tools drops a draft stroke', () async {
    final controller = await loadedController();
    controller
      ..selectTool(EditorTool.draw)
      ..startStroke(const Offset(0.1, 0.1))
      ..selectTool(EditorTool.compress);
    expect(controller.draftStroke, isNull);
    expect(controller.value.strokes, isEmpty);
  });

  test('addText while drawing switches to text entry', () async {
    final controller = await loadedController();
    controller.selectTool(EditorTool.draw);
    final id = controller.addText();
    expect(controller.activeTool, EditorTool.text);
    expect(controller.editingTextId, id);
  });
}
