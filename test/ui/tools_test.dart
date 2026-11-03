import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/render/text_layer_colors.dart';
import 'package:chat_image_editor/src/ui/crop_overlay.dart';
import 'package:chat_image_editor/src/ui/delete_target.dart';
import 'package:chat_image_editor/src/ui/editor_canvas.dart';
import 'package:chat_image_editor/src/ui/editor_icon_button.dart';
import 'package:chat_image_editor/src/ui/editor_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

void main() {
  group('tools', () {
    testWidgets('draw: shows controls and records a dragged stroke', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.draw);
      expect(find.byTooltip('Pen'), findsOneWidget);
      expect(find.byTooltip('Arrow'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      final center = tester.getCenter(find.byType(Scaffold));
      await tester.dragFrom(center, const Offset(60, 40));
      await tester.pumpAndSettle();

      expect(controller.value.strokes, hasLength(1));
      expect(controller.canUndo, isTrue);

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(controller.value.strokes, isEmpty);
    });

    testWidgets('draw: picking a shape and a color updates the controller', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      await tester.tap(find.byTooltip('Rectangle'));
      await tester.pump();
      expect(controller.shapeType, ShapeType.rectangle);

      final before = controller.drawColor;
      const palette = ChatImageEditorThemeData.defaultPalette;
      final target = palette.firstWhere((color) => color != before);
      // Tap the swatch for [target] in the strip.
      final swatch = find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedContainer &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == target,
      );
      await tester.tap(swatch);
      await tester.pump();
      expect(controller.drawColor, target);
    });

    testWidgets('draw: a single offered shape is drawn without a picker', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.arrow],
        ),
      );

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      expect(find.byTooltip('Arrow'), findsNothing);
      expect(find.byTooltip('Pen'), findsNothing);
      expect(controller.shapeType, ShapeType.arrow);

      final center = tester.getCenter(find.byType(Scaffold));
      await tester.dragFrom(center, const Offset(60, 40));
      await tester.pumpAndSettle();
      expect(controller.value.strokes.single.type, ShapeType.arrow);
    });

    testWidgets('draw: the picker highlights the first offered shape', (
      tester,
    ) async {
      final controller = await pumpReadyEditor(
        tester,
        config: const ChatImageEditorConfig(
          shapes: <ShapeType>[ShapeType.line, ShapeType.arrow],
        ),
      );

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();
      expect(controller.shapeType, ShapeType.line);
      expect(find.byTooltip('Pen'), findsNothing);
      final line = tester.widget<EditorIconButton>(
        find.ancestor(
          of: find.byTooltip('Line'),
          matching: find.byType(EditorIconButton),
        ),
      );
      expect(line.active, isTrue);
    });

    testWidgets('draw: screen readers can pick each swatch', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await pumpReadyEditor(
        tester,
        strings: ChatImageEditorStrings(
          colorLabel: (color, index, count) => 'Swatch ${index + 1}/$count',
        ),
      );

      await tester.tap(find.byTooltip('Draw'));
      await tester.pump();

      const palette = ChatImageEditorThemeData.defaultPalette;
      for (var i = 0; i < palette.length; i++) {
        expect(
          tester.getSemantics(find.bySemanticsLabel('Swatch ${i + 1}/10')),
          matchesSemantics(
            label: 'Swatch ${i + 1}/10',
            isButton: true,
            hasTapAction: true,
            hasSelectedState: true,
            isSelected: palette[i] == controller.drawColor,
          ),
        );
      }

      final target = palette.indexWhere((c) => c != controller.drawColor);
      tester.semantics.tap(find.semantics.byLabel('Swatch ${target + 1}/10'));
      await tester.pump();
      expect(controller.drawColor, palette[target]);
      semantics.dispose();
    });

    testWidgets('crop: rotate and confirm', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.crop);
      expect(find.byTooltip('Rotate left'), findsOneWidget);
      expect(find.byTooltip('Flip horizontally'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.byTooltip('Rotate right'));
      await tester.pump();
      expect(controller.value.quarterTurns, 1);

      await tester.tap(find.text('1:1'));
      await tester.pump();
      expect(controller.cropAspectRatio, 1);

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(controller.value.quarterTurns, 1);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('crop: cancel restores the image', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pump();
      await tester.tap(find.byTooltip('Flip vertically'));
      await tester.pump();
      expect(controller.value.flipY || controller.value.flipX, isTrue);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
      expect(controller.hasChanges, isFalse);
    });

    testWidgets('crop: dragging a corner changes the crop', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Crop and rotate'));
      await tester.pumpAndSettle();
      expect(controller.value.crop, isNull);

      // The frame starts on the whole image; grab its bottom-right corner.
      final overlay = find.byType(CropOverlay);
      final image = EditorLayout.imageRect(
        tester.getSize(overlay),
        EditorLayout.canvasPadding(tester.element(overlay), EditorTool.crop),
        EditorLayout.paintedOutputSize(controller),
      ).shift(tester.getTopLeft(overlay));
      await tester.dragFrom(
        image.bottomRight - const Offset(2, 2),
        const Offset(-60, -40),
      );
      await tester.pump();

      final crop = controller.value.crop;
      expect(crop, isNotNull);
      expect(crop!.right, lessThan(1));
      expect(crop.bottom, lessThan(1));
    });

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
        expect(
          style.backgroundColor,
          TextLayerColors.boxColor(layer),
          reason: '$background',
        );
      }
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

      final canvas = find.byType(EditorCanvas);
      final image = EditorLayout.imageRect(
        tester.getSize(canvas),
        EditorLayout.canvasPadding(tester.element(canvas), EditorTool.none),
        EditorLayout.paintedOutputSize(controller),
      ).shift(tester.getTopLeft(canvas));

      final gesture = await tester.startGesture(image.center);
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      expect(controller.activeTextId, isNotNull);
      expect(find.byType(DeleteTarget), findsOneWidget);
      expect(controller.value.texts.single.position, isNot(start));

      await gesture.moveTo(tester.getCenter(find.byType(DeleteTarget)));
      await gesture.moveBy(const Offset(0, 1));
      await tester.pump();
      expect(controller.isOverDeleteTarget, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.activeTextId, isNull);
      expect(controller.value.texts, isEmpty);
      expect(find.byType(DeleteTarget), findsNothing);
    });

    testWidgets('text: tapping a layer opens it for editing', (tester) async {
      final controller = await pumpReadyEditor(tester);
      controller
        ..selectTool(EditorTool.text)
        ..updateEditingText('Edit me')
        ..finishTextEditing();
      await tester.pumpAndSettle();
      final id = controller.value.texts.single.id;

      final canvas = find.byType(EditorCanvas);
      final image = EditorLayout.imageRect(
        tester.getSize(canvas),
        EditorLayout.canvasPadding(tester.element(canvas), EditorTool.none),
        EditorLayout.paintedOutputSize(controller),
      ).shift(tester.getTopLeft(canvas));
      await tester.tapAt(image.center);
      await tester.pump();

      expect(controller.editingTextId, id);
      expect(find.text('Edit me'), findsOneWidget);
    });

    testWidgets('text: an empty layer is dropped', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Text'));
      await tester.pump();
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      expect(controller.value.texts, isEmpty);
    });

    testWidgets('every tool fits a small phone screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = await pumpReadyEditor(tester);

      for (final tool in <String>['Draw', 'Crop and rotate', 'Image quality']) {
        await tester.tap(find.byTooltip(tool));
        await tester.pumpAndSettle();
        controller.closeTool();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Text'));
      await tester.pumpAndSettle();
      expect(controller.editingTextId, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compress: shows sizes and commits on close', (tester) async {
      final controller = await pumpReadyEditor(tester);

      await tester.tap(find.byTooltip('Image quality'));
      await tester.pump();
      expect(controller.activeTool, EditorTool.compress);
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Estimated size'), findsOneWidget);
      expect(find.text('Calculating…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 350));
      await pumpUntil(
        tester,
        () => find.text('Calculating…').evaluate().isEmpty,
      );

      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      expect(controller.activeTool, EditorTool.none);
    });
  });
}
