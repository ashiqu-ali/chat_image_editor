import 'dart:math' as math;

import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/render/text_layer_colors.dart';
import 'package:chat_image_editor/src/ui/caption_bar.dart';
import 'package:chat_image_editor/src/ui/color_strip.dart';
import 'package:chat_image_editor/src/ui/delete_target.dart';
import 'package:chat_image_editor/src/ui/editor_canvas.dart';
import 'package:chat_image_editor/src/ui/editor_icon_button.dart';
import 'package:chat_image_editor/src/ui/editor_layout.dart';
import 'package:chat_image_editor/src/ui/editor_pill_button.dart';
import 'package:chat_image_editor/src/ui/text_entry_overlay.dart';
import 'package:chat_image_editor/src/ui/text_layer_gestures.dart';
import 'package:chat_image_editor/src/ui/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

/// The displayed image, in global coordinates.
Rect imageRectOf(WidgetTester tester, ChatImageEditorController controller) {
  final canvas = find.byType(EditorCanvas);
  return EditorLayout.imageRect(
    tester.getSize(canvas),
    EditorLayout.canvasPadding(tester.element(canvas), EditorTool.none),
    EditorLayout.paintedOutputSize(controller),
  ).shift(tester.getTopLeft(canvas));
}

/// The center guides the canvas currently paints.
CenterGuides guidesOf(WidgetTester tester) {
  final painters = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((paint) => paint.painter)
      .whereType<GuideLinesPainter>();
  return painters.single.guides.value;
}

/// Commits a text layer reading [text] at [viewPosition] and returns it.
Future<TextLayer> addLayer(
  WidgetTester tester,
  ChatImageEditorController controller,
  String text, {
  Offset? viewPosition,
}) async {
  controller
    ..addText(viewPosition: viewPosition)
    ..updateEditingText(text)
    ..finishTextEditing();
  await tester.pumpAndSettle();
  return controller.value.texts.last;
}

/// Records light haptics until the test ends.
List<Object?> recordHaptics(WidgetTester tester) {
  final haptics = <Object?>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
    return null;
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return haptics;
}

/// Finds a widget of [type] inside the text entry overlay.
Finder inOverlay(Type type) {
  return find.descendant(
    of: find.byType(TextEntryOverlay),
    matching: find.byType(type),
  );
}

/// Whether the chrome holding a [type] widget is faded out.
bool chromeHidden(WidgetTester tester, Type type) {
  final faded = find.ancestor(
    of: find.byType(type),
    matching: find.byWidgetPredicate(
      (widget) => widget is AnimatedOpacity && widget.opacity == 0,
    ),
  );
  return faded.evaluate().isNotEmpty;
}

