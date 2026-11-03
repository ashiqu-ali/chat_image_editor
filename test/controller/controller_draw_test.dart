import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import '../core/test_utils.dart';
import 'controller_helpers.dart';

void main() {
  test('strokes use the current shape, color and width', () async {
    final controller = await loadedController();
    controller
      ..setShapeType(ShapeType.arrow)
      ..setDrawColor(const Color(0xFF00FF00))
      ..setStrokeWidth(0.02)
      ..startStroke(const Offset(0.1, 0.1));
    final draft = controller.draftStroke!;
    expect(draft.type, ShapeType.arrow);
    expect(draft.color, const Color(0xFF00FF00));
    expect(draft.width, 0.02);
  });

  test('points are stored in original space', () async {
    final controller = await loadedController(
      initialValue: const ImageEditValue(quarterTurns: 1),
    );
    controller.startStroke(Offset.zero);
    // Turned clockwise, the view's top-left is the original bottom-left.
    expect(
      controller.draftStroke!.points.single,
      offsetCloseTo(const Offset(0, 1)),
    );

    final cropped = await loadedController(
      initialValue: const ImageEditValue(
        flipX: true,
        crop: Rect.fromLTRB(0.5, 0.5, 1, 1),
      ),
    );
    cropped.startStroke(const Offset(0.5, 0.5));
    expect(
      cropped.draftStroke!.points.single,
      offsetCloseTo(
        ImageGeometry.viewToOriginal(
          const Offset(0.5, 0.5),
          sourceSize,
          cropped.value,
        ),
      ),
    );
    expect(
      cropped.draftStroke!.points.single,
      offsetCloseTo(const Offset(0.25, 0.75)),
    );
  });

  test('freehand appends points and skips near-duplicates', () async {
    final controller = await loadedController();
    controller.startStroke(const Offset(0.1, 0.1));
    expect(
      notificationsDuring(
        controller,
        () => controller.updateStroke(const Offset(0.2, 0.2)),
      ),
      1,
    );
    expect(
      notificationsDuring(
        controller,
        () => controller.updateStroke(const Offset(0.2001, 0.2)),
      ),
      0,
    );
    controller.updateStroke(const Offset(0.3, 0.2));
    expect(controller.draftStroke!.points, hasLength(3));
  });

  test('other shapes keep only the first and last point', () async {
    final controller = await loadedController();
    controller
      ..setShapeType(ShapeType.rectangle)
      ..startStroke(const Offset(0.1, 0.1))
      ..updateStroke(const Offset(0.3, 0.3))
      ..updateStroke(const Offset(0.6, 0.4));
    expect(controller.draftStroke!.points, <Offset>[
      const Offset(0.1, 0.1),
      const Offset(0.6, 0.4),
    ]);
  });

  test('endStroke commits one history entry', () async {
    final controller = await loadedController();
    controller
      ..startStroke(const Offset(0.1, 0.1))
      ..updateStroke(const Offset(0.4, 0.4));
    expect(notificationsDuring(controller, controller.endStroke), 1);
    expect(controller.draftStroke, isNull);
    expect(controller.value.strokes, hasLength(1));
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.value.strokes, isEmpty);
    controller.redo();
    expect(controller.value.strokes, hasLength(1));
  });

  test('a freehand tap commits a dot', () async {
    final controller = await loadedController();
    controller
      ..startStroke(const Offset(0.5, 0.5))
      ..updateStroke(const Offset(0.501, 0.5))
      ..endStroke();
    expect(controller.value.strokes.single.points, hasLength(1));
    expect(controller.canUndo, isTrue);
  });

  test('a shape tap is dropped without history', () async {
    final controller = await loadedController();
    for (final type in <ShapeType>[
      ShapeType.line,
      ShapeType.rectangle,
      ShapeType.circle,
      ShapeType.arrow,
    ]) {
      controller
        ..setShapeType(type)
        ..startStroke(const Offset(0.5, 0.5));
      expect(notificationsDuring(controller, controller.endStroke), 1);
      expect(controller.draftStroke, isNull);
    }
    expect(controller.value.strokes, isEmpty);
    expect(controller.canUndo, isFalse);
  });

  test('cancelStroke drops the draft without history', () async {
    final controller = await loadedController();
    controller
      ..startStroke(const Offset(0.1, 0.1))
      ..updateStroke(const Offset(0.5, 0.5));
    expect(notificationsDuring(controller, controller.cancelStroke), 1);
    expect(controller.draftStroke, isNull);
    expect(controller.value.strokes, isEmpty);
    expect(controller.canUndo, isFalse);
    expect(notificationsDuring(controller, controller.cancelStroke), 0);
  });

  test('stroke width is clamped to the config limits', () async {
    final controller = await loadedController();
    controller.setStrokeWidth(1);
    expect(controller.strokeWidth, controller.config.maxStrokeWidth);
    controller.setStrokeWidth(0);
    expect(controller.strokeWidth, controller.config.minStrokeWidth);
  });

  group('config.shapes', () {
    test('a single offered shape is the one drawn', () async {
      final controller = await loadedController(
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.arrow],
        ),
      );
      expect(controller.shapeType, ShapeType.arrow);
      controller
        ..selectTool(EditorTool.draw)
        ..startStroke(const Offset(0.2, 0.2))
        ..updateStroke(const Offset(0.8, 0.7))
        ..endStroke();
      expect(controller.value.strokes.single.type, ShapeType.arrow);
    });

    test('starts on the first offered shape without freehand', () async {
      final controller = await loadedController(
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.line, ShapeType.arrow],
        ),
      );
      expect(controller.shapeType, ShapeType.line);
    });

    test('keeps freehand first when it is offered', () async {
      final controller = await loadedController(
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.arrow, ShapeType.freehand],
        ),
      );
      expect(controller.shapeType, ShapeType.freehand);
    });

    test('setShapeType ignores shapes that are not offered', () async {
      final controller = await loadedController(
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.line, ShapeType.arrow],
        ),
      );
      expect(
        notificationsDuring(
          controller,
          () => controller.setShapeType(ShapeType.circle),
        ),
        0,
      );
      expect(controller.shapeType, ShapeType.line);
      controller.setShapeType(ShapeType.arrow);
      expect(controller.shapeType, ShapeType.arrow);
    });

    test('an empty list allows any shape', () async {
      final controller = await loadedController(
        config: const ChatImageEditorConfig(shapes: <ShapeType>[]),
      );
      expect(controller.shapeType, ShapeType.freehand);
      controller.setShapeType(ShapeType.circle);
      expect(controller.shapeType, ShapeType.circle);
    });

    test('a new config moves to an offered shape', () async {
      final controller = await loadedController();
      controller.setShapeType(ShapeType.circle);
      expect(
        notificationsDuring(controller, () {
          controller.config = const ChatImageEditorConfig(
            shapes: <ShapeType>[ShapeType.rectangle, ShapeType.arrow],
          );
        }),
        1,
      );
      expect(controller.shapeType, ShapeType.rectangle);

      // A config that still offers the current shape keeps it.
      controller
        ..setShapeType(ShapeType.arrow)
        ..config = const ChatImageEditorConfig();
      expect(controller.shapeType, ShapeType.arrow);
    });
  });

  test('setters notify once and ignore unchanged values', () async {
    final controller = await loadedController();
    expect(
      notificationsDuring(
        controller,
        () => controller.setShapeType(ShapeType.circle),
      ),
      1,
    );
    expect(
      notificationsDuring(
        controller,
        () => controller.setShapeType(ShapeType.circle),
      ),
      0,
    );
    expect(
      notificationsDuring(
        controller,
        () => controller.setDrawColor(const Color(0xFF010203)),
      ),
      1,
    );
    expect(
      notificationsDuring(controller, () => controller.setStrokeWidth(0.01)),
      1,
    );
    expect(
      notificationsDuring(
        controller,
        () => controller.startStroke(const Offset(0.2, 0.2)),
      ),
      1,
    );
  });

  test('ids are unique, including against the initial value', () async {
    final controller = await loadedController(
      initialValue: const ImageEditValue(
        strokes: <Stroke>[
          Stroke(
            id: 'stroke-1',
            type: ShapeType.line,
            points: <Offset>[Offset.zero, Offset(1, 1)],
            color: Color(0xFF000000),
            width: 0.01,
          ),
        ],
      ),
    );
    final ids = <String>{'stroke-1'};
    for (var i = 0; i < 3; i++) {
      controller
        ..startStroke(Offset(0.1 * i, 0.1))
        ..updateStroke(Offset(0.1 * i + 0.3, 0.5))
        ..endStroke();
    }
    ids.addAll(controller.value.strokes.map((Stroke s) => s.id));
    expect(ids, hasLength(4));
  });
}
