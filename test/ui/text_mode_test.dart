import 'package:chat_image_editor/chat_image_editor.dart';
import 'package:chat_image_editor/src/core/render/text_layer_colors.dart';
import 'package:chat_image_editor/src/ui/delete_target.dart';
import 'package:chat_image_editor/src/ui/editor_canvas.dart';
import 'package:chat_image_editor/src/ui/editor_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_test_utils.dart';

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
  });
}
