import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/test_utils.dart';
import 'controller_helpers.dart';

void main() {
  group('text entry', () {
    test('selecting the text tool adds a centered layer in entry', () async {
      final controller = await loadedController();
      final count = notificationsDuring(
        controller,
        () => controller.selectTool(EditorTool.text),
      );
      expect(count, 1);
      expect(controller.activeTool, EditorTool.text);
      final layer = controller.editingText!;
      expect(controller.editingTextId, layer.id);
      expect(layer.text, isEmpty);
      expect(layer.position, offsetCloseTo(const Offset(0.5, 0.5)));
      expect(layer.fontSize, controller.config.defaultFontSize);
      expect(layer.color, controller.textColor);
      expect(layer.background, controller.textBackground);
    });

    test('addText maps the view position to original space', () async {
      final controller = await loadedController(
        initialValue: const ImageEditValue(quarterTurns: 2),
      );
      final id = controller.addText(viewPosition: const Offset(0.2, 0.3));
      expect(controller.editingTextId, id);
      expect(controller.activeTool, EditorTool.text);
      expect(
        controller.textById(id)!.position,
        offsetCloseTo(const Offset(0.8, 0.7)),
      );
    });

    for (final cropRect in <Rect?>[
      null,
      const Rect.fromLTRB(0.1, 0.2, 0.8, 0.7),
    ]) {
      test('new text reads upright for every rotation and flip '
          '(crop: $cropRect)', () async {
        for (final value in allOrientations(crop: cropRect)) {
          final controller = await loadedController(initialValue: value);
          final layer = controller.textById(controller.addText())!;
          final x = screenDirection(
            layer,
            const Offset(1, 0),
            sourceSize,
            controller.value,
          );
          final y = screenDirection(
            layer,
            const Offset(0, 1),
            sourceSize,
            controller.value,
          );
          expect(
            x,
            offsetCloseTo(const Offset(1, 0), 1e-6),
            reason: describeTransform(value),
          );
          expect(
            y,
            offsetCloseTo(const Offset(0, 1), 1e-6),
            reason: describeTransform(value),
          );
        }
      });
    }

    test('typing, recoloring and finishing is one history entry', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('Hello')
        ..setTextColor(const Color(0xFF00FF00))
        ..setTextBackground(TextBackgroundStyle.solid);
      final layer = controller.editingText!;
      expect(layer.text, 'Hello');
      expect(layer.color, const Color(0xFF00FF00));
      expect(layer.background, TextBackgroundStyle.solid);

      expect(notificationsDuring(controller, controller.finishTextEditing), 1);
      expect(controller.editingTextId, isNull);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.texts, hasLength(1));

      controller.undo();
      expect(controller.value.texts, isEmpty);
      expect(controller.canUndo, isFalse);
      controller.redo();
      expect(controller.value.texts.single.text, 'Hello');
    });

    test('empty or blank layers are removed without history', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.text)
        ..finishTextEditing();
      expect(controller.value.texts, isEmpty);
      expect(controller.canUndo, isFalse);

      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('  \n ')
        ..finishTextEditing();
      expect(controller.value.texts, isEmpty);
      expect(controller.canUndo, isFalse);
    });

    test('toggling the text tool finishes the entry', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('Hi')
        ..selectTool(EditorTool.text);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.editingTextId, isNull);
      expect(controller.value.texts.single.text, 'Hi');
    });

    test('editing an existing layer records one entry', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('One')
        ..finishTextEditing();
      final id = controller.value.texts.single.id;

      controller.editText(id);
      expect(controller.editingTextId, id);
      expect(controller.activeTool, EditorTool.text);
      controller
        ..updateEditingText('Two')
        ..finishTextEditing();
      expect(controller.textById(id)!.text, 'Two');

      controller.undo();
      expect(controller.textById(id)!.text, 'One');
    });

    test('editing a layer picks up its style', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('A')
        ..setTextColor(const Color(0xFF0000FF))
        ..setTextBackground(TextBackgroundStyle.translucent)
        ..finishTextEditing()
        ..setTextColor(const Color(0xFFFFFFFF))
        ..setTextBackground(TextBackgroundStyle.none);
      controller.editText(controller.value.texts.single.id);
      expect(controller.textColor, const Color(0xFF0000FF));
      expect(controller.textBackground, TextBackgroundStyle.translucent);
    });

    test('clearing an existing layer deletes it as one entry', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('Bye')
        ..finishTextEditing();
      final id = controller.value.texts.single.id;
      controller
        ..editText(id)
        ..updateEditingText('')
        ..finishTextEditing();
      expect(controller.value.texts, isEmpty);
      controller.undo();
      expect(controller.textById(id)!.text, 'Bye');
    });

    test('cycleTextBackground wraps around', () async {
      final controller = await loadedController();
      expect(controller.textBackground, TextBackgroundStyle.none);
      controller.cycleTextBackground();
      expect(controller.textBackground, TextBackgroundStyle.solid);
      controller.cycleTextBackground();
      expect(controller.textBackground, TextBackgroundStyle.translucent);
      controller.cycleTextBackground();
      expect(controller.textBackground, TextBackgroundStyle.none);
    });

    test('text setters notify once', () async {
      final controller = await loadedController();
      controller.selectTool(EditorTool.text);
      expect(
        notificationsDuring(
          controller,
          () => controller.updateEditingText('x'),
        ),
        1,
      );
      expect(
        notificationsDuring(
          controller,
          () => controller.setTextColor(const Color(0xFF111111)),
        ),
        1,
      );
      expect(
        notificationsDuring(controller, controller.cycleTextBackground),
        1,
      );
      expect(
        notificationsDuring(
          controller,
          () => controller.updateEditingText('x'),
        ),
        0,
      );
    });
  });

  group('text gestures', () {
    Future<(ChatImageEditorController, String)> withLayer({
      ImageEditValue initialValue = ImageEditValue.empty,
      String text = 'Hi',
    }) async {
      final controller = await loadedController(initialValue: initialValue);
      final id = controller.addText();
      controller
        ..updateEditingText(text)
        ..finishTextEditing();
      return (controller, id);
    }

    test('startTextGesture brings the layer to the top', () async {
      final (controller, first) = await withLayer();
      final second = controller.addText();
      controller
        ..updateEditingText('Second')
        ..finishTextEditing();
      expect(controller.value.texts.last.id, second);

      expect(
        notificationsDuring(
          controller,
          () => controller.startTextGesture(first),
        ),
        1,
      );
      expect(controller.activeTextId, first);
      expect(controller.value.texts.last.id, first);
    });

    test('moves in view space, scales and rotates; one entry', () async {
      final (controller, id) = await withLayer(
        initialValue: const ImageEditValue(quarterTurns: 1),
      );
      final start = controller.textById(id)!;
      controller.startTextGesture(id);
      expect(
        notificationsDuring(
          controller,
          () => controller.updateTextGesture(
            viewTranslation: const Offset(0.1, -0.2),
            scale: 2,
            rotation: 0.3,
          ),
        ),
        1,
      );
      final moved = controller.textById(id)!;
      final startView = ImageGeometry.originalToView(
        start.position,
        sourceSize,
        controller.value,
      );
      expect(
        ImageGeometry.originalToView(
          moved.position,
          sourceSize,
          controller.value,
        ),
        offsetCloseTo(startView + const Offset(0.1, -0.2), 1e-9),
      );
      expect(moved.fontSize, closeTo(start.fontSize * 2, 1e-12));
      expect(moved.rotation, closeTo(start.rotation + 0.3, 1e-12));

      expect(notificationsDuring(controller, controller.endTextGesture), 1);
      expect(controller.activeTextId, isNull);
      controller.undo();
      expect(controller.textById(id), start);
    });

    test('updates are relative to the gesture start', () async {
      final (controller, id) = await withLayer();
      final start = controller.textById(id)!;
      controller
        ..startTextGesture(id)
        ..updateTextGesture(viewTranslation: const Offset(0.1, 0))
        ..updateTextGesture(viewTranslation: const Offset(0.2, 0));
      expect(
        controller.textById(id)!.position.dx,
        closeTo(start.position.dx + 0.2, 1e-9),
      );
    });

    test('scale is clamped to the config limits', () async {
      final (controller, id) = await withLayer();
      controller
        ..startTextGesture(id)
        ..updateTextGesture(scale: 100);
      expect(controller.textById(id)!.fontSize, controller.config.maxFontSize);
      controller.updateTextGesture(scale: 0.001);
      expect(controller.textById(id)!.fontSize, controller.config.minFontSize);
    });

    test('rotation turns clockwise on screen even when mirrored', () async {
      final (controller, id) = await withLayer(
        initialValue: const ImageEditValue(flipX: true),
      );
      final start = controller.textById(id)!;
      controller
        ..startTextGesture(id)
        ..updateTextGesture(rotation: math.pi / 2);
      final turned = controller.textById(id)!;
      // Upright text turned a quarter clockwise on screen: its x axis
      // points down.
      expect(
        screenDirection(
          turned,
          const Offset(1, 0),
          sourceSize,
          controller.value,
        ),
        offsetCloseTo(const Offset(0, 1), 1e-6),
      );
      expect(turned.rotation, closeTo(start.rotation - math.pi / 2, 1e-12));
    });

    test('a tap brings the layer up without an undo step', () async {
      final (controller, first) = await withLayer();
      controller.addText();
      controller
        ..updateEditingText('Second')
        ..finishTextEditing()
        ..startTextGesture(first)
        ..endTextGesture();
      expect(controller.value.texts.last.id, first);
      controller.undo();
      // The undo removed the second layer, not the reorder.
      expect(controller.value.texts.single.id, first);
    });

    test(
      'a tap reorders the recorded entry without baking in live state',
      () async {
        final (controller, first) = await withLayer();
        controller.addText();
        controller
          ..updateEditingText('Second')
          ..finishTextEditing()
          ..selectTool(EditorTool.compress)
          // Live, not yet committed.
          ..setQuality(40)
          ..startTextGesture(first)
          ..endTextGesture();
        expect(controller.value.texts.last.id, first);
        expect(controller.value.quality, 40);

        // The quality change is still pending, so it records its own entry.
        expect(notificationsDuring(controller, controller.commitQuality), 1);
        controller.undo();
        expect(controller.value.quality, isNull);
        expect(controller.value.texts, hasLength(2));
        expect(controller.value.texts.last.id, first);
      },
    );

    test('dropping on the delete target deletes as one entry', () async {
      final (controller, id) = await withLayer();
      controller.startTextGesture(id);
      expect(
        notificationsDuring(
          controller,
          () => controller.setOverDeleteTarget(true),
        ),
        1,
      );
      expect(controller.isOverDeleteTarget, isTrue);
      expect(
        notificationsDuring(
          controller,
          () => controller.setOverDeleteTarget(true),
        ),
        0,
      );
      controller.endTextGesture();
      expect(controller.textById(id), isNull);
      expect(controller.isOverDeleteTarget, isFalse);
      controller.undo();
      expect(controller.textById(id), isNotNull);
    });

    test('leaving the delete target keeps the layer', () async {
      final (controller, id) = await withLayer();
      controller
        ..startTextGesture(id)
        ..setOverDeleteTarget(true)
        ..setOverDeleteTarget(false)
        ..endTextGesture();
      expect(controller.textById(id), isNotNull);
    });

    test('a layer dragged off the image is pulled back to its edge', () async {
      final (controller, id) = await withLayer();
      controller
        ..startTextGesture(id)
        ..updateTextGesture(viewTranslation: const Offset(2, 0))
        ..endTextGesture();
      final view = ImageGeometry.originalToView(
        controller.textById(id)!.position,
        sourceSize,
        controller.value,
      );
      expect(view.dx, closeTo(1, 1e-9));
      expect(view.dy, closeTo(0.5, 1e-9));
    });

    test('deleteText removes a layer as one entry', () async {
      final (controller, id) = await withLayer();
      expect(
        notificationsDuring(controller, () => controller.deleteText(id)),
        1,
      );
      expect(controller.textById(id), isNull);
      controller.undo();
      expect(controller.textById(id), isNotNull);
      controller.redo();
      expect(controller.textById(id), isNull);
    });

    test('deleting the layer in entry closes the entry', () async {
      final controller = await loadedController();
      final id = controller.addText();
      controller.deleteText(id);
      expect(controller.editingTextId, isNull);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.canUndo, isFalse);
    });

    test('gesture calls without an active layer do nothing', () async {
      final controller = await loadedController();
      expect(
        notificationsDuring(controller, () {
          controller
            ..updateTextGesture(scale: 2)
            ..setOverDeleteTarget(true)
            ..endTextGesture()
            ..startTextGesture('missing');
        }),
        0,
      );
    });
  });
}
