import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/test_utils.dart';
import 'controller_helpers.dart';

void main() {
  group('crop session', () {
    test('changes are live and confirm records one entry', () async {
      final controller = await loadedController();
      controller.selectTool(EditorTool.crop);
      expect(controller.activeTool, EditorTool.crop);
      controller
        ..rotateRight()
        ..flipHorizontal()
        ..setCrop(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9));
      expect(controller.value.quarterTurns, 1);
      expect(controller.value.crop, isNotNull);
      expect(controller.canUndo, isFalse);

      expect(notificationsDuring(controller, controller.confirmCrop), 1);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.canUndo, isTrue);
      final confirmed = controller.value;

      controller.undo();
      expect(controller.value, ImageEditValue.empty);
      controller.redo();
      expect(controller.value, confirmed);
    });

    test('cancelCrop restores the state from before the session', () async {
      final controller = await loadedController(
        initialValue: const ImageEditValue(quarterTurns: 3),
      );
      controller
        ..selectTool(EditorTool.crop)
        ..rotateLeft()
        ..setCropAspectRatio(1);
      expect(notificationsDuring(controller, controller.cancelCrop), 1);
      expect(controller.value, const ImageEditValue(quarterTurns: 3));
      expect(controller.cropAspectRatio, isNull);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.canUndo, isFalse);
    });

    for (final exit in <String, void Function(ChatImageEditorController)>{
      'closeTool': (ChatImageEditorController c) => c.closeTool(),
      'selecting crop again': (ChatImageEditorController c) =>
          c.selectTool(EditorTool.crop),
      'selecting another tool': (ChatImageEditorController c) =>
          c.selectTool(EditorTool.draw),
    }.entries) {
      test('${exit.key} cancels the session', () async {
        final controller = await loadedController();
        controller
          ..selectTool(EditorTool.crop)
          ..rotateRight()
          ..setCrop(const Rect.fromLTRB(0, 0, 0.5, 0.5));
        expect(
          notificationsDuring(controller, () => exit.value(controller)),
          1,
        );
        expect(controller.value, ImageEditValue.empty);
        expect(controller.canUndo, isFalse);
      });
    }

    test('undo cancels the session and steps back', () async {
      final controller = await loadedController();
      controller
        ..startStroke(const Offset(0.1, 0.1))
        ..updateStroke(const Offset(0.6, 0.6))
        ..endStroke()
        ..selectTool(EditorTool.crop)
        ..rotateRight();
      expect(notificationsDuring(controller, controller.undo), 1);
      expect(controller.value, ImageEditValue.empty);
      expect(controller.activeTool, EditorTool.none);
    });

    group('actions that record history cancel the session first', () {
      test('drawing a stroke', () async {
        final controller = await loadedController();
        controller
          ..selectTool(EditorTool.crop)
          ..rotateRight()
          ..startStroke(const Offset(0.1, 0.1))
          ..updateStroke(const Offset(0.6, 0.6))
          ..endStroke();
        expect(controller.activeTool, EditorTool.none);
        expect(controller.value.quarterTurns, 0);
        expect(controller.value.strokes, hasLength(1));
        final drawn = controller.value;

        expect(notificationsDuring(controller, controller.cancelCrop), 0);
        expect(controller.value, drawn);

        controller.undo();
        expect(controller.value, ImageEditValue.empty);
        expect(controller.canUndo, isFalse);
        controller.redo();
        expect(controller.value, drawn);
      });

      test('a text gesture without movement', () async {
        final controller = await loadedController();
        final id = controller.addText();
        controller
          ..updateEditingText('Hi')
          ..finishTextEditing();
        final withText = controller.value;

        controller
          ..selectTool(EditorTool.crop)
          ..flipHorizontal()
          ..startTextGesture(id)
          ..endTextGesture()
          ..cancelCrop();
        expect(controller.value, withText);
        expect(controller.value.flipX, isFalse);
        expect(controller.hasChanges, isTrue);

        controller.undo();
        expect(controller.value, ImageEditValue.empty);
        expect(controller.canUndo, isFalse);
        controller.redo();
        expect(controller.value, withText);
      });

      test('deleting a text layer', () async {
        final controller = await loadedController();
        final id = controller.addText();
        controller
          ..updateEditingText('Hi')
          ..finishTextEditing();
        final withText = controller.value;

        controller.selectTool(EditorTool.crop);
        controller.rotateRight();
        expect(
          notificationsDuring(controller, () => controller.deleteText(id)),
          1,
        );
        expect(controller.activeTool, EditorTool.none);
        controller.cancelCrop();
        expect(controller.value, ImageEditValue.empty);

        controller.undo();
        expect(controller.value, withText);
        expect(controller.value.quarterTurns, 0);
        controller.undo();
        expect(controller.value, ImageEditValue.empty);
        expect(controller.canUndo, isFalse);
      });

      test('commitQuality leaves the session to confirm or cancel', () async {
        final controller = await loadedController();
        controller
          ..selectTool(EditorTool.crop)
          ..rotateRight()
          ..setQuality(50);
        expect(notificationsDuring(controller, controller.commitQuality), 0);
        expect(controller.canUndo, isFalse);

        controller.cancelCrop();
        expect(controller.value, ImageEditValue.empty);
        expect(controller.canUndo, isFalse);
        controller.undo();
        expect(controller.value, ImageEditValue.empty);
      });
    });

    test('confirming an unchanged session records nothing', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.crop)
        ..confirmCrop();
      expect(controller.canUndo, isFalse);
      expect(notificationsDuring(controller, controller.confirmCrop), 0);
      expect(notificationsDuring(controller, controller.cancelCrop), 0);
    });

    test('every crop action notifies once', () async {
      final controller = await loadedController();
      controller.selectTool(EditorTool.crop);
      for (final action in <void Function()>[
        controller.rotateRight,
        controller.rotateLeft,
        controller.flipHorizontal,
        controller.flipVertical,
        () => controller.setCrop(const Rect.fromLTRB(0.2, 0.2, 0.8, 0.8)),
        () => controller.setCropAspectRatio(1),
        controller.resetCrop,
      ]) {
        expect(notificationsDuring(controller, action), 1);
      }
    });
  });

  group('rotate and flip', () {
    const crop = Rect.fromLTRB(0.1, 0.2, 0.6, 0.9);

    test('the crop turns with the image', () async {
      final controller = await loadedController(
        initialValue: const ImageEditValue(crop: crop, flipY: true),
      );
      controller.selectTool(EditorTool.crop);
      final before = controller.value;
      controller.rotateRight();
      final after = controller.value;
      expect(after.quarterTurns, 1);
      for (final p in const <Offset>[
        Offset.zero,
        Offset(1, 0),
        Offset(0.4, 0.7),
      ]) {
        expect(
          ImageGeometry.viewToOriginal(
            Offset(1 - p.dy, p.dx),
            sourceSize,
            after,
          ),
          offsetCloseTo(ImageGeometry.viewToOriginal(p, sourceSize, before)),
        );
      }

      controller.rotateLeft();
      expect(controller.value, before);
    });

    test('four turns return to the start', () async {
      final controller = await loadedController(
        initialValue: const ImageEditValue(crop: crop),
      );
      controller.selectTool(EditorTool.crop);
      for (var i = 0; i < 4; i++) {
        controller.rotateLeft();
      }
      expect(controller.value, const ImageEditValue(crop: crop));
    });

    for (final turns in <int>[0, 1, 2, 3]) {
      test('flips mirror what the user sees (turns: $turns)', () async {
        final controller = await loadedController(
          initialValue: ImageEditValue(quarterTurns: turns, crop: crop),
        );
        controller.selectTool(EditorTool.crop);
        final before = controller.value;

        controller.flipHorizontal();
        final mirrored = controller.value;
        for (final p in const <Offset>[Offset.zero, Offset(0.3, 0.8)]) {
          expect(
            ImageGeometry.viewToOriginal(p, sourceSize, mirrored),
            offsetCloseTo(
              ImageGeometry.viewToOriginal(
                Offset(1 - p.dx, p.dy),
                sourceSize,
                before,
              ),
            ),
          );
        }
        controller.flipHorizontal();
        expect(controller.value, before);

        controller.flipVertical();
        final flipped = controller.value;
        for (final p in const <Offset>[Offset.zero, Offset(0.3, 0.8)]) {
          expect(
            ImageGeometry.viewToOriginal(p, sourceSize, flipped),
            offsetCloseTo(
              ImageGeometry.viewToOriginal(
                Offset(p.dx, 1 - p.dy),
                sourceSize,
                before,
              ),
            ),
          );
        }
      });
    }

    test('rotating inverts the aspect lock', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.crop)
        ..setCropAspectRatio(16 / 9)
        ..rotateRight();
      expect(controller.cropAspectRatio, closeTo(9 / 16, 1e-12));
    });

    test('outside a crop session each change is its own entry', () async {
      final controller = await loadedController();
      expect(notificationsDuring(controller, controller.rotateRight), 1);
      controller.flipVertical();
      expect(controller.value.quarterTurns, 1);
      controller.undo();
      expect(controller.value, const ImageEditValue(quarterTurns: 1));
      controller.undo();
      expect(controller.value, ImageEditValue.empty);
    });
  });

  group('setCrop', () {
    test('clamps the rect inside the image', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.crop)
        ..setCrop(const Rect.fromLTRB(-0.5, 0.25, 0.5, 2));
      expect(
        controller.value.crop,
        rectCloseTo(const Rect.fromLTRB(0, 0.25, 0.5, 1)),
      );
    });

    test('keeps a minimum size', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.crop)
        ..setCrop(const Rect.fromLTRB(0.5, 0.5, 0.5001, 0.5001));
      final crop = controller.value.crop!;
      expect(crop.width, greaterThan(0.01));
      expect(crop.height, greaterThan(0.01));
    });

    test('the whole image and null clear the crop', () async {
      final controller = await loadedController(
        initialValue: const ImageEditValue(crop: Rect.fromLTRB(0, 0, 0.5, 0.5)),
      );
      controller
        ..selectTool(EditorTool.crop)
        ..setCrop(const Rect.fromLTRB(0, 0, 1, 1));
      expect(controller.value.crop, isNull);
      controller
        ..setCrop(const Rect.fromLTRB(0, 0, 0.5, 0.5))
        ..setCrop(null);
      expect(controller.value.crop, isNull);
    });

    test('follows the aspect lock on screen', () async {
      final controller = await loadedController(
        initialValue: const ImageEditValue(quarterTurns: 1),
      );
      controller
        ..selectTool(EditorTool.crop)
        ..setCropAspectRatio(1)
        ..setCrop(const Rect.fromLTRB(0.1, 0.1, 0.9, 0.5));
      final output = ImageGeometry.outputSize(sourceSize, controller.value);
      expect(output.width / output.height, closeTo(1, 1e-6));
    });

    test('ignores non-finite rects', () async {
      final controller = await loadedController();
      controller.selectTool(EditorTool.crop);
      expect(
        notificationsDuring(
          controller,
          () =>
              controller.setCrop(const Rect.fromLTRB(0, 0, double.infinity, 1)),
        ),
        0,
      );
    });
  });

  group('setCropAspectRatio', () {
    test('fits the largest centered rect with that ratio', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.crop)
        ..setCropAspectRatio(1);
      expect(controller.cropAspectRatio, 1);
      final output = ImageGeometry.outputSize(sourceSize, controller.value);
      // 80×60 → the largest square is 60×60, centered.
      expect(output.width, closeTo(60, 1e-6));
      expect(output.height, closeTo(60, 1e-6));
      expect(
        controller.value.crop,
        rectCloseTo(const Rect.fromLTRB(0.125, 0, 0.875, 1)),
      );
    });

    test('fits inside the current crop', () async {
      final controller = await loadedController(
        initialValue: const ImageEditValue(crop: Rect.fromLTRB(0, 0, 0.5, 1)),
      );
      controller
        ..selectTool(EditorTool.crop)
        ..setCropAspectRatio(2);
      final output = ImageGeometry.outputSize(sourceSize, controller.value);
      expect(output.width / output.height, closeTo(2, 1e-6));
      expect(output.width, closeTo(40, 1e-6));
    });

    test('null unlocks and keeps the crop', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.crop)
        ..setCropAspectRatio(1);
      final crop = controller.value.crop;
      controller.setCropAspectRatio(null);
      expect(controller.cropAspectRatio, isNull);
      expect(controller.value.crop, crop);
    });

    test('a stale lock is dropped when a session starts', () async {
      final controller = await loadedController();
      controller
        ..selectTool(EditorTool.crop)
        ..setCropAspectRatio(1)
        ..confirmCrop()
        ..undo()
        ..selectTool(EditorTool.crop);
      expect(controller.cropAspectRatio, isNull);
    });
  });

  test('resetCrop clears crop, rotation, flips and the lock', () async {
    final controller = await loadedController(
      initialValue: const ImageEditValue(
        quarterTurns: 2,
        flipX: true,
        crop: Rect.fromLTRB(0.1, 0.1, 0.5, 0.5),
      ),
    );
    controller
      ..selectTool(EditorTool.crop)
      ..setCropAspectRatio(1)
      ..resetCrop();
    expect(controller.value, ImageEditValue.empty);
    expect(controller.cropAspectRatio, isNull);
    controller.confirmCrop();
    controller.undo();
    expect(controller.value.quarterTurns, 2);
  });
}