void main() {
  group('text mode', () {
    testWidgets('text: type, finish and keep the layer', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      expect(controller.editingTextId, isNotNull);
      expect(find.byTooltip('Text background'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      expect(controller.editingText?.text, 'Hello');

      await tester.tap(find.byTooltip('Text background'));
      await tester.pump();
      expect(
        controller.editingText?.background,
        isNot(TextBackgroundStyle.none),
      );

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.editingTextId, isNull);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.texts.single.text, 'Hello');
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('text: the entry is centered with Done left of the toggle', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      final screen = tester.getRect(find.byType(EditorCanvas));

      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      final layer = controller.editingText!;
      expect(layer.position, const Offset(0.5, 0.5));

      // Done pill at the top left, background toggle at the top right, in
      // one row of the top bar's height.
      final done = inOverlay(EditorPillButton);
      final toggle = find.ancestor(
        of: find.byTooltip('Text background'),
        matching: find.byType(EditorIconButton),
      );
      expect(tester.widget<EditorPillButton>(done).label, 'Done');
      final doneRect = tester.getRect(done);
      final toggleRect = tester.getRect(toggle);
      expect(doneRect.right, lessThan(toggleRect.left));
      expect(doneRect.left, lessThan(screen.center.dx));
      expect(toggleRect.right, greaterThan(screen.center.dx));
      expect(doneRect.center.dy, moreOrLessEquals(toggleRect.center.dy));
      expect(doneRect.bottom, lessThanOrEqualTo(EditorLayout.topBarHeight));
      expect(toggleRect.bottom, lessThanOrEqualTo(EditorLayout.topBarHeight));
      final row = find.ancestor(of: done, matching: find.byType(Row)).first;
      expect(
        find.descendant(of: row, matching: toggle),
        findsOneWidget,
        reason: 'Done and the toggle share the top bar row',
      );

      // The color slider sits on the right, below the top bar.
      final strip = tester.getRect(inOverlay(ColorStrip));
      expect(strip.left, greaterThan(screen.center.dx));
      expect(strip.top, greaterThanOrEqualTo(EditorLayout.topBarHeight));

      // A centered, multi-line, center-aligned field at the size the text
      // will have on the image.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, isNull);
      expect(field.textAlign, TextAlign.center);
      final box = tester.getRect(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(box.center.dx, moreOrLessEquals(screen.center.dx));
      expect(box.right, lessThan(strip.left));
      final image = imageRectOf(tester, controller);
      final displayScale =
          image.width / EditorLayout.paintedOutputSize(controller).width;
      expect(
        field.style!.fontSize,
        moreOrLessEquals(
          layer.fontSize * controller.originalSize.shortestSide * displayScale,
        ),
      );
    });

    testWidgets('text: typing previews the rendered colors', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      for (final background in TextBackgroundStyle.values) {
        controller.setTextBackground(background);
        await tester.pump();
        final layer = controller.editingText!;
        final style = tester.widget<TextField>(find.byType(TextField)).style!;
        expect(
          style.color,
          TextLayerColors.textColor(layer),
          reason: '$background',
        );
        // The rounded box behind the text, not a per-line highlight.
        expect(style.backgroundColor, isNull, reason: '$background');
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect(
          (box.decoration as BoxDecoration).color,
          TextLayerColors.boxColor(layer),
          reason: '$background',
        );
      }
    });

    testWidgets('text: a foreground paint in the text style previews', (
      tester,
    ) async {
      final paint = Paint()..color = const Color(0xFF00FF00);
      final controller = await pumpReadyEditor(
        tester,
        theme: ChatImageEditorThemeData(
          textLayerStyle: TextStyle(foreground: paint),
        ),
      );

      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Paint');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(controller.editingText?.text, 'Paint');
      final style = tester.widget<TextField>(find.byType(TextField)).style!;
      expect(style.foreground, same(paint));
      expect(style.color, isNull);
    });

    testWidgets('text: the background toggle cycles and shows its state', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      final toggle = find.ancestor(
        of: find.byTooltip('Text background'),
        matching: find.byType(EditorIconButton),
      );
      final theme = scopeOf(tester, toggle).theme;
      Color? iconColor() => IconTheme.of(
        tester.element(
          find.descendant(of: toggle, matching: find.byType(Icon)),
        ),
      ).color;

      expect(tester.widget<EditorIconButton>(toggle).active, isFalse);
      expect(iconColor(), theme.foregroundColor);
      for (final expected in <TextBackgroundStyle>[
        TextBackgroundStyle.solid,
        TextBackgroundStyle.translucent,
        TextBackgroundStyle.none,
      ]) {
        await tester.tap(toggle);
        await tester.pump();
        expect(controller.editingText!.background, expected);
        final on = expected != TextBackgroundStyle.none;
        expect(tester.widget<EditorIconButton>(toggle).active, on);
        expect(
          iconColor(),
          on ? theme.activeToolColor : theme.foregroundColor,
          reason: '$expected',
        );
      }
    });

    testWidgets('text: the color slider recolors the text live', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();

      final strip = inOverlay(ColorStrip);
      final palette = scopeOf(tester, strip).theme.palette;
      final rect = tester.getRect(strip);
      Color? fieldColor() =>
          tester.widget<TextField>(find.byType(TextField)).style!.color;
      expect(controller.editingText!.color, isNot(palette.last));

      await tester.tapAt(rect.bottomCenter - const Offset(0, 1));
      await tester.pump();
      expect(controller.editingText!.color, palette.last);
      expect(controller.textColor, palette.last);
      expect(fieldColor(), palette.last);
      expect(
        tester.widget<ColorStrip>(strip).selected,
        palette.last,
        reason: 'the thumb shows the text color',
      );

      // Dragging picks colors continuously.
      final gesture = await tester.startGesture(
        rect.bottomCenter - const Offset(0, 1),
      );
      await gesture.moveTo(rect.center);
      await tester.pump();
      final middle = controller.editingText!.color;
      expect(middle, isNot(palette.last));
      expect(middle, isNot(palette.first));
      expect(fieldColor(), middle);

      await gesture.moveTo(rect.topCenter + const Offset(0, 1));
      await tester.pump();
      expect(controller.editingText!.color, palette.first);
      expect(fieldColor(), palette.first);
      await gesture.up();
      await tester.pump();

      // Still typing: picking a color doesn't finish the entry.
      expect(controller.editingTextId, isNotNull);
    });

    testWidgets('text: tapping the dimmed area finishes', (tester) async {
      final controller = await pumpReadyEditor(tester);
      final screen = tester.getRect(find.byType(EditorCanvas));
      final dimmed = Offset(screen.width / 8, screen.height * 7 / 8);

      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      // Tapping the text's box focuses the field instead of finishing.
      final box = find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(DecoratedBox),
          )
          .first;
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(box) + const Offset(2, 2));
      await tester.pump();
      expect(controller.editingTextId, isNotNull);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode,
        isA<FocusNode>().having((node) => node.hasFocus, 'hasFocus', isTrue),
      );

      await tester.tapAt(dimmed);
      await tester.pumpAndSettle();
      expect(controller.editingTextId, isNull);
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.texts.single.text, 'Hello');
      expect(find.byType(TextEntryOverlay), findsNothing);

      // Finishing an empty entry the same way drops its layer.
      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      expect(controller.value.texts, hasLength(2));
      await tester.tapAt(dimmed);
      await tester.pumpAndSettle();
      expect(controller.editingTextId, isNull);
      expect(controller.value.texts.single.text, 'Hello');
    });

    testWidgets('text: drag a layer and drop it on the delete target', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('Hi')
        ..finishTextEditing();
      await tester.pumpAndSettle();
      final start = controller.value.texts.single.position;
      final image = imageRectOf(tester, controller);
      expect(chromeHidden(tester, EditorTopBar), isFalse);
      expect(chromeHidden(tester, EditorBottomBar), isFalse);

      final gesture = await tester.startGesture(image.center);
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(controller.activeTextId, isNotNull);
      expect(find.byType(DeleteTarget), findsOneWidget);
      expect(controller.value.texts.single.position, isNot(start));
      expect(
        tester.widget<DeleteTarget>(find.byType(DeleteTarget)).active,
        isFalse,
      );
      expect(chromeHidden(tester, EditorTopBar), isTrue);
      expect(chromeHidden(tester, EditorBottomBar), isTrue);

      await gesture.moveTo(tester.getCenter(find.byType(DeleteTarget)));
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      expect(controller.isOverDeleteTarget, isTrue);
      // The target grows and tints; guides hide over it.
      final target = find.byType(DeleteTarget);
      expect(tester.widget<DeleteTarget>(target).active, isTrue);
      expect(
        tester
            .widget<AnimatedScale>(
              find.descendant(of: target, matching: find.byType(AnimatedScale)),
            )
            .scale,
        DeleteTarget.activeScale,
      );
      expect(guidesOf(tester), CenterGuides.none);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.activeTextId, isNull);
      expect(controller.value.texts, isEmpty);
      expect(find.byType(DeleteTarget), findsNothing);
      expect(chromeHidden(tester, EditorTopBar), isFalse);
      expect(chromeHidden(tester, EditorBottomBar), isFalse);
    });

    testWidgets('text: a drop away from the delete target keeps the layer', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      await addLayer(tester, controller, 'Keep');
      final image = imageRectOf(tester, controller);

      final gesture = await tester.startGesture(image.center);
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(DeleteTarget)));
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      expect(controller.isOverDeleteTarget, isTrue);

      // Dragging back out of the target cancels the delete.
      await gesture.moveTo(image.center + const Offset(60, -60));
      await tester.pump();
      expect(controller.isOverDeleteTarget, isFalse);
      expect(
        tester.widget<DeleteTarget>(find.byType(DeleteTarget)).active,
        isFalse,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      final layer = controller.value.texts.single;
      expect(layer.text, 'Keep');
      expect(layer.position.dx, moreOrLessEquals(0.5 + 60 / image.width));
      expect(layer.position.dy, moreOrLessEquals(0.5 - 60 / image.height));
    });

    testWidgets('text: center guides show while the layer is centered', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      final controller = await pumpReadyEditor(tester);
      await addLayer(
        tester,
        controller,
        'Hi',
        viewPosition: const Offset(0.3, 0.3),
      );
      final image = imageRectOf(tester, controller);
      Offset at(Offset view) =>
          image.topLeft + Offset(view.dx * image.width, view.dy * image.height);
      Offset position() => controller.value.texts.single.position;

      final gesture = await tester.startGesture(at(const Offset(0.3, 0.3)));
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(controller.activeTextId, isNotNull);
      expect(guidesOf(tester), CenterGuides.none);
      expect(haptics, isEmpty);

      // Right on the center: both guides and one haptic.
      await gesture.moveTo(image.center);
      await tester.pump();
      expect(
        guidesOf(tester),
        const CenterGuides(vertical: true, horizontal: true),
      );
      expect(position().dx, moreOrLessEquals(0.5));
      expect(position().dy, moreOrLessEquals(0.5));
      expect(haptics, hasLength(1));

      // Near the vertical center line: its guide stays, but the text follows
      // the finger exactly instead of snapping to the line.
      const near = Offset(TextLayerGestures.guideDistance - 2, 30);
      await gesture.moveTo(image.center + near);
      await tester.pump();
      expect(guidesOf(tester), const CenterGuides(vertical: true));
      expect(position().dx, moreOrLessEquals(0.5 + near.dx / image.width));
      expect(position().dy, moreOrLessEquals(0.5 + near.dy / image.height));
      expect(haptics, hasLength(1), reason: 'no haptic while still aligned');

      // Away from both lines, then back onto one: a new haptic.
      await gesture.moveTo(image.center + const Offset(60, 30));
      await tester.pump();
      expect(guidesOf(tester), CenterGuides.none);
      await gesture.moveTo(image.center + const Offset(0, 30));
      await tester.pump();
      expect(guidesOf(tester), const CenterGuides(vertical: true));
      expect(haptics, hasLength(2));

      await gesture.up();
      await tester.pump();
      expect(guidesOf(tester), CenterGuides.none);
      expect(controller.value.texts.single.text, 'Hi');
    });

    testWidgets('text: guides show without haptics when those are off', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(enableHaptics: false),
      );
      await addLayer(
        tester,
        controller,
        'Hi',
        viewPosition: const Offset(0.3, 0.3),
      );
      final image = imageRectOf(tester, controller);

      final gesture = await tester.startGesture(
        image.topLeft + Offset(image.width * 0.3, image.height * 0.3),
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveTo(image.center);
      await tester.pump();
      expect(
        guidesOf(tester),
        const CenterGuides(vertical: true, horizontal: true),
      );
      await gesture.up();
      await tester.pump();
      expect(haptics, isEmpty);
    });

    testWidgets('text: a second finger anywhere scales and rotates', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);
      final start = await addLayer(tester, controller, 'Hi');
      final image = imageRectOf(tester, controller);
      final center = image.center;

      final first = await tester.startGesture(center, pointer: 1);
      // The second finger lands well off the layer.
      final second = await tester.startGesture(
        center - const Offset(150, 0),
        pointer: 2,
      );
      final canvasOrigin = tester.getTopLeft(find.byType(EditorCanvas));
      expect(
        TextLayerGestures.hitTest(
          controller,
          center - const Offset(150, 0) - canvasOrigin,
          CanvasLayout(
            imageRect: image.shift(-canvasOrigin),
            outputSize: EditorLayout.paintedOutputSize(controller),
            originalSize: controller.originalSize,
            value: controller.value,
          ),
          scopeOf(tester, find.byType(EditorCanvas)).theme.textLayerStyle,
        ),
        isNull,
      );
      // Spread the fingers past the slop to start the pinch.
      await second.moveTo(center - const Offset(200, 0));
      await tester.pump();
      expect(controller.activeTextId, start.id);

      // A quarter turn clockwise while spreading to 1.4×.
      await second.moveTo(center - const Offset(0, 280));
      await tester.pump();
      final layer = controller.value.texts.single;
      expect(layer.fontSize, moreOrLessEquals(start.fontSize * 1.4));
      expect(layer.rotation - start.rotation, moreOrLessEquals(math.pi / 2));

      await second.up();
      await first.up();
      await tester.pumpAndSettle();
      expect(controller.activeTextId, isNull);
      expect(controller.value.texts.single.fontSize, layer.fontSize);
      expect(controller.canUndo, isTrue);
    });

    testWidgets('text: tapping a layer opens it for editing', (tester) async {
      final controller = await pumpReadyEditor(tester);
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('Edit me')
        ..finishTextEditing();
      await tester.pumpAndSettle();
      final id = controller.value.texts.single.id;

      final image = imageRectOf(tester, controller);
      await tester.tapAt(image.center);
      await tester.pump();

      expect(controller.editingTextId, id);
      expect(find.text('Edit me'), findsOneWidget);

      // Editing changes the same layer.
      await tester.enterText(find.byType(TextField), 'Edited');
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.editingTextId, isNull);
      final layer = controller.value.texts.single;
      expect(layer.id, id);
      expect(layer.text, 'Edited');
    });

    testWidgets('text: an empty layer is dropped', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      expect(controller.value.texts, isEmpty);
    });
  });
}
